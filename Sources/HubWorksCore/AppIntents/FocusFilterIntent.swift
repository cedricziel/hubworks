import AppIntents
import Foundation
import SwiftData

// MARK: - Scope App Entity

/// Represents a notification scope for Focus Filter configuration
@available(iOS 16.0, macOS 13.0, *)
public struct ScopeAppEntity: AppEntity {
    public let id: String
    public let name: String
    public let emoji: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(emoji) \(name)",
            subtitle: "Notification Scope"
        )
    }

    nonisolated(unsafe) public static let defaultQuery = ScopeEntityQuery()

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Notification Scope")
    }
}

// MARK: - Scope Entity Query

/// Provides available scopes for Focus Filter configuration
@available(iOS 16.0, macOS 13.0, *)
public struct ScopeEntityQuery: EntityQuery {
    public init() {}

    public func suggestedEntities() async throws -> [ScopeAppEntity] {
        let modelContainer = await MainActor.run { HubWorksCore.modelContainer }
        let modelContext = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<NotificationScope>(
            sortBy: [SortDescriptor(\.name)]
        )
        let scopes = try modelContext.fetch(descriptor)

        return scopes.map { scope in
            ScopeAppEntity(
                id: scope.id,
                name: scope.name,
                emoji: scope.emoji
            )
        }
    }

    public func entities(for identifiers: [String]) async throws -> [ScopeAppEntity] {
        let allScopes = try await suggestedEntities()
        return allScopes.filter { identifiers.contains($0.id) }
    }
}

// MARK: - Focus Filter Intent

@available(iOS 16.0, macOS 13.0, *)
public struct HubWorksFocusFilterIntent: SetFocusFilterIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Filter GitHub Notifications"

    nonisolated(unsafe) public static var description: IntentDescription? = IntentDescription(
        "Show only notifications from specific organizations or repositories"
    )

    @Parameter(title: "Scope") public var scope: ScopeAppEntity?

    public var displayRepresentation: DisplayRepresentation {
        if let scope {
            DisplayRepresentation(
                title: "\(scope.emoji) \(scope.name)",
                subtitle: "GitHub Notifications"
            )
        } else {
            DisplayRepresentation(
                title: "All Notifications",
                subtitle: "GitHub Notifications"
            )
        }
    }

    public init() {}

    public init(scope: ScopeAppEntity?) {
        self.scope = scope
    }

    public func perform() async throws -> some IntentResult {
        // Update active scope in shared storage
        if let scope {
            UserDefaults.standard.set(scope.id, forKey: "active_focus_scope_id")
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
