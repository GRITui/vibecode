import Foundation
import OrbStack

public struct DiskSpaceHealthCheck: HealthCheck {
    public let componentName = "system:disk"
    private let orbStack: any ContainerRuntime
    private let containerName: String?

    public init(containerName: String? = nil, orbStack: any ContainerRuntime) {
        self.containerName = containerName
        self.orbStack = orbStack
    }
    
    public func performCheck() async -> ComponentHealth {
        let start = Date()
        do {
            let latency = Date().timeIntervalSince(start) * 1000
            if let container = containerName {
                let command = ["sh", "-c", "df -h / | tail -1 | awk '{print $5}' | tr -d '%'"]
                let output = try await orbStack.execInContainer(name: container, command: command)
                let usage = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100
                let healthy = usage < 90
                return ComponentHealth(
                    component: componentName,
                    healthy: healthy,
                    status: "\(usage)% used",
                    latencyMs: latency,
                    errorMessage: healthy ? nil : "Disk usage at \(usage)%"
                )
            } else {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["df", "-h", "/"]
                let pipe = Pipe()
                process.standardOutput = pipe
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.split(separator: "\n")
                if lines.count > 1 {
                    let parts = lines[1].split(separator: " ").filter { !$0.isEmpty }
                    if parts.count > 4 {
                        let usageStr = String(parts[4]).trimmingCharacters(in: CharacterSet(charactersIn: "%"))
                        let usage = Int(usageStr) ?? 100
                        let healthy = usage < 90
                        return ComponentHealth(
                            component: componentName,
                            healthy: healthy,
                            status: "\(usage)% used",
                            latencyMs: latency,
                            errorMessage: healthy ? nil : "Disk usage at \(usage)%"
                        )
                    }
                }
                return ComponentHealth(
                    component: componentName,
                    healthy: false,
                    status: "unknown",
                    latencyMs: latency,
                    errorMessage: "Could not parse disk usage"
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
