import Foundation

/// Represents the three usage limit categories matching the official Claude usage page
struct PlanUsageLimits {
    let session: UsageLimitInfo
    let weeklyAllModels: UsageLimitInfo
    let weeklySonnetOnly: UsageLimitInfo
    let extraUsage: ExtraUsageLimitInfo
}

/// A single limit bar's data
struct UsageLimitInfo {
    let label: String
    let estimatedCost: Decimal
    let budget: Decimal
    let resetDescription: String
    let resetDate: Date

    /// Usage fraction (0.0+)
    var usageFraction: Double {
        guard budget > 0 else { return 0 }
        return Double(truncating: (estimatedCost / budget) as NSDecimalNumber)
    }

    /// Usage percentage clamped for display
    var usagePercent: Int {
        min(Int(usageFraction * 100), 999)
    }
}

/// Extra usage limit info (monthly)
struct ExtraUsageLimitInfo {
    let spent: Decimal
    let monthlyLimit: Decimal
    let resetDate: Date

    var usageFraction: Double {
        guard monthlyLimit > 0 else { return 0 }
        return Double(truncating: (spent / monthlyLimit) as NSDecimalNumber)
    }

    var usagePercent: Int {
        min(Int(usageFraction * 100), 999)
    }
}
