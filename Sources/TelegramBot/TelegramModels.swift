import Foundation

// MARK: - Telegram API Models

public struct TelegramUpdate: Codable {
    public let updateId: Int
    public let message: TelegramMessage?
    public let callbackQuery: TelegramCallbackQuery?
    
    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
        case callbackQuery = "callback_query"
    }
}

public struct TelegramMessage: Codable {
    public let messageId: Int
    public let from: TelegramUser?
    public let chat: TelegramChat
    public let text: String?
    public let date: Int
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from
        case chat
        case text
        case date
    }
}

public struct TelegramUser: Codable {
    public let id: Int
    public let isBot: Bool
    public let firstName: String
    public let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case username
    }
}

public struct TelegramChat: Codable {
    public let id: Int
    public let type: String
}

public struct TelegramCallbackQuery: Codable {
    public let id: String
    public let from: TelegramUser
    public let message: TelegramMessage?
    public let data: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case from
        case message
        case data
    }
}

public struct InlineKeyboardMarkup: Codable {
    public let inlineKeyboard: [[InlineKeyboardButton]]
    
    enum CodingKeys: String, CodingKey {
        case inlineKeyboard = "inline_keyboard"
    }
    
    public init(inlineKeyboard: [[InlineKeyboardButton]]) {
        self.inlineKeyboard = inlineKeyboard
    }
}

public struct InlineKeyboardButton: Codable {
    public let text: String
    public let callbackData: String?
    public let url: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case callbackData = "callback_data"
        case url
    }
    
    public init(text: String, callbackData: String? = nil, url: String? = nil) {
        self.text = text
        self.callbackData = callbackData
        self.url = url
    }
}

public struct TelegramBotInfo: Codable {
    public let id: Int
    public let username: String?
}

// MARK: - API Response

struct TelegramAPIResponse<T: Codable>: Codable {
    let ok: Bool
    let result: T?
    let description: String?
}
