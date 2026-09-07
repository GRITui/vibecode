import Foundation
import OrbStack

public struct MemoryHealthCheck: HealthCheck {
    public let componentName = "system:memory"
    private let orbStack: OrbStackManager
    private let containerName: String?
    
    public init(containerName: String? = nil, orbStack: OrbStackManager) {
        self.containerName = containerName
        self.orbStack = orbStack
    }
    
    public func performCheck() async -> ComponentHealth {
        let start = Date()
        do {
            let latency = Date().timeIntervalSince(start) * 1000
            if let container = containerName {
                let output = try await orbStack.execInContainer(
                    name: container,
                    command: ["sh", "-c", "free | grep Mem | awk '{print int($3/$2 * 100.0)}'"]
                )
                let usage = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100
                let healthy = usage < 90
                return ComponentHealth(
                    component: componentName,
                    healthy: healthy,
                    status: "\(usage)% used",
                    latencyMs: latency,
                    errorMessage: healthy ? nil : "Memory usage at \(usage)%"
                )
            } else {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["vm_stat"]
                let pipe = Pipe()
                process.standardOutput = pipe
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.split(separator: "\n")
                var pageSize: UInt64 = 4096
                var freePages: UInt64 = 0
                var activePages: UInt64 = 0
                var inactivePages: UInt64 = 0
                var wiredPages: UInt64 = 0
                
                for line in lines {
                    if line.contains("page size of") {
                        let components = line.split(separator: " ")
                        if let idx = components.firstIndex(of: "bytes"), idx > 0 {
                            pageSize = UInt64(components[idx - 1]) ?? 4096
                        }
                    } else if line.contains("Pages free") {
                        let num = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        freePages = UInt64(num ?? "0") ?? 0
                    } else if line.contains("Pages active") {
                        let num = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        activePages = UInt64(num ?? "0") ?? 0
                    } else if line.contains("Pages inactive") {
                        let num = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        inactivePages = UInt64(num ?? "0") ?? 0
                    } else if line.contains("Pages wired down") {
                        let num = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        wiredPages = UInt64(num ?? "0") ?? 0
                    }
                }
                
                let totalPages = freePages + activePages + inactivePages + wiredPages
                let usedPages = activePages + inactivePages + wiredPages
                let usage = totalPages > 0 ? Int((usedPages * 100) / totalPages) : 0
                let healthy = usage < 90
                
                return ComponentHealth(
                    component: componentName,
                    healthy: healthy,
                    status: "\(usage)% used",
                    latencyMs: latency,
                    errorMessage: healthy ? nil : "Memory usage at \(usage)%"
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
