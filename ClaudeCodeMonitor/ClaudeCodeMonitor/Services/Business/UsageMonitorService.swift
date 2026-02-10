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

        // Session: user override > auto-detect from gaps > rolling 5h fallback
        let (sessionStart, sessionResetDate) = resolveSessionWindow(
            config: config, entries: weeklyResult.entries, now: now
        )
        let sessionEntries = weeklyResult.entries.filter { $0.timestamp >= sessionStart }
        // Use weighted cost (internal compute rates) for plan limit percentages
        let sessionWeightedCost = computeWeightedCostFromEntries(sessionEntries)

        // Resolve budgets: user override > plan default
        let sessionBudget = config.sessionBudgetOverride ?? plan.defaultSessionBudget
        let weeklyAllBudget = config.weeklyAllModelsBudgetOverride ?? plan.defaultWeeklyAllModelsBudget
        let weeklySonnetBudget = config.weeklySonnetBudgetOverride ?? plan.defaultWeeklySonnetBudget

        let sessionInfo = UsageLimitInfo(
            label: "目前工作階段",
            estimatedCost: sessionWeightedCost,
            budget: sessionBudget,
            resetDescription: formatSessionReset(sessionResetDate, from: now),
            resetDate: sessionResetDate
        )

        // Weekly all models (weighted cost)
        let weeklyAllWeightedCost = computeWeightedCostFromEntries(weeklyResult.entries)

        let weeklyAllInfo = UsageLimitInfo(
            label: "所有模型",
            estimatedCost: weeklyAllWeightedCost,
            budget: weeklyAllBudget,
            resetDescription: formatWeeklyReset(nextWeeklyReset),
            resetDate: nextWeeklyReset
        )

        // Weekly Sonnet only (no weighting needed — Sonnet compute cost ≈ API price)
        let sonnetEntries = weeklyResult.entries.filter { $0.model.contains("sonnet") }
        let sonnetCost = computeWeightedCostFromEntries(sonnetEntries)

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

    /// Compute weighted cost using internal compute rates (for plan usage limit percentages).
    /// Always calculates from tokens — ignores JSONL costUSD since those reflect API pricing.
    private func computeWeightedCostFromEntries(_ entries: [LocalUsageEntry]) -> Decimal {
        var modelBreakdown: [String: TokenBreakdown] = [:]
        for entry in entries {
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
        var total: Decimal = 0
        for (model, tokens) in modelBreakdown {
            total += costCalculationService.calculateUsageWeight(model: model, tokens: tokens)
        }
        return total
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

    /// Resolve session window: user override > auto-detect from gaps > rolling 5h fallback
    private func resolveSessionWindow(
        config: AppConfiguration,
        entries: [LocalUsageEntry],
        now: Date
    ) -> (start: Date, reset: Date) {
        // 1. User-configured reset date
        if let configuredReset = config.sessionResetDate, configuredReset > now {
            return (configuredReset.addingTimeInterval(-5 * 3600), configuredReset)
        }
        // 2. Auto-detect session start from entry gaps (>= 5h gap = new session)
        if let detectedStart = detectSessionStart(from: entries, now: now) {
            let detectedReset = detectedStart.addingTimeInterval(5 * 3600)
            if detectedReset > now {
                return (detectedStart, detectedReset)
            }
        }
        // 3. Fallback: rolling 5h window
        return (now.addingTimeInterval(-5 * 3600), now.addingTimeInterval(5 * 3600))
    }

    /// Detect the start of the current session by walking entries forward and finding gaps >= 5h.
    /// Returns the timestamp of the first entry in the most recent session block, or nil if no entries.
    private func detectSessionStart(from entries: [LocalUsageEntry], now: Date) -> Date? {
        // Only consider entries from the last 10 hours (enough for one full session + gap)
        let cutoff = now.addingTimeInterval(-10 * 3600)
        let recent = entries.filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
        guard !recent.isEmpty else { return nil }

        var sessionStart = recent[0].timestamp
        for i in 1..<recent.count {
            let gap = recent[i].timestamp.timeIntervalSince(recent[i - 1].timestamp)
            if gap >= 5 * 3600 {
                // Gap >= 5h means a new session started at this entry
                sessionStart = recent[i].timestamp
            }
        }
        return sessionStart
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
