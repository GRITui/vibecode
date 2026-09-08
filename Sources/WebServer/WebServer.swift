import Foundation
import Hummingbird
import HealthMonitor
import OrbStack
import TelegramBot

/// Hummingbird-based web server providing HTTP endpoints for health, status, webhooks, and Mini App sessions.
public actor WebServer {
    let orbStack: OrbStackManager
    let healthMonitor: HealthMonitor
    let telegramBot: TelegramBotClient?
    let authorizedChatId: Int?
    let botToken: String?
    let port: Int
    let sessionManager: MiniAppSessionManager

    public init(
        orbStack: OrbStackManager,
        healthMonitor: HealthMonitor,
        telegramBot: TelegramBotClient? = nil,
        authorizedChatId: Int? = nil,
        botToken: String? = nil,
        port: Int = 8080
    ) {
        self.orbStack = orbStack
        self.healthMonitor = healthMonitor
        self.telegramBot = telegramBot
        self.authorizedChatId = authorizedChatId
        self.botToken = botToken
        self.port = port
        self.sessionManager = MiniAppSessionManager()
    }

    /// Builds the Hummingbird router with all routes registered. Exposed (via `@testable import`)
    /// so tests can exercise routes through `HummingbirdTesting`'s `.router` test framework
    /// without binding a real port.
    func buildRouter() -> Router<BasicRequestContext> {
        let router = Router()

        // Capture values for @Sendable route closures
        let healthMonitor = self.healthMonitor
        let orbStack = self.orbStack
        let telegramBot = self.telegramBot
        let authorizedChatId = self.authorizedChatId
        let botToken = self.botToken
        let sessionManager = self.sessionManager

        // GET /health — returns latest health status JSON
        router.get("/health") { _, _ async in
            let json = await healthMonitor.exportStatusJSON()
            if let json = json {
                var response = Response(
                    status: .ok,
                    headers: .init(),
                    body: .init(byteBuffer: .init(string: json))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            } else {
                return Response(status: .noContent)
            }
        }

        // GET /status — returns bot status overview
        router.get("/status") { _, _ async in
            let containers = try? await orbStack.listContainers()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys
            let response = StatusResponse(
                botRunning: true,
                orbStackConnected: true,
                activeContainers: containers?.count ?? 0,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            let data = (try? encoder.encode(response)) ?? Data()
            var responseObj = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(data: data))
            )
            responseObj.headers[.contentType] = "application/json; charset=utf-8"
            return responseObj
        }

        // GET /dashboard — service-health dashboard UI
        router.get("/dashboard") { _, _ async in
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(string: DashboardHTML.render()))
            )
            response.headers[.contentType] = "text/html; charset=utf-8"
            return response
        }

        // GET /roadmap.json — parses BACKLOG.md into kanban-ready sections
        router.get("/roadmap.json") { _, _ async in
            guard let markdown = try? String(contentsOfFile: "BACKLOG.md", encoding: .utf8) else {
                var response = Response(
                    status: .internalServerError,
                    headers: .init(),
                    body: .init(byteBuffer: .init(string: #"{"error":"Could not read BACKLOG.md"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }
            let sections = BacklogParser.parse(markdown)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = (try? encoder.encode(sections)) ?? Data()
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(data: data))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // GET /diagnostics — bot-not-responding diagnostics (ISS-2), reachable even if the
        // Telegram polling loop itself is wedged, since this is served independently of it.
        router.get("/diagnostics") { _, _ async in
            let orbAvailability: String
            switch await orbStack.checkAvailability() {
            case .available(let version):
                orbAvailability = "available(\(version))"
            case .commandNotFound:
                orbAvailability = "commandNotFound"
            case .commandFailed(let reason):
                orbAvailability = "commandFailed(\(reason))"
            }

            var telegramReachable = false
            if let bot = telegramBot {
                telegramReachable = (try? await bot.getMe()) ?? false
            }

            let lastCheck = await healthMonitor.getLastStatus()
            let secondsSinceLastHealthCheck = lastCheck.map { Date().timeIntervalSince($0.timestamp) }

            let diagnostics = DiagnosticsResponse(
                telegramConfigured: telegramBot != nil,
                telegramReachable: telegramReachable,
                orbStackAvailability: orbAvailability,
                secondsSinceLastHealthCheck: secondsSinceLastHealthCheck
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = (try? encoder.encode(diagnostics)) ?? Data()
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(data: data))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // POST /health/delegate — delegate current health status to the small-model decision path
        router.post("/health/delegate") { request, _ async throws -> Response in
            await healthMonitor.runCheckCycle()
            guard let prompt = await healthMonitor.generateSmallModelPrompt() else {
                return Response(status: .noContent)
            }

            var decision = "alert"
            if let buffer = try? await request.body.collect(upTo: 1024 * 1024) {
                let bodyString = String(buffer: buffer)
                struct DelegateRequest: Decodable { let decision: String }
                if let bodyData = bodyString.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode(DelegateRequest.self, from: bodyData) {
                    decision = parsed.decision
                }
            }

            let result = await healthMonitor.applySmallModelDecision(decision)

            struct DelegateResponse: Codable {
                let prompt: String
                let decision: String
                let result: String
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = (try? encoder.encode(DelegateResponse(prompt: prompt, decision: decision, result: result))) ?? Data()
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(data: data))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // POST /webhook/telegram — Telegram webhook receiver
        router.post("/webhook/telegram") { _, _ async in
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(string: "{\"ok\":true}"))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // POST /webhook/n8n — n8n automation webhook
        router.post("/webhook/n8n") { request, _ async throws in
            let buffer = try await request.body.collect(upTo: 1024 * 1024)
            let bodyString = String(buffer: buffer)
            print("📡 n8n webhook received: \(bodyString)")
            if let bot = telegramBot, let chatId = authorizedChatId {
                try? await bot.sendMessage(chatId: chatId, text: "📡 n8n webhook: \(bodyString)")
            }
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(string: "{\"received\":true}"))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // POST /webhook/litellm-budget — LiteLLM budget alert webhook (Issue #40)
        router.post("/webhook/litellm-budget") { request, _ async throws in
            let buffer = try await request.body.collect(upTo: 1024 * 1024)
            let bodyString = String(buffer: buffer)
            print("💰 LiteLLM budget alert received: \(bodyString)")
            let alert = LiteLLMBudgetAlert.parse(from: bodyString)
            if let bot = telegramBot, let chatId = authorizedChatId, let alert = alert {
                let pct = String(format: "%.1f", (alert.currentSpend / alert.budgetLimit) * 100)
                let alertMessage = """
                🚨 **LiteLLM Budget Alert**
                • Current spend: $\(String(format: "%.2f", alert.currentSpend)) / $\(String(format: "%.2f", alert.budgetLimit))
                • Usage: \(pct)% of monthly cap
                • Type: \(alert.alertType)
                \(alert.projectedSpend.map { "• Projected: $\(String(format: "%.2f", $0))" } ?? "")
                
                Check your usage dashboard.
                """
                try? await bot.sendMessage(chatId: chatId, text: alertMessage)
            }
            var response = Response(
                status: .ok,
                headers: .init(),
                body: .init(byteBuffer: .init(string: "{\"received\":true}"))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        // MARK: - Mini App Endpoints

        // POST /miniapp/launch — Validate WebAppInitData and create session
        router.post("/miniapp/launch") { request, _ async throws -> Response in
            let buffer = try await request.body.collect(upTo: 1024 * 1024)
            let bodyString = String(buffer: buffer)

            struct LaunchRequest: Decodable {
                let initData: String
            }

            guard let bodyData = bodyString.data(using: .utf8),
                  let launchReq = try? JSONDecoder().decode(LaunchRequest.self, from: bodyData) else {
                var response = Response(
                    status: .badRequest,
                    body: .init(byteBuffer: .init(string: #"{"error":"Invalid request body. Expected JSON: { \"initData\": \"...\" }"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            guard let initData = WebAppInitData(from: launchReq.initData) else {
                var response = Response(
                    status: .badRequest,
                    body: .init(byteBuffer: .init(string: #"{"error":"Invalid init data format"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            guard !initData.isExpired else {
                var response = Response(
                    status: .unauthorized,
                    body: .init(byteBuffer: .init(string: #"{"error":"Init data expired"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            guard let token = botToken else {
                var response = Response(
                    status: .internalServerError,
                    body: .init(byteBuffer: .init(string: #"{"error":"Bot token not configured"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            guard initData.isValid(botToken: token) else {
                var response = Response(
                    status: .unauthorized,
                    body: .init(byteBuffer: .init(string: #"{"error":"Invalid init data signature"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            guard let session = await sessionManager.createSession(from: initData) else {
                var response = Response(
                    status: .internalServerError,
                    body: .init(byteBuffer: .init(string: #"{"error":"Failed to create session"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let responseBody = LaunchResponse(
                token: session.token,
                userId: session.userId,
                firstName: session.firstName,
                username: session.username
            )
            let data = try encoder.encode(responseBody)
            var response = Response(
                status: .ok,
                body: .init(byteBuffer: .init(data: data))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            response.headers[.accessControlAllowOrigin] = "*"
            return response
        }

        // GET /miniapp/me — Return current user from session token
        router.get("/miniapp/me") { request, _ async throws -> Response in
            guard let authHeader = request.headers[.authorization] else {
                var response = Response(
                    status: .unauthorized,
                    body: .init(byteBuffer: .init(string: #"{"error":"Missing Authorization header"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            let token: String
            if authHeader.hasPrefix("Bearer ") {
                token = String(authHeader.dropFirst(7))
            } else {
                token = authHeader
            }

            guard let session = await sessionManager.getSession(token: token) else {
                var response = Response(
                    status: .unauthorized,
                    body: .init(byteBuffer: .init(string: #"{"error":"Invalid or expired session"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let responseBody = MeResponse(
                userId: session.userId,
                firstName: session.firstName,
                username: session.username
            )
            let data = try encoder.encode(responseBody)
            var response = Response(
                status: .ok,
                body: .init(byteBuffer: .init(data: data))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            response.headers[.accessControlAllowOrigin] = "*"
            return response
        }

        // POST /miniapp/logout — Invalidate session
        router.post("/miniapp/logout") { request, _ async throws -> Response in
            guard let authHeader = request.headers[.authorization] else {
                var response = Response(
                    status: .badRequest,
                    body: .init(byteBuffer: .init(string: #"{"error":"Missing Authorization header"}"#))
                )
                response.headers[.contentType] = "application/json; charset=utf-8"
                return response
            }

            let token: String
            if authHeader.hasPrefix("Bearer ") {
                token = String(authHeader.dropFirst(7))
            } else {
                token = authHeader
            }

            await sessionManager.invalidateSession(token: token)
            var response = Response(
                status: .ok,
                body: .init(byteBuffer: .init(string: #"{"ok":true}"#))
            )
            response.headers[.contentType] = "application/json; charset=utf-8"
            return response
        }

        return router
    }

    public func start() async throws {
        let router = buildRouter()
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )
        print("🌐 Web server starting on port \(port)")
        try await app.run()
        print("🌐 Web server stopped")
    }
}

struct DiagnosticsResponse: Codable {
    let telegramConfigured: Bool
    let telegramReachable: Bool
    let orbStackAvailability: String
    let secondsSinceLastHealthCheck: Double?
}

struct StatusResponse: Codable {
    let botRunning: Bool
    let orbStackConnected: Bool
    let activeContainers: Int
    let timestamp: String
}

struct LaunchResponse: Codable {
    let token: String
    let userId: Int64
    let firstName: String
    let username: String?
}

struct MeResponse: Codable {
    let userId: Int64
    let firstName: String
    let username: String?
}

/// LiteLLM budget alert payload parser (Issue #40)
public struct LiteLLMBudgetAlert: Codable {
    public let budgetAlert: Bool
    public let budgetLimit: Double
    public let currentSpend: Double
    public let projectedSpend: Double?
    public let alertType: String
    public let userEmail: String?
    public let teamName: String?

    enum CodingKeys: String, CodingKey {
        case budgetAlert = "budget_alert"
        case budgetLimit = "budget_limit"
        case currentSpend = "current_spend"
        case projectedSpend = "projected_spend"
        case alertType = "alert_type"
        case userEmail = "user_email"
        case teamName = "team_name"
    }

    public static func parse(from jsonString: String) -> LiteLLMBudgetAlert? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LiteLLMBudgetAlert.self, from: data)
    }
}
