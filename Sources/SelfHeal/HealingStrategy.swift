import Foundation
import OrbStack

public protocol HealingStrategy {
    var name: String { get }
    func canHeal(testResult: TestResult) -> Bool
    func heal(testResult: TestResult, context: HealingContext) async throws -> Bool
}

public struct HealingContext {
    public let containerName: String
    public let workingDir: String
    public let orbStack: OrbStackManager
    
    public init(containerName: String, workingDir: String, orbStack: OrbStackManager) {
        self.containerName = containerName
        self.workingDir = workingDir
        self.orbStack = orbStack
    }
}

// MARK: - Built-in Strategies

public struct RetryStrategy: HealingStrategy {
    public let name = "Retry"
    public let maxRetries: Int
    
    public init(maxRetries: Int = 3) {
        self.maxRetries = maxRetries
    }
    
    public func canHeal(testResult: TestResult) -> Bool {
        return !testResult.passed
    }
    
    public func heal(testResult: TestResult, context: HealingContext) async throws -> Bool {
        // Simple retry - just run the test again
        // In a real implementation, you might add delays or other logic
        return false // Let other strategies handle it
    }
}

public struct DependencyInstallStrategy: HealingStrategy {
    public let name = "DependencyInstall"
    
    public func canHeal(testResult: TestResult) -> Bool {
        guard let error = testResult.errorMessage else { return false }
        return error.contains("module not found") ||
               error.contains("cannot find module") ||
               error.contains("No such file") ||
               error.contains("command not found")
    }
    
    public func heal(testResult: TestResult, context: HealingContext) async throws -> Bool {
        // Try to install dependencies
        let commands = [
            ["npm", "install"],
            ["yarn", "install"],
            ["pip", "install", "-r", "requirements.txt"],
            ["bundle", "install"]
        ]
        
        for command in commands {
            do {
                _ = try await context.orbStack.execInContainer(
                    name: context.containerName,
                    command: ["sh", "-c", command.joined(separator: " ")]
                )
                return true
            } catch {
                continue
            }
        }
        
        return false
    }
}

public struct SyntaxFixStrategy: HealingStrategy {
    public let name = "SyntaxFix"
    
    public func canHeal(testResult: TestResult) -> Bool {
        guard let error = testResult.errorMessage else { return false }
        return error.contains("SyntaxError") ||
               error.contains("unexpected token") ||
               error.contains("parse error")
    }
    
    public func heal(testResult: TestResult, context: HealingContext) async throws -> Bool {
        // In a real implementation, this would use AI to fix syntax errors
        // For now, just return false
        return false
    }
}
