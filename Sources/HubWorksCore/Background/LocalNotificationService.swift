import ComposableArchitecture
import Foundation
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

    public init(
        id: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        threadId: String,
        categoryId: String? = nil,
        userInfo: [String: String] = [:],
        playSound: Bool = true
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.threadId = threadId
        self.categoryId = categoryId
        self.userInfo = userInfo
        self.playSound = playSound
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
            ]
        )
    }
}
