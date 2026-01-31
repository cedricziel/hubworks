import ComposableArchitecture
import HubWorksCore
import HubWorksUI
import SwiftData
import SwiftUI

@main
struct HubWorksApp: App {
    let store = Store(initialState: WatchAppFeature.State()) {
        WatchAppFeature()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView(store: store)
                .modelContainer(HubWorksCore.modelContainer)
        }
    }
}

@Reducer
struct WatchAppFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var notifications: [WatchNotification] = []
        var isLoading: Bool = true
        var error: String?
    }

    enum Action: Sendable {
        case onAppear
        case notificationsReceived([WatchNotification])
        case error(String)
        case markAsRead(String)
        case refresh
    }

    @Dependency(\.gitHubAPIClient) var gitHubAPIClient
    @Dependency(\.keychainService) var keychainService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .send(.refresh)

            case let .notificationsReceived(notifications):
                state.notifications = notifications
                state.isLoading = false
                state.error = nil
                return .none

            case let .error(message):
                state.error = message
                state.isLoading = false
                return .none

            case let .markAsRead(id):
                if let index = state.notifications.firstIndex(where: { $0.id == id }) {
                    state.notifications[index].isUnread = false
                }
                return .run { _ in
                    guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                        return
                    }
                    try await gitHubAPIClient.markAsRead(token, id)
                }

            case .refresh:
                return .run { send in
                    do {
                        guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                            await send(.error("Not authenticated"))
                            return
                        }

                        let result = try await gitHubAPIClient.fetchNotifications(token, nil, false, false)
                        let notifications = result.notifications.prefix(10).map { notification in
                            WatchNotification(
                                id: notification.id,
                                title: notification.subject.title,
                                repository: notification.repository.name,
                                reason: notification.reason,
                                isUnread: notification.unread
                            )
                        }
                        await send(.notificationsReceived(Array(notifications)))
                    } catch {
                        await send(.error(error.localizedDescription))
                    }
                }
            }
        }
    }
}

struct WatchNotification: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let repository: String
    let reason: String
    var isUnread: Bool
}

struct WatchContentView: View {
    @Bindable var store: StoreOf<WatchAppFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if let error = store.error {
                    Text(error)
                        .foregroundStyle(.secondary)
                } else if store.notifications.isEmpty {
                    Text("No notifications")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(store.notifications) { notification in
                            WatchNotificationRow(notification: notification) {
                                store.send(.markAsRead(notification.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("HubWorks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.refresh)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

struct WatchNotificationRow: View {
    let notification: WatchNotification
    let onMarkAsRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if notification.isUnread {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }
                Text(notification.repository)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(notification.title)
                .font(.caption)
                .lineLimit(2)
        }
        .swipeActions {
            Button {
                onMarkAsRead()
            } label: {
                Image(systemName: "checkmark")
            }
            .tint(.blue)
        }
    }
}
