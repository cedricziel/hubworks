import ComposableArchitecture
import Foundation
import SwiftData

@DependencyClient
public struct OrganizationRepositoryService: Sendable {
    /// Load distinct organizations from cached notifications
    public var loadOrganizations: @Sendable () async -> [String] = { [] }

    /// Load distinct repositories from cached notifications
    public var loadRepositories: @Sendable () async -> [String] = { [] }
}

extension OrganizationRepositoryService: DependencyKey {
    public static var liveValue: OrganizationRepositoryService {
        OrganizationRepositoryService(
            loadOrganizations: {
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let descriptor = FetchDescriptor<CachedNotification>()

                    guard let notifications = try? context.fetch(descriptor) else {
                        return []
                    }

                    let organizations = Set(notifications.map(\.repositoryOwner))
                    return organizations.sorted()
                }
            },

            loadRepositories: {
                await MainActor.run {
                    let container = HubWorksCore.modelContainer
                    let context = container.mainContext
                    let descriptor = FetchDescriptor<CachedNotification>()

                    guard let notifications = try? context.fetch(descriptor) else {
                        return []
                    }

                    let repositories = Set(notifications.map(\.repositoryFullName))
                    return repositories.sorted()
                }
            }
        )
    }

    public static let testValue = OrganizationRepositoryService()
}

extension DependencyValues {
    public var organizationRepositoryService: OrganizationRepositoryService {
        get { self[OrganizationRepositoryService.self] }
        set { self[OrganizationRepositoryService.self] = newValue }
    }
}
