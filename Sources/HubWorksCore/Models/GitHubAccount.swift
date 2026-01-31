import Foundation
import SwiftData

@Model
public final class GitHubAccount {
    // CloudKit doesn't support unique constraints - we handle uniqueness in app logic
    public var id: String = UUID().uuidString

    public var username: String = ""
    public var avatarURL: URL?
    public var email: String?
    public var displayName: String?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    // CloudKit requires optional relationships
    @Relationship(deleteRule: .nullify, inverse: \NotificationScope.accounts)
    public var scopes: [NotificationScope]?

    public var lastNotificationFetchedAt: Date?
    public var lastModifiedHeader: String?

    public init(
        id: String = UUID().uuidString,
        username: String,
        avatarURL: URL? = nil,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        scopes: [NotificationScope]? = [],
        lastNotificationFetchedAt: Date? = nil,
        lastModifiedHeader: String? = nil
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scopes = scopes
        self.lastNotificationFetchedAt = lastNotificationFetchedAt
        self.lastModifiedHeader = lastModifiedHeader
    }
}

extension GitHubAccount {
    public var keychainKey: String {
        "github_oauth_token_\(id)"
    }
}
