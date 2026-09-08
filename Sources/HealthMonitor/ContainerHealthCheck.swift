import Foundation
import OrbStack

public struct ContainerHealthCheck: HealthCheck {
    public let componentName: String
    private let containerName: String
    private let orbStack: any ContainerRuntime

    public init(containerName: String, orbStack: any ContainerRuntime) {
        self.containerName = containerName
        self.componentName = "container:\(containerName)"
        self.orbStack = orbStack
    }
    
    public func performCheck() async -> ComponentHealth {
        let start = Date()
        do {
            let status = try await orbStack.getContainerStatus(name: containerName)
            let latency = Date().timeIntervalSince(start) * 1000
            if let status = status {
                let healthy = status.state == "running"
                return ComponentHealth(
                    component: componentName,
                    healthy: healthy,
                    status: status.state,
                    latencyMs: latency,
                    errorMessage: healthy ? nil : "Container state: \(status.state)"
                )
            } else {
                return ComponentHealth(
                    component: componentName,
                    healthy: false,
                    status: "not_found",
                    latencyMs: latency,
                    errorMessage: "Container not found"
                )
            }
        } catch {
            let latency = Date().timeIntervalSince(start) * 1000
            return ComponentHealth(
                component: componentName,
                healthy: false,
                status: "error",
                latencyMs: latency,
                errorMessage: String(describing: error)
            )
        }
    }
}
