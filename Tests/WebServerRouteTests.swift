import Testing
import Foundation
import Hummingbird
import HummingbirdTesting
@testable import WebServer
import OrbStack
import HealthMonitor

// MARK: - WebServer Route Tests (EP-1..4)
//
// Uses Hummingbird's `.router` test framework, which sends requests directly to the
// router without binding a real port. `WebServer.buildRouter()` is `internal`, reachable
// here via `@testable import WebServer`.

@Suite("WebServer routes")
struct WebServerRouteTests {
    func makeServer() -> WebServer {
        let orbStack = OrbStackManager()
        let healthMonitor = HealthMonitor(orbStack: orbStack)
        return WebServer(orbStack: orbStack, healthMonitor: healthMonitor)
    }

    @Test("GET /health returns 204 when no health status has been recorded yet")
    func healthRouteNoContentWhenNoStatus() async throws {
        let server = makeServer()
        let router = await server.buildRouter()
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                #expect(response.status == .noContent)
            }
        }
    }

    @Test("GET /status returns 200 JSON with expected fields")
    func statusRouteReturnsJSON() async throws {
        let server = makeServer()
        let router = await server.buildRouter()
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/status", method: .get) { response in
                #expect(response.status == .ok)
                #expect(response.headers[.contentType] == "application/json; charset=utf-8")
                let body = String(buffer: response.body)
                #expect(body.contains("\"botRunning\":true"))
                #expect(body.contains("\"activeContainers\""))
            }
        }
    }

    @Test("POST /webhook/telegram always returns 200 {ok:true}")
    func telegramWebhookReturnsOk() async throws {
        let server = makeServer()
        let router = await server.buildRouter()
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/webhook/telegram", method: .post) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "{\"ok\":true}")
            }
        }
    }

    @Test("POST /webhook/n8n echoes received:true and logs the body")
    func n8nWebhookReturnsReceived() async throws {
        let server = makeServer()
        let router = await server.buildRouter()
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(
                uri: "/webhook/n8n",
                method: .post,
                body: ByteBuffer(string: "{\"source\":\"test\"}")
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "{\"received\":true}")
            }
        }
    }
}
