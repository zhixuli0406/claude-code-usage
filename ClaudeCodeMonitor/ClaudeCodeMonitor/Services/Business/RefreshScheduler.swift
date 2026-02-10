import Foundation
import Observation

/// Scheduler for background data refresh
@Observable
final class RefreshScheduler {
    private var timer: Timer?
    private let usageMonitorService: UsageMonitorService
    private let userDefaultsService: UserDefaultsService

    var isRunning = false
    var lastRefreshDate: Date?
    var nextRefreshDate: Date? {
        guard let last = lastRefreshDate else { return nil }
        let config = userDefaultsService.loadConfiguration()
        return last.addingTimeInterval(config.refreshInterval)
    }

    init(
        usageMonitorService: UsageMonitorService,
        userDefaultsService: UserDefaultsService
    ) {
        self.usageMonitorService = usageMonitorService
        self.userDefaultsService = userDefaultsService
    }

    /// Start automatic refresh
    func start() {
        stop()  // Cancel existing timer

        let config = userDefaultsService.loadConfiguration()
        let interval = config.refreshInterval

        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performRefresh()
            }
        }

        isRunning = true

        // Initial refresh
        Task { @MainActor in
            await performRefresh()
        }
    }

    /// Stop automatic refresh
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Force refresh now
    @MainActor
    func forceRefresh() async {
        await performRefresh()
    }

    /// Perform refresh
    @MainActor
    private func performRefresh() async {
        await usageMonitorService.refreshAllData()
        lastRefreshDate = Date()
        userDefaultsService.updateLastRefreshDate(Date())
    }

    deinit {
        stop()
    }
}
