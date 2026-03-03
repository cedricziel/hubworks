import ComposableArchitecture
import Foundation

@DependencyClient
public struct FocusFilterService: Sendable {
    public var getActiveScope: @Sendable () async -> String?
    public var setActiveScope: @Sendable (String?) async -> Void
    public var clearActiveScope: @Sendable () async -> Void
}

extension FocusFilterService: DependencyKey {
    public static let liveValue = FocusFilterService(
        getActiveScope: {
            UserDefaults.standard.string(forKey: "active_focus_scope_id")
        },

        setActiveScope: { scopeId in
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
        },

        clearActiveScope: {
            UserDefaults.standard.removeObject(forKey: "active_focus_scope_id")
            NotificationCenter.default.post(
                name: .activeFocusScopeChanged,
                object: nil
            )
        }
    )

    public static let testValue = FocusFilterService(
        getActiveScope: { nil },
        setActiveScope: { _ in },
        clearActiveScope: {}
    )
}

extension DependencyValues {
    public var focusFilterService: FocusFilterService {
        get { self[FocusFilterService.self] }
        set { self[FocusFilterService.self] = newValue }
    }
}
