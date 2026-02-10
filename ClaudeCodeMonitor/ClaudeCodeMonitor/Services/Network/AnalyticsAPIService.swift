import Foundation

/// Service for Claude Code Analytics API
@available(macOS 14.0, *)
final class AnalyticsAPIService {
    private let apiClient: AnthropicAPIClient

    init(apiClient: AnthropicAPIClient) {
        self.apiClient = apiClient
    }

    /// Fetch daily analytics for a specific date
    @available(iOS 13.0.0, *)
    func fetchDailyAnalytics(date: Date, limit: Int = 100) async throws -> AnalyticsResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let parameters: [String: String] = [
            "date": formatter.string(from: date),
            "limit": "\(limit)"
        ]

        return try await apiClient.request(
            endpoint: "/organizations/usage_report/claude_code",
            method: .get,
            parameters: parameters
        )
    }

    /// Fetch analytics for a date range
    @available(iOS 13.0.0, *)
    func fetchAnalyticsRange(
        startDate: Date,
        endDate: Date
    ) async throws -> [AnalyticsResponse] {
        var responses: [AnalyticsResponse] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let response = try await fetchDailyAnalytics(date: currentDate)
            responses.append(response)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return responses
    }
}
