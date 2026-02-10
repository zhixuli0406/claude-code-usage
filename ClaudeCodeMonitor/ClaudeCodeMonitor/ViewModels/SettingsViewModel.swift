import Foundation
import Observation

/// ViewModel for Settings window
@Observable
@MainActor
final class SettingsViewModel {
    private let userDefaultsService: UserDefaultsService
    private let launchAtLoginService = LaunchAtLoginService()

    var refreshInterval: TimeInterval = 60.0
    var showNotifications: Bool = true
    var launchAtLogin: Bool = false
    var selectedTimeGranularity: TimeGranularity = .oneMinute
    var monthlySpendingLimit: Decimal = 20.0
    var subscriptionPlan: SubscriptionPlan = .pro
    var weeklyResetDayOfWeek: Int = 3
    var weeklyResetHour: Int = 8
    var sessionBudgetText: String = ""
    var weeklyAllModelsBudgetText: String = ""
    var weeklySonnetBudgetText: String = ""

    var errorMessage: String?
    var showError = false
    var saveSuccess = false

    init(userDefaultsService: UserDefaultsService) {
        self.userDefaultsService = userDefaultsService
        loadSettings()
    }

    /// Load settings from storage
    func loadSettings() {
        let config = userDefaultsService.loadConfiguration()
        refreshInterval = config.refreshInterval
        showNotifications = config.showNotifications
        launchAtLogin = launchAtLoginService.isEnabled
        selectedTimeGranularity = config.selectedTimeGranularity
        monthlySpendingLimit = config.monthlySpendingLimit
        subscriptionPlan = config.subscriptionPlan
        weeklyResetDayOfWeek = config.weeklyResetDayOfWeek
        weeklyResetHour = config.weeklyResetHour
        sessionBudgetText = config.sessionBudgetOverride.map { formatBudget($0) } ?? ""
        weeklyAllModelsBudgetText = config.weeklyAllModelsBudgetOverride.map { formatBudget($0) } ?? ""
        weeklySonnetBudgetText = config.weeklySonnetBudgetOverride.map { formatBudget($0) } ?? ""
    }

    private func formatBudget(_ value: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: value)
        return NumberFormatter.localizedString(from: nsNumber, number: .decimal)
    }

    private func parseBudget(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Decimal(string: trimmed)
    }

    /// Save settings
    func saveSettings() {
        do {
            // Save launch at login
            try launchAtLoginService.setEnabled(launchAtLogin)

            // Save configuration
            var config = AppConfiguration()
            config.refreshInterval = refreshInterval
            config.showNotifications = showNotifications
            config.launchAtLogin = launchAtLogin
            config.selectedTimeGranularity = selectedTimeGranularity
            config.monthlySpendingLimit = monthlySpendingLimit
            config.subscriptionPlan = subscriptionPlan
            config.weeklyResetDayOfWeek = weeklyResetDayOfWeek
            config.weeklyResetHour = weeklyResetHour
            config.sessionBudgetOverride = parseBudget(sessionBudgetText)
            config.weeklyAllModelsBudgetOverride = parseBudget(weeklyAllModelsBudgetText)
            config.weeklySonnetBudgetOverride = parseBudget(weeklySonnetBudgetText)

            userDefaultsService.saveConfiguration(config)

            saveSuccess = true

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
