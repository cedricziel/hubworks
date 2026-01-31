import AuthenticationServices
import ComposableArchitecture
import CryptoKit
import Foundation

#if os(macOS)
import AppKit

/// Manages ASWebAuthenticationSession presentation on macOS
/// Stored statically to ensure it lives for the duration of auth
@MainActor
enum WebAuthManager {
    private final class Presenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        @MainActor
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            // Ensure we're on main thread and app is active
            NSApp.activate(ignoringOtherApps: true)

            // Try to get a valid window
            if let window = NSApp.keyWindow, window.isVisible {
                return window
            }
            if let window = NSApp.mainWindow, window.isVisible {
                return window
            }
            for window in NSApp.windows where window.isVisible && window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return window
            }

            // This should not happen if app has a proper window
            fatalError("No window available for authentication")
        }
    }

    /// Static storage to keep presenter alive during auth
    nonisolated(unsafe) private static var currentPresenter: Presenter?

    static func startSession(_ session: ASWebAuthenticationSession) {
        let presenter = Presenter()
        currentPresenter = presenter
        session.presentationContextProvider = presenter
        session.start()
    }

    static func cleanup() {
        currentPresenter = nil
    }
}

#elseif os(iOS)
import UIKit

/// Manages ASWebAuthenticationSession presentation on iOS
/// Stored statically to ensure it lives for the duration of auth
@MainActor
enum WebAuthManager {
    private final class Presenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        @MainActor
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            // Get the key window from the active scene
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let window = windowScene.windows.first(where: { $0.isKeyWindow })
            else {
                // Fallback: try to find any visible window
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first,
                    let window = windowScene.windows.first
                {
                    return window
                }
                fatalError("No window available for authentication")
            }
            return window
        }
    }

    /// Static storage to keep presenter alive during auth
    nonisolated(unsafe) private static var currentPresenter: Presenter?

    static func startSession(_ session: ASWebAuthenticationSession) {
        let presenter = Presenter()
        currentPresenter = presenter
        session.presentationContextProvider = presenter
        session.start()
    }

    static func cleanup() {
        currentPresenter = nil
    }
}
#endif

// MARK: - OAuth Credentials

public struct OAuthCredentials: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Device Flow Types

/// Response from GitHub's device code request
public struct DeviceCodeResponse: Codable, Equatable, Sendable {
    /// The device verification code (used internally for polling)
    public let deviceCode: String
    /// The user verification code to display to the user
    public let userCode: String
    /// The URL where the user should enter the code
    public let verificationUri: String
    /// Optional direct URL with code pre-filled
    public let verificationUriComplete: String?
    /// Seconds until the codes expire
    public let expiresIn: Int
    /// Minimum seconds to wait between polling attempts
    public let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
    }
}

/// Status updates during device flow polling
public enum DeviceFlowStatus: Equatable, Sendable {
    /// Waiting for user to enter code
    case waitingForUser(userCode: String, verificationUri: String, expiresAt: Date)
    /// User authorized, token received
    case authorized(OAuthCredentials)
    /// User denied access
    case denied
    /// Code expired before user completed auth
    case expired
    /// An error occurred
    case error(String)
}

// MARK: - Configuration

public struct OAuthConfiguration: Equatable, Sendable {
    public let clientId: String
    public let clientSecret: String?
    public let redirectURI: String
    public let scopes: [String]

    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectURI: String = "hubworks://oauth/callback",
        scopes: [String] = ["notifications", "read:user", "repo"]
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    /// Loads configuration from Info.plist
    public static func fromInfoPlist() throws -> OAuthConfiguration {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GitHubClientID") as? String,
              !clientId.isEmpty,
              clientId != "YOUR_GITHUB_CLIENT_ID_HERE"
        else {
            throw OAuthError.configurationMissing
        }
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "GitHubClientSecret") as? String
        return OAuthConfiguration(clientId: clientId, clientSecret: clientSecret)
    }

    /// Default configuration loaded from Info.plist
    public static var `default`: OAuthConfiguration {
        (try? fromInfoPlist()) ?? OAuthConfiguration(clientId: "MISSING_CLIENT_ID")
    }
}

// MARK: - Errors

public enum OAuthError: Error, Equatable, Sendable, LocalizedError {
    case configurationMissing
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case invalidCallbackURL
    case invalidState
    case userCancelled
    // Device Flow errors
    case deviceFlowNotEnabled
    case authorizationPending
    case slowDown
    case accessDenied
    case expiredToken

