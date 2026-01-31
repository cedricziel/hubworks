import Foundation
import SwiftData

public enum NotificationState: String, Codable, Sendable {
    case unread
    case read
    case archived
    case snoozed
}

@Model
public final class ReadState {
    /// CloudKit doesn't support unique constraints - we handle uniqueness in app logic
    public var threadId: String = ""

    public var stateRaw: String = NotificationState.unread.rawValue
    public var snoozeUntil: Date?
    public var accountId: String = ""
    public var createdAt = Date.now
    public var updatedAt = Date.now

    public init(
        threadId: String,
        state: NotificationState = .unread,
        snoozeUntil: Date? = nil,
        accountId: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.threadId = threadId
        stateRaw = state.rawValue
        self.snoozeUntil = snoozeUntil
        self.accountId = accountId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ReadState {
    public var state: NotificationState {
        get {
            NotificationState(rawValue: stateRaw) ?? .unread
        }
        set {
            stateRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    public var isSnoozed: Bool {
        guard state == .snoozed, let until = snoozeUntil else {
            return false
        }
        return until > Date.now
    }

    public func snooze(until date: Date) {
        state = .snoozed
        snoozeUntil = date
    }

    public func unsnooze() {
        state = .unread
        snoozeUntil = nil
    }
}
