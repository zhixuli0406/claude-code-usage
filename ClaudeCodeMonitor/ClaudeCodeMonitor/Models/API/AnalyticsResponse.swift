import Foundation

/// Response from Claude Code Analytics API
struct AnalyticsResponse: Codable {
    let data: [AnalyticsRecord]
    let hasMore: Bool?
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

/// Analytics record for a specific user/date
struct AnalyticsRecord: Codable {
    let date: Date
    let actor: Actor
    let organizationId: String
    let terminalType: String?
    let coreMetrics: CoreMetrics
    let toolActions: ToolActions
    let modelBreakdown: [ModelUsage]?

    enum CodingKeys: String, CodingKey {
        case date
        case actor
        case organizationId = "organization_id"
        case terminalType = "terminal_type"
        case coreMetrics = "core_metrics"
        case toolActions = "tool_actions"
        case modelBreakdown = "model_breakdown"
    }
}

/// Actor (user) information
struct Actor: Codable {
    let type: String
    let id: String
}

/// Core productivity metrics
struct CoreMetrics: Codable {
    let numSessions: Int
    let linesOfCode: LinesOfCode
    let commitsByClaude: Int
    let pullRequestsByClaude: Int

    enum CodingKeys: String, CodingKey {
        case numSessions = "num_sessions"
        case linesOfCode = "lines_of_code"
        case commitsByClaude = "commits_by_claude_code"
        case pullRequestsByClaude = "pull_requests_by_claude_code"
    }
}

/// Lines of code statistics
struct LinesOfCode: Codable {
    let added: Int
    let removed: Int

    var netChange: Int {
        added - removed
    }
}

/// Tool usage actions
struct ToolActions: Codable {
    let editTool: ToolMetric?
    let writeTool: ToolMetric?
    let multiEditTool: ToolMetric?
    let notebookEditTool: ToolMetric?

    enum CodingKeys: String, CodingKey {
        case editTool = "edit_tool"
        case writeTool = "write_tool"
        case multiEditTool = "multi_edit_tool"
        case notebookEditTool = "notebook_edit_tool"
    }

    /// Get all tools as an array
    var allTools: [(name: String, metric: ToolMetric)] {
        var tools: [(String, ToolMetric)] = []
        if let edit = editTool { tools.append(("Edit", edit)) }
        if let write = writeTool { tools.append(("Write", write)) }
        if let multiEdit = multiEditTool { tools.append(("MultiEdit", multiEdit)) }
        if let notebook = notebookEditTool { tools.append(("Notebook", notebook)) }
        return tools
    }
}

/// Tool acceptance/rejection metrics
struct ToolMetric: Codable {
    let accepted: Int
    let rejected: Int

    var total: Int {
        accepted + rejected
    }

    var acceptanceRate: Double {
        guard total > 0 else { return 0 }
        return Double(accepted) / Double(total)
    }
}

/// Model usage breakdown
struct ModelUsage: Codable {
    let model: String
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
