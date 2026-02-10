import Foundation

/// Service for Usage API (/v1/organizations/usage_report/messages)
@available(macOS 14.0, *)
final class UsageAPIService {
    private let apiClient: AnthropicAPIClient

    init(apiClient: AnthropicAPIClient) {
        self.apiClient = apiClient
    }

    /// Fetch realtime usage (last 5 minutes)
    func fetchRealtimeUsage(
        startingAt: Date? = nil,
        endingAt: Date? = nil,
        bucketWidth: TimeGranularity = .oneMinute
    ) async throws -> UsageReportResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let end = endingAt ?? Date()
        let start = startingAt ?? end.addingTimeInterval(-300)  // 5 minutes ago

        let parameters: [String: String] = [
            "starting_at": formatter.string(from: start),
            "ending_at": formatter.string(from: end),
            "bucket_width": bucketWidth.rawValue,
            "group_by[]": "model"  // Group by model for breakdown
        ]

        return try await apiClient.request(
            endpoint: "/organizations/usage_report/messages",
            method: .get,
            parameters: parameters
        )
    }

    /// Fetch historical usage
    func fetchHistoricalUsage(
        startingAt: Date,
        endingAt: Date,
        bucketWidth: TimeGranularity,
        groupBy: [String] = ["model"]
    ) async throws -> UsageReportResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var parameters: [String: String] = [
            "starting_at": formatter.string(from: startingAt),
            "ending_at": formatter.string(from: endingAt),
            "bucket_width": bucketWidth.rawValue
        ]

        // Add group_by parameters
        for (index, group) in groupBy.enumerated() {
            parameters["group_by[\(index)]"] = group
        }

        return try await apiClient.request(
            endpoint: "/organizations/usage_report/messages",
            method: .get,
            parameters: parameters
        )
    }
}
