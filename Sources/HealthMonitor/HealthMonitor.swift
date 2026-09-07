import Foundation
import OrbStack
import SelfHeal
import TelegramBot

/// A lightweight sub-agent that continuously monitors system and container health,
/// delegates healing to small-model-compatible strategies, and reports status.
public actor HealthMonitor {
    let orbStack: OrbStackManager
    let telegramBot: TelegramBotClient?
    let authorizedChatId: Int?
    let checks: [HealthCheck]
    let healingActions: [HealingAction]
    let checkInterval: TimeInterval
    private var isRunning = false
    private var healingHistory: [HealingActionRecord] = []
    var lastStatus: HealthStatus?
    private var currentTask: Task<Void, Never>?
    
    public init(
        orbStack: OrbStackManager,
        telegramBot: TelegramBotClient? = nil,
        authorizedChatId: Int? = nil,
        checks: [HealthCheck]? = nil,
        healingActions: [HealingAction]? = nil,
        checkInterval: TimeInterval = 60
    ) {
        self.orbStack = orbStack
        self.telegramBot = telegramBot
        self.authorizedChatId = authorizedChatId
        self.checks = checks ?? []
        self.healingActions = healingActions ?? HealthMonitor.defaultHealingActions()
        self.checkInterval = checkInterval
    }
    
    public func start() async {
        guard !isRunning else { return }
        isRunning = true
        print("🏥 Health Monitor sub-agent started (interval: \(Int(checkInterval))s)")
        currentTask = Task { [weak self] in
            while let monitor = self, await monitor.isRunning {
                await monitor.runCheckCycle()
                try? await Task.sleep(nanoseconds: UInt64(monitor.checkInterval * 1_000_000_000))
            }
        }
    }
    
    public func stop() {
        isRunning = false
        currentTask?.cancel()
        currentTask = nil
        print("🛑 Health Monitor sub-agent stopped")
    }
    
    public func runCheckCycle() async {
        var componentHealths: [ComponentHealth] = []
        var healingRecords: [HealingActionRecord] = []
        
        for check in checks {
            let health = await check.performCheck()
            componentHealths.append(health)
            if !health.healthy {
                print("⚠️ \(check.componentName) unhealthy: \(health.errorMessage ?? "unknown")")
                let records = await attemptHealing(health: health)
                healingRecords.append(contentsOf: records)
            }
        }
        
        let overallHealthy = componentHealths.allSatisfy { $0.healthy }
        let status = HealthStatus(
            timestamp: Date(),
            overallHealthy: overallHealthy,
            checks: componentHealths,
            healingActions: healingRecords
        )
        lastStatus = status
        if !overallHealthy {
            await notifyUnhealthy(status: status)
        }
    }
    
    private func attemptHealing(health: ComponentHealth) async -> [HealingActionRecord] {
        var records: [HealingActionRecord] = []
        let target = extractTarget(from: health.component)
        for action in healingActions {
            if action.canHeal(health) {
                print("🔧 Healing action '\(action.name)' targeting \(target)")
                do {
                    let success = try await action.execute(target: target, orbStack: orbStack)
                    let record = HealingActionRecord(action: action.name, target: target, success: success)
                    records.append(record)
                    if success { break }
                } catch {
                    let record = HealingActionRecord(action: action.name, target: target, success: false, errorMessage: String(describing: error))
                    records.append(record)
                }
            }
        }
        healingHistory.append(contentsOf: records)
        if healingHistory.count > 100 { healingHistory.removeFirst(healingHistory.count - 100) }
        return records
    }
    
    func extractTarget(from component: String) -> String {
        if let colonIndex = component.firstIndex(of: ":") {
            return String(component.suffix(from: component.index(after: colonIndex)))
        }
        return component
    }
    
    private func notifyUnhealthy(status: HealthStatus) async {
        guard let bot = telegramBot, let chatId = authorizedChatId else { return }
        var text = "🚨 Health Alert\n\n"
        for check in status.checks where !check.healthy {
            text += "❌ \(check.component): \(check.errorMessage ?? check.status)\n"
        }
        if !status.healingActions.isEmpty {
            text += "\n🔧 Healing attempts:\n"
            for action in status.healingActions {
                text += "• \(action.action) on \(action.target): \(action.success ? "✅" : "❌")\n"
            }
        }
        do {
            try await bot.sendMessage(chatId: chatId, text: text)
        } catch {
            print("❌ Failed to send health alert: \(error)")
        }
    }
    
    public func getLastStatus() -> HealthStatus? { lastStatus }
    public func getHealingHistory() -> [HealingActionRecord] { healingHistory }
    
    public func exportStatusJSON() -> String? {
        guard let status = lastStatus else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(status) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public static func defaultHealingActions() -> [HealingAction] {
        return [RestartContainerAction(), ClearCacheAction(), DependencyHealAction(), RebuildContainerAction()]
    }
}
