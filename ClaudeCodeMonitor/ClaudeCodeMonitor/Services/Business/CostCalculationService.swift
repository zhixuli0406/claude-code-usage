import Foundation

/// Model pricing structure (per million tokens)
/// Cache pricing uses 5-minute TTL (Claude Code default):
///   - Cache write = 1.25 × input price
///   - Cache read  = 0.1  × input price
struct ModelPricing {
    let inputPerMTok: Decimal
    let outputPerMTok: Decimal
    let cacheWritePerMTok: Decimal
    let cacheReadPerMTok: Decimal
}

/// Service for calculating API costs (= Extra Usage rates for paid plans)
/// Pricing source: https://platform.claude.com/docs/en/about-claude/pricing
@available(macOS 14.0, *)
final class CostCalculationService {
    // Official API pricing as of February 2026 (per million tokens)
    // Extra usage for Pro/Max plans is billed at these same standard API rates
    private let pricingTable: [String: ModelPricing] = [
        // Opus 4.6 — $5 input, $25 output
        "claude-opus-4-6": ModelPricing(
            inputPerMTok: 5.00,
            outputPerMTok: 25.00,
            cacheWritePerMTok: 6.25,    // 5 × 1.25
            cacheReadPerMTok: 0.50      // 5 × 0.1
        ),
        // Opus 4.5 — $5 input, $25 output
        "claude-opus-4-5": ModelPricing(
            inputPerMTok: 5.00,
            outputPerMTok: 25.00,
            cacheWritePerMTok: 6.25,
            cacheReadPerMTok: 0.50
        ),
        // Opus 4.1 — $15 input, $75 output (legacy tier)
        "claude-opus-4-1": ModelPricing(
            inputPerMTok: 15.00,
            outputPerMTok: 75.00,
            cacheWritePerMTok: 18.75,   // 15 × 1.25
            cacheReadPerMTok: 1.50      // 15 × 0.1
        ),
        // Opus 4 — $15 input, $75 output (legacy tier)
        "claude-opus-4": ModelPricing(
            inputPerMTok: 15.00,
            outputPerMTok: 75.00,
            cacheWritePerMTok: 18.75,
            cacheReadPerMTok: 1.50
        ),
        // Sonnet 4.5 — $3 input, $15 output
        "claude-sonnet-4-5": ModelPricing(
            inputPerMTok: 3.00,
            outputPerMTok: 15.00,
            cacheWritePerMTok: 3.75,    // 3 × 1.25
            cacheReadPerMTok: 0.30      // 3 × 0.1
        ),
        // Sonnet 4 — $3 input, $15 output
        "claude-sonnet-4": ModelPricing(
            inputPerMTok: 3.00,
            outputPerMTok: 15.00,
            cacheWritePerMTok: 3.75,
            cacheReadPerMTok: 0.30
        ),
        // Haiku 4.5 — $1 input, $5 output
        "claude-haiku-4-5": ModelPricing(
            inputPerMTok: 1.00,
            outputPerMTok: 5.00,
            cacheWritePerMTok: 1.25,    // 1 × 1.25
            cacheReadPerMTok: 0.10      // 1 × 0.1
        ),
        // Haiku 3.5 — $0.80 input, $4 output (legacy)
        "claude-haiku-3-5": ModelPricing(
            inputPerMTok: 0.80,
            outputPerMTok: 4.00,
            cacheWritePerMTok: 1.00,    // 0.80 × 1.25
            cacheReadPerMTok: 0.08      // 0.80 × 0.1
        ),
    ]

    /// Resolve pricing for a model name with multi-level fallback:
    /// 1. Exact match  2. Prefix match  3. Keyword match  4. Default Sonnet 4.5
    private func resolvePricing(for model: String) -> ModelPricing {
        if let exact = pricingTable[model] {
            return exact
        }
        // Prefix match for model variants (e.g. "claude-opus-4-6-fast")
        for (key, pricing) in pricingTable where model.hasPrefix(key) {
            return pricing
        }
        // Keyword-based fallback (matching reference repo logic)
        let lowercased = model.lowercased()
        if lowercased.contains("opus") {
            return pricingTable["claude-opus-4-6"]!
        }
        if lowercased.contains("haiku") {
            return pricingTable["claude-haiku-4-5"]!
        }
        // Default to Sonnet 4.5 for all other unknown models
        return pricingTable["claude-sonnet-4-5"]!
    }

    // MARK: - Usage Weight Pricing
    // Anthropic's plan usage limits are calculated using internal compute costs,
    // which differ from public API pricing. Opus 4.5+ API price was reduced from
    // $15/$75 to $5/$25, but plan usage still reflects the higher compute cost.
    // Reference: https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor
    private let usageWeightPricing: [String: ModelPricing] = [
        "claude-opus-4-6": ModelPricing(
            inputPerMTok: 15.00, outputPerMTok: 75.00,
            cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50
        ),
        "claude-opus-4-5": ModelPricing(
            inputPerMTok: 15.00, outputPerMTok: 75.00,
            cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50
        ),
    ]

    /// Resolve usage-weight pricing (for plan limit percentage calculation)
    private func resolveUsageWeightPricing(for model: String) -> ModelPricing {
        // Check usage weight overrides first
        if let exact = usageWeightPricing[model] {
            return exact
        }
        for (key, pricing) in usageWeightPricing where model.hasPrefix(key) {
            return pricing
        }
        let lowercased = model.lowercased()
        if lowercased.contains("opus") {
            return usageWeightPricing["claude-opus-4-6"]!
        }
        // For non-Opus models, API pricing ≈ compute cost
        return resolvePricing(for: model)
    }

    /// Calculate cost for given model and tokens
    func calculateCost(model: String, tokens: TokenBreakdown) -> Decimal {
        let pricing = resolvePricing(for: model)
        return computeCostWithPricing(pricing, tokens: tokens)
    }

    /// Calculate usage weight for plan limit percentages (uses internal compute cost rates)
    func calculateUsageWeight(model: String, tokens: TokenBreakdown) -> Decimal {
        let pricing = resolveUsageWeightPricing(for: model)
        return computeCostWithPricing(pricing, tokens: tokens)
    }

    private func computeCostWithPricing(_ pricing: ModelPricing, tokens: TokenBreakdown) -> Decimal {
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
