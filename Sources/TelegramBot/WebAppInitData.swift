import Foundation
import CryptoKit

/// Represents Telegram Mini App initialization data passed via WebAppInitData.
/// See: https://core.telegram.org/bots/webapps#initializing-mini-apps
public struct WebAppInitData: Sendable {
    public let rawQueryString: String
    public let user: WebAppUser?
    public let receiver: WebAppUser?
    public let chat: WebAppChat?
    public let chatType: String?
    public let chatInstance: String?
    public let startParam: String?
    public let authDate: Int
    public let queryId: String?
    public let signature: String?
    public let hash: String

    /// Whether the auth_date is older than 24 hours (replay protection).
    public var isExpired: Bool {
        let authDateInterval = TimeInterval(authDate)
        let now = Date().timeIntervalSince1970
        return (now - authDateInterval) > 86400
    }

    public init?(from queryString: String) {
        self.rawQueryString = queryString

        var components = URLComponents()
        components.query = queryString

        guard let items = components.queryItems, !items.isEmpty else {
            return nil
        }

        var dict: [String: String] = [:]
        for item in items {
            dict[item.name] = item.value ?? ""
        }

        guard let hash = dict["hash"], !hash.isEmpty else {
            return nil
        }
        self.hash = hash

        // Parse JSON-embedded fields (URL-decoded)
        if let userJson = dict["user"]?.removingPercentEncoding {
            self.user = try? JSONDecoder().decode(WebAppUser.self, from: Data(userJson.utf8))
        } else {
            self.user = nil
        }

        if let receiverJson = dict["receiver"]?.removingPercentEncoding {
            self.receiver = try? JSONDecoder().decode(WebAppUser.self, from: Data(receiverJson.utf8))
        } else {
            self.receiver = nil
        }

        if let chatJson = dict["chat"]?.removingPercentEncoding {
            self.chat = try? JSONDecoder().decode(WebAppChat.self, from: Data(chatJson.utf8))
        } else {
            self.chat = nil
        }

        self.authDate = Int(dict["auth_date"] ?? "") ?? 0
        self.queryId = dict["query_id"]
        self.chatInstance = dict["chat_instance"]
        self.chatType = dict["chat_type"]
        self.startParam = dict["start_param"]
        self.signature = dict["signature"]
    }

    /// Validates the HMAC-SHA256 hash using the bot token.
    /// Returns `true` if the init data is authentic and un-tampered.
    public func isValid(botToken: String) -> Bool {
        var components = URLComponents()
        components.query = rawQueryString

        guard let items = components.queryItems else { return false }

        // Build data-check-string from all fields except hash and signature
        var pairs: [(key: String, value: String)] = []
        for item in items {
            if item.name == "hash" || item.name == "signature" {
                continue
            }
            pairs.append((item.name, item.value ?? ""))
        }

        pairs.sort { $0.key < $1.key }
        let dataCheckString = pairs.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")

        guard let botTokenData = botToken.data(using: .utf8),
              let dataCheckStringData = dataCheckString.data(using: .utf8),
              let webAppDataData = "WebAppData".data(using: .utf8) else {
            return false
        }

        let secretKey = HMAC<SHA256>.authenticationCode(
            for: botTokenData,
            using: SymmetricKey(data: webAppDataData)
        )
        let secretKeySym = SymmetricKey(data: Data(secretKey))
        let computedHash = HMAC<SHA256>.authenticationCode(
            for: dataCheckStringData,
            using: secretKeySym
        )
        let computedHashHex = Data(computedHash).map { String(format: "%02x", $0) }.joined()

        return computedHashHex == hash
    }
}

public struct WebAppUser: Codable, Sendable {
    public let id: Int64
    public let isBot: Bool?
    public let firstName: String
    public let lastName: String?
    public let username: String?
    public let languageCode: String?
    public let isPremium: Bool?
    public let addedToAttachmentMenu: Bool?
    public let allowsWriteToPm: Bool?
    public let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case languageCode = "language_code"
        case isPremium = "is_premium"
        case addedToAttachmentMenu = "added_to_attachment_menu"
        case allowsWriteToPm = "allows_write_to_pm"
        case photoUrl = "photo_url"
    }
}

public struct WebAppChat: Codable, Sendable {
    public let id: Int64
    public let type: String
    public let title: String?
    public let username: String?
    public let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case username
        case photoUrl = "photo_url"
    }
}
