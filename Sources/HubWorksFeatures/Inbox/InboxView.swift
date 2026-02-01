import ComposableArchitecture
import HubWorksCore
import HubWorksUI
import SwiftData
import SwiftUI

/// Represents the unified selection state for the sidebar
private enum SidebarSelection: Hashable {
    case filter(InboxFeature.State.Filter)
    case repository(String)
}

// swiftlint:disable:next type_body_length
public struct InboxView: View {
    @Bindable var store: StoreOf<InboxFeature>

    /// Reactive SwiftData query - views automatically update when data changes
    @Query(
        filter: #Predicate<CachedNotification> { !$0.isArchived },
        sort: [SortDescriptor(\CachedNotification.updatedAt, order: .reverse)]
    ) private var notifications: [CachedNotification]

    @Query private var scopes: [NotificationScope]
    @Environment(\.modelContext) private var modelContext

    public init(store: StoreOf<InboxFeature>) {
        self.store = store
    }

    // MARK: - Computed Properties from SwiftData

    private var activeScope: NotificationScope? {
        guard let activeScopeId = store.activeFocusScopeId else { return nil }
        return scopes.first { $0.id == activeScopeId }
    }

    private var filteredNotifications: [CachedNotification] {
        var result = notifications

        // Apply scope filtering first if Focus Filter is active and not temporarily disabled
        if let scope = activeScope,
           !store.isFocusFilterTemporarilyDisabled,
           !scope.isDefault
        {
            result = result.filter { notification in
                scope.matchesNotification(notification)
            }
        }

        // Apply repository filter
        if let repo = store.selectedRepository {
            result = result.filter { $0.repositoryFullName == repo }
        }

        // Then apply type filter
        switch store.filter {
            case .all:
                return result
            case .unread:
                return result.filter(\.unread)
            case .participating:
                return result.filter { $0.reason == .mention || $0.reason == .reviewRequested || $0.reason == .assign }
            case .mentions:
                return result.filter { $0.reason == .mention }
        }
    }

