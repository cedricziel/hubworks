import Foundation
import SwiftData

public enum NotificationSubjectType: String, Codable, Sendable {
    case issue = "Issue"
    case pullRequest = "PullRequest"
    case release = "Release"
    case discussion = "Discussion"
    case commit = "Commit"
    case repositoryInvitation = "RepositoryInvitation"
    case securityAdvisory = "RepositoryVulnerabilityAlert"
    case checkSuite = "CheckSuite"
    case unknown

    public init(from rawValue: String) {
        self = NotificationSubjectType(rawValue: rawValue) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .issue: "Issue"
        case .pullRequest: "Pull Request"
        case .release: "Release"
        case .discussion: "Discussion"
        case .commit: "Commit"
        case .repositoryInvitation: "Invitation"
        case .securityAdvisory: "Security Advisory"
        case .checkSuite: "Check Suite"
        case .unknown: "Notification"
        }
    }

    public var systemImage: String {
        switch self {
        case .issue: "circle.circle"
        case .pullRequest: "arrow.triangle.pull"
        case .release: "tag"
        case .discussion: "bubble.left.and.bubble.right"
        case .commit: "point.topleft.down.to.point.bottomright.curvepath"
        case .repositoryInvitation: "envelope"
        case .securityAdvisory: "exclamationmark.shield"
        case .checkSuite: "checkmark.circle"
        case .unknown: "bell"
        }
    }
}

@Model
public final class CachedNotification {
    // CloudKit doesn't support unique constraints - we handle uniqueness in app logic
    public var id: String = UUID().uuidString

    public var threadId: String = ""
    public var accountId: String = ""
    public var unread: Bool = true
    public var reasonRaw: String = NotificationReason.subscribed.rawValue
    public var updatedAt: Date = Date.now
    public var lastReadAt: Date?

    public var subjectTitle: String = ""
    public var subjectTypeRaw: String = NotificationSubjectType.unknown.rawValue
    public var subjectURL: String?
    public var latestCommentURL: String?

    public var repositoryId: Int = 0
    public var repositoryName: String = ""
    public var repositoryFullName: String = ""
    public var repositoryOwner: String = ""
    public var repositoryAvatarURL: String?
    public var isPrivateRepository: Bool = false

    public var fetchedAt: Date = Date.now

    public init(
        id: String = UUID().uuidString,
        threadId: String,
        accountId: String,
        unread: Bool,
        reason: NotificationReason,
        updatedAt: Date,
        lastReadAt: Date? = nil,
        subjectTitle: String,
        subjectType: NotificationSubjectType,
        subjectURL: String? = nil,
        latestCommentURL: String? = nil,
        repositoryId: Int,
        repositoryName: String,
        repositoryFullName: String,
        repositoryOwner: String,
        repositoryAvatarURL: String? = nil,
        isPrivateRepository: Bool,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.threadId = threadId
        self.accountId = accountId
        self.unread = unread
        self.reasonRaw = reason.rawValue
        self.updatedAt = updatedAt
        self.lastReadAt = lastReadAt
        self.subjectTitle = subjectTitle
        self.subjectTypeRaw = subjectType.rawValue
        self.subjectURL = subjectURL
        self.latestCommentURL = latestCommentURL
        self.repositoryId = repositoryId
        self.repositoryName = repositoryName
        self.repositoryFullName = repositoryFullName
        self.repositoryOwner = repositoryOwner
        self.repositoryAvatarURL = repositoryAvatarURL
        self.isPrivateRepository = isPrivateRepository
        self.fetchedAt = fetchedAt
    }
}

extension CachedNotification {
    public var reason: NotificationReason {
        NotificationReason(rawValue: reasonRaw) ?? .subscribed
    }

    public var subjectType: NotificationSubjectType {
        NotificationSubjectType(from: subjectTypeRaw)
    }

    public var webURL: URL? {
        guard let subjectURL else { return nil }

        var urlString = subjectURL
            .replacingOccurrences(of: "api.github.com/repos", with: "github.com")
            .replacingOccurrences(of: "/pulls/", with: "/pull/")

        if let range = urlString.range(of: "/comments/") {
            urlString = String(urlString[..<range.lowerBound])
        }

        return URL(string: urlString)
    }
}
