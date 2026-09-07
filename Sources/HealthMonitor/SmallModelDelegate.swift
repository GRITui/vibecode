import Foundation
import OrbStack
import TelegramBot

extension HealthMonitor {
    /// Formats health data into a compact prompt suitable for a small LLM.
    public func generateSmallModelPrompt() -> String? {
        guard let status = lastStatus else { return nil }
        var prompt = "System health report:\n"
        for check in status.checks {
            let emoji = check.healthy ? "✅" : "❌"
            prompt += "\(emoji) \(check.component) (\(check.status))\n"
            if let err = check.errorMessage {
                prompt += "  Error: \(err)\n"
            }
        }
        prompt += "\nRecent healing attempts: \(status.healingActions.count)\n"
        prompt += "Overall healthy: \(status.overallHealthy)\n"
        prompt += "\nWhat action should be taken? (restart|rebuild|ignore|alert|escalate)"
        return prompt
    }
    
    /// Accepts a small model decision and translates it into an action.
    public func applySmallModelDecision(_ decision: String) async -> String {
        let lower = decision.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lower {
        case let s where s.contains("restart"):
            guard let status = lastStatus else { return "No status available" }
            for check in status.checks where !check.healthy {
                let target = extractTarget(from: check.component)
                if check.component.starts(with: "container:") {
                    do {
                        try await orbStack.stopContainer(name: target)
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        try await orbStack.startContainer(name: target)
                        return "Restarted \(target)"
                    } catch {
                        return "Failed to restart \(target): \(error)"
                    }
                }
            }
            return "No container to restart"
        case let s where s.contains("rebuild"):
            guard let status = lastStatus else { return "No status available" }
            for check in status.checks where !check.healthy {
                let target = extractTarget(from: check.component)
                if check.component.starts(with: "container:") {
                    do {
                        try await orbStack.removeContainer(name: target, force: true)
                        return "Removed \(target) for rebuild"
                    } catch {
                        return "Failed to remove \(target): \(error)"
                    }
                }
            }
            return "No container to rebuild"
        case let s where s.contains("alert"):
            guard let bot = telegramBot, let chatId = authorizedChatId else { return "No Telegram configured" }
            do {
                try await bot.sendMessage(chatId: chatId, text: "🚨 Health alert escalated by sub-agent.")
                return "Alert sent"
            } catch {
                return "Failed to alert: \(error)"
            }
        case let s where s.contains("escalate"):
            return "Escalated to human operator"
        default:
            return "Ignored"
        }
    }
}
