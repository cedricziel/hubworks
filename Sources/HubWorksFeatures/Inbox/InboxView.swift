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
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
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
                iOSToolbarContent
            }
            .refreshable {
                await refreshNotifications()
            }
        }
    }

    @ToolbarContentBuilder
    private var iOSToolbarContent: some ToolbarContent {
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
    }
    #endif

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Main content
                Group {
                    if store.isLoading && store.notifications.isEmpty {
                        ProgressView("Loading notifications...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if store.filteredNotifications.isEmpty {
                        emptyState
                    } else {
                        notificationList
                    }
                }

                // Status bar
                statusBar
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                macOSToolbarContent
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var navigationTitle: String {
        if let repo = store.selectedRepository {
            return repo.components(separatedBy: "/").last ?? repo
        }
        return store.filter.rawValue
    }

    private var sidebarView: some View {
        List(selection: Binding(
            get: { store.filter },
            set: { store.send(.filterChanged($0)) }
        )) {
            // Inbox section
            Section("Inbox") {
                ForEach(InboxFeature.State.Filter.allCases, id: \.self) { filter in
                    sidebarRow(
                        title: filter.rawValue,
                        icon: filter.systemImage,
                        count: countFor(filter: filter),
                        isSelected: store.filter == filter && store.selectedRepository == nil
                    )
                    .tag(filter)
                    .onTapGesture {
                        store.send(.repositorySelected(nil))
                        store.send(.filterChanged(filter))
                    }
                }
            }

            // Repositories section
            if !store.repositories.isEmpty {
                Section("Repositories") {
                    ForEach(store.repositories, id: \.name) { repo in
                        sidebarRow(
                            title: repo.name.components(separatedBy: "/").last ?? repo.name,
                            icon: "folder",
                            count: repo.unreadCount,
                            isSelected: store.selectedRepository == repo.name
                        )
                        .onTapGesture {
                            store.send(.repositorySelected(repo.name))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(title: String, icon: String, count: Int, isSelected: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    private func countFor(filter: InboxFeature.State.Filter) -> Int {
        switch filter {
        case .all:
            return store.notifications.count
        case .unread:
            return store.unreadCount
        case .participating:
            return store.notifications.filter { $0.reason == .mention || $0.reason == .reviewRequested || $0.reason == .assign }.count
        case .mentions:
            return store.notifications.filter { $0.reason == .mention }.count
        }
    }

    private var statusBar: some View {
        HStack {
            if store.unreadCount > 0 {
                Text("\(store.unreadCount) unread")
                    .foregroundStyle(.secondary)
            } else {
                Text("All caught up")
                    .foregroundStyle(.secondary)
            }

            if let lastUpdated = store.lastUpdated {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var macOSToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.refresh)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.markAllAsRead)
            } label: {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(store.unreadCount == 0)
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.archiveAll)
            } label: {
                Label("Archive All", systemImage: "archivebox")
            }
            .disabled(store.filteredNotifications.isEmpty)
        }
    }
    #endif

    // MARK: - Shared Views

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
            if store.isRefreshing && !store.notifications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }
        }
    }

    private func refreshNotifications() async {
        store.send(.refresh)
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
