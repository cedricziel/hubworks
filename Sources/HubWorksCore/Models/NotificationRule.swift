import Foundation
import SwiftData

public enum NotificationReason: String, Codable, CaseIterable, Sendable {
    case assign
    case author
    case ciActivity = "ci_activity"
    case comment
    case invitation
    case manual
    case mention
    case reviewRequested = "review_requested"
    case securityAlert = "security_alert"
    case stateChange = "state_change"
    case subscribed
    case teamMention = "team_mention"

    public var displayName: String {
        switch self {
            case .assign: "Assigned"
            case .author: "Author"
            case .ciActivity: "CI Activity"
            case .comment: "Comment"
            case .invitation: "Invitation"
            case .manual: "Manual"
            case .mention: "Mention"
            case .reviewRequested: "Review Requested"
            case .securityAlert: "Security Alert"
            case .stateChange: "State Change"
            case .subscribed: "Subscribed"
            case .teamMention: "Team Mention"
        }
    }

    public var systemImage: String {
        switch self {
            case .assign: "person.badge.plus"
            case .author: "person.fill"
            case .ciActivity: "gearshape.2"
            case .comment: "text.bubble"
            case .invitation: "envelope"
            case .manual: "hand.tap"
            case .mention: "at"
            case .reviewRequested: "eye"
            case .securityAlert: "exclamationmark.shield"
            case .stateChange: "arrow.triangle.2.circlepath"
            case .subscribed: "bell"
            case .teamMention: "person.3"
        }
    }
}

@Model
public final class NotificationRule {
    /// CloudKit doesn't support unique constraints - we handle uniqueness in app logic
    public var id: String = UUID().uuidString

    public var repositoryPattern: String?
    public var organizationPattern: String?
    public var reasonsRaw: [String] = []
    public var sendPushNotification: Bool = true
    public var isHighPriority: Bool = false
    public var isMuted: Bool = false
    public var createdAt = Date.now
    public var updatedAt = Date.now

    public var scope: NotificationScope?

    public init(
        id: String = UUID().uuidString,
        repositoryPattern: String? = nil,
        organizationPattern: String? = nil,
        reasons: [NotificationReason] = [],
        sendPushNotification: Bool = true,
        isHighPriority: Bool = false,
        isMuted: Bool = false,
        scope: NotificationScope? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.repositoryPattern = repositoryPattern
        self.organizationPattern = organizationPattern
        reasonsRaw = reasons.map(\.rawValue)
        self.sendPushNotification = sendPushNotification
        self.isHighPriority = isHighPriority
        self.isMuted = isMuted
        self.scope = scope
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension NotificationRule {
    public var reasons: [NotificationReason] {
        get {
            reasonsRaw.compactMap { NotificationReason(rawValue: $0) }
        }
        set {
            reasonsRaw = newValue.map(\.rawValue)
        }
    }

    public func matches(
        repository: String,
        organization: String?,
        reason: NotificationReason
    ) -> Bool {
        if let repoPattern = repositoryPattern,
           !matchesPattern(repoPattern, value: repository)
        {
            return false
        }

        if let orgPattern = organizationPattern,
           let org = organization,
           !matchesPattern(orgPattern, value: org)
        {
            return false
        }

        if !reasonsRaw.isEmpty, !reasonsRaw.contains(reason.rawValue) {
            return false
        }

        return true
    }

    private func matchesPattern(_ pattern: String, value: String) -> Bool {
        if pattern == "*" { return true }

        if pattern.contains("*") {
            let regex = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            return (try? NSRegularExpression(pattern: "^\(regex)$", options: .caseInsensitive))
                .map { $0.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil }
                ?? false
        }

        return pattern.lowercased() == value.lowercased()
    }
}
