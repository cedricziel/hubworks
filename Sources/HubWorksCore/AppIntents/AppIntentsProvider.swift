import AppIntents

/// Package declaration that makes HubWorks Focus Filter intents discoverable by the system
@available(iOS 16.0, macOS 13.0, *)
public struct HubWorksAppIntentsPackage: AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] = []
}

/// App dependency that exposes our Focus Filter intent and entities to the system
@available(iOS 16.0, macOS 13.0, *)
public struct HubWorksAppDependency: AppDependency {
    public static var includedDependencies: [any AppDependency.Type] = []

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
