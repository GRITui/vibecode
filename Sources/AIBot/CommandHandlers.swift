import Foundation
import TelegramBot
import OrbStack
import SelfHeal
import HealthMonitor

extension AIBotOrchestrator {
    func handleStatusCommand(chatId: Int) async throws {
        let containers = try await orbStack.listContainers()
        let status = """
        📊 Bot Status
        
        • OrbStack: ✅ Connected
        • Active Containers: \(containers.count)
        • Bot Status: \(isRunning ? "🟢 Running" : "🔴 Stopped")
        """
        
        try await telegramBot.sendMessage(chatId: chatId, text: status)
    }
    
    func handleRunCommand(chatId: Int) async throws {
        try await telegramBot.sendMessage(
            chatId: chatId,
            text: "🧪 Running tests with self-healing enabled..."
        )
        
        let requestId = UUID().uuidString
        let keyboard = CallbackQueryHandler.createApprovalKeyboard(requestId: requestId)
        
        callbackHandler.registerApproval(requestId: requestId) { [weak self] _, _ in
            guard let self = self else { return false }
            
            Task {
                do {
                    let result = try await self.testRunner.runTests(
                        containerName: "test-container",
                        workingDir: "/workspace",
                        testCommand: "npm test",
                        parseResults: { output in
                            return [TestResult(testName: "Example", passed: output.contains("PASS"))]
                        }
                    )
                    
                    let summary = """
                    🧪 Test Results
                    
                    ✅ Passed: \(result.passedCount)
                    ❌ Failed: \(result.failedCount)
                    ⏱️ Duration: \(String(format: "%.2f", result.totalDuration))s
                    """
                    
                    try await self.telegramBot.sendMessage(chatId: chatId, text: summary)
                } catch {
                    try? await self.telegramBot.sendMessage(
                        chatId: chatId,
                        text: "❌ Test execution failed: \(error.localizedDescription)"
                    )
                }
            }
            
            return true
        }
        
        try await telegramBot.sendMessage(
            chatId: chatId,
            text: "⚠️ Run tests with self-healing?",
            replyMarkup: keyboard
        )
    }
    
    func handleContainersCommand(chatId: Int) async throws {
        let containers = try await orbStack.listContainers()
        
        if containers.isEmpty {
            try await telegramBot.sendMessage(
                chatId: chatId,
                text: "📦 No containers found"
            )
            return
        }
        
        var text = "📦 Containers:\n\n"
        for container in containers {
            let emoji = container.state == "running" ? "🟢" : "🔴"
            text += "\(emoji) \(container.name)\n   State: \(container.state)\n   Status: \(container.status)\n\n"
        }
        
        try await telegramBot.sendMessage(chatId: chatId, text: text)
    }
    
    func handleHealthCommand(chatId: Int) async throws {
        await healthMonitor.runCheckCycle()
        
        guard let status = await healthMonitor.getLastStatus() else {
            try await telegramBot.sendMessage(
                chatId: chatId,
                text: "🏥 No health data available yet."
            )
            return
        }
        
        var text = "🏥 Health Status\n"
        text += "Overall: \(status.overallHealthy ? "✅ Healthy" : "❌ Unhealthy")\n\n"
        
        for check in status.checks {
            let emoji = check.healthy ? "✅" : "❌"
            text += "\(emoji) \(check.component)\n"
            text += "   Status: \(check.status)\n"
            text += "   Latency: \(String(format: "%.0f", check.latencyMs))ms\n"
            if let error = check.errorMessage {
                text += "   Error: \(error)\n"
            }
        }
        
        if !status.healingActions.isEmpty {
            text += "\n🔧 Recent Healing:\n"
            for action in status.healingActions {
                text += "• \(action.action) on \(action.target): \(action.success ? "✅" : "❌")\n"
            }
        }
        
        // Small model delegation prompt
        if let prompt = await healthMonitor.generateSmallModelPrompt() {
            text += "\n📋 Small Model Prompt:\n```\n\(prompt)\n```"
        }
        
        try await telegramBot.sendMessage(chatId: chatId, text: text)
    }
}
