import ComposableArchitecture
import Foundation
import SwiftData
import UserNotifications

public struct NotificationContent: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let subtitle: String?
    public let threadId: String
    public let categoryId: String?
    public let userInfo: [String: String]
    public let playSound: Bool
    public let repositoryFullName: String
    public let repositoryOwner: String
    public let reason: String

    public init(
        id: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        threadId: String,
        categoryId: String? = nil,
        userInfo: [String: String] = [:],
        playSound: Bool = true,
        repositoryFullName: String,
        repositoryOwner: String,
        reason: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.threadId = threadId
        self.categoryId = categoryId
        self.userInfo = userInfo
        self.playSound = playSound
        self.repositoryFullName = repositoryFullName
        self.repositoryOwner = repositoryOwner
        self.reason = reason
    }
}

public enum NotificationCategoryIdentifier: String, Sendable {
    case notification = "NOTIFICATION"
    case mentionNotification = "MENTION_NOTIFICATION"
    case reviewRequestNotification = "REVIEW_REQUEST_NOTIFICATION"
}

public enum NotificationActionIdentifier: String, Sendable {
    case markRead = "MARK_READ"
    case snooze = "SNOOZE"
    case archive = "ARCHIVE"
    case open = "OPEN"
}

@DependencyClient
public struct LocalNotificationService: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var getAuthorizationStatus: @Sendable () async -> UNAuthorizationStatus = { .notDetermined }
    public var scheduleNotification: @Sendable (_ content: NotificationContent) async throws -> Void
    public var removeNotification: @Sendable (_ id: String) async -> Void
    public var removeAllNotifications: @Sendable () async -> Void
    public var registerCategories: @Sendable () async -> Void
}

extension LocalNotificationService: DependencyKey {
    public static let liveValue = LocalNotificationService(
        requestAuthorization: {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        },

        getAuthorizationStatus: {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        },

        scheduleNotification: { content in
            // Check if notification should be delivered based on active Focus scope
            let shouldDeliver = await checkNotificationMatchesActiveScope(content)
            guard shouldDeliver else {
                return // Don't deliver - doesn't match active Focus scope
            }

            // Proceed with normal notification delivery
            let notificationContent = UNMutableNotificationContent()
            notificationContent.title = content.title
            notificationContent.body = content.body

            if let subtitle = content.subtitle {
                notificationContent.subtitle = subtitle
            }

            notificationContent.threadIdentifier = content.threadId

            if content.playSound {
                notificationContent.sound = .default
            }

            if let categoryId = content.categoryId {
                notificationContent.categoryIdentifier = categoryId
            }

            var userInfo: [String: Any] = [:]
            for (key, value) in content.userInfo {
                userInfo[key] = value
            }
            notificationContent.userInfo = userInfo

            let request = UNNotificationRequest(
                identifier: content.id,
                content: notificationContent,
                trigger: nil
            )

            try await UNUserNotificationCenter.current().add(request)
        },

        removeNotification: { id in
            let center = UNUserNotificationCenter.current()
            center.removeDeliveredNotifications(withIdentifiers: [id])
            center.removePendingNotificationRequests(withIdentifiers: [id])
        },

        removeAllNotifications: {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
        },

        registerCategories: {
            let markReadAction = UNNotificationAction(
                identifier: NotificationActionIdentifier.markRead.rawValue,
                title: "Mark as Read",
                options: []
            )

            let snoozeAction = UNNotificationAction(
                identifier: NotificationActionIdentifier.snooze.rawValue,
                title: "Snooze 1 Hour",
                options: []
            )

            let archiveAction = UNNotificationAction(
                identifier: NotificationActionIdentifier.archive.rawValue,
                title: "Archive",
                options: .destructive
            )

            let openAction = UNNotificationAction(
                identifier: NotificationActionIdentifier.open.rawValue,
                title: "Open",
                options: .foreground
            )

            let notificationCategory = UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.notification.rawValue,
                actions: [markReadAction, snoozeAction, archiveAction, openAction],
                intentIdentifiers: [],
                options: []
            )

            let mentionCategory = UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.mentionNotification.rawValue,
                actions: [openAction, snoozeAction, archiveAction],
                intentIdentifiers: [],
                options: []
            )

            let reviewCategory = UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.reviewRequestNotification.rawValue,
                actions: [openAction, snoozeAction, archiveAction],
                intentIdentifiers: [],
                options: []
            )

            UNUserNotificationCenter.current().setNotificationCategories([
                notificationCategory,
                mentionCategory,
                reviewCategory,
            ])
        }
    )

    public static let testValue = LocalNotificationService()
}

extension DependencyValues {
    public var localNotificationService: LocalNotificationService {
        get { self[LocalNotificationService.self] }
        set { self[LocalNotificationService.self] = newValue }
    }
}

// MARK: - Helper Functions

@MainActor
private func checkNotificationMatchesActiveScope(_ content: NotificationContent) async -> Bool {
    // Check if there's an active Focus scope
    let activeScopeId = UserDefaults.standard.string(forKey: "active_focus_scope_id")

    guard let activeScopeId else {
        return true // No active scope, deliver notification
    }

    // Load active scope and check if notification matches
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    let predicate = #Predicate<NotificationScope> { $0.id == activeScopeId }
    let descriptor = FetchDescriptor<NotificationScope>(predicate: predicate)

    guard let activeScope = try? context.fetch(descriptor).first else {
        return true // Scope not found, deliver notification
    }

    // Create a temporary CachedNotification to check against scope rules
    let notificationReason = NotificationReason(rawValue: content.reason) ?? .subscribed
    let tempNotification = CachedNotification(
        id: content.id,
        threadId: content.threadId,
        accountId: "",
        unread: true,
        reason: notificationReason,
        updatedAt: Date(),
        lastReadAt: nil,
        subjectTitle: content.body,
        subjectType: .issue,
        subjectURL: nil,
        latestCommentURL: nil,
        repositoryId: 0,
        repositoryName: "",
        repositoryFullName: content.repositoryFullName,
        repositoryOwner: content.repositoryOwner,
        repositoryAvatarURL: nil,
        isPrivateRepository: false
    )

    // Check if notification matches the active scope
    return activeScope.matchesNotification(tempNotification)
}

extension LocalNotificationService {
    public func notificationContent(
        from notification: CachedNotification,
        accountUsername: String
    ) -> NotificationContent {
        let title: String
        let categoryId: String

        switch notification.reason {
            case .mention, .teamMention:
                title = "@\(accountUsername) mentioned in \(notification.repositoryFullName)"
                categoryId = NotificationCategoryIdentifier.mentionNotification.rawValue
            case .reviewRequested:
                title = "Review requested in \(notification.repositoryFullName)"
                categoryId = NotificationCategoryIdentifier.reviewRequestNotification.rawValue
            case .assign:
                title = "Assigned to you in \(notification.repositoryFullName)"
                categoryId = NotificationCategoryIdentifier.notification.rawValue
            default:
                title = notification.repositoryFullName
                categoryId = NotificationCategoryIdentifier.notification.rawValue
        }

        return NotificationContent(
            id: notification.threadId,
            title: title,
            body: notification.subjectTitle,
            subtitle: notification.subjectType.displayName,
            threadId: "github-\(notification.repositoryFullName)",
            categoryId: categoryId,
            userInfo: [
                "threadId": notification.threadId,
                "accountId": notification.accountId,
                "repositoryFullName": notification.repositoryFullName,
            ],
            repositoryFullName: notification.repositoryFullName,
            repositoryOwner: notification.repositoryOwner,
            reason: notification.reason.rawValue
        )
    }
}
