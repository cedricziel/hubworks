import ComposableArchitecture
import HubWorksCore
import SwiftUI

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var accounts: [AccountState] = []
        public var isLoadingUser: Bool = false
        public var userLoadError: String?
        public var pollInterval: Int = 60
        public var notificationsEnabled: Bool = true
        public var showUnreadBadge: Bool = true
        public var groupByRepository: Bool = true
        public var appVersion: String = "1.0.0"
        public var buildNumber: String = "1"
        public var focusScopes: FocusScopeFeature.State = .init()

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
            isLoadingUser: Bool = false,
            userLoadError: String? = nil,
            pollInterval: Int = 60,
            notificationsEnabled: Bool = true,
            showUnreadBadge: Bool = true,
            groupByRepository: Bool = true,
            appVersion: String = "1.0.0",
            buildNumber: String = "1",
            focusScopes: FocusScopeFeature.State = .init()
        ) {
            self.accounts = accounts
            self.isLoadingUser = isLoadingUser
            self.userLoadError = userLoadError
            self.pollInterval = pollInterval
            self.notificationsEnabled = notificationsEnabled
            self.showUnreadBadge = showUnreadBadge
            self.groupByRepository = groupByRepository
            self.appVersion = appVersion
            self.buildNumber = buildNumber
            self.focusScopes = focusScopes
        }
    }

    public enum Action: Sendable {
        case onAppear
        case loadCurrentUser
        case currentUserLoaded(GitHubUser)
        case currentUserLoadFailed(String)
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
        case focusScopes(FocusScopeFeature.Action)
    }

    @Dependency(\.keychainService) var keychainService
    @Dependency(\.localNotificationService) var localNotificationService
    @Dependency(\.gitHubAPIClient) var gitHubAPIClient

    public init() {}

    // swiftformat:disable indent
    public var body: some ReducerOf<Self> {
        Scope(state: \.focusScopes, action: \.focusScopes) {
            FocusScopeFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadCurrentUser)

            case .loadCurrentUser:
                guard !state.isLoadingUser else { return .none }
                state.isLoadingUser = true
                state.userLoadError = nil
                return .run { send in
                    do {
                        guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                            await send(.currentUserLoadFailed("No token found"))
                            return
                        }
                        let user = try await gitHubAPIClient.fetchCurrentUser(token)
                        await send(.currentUserLoaded(user))
                    } catch {
                        await send(.currentUserLoadFailed(error.localizedDescription))
                    }
                }

            case let .currentUserLoaded(user):
                state.isLoadingUser = false
                let avatarURL = user.avatarUrl.flatMap { URL(string: $0) }
                let account = State.AccountState(
                    id: "default",
                    username: user.login,
                    avatarURL: avatarURL,
                    email: user.email
                )
                state.accounts = [account]
                return .none

            case let .currentUserLoadFailed(error):
                state.isLoadingUser = false
                state.userLoadError = error
                state.accounts = []
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

            case .focusScopes:
                return .none
            }
        }
    }
    // swiftformat:enable indent
}
