import Foundation
import TelegramBot

/// Manages authenticated sessions for Telegram Mini App users.
public actor MiniAppSessionManager {
    public struct Session: Codable, Sendable {
        public let token: String
        public let userId: Int64
        public let username: String?
        public let firstName: String
        public let authDate: Int
        public let hash: String
        public let createdAt: Date
    }

    private var sessions: [String: Session] = [:]
    private let sessionTimeout: TimeInterval

    public init(sessionTimeout: TimeInterval = 86400 * 7) {
        self.sessionTimeout = sessionTimeout
    }

    /// Creates a new session from validated WebAppInitData.
    public func createSession(from initData: WebAppInitData) -> Session? {
        guard let user = initData.user else { return nil }
        let token = UUID().uuidString
        let session = Session(
            token: token,
            userId: user.id,
            username: user.username,
            firstName: user.firstName,
            authDate: initData.authDate,
            hash: initData.hash,
            createdAt: Date()
        )
        sessions[token] = session
        return session
    }

    /// Retrieves a session by token if it exists and hasn't expired.
    public func getSession(token: String) -> Session? {
        guard let session = sessions[token] else { return nil }
        if Date().timeIntervalSince(session.createdAt) > sessionTimeout {
            sessions.removeValue(forKey: token)
            return nil
        }
        return session
    }

    /// Invalidates a session token.
    public func invalidateSession(token: String) {
        sessions.removeValue(forKey: token)
    }
}