    private var groupedNotifications: [(String, [CachedNotification])] {
        guard store.groupByRepository else {
            return [("All", filteredNotifications)]
        }

        let grouped = Dictionary(grouping: filteredNotifications) { $0.repositoryFullName }
        return grouped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private var repositories: [(name: String, unreadCount: Int)] {
        let grouped = Dictionary(grouping: notifications) { $0.repositoryFullName }
        return grouped
            .map { (name: $0.key, unreadCount: $0.value.filter(\.unread).count) }
            .sorted { $0.name < $1.name }
    }

    private var unreadCount: Int {
        notifications.filter(\.unread).count
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
            VStack(spacing: 0) {
                // Show Focus Filter banner when active
                if let scope = activeScope,
                   !scope.isDefault
                {
                    FocusFilterBannerView(
                        scopeName: scope.name,
                        scopeEmoji: scope.emoji,
                        isEnabled: !store.isFocusFilterTemporarilyDisabled
                    ) {
                        store.send(.toggleFocusFilter)
                    }
                }

                // Main content
                Group {
                    if store.isLoading, notifications.isEmpty {
                        ProgressView("Loading notifications...")
                    } else if notifications.isEmpty {
                        emptyState
                    } else {
                        notificationList
                    }
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
        .onAppear {
            store.send(.checkActiveFocusScope)
        }
    }

    @ToolbarContentBuilder private var iOSToolbarContent: some ToolbarContent {
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
            .help("Filter notifications by type")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.markAllAsRead)
            } label: {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(unreadCount == 0)
            .help("Mark all notifications as read")
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
                // Show Focus Filter banner when active
                if let scope = activeScope,
                   !scope.isDefault
                {
                    FocusFilterBannerView(
                        scopeName: scope.name,
                        scopeEmoji: scope.emoji,
                        isEnabled: !store.isFocusFilterTemporarilyDisabled
                    ) {
                        store.send(.toggleFocusFilter)
                    }
                }

                // Main content
                Group {
                    if store.isLoading, notifications.isEmpty {
                        ProgressView("Loading notifications...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredNotifications.isEmpty {
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
        .onAppear {
            store.send(.checkActiveFocusScope)
        }
    }

    private var navigationTitle: String {
        if let repo = store.selectedRepository {
            return repo.components(separatedBy: "/").last ?? repo
        }
        return store.filter.rawValue
    }

    private var sidebarView: some View {
        List(selection: Binding(
            get: {
                if let repo = store.selectedRepository {
                    SidebarSelection.repository(repo)
                } else {
                    SidebarSelection.filter(store.filter)
                }
            },
            set: { newSelection in
                guard let selection = newSelection else { return }
                switch selection {
                    case let .filter(filter):
                        store.send(.repositorySelected(nil))
                        store.send(.filterChanged(filter))
                    case let .repository(repo):
                        store.send(.repositorySelected(repo))
                }
            }
        )) {
            // Inbox section
            Section("Inbox") {
                ForEach(InboxFeature.State.Filter.allCases, id: \.self) { filter in
                    sidebarRow(
                        title: filter.rawValue,
                        icon: filter.systemImage,
                        count: countFor(filter: filter)
                    )
                    .tag(SidebarSelection.filter(filter))
                }
            }

            // Repositories section
            if !repositories.isEmpty {
                Section("Repositories") {
                    ForEach(repositories, id: \.name) { repo in
                        sidebarRow(
                            title: repo.name.components(separatedBy: "/").last ?? repo.name,
                            icon: "folder",
                            count: repo.unreadCount
                        )
                        .tag(SidebarSelection.repository(repo.name))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(title: String, icon: String, count: Int) -> some View {
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
                notifications.count
            case .unread:
                unreadCount
            case .participating:
                notifications.count { $0.reason == .mention || $0.reason == .reviewRequested || $0.reason == .assign }
            case .mentions:
                notifications.count { $0.reason == .mention }
        }
    }

    private var statusBar: some View {
        HStack {
            if unreadCount > 0 {
                Text("\(unreadCount) unread")
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

            if let progress = store.loadingProgress {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(progress)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Rate limit indicator
            if let rateLimit = store.rateLimit {
                rateLimitView(rateLimit)
            }

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

    private func rateLimitView(_ rateLimit: RateLimitInfo) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(rateLimitColor(rateLimit))
                .frame(width: 6, height: 6)

            Text("\(rateLimit.remaining)/\(rateLimit.limit)")
                .foregroundStyle(rateLimit.isLow ? .orange : .secondary)
        }
        .help("""
        API Rate Limit: \(rateLimit.remaining) of \(rateLimit.limit) requests remaining. \
        Resets \(rateLimit.reset, format: .relative(presentation: .named))
        """)
    }

    private func rateLimitColor(_ rateLimit: RateLimitInfo) -> Color {
        if rateLimit.percentRemaining > 0.5 {
            .green
        } else if rateLimit.percentRemaining > 0.1 {
            .yellow
        } else {
            .red
        }
    }

    @ToolbarContentBuilder private var macOSToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.refresh)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh notifications (⌘R)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.markAllAsRead)
            } label: {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(unreadCount == 0)
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .help("Mark all notifications as read (⌘⇧U)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.archiveAll(filteredNotifications.map(\.threadId)))
            } label: {
                Label("Archive All", systemImage: "archivebox")
            }
            .disabled(filteredNotifications.isEmpty)
            .help("Archive all visible notifications")
        }
    }
    #endif

    // MARK: - Shared Views

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

    @ViewBuilder private var notificationList: some View {
        List {
            ForEach(groupedNotifications, id: \.0) { group in
                Section(header: Text(group.0)) {
                    ForEach(group.1, id: \.threadId) { notification in
                        CachedNotificationRowView(
                            notification: notification,
                            onTap: {
                                store.send(.notificationTapped(notification.threadId, notification.webURL))
                            },
                            onMarkAsRead: {
                                store.send(.markAsRead(notification.threadId))
                            },
                            onArchive: {
                                store.send(.archive(notification.threadId))
                            },
                            onSnooze: { date in
                                store.send(.snooze(notification.threadId, date))
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
            if store.isRefreshing, !notifications.isEmpty {
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
