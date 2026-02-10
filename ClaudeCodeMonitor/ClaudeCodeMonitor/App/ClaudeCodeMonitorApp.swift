import SwiftUI
import Foundation

@available(macOS 14.0, *)
@main
struct ClaudeCodeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var menuBarViewModel: MenuBarViewModel

    init() {
        // Initialize services
        let localUsageService = LocalUsageService()
        let costCalculationService = CostCalculationService()
        let userDefaultsService = UserDefaultsService()

        let usageMonitorService = UsageMonitorService(
            localUsageService: localUsageService,
            costCalculationService: costCalculationService
        )

        let refreshScheduler = RefreshScheduler(
            usageMonitorService: usageMonitorService,
            userDefaultsService: userDefaultsService
        )

        // Initialize ViewModel
        self._menuBarViewModel = State(initialValue: MenuBarViewModel(
            usageMonitorService: usageMonitorService,
            refreshScheduler: refreshScheduler,
            userDefaultsService: userDefaultsService
        ))
    }

    var body: some Scene {
        // MenuBarExtra for menu bar application
        MenuBarExtra("Claude Code Monitor", systemImage: "bolt.fill") {
            MenuBarContentView(viewModel: menuBarViewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Window("設定", id: "settings") {
            SettingsWindowView(
                viewModel: SettingsViewModel(
                    userDefaultsService: menuBarViewModel.userDefaultsService
                )
            )
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

@available(macOS 14.0, *)
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.accessory)
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when settings window closes
        return false
    }
}
