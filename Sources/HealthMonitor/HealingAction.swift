import Foundation
import OrbStack

// MARK: - Built-in Healing Actions

public struct RestartContainerAction: HealingAction {
    public let name = "RestartContainer"
    
    public init() {}
    
    public func canHeal(_ health: ComponentHealth) -> Bool {
        return !health.healthy && health.component.starts(with: "container:")
    }
    
    public func execute(target: String, orbStack: OrbStackManager) async throws -> Bool {
        let containerName = target
        do {
            try await orbStack.stopContainer(name: containerName)
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s grace
            try await orbStack.startContainer(name: containerName)
            return true
        } catch {
            return false
        }
    }
}

public struct RebuildContainerAction: HealingAction {
    public let name = "RebuildContainer"
    
    public init() {}
    
    public func canHeal(_ health: ComponentHealth) -> Bool {
        return !health.healthy && health.component.starts(with: "container:")
    }
    
    public func execute(target: String, orbStack: OrbStackManager) async throws -> Bool {
        let containerName = target
        do {
            try await orbStack.removeContainer(name: containerName, force: true)
            // Re-creation is outside scope here; caller handles re-create via config
            return true
        } catch {
            return false
        }
    }
}

public struct ClearCacheAction: HealingAction {
    public let name = "ClearCache"
    
    public init() {}
    
    public func canHeal(_ health: ComponentHealth) -> Bool {
        guard let error = health.errorMessage else { return false }
        return !health.healthy && (
            error.contains("ENOSPC") ||
            error.contains("no space") ||
            error.contains("disk full")
        )
    }
    
    public func execute(target: String, orbStack: OrbStackManager) async throws -> Bool {
        let containerName = target
        _ = try await orbStack.execInContainer(
            name: containerName,
            command: ["sh", "-c", "rm -rf /tmp/* /var/cache/* 2>/dev/null; echo cleared"]
        )
        return true
    }
}

public struct DependencyHealAction: HealingAction {
    public let name = "DependencyHeal"
    
    public init() {}
    
    public func canHeal(_ health: ComponentHealth) -> Bool {
        guard let error = health.errorMessage else { return false }
        return !health.healthy && (
            error.contains("module not found") ||
            error.contains("cannot find") ||
            error.contains("missing dependency") ||
            error.contains("package not found")
        )
    }
    
    public func execute(target: String, orbStack: OrbStackManager) async throws -> Bool {
        let containerName = target
        let commands = [
            ["npm", "install"],
            ["yarn", "install"],
            ["pip", "install", "-r", "requirements.txt"],
            ["bundle", "install"],
            ["go", "mod", "download"],
            ["swift", "package", "resolve"]
        ]
        for cmd in commands {
            do {
                _ = try await orbStack.execInContainer(
                    name: containerName,
                    command: ["sh", "-c", cmd.joined(separator: " ")]
                )
                return true
            } catch {
                continue
            }
        }
        return false
    }
}
