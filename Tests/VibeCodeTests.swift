import Testing
import Foundation
import TelegramBot
import OrbStack
import SelfHeal
import HealthMonitor
import LLMConfig
import WebServer
@testable import AIBot

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

@Test func rebuildContainerActionCanHeal() async throws {
    let healthy = ComponentHealth(component: "container:app", healthy: true, status: "running", latencyMs: 10)
    let unhealthyContainer = ComponentHealth(component: "container:app", healthy: false, status: "exited", latencyMs: 10, errorMessage: "stopped")
    let unhealthyNonContainer = ComponentHealth(component: "system:disk", healthy: false, status: "95% used", latencyMs: 10)

    let action = RebuildContainerAction()
    #expect(action.canHeal(healthy) == false)
    #expect(action.canHeal(unhealthyContainer) == true)
    #expect(action.canHeal(unhealthyNonContainer) == false)
}

@Test func clearCacheActionCanHeal() async throws {
    let healthyDiskFull = ComponentHealth(component: "system:disk", healthy: true, status: "95% used", latencyMs: 10, errorMessage: "no space")
    let unhealthyNoSpace = ComponentHealth(component: "system:disk", healthy: false, status: "95% used", latencyMs: 10, errorMessage: "no space left on device")
    let unhealthyDiskFull = ComponentHealth(component: "system:disk", healthy: false, status: "95% used", latencyMs: 10, errorMessage: "disk full")
    let unhealthyEnospc = ComponentHealth(component: "system:disk", healthy: false, status: "err", latencyMs: 10, errorMessage: "write failed: ENOSPC")
    let unhealthyOtherError = ComponentHealth(component: "system:disk", healthy: false, status: "err", latencyMs: 10, errorMessage: "permission denied")
    let unhealthyNoError = ComponentHealth(component: "system:disk", healthy: false, status: "err", latencyMs: 10)

    let action = ClearCacheAction()
    #expect(action.canHeal(healthyDiskFull) == false)
    #expect(action.canHeal(unhealthyNoSpace) == true)
    #expect(action.canHeal(unhealthyDiskFull) == true)
    #expect(action.canHeal(unhealthyEnospc) == true)
    #expect(action.canHeal(unhealthyOtherError) == false)
    #expect(action.canHeal(unhealthyNoError) == false)
}

@Test func dependencyHealActionCanHeal() async throws {
    let noError = ComponentHealth(component: "service:app", healthy: false, status: "error", latencyMs: 10)
    let missingDep = ComponentHealth(component: "service:app", healthy: false, status: "error", latencyMs: 10, errorMessage: "module not found")
    
    let action = DependencyHealAction()
    #expect(action.canHeal(noError) == false)
    #expect(action.canHeal(missingDep) == true)
}

// MARK: - Healing Action execute() Tests

@Test func restartContainerActionExecuteSucceeds() async throws {
    let mock = MockOrbStack()
    let action = RestartContainerAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == true)
    #expect(mock.stoppedContainers == ["app"])
    #expect(mock.startedContainers == ["app"])
}

@Test func restartContainerActionExecuteReturnsFalseOnFailure() async throws {
    let mock = MockOrbStack()
    mock.errorToThrow = MockError(message: "boom")
    let action = RestartContainerAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == false)
}

@Test func rebuildContainerActionExecuteSucceeds() async throws {
    let mock = MockOrbStack()
    let action = RebuildContainerAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == true)
    #expect(mock.removedContainers.count == 1)
    #expect(mock.removedContainers.first?.name == "app")
    #expect(mock.removedContainers.first?.force == true)
}

@Test func rebuildContainerActionExecuteReturnsFalseOnFailure() async throws {
    let mock = MockOrbStack()
    mock.errorToThrow = MockError(message: "boom")
    let action = RebuildContainerAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == false)
}

@Test func clearCacheActionExecuteSucceeds() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "cleared"
    let action = ClearCacheAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == true)
    #expect(mock.execCalls.count == 1)
    #expect(mock.execCalls.first?.name == "app")
}

