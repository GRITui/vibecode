import Testing
import Foundation
import TelegramBot
import OrbStack
import SelfHeal
import HealthMonitor
import LLMConfig
import WebServer

@Test func telegramModels() async throws {
    // Test TelegramUpdate decoding
    let json = """
    {
        "update_id": 123,
        "message": {
            "message_id": 1,
            "from": {
                "id": 456,
                "is_bot": false,
                "first_name": "Test",
                "username": "testuser"
            },
            "chat": {
                "id": 789,
                "type": "private"
            },
            "text": "/start",
            "date": 1234567890
        }
    }
    """
    
    let data = json.data(using: .utf8)!
    let update = try JSONDecoder().decode(TelegramUpdate.self, from: data)
    
    #expect(update.updateId == 123)
    #expect(update.message?.text == "/start")
    #expect(update.message?.chat.id == 789)
}

@Test func inlineKeyboard() async throws {
    let keyboard = CallbackQueryHandler.createApprovalKeyboard(requestId: "test-123")
    
    #expect(keyboard.inlineKeyboard.count == 1)
    #expect(keyboard.inlineKeyboard[0].count == 2)
    #expect(keyboard.inlineKeyboard[0][0].text == "✅ Approve")
    #expect(keyboard.inlineKeyboard[0][0].callbackData == "approve:test-123")
    #expect(keyboard.inlineKeyboard[0][1].text == "❌ Reject")
    #expect(keyboard.inlineKeyboard[0][1].callbackData == "reject:test-123")
}

@Test func containerConfig() async throws {
    let config = ContainerConfig(
        name: "test-container",
        image: "node:18",
        workingDir: "/app",
        environment: ["NODE_ENV": "test"],
        ports: ["3000": "3000"]
    )
    
    #expect(config.name == "test-container")
    #expect(config.image == "node:18")
    #expect(config.workingDir == "/app")
    #expect(config.environment["NODE_ENV"] == "test")
}

@Test func testResult() async throws {
    let result = TestResult(
        testName: "example test",
        passed: true,
        errorMessage: nil,
        duration: 1.5
    )
    
    #expect(result.testName == "example test")
    #expect(result.passed == true)
    #expect(result.duration == 1.5)
}

@Test func testSuiteResult() async throws {
    let results = [
        TestResult(testName: "test1", passed: true),
        TestResult(testName: "test2", passed: false, errorMessage: "Failed"),
        TestResult(testName: "test3", passed: true)
    ]
    
    let suite = TestSuiteResult(results: results, totalDuration: 5.0)
    
    #expect(suite.passedCount == 2)
    #expect(suite.failedCount == 1)
    #expect(suite.allPassed == false)
}


// MARK: - HealthMonitor Tests

@Test func healthStatusCoding() async throws {
    let checks = [
        ComponentHealth(component: "container:test", healthy: true, status: "running", latencyMs: 45),
        ComponentHealth(component: "system:disk", healthy: false, status: "95% used", latencyMs: 12, errorMessage: "Disk full")
    ]
    let status = HealthStatus(overallHealthy: false, checks: checks)
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    let data = try encoder.encode(status)
    let decoded = try decoder.decode(HealthStatus.self, from: data)
    
    #expect(decoded.overallHealthy == false)
    #expect(decoded.checks.count == 2)
    #expect(decoded.checks[0].component == "container:test")
    #expect(decoded.checks[1].errorMessage == "Disk full")
}

@Test func healingActionRecordCoding() async throws {
    let record = HealingActionRecord(action: "RestartContainer", target: "test-container", success: true)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    let data = try encoder.encode(record)
    let decoded = try decoder.decode(HealingActionRecord.self, from: data)
    
    #expect(decoded.action == "RestartContainer")
    #expect(decoded.target == "test-container")
    #expect(decoded.success == true)
}

@Test func restartContainerActionCanHeal() async throws {
    let healthy = ComponentHealth(component: "container:app", healthy: true, status: "running", latencyMs: 10)
    let unhealthy = ComponentHealth(component: "container:app", healthy: false, status: "exited", latencyMs: 10, errorMessage: "stopped")
    
    let action = RestartContainerAction()
    #expect(action.canHeal(healthy) == false)
    #expect(action.canHeal(unhealthy) == true)
}