    public var errorDescription: String? {
        switch self {
            case .configurationMissing:
                "GitHub OAuth is not configured. Please set GITHUB_CLIENT_ID."
            case let .authorizationFailed(message):
                "Authorization failed: \(message)"
            case let .tokenExchangeFailed(message):
                "Token exchange failed: \(message)"
            case .invalidCallbackURL:
                "Invalid callback URL from GitHub"
            case .invalidState:
                "Security validation failed (state mismatch)"
            case .userCancelled:
                "Sign in was cancelled"
            case .deviceFlowNotEnabled:
                "Device flow is not enabled for this OAuth app"
            case .authorizationPending:
                "Waiting for authorization..."
            case .slowDown:
                "Too many requests, slowing down..."
            case .accessDenied:
                "Access was denied"
            case .expiredToken:
                "The authorization code has expired"
        }
    }
}

// MARK: - OAuth Service

@DependencyClient
public struct OAuthService: Sendable {
    // MARK: Web Flow (PKCE)

    /// Authorize using web-based OAuth flow with PKCE (iOS/macOS)
    public var authorize: @Sendable (_ configuration: OAuthConfiguration) async throws -> OAuthCredentials

    /// Exchange authorization code for token
    public var exchangeCode: @Sendable (
        _ code: String,
        _ codeVerifier: String,
        _ configuration: OAuthConfiguration
    ) async throws -> OAuthCredentials

    // MARK: Device Flow

    /// Request a device code for Device Flow authorization
    public var requestDeviceCode: @Sendable (_ configuration: OAuthConfiguration) async throws -> DeviceCodeResponse

    /// Poll for token after user enters device code (returns async stream of status updates)
    public var pollForDeviceToken: @Sendable (
        _ deviceCode: String,
        _ interval: Int,
        _ expiresIn: Int,
        _ configuration: OAuthConfiguration
    ) -> AsyncStream<DeviceFlowStatus> = { _, _, _, _ in .finished }

    /// Authorize using Device Flow (combines requestDeviceCode + pollForDeviceToken)
    public var authorizeWithDeviceFlow: @Sendable (_ configuration: OAuthConfiguration) -> AsyncStream<DeviceFlowStatus> = { _ in
        .finished
    }
}

// MARK: - Live Implementation

