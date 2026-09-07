import Foundation

/// Central configuration for LLM providers and model fallback chain.
public struct LLMConfig {
    public let apiURL: URL?
    public let apiKey: String?
    public let primaryModel: String
    public let fallbackModels: [String]
    public let budgetWebhookURL: URL?
    public let monthlyBudgetUSD: Double

    public init(
        apiURL: URL? = nil,
        apiKey: String? = nil,
        primaryModel: String = "gpt-4o-mini",
        fallbackModels: [String] = [],
        budgetWebhookURL: URL? = nil,
        monthlyBudgetUSD: Double = 15.0
    ) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.primaryModel = primaryModel
        self.fallbackModels = fallbackModels
        self.budgetWebhookURL = budgetWebhookURL
        self.monthlyBudgetUSD = monthlyBudgetUSD
    }

    /// Loads configuration from environment variables.
    public static func fromEnvironment() -> LLMConfig {
        let apiURL = ProcessInfo.processInfo.environment["LITELLM_API_URL"].flatMap { URL(string: $0) }
        let apiKey = ProcessInfo.processInfo.environment["LITELLM_API_KEY"]
        let budgetWebhook = ProcessInfo.processInfo.environment["LITELLM_BUDGET_WEBHOOK_URL"].flatMap { URL(string: $0) }
        let budgetStr = ProcessInfo.processInfo.environment["LITELLM_MONTHLY_BUDGET_USD"] ?? "15.0"
        let budget = Double(budgetStr) ?? 15.0

        return LLMConfig(
            apiURL: apiURL,
            apiKey: apiKey,
            primaryModel: "gpt-4o-mini",
            fallbackModels: [
                "z-ai/glm-5.2:free",   // Issue #3 candidate
                "openai/gpt-4o-mini",
                "anthropic/claude-3-haiku"
            ],
            budgetWebhookURL: budgetWebhook,
            monthlyBudgetUSD: budget
        )
    }

    /// Returns the model to use, considering fallback chain.
    public func selectModel(attempt: Int = 0) -> String {
        let chain = [primaryModel] + fallbackModels
        let index = min(attempt, chain.count - 1)
        return chain[index]
    }
}

/// Registry for evaluating and tracking model capabilities.
public struct ModelRegistry {
    public static let shared = ModelRegistry()

    private var evaluations: [String: ModelEvaluation] = [:]

    public mutating func recordEvaluation(
        model: String,
        toolCallingReliable: Bool,
        latencyMs: Int,
        notes: String
    ) {
        evaluations[model] = ModelEvaluation(
            model: model,
            toolCallingReliable: toolCallingReliable,
            latencyMs: latencyMs,
            notes: notes,
            evaluatedAt: Date()
        )
    }

    public func evaluation(for model: String) -> ModelEvaluation? {
        evaluations[model]
    }

    public func recommendedPrimary() -> String? {
        evaluations
            .values
            .filter(\.toolCallingReliable)
            .min(by: { $0.latencyMs < $1.latencyMs })?
            .model
    }
}

public struct ModelEvaluation: Codable {
    public let model: String
    public let toolCallingReliable: Bool
    public let latencyMs: Int
    public let notes: String
    public let evaluatedAt: Date
}
