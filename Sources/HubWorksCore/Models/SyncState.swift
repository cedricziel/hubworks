import Foundation
import SwiftData

/// Persists sync state for polling optimization.
/// Uses CloudKit sync so all devices share the same lastModified state.
@Model
public final class SyncState {
    public var accountId: String = "default"
    public var lastModified: String?
    public var lastPolledAt: Date?
    public var pollInterval: Int = 60

    public init(
        accountId: String = "default",
        lastModified: String? = nil,
        lastPolledAt: Date? = nil,
        pollInterval: Int = 60
    ) {
        self.accountId = accountId
        self.lastModified = lastModified
        self.lastPolledAt = lastPolledAt
        self.pollInterval = pollInterval
    }
}
