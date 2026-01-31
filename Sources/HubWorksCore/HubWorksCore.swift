import Foundation
import SwiftData

@MainActor
public enum HubWorksCore {
    public static var modelContainer: ModelContainer = {
        let schema = Schema([
            GitHubAccount.self,
            NotificationScope.self,
            NotificationRule.self,
            ReadState.self,
            CachedNotification.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    public static func createPreviewContainer() -> ModelContainer {
        let schema = Schema([
            GitHubAccount.self,
            NotificationScope.self,
            NotificationRule.self,
            ReadState.self,
            CachedNotification.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}
