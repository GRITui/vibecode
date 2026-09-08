import Foundation
import TelegramBot
import OrbStack
import SelfHeal
import HealthMonitor

extension AIBotOrchestrator {
    func handleMessage(_ message: TelegramMessage) async {
        guard message.chat.id == authorizedChatId else {
            return
        }
        
        guard let text = message.text else { return }
        
        do {
            switch text {
            case "/start", "/help":
                try await telegramBot.sendMessage(
                    chatId: message.chat.id,
                    text: "🤖 AI Bot Commands:\n\n/status - Check bot status\n/run - Run tests with self-healing\n/containers - List containers\n/health - Health status & small-model prompt\n/diag - Diagnostics (bot-not-responding troubleshooting)\n/provider - Choose AI coding CLI (Claude, Cline, opencode)\n/task <prompt> - Run a prompt with the selected AI CLI"
                )

            case "/status":
                try await handleStatusCommand(chatId: message.chat.id)

            case "/run":
                try await handleRunCommand(chatId: message.chat.id)

            case "/containers":
                try await handleContainersCommand(chatId: message.chat.id)

            case "/health":
                try await handleHealthCommand(chatId: message.chat.id)

            case "/diag":
                try await handleDiagCommand(chatId: message.chat.id)

            case "/provider":
                try await handleProviderCommand(chatId: message.chat.id)

            default:
                if text.hasPrefix("/task") {
                    let prompt = String(text.dropFirst("/task".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    try await handleTaskCommand(chatId: message.chat.id, prompt: prompt)
                } else if text.hasPrefix("/") {
                    try await telegramBot.sendMessage(
                        chatId: message.chat.id,
                        text: "Unknown command. Use /help to see available commands."
                    )
                }
            }
        } catch {
            print("❌ Error handling message: \(error)")
            try? await telegramBot.sendMessage(
                chatId: message.chat.id,
                text: "❌ Error: \(error.localizedDescription)"
            )
        }
    }
    
    func handleCallbackQuery(_ callbackQuery: TelegramCallbackQuery) async {
        guard callbackQuery.from.id == authorizedChatId else {
            return
        }

        if let data = callbackQuery.data, data.hasPrefix("provider:") {
            await handleProviderCallbackQuery(callbackQuery)
            return
        }

        do {
            let response = try await callbackHandler.handleCallbackQuery(callbackQuery)
            
            if let messageId = callbackQuery.message?.messageId {
                try await telegramBot.editMessageText(
                    chatId: callbackQuery.from.id,
                    messageId: messageId,
                    text: callbackQuery.message?.text ?? "Action completed",
                    replyMarkup: nil
                )
            }
            
            try await telegramBot.answerCallbackQuery(
                callbackQueryId: callbackQuery.id,
                text: response
            )
        } catch {
            print("❌ Error handling callback: \(error)")
        }
    }

    /// Handles "provider:<rawValue>" callbacks from the `/provider` keyboard.
    /// Stateless selection — doesn't go through `CallbackQueryHandler`'s
    /// approve/reject `pendingApprovals` machinery, which doesn't fit here.
    func handleProviderCallbackQuery(_ callbackQuery: TelegramCallbackQuery) async {
        guard let data = callbackQuery.data else { return }
        let rawValue = String(data.dropFirst("provider:".count))

        guard let provider = AIProvider(rawValue: rawValue) else {
            try? await telegramBot.answerCallbackQuery(
                callbackQueryId: callbackQuery.id,
                text: "Unknown provider"
            )
            return
        }

        selectedProvider = provider

        do {
            if let messageId = callbackQuery.message?.messageId {
                try await telegramBot.editMessageText(
                    chatId: callbackQuery.from.id,
                    messageId: messageId,
                    text: "✅ Using \(provider.displayName)",
                    replyMarkup: nil
                )
            }

            try await telegramBot.answerCallbackQuery(
                callbackQueryId: callbackQuery.id,
                text: "✅ Using \(provider.displayName)"
            )
        } catch {
            print("❌ Error handling provider callback: \(error)")
        }
    }
}
