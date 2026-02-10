import Foundation

/// User preferences configuration
struct AppConfiguration: Codable {
    var refreshInterval: TimeInterval = 60.0  // Default: 60 seconds
    var showNotifications: Bool = true
    var selectedTimeGranularity: TimeGranularity = .oneMinute
    var costAlertThreshold: Decimal?
    var lastRefreshDate: Date?
    var launchAtLogin: Bool = false
}

/// Time granularity for API queries
@available(macOS 14.0, *)
enum TimeGranularity: String, Codable, CaseIterable {
    case oneMinute = "1m"
    case oneHour = "1h"
    case oneDay = "1d"

    var displayName: String {
        switch self {
        case .oneMinute: return "1 分鐘"
        case .oneHour: return "1 小時"
        case .oneDay: return "1 天"
        }
    }
}

/// Service for managing app configuration in UserDefaults
@available(macOS 14.0, *)
final class UserDefaultsService {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showNotifications = "showNotifications"
        static let timeGranularity = "timeGranularity"
        static let costAlertThreshold = "costAlertThreshold"
        static let lastRefreshDate = "lastRefreshDate"
        static let launchAtLogin = "launchAtLogin"
    }

    /// Load configuration from UserDefaults
    func loadConfiguration() -> AppConfiguration {
        var config = AppConfiguration()

        if let interval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval {
            config.refreshInterval = interval
        }

        config.showNotifications = defaults.bool(forKey: Keys.showNotifications)

        if let granularityRaw = defaults.string(forKey: Keys.timeGranularity),
           let granularity = TimeGranularity(rawValue: granularityRaw) {
            config.selectedTimeGranularity = granularity
        }

        if let thresholdValue = defaults.object(forKey: Keys.costAlertThreshold) as? NSDecimalNumber {
            config.costAlertThreshold = thresholdValue.decimalValue
        }

        if let lastRefresh = defaults.object(forKey: Keys.lastRefreshDate) as? Date {
            config.lastRefreshDate = lastRefresh
        }

        if defaults.object(forKey: Keys.launchAtLogin) != nil {
            config.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        }

        return config
    }

    /// Save configuration to UserDefaults
    func saveConfiguration(_ config: AppConfiguration) {
        defaults.set(config.refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(config.showNotifications, forKey: Keys.showNotifications)
        defaults.set(config.selectedTimeGranularity.rawValue, forKey: Keys.timeGranularity)

        if let threshold = config.costAlertThreshold {
            defaults.set(NSDecimalNumber(decimal: threshold), forKey: Keys.costAlertThreshold)
        } else {
            defaults.removeObject(forKey: Keys.costAlertThreshold)
        }

        if let lastRefresh = config.lastRefreshDate {
            defaults.set(lastRefresh, forKey: Keys.lastRefreshDate)
        }

        defaults.set(config.launchAtLogin, forKey: Keys.launchAtLogin)
    }

    /// Update last refresh date
    func updateLastRefreshDate(_ date: Date) {
        defaults.set(date, forKey: Keys.lastRefreshDate)
    }
}