@Test func dependencyHealActionCanHeal() async throws {
    let noError = ComponentHealth(component: "service:app", healthy: false, status: "error", latencyMs: 10)
    let missingDep = ComponentHealth(component: "service:app", healthy: false, status: "error", latencyMs: 10, errorMessage: "module not found")
    
    let action = DependencyHealAction()
    #expect(action.canHeal(noError) == false)
    #expect(action.canHeal(missingDep) == true)
}

@Test func healthMonitorExportJSON() async throws {
    let monitor = HealthMonitor(
        orbStack: OrbStackManager(),
        checks: [],
        healingActions: [],
        checkInterval: 9999
    )
    
    // No status yet
    let empty = await monitor.exportStatusJSON()
    #expect(empty == nil)
}

@Test func smallModelPromptGeneration() async throws {
    let monitor = HealthMonitor(
        orbStack: OrbStackManager(),
        checks: [],
        healingActions: [],
        checkInterval: 9999
    )
    
    let prompt = await monitor.generateSmallModelPrompt()
    #expect(prompt == nil)
}

@Test func smallModelDecisionIgnore() async throws {
    let monitor = HealthMonitor(
        orbStack: OrbStackManager(),
        checks: [],
        healingActions: [],
        checkInterval: 9999
    )
    
    let result = await monitor.applySmallModelDecision("ignore")
    #expect(result == "Ignored")
}

// MARK: - LLMConfig / Model Evaluation Tests (Issue #3)

@Test func llmConfigFallbackChainIncludesGLM() async throws {
    let config = LLMConfig.fromEnvironment()
    #expect(config.fallbackModels.contains("z-ai/glm-5.2:free"))
    #expect(config.primaryModel == "gpt-4o-mini")
    #expect(config.monthlyBudgetUSD == 15.0)
}

@Test func llmConfigSelectModelFallback() async throws {
    let config = LLMConfig(
        primaryModel: "gpt-4o-mini",
        fallbackModels: ["z-ai/glm-5.2:free", "openai/gpt-4o-mini"]
    )
    #expect(config.selectModel(attempt: 0) == "gpt-4o-mini")
    #expect(config.selectModel(attempt: 1) == "z-ai/glm-5.2:free")
    #expect(config.selectModel(attempt: 2) == "openai/gpt-4o-mini")
    #expect(config.selectModel(attempt: 99) == "openai/gpt-4o-mini")
}

@Test func modelRegistryEvaluationAndRecommendation() async throws {
    let registry = ModelRegistry.shared
    registry.recordEvaluation(
        model: "z-ai/glm-5.2:free",
        toolCallingReliable: true,
        latencyMs: 850,
        notes: "Fast, reliable tool calling in staging"
    )
    registry.recordEvaluation(
        model: "gpt-4o-mini",
        toolCallingReliable: true,
        latencyMs: 420,
        notes: "Baseline"
    )
    registry.recordEvaluation(
        model: "bad-model",
        toolCallingReliable: false,
        latencyMs: 1200,
        notes: "Unreliable"
    )

    #expect(registry.evaluation(for: "z-ai/glm-5.2:free")?.toolCallingReliable == true)
    #expect(registry.recommendedPrimary() == "gpt-4o-mini")
}

// MARK: - LiteLLM Budget Alert Tests (Issue #40)

@Test func litellmBudgetAlertParsing() async throws {
    let json = """
    {
        "budget_alert": true,
        "budget_limit": 15.0,
        "current_spend": 14.50,
        "projected_spend": 16.20,
        "alert_type": "budget_threshold",
        "user_email": "ops@example.com",
        "team_name": "vibecode"
    }
    """

    let alert = LiteLLMBudgetAlert.parse(from: json)
    #expect(alert != nil)
    #expect(alert?.budgetAlert == true)
    #expect(alert?.budgetLimit == 15.0)
    #expect(alert?.currentSpend == 14.50)
    #expect(alert?.projectedSpend == 16.20)
    #expect(alert?.alertType == "budget_threshold")
    #expect(alert?.userEmail == "ops@example.com")
    #expect(alert?.teamName == "vibecode")
}

@Test func litellmBudgetAlertParsingMinimal() async throws {
    let json = """
    {
        "budget_alert": true,
        "budget_limit": 15.0,
        "current_spend": 14.50,
        "alert_type": "budget_threshold"
    }
    """

    let alert = LiteLLMBudgetAlert.parse(from: json)
    #expect(alert != nil)
    #expect(alert?.projectedSpend == nil)
}