@Test func dependencyHealActionExecuteTriesNextCommandOnFailure() async throws {
    let mock = MockOrbStack()
    let action = DependencyHealAction()
    let result = try await action.execute(target: "app", orbStack: mock)
    #expect(result == true)
    #expect(mock.execCalls.count == 1)
}

// MARK: - Health Check Tests

@Test func containerHealthCheckReportsRunning() async throws {
    let mock = MockOrbStack()
    mock.statusToReturn = ContainerStatus(id: "abc123", name: "app", state: "running", status: "Up 2 minutes")
    let check = ContainerHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.component == "container:app")
    #expect(health.healthy == true)
    #expect(health.status == "running")
}

@Test func containerHealthCheckReportsExited() async throws {
    let mock = MockOrbStack()
    mock.statusToReturn = ContainerStatus(id: "abc123", name: "app", state: "exited", status: "Exited (1)")
    let check = ContainerHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
    #expect(health.status == "exited")
}

@Test func containerHealthCheckReportsNotFound() async throws {
    let mock = MockOrbStack()
    mock.statusToReturn = nil
    let check = ContainerHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
    #expect(health.status == "not_found")
}

@Test func containerHealthCheckReportsError() async throws {
    let mock = MockOrbStack()
    mock.errorToThrow = MockError(message: "docker not reachable")
    let check = ContainerHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
    #expect(health.status == "error")
}

@Test func diskSpaceHealthCheckContainerHealthy() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "42"
    let check = DiskSpaceHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.component == "system:disk")
    #expect(health.healthy == true)
    #expect(health.status == "42% used")
}

@Test func diskSpaceHealthCheckContainerUnhealthy() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "95"
    let check = DiskSpaceHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
    #expect(health.status == "95% used")
}

@Test func memoryHealthCheckContainerHealthy() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "30"
    let check = MemoryHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.component == "system:memory")
    #expect(health.healthy == true)
}

@Test func memoryHealthCheckContainerUnhealthy() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "97"
    let check = MemoryHealthCheck(containerName: "app", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
}

@Test func testRunnerHealthCheckPassing() async throws {
    let mock = MockOrbStack()
    mock.execResultToReturn = "All tests passed"
    let check = TestRunnerHealthCheck(containerName: "app", workingDir: "/app", testCommand: "npm test", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.component == "service:testrunner")
    #expect(health.healthy == true)
}