extension OAuthService: DependencyKey {
    public static let liveValue: OAuthService = {
        // PKCE State Actor
        actor PKCEState {
            var codeVerifier: String?
            var state: String?

            func generate() -> (verifier: String, challenge: String, state: String) {
                let verifier = Self.generateCodeVerifier()
                let challenge = Self.generateCodeChallenge(from: verifier)
                let state = UUID().uuidString

                self.codeVerifier = verifier
                self.state = state

                return (verifier, challenge, state)
            }

            func validate(state: String) -> String? {
                guard state == self.state else { return nil }
                defer {
                    self.codeVerifier = nil
                    self.state = nil
                }
                return codeVerifier
            }

            private static func generateCodeVerifier() -> String {
                var bytes = [UInt8](repeating: 0, count: 32)
                _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                return Data(bytes).base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }

            private static func generateCodeChallenge(from verifier: String) -> String {
                let data = Data(verifier.utf8)
                let hash = SHA256.hash(data: data)
                return Data(hash).base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
        }

        let pkceState = PKCEState()

        return OAuthService(

            // MARK: Web Flow Authorization

            authorize: { configuration in
                let (verifier, challenge, state) = await pkceState.generate()

                var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
                components.queryItems = [
                    URLQueryItem(name: "client_id", value: configuration.clientId),
                    URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
                    URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
                    URLQueryItem(name: "state", value: state),
                    URLQueryItem(name: "code_challenge", value: challenge),
                    URLQueryItem(name: "code_challenge_method", value: "S256"),
                ]

                guard let authURL = components.url else {
                    throw OAuthError.authorizationFailed("Invalid authorization URL")
                }

                let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                    let session = ASWebAuthenticationSession(
                        url: authURL,
                        callbackURLScheme: "hubworks"
                    ) { callbackURL, error in
                        if let error = error as? ASWebAuthenticationSessionError {
                            switch error.code {
                                case .canceledLogin:
                                    continuation.resume(throwing: OAuthError.userCancelled)
                                default:
                                    continuation.resume(throwing: OAuthError.authorizationFailed(error.localizedDescription))
                            }
                            return
                        }

                        if let error {
                            continuation.resume(throwing: OAuthError.authorizationFailed(error.localizedDescription))
                            return
                        }

                        guard let callbackURL else {
                            continuation.resume(throwing: OAuthError.invalidCallbackURL)
                            return
                        }

                        continuation.resume(returning: callbackURL)
                    }

                    session.prefersEphemeralWebBrowserSession = false

                    #if os(macOS) || os(iOS)
                    DispatchQueue.main.async {
                        WebAuthManager.startSession(session)
                    }
                    #else
                    session.start()
                    #endif
                }

                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
                else {
                    throw OAuthError.invalidCallbackURL
                }

                guard let verifier = await pkceState.validate(state: returnedState) else {
                    throw OAuthError.invalidState
                }

                let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!
                var request = URLRequest(url: tokenURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                // Send parameters in POST body, not URL
                var bodyParamsList = [
                    "client_id=\(configuration.clientId)",
                    "code=\(code)",
                    "redirect_uri=\(configuration.redirectURI)",
                    "code_verifier=\(verifier)",
                ]
                // Add client_secret for traditional OAuth Apps
                if let clientSecret = configuration.clientSecret, !clientSecret.isEmpty {
                    bodyParamsList.append("client_secret=\(clientSecret)")
                }
                let bodyParams = bodyParamsList.joined(separator: "&")
                request.httpBody = bodyParams.data(using: .utf8)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OAuthError.tokenExchangeFailed("Invalid response")
                }

                // Check for error response from GitHub
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? String
                {
                    let description = errorJson["error_description"] as? String ?? error
                    throw OAuthError.tokenExchangeFailed(description)
                }

                guard httpResponse.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw OAuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(body)")
                }

                do {
                    return try JSONDecoder().decode(OAuthCredentials.self, from: data)
                } catch {
                    let body = String(data: data, encoding: .utf8) ?? "Unable to read response"
                    throw OAuthError.tokenExchangeFailed("Failed to decode: \(body)")
                }
            },

            // MARK: Exchange Code

            exchangeCode: { code, codeVerifier, configuration in
                let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!

                var request = URLRequest(url: tokenURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                var bodyParamsList = [
                    "client_id=\(configuration.clientId)",
                    "code=\(code)",
                    "redirect_uri=\(configuration.redirectURI)",
                    "code_verifier=\(codeVerifier)",
                ]
                if let clientSecret = configuration.clientSecret, !clientSecret.isEmpty {
                    bodyParamsList.append("client_secret=\(clientSecret)")
                }
                request.httpBody = bodyParamsList.joined(separator: "&").data(using: .utf8)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else {
                    throw OAuthError.tokenExchangeFailed("Token exchange failed")
                }

                return try JSONDecoder().decode(OAuthCredentials.self, from: data)
            },

            // MARK: Device Flow - Request Code

            requestDeviceCode: { configuration in
                let url = URL(string: "https://github.com/login/device/code")!

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                let body = "client_id=\(configuration.clientId)&scope=\(configuration.scopes.joined(separator: " "))"
                request.httpBody = body.data(using: .utf8)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OAuthError.authorizationFailed("Invalid response")
                }

                guard httpResponse.statusCode == 200 else {
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        throw OAuthError.authorizationFailed("Device flow error: \(errorResponse)")
                    }
                    throw OAuthError.deviceFlowNotEnabled
                }

                return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
            },

            // MARK: Device Flow - Poll for Token

