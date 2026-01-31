import ComposableArchitecture
import Foundation

@DependencyClient
public struct NotificationPollingService: Sendable {
    public var startPolling: @Sendable (_ interval: TimeInterval) -> AsyncStream<[GitHubNotification]> = { _ in .finished }
    public var stopPolling: @Sendable () -> Void
    public var pollNow: @Sendable () async throws -> [GitHubNotification]
}

extension NotificationPollingService: DependencyKey {
    public static let liveValue: NotificationPollingService = {
        // Use nonisolated(unsafe) for mutable state - we manage thread safety manually
        nonisolated(unsafe) var isPolling = false
        nonisolated(unsafe) var lastModified: String?

        return NotificationPollingService(
            startPolling: { interval in
                AsyncStream { continuation in
                    let task = Task { @Sendable in
                        @Dependency(\.gitHubAPIClient) var gitHubAPIClient
                        @Dependency(\.keychainService) var keychainService

                        isPolling = true

                        // Initial fetch immediately
                        do {
                            guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                isPolling = false
                                continuation.finish()
                                return
                            }

                            let result = try await gitHubAPIClient.fetchNotifications(token, lastModified, false, false)
                            lastModified = result.lastModified
                            continuation.yield(result.notifications)
                        } catch {
                            // Continue even on error, yield empty
                            continuation.yield([])
                        }

                        // Then poll periodically
                        while isPolling && !Task.isCancelled {
                            do {
                                try await Task.sleep(for: .seconds(interval))

                                guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                    break
                                }

                                let result = try await gitHubAPIClient.fetchNotifications(token, lastModified, false, false)

                                if result.wasModified {
                                    lastModified = result.lastModified
                                    continuation.yield(result.notifications)
                                }
                            } catch {
                                // On error, continue polling
                            }
                        }

                        isPolling = false
                        continuation.finish()
                    }

                    continuation.onTermination = { _ in
                        task.cancel()
                        isPolling = false
                    }
                }
            },

            stopPolling: {
                isPolling = false
            },

            pollNow: {
                @Dependency(\.gitHubAPIClient) var gitHubAPIClient
                @Dependency(\.keychainService) var keychainService

                guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                    return []
                }

                let result = try await gitHubAPIClient.fetchNotifications(token, nil, false, false)
                return result.notifications
            }
        )
    }()

    public static let testValue = NotificationPollingService()
}

extension DependencyValues {
    public var notificationPollingService: NotificationPollingService {
        get { self[NotificationPollingService.self] }
        set { self[NotificationPollingService.self] = newValue }
    }
}
