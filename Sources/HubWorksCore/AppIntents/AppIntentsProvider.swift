import AppIntents

/// Package declaration that makes HubWorks Focus Filter intents discoverable by the system
@available(iOS 16.0, macOS 13.0, *)
public struct HubWorksAppIntentsPackage: AppIntentsPackage {
    nonisolated(unsafe) public static var includedPackages: [any AppIntentsPackage.Type] = []

    public static var intents: [any AppIntent.Type] {
        [HubWorksFocusFilterIntent.self]
    }

    public static var entities: [any AppEntity.Type] {
        [ScopeAppEntity.self]
    }

    public static var queries: [any EntityQuery.Type] {
        [ScopeEntityQuery.self]
    }
}
