import Foundation
import Observation

/// Service for orchestrating usage monitoring via local JSONL files
@Observable
final class UsageMonitorService {
    private let localUsageService: LocalUsageService
    private let costCalculationService: CostCalculationService
    private let userDefaultsService: UserDefaultsService

    var currentUsage: UsageMetrics?
    var sessionHistory: [SessionData] = []
    var planUsageLimits: PlanUsageLimits?
    var isLoading = false
    var lastError: AppError?

    init(
        localUsageService: LocalUsageService,
        costCalculationService: CostCalculationService,
        userDefaultsService: UserDefaultsService
    ) {
        self.localUsageService = localUsageService
        self.costCalculationService = costCalculationService
        self.userDefaultsService = userDefaultsService
    }

    /// Refresh all data from local JSONL files
    @MainActor
    func refreshAllData() async {
        isLoading = true
        lastError = nil

        // Read today's usage from local files
        let todayResult = localUsageService.fetchTodayUsage()

        // Calculate cost: prefer JSONL costUSD, fall back to token-based calculation
        let totalCost = computeCostFromEntries(todayResult.entries)

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

        // Compute plan usage limits
        let config = userDefaultsService.loadConfiguration()
        planUsageLimits = computePlanUsageLimits(config: config)

        isLoading = false
    }

    /// Load cached data (initial read from local files)
    func loadCachedData() {
        let todayResult = localUsageService.fetchTodayUsage()

        // Calculate cost: prefer JSONL costUSD, fall back to token-based calculation
        let totalCost = computeCostFromEntries(todayResult.entries)

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

        let config = userDefaultsService.loadConfiguration()
        planUsageLimits = computePlanUsageLimits(config: config)
    }

    // MARK: - Plan Usage Limits

    private func computePlanUsageLimits(config: AppConfiguration) -> PlanUsageLimits {
        let now = Date()
        let plan = config.subscriptionPlan

        // Weekly window (widest range, fetch once)
        let weeklyStart = computeWeeklyStart(
            from: now,
            dayOfWeek: config.weeklyResetDayOfWeek,
            hour: config.weeklyResetHour
        )
        let weeklyResult = localUsageService.fetchUsage(from: weeklyStart, to: now)
        let nextWeeklyReset = weeklyStart.addingTimeInterval(7 * 24 * 3600)

        // Session: use configured reset date if valid, otherwise fall back to rolling 5h window
        let sessionResetDate: Date
        let sessionStart: Date
        if let configuredReset = config.sessionResetDate, configuredReset > now {
            // User has set a valid future reset date
            sessionResetDate = configuredReset
            sessionStart = configuredReset.addingTimeInterval(-5 * 3600)
        } else {
            // No configured date or expired: use rolling 5h window
            sessionStart = now.addingTimeInterval(-5 * 3600)
            sessionResetDate = now.addingTimeInterval(5 * 3600)
        }
        let sessionEntries = weeklyResult.entries.filter { $0.timestamp >= sessionStart }
        let sessionCost = computeCostFromEntries(sessionEntries)

        // Resolve budgets: user override > plan default
        let sessionBudget = config.sessionBudgetOverride ?? plan.defaultSessionBudget
        let weeklyAllBudget = config.weeklyAllModelsBudgetOverride ?? plan.defaultWeeklyAllModelsBudget
        let weeklySonnetBudget = config.weeklySonnetBudgetOverride ?? plan.defaultWeeklySonnetBudget

        let sessionInfo = UsageLimitInfo(
            label: "目前工作階段",
            estimatedCost: sessionCost,
            budget: sessionBudget,
            resetDescription: formatSessionReset(sessionResetDate, from: now),
            resetDate: sessionResetDate
        )

        // Weekly all models
        let weeklyAllCost = computeCost(from: weeklyResult)

        let weeklyAllInfo = UsageLimitInfo(
            label: "所有模型",
            estimatedCost: weeklyAllCost,
            budget: weeklyAllBudget,
            resetDescription: formatWeeklyReset(nextWeeklyReset),
            resetDate: nextWeeklyReset
        )

        // Weekly Sonnet only
        let sonnetEntries = weeklyResult.entries.filter { $0.model.contains("sonnet") }
        let sonnetCost = computeCostFromEntries(sonnetEntries)

        let weeklySonnetInfo = UsageLimitInfo(
            label: "僅 Sonnet",
            estimatedCost: sonnetCost,
            budget: weeklySonnetBudget,
            resetDescription: formatWeeklyReset(nextWeeklyReset),
            resetDate: nextWeeklyReset
        )

        // Extra usage (monthly)
        let monthStart = computeMonthStart(from: now)
        let monthResult = localUsageService.fetchUsage(from: monthStart, to: now)
        let monthCost = computeCost(from: monthResult)
        let daysElapsed = max(1, Calendar.current.dateComponents([.day], from: monthStart, to: now).day ?? 1)
        let monthBudget = plan.estimatedDailyBudget * Decimal(daysElapsed)
        let extraSpent = max(0, monthCost - monthBudget)
        let nextMonthReset = computeNextMonthStart(from: now)

        let extraInfo = ExtraUsageLimitInfo(
            spent: extraSpent,
            monthlyLimit: config.monthlySpendingLimit,
            resetDate: nextMonthReset
        )

        return PlanUsageLimits(
            session: sessionInfo,
            weeklyAllModels: weeklyAllInfo,
            weeklySonnetOnly: weeklySonnetInfo,
            extraUsage: extraInfo
        )
    }

