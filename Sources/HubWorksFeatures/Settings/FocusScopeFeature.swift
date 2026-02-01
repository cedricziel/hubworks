import ComposableArchitecture
import Foundation
import HubWorksCore
import SwiftData

@Reducer
public struct FocusScopeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var scopes: [ScopeState] = []
        public var selectedScopeId: String?
        public var isLoading: Bool = false
        public var error: String?

        public struct ScopeState: Equatable, Identifiable, Sendable {
            public let id: String
            public let name: String
            public let emoji: String
            public let colorHex: String
            public var focusModeIdentifier: String?
            public var ruleCount: Int
            public var isDefault: Bool

            public init(from scope: NotificationScope) {
                id = scope.id
                name = scope.name
                emoji = scope.emoji
                colorHex = scope.colorHex
                focusModeIdentifier = scope.focusModeIdentifier
                ruleCount = scope.rules?.count ?? 0
                isDefault = scope.isDefault
            }
        }

        public init(
            scopes: [ScopeState] = [],
            selectedScopeId: String? = nil,
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.scopes = scopes
            self.selectedScopeId = selectedScopeId
            self.isLoading = isLoading
            self.error = error
        }
    }

    public enum Action: Sendable {
        case onAppear
        case loadScopes
        case scopesLoaded([State.ScopeState])
        case scopeSelected(String?)
        case createNewScope
        case editScope(String)
        case deleteScope(String)
        case scopeDeleted
        case assignToFocusMode(scopeId: String, focusIdentifier: String?)
        case focusModeAssigned
        case errorOccurred(String)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    return .send(.loadScopes)

                case .loadScopes:
                    state.isLoading = true
                    state.error = nil
                    return .run { send in
                        let scopes = await loadScopesFromDatabase()
                        await send(.scopesLoaded(scopes))
                    }

                case let .scopesLoaded(scopes):
                    state.scopes = scopes
                    state.isLoading = false
                    return .none

                case let .scopeSelected(id):
                    state.selectedScopeId = id
                    return .none

                case .createNewScope:
                    // Navigation handled by view
                    return .none

                case .editScope:
                    // Navigation handled by view
                    return .none

                case let .deleteScope(id):
                    return .run { send in
                        do {
                            try await deleteScopeFromDatabase(id)
                            await send(.scopeDeleted)
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }

                case .scopeDeleted:
                    return .send(.loadScopes)

                case let .assignToFocusMode(scopeId, focusIdentifier):
                    return .run { send in
                        do {
                            try await updateScopeFocusIdentifier(scopeId, focusIdentifier)
                            await send(.focusModeAssigned)
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }

                case .focusModeAssigned:
                    return .send(.loadScopes)

                case let .errorOccurred(error):
                    state.error = error
                    state.isLoading = false
                    return .none
            }
        }
    }
}

// MARK: - Database Operations

@MainActor
private func loadScopesFromDatabase() async -> [FocusScopeFeature.State.ScopeState] {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    // Seed default scopes if database is empty
    let defaultScopeService = DefaultScopeService()
    try? defaultScopeService.seedDefaultScopesIfNeeded(modelContext: context)

    let descriptor = FetchDescriptor<NotificationScope>(
        sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    )

    guard let scopes = try? context.fetch(descriptor) else {
        return []
    }

    return scopes.map { FocusScopeFeature.State.ScopeState(from: $0) }
}

@MainActor
private func deleteScopeFromDatabase(_ scopeId: String) async throws {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    let predicate = #Predicate<NotificationScope> { $0.id == scopeId }
    let descriptor = FetchDescriptor<NotificationScope>(predicate: predicate)

    guard let scope = try context.fetch(descriptor).first else {
        return
    }

    context.delete(scope)
    try context.save()
}

@MainActor
private func updateScopeFocusIdentifier(_ scopeId: String, _ focusIdentifier: String?) async throws {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    let predicate = #Predicate<NotificationScope> { $0.id == scopeId }
    let descriptor = FetchDescriptor<NotificationScope>(predicate: predicate)

    guard let scope = try context.fetch(descriptor).first else {
        return
    }

    scope.focusModeIdentifier = focusIdentifier
    scope.updatedAt = Date()
    try context.save()
}
