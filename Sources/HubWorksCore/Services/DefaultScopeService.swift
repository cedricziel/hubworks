import Foundation
import SwiftData

/// Service for creating default notification scopes on first launch
public struct DefaultScopeService {
    public init() {}

    /// Creates default scopes if they don't already exist
    @MainActor
    public func seedDefaultScopesIfNeeded(modelContext: ModelContext) throws {
        // Check if we already have scopes
        let descriptor = FetchDescriptor<NotificationScope>()
        let existingScopes = try modelContext.fetch(descriptor)

        guard existingScopes.isEmpty else {
            return // Scopes already exist, no need to seed
        }

        // Create default scopes
        let allScope = createAllScope()
        let workScope = createWorkScope()
        let personalScope = createPersonalScope()

        modelContext.insert(allScope)
        modelContext.insert(workScope)
        modelContext.insert(personalScope)

        try modelContext.save()
    }

    // MARK: - Private Helpers

    private func createAllScope() -> NotificationScope {
        NotificationScope(
            name: "All Notifications",
            emoji: "🔔",
            colorHex: "#007AFF", // Default blue
            quietHoursEnabled: false,
            quietHoursStart: 22,
            quietHoursEnd: 8,
            quietHoursDays: [],
            isDefault: true
        )
    }

    private func createWorkScope() -> NotificationScope {
        NotificationScope(
            name: "Work",
            emoji: "💼",
            colorHex: "#FF9500", // Orange
            quietHoursEnabled: false,
            quietHoursStart: 22,
            quietHoursEnd: 8,
            quietHoursDays: [],
            isDefault: false
        )
    }

    private func createPersonalScope() -> NotificationScope {
        NotificationScope(
            name: "Personal",
            emoji: "🏠",
            colorHex: "#34C759", // Green
            quietHoursEnabled: false,
            quietHoursStart: 22,
            quietHoursEnd: 8,
            quietHoursDays: [],
            isDefault: false
        )
    }
}