            pollForDeviceToken: { deviceCode, interval, expiresIn, configuration in
                AsyncStream { continuation in
                    Task {
                        let expiresAt = Date.now.addingTimeInterval(TimeInterval(expiresIn))
                        var currentInterval = TimeInterval(interval)

                        while Date.now < expiresAt {
                            try? await Task.sleep(for: .seconds(currentInterval))

                            if Task.isCancelled {
                                continuation.finish()
                                return
                            }

                            let url = URL(string: "https://github.com/login/oauth/access_token")!
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.setValue("application/json", forHTTPHeaderField: "Accept")
                            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                            let grantType = "urn:ietf:params:oauth:grant-type:device_code"
                            let body = "client_id=\(configuration.clientId)&device_code=\(deviceCode)&grant_type=\(grantType)"
                            request.httpBody = body.data(using: .utf8)

                            do {
                                let (data, _) = try await URLSession.shared.data(for: request)

                                // Try to decode as credentials first
                                if let credentials = try? JSONDecoder().decode(OAuthCredentials.self, from: data) {
                                    continuation.yield(.authorized(credentials))
                                    continuation.finish()
                                    return
                                }

                                // Try to decode as error response
                                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let error = json["error"] as? String
                                {
                                    switch error {
                                        case "authorization_pending":
                                            // User hasn't entered code yet, continue polling
                                            continue

                                        case "slow_down":
                                            // Increase polling interval
                                            currentInterval += 5
                                            continue

                                        case "expired_token":
                                            continuation.yield(.expired)
                                            continuation.finish()
                                            return

                                        case "access_denied":
                                            continuation.yield(.denied)
                                            continuation.finish()
                                            return

                                        default:
                                            let description = json["error_description"] as? String ?? error
                                            continuation.yield(.error(description))
                                            continuation.finish()
                                            return
                                    }
                                }
                            } catch {
                                continuation.yield(.error(error.localizedDescription))
                                continuation.finish()
                                return
                            }
                        }

                        // Expired
                        continuation.yield(.expired)
                        continuation.finish()
                    }
                }
            },

            // MARK: Device Flow - Full Authorization

            authorizeWithDeviceFlow: { configuration in
                AsyncStream { continuation in
                    Task {
                        do {
                            // Step 1: Request device code
                            let url = URL(string: "https://github.com/login/device/code")!
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.setValue("application/json", forHTTPHeaderField: "Accept")
                            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                            let body = "client_id=\(configuration.clientId)&scope=\(configuration.scopes.joined(separator: " "))"
                            request.httpBody = body.data(using: .utf8)

                            let (data, response) = try await URLSession.shared.data(for: request)

                            guard let httpResponse = response as? HTTPURLResponse,
                                  httpResponse.statusCode == 200
                            else {
                                continuation.yield(.error("Failed to request device code"))
                                continuation.finish()
                                return
                            }

                            let deviceCodeResponse = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
                            let expiresAt = Date.now.addingTimeInterval(TimeInterval(deviceCodeResponse.expiresIn))

                            // Step 2: Notify user to enter code
                            continuation.yield(.waitingForUser(
                                userCode: deviceCodeResponse.userCode,
                                verificationUri: deviceCodeResponse.verificationUri,
                                expiresAt: expiresAt
                            ))

                            // Step 3: Poll for token
                            var currentInterval = TimeInterval(deviceCodeResponse.interval)

                            while Date.now < expiresAt {
                                try await Task.sleep(for: .seconds(currentInterval))

                                if Task.isCancelled {
                                    continuation.finish()
                                    return
                                }

                                let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!
                                var tokenRequest = URLRequest(url: tokenURL)
                                tokenRequest.httpMethod = "POST"
                                tokenRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                                tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                                let grantType = "urn:ietf:params:oauth:grant-type:device_code"
                                let clientId = configuration.clientId
                                let deviceCode = deviceCodeResponse.deviceCode
                                let tokenBody = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=\(grantType)"
                                tokenRequest.httpBody = tokenBody.data(using: .utf8)

                                let (tokenData, _) = try await URLSession.shared.data(for: tokenRequest)

                                // Try to decode as credentials
                                if let credentials = try? JSONDecoder().decode(OAuthCredentials.self, from: tokenData) {
                                    continuation.yield(.authorized(credentials))
                                    continuation.finish()
                                    return
                                }

                                // Try to decode as error
                                if let json = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
                                   let error = json["error"] as? String
                                {
                                    switch error {
                                        case "authorization_pending":
                                            continue
                                        case "slow_down":
                                            currentInterval += 5
                                            continue
                                        case "expired_token":
                                            continuation.yield(.expired)
                                            continuation.finish()
                                            return
                                        case "access_denied":
                                            continuation.yield(.denied)
                                            continuation.finish()
                                            return
                                        default:
                                            let description = json["error_description"] as? String ?? error
                                            continuation.yield(.error(description))
                                            continuation.finish()
                                            return
                                    }
                                }
                            }

                            continuation.yield(.expired)
                            continuation.finish()
                        } catch {
                            continuation.yield(.error(error.localizedDescription))
                            continuation.finish()
                        }
                    }
                }
            }
        )
    }()

    public static let testValue = OAuthService()
}

// MARK: - Dependency Values

extension DependencyValues {
    public var oauthService: OAuthService {
        get { self[OAuthService.self] }
        set { self[OAuthService.self] = newValue }
    }
}
