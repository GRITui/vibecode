import Testing
import Foundation
@testable import SelfHeal
import OrbStack

// MARK: - ISS-3: SelfHealingTestRunner error-prefix diagnostics

@Suite("SelfHealingTestRunner diagnostics")
struct SelfHealingTestRunnerDiagnosticsTests {
    @Test("containerNotFound classifies as [container-missing]")
    func containerNotFoundClassifiesAsMissing() {
        let error = OrbStackManager.OrbStackError.containerNotFound("test-container")
        let message = SelfHealingTestRunner.diagnosticMessage(for: error)
        #expect(message.hasPrefix("[container-missing]"))
    }

    @Test("commandFailed with 'No such container' stderr classifies as [container-missing]")
    func commandFailedNoSuchContainerClassifiesAsMissing() {
        let error = OrbStackManager.OrbStackError.commandFailed(
            command: "docker exec test-container npm test",
            exitCode: 1,
            error: "Error: No such container: test-container"
        )
        let message = SelfHealingTestRunner.diagnosticMessage(for: error)
        #expect(message.hasPrefix("[container-missing]"))
    }

    @Test("commandFailed with 'is not running' stderr classifies as [container-stopped]")
    func commandFailedNotRunningClassifiesAsStopped() {
        let error = OrbStackManager.OrbStackError.commandFailed(
            command: "docker exec test-container npm test",
            exitCode: 1,
            error: "Error response from daemon: Container test-container is not running"
        )
        let message = SelfHealingTestRunner.diagnosticMessage(for: error)
        #expect(message.hasPrefix("[container-stopped]"))
    }

    @Test("commandFailed with an ordinary non-zero exit classifies as [test-command-failed]")
    func commandFailedOrdinaryExitClassifiesAsTestCommandFailed() {
        let error = OrbStackManager.OrbStackError.commandFailed(
            command: "docker exec test-container npm test",
            exitCode: 1,
            error: "1 failing"
        )
        let message = SelfHealingTestRunner.diagnosticMessage(for: error)
        #expect(message.hasPrefix("[test-command-failed]"))
    }

    @Test("An unrecognized error falls back to [test-command-failed]")
    func unrecognizedErrorFallsBackToTestCommandFailed() {
        struct OtherError: Error {}
        let message = SelfHealingTestRunner.diagnosticMessage(for: OtherError())
        #expect(message.hasPrefix("[test-command-failed]"))
    }
}
