import Foundation
import Observation

/// Service for orchestrating usage monitoring via local JSONL files
@Observable
final class UsageMonitorService {
    private let localUsageService: LocalUsageService
    private let costCalculationService: CostCalculationService

    var currentUsage: UsageMetrics?
    var sessionHistory: [SessionData] = []
    var isLoading = false
    var lastError: AppError?

    init(
        localUsageService: LocalUsageService,
        costCalculationService: CostCalculationService
    ) {
        self.localUsageService = localUsageService
        self.costCalculationService = costCalculationService
    }

    /// Refresh all data from local JSONL files
    @MainActor
    func refreshAllData() async {
        isLoading = true
        lastError = nil

        // Read today's usage from local files
        let todayResult = localUsageService.fetchTodayUsage()

        // Calculate cost per model
        var totalCost: Decimal = 0
        for (model, breakdown) in todayResult.modelBreakdown {
            totalCost += costCalculationService.calculateCost(model: model, tokens: breakdown)
        }

        // Build UsageMetrics
        let metrics = UsageMetrics(
            timestamp: Date(),
            tokenBreakdown: todayResult.totalBreakdown,
            estimatedCost: totalCost,
            modelBreakdown: todayResult.modelBreakdown
        )

        // Build SessionData
        let session = SessionData(
            date: Date(),
            sessionCount: todayResult.sessionCount,
            projectCount: todayResult.projectCount
        )

        // Update state
        currentUsage = metrics
        sessionHistory = [session]
        isLoading = false
    }

    /// Load cached data (initial read from local files)
    func loadCachedData() {
        let todayResult = localUsageService.fetchTodayUsage()

        var totalCost: Decimal = 0
        for (model, breakdown) in todayResult.modelBreakdown {
            totalCost += costCalculationService.calculateCost(model: model, tokens: breakdown)
        }

        currentUsage = UsageMetrics(
            timestamp: Date(),
            tokenBreakdown: todayResult.totalBreakdown,
            estimatedCost: totalCost,
            modelBreakdown: todayResult.modelBreakdown
        )

        sessionHistory = [SessionData(
            date: Date(),
            sessionCount: todayResult.sessionCount,
            projectCount: todayResult.projectCount
        )]
    }
}
