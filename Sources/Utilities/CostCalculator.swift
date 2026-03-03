import Foundation

struct CostCalculator {
    struct ModelPricing {
        let inputPerMToken: Double
        let outputPerMToken: Double
    }

    static let pricing: [String: ModelPricing] = [
        // Claude models
        "claude-opus-4-6":   ModelPricing(inputPerMToken: 15.0,  outputPerMToken: 75.0),
        "claude-sonnet-4-6": ModelPricing(inputPerMToken: 3.0,   outputPerMToken: 15.0),
        "claude-haiku-4-5":  ModelPricing(inputPerMToken: 0.80,  outputPerMToken: 4.0),
        // Gemini models (Phase 2)
        "gemini-2.0-flash":  ModelPricing(inputPerMToken: 0.10,  outputPerMToken: 0.40),
        "gemini-2.5-pro":    ModelPricing(inputPerMToken: 1.25,  outputPerMToken: 10.0),
    ]

    static func estimate(model: String, inputTokens: Int, outputTokens: Int) -> Double {
        // Try exact match first, then prefix match
        let price = pricing[model] ?? pricing.first { model.hasPrefix($0.key) }?.value

        guard let price else {
            // Default to Sonnet pricing if model unknown
            return estimate(model: "claude-sonnet-4-6", inputTokens: inputTokens, outputTokens: outputTokens)
        }

        let inputCost = Double(inputTokens) / 1_000_000 * price.inputPerMToken
        let outputCost = Double(outputTokens) / 1_000_000 * price.outputPerMToken
        return inputCost + outputCost
    }

    static func format(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}
