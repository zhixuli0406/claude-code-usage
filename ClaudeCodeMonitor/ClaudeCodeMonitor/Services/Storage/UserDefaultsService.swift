import Foundation
import SwiftUI

/// Claude subscription plan tiers
/// Estimated daily API-equivalent budget based on Anthropic's published data (~$6/day avg for Pro)
enum SubscriptionPlan: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case max5x = "max5x"
    case max20x = "max20x"
    case team = "team"
    case teamPremium = "teamPremium"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .max5x: return "Max 5x"
        case .max20x: return "Max 20x"
        case .team: return "Team"
        case .teamPremium: return "Team Premium"
        }
    }

    /// Monthly subscription price (USD)
    var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .pro: return 20
        case .max5x: return 100
        case .max20x: return 200
        case .team: return 25
        case .teamPremium: return 125
        }
    }

    /// Estimated daily API-equivalent budget included in the plan
    /// Based on Anthropic's data: average Claude Code usage ~$6/day for Pro
    var estimatedDailyBudget: Decimal {
        switch self {
        case .free: return 0
        case .pro: return 5
        case .max5x: return 25       // 5× Pro
        case .max20x: return 100     // 20× Pro
        case .team: return 5         // Pro-level
        case .teamPremium: return 25 // 5× level
        }
    }

    /// Accent color for the plan tier
    var color: Color {
        switch self {
        case .free: return .gray
        case .pro: return .blue
        case .max5x: return .purple
        case .max20x: return .orange
        case .team: return .teal
        case .teamPremium: return .indigo
        }
    }
}

/// User preferences configuration
struct AppConfiguration: Codable {
    var refreshInterval: TimeInterval = 60.0  // Default: 60 seconds
    var showNotifications: Bool = true
    var selectedTimeGranularity: TimeGranularity = .oneMinute
    var costAlertThreshold: Decimal?
    var monthlySpendingLimit: Decimal = 20.0  // Default: $20 (Extra usage limit)
    var subscriptionPlan: SubscriptionPlan = .pro
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
        static let monthlySpendingLimit = "monthlySpendingLimit"
        static let subscriptionPlan = "subscriptionPlan"
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

        if let limitValue = defaults.object(forKey: Keys.monthlySpendingLimit) as? NSDecimalNumber {
            config.monthlySpendingLimit = limitValue.decimalValue
        }

        if let planRaw = defaults.string(forKey: Keys.subscriptionPlan),
           let plan = SubscriptionPlan(rawValue: planRaw) {
            config.subscriptionPlan = plan
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

        defaults.set(NSDecimalNumber(decimal: config.monthlySpendingLimit), forKey: Keys.monthlySpendingLimit)
        defaults.set(config.subscriptionPlan.rawValue, forKey: Keys.subscriptionPlan)

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
