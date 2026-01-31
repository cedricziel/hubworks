import ComposableArchitecture
import Foundation
import SwiftData

/// Result yielded for each page of notifications during polling
public struct PollingPageResult: Sendable {
    public let notifications: [GitHubNotification]
    public let isFirstPage: Bool
    public let hasMorePages: Bool
    public let lastModified: String?
    public let rateLimit: RateLimitInfo?

    public init(
        notifications: [GitHubNotification],
        isFirstPage: Bool,
        hasMorePages: Bool,
        lastModified: String?,
        rateLimit: RateLimitInfo? = nil
    ) {
        self.notifications = notifications
        self.isFirstPage = isFirstPage
        self.hasMorePages = hasMorePages
        self.lastModified = lastModified
        self.rateLimit = rateLimit
    }
}

@DependencyClient
public struct NotificationPollingService: Sendable {
    /// Start polling, yielding pages progressively for immediate UI updates
    public var startPolling: @Sendable (_ interval: TimeInterval) -> AsyncStream<PollingPageResult> = { _ in .finished }
    public var stopPolling: @Sendable () -> Void
    /// Poll now, yielding pages progressively
    public var pollNow: @Sendable () -> AsyncThrowingStream<PollingPageResult, Error> = {
        AsyncThrowingStream { $0.finish() }
    }
}

/// Sendable struct to hold sync state data
public struct SyncStateData: Sendable {
    public let lastModified: String?
    public let pollInterval: Int

    public init(lastModified: String?, pollInterval: Int) {
        self.lastModified = lastModified
        self.pollInterval = pollInterval
    }
}

extension NotificationPollingService: DependencyKey {
    public static let liveValue: NotificationPollingService = {
        nonisolated(unsafe) var isPolling = false

        /// Load sync state from SwiftData - returns Sendable data
        @Sendable
        func loadSyncState(accountId: String) async -> SyncStateData? {
            await MainActor.run {
                let container = HubWorksCore.modelContainer
                let context = container.mainContext
                let predicate = #Predicate<SyncState> { $0.accountId == accountId }
                let descriptor = FetchDescriptor<SyncState>(predicate: predicate)
                guard let state = try? context.fetch(descriptor).first else {
                    return nil
                }
                return SyncStateData(
                    lastModified: state.lastModified,
                    pollInterval: state.pollInterval
                )
            }
        }

        /// Save sync state to SwiftData
        @Sendable
        func saveSyncState(accountId: String, lastModified: String?, pollInterval: Int?) async {
            await MainActor.run {
                let container = HubWorksCore.modelContainer
                let context = container.mainContext
                let predicate = #Predicate<SyncState> { $0.accountId == accountId }
                let descriptor = FetchDescriptor<SyncState>(predicate: predicate)

                if let existing = try? context.fetch(descriptor).first {
                    existing.lastModified = lastModified
                    existing.lastPolledAt = Date.now
                    if let pollInterval {
                        existing.pollInterval = pollInterval
                    }
                } else {
                    let newState = SyncState(
                        accountId: accountId,
                        lastModified: lastModified,
                        lastPolledAt: Date.now,
                        pollInterval: pollInterval ?? 60
                    )
                    context.insert(newState)
                }
                try? context.save()
            }
        }

        return NotificationPollingService(
            startPolling: { _ in
                AsyncStream { continuation in
                    let task = Task { @Sendable in
                        @Dependency(\.gitHubAPIClient) var gitHubAPIClient
                        @Dependency(\.keychainService) var keychainService

                        isPolling = true
                        let accountId = "default"

                        // Load persisted sync state
                        let syncState = await loadSyncState(accountId: accountId)
                        var lastModified = syncState?.lastModified

                        // Initial fetch immediately
                        do {
                            guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                isPolling = false
                                continuation.finish()
                                return
                            }

                            // Stream pages progressively
                            for try await page in gitHubAPIClient.fetchNotificationsStream(token, lastModified, true, false) {
                                // Update lastModified from first page
                                if page.isFirstPage, let newLastModified = page.lastModified {
                                    lastModified = newLastModified
                                    await saveSyncState(
                                        accountId: accountId,
                                        lastModified: newLastModified,
                                        pollInterval: page.pollInterval
                                    )
                                }

                                // Yield each page for immediate UI update
                                continuation.yield(PollingPageResult(
                                    notifications: page.notifications,
                                    isFirstPage: page.isFirstPage,
                                    hasMorePages: page.hasMorePages,
                                    lastModified: page.lastModified,
                                    rateLimit: page.rateLimit
                                ))
                            }
                        } catch {
                            // Continue even on error
                        }

                        // Then poll periodically
                        while isPolling, !Task.isCancelled {
                            do {
                                // Load latest sync state (might have been updated by another device)
                                let currentSyncState = await loadSyncState(accountId: accountId)
                                let currentLastModified = currentSyncState?.lastModified ?? lastModified
                                let pollWait = TimeInterval(currentSyncState?.pollInterval ?? 60)

                                try await Task.sleep(for: .seconds(pollWait))

                                guard let token = try keychainService.loadToken(forKey: "github_oauth_token_default") else {
                                    break
                                }

                                // Stream pages progressively
                                for try await page in gitHubAPIClient.fetchNotificationsStream(token, currentLastModified, true, false) {
                                    // Update lastModified from first page
                                    if page.isFirstPage, let newLastModified = page.lastModified {
                                        lastModified = newLastModified
                                        await saveSyncState(
                                            accountId: accountId,
                                            lastModified: newLastModified,
                                            pollInterval: page.pollInterval
                                        )
                                    }

                                    // Only yield if there are notifications (304 Not Modified returns empty)
                                    if !page.notifications.isEmpty {
                                        continuation.yield(PollingPageResult(
                                            notifications: page.notifications,
                                            isFirstPage: page.isFirstPage,
                                            hasMorePages: page.hasMorePages,
                                            lastModified: page.lastModified,
                                            rateLimit: page.rateLimit
                                        ))
                                    }
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
                AsyncThrowingStream { continuation in
                    Task {
                        @Dependency(\.gitHubAPIClient) var gitHubAPIClient
                        @Dependency(\.keychainService) var keychainService

                        let accountId = "default"

                        // Load persisted sync state
                        let syncState = await loadSyncState(accountId: accountId)
                        let lastModified = syncState?.lastModified

                        guard let token = try? keychainService.loadToken(forKey: "github_oauth_token_default") else {
                            continuation.finish()
                            return
                        }

                        do {
                            for try await page in gitHubAPIClient.fetchNotificationsStream(token, lastModified, true, false) {
                                // Update sync state from first page
                                if page.isFirstPage, let newLastModified = page.lastModified {
                                    await saveSyncState(
                                        accountId: accountId,
                                        lastModified: newLastModified,
                                        pollInterval: page.pollInterval
                                    )
                                }

                                continuation.yield(PollingPageResult(
                                    notifications: page.notifications,
                                    isFirstPage: page.isFirstPage,
                                    hasMorePages: page.hasMorePages,
                                    lastModified: page.lastModified,
                                    rateLimit: page.rateLimit
                                ))
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
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
