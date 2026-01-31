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
        public var groupByRepository: Bool = true
        public var selectedNotificationId: String?

        public enum Filter: String, CaseIterable, Sendable {
            case all = "All"
            case unread = "Unread"
            case participating = "Participating"

            public var systemImage: String {
                switch self {
                case .all: "tray.full"
                case .unread: "circle.fill"
                case .participating: "person.fill"
                }
            }
        }

        public init(
            notifications: IdentifiedArrayOf<NotificationRowState> = [],
            isLoading: Bool = false,
            isRefreshing: Bool = false,
            error: String? = nil,
            filter: Filter = .all,
            groupByRepository: Bool = true,
            selectedNotificationId: String? = nil
        ) {
            self.notifications = notifications
            self.isLoading = isLoading
            self.isRefreshing = isRefreshing
            self.error = error
            self.filter = filter
            self.groupByRepository = groupByRepository
            self.selectedNotificationId = selectedNotificationId
        }

        public var filteredNotifications: IdentifiedArrayOf<NotificationRowState> {
            switch filter {
            case .all:
                notifications
            case .unread:
                notifications.filter(\.isUnread)
            case .participating:
                notifications.filter { $0.reason == .mention || $0.reason == .reviewRequested || $0.reason == .assign }
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
        case toggleGroupByRepository
        case notificationTapped(String)
        case markAsRead(String)
        case markAsReadCompleted(String)
        case markAllAsRead
        case markAllAsReadCompleted
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

                let rowStates = notifications.map { notification in
                    NotificationRowState(
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
                }

                state.notifications = IdentifiedArrayOf(uniqueElements: rowStates)
                return .none

            case let .notificationsFailed(error):
                state.isLoading = false
                state.isRefreshing = false
                state.error = error
                return .none

            case let .filterChanged(filter):
                state.filter = filter
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
