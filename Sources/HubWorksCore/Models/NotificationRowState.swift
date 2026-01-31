import Foundation

public struct NotificationRowState: Equatable, Identifiable, Sendable {
    public let id: String
    public let threadId: String
    public let title: String
    public let repositoryFullName: String
    public let repositoryOwner: String
    public let repositoryAvatarURL: URL?
    public let subjectType: NotificationSubjectType
    public let reason: NotificationReason
    public var isUnread: Bool
    public let updatedAt: Date
    public let webURL: URL?
    public var isSnoozed: Bool = false
    public var snoozeUntil: Date?

    public init(
        id: String,
        threadId: String,
        title: String,
        repositoryFullName: String,
        repositoryOwner: String,
        repositoryAvatarURL: URL?,
        subjectType: NotificationSubjectType,
        reason: NotificationReason,
        isUnread: Bool,
        updatedAt: Date,
        webURL: URL?,
        isSnoozed: Bool = false,
        snoozeUntil: Date? = nil
    ) {
        self.id = id
        self.threadId = threadId
        self.title = title
        self.repositoryFullName = repositoryFullName
        self.repositoryOwner = repositoryOwner
        self.repositoryAvatarURL = repositoryAvatarURL
        self.subjectType = subjectType
        self.reason = reason
        self.isUnread = isUnread
        self.updatedAt = updatedAt
        self.webURL = webURL
        self.isSnoozed = isSnoozed
        self.snoozeUntil = snoozeUntil
    }
}
