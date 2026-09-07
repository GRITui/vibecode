import Foundation
import TelegramBot

/// Reports health status to external systems (n8n webhooks, HTTP endpoints, Telegram).
public actor HealthReporter {
    private let telegramBot: TelegramBotClient?
    private let authorizedChatId: Int?
    private let webhookURL: URL?
    private let session: URLSession
    
    public init(
        telegramBot: TelegramBotClient? = nil,
        authorizedChatId: Int? = nil,
        webhookURL: String? = nil
    ) {
        self.telegramBot = telegramBot
        self.authorizedChatId = authorizedChatId
        self.webhookURL = webhookURL.flatMap { URL(string: $0) }
        self.session = URLSession(configuration: .default)
    }
    
    /// Send a health status payload to the configured n8n webhook.
    public func reportToWebhook(status: HealthStatus) async -> Bool {
        guard let url = webhookURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(status) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
            return false
        } catch {
            print("❌ Webhook report failed: \(error)")
            return false
        }
    }
    
    /// Send a compact summary to Telegram.
    public func reportToTelegram(status: HealthStatus) async {
        guard let bot = telegramBot, let chatId = authorizedChatId else { return }
        
        var text = "📊 Health Status\n"
        text += "Overall: \(status.overallHealthy ? "✅ Healthy" : "❌ Unhealthy")\n\n"
        for check in status.checks {
            let emoji = check.healthy ? "✅" : "❌"
            text += "\(emoji) \(check.component) (\(String(format: "%.0f", check.latencyMs))ms)\n"
        }
        
        do {
            try await bot.sendMessage(chatId: chatId, text: text)
        } catch {
            print("❌ Telegram report failed: \(error)")
        }
    }
    
    /// Publish health status to all configured channels.
    public func publish(status: HealthStatus) async {
        _ = await reportToWebhook(status: status)
        await reportToTelegram(status: status)
    }
}
