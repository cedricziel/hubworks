import ComposableArchitecture
import HubWorksCore
import HubWorksUI
import SwiftUI

public struct InboxView: View {
    @Bindable var store: StoreOf<InboxFeature>

    public init(store: StoreOf<InboxFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView("Loading notifications...")
                } else if store.notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                toolbarContent
            }
            .refreshable {
                await refreshNotifications()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notifications", systemImage: "tray")
        } description: {
            Text("You're all caught up!")
        } actions: {
            Button("Refresh") {
                store.send(.refresh)
            }
        }
    }

    @ViewBuilder
    private var notificationList: some View {
        List {
            ForEach(store.groupedNotifications, id: \.0) { group in
                Section(header: Text(group.0)) {
                    ForEach(group.1) { notification in
                        NotificationRowView(
                            notification: notification,
                            onTap: {
                                store.send(.notificationTapped(notification.id))
                            },
                            onMarkAsRead: {
                                store.send(.markAsRead(notification.id))
                            },
                            onArchive: {
                                store.send(.archive(notification.id))
                            },
                            onSnooze: { date in
                                store.send(.snooze(notification.id, date))
                            }
                        )
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .overlay {
            if store.isRefreshing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(InboxFeature.State.Filter.allCases, id: \.self) { filter in
                    Button {
                        store.send(.filterChanged(filter))
                    } label: {
                        Label(filter.rawValue, systemImage: filter.systemImage)
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.markAllAsRead)
            } label: {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(store.unreadCount == 0)
        }

        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.refresh)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        #endif
    }

    private func refreshNotifications() async {
        store.send(.refresh)
        // Wait a bit for the refresh to complete
        try? await Task.sleep(for: .seconds(1))
    }
}

#Preview {
    InboxView(
        store: Store(initialState: InboxFeature.State()) {
            InboxFeature()
        }
    )
}
