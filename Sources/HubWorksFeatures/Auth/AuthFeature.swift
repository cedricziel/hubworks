import ComposableArchitecture
import HubWorksCore
import SwiftUI

@Reducer
public struct AuthFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var isAuthenticating: Bool = false
        public var error: String?
        public var currentUser: GitHubUser?

        /// Device Flow state
        public var deviceFlowStatus: DeviceFlowState?

        public struct DeviceFlowState: Equatable, Sendable {
            public var userCode: String
            public var verificationUri: String
            public var expiresAt: Date

            public var isExpired: Bool {
                Date.now >= expiresAt
            }
        }

        public init(
            isAuthenticating: Bool = false,
            error: String? = nil,
            currentUser: GitHubUser? = nil,
            deviceFlowStatus: DeviceFlowState? = nil
        ) {
            self.isAuthenticating = isAuthenticating
            self.error = error
            self.currentUser = currentUser
            self.deviceFlowStatus = deviceFlowStatus
        }
    }

    public enum Action: Sendable {
        // Web Flow
        case signInTapped
        case signInCompleted(OAuthCredentials)
        case signInFailed(String)

        // Device Flow
        case signInWithDeviceFlowTapped
        case deviceFlowStatusUpdated(DeviceFlowStatus)

        // Common
        case authenticationCompleted(GitHubUser)
        case signOutTapped
        case signOutCompleted
        case clearError
        case cancelAuthTapped
    }

    @Dependency(\.oauthService) var oauthService
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.gitHubAPIClient) var gitHubAPIClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Web Flow

                case .signInTapped:
                    state.isAuthenticating = true
                    state.error = nil
                    state.deviceFlowStatus = nil

                    return .run { send in
                        do {
                            let credentials = try await oauthService.authorize(.default)
                            await send(.signInCompleted(credentials))
                        } catch let error as OAuthError {
                            switch error {
                                case .userCancelled:
                                    await send(.signInFailed("Sign in cancelled"))
                                default:
                                    await send(.signInFailed(error.localizedDescription))
                            }
                        } catch {
                            await send(.signInFailed(error.localizedDescription))
                        }
                    }

                case let .signInCompleted(credentials):
                    return .run { send in
                        do {
                            try keychainService.saveToken(
                                credentials.accessToken,
                                forKey: "github_oauth_token_default",
                                synchronizable: false // Disabled to avoid iCloud Keychain issues
                            )
                            let user = try await gitHubAPIClient.fetchCurrentUser(credentials.accessToken)
                            await send(.authenticationCompleted(user))
                        } catch {
                            await send(.signInFailed(error.localizedDescription))
                        }
                    }

                case let .signInFailed(error):
                    state.isAuthenticating = false
                    state.deviceFlowStatus = nil
                    state.error = error
                    return .none

            // MARK: - Device Flow

                case .signInWithDeviceFlowTapped:
                    state.isAuthenticating = true
                    state.error = nil
                    state.deviceFlowStatus = nil

                    return .run { send in
                        for await status in oauthService.authorizeWithDeviceFlow(.default) {
                            await send(.deviceFlowStatusUpdated(status))
                        }
                    }

                case let .deviceFlowStatusUpdated(status):
                    switch status {
                        case let .waitingForUser(userCode, verificationUri, expiresAt):
                            state.deviceFlowStatus = .init(
                                userCode: userCode,
                                verificationUri: verificationUri,
                                expiresAt: expiresAt
                            )
                            return .none

                        case let .authorized(credentials):
                            state.deviceFlowStatus = nil
                            return .send(.signInCompleted(credentials))

                        case .denied:
                            state.isAuthenticating = false
                            state.deviceFlowStatus = nil
                            state.error = "Access denied. Please try again."
                            return .none

                        case .expired:
                            state.isAuthenticating = false
                            state.deviceFlowStatus = nil
                            state.error = "Code expired. Please try again."
                            return .none

                        case let .error(message):
                            state.isAuthenticating = false
                            state.deviceFlowStatus = nil
                            state.error = message
                            return .none
                    }

            // MARK: - Common

                case let .authenticationCompleted(user):
                    state.isAuthenticating = false
                    state.currentUser = user
                    state.error = nil
                    state.deviceFlowStatus = nil
                    return .none

                case .signOutTapped:
                    return .run { send in
                        try? keychainService.delete("github_oauth_token_default")
                        await send(.signOutCompleted)
                    }

                case .signOutCompleted:
                    state.currentUser = nil
                    return .none

                case .clearError:
                    state.error = nil
                    return .none

                case .cancelAuthTapped:
                    state.isAuthenticating = false
                    state.deviceFlowStatus = nil
                    return .none
            }
        }
    }
}
