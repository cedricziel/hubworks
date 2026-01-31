import ComposableArchitecture
import HubWorksCore
import SwiftData
import SwiftUI

@Reducer
public struct InboxFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        // UI state only - notifications are observed via @Query in views
        public var isLoading: Bool = false
        public var isRefreshing: Bool = false
        public var error: String?
        public var filter: Filter = .all
        public var selectedRepository: String? // nil means all repos
        public var groupByRepository: Bool = true
        public var selectedNotificationId: String?
        public var lastUpdated: Date?
        public var loadingProgress: String? // e.g., "Loading page 2..."
        public var rateLimit: RateLimitInfo? // GitHub API rate limit status
        public var activeFocusScopeId: String?
        public var isFocusFilterTemporarilyDisabled: Bool = false

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
            isLoading: Bool = false,
            isRefreshing: Bool = false,
            error: String? = nil,
            filter: Filter = .all,
            selectedRepository: String? = nil,
            groupByRepository: Bool = true,
            selectedNotificationId: String? = nil,
            lastUpdated: Date? = nil,
            loadingProgress: String? = nil,
            rateLimit: RateLimitInfo? = nil,
            activeFocusScopeId: String? = nil,
            isFocusFilterTemporarilyDisabled: Bool = false
        ) {
            self.isLoading = isLoading
            self.isRefreshing = isRefreshing
            self.error = error
            self.filter = filter
            self.selectedRepository = selectedRepository
            self.groupByRepository = groupByRepository
            self.selectedNotificationId = selectedNotificationId
            self.lastUpdated = lastUpdated
            self.loadingProgress = loadingProgress
            self.rateLimit = rateLimit
            self.activeFocusScopeId = activeFocusScopeId
            self.isFocusFilterTemporarilyDisabled = isFocusFilterTemporarilyDisabled
        }
    }

    public enum Action: Sendable {
        case startPolling
        case stopPolling
        case pollNow
        case pageReceived(PollingPageResult)
        case pollingCompleted
        case notificationsFailed(String)
        case filterChanged(State.Filter)
        case repositorySelected(String?) // nil clears filter
        case toggleGroupByRepository
        case notificationTapped(String)
        case markAsRead(String)
        case markAsReadCompleted(String)
        case markAllAsRead
        case markAllAsReadCompleted
        case archiveAll([String]) // threadIds to archive
        case archive(String)
        case archiveCompleted(String)
        case snooze(String, Date)
        case snoozeCompleted(String)
        case refresh
        case refreshCompleted
        case checkActiveFocusScope
        case focusScopeChanged(String?)
        case toggleFocusFilter
    }

    @Dependency(\.gitHubAPIClient) var gitHubAPIClient
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.notificationPollingService) var pollingService
    @Dependency(\.notificationPersistence) var persistence
    @Dependency(\.focusFilterService) var focusFilterService

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .startPolling:
                    state.isLoading = true
                    state.loadingProgress = "Loading..."
                    return .run { send in
                        for await page in pollingService.startPolling(60) {
                            await send(.pageReceived(page))
                        }
                        await send(.pollingCompleted)
                    }

                case .stopPolling:
                    pollingService.stopPolling()
                    return .none

                case .pollNow:
                    state.isRefreshing = true
                    return .run { send in
                        do {
                            for try await page in pollingService.pollNow() {
                                await send(.pageReceived(page))
                            }
                            await send(.pollingCompleted)
                        } catch {
                            await send(.notificationsFailed(error.localizedDescription))
                        }
                    }

                case let .pageReceived(page):
                    // Update loading state
                    if page.isFirstPage {
                        state.isLoading = false
                        state.loadingProgress = page.hasMorePages ? "Loading more..." : nil
                    } else {
                        state.loadingProgress = page.hasMorePages ? "Loading more..." : nil
                    }

                    state.error = nil
                    state.lastUpdated = Date()

                    // Update rate limit info
                    if let rateLimit = page.rateLimit {
                        state.rateLimit = rateLimit
                    }

                    // Save this page to SwiftData immediately - views update reactively
                    return .run { [persistence] _ in
                        if !page.notifications.isEmpty {
                            try await persistence.upsertFromAPI(page.notifications, "default")
                        }
                    }

                case .pollingCompleted:
                    state.isLoading = false
                    state.isRefreshing = false
                    state.loadingProgress = nil
                    return .none

                case let .notificationsFailed(error):
                    state.isLoading = false
                    state.isRefreshing = false
                    state.loadingProgress = nil
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
                    return .run { [persistence, keychainService, gitHubAPIClient] send in
                        // Update locally first for immediate feedback
                        try await persistence.markAsRead(threadId)

                        // Then sync with GitHub
                        do {
                            guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                return
                            }
                            try await gitHubAPIClient.markAsRead(token, threadId)
                            await send(.markAsReadCompleted(threadId))
                        } catch {
                            // API error - local state already updated
                        }
                    }

                case .markAsReadCompleted:
                    // Already updated in SwiftData, views update automatically
                    return .none

                case .markAllAsRead:
                    return .run { [persistence, keychainService, gitHubAPIClient] send in
                        // Update locally first
                        try await persistence.markAllAsRead("default")

                        // Then sync with GitHub
                        do {
                            guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                return
                            }
                            try await gitHubAPIClient.markAllAsRead(token, nil)
                            await send(.markAllAsReadCompleted)
                        } catch {
                            // API error - local state already updated
                        }
                    }

                case .markAllAsReadCompleted:
                    // Already updated in SwiftData
                    return .none

                case let .archiveAll(threadIds):
                    return .run { [persistence, keychainService, gitHubAPIClient] send in
                        for threadId in threadIds {
                            try await persistence.archive(threadId)

                            // Also mark as read on GitHub
                            do {
                                guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                    continue
                                }
                                try await gitHubAPIClient.markAsRead(token, threadId)
                            } catch {
                                // Continue archiving even if GitHub sync fails
                            }

                            await send(.archiveCompleted(threadId))
                        }
                    }

                case let .archive(threadId):
                    return .run { [persistence, keychainService, gitHubAPIClient] send in
                        try await persistence.archive(threadId)

                        // Also mark as read on GitHub
                        do {
                            guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                return
                            }
                            try await gitHubAPIClient.markAsRead(token, threadId)
                        } catch {
                            // Continue even if GitHub sync fails
                        }

                        await send(.archiveCompleted(threadId))
                    }

                case .archiveCompleted:
                    // Already updated in SwiftData
                    return .none

                case let .snooze(threadId, until):
                    return .run { [persistence] send in
                        try await persistence.snooze(threadId, until)
                        await send(.snoozeCompleted(threadId))
                    }

                case .snoozeCompleted:
                    return .none

                case .refresh:
                    return .send(.pollNow)

                case .refreshCompleted:
                    state.isRefreshing = false
                    return .none

                case .checkActiveFocusScope:
                    return .run { send in
                        let scopeId = await focusFilterService.getActiveScope()
                        await send(.focusScopeChanged(scopeId))
                    }

                case let .focusScopeChanged(scopeId):
                    state.activeFocusScopeId = scopeId
                    // Reset temporary disable when Focus changes
                    state.isFocusFilterTemporarilyDisabled = false
                    UserDefaults.standard.set(false, forKey: "focus_filter_temporarily_disabled")
                    return .none

                case .toggleFocusFilter:
                    let newValue = !state.isFocusFilterTemporarilyDisabled
                    state.isFocusFilterTemporarilyDisabled = newValue
                    UserDefaults.standard.set(newValue, forKey: "focus_filter_temporarily_disabled")
                    return .none
            }
        }
    }
}
