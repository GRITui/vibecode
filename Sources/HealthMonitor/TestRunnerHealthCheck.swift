import Foundation
import OrbStack

public struct TestRunnerHealthCheck: HealthCheck {
    public let componentName = "service:testrunner"
    private let containerName: String
    private let workingDir: String
    private let testCommand: String
    private let orbStack: any ContainerRuntime

    public init(containerName: String, workingDir: String, testCommand: String, orbStack: any ContainerRuntime) {
        self.containerName = containerName
        self.workingDir = workingDir
        self.testCommand = testCommand
        self.orbStack = orbStack
    }
    
    public func performCheck() async -> ComponentHealth {
        let start = Date()
        do {
            _ = try await orbStack.execInContainer(
                name: containerName,
                command: ["sh", "-c", "cd \(workingDir) && \(testCommand)"]
            )
            let latency = Date().timeIntervalSince(start) * 1000
            return ComponentHealth(
                component: componentName,
                healthy: true,
                status: "tests_passing",
                latencyMs: latency
            )
        } catch {
            let latency = Date().timeIntervalSince(start) * 1000
            return ComponentHealth(
                component: componentName,
                healthy: false,
                status: "tests_failing",
                latencyMs: latency,
                errorMessage: String(describing: error)
            )
        }
    }
}
