import Foundation

public final class TelegramBotClient {
    private let botToken: String
    private let baseUrl: String
    private let session: URLSession
    
    public init(botToken: String) {
        self.botToken = botToken
        self.baseUrl = "https://api.telegram.org/bot\(botToken)"
        self.session = URLSession(configuration: .default)
    }

    /// First 8 characters of the bot token, for diagnostics — never the full token.
    public var tokenPrefix: String {
        String(botToken.prefix(8))
    }

    // MARK: - Reachability

    /// Calls Telegram's `getMe` endpoint — a lightweight reachability/token-validity probe
    /// (distinct from polling `getUpdates`), used for bot-not-responding diagnostics (ISS-2).
    public func getMe() async throws -> Bool {
        guard let url = URL(string: "\(baseUrl)/getMe") else {
            throw BotError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TelegramAPIResponse<TelegramBotInfo>.self, from: data)
        return response.ok
    }

    // MARK: - Polling

    public func getUpdates(offset: Int? = nil, timeout: Int = 30) async throws -> [TelegramUpdate] {
        var urlString = "\(baseUrl)/getUpdates?timeout=\(timeout)"
        if let offset = offset {
            urlString += "&offset=\(offset)"
        }
        
        guard let url = URL(string: urlString) else {
            throw BotError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TelegramAPIResponse<[TelegramUpdate]>.self, from: data)
        
        guard response.ok else {
            throw BotError.apiError(response.description ?? "Unknown error")
        }
        
        return response.result ?? []
    }
    
    // MARK: - Send Message
    
    public func sendMessage(chatId: Int, text: String, replyMarkup: InlineKeyboardMarkup? = nil) async throws {
        var body: [String: Any] = [
            "chat_id": chatId,
            "text": text
        ]
        
        if let markup = replyMarkup {
            let encoder = JSONEncoder()
            let markupData = try encoder.encode(markup)
            let markupDict = try JSONSerialization.jsonObject(with: markupData) as? [String: Any]
            body["reply_markup"] = markupDict
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        guard let url = URL(string: "\(baseUrl)/sendMessage") else {
            throw BotError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(TelegramAPIResponse<TelegramMessage>.self, from: data)
        
        guard response.ok else {
            throw BotError.apiError(response.description ?? "Unknown error")
        }
    }
    
    // MARK: - Answer Callback Query
    
    public func answerCallbackQuery(callbackQueryId: String, text: String? = nil) async throws {
        var body: [String: Any] = [
            "callback_query_id": callbackQueryId
        ]
        
        if let text = text {
            body["text"] = text
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        guard let url = URL(string: "\(baseUrl)/answerCallbackQuery") else {
            throw BotError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(TelegramAPIResponse<Bool>.self, from: data)
        
        guard response.ok else {
            throw BotError.apiError(response.description ?? "Unknown error")
        }
    }
    
    // MARK: - Edit Message
    
    public func editMessageText(chatId: Int, messageId: Int, text: String, replyMarkup: InlineKeyboardMarkup? = nil) async throws {
        var body: [String: Any] = [
            "chat_id": chatId,
            "message_id": messageId,
            "text": text
        ]
        
        if let markup = replyMarkup {
            let encoder = JSONEncoder()
            let markupData = try encoder.encode(markup)
            let markupDict = try JSONSerialization.jsonObject(with: markupData) as? [String: Any]
            body["reply_markup"] = markupDict
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        guard let url = URL(string: "\(baseUrl)/editMessageText") else {
            throw BotError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(TelegramAPIResponse<TelegramMessage>.self, from: data)
        
        guard response.ok else {
            throw BotError.apiError(response.description ?? "Unknown error")
        }
    }
    
    // MARK: - Errors
    
    public enum BotError: Error, LocalizedError {
        case invalidURL
        case apiError(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .apiError(let message):
                return "Telegram API error: \(message)"
            }
        }
    }
}
