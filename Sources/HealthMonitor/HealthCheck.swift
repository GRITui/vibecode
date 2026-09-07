import Foundation
import OrbStack
import SelfHeal

// MARK: - Health Check Models

public struct HealthStatus: Codable {
    public let timestamp: Date
    public let overallHealthy: Bool
    public let checks: [ComponentHealth]
    public let healingActions: [HealingActionRecord]
    
    public init(
        timestamp: Date = Date(),
        overallHealthy: Bool,
        checks: [ComponentHealth],
        healingActions: [HealingActionRecord] = []
    ) {
        self.timestamp = timestamp
        self.overallHealthy = overallHealthy
        self.checks = checks
        self.healingActions = healingActions
    }
}

public struct ComponentHealth: Codable {
    public let component: String
    public let healthy: Bool
    public let status: String
    public let latencyMs: Double
    public let errorMessage: String?
    
    public init(
        component: String,
        healthy: Bool,
        status: String,
        latencyMs: Double,
        errorMessage: String? = nil
    ) {
        self.component = component
        self.healthy = healthy
        self.status = status
        self.latencyMs = latencyMs
        self.errorMessage = errorMessage
    }
}

public struct HealingActionRecord: Codable {
    public let timestamp: Date
    public let action: String
    public let target: String
    public let success: Bool
    public let errorMessage: String?
    
    public init(
        timestamp: Date = Date(),
        action: String,
        target: String,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.timestamp = timestamp
        self.action = action
        self.target = target
        self.success = success
        self.errorMessage = errorMessage
    }
}

// MARK: - Health Check Protocol

public protocol HealthCheck {
    var componentName: String { get }
    func performCheck() async -> ComponentHealth
}

public protocol HealingAction {
    var name: String { get }
    func canHeal(_ health: ComponentHealth) -> Bool
    func execute(target: String, orbStack: OrbStackManager) async throws -> Bool
}
