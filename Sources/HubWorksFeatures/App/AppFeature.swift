import ComposableArchitecture
import HubWorksCore
import SwiftUI

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .inbox
        public var inbox: InboxFeature.State
        public var settings: SettingsFeature.State
        public var auth: AuthFeature.State
        public var isAuthenticated: Bool = false
        public var isLoading: Bool = true

        public enum Tab: String, CaseIterable, Sendable {
            case inbox
            case settings
        }

        public init(
            selectedTab: Tab = .inbox,
            inbox: InboxFeature.State = .init(),
            settings: SettingsFeature.State = .init(),
            auth: AuthFeature.State = .init(),
            isAuthenticated: Bool = false,
            isLoading: Bool = true
        ) {
            self.selectedTab = selectedTab
            self.inbox = inbox
            self.settings = settings
            self.auth = auth
            self.isAuthenticated = isAuthenticated
            self.isLoading = isLoading
        }
    }

    public enum Action: Sendable {
        case onAppear
        case checkAuthenticationCompleted(Bool)
        case tabSelected(State.Tab)
        case inbox(InboxFeature.Action)
        case settings(SettingsFeature.Action)
        case auth(AuthFeature.Action)
        case backgroundRefreshTriggered
        case backgroundRefreshCompleted(Bool)
        case scenePhaseChanged(ScenePhase)
    }

    @Dependency(\.keychainService) private var keychainService
    @Dependency(\.backgroundRefreshManager) private var backgroundRefreshManager
    @Dependency(\.localNotificationService) private var localNotificationService
    @Dependency(\.accountCleanupService) private var accountCleanupService

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.inbox, action: \.inbox) {
            InboxFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }

        Reduce { state, action in
            switch action {
                case .onAppear:
                    return .run { send in
                        // Clean up any orphaned data from previous sessions or bundle ID changes
                        try? await accountCleanupService.validateAndCleanupOrphans()

                        // Check if we have any stored tokens
                        let hasToken = keychainService.exists("github_oauth_token_default")
                        await send(.checkAuthenticationCompleted(hasToken))
                    }

                case let .checkAuthenticationCompleted(isAuthenticated):
                    state.isAuthenticated = isAuthenticated
                    state.isLoading = false

                    if isAuthenticated {
                        return .send(.inbox(.startPolling))
                    }
                    return .none

                case let .tabSelected(tab):
                    state.selectedTab = tab
                    return .none

                case .inbox:
                    return .none

                case .settings:
                    return .none

                case .auth(.authenticationCompleted):
                    state.isAuthenticated = true
                    return .send(.inbox(.startPolling))

                case .auth(.signOutCompleted):
                    state.isAuthenticated = false
                    state.inbox = .init()
                    return .none

                case .auth:
                    return .none

                case .backgroundRefreshTriggered:
                    return .run { send in
                        // Trigger background poll
                        await send(.inbox(.pollNow))
                        await send(.backgroundRefreshCompleted(true))
                    }

                case .backgroundRefreshCompleted:
                    return .none

                case let .scenePhaseChanged(phase):
                    // Check for Focus scope changes when app becomes active
                    switch phase {
                        case .active:
                            return .send(.inbox(.checkActiveFocusScope))
                        case .background, .inactive:
                            return .none
                        @unknown default:
                            return .none
                    }
            }
        }
    }
}
