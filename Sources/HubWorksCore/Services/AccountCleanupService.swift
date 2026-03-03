import ComposableArchitecture
import Foundation
import SwiftData

public struct AccountCleanupError: Error, Equatable, Sendable, LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }

    public static func dataCleanupFailed(_ underlying: Error) -> AccountCleanupError {
        AccountCleanupError(message: "Data cleanup failed: \(underlying.localizedDescription)")
    }

    public static func keychainDeleteFailed(_ key: String) -> AccountCleanupError {
        AccountCleanupError(message: "Failed to delete keychain token: \(key)")
    }
}

@DependencyClient
public struct AccountCleanupService: Sendable {
    /// Clean up all data for a specific account
    public var cleanupAccount: @Sendable (_ accountId: String) async throws -> Void

    /// Validate data integrity and clean up orphaned records
    public var validateAndCleanupOrphans: @Sendable () async throws -> Void
}

extension AccountCleanupService: DependencyKey {
    public static var liveValue: AccountCleanupService {
        AccountCleanupService(
            cleanupAccount: { accountId in
                @Dependency(\.notificationPersistence) var notificationPersistence
                @Dependency(\.keychainService) var keychainService

                // Delete all notifications for the account
                try await notificationPersistence.deleteAllForAccount(accountId)

                // Delete all read states for the account
                try await notificationPersistence.deleteAllReadStatesForAccount(accountId)

                // Delete all sync states for the account
                try await notificationPersistence.deleteAllSyncStatesForAccount(accountId)

                // Delete keychain token
                do {
                    try keychainService.delete("github_oauth_token_\(accountId)")
                } catch {
                    throw AccountCleanupError.keychainDeleteFailed("github_oauth_token_\(accountId)")
                }
            },

            validateAndCleanupOrphans: {
                @Dependency(\.keychainService) var keychainService

                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext

                    // Get all valid account IDs from keychain
                    // For now, we only support "default" account, but this is future-proof
                    var validAccountIds: Set<String> = []

                    // Check if default account exists
                    if keychainService.exists("github_oauth_token_default") {
                        validAccountIds.insert("default")
                    }

                    // IMPORTANT: Multi-device sync safety check
                    // If we have no local keychain tokens but DO have notifications,
                    // they likely came from CloudKit sync (another device).
                    // Don't delete them! The user needs to sign in to access them.
                    if validAccountIds.isEmpty {
                        let notificationDescriptor = FetchDescriptor<CachedNotification>()
                        let notificationCount = (try? context.fetchCount(notificationDescriptor)) ?? 0

                        if notificationCount > 0 {
                            print(
                                """
                                [AccountCleanupService] Found \(notificationCount) notifications but no local tokens. \
                                Likely synced from another device via CloudKit. Skipping cleanup.
                                """
                            )
                            return
                        }
                    }

                    // Only proceed with cleanup if we have local tokens or no data at all

                    // Find and delete orphaned notifications
                    let notificationDescriptor = FetchDescriptor<CachedNotification>()
                    if let allNotifications = try? context.fetch(notificationDescriptor) {
                        let orphanedNotifications = allNotifications.filter { notification in
                            !validAccountIds.contains(notification.accountId)
                        }

                        for notification in orphanedNotifications {
                            context.delete(notification)
                        }

                        if !orphanedNotifications.isEmpty {
                            print("[AccountCleanupService] Cleaned up \(orphanedNotifications.count) orphaned notifications")
                        }
                    }

                    // Find and delete orphaned read states
                    let readStateDescriptor = FetchDescriptor<ReadState>()
                    if let allReadStates = try? context.fetch(readStateDescriptor) {
                        let orphanedReadStates = allReadStates.filter { readState in
                            !validAccountIds.contains(readState.accountId)
                        }

                        for readState in orphanedReadStates {
                            context.delete(readState)
                        }

                        if !orphanedReadStates.isEmpty {
                            print("[AccountCleanupService] Cleaned up \(orphanedReadStates.count) orphaned read states")
                        }
                    }

                    // Find and delete orphaned sync states
                    let syncStateDescriptor = FetchDescriptor<SyncState>()
                    if let allSyncStates = try? context.fetch(syncStateDescriptor) {
                        let orphanedSyncStates = allSyncStates.filter { syncState in
                            !validAccountIds.contains(syncState.accountId)
                        }

                        for syncState in orphanedSyncStates {
                            context.delete(syncState)
                        }

                        if !orphanedSyncStates.isEmpty {
                            print("[AccountCleanupService] Cleaned up \(orphanedSyncStates.count) orphaned sync states")
                        }
                    }

                    // Save if there were any deletions
                    if context.hasChanges {
                        try? context.save()
                    }
                }
            }
        )
    }

    public static let testValue = AccountCleanupService()
}

extension DependencyValues {
    public var accountCleanupService: AccountCleanupService {
        get { self[AccountCleanupService.self] }
        set { self[AccountCleanupService.self] = newValue }
    }
}
