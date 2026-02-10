import Foundation

/// Response from Usage API (/v1/organizations/usage_report/messages)
struct UsageReportResponse: Codable {
    let data: [UsageBucket]
    let hasMore: Bool?
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

/// Time bucket containing usage results
struct UsageBucket: Codable {
    let startTime: Date
    let endTime: Date
    let results: [UsageResult]

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case results
    }
}

/// Usage result for a specific model/workspace combination
struct UsageResult: Codable {
    let model: String?
    let workspaceId: String?
    let apiKeyId: String?
    let serviceTier: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case workspaceId = "workspace_id"
        case apiKeyId = "api_key_id"
        case serviceTier = "service_tier"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    /// Calculate total tokens
    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }
}

/// Token breakdown for presentation
struct TokenBreakdown {
    let uncachedInput: Int
    let cachedInput: Int
    let cacheCreation: Int
    let output: Int

    var total: Int {
        uncachedInput + cachedInput + cacheCreation + output
    }

    var cacheHitRate: Double {
        let totalInput = uncachedInput + cachedInput
        guard totalInput > 0 else { return 0 }
        return Double(cachedInput) / Double(totalInput)
    }
}