    // MARK: - Helpers

    private func computeCost(from result: LocalUsageResult) -> Decimal {
        return computeCostFromEntries(result.entries)
    }

    private func computeCostFromEntries(_ entries: [LocalUsageEntry]) -> Decimal {
        // Prefer pre-computed costUSD from JSONL when available (most accurate),
        // fall back to token-based calculation per model
        var cachedCostTotal: Decimal = 0
        var uncachedEntries: [LocalUsageEntry] = []

        for entry in entries {
            if let cost = entry.costUSD {
                cachedCostTotal += cost
            } else {
                uncachedEntries.append(entry)
            }
        }

        // Calculate cost for entries without pre-computed cost
        var modelBreakdown: [String: TokenBreakdown] = [:]
        for entry in uncachedEntries {
            let existing = modelBreakdown[entry.model] ?? TokenBreakdown(
                uncachedInput: 0, cachedInput: 0, cacheCreation: 0, output: 0
            )
            modelBreakdown[entry.model] = TokenBreakdown(
                uncachedInput: existing.uncachedInput + entry.inputTokens,
                cachedInput: existing.cachedInput + entry.cacheReadInputTokens,
                cacheCreation: existing.cacheCreation + entry.cacheCreationInputTokens,
                output: existing.output + entry.outputTokens
            )
        }
        var calculatedTotal: Decimal = 0
        for (model, tokens) in modelBreakdown {
            calculatedTotal += costCalculationService.calculateCost(model: model, tokens: tokens)
        }
        return cachedCostTotal + calculatedTotal
    }

    private func computeWeeklyStart(from date: Date, dayOfWeek: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        var targetComponents = DateComponents()
        targetComponents.weekday = dayOfWeek
        targetComponents.hour = hour
        targetComponents.minute = 0
        targetComponents.second = 0

        if let candidate = calendar.nextDate(
            after: date,
            matching: targetComponents,
            matchingPolicy: .nextTime,
            direction: .backward
        ) {
            return candidate
        }
        return date.addingTimeInterval(-7 * 24 * 3600)
    }

    private func formatSessionReset(_ resetDate: Date, from now: Date) -> String {
        let remaining = resetDate.timeIntervalSince(now)
        if remaining <= 0 { return "5 小時 0 分後重設" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours) 小時 \(minutes) 分後重設"
    }

    private func formatWeeklyReset(_ resetDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-TW")
        formatter.dateFormat = "EEEE HH:00 重設"
        return formatter.string(from: resetDate)
    }

    private func computeMonthStart(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func computeNextMonthStart(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = calendar.dateComponents([.year, .month], from: date)
        components.month! += 1
        return calendar.date(from: components) ?? date
    }
}
