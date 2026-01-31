import ComposableArchitecture
import HubWorksCore
import SwiftData
import SwiftUI

@Reducer
public struct InboxFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var notifications: IdentifiedArrayOf<NotificationRowState> = []
        public var isLoading: Bool = false
        public var isRefreshing: Bool = false
        public var error: String?
        public var filter: Filter = .all
        public var selectedRepository: String? = nil  // nil means all repos
        public var groupByRepository: Bool = true
        public var selectedNotificationId: String?
        public var lastUpdated: Date? = nil

        public enum Filter: String, CaseIterable, Sendable {
            case all = "All"
            case unread = "Unread"
            case participating = "Participating"
            case mentions = "Mentions"

            public var systemImage: String {
                switch self {
                case .all: "tray.full"
                case .unread: "envelope.badge"
                case .participating: "bubble.left.and.bubble.right"
                case .mentions: "at"
                }
            }
        }

        public init(
            notifications: IdentifiedArrayOf<NotificationRowState> = [],
            isLoading: Bool = false,
            isRefreshing: Bool = false,
            error: String? = nil,
            filter: Filter = .all,
            selectedRepository: String? = nil,
            groupByRepository: Bool = true,
            selectedNotificationId: String? = nil,
            lastUpdated: Date? = nil
        ) {
            self.notifications = notifications
            self.isLoading = isLoading
            self.isRefreshing = isRefreshing
            self.error = error
            self.filter = filter
            self.selectedRepository = selectedRepository
            self.groupByRepository = groupByRepository
            self.selectedNotificationId = selectedNotificationId
            self.lastUpdated = lastUpdated
        }

        /// List of unique repositories from notifications with their unread counts
        public var repositories: [(name: String, unreadCount: Int)] {
            let grouped = Dictionary(grouping: notifications.elements) { $0.repositoryFullName }
            return grouped
                .map { (name: $0.key, unreadCount: $0.value.filter(\.isUnread).count) }
                .sorted { $0.name < $1.name }
        }

        public var filteredNotifications: IdentifiedArrayOf<NotificationRowState> {
            var result = notifications

            // Apply repository filter first
            if let repo = selectedRepository {
                result = result.filter { $0.repositoryFullName == repo }
            }

            // Then apply type filter
            switch filter {
            case .all:
                return result
            case .unread:
                return result.filter(\.isUnread)
            case .participating:
                return result.filter { $0.reason == .mention || $0.reason == .reviewRequested || $0.reason == .assign }
            case .mentions:
                return result.filter { $0.reason == .mention }
            }
        }

        public var groupedNotifications: [(String, IdentifiedArrayOf<NotificationRowState>)] {
            guard groupByRepository else {
                return [("All", filteredNotifications)]
            }

            let grouped = Dictionary(grouping: filteredNotifications.elements) { $0.repositoryFullName }
            return grouped
                .sorted { $0.key < $1.key }
                .map { ($0.key, IdentifiedArrayOf(uniqueElements: $0.value)) }
        }

        public var unreadCount: Int {
            notifications.filter(\.isUnread).count
        }
    }

    public enum Action: Sendable {
        case startPolling
        case stopPolling
        case pollNow
        case notificationsReceived([GitHubNotification])
        case notificationsFailed(String)
        case filterChanged(State.Filter)
        case repositorySelected(String?)  // nil clears filter
        case toggleGroupByRepository
        case notificationTapped(String)
        case markAsRead(String)
        case markAsReadCompleted(String)
        case markAllAsRead
        case markAllAsReadCompleted
        case archiveAll
        case archive(String)
        case archiveCompleted(String)
        case snooze(String, Date)
        case snoozeCompleted(String)
        case refresh
        case refreshCompleted
    }

    @Dependency(\.gitHubAPIClient) var gitHubAPIClient
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.notificationPollingService) var pollingService

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startPolling:
                state.isLoading = true
                return .run { send in
                    for await notifications in pollingService.startPolling(60) {
                        await send(.notificationsReceived(notifications))
                    }
                }

            case .stopPolling:
                pollingService.stopPolling()
                return .none

            case .pollNow:
                return .run { send in
                    do {
                        let notifications = try await pollingService.pollNow()
                        await send(.notificationsReceived(notifications))
                    } catch {
                        await send(.notificationsFailed(error.localizedDescription))
                    }
                }

            case let .notificationsReceived(notifications):
                state.isLoading = false
                state.isRefreshing = false
                state.error = nil
                state.lastUpdated = Date()

                // Upsert notifications: update existing, insert new
                // This preserves local state (snoozed, archived) for existing items
                var seenIds = Set<String>()

                for notification in notifications {
                    // Skip duplicates within this batch
                    guard seenIds.insert(notification.id).inserted else { continue }

                    let newRowState = NotificationRowState(
                        id: notification.id,
                        threadId: notification.id,
                        title: notification.subject.title,
                        repositoryFullName: notification.repository.fullName,
                        repositoryOwner: notification.repository.owner.login,
                        repositoryAvatarURL: notification.repository.owner.avatarUrl.flatMap { URL(string: $0) },
                        subjectType: NotificationSubjectType(from: notification.subject.type),
                        reason: NotificationReason(rawValue: notification.reason) ?? .subscribed,
                        isUnread: notification.unread,
                        updatedAt: ISO8601DateFormatter().date(from: notification.updatedAt) ?? .now,
                        webURL: notification.subject.url.flatMap { URL(string: $0) }
                    )

                    if let existingIndex = state.notifications.index(id: notification.id) {
                        // Update existing: preserve local state (snoozed, archived)
                        var updated = newRowState
                        updated.isSnoozed = state.notifications[existingIndex].isSnoozed
                        updated.snoozeUntil = state.notifications[existingIndex].snoozeUntil
                        state.notifications[existingIndex] = updated
                    } else {
                        // Insert new
                        state.notifications.append(newRowState)
                    }
                }
                return .none

            case let .notificationsFailed(error):
                state.isLoading = false
                state.isRefreshing = false
                state.error = error
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                return .none

            case let .repositorySelected(repo):
                state.selectedRepository = repo
                return .none

            case .toggleGroupByRepository:
                state.groupByRepository.toggle()
                return .none

            case let .notificationTapped(id):
                state.selectedNotificationId = id
                return .none

            case let .markAsRead(threadId):
                return .run { send in
                    do {
                        guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                            return
                        }
                        try await gitHubAPIClient.markAsRead(token, threadId)
                        await send(.markAsReadCompleted(threadId))
                    } catch {
                        // Handle error silently for now
                    }
                }

            case let .markAsReadCompleted(threadId):
                if let index = state.notifications.firstIndex(where: { $0.id == threadId }) {
                    state.notifications[index].isUnread = false
                }
                return .none

            case .markAllAsRead:
                return .run { send in
                    do {
                        guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                            return
                        }
                        try await gitHubAPIClient.markAllAsRead(token, nil)
                        await send(.markAllAsReadCompleted)
                    } catch {
                        // Handle error silently for now
                    }
                }

            case .markAllAsReadCompleted:
                for index in state.notifications.indices {
                    state.notifications[index].isUnread = false
                }
                return .none

            case .archiveAll:
                // Archive all currently filtered notifications
                let idsToArchive = state.filteredNotifications.map(\.id)
                return .run { send in
                    for id in idsToArchive {
                        await send(.archive(id))
                    }
                }

            case let .archive(threadId):
                return .send(.markAsRead(threadId))

            case let .archiveCompleted(threadId):
                state.notifications.remove(id: threadId)
                return .none

            case let .snooze(threadId, until):
                // Store snooze state locally
                if let index = state.notifications.firstIndex(where: { $0.id == threadId }) {
                    state.notifications[index].isSnoozed = true
                    state.notifications[index].snoozeUntil = until
                }
                return .send(.snoozeCompleted(threadId))

            case .snoozeCompleted:
                return .none

            case .refresh:
                state.isRefreshing = true
                return .send(.pollNow)

            case .refreshCompleted:
                state.isRefreshing = false
                return .none
            }
        }
    }
}

// NotificationRowState is now defined in HubWorksCore
