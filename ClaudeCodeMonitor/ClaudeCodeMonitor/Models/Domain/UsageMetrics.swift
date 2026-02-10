import Foundation

/// Domain model for usage metrics
struct UsageMetrics {
    let timestamp: Date
    let tokenBreakdown: TokenBreakdown
    let estimatedCost: Decimal
    let modelBreakdown: [String: TokenBreakdown]
}

/// Session data from local JSONL files
struct SessionData {
    let date: Date
    let sessionCount: Int
    let projectCount: Int
}
