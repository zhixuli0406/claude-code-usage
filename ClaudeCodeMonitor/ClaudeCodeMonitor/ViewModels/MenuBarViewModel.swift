import Foundation
import Observation
import SwiftUI

/// Main ViewModel for the menu bar application
@Observable
@MainActor
final class MenuBarViewModel {
    private let usageMonitorService: UsageMonitorService
    private let refreshScheduler: RefreshScheduler
    let userDefaultsService: UserDefaultsService

    var isLoading: Bool {
        usageMonitorService.isLoading
    }

    var currentUsage: UsageMetrics? {
        usageMonitorService.currentUsage
    }

    var sessionHistory: [SessionData] {
        usageMonitorService.sessionHistory
    }

    var lastError: AppError? {
        usageMonitorService.lastError
    }

    var lastRefreshDate: Date? {
        refreshScheduler.lastRefreshDate
    }

    var nextRefreshDate: Date? {
        refreshScheduler.nextRefreshDate
    }

    var isRefreshSchedulerRunning: Bool {
        refreshScheduler.isRunning
    }

    init(
        usageMonitorService: UsageMonitorService,
        refreshScheduler: RefreshScheduler,
        userDefaultsService: UserDefaultsService
    ) {
        self.usageMonitorService = usageMonitorService
        self.refreshScheduler = refreshScheduler
        self.userDefaultsService = userDefaultsService

        // Load cached data on init
        usageMonitorService.loadCachedData()

        // Start refresh scheduler
        refreshScheduler.start()
    }

    /// Force refresh now
    func refresh() async {
        await refreshScheduler.forceRefresh()
    }

    /// Open settings window
    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Quit application
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// Get menu bar icon state
    var iconState: MenuBarIconState {
        if isLoading {
            return .loading
        }
        if lastError != nil {
            return .error
        }
        if let lastRefresh = lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < 120 {
            return .active
        }
        return .idle
    }
}

/// Menu bar icon states
enum MenuBarIconState {
    case idle
    case active
    case warning
    case error
    case loading

    var systemImage: String {
        switch self {
        case .idle: return "bolt"
        case .active: return "bolt.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .loading: return "arrow.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .active: return .blue
        case .warning: return .orange
        case .error: return .red
        case .loading: return .gray
        }
    }
}