@Test func testRunnerHealthCheckFailing() async throws {
    let mock = MockOrbStack()
    mock.errorToThrow = MockError(message: "test command failed")
    let check = TestRunnerHealthCheck(containerName: "app", workingDir: "/app", testCommand: "npm test", orbStack: mock)
    let health = await check.performCheck()
    #expect(health.healthy == false)
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

// MARK: - BacklogParser Tests

@Test func backlogParserParsesKnownSections() async throws {
    let markdown = """
    ## Core Features

    | ID | Feature | Status | Notes |
    |----|---------|--------|-------|
    | F-1 | Telegram Integration | ✅ | Control via Telegram |

    ## Health Checks

    | ID | Check | Status | Description |
    |----|-------|--------|-------------|
    | HC-1 | ContainerHealthCheck | 🚧 | Verify container state |
    """

    let sections = BacklogParser.parse(markdown)
    #expect(sections.count == 2)
    #expect(sections[0].name == "Core Features")
    #expect(sections[1].name == "Health Checks")
}

@Test func backlogParserNormalizesStatusEmojis() async throws {
    let markdown = """
    ## Status Cases

    | ID | Feature | Status | Notes |
    |----|---------|--------|-------|
    | S-1 | Done Item | ✅ | done |
    | S-2 | Partial Item | 🚧 | in progress |
    | S-3 | Todo Item | ⬜ | not started |
    """

    let sections = BacklogParser.parse(markdown)
    let items = sections[0].items
    #expect(items[0].status == "done")
    #expect(items[1].status == "in_progress")
    #expect(items[2].status == "todo")
}

@Test func backlogParserHandlesMethodColumn() async throws {
    let markdown = """
    ## Web Server Endpoints

    | ID | Endpoint | Method | Status | Description |
    |----|----------|--------|--------|-------------|
    | EP-1 | `/health` | GET | 🚧 | Latest health check status |
    """

    let sections = BacklogParser.parse(markdown)
    #expect(sections[0].items[0].title == "GET `/health`")
}

@Test func backlogParserSkipsSectionsWithNoTable() async throws {
    let markdown = """
    ## Empty Section

    This section has no table, just prose.

    ## Populated Section

    | ID | Feature | Status | Notes |
    |----|---------|--------|-------|
    | F-1 | Something | ✅ | note |
    """

    let sections = BacklogParser.parse(markdown)
    #expect(sections.count == 1)
    #expect(sections[0].name == "Populated Section")
}

@Test func backlogParserIgnoresNonTableProse() async throws {
    let markdown = """
    # VibeCode Backlog

    This backlog captures features and enhancements.

    ---

    ## Core Features

    | ID | Feature | Status | Notes |
    |----|---------|--------|-------|
    | F-1 | Telegram Integration | ✅ | Control via Telegram |
    """

    let sections = BacklogParser.parse(markdown)
    #expect(sections.count == 1)
    #expect(sections[0].items.count == 1)
}

// MARK: - AIProvider Tests

@Test func aiProviderDisplayNamesAndBinaries() async throws {
    #expect(AIProvider.claude.displayName == "Claude Code")
    #expect(AIProvider.claude.cliBinary == "claude")
    #expect(AIProvider.cline.displayName == "Cline")
    #expect(AIProvider.cline.cliBinary == "cline")
    #expect(AIProvider.opencode.displayName == "opencode")
    #expect(AIProvider.opencode.cliBinary == "opencode")
}

@Test func aiProviderKeyboardHasThreeButtonsWithCallbackData() async throws {
    let keyboard = AIProvider.createProviderKeyboard()

    #expect(keyboard.inlineKeyboard.count == 1)
    let buttons = keyboard.inlineKeyboard[0]
    #expect(buttons.count == 3)

    #expect(buttons[0].callbackData == "provider:claude")
    #expect(buttons[1].callbackData == "provider:cline")
    #expect(buttons[2].callbackData == "provider:opencode")

    #expect(buttons[0].text == "Claude Code")
    #expect(buttons[1].text == "Cline")
    #expect(buttons[2].text == "opencode")
}

@Test func aiProviderParsesFromCallbackData() async throws {
    let data = "provider:cline"
    let rawValue = String(data.dropFirst("provider:".count))
    let provider = AIProvider(rawValue: rawValue)

    #expect(provider == .cline)
}

@Test func aiProviderRejectsUnknownCallbackData() async throws {
    let data = "provider:unknown"
    let rawValue = String(data.dropFirst("provider:".count))
    let provider = AIProvider(rawValue: rawValue)

    #expect(provider == nil)
}

@Test func orchestratorDefaultsToClaudeAndSelectionUpdates() async throws {
    let orchestrator = AIBotOrchestrator(
        botToken: "test-token",
        authorizedChatId: 1,
        orbStack: OrbStackManager()
    )

    #expect(orchestrator.selectedProvider == .claude)

    orchestrator.selectedProvider = .opencode
    #expect(orchestrator.selectedProvider == .opencode)
    #expect(orchestrator.selectedProvider.displayName == "opencode")
}

@Test func backlogParserOnRealBacklogFile() async throws {
    let markdown = try String(contentsOfFile: "BACKLOG.md", encoding: .utf8)
    let sections = BacklogParser.parse(markdown)
    let names = sections.map { $0.name }
    #expect(names.contains("Core Features"))
    #expect(names.contains("Health Checks"))
    #expect(names.contains("Healing Actions"))
    #expect(names.contains("Web Server Endpoints"))
    #expect(!sections.isEmpty)
}

