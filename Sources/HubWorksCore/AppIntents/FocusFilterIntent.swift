import AppIntents
import Foundation

@available(iOS 16.0, macOS 13.0, *)
public struct HubWorksFocusFilterIntent: SetFocusFilterIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Filter GitHub Notifications"

    nonisolated(unsafe) public static var description: IntentDescription? = IntentDescription(
        "Show only notifications from specific organizations or repositories"
    )

    @Parameter(title: "Scope ID") public var scopeId: String?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Filter GitHub Notifications")
    }

    public init() {}

    public init(scopeId: String?) {
        self.scopeId = scopeId
    }

    public func perform() async throws -> some IntentResult {
        // Update active scope in shared storage
        if let scopeId {
            UserDefaults.standard.set(scopeId, forKey: "active_focus_scope_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "active_focus_scope_id")
        }

        // Post notification for reactive updates
        NotificationCenter.default.post(
            name: .activeFocusScopeChanged,
            object: nil
        )

        return .result()
    }
}

extension Notification.Name {
    public static let activeFocusScopeChanged = Notification.Name("activeFocusScopeChanged")
}
