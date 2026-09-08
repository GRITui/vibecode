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
        • AI Provider: \(selectedProvider.displayName)
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

    /// ISS-2: bot-not-responding diagnostics — reports the signals most likely to explain
    /// "the bot isn't responding" without requiring log access.
    func handleDiagCommand(chatId: Int) async throws {
        var text = "🔍 Diagnostics\n\n"

        text += "• Token: \(telegramBot.tokenPrefix)…\n"
        text += "• Chat: \(chatId == authorizedChatId ? "✅ authorized" : "❌ unauthorized (expected \(authorizedChatId))")\n"

        let reachable = (try? await telegramBot.getMe()) ?? false
        text += "• Telegram API reachable: \(reachable ? "✅" : "❌")\n"

        switch await orbStack.checkAvailability() {
        case .available(let version):
            text += "• OrbStack: ✅ \(version)\n"
        case .commandNotFound:
            text += "• OrbStack: ❌ command not found\n"
        case .commandFailed(let reason):
            text += "• OrbStack: ❌ \(reason)\n"
        }

        if let status = await healthMonitor.getLastStatus() {
            let age = Date().timeIntervalSince(status.timestamp)
            text += "• Last health check: \(String(format: "%.0f", age))s ago\n"
        } else {
            text += "• Last health check: none recorded yet\n"
        }

        try await telegramBot.sendMessage(chatId: chatId, text: text)
    }

    func handleProviderCommand(chatId: Int) async throws {
        let keyboard = AIProvider.createProviderKeyboard()

        try await telegramBot.sendMessage(
            chatId: chatId,
            text: "🧑‍💻 Choose an AI coding CLI:",
            replyMarkup: keyboard
        )
    }

    func handleTaskCommand(chatId: Int, prompt: String) async throws {
        guard !prompt.isEmpty else {
            try await telegramBot.sendMessage(
                chatId: chatId,
                text: "Usage: /task <prompt>"
            )
            return
        }

        do {
            let provider = selectedProvider
            let output = try await orbStack.execInContainer(
                name: "test-container",
                command: [provider.cliBinary, prompt]
            )

            let truncated = output.count > 3500 ? String(output.prefix(3500)) + "\n…(truncated)" : output
            try await telegramBot.sendMessage(
                chatId: chatId,
                text: "🤖 \(provider.displayName) output:\n\n\(truncated)"
            )
        } catch {
            print("❌ Error running /task: \(error)")
            try? await telegramBot.sendMessage(
                chatId: chatId,
                text: "❌ Task execution failed: \(error.localizedDescription)"
            )
        }
    }
}
