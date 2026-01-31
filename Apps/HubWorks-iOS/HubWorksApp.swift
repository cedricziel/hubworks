import ComposableArchitecture
import HubWorksCore
import HubWorksFeatures
import SwiftData
import SwiftUI

@main
struct HubWorksApp: App {
    @Dependency(\.backgroundRefreshManager) var backgroundRefreshManager
    @Dependency(\.localNotificationService) var localNotificationService

    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    init() {
        setupBackgroundRefresh()
        setupNotifications()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .modelContainer(HubWorksCore.modelContainer)
        }
    }

    private func setupBackgroundRefresh() {
        backgroundRefreshManager.registerHandler {
            await performBackgroundRefresh()
        }
    }

    private func setupNotifications() {
        Task {
            await localNotificationService.registerCategories()
        }
    }

    private func performBackgroundRefresh() async -> Bool {
        await store.send(.backgroundRefreshTriggered).finish()
        return true
    }
}
