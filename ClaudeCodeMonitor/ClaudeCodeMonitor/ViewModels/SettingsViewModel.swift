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

            userDefaultsService.saveConfiguration(config)

            saveSuccess = true

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
