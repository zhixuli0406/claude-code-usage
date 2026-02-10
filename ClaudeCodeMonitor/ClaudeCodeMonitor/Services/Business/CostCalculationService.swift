import Foundation

/// Model pricing structure
struct ModelPricing {
    let inputPerMTok: Decimal  // Per million tokens
    let outputPerMTok: Decimal
    let cacheWritePerMTok: Decimal
    let cacheReadPerMTok: Decimal
}

/// Service for calculating API costs
@available(macOS 14.0, *)
final class CostCalculationService {
    // Pricing as of February 2026 (per million tokens)
    private let pricingTable: [String: ModelPricing] = [
        "claude-opus-4-6": ModelPricing(
            inputPerMTok: 15.00,
            outputPerMTok: 75.00,
            cacheWritePerMTok: 18.75,
            cacheReadPerMTok: 1.50
        ),
        "claude-sonnet-4-5": ModelPricing(
            inputPerMTok: 3.00,
            outputPerMTok: 15.00,
            cacheWritePerMTok: 3.75,
            cacheReadPerMTok: 0.30
        ),
        "claude-haiku-4-5": ModelPricing(
            inputPerMTok: 0.80,
            outputPerMTok: 4.00,
            cacheWritePerMTok: 1.00,
            cacheReadPerMTok: 0.08
        )
    ]

    /// Calculate cost for given model and tokens
    func calculateCost(model: String, tokens: TokenBreakdown) -> Decimal {
        guard let pricing = pricingTable[model] else {
            // Unknown model - use average pricing
            return calculateCost(model: "claude-sonnet-4-5", tokens: tokens)
        }

        let inputCost = Decimal(tokens.uncachedInput) * pricing.inputPerMTok / 1_000_000
        let outputCost = Decimal(tokens.output) * pricing.outputPerMTok / 1_000_000
        let cacheWriteCost = Decimal(tokens.cacheCreation) * pricing.cacheWritePerMTok / 1_000_000
        let cacheReadCost = Decimal(tokens.cachedInput) * pricing.cacheReadPerMTok / 1_000_000

        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    /// Calculate total cost from usage metrics
    func calculateTotalCost(metrics: UsageMetrics) -> Decimal {
        var totalCost: Decimal = 0

        for (model, breakdown) in metrics.modelBreakdown {
            totalCost += calculateCost(model: model, tokens: breakdown)
        }

        return totalCost
    }

    /// Estimate monthly cost based on recent usage
    func estimateMonthlyBurn(dailyCost: Decimal) -> Decimal {
        return dailyCost * 30
    }
}
