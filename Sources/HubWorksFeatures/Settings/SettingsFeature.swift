import ComposableArchitecture
import HubWorksCore
import SwiftUI

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var accounts: [AccountState] = []
        public var pollInterval: Int = 60
        public var notificationsEnabled: Bool = true
        public var showUnreadBadge: Bool = true
        public var groupByRepository: Bool = true
        public var appVersion: String = "1.0.0"

        public struct AccountState: Equatable, Identifiable, Sendable {
            public let id: String
            public let username: String
            public let avatarURL: URL?
            public let email: String?

            public init(
                id: String,
                username: String,
                avatarURL: URL? = nil,
                email: String? = nil
            ) {
                self.id = id
                self.username = username
                self.avatarURL = avatarURL
                self.email = email
            }
        }

        public init(
            accounts: [AccountState] = [],
            pollInterval: Int = 60,
            notificationsEnabled: Bool = true,
            showUnreadBadge: Bool = true,
            groupByRepository: Bool = true,
            appVersion: String = "1.0.0"
        ) {
            self.accounts = accounts
            self.pollInterval = pollInterval
            self.notificationsEnabled = notificationsEnabled
            self.showUnreadBadge = showUnreadBadge
            self.groupByRepository = groupByRepository
            self.appVersion = appVersion
        }
    }

    public enum Action: Sendable {
        case onAppear
        case loadAccountsCompleted([State.AccountState])
        case addAccountTapped
        case removeAccount(String)
        case removeAccountCompleted(String)
        case pollIntervalChanged(Int)
        case notificationsEnabledChanged(Bool)
        case showUnreadBadgeChanged(Bool)
        case groupByRepositoryChanged(Bool)
        case signOutTapped
        case signOutCompleted
    }

    @Dependency(\.keychainService) var keychainService
    @Dependency(\.localNotificationService) var localNotificationService

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .loadAccountsCompleted(accounts):
                state.accounts = accounts
                return .none

            case .addAccountTapped:
                // Trigger OAuth flow for new account
                return .none

            case let .removeAccount(accountId):
                return .run { send in
                    try? keychainService.delete("github_oauth_token_\(accountId)")
                    await send(.removeAccountCompleted(accountId))
                }

            case let .removeAccountCompleted(accountId):
                state.accounts.removeAll { $0.id == accountId }
                return .none

            case let .pollIntervalChanged(interval):
                state.pollInterval = interval
                return .none

            case let .notificationsEnabledChanged(enabled):
                state.notificationsEnabled = enabled
                if enabled {
                    return .run { _ in
                        _ = try? await localNotificationService.requestAuthorization()
                    }
                }
                return .none

            case let .showUnreadBadgeChanged(show):
                state.showUnreadBadge = show
                return .none

            case let .groupByRepositoryChanged(group):
                state.groupByRepository = group
                return .none

            case .signOutTapped:
                return .run { send in
                    try? keychainService.delete("github_oauth_token_default")
                    await send(.signOutCompleted)
                }

            case .signOutCompleted:
                state.accounts = []
                return .none
            }
        }
    }
}
