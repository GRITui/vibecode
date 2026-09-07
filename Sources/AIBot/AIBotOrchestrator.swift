import Foundation
import TelegramBot
import OrbStack
import SelfHeal
import HealthMonitor
import WebServer
import LLMConfig

public final class AIBotOrchestrator {
    let telegramBot: TelegramBotClient
    let callbackHandler: CallbackQueryHandler
    let orbStack: OrbStackManager
    let testRunner: SelfHealingTestRunner
    let healthMonitor: HealthMonitor
    let webServer: WebServer
    let authorizedChatId: Int
    let llmConfig: LLMConfig
    
    private var lastUpdateId: Int = 0
    var isRunning = false
    
    public init(
        botToken: String,
        authorizedChatId: Int,
        orbStack: OrbStackManager = OrbStackManager()
    ) {
        self.telegramBot = TelegramBotClient(botToken: botToken)
        self.callbackHandler = CallbackQueryHandler()
        self.orbStack = orbStack
        self.testRunner = SelfHealingTestRunner(orbStack: orbStack)
        self.authorizedChatId = authorizedChatId
        self.llmConfig = LLMConfig.fromEnvironment()
        
        // Configure HealthMonitor sub-agent
        let _ = ProcessInfo.processInfo.environment["HEALTH_WEBHOOK_URL"]
        let intervalStr = ProcessInfo.processInfo.environment["HEALTH_CHECK_INTERVAL"]
        let checkInterval = intervalStr.flatMap { TimeInterval($0) } ?? 60
        
        self.healthMonitor = HealthMonitor(
            orbStack: orbStack,
            telegramBot: telegramBot,
            authorizedChatId: authorizedChatId,
            checks: [
                ContainerHealthCheck(containerName: "test-container", orbStack: orbStack),
                DiskSpaceHealthCheck(orbStack: orbStack),
                MemoryHealthCheck(orbStack: orbStack)
            ],
            checkInterval: checkInterval
        )
        
        let portStr = ProcessInfo.processInfo.environment["WEB_SERVER_PORT"]
        let port = portStr.flatMap { Int($0) } ?? 8080
        self.webServer = WebServer(
            orbStack: orbStack,
            healthMonitor: healthMonitor,
            telegramBot: telegramBot,
            authorizedChatId: authorizedChatId,
            botToken: botToken,
            port: port
        )
    }
    
    public func start() async throws {
        print("🤖 Starting AI Bot...")
        print("🧠 LLM Primary Model: \(llmConfig.primaryModel)")
        print("🧠 LLM Fallbacks: \(llmConfig.fallbackModels.joined(separator: ", "))")
        
        let hasOrbStack = try await orbStack.verifyOrbStack()
        guard hasOrbStack else {
            throw BotOrchestratorError.orbStackNotAvailable
        }
        print("✅ OrbStack verified")
        
        isRunning = true
        
        // Start health monitor sub-agent
        await healthMonitor.start()
        
        // Start web server concurrently
        async let _ = webServer.start()
        
        try await telegramBot.sendMessage(
            chatId: authorizedChatId,
            text: "🤖 AI Bot started and ready!\n\nCommands:\n/status - Check bot status\n/run - Run tests with self-healing\n/containers - List containers\n/health - Health status"
        )
        
        while isRunning {
            do {
                let updates = try await telegramBot.getUpdates(offset: lastUpdateId + 1, timeout: 30)
                for update in updates {
                    lastUpdateId = update.updateId
                    if let message = update.message {
                        await handleMessage(message)
                    } else if let callbackQuery = update.callbackQuery {
                        await handleCallbackQuery(callbackQuery)
                    }
                }
            } catch {
                print("❌ Error polling updates: \(error)")
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    public func stop() {
        isRunning = false
        Task {
            await healthMonitor.stop()
        }
    }
    
    public enum BotOrchestratorError: Error, LocalizedError {
        case orbStackNotAvailable
        case unauthorizedAccess
        
        public var errorDescription: String? {
            switch self {
            case .orbStackNotAvailable:
                return "OrbStack is not available or not running"
            case .unauthorizedAccess:
                return "Unauthorized access"
            }
        }
    }
}
