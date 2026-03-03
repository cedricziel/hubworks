import ComposableArchitecture
import Foundation
import SwiftData

/// Service for writing to SwiftData notification storage.
/// Views should use @Query for reactive reading.
@DependencyClient
public struct NotificationPersistenceService: Sendable {
    /// Upsert notifications from API response
    public var upsertFromAPI: @Sendable (_ notifications: [GitHubNotification], _ accountId: String) async throws -> Void

    /// Delete a notification by threadId
    public var delete: @Sendable (_ threadId: String) async throws -> Void

    /// Delete all notifications for an account
    public var deleteAllForAccount: @Sendable (_ accountId: String) async throws -> Void

    /// Delete all read states for an account
    public var deleteAllReadStatesForAccount: @Sendable (_ accountId: String) async throws -> Void

    /// Delete all sync states for an account
    public var deleteAllSyncStatesForAccount: @Sendable (_ accountId: String) async throws -> Void

    /// Mark notification as read
    public var markAsRead: @Sendable (_ threadId: String) async throws -> Void

    /// Mark all notifications as read for an account
    public var markAllAsRead: @Sendable (_ accountId: String) async throws -> Void

    /// Snooze a notification
    public var snooze: @Sendable (_ threadId: String, _ until: Date) async throws -> Void

    /// Unsnooze a notification
    public var unsnooze: @Sendable (_ threadId: String) async throws -> Void

    /// Archive a notification
    public var archive: @Sendable (_ threadId: String) async throws -> Void

    /// Unarchive a notification
    public var unarchive: @Sendable (_ threadId: String) async throws -> Void
}

extension NotificationPersistenceService: DependencyKey {
    public static var liveValue: NotificationPersistenceService {
        NotificationPersistenceService(
            upsertFromAPI: { notifications, accountId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let dateFormatter = ISO8601DateFormatter()

                    var hasChanges = false

                    for notification in notifications {
                        // Check if exists by threadId
                        let threadId = notification.id
                        let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                        let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                        let existing = try? context.fetch(descriptor)

                        if let existing = existing?.first {
                            // Only update fields that have actually changed
                            let newUpdatedAt = dateFormatter.date(from: notification.updatedAt) ?? .now

                            // Check if anything changed before updating
                            var recordChanged = false

                            if existing.unread != notification.unread {
                                existing.unread = notification.unread
                                recordChanged = true
                            }
                            if existing.updatedAt != newUpdatedAt {
                                existing.updatedAt = newUpdatedAt
                                recordChanged = true
                            }
                            if existing.subjectTitle != notification.subject.title {
                                existing.subjectTitle = notification.subject.title
                                recordChanged = true
                            }
                            if existing.subjectTypeRaw != notification.subject.type {
                                existing.subjectTypeRaw = notification.subject.type
                                recordChanged = true
                            }
                            if existing.subjectURL != notification.subject.url {
                                existing.subjectURL = notification.subject.url
                                recordChanged = true
                            }
                            if existing.latestCommentURL != notification.subject.latestCommentUrl {
                                existing.latestCommentURL = notification.subject.latestCommentUrl
                                recordChanged = true
                            }

                            // Only update fetchedAt if the record actually changed
                            if recordChanged {
                                existing.fetchedAt = Date.now
                                hasChanges = true
                            }
                        } else {
                            // Insert new
                            let cached = CachedNotification(
                                id: notification.id,
                                threadId: notification.id,
                                accountId: accountId,
                                unread: notification.unread,
                                reason: NotificationReason(rawValue: notification.reason) ?? .subscribed,
                                updatedAt: dateFormatter.date(from: notification.updatedAt) ?? .now,
                                lastReadAt: notification.lastReadAt.flatMap { dateFormatter.date(from: $0) },
                                subjectTitle: notification.subject.title,
                                subjectType: NotificationSubjectType(from: notification.subject.type),
                                subjectURL: notification.subject.url,
                                latestCommentURL: notification.subject.latestCommentUrl,
                                repositoryId: notification.repository.id,
                                repositoryName: notification.repository.name,
                                repositoryFullName: notification.repository.fullName,
                                repositoryOwner: notification.repository.owner.login,
                                repositoryAvatarURL: notification.repository.owner.avatarUrl,
                                isPrivateRepository: notification.repository.private
                            )
                            context.insert(cached)
                            hasChanges = true
                        }
                    }

                    // Only save if there were actual changes
                    if hasChanges {
                        try? context.save()
                    }
                }
            },

            delete: { threadId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let toDelete = (try? context.fetch(descriptor)) ?? []
                    for notification in toDelete {
                        context.delete(notification)
                    }
                    try? context.save()
                }
            },

            deleteAllForAccount: { accountId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.accountId == accountId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let toDelete = (try? context.fetch(descriptor)) ?? []
                    for notification in toDelete {
                        context.delete(notification)
                    }
                    try? context.save()
                }
            },

            deleteAllReadStatesForAccount: { accountId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<ReadState> { $0.accountId == accountId }
                    let descriptor = FetchDescriptor<ReadState>(predicate: predicate)

                    let toDelete = (try? context.fetch(descriptor)) ?? []
                    for readState in toDelete {
                        context.delete(readState)
                    }
                    try? context.save()
                }
            },

            deleteAllSyncStatesForAccount: { accountId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<SyncState> { $0.accountId == accountId }
                    let descriptor = FetchDescriptor<SyncState>(predicate: predicate)

                    let toDelete = (try? context.fetch(descriptor)) ?? []
                    for syncState in toDelete {
                        context.delete(syncState)
                    }
                    try? context.save()
                }
            },

            markAsRead: { threadId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.unread = false
                        notification.lastReadAt = Date.now
                    }
                    try? context.save()
                }
            },

            markAllAsRead: { accountId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> {
                        $0.accountId == accountId && $0.unread == true
                    }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.unread = false
                        notification.lastReadAt = Date.now
                    }
                    try? context.save()
                }
            },

            snooze: { threadId, until in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.isSnoozed = true
                        notification.snoozeUntil = until
                    }
                    try? context.save()
                }
            },

            unsnooze: { threadId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.isSnoozed = false
                        notification.snoozeUntil = nil
                    }
                    try? context.save()
                }
            },

            archive: { threadId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.isArchived = true
                    }
                    try? context.save()
                }
            },

            unarchive: { threadId in
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let predicate = #Predicate<CachedNotification> { $0.threadId == threadId }
                    let descriptor = FetchDescriptor<CachedNotification>(predicate: predicate)

                    let notifications = (try? context.fetch(descriptor)) ?? []
                    for notification in notifications {
                        notification.isArchived = false
                    }
                    try? context.save()
                }
            }
        )
    }

    public static let testValue = NotificationPersistenceService()
}

extension DependencyValues {
    public var notificationPersistence: NotificationPersistenceService {
        get { self[NotificationPersistenceService.self] }
        set { self[NotificationPersistenceService.self] = newValue }
    }
}
