import Foundation

public final class OrbStackManager {
    private let dockerCommand: String
    
    public init(dockerCommand: String = "docker") {
        self.dockerCommand = dockerCommand
    }
    
    // MARK: - Container Lifecycle
    
    public func createContainer(config: ContainerConfig) async throws -> String {
        var args = ["run", "-d", "--name", config.name, "-w", config.workingDir]
        
        // Add environment variables
        for (key, value) in config.environment {
            args.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        
        // Add port mappings
        for (host, container) in config.ports {
            args.append(contentsOf: ["-p", "\(host):\(container)"])
        }
        
        // Add volume mounts
        for (host, container) in config.volumes {
            args.append(contentsOf: ["-v", "\(host):\(container)"])
        }
        
        args.append(config.image)
        
        let output = try await runCommand(args)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func startContainer(name: String) async throws {
        _ = try await runCommand(["start", name])
    }
    
    public func stopContainer(name: String) async throws {
        _ = try await runCommand(["stop", name])
    }
    
    public func removeContainer(name: String, force: Bool = false) async throws {
        var args = ["rm"]
        if force {
            args.append("-f")
        }
        args.append(name)
        _ = try await runCommand(args)
    }
    
    public func getContainerStatus(name: String) async throws -> ContainerStatus? {
        let output = try await runCommand([
            "ps", "-a", "--filter", "name=\(name)",
            "--format", "{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}"
        ])
        
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n")
        guard let line = lines.first else { return nil }
        
        let parts = line.split(separator: "|")
        guard parts.count == 4 else { return nil }
        
        return ContainerStatus(
            id: String(parts[0]),
            name: String(parts[1]),
            state: String(parts[2]),
            status: String(parts[3])
        )
    }
    
    public func listContainers() async throws -> [ContainerStatus] {
        let output = try await runCommand([
            "ps", "-a", "--format", "{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}"
        ])
        
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n")
        return lines.compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count == 4 else { return nil }
            return ContainerStatus(
                id: String(parts[0]),
                name: String(parts[1]),
                state: String(parts[2]),
                status: String(parts[3])
            )
        }
    }
    
    // MARK: - Execute Commands in Container
    
    public func execInContainer(name: String, command: [String]) async throws -> String {
        var args = ["exec", name]
        args.append(contentsOf: command)
        return try await runCommand(args)
    }
    
    public func copyToContainer(name: String, source: String, destination: String) async throws {
        _ = try await runCommand(["cp", source, "\(name):\(destination)"])
    }
    
    public func copyFromContainer(name: String, source: String, destination: String) async throws {
        _ = try await runCommand(["cp", "\(name):\(source)", destination])
    }
    
    // MARK: - OrbStack Specific
    
    public func verifyOrbStack() async throws -> Bool {
        do {
            let output = try await runCommand(["--version"])
            return output.contains("OrbStack") || output.contains("Docker")
        } catch {
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func runCommand(_ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [dockerCommand] + args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw OrbStackError.commandFailed(
                command: "\(dockerCommand) \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                error: error
            )
        }
        
        return output
    }
    
    public enum OrbStackError: Error, LocalizedError {
        case commandFailed(command: String, exitCode: Int32, error: String)
        case containerNotFound(String)
        
        public var errorDescription: String? {
            switch self {
            case .commandFailed(let command, let exitCode, let error):
                return "Command failed: \(command) (exit code: \(exitCode))\n\(error)"
            case .containerNotFound(let name):
                return "Container not found: \(name)"
            }
        }
    }
}
