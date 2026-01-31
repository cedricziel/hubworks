import AppKit
import Combine
import ComposableArchitecture
import HubWorksCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pollingTimer: AnyCancellable?

    @Dependency(\.notificationPollingService) var pollingService
    @Dependency(\.localNotificationService) var localNotificationService

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app activates and shows window
        NSApp.activate(ignoringOtherApps: true)

        setupPolling()
        setupNotifications()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen main window when dock icon is clicked
        if !flag {
            for window in NSApp.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollingTimer?.cancel()
        pollingService.stopPolling()
    }

    private func setupPolling() {
        // Start foreground polling every 60 seconds for macOS menu bar app
        pollingTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    try? await self.pollingService.pollNow()
                }
            }
    }

    private func setupNotifications() {
        Task { @MainActor in
            await localNotificationService.registerCategories()
        }
    }
}
