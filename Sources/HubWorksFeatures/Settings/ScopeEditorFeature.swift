import ComposableArchitecture
import Foundation
import HubWorksCore
import SwiftData
import SwiftUI

@Reducer
public struct ScopeEditorFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var scopeId: String?
        public var name: String = ""
        public var emoji: String = "🔔"
        public var colorHex: String = "#007AFF"
        public var selectedOrganizations: [String] = []
        public var selectedRepositories: [String] = []
        public var quietHoursEnabled: Bool = false
        public var quietHoursStart: Int = 22
        public var quietHoursEnd: Int = 8
        public var quietHoursDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
        public var isDefault: Bool = false
        public var isLoading: Bool = false
        public var isSaving: Bool = false
        public var error: String?

        public var isNewScope: Bool {
            scopeId == nil
        }

        public var canSave: Bool {
            !name.isEmpty && !emoji.isEmpty
        }

        public init(
            scopeId: String? = nil,
            name: String = "",
            emoji: String = "🔔",
            colorHex: String = "#007AFF",
            selectedOrganizations: [String] = [],
            selectedRepositories: [String] = [],
            quietHoursEnabled: Bool = false,
            quietHoursStart: Int = 22,
            quietHoursEnd: Int = 8,
            quietHoursDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
            isDefault: Bool = false,
            isLoading: Bool = false,
            isSaving: Bool = false,
            error: String? = nil
        ) {
            self.scopeId = scopeId
            self.name = name
            self.emoji = emoji
            self.colorHex = colorHex
            self.selectedOrganizations = selectedOrganizations
            self.selectedRepositories = selectedRepositories
            self.quietHoursEnabled = quietHoursEnabled
            self.quietHoursStart = quietHoursStart
            self.quietHoursEnd = quietHoursEnd
            self.quietHoursDays = quietHoursDays
            self.isDefault = isDefault
            self.isLoading = isLoading
            self.isSaving = isSaving
            self.error = error
        }

        public init(from scope: NotificationScope) {
            scopeId = scope.id
            name = scope.name
            emoji = scope.emoji
            colorHex = scope.colorHex
            quietHoursEnabled = scope.quietHoursEnabled
            quietHoursStart = scope.quietHoursStart
            quietHoursEnd = scope.quietHoursEnd
            quietHoursDays = scope.quietHoursDays
            isDefault = scope.isDefault

            // Extract organizations and repositories from rules
            if let rules = scope.rules {
                selectedOrganizations = rules.compactMap(\.organizationPattern).filter { !$0.isEmpty }
                selectedRepositories = rules.compactMap(\.repositoryPattern).filter { !$0.isEmpty }
            }
        }
    }

    public enum Action: Sendable {
        case onAppear
        case loadScope
        case scopeLoaded(NotificationScope)
        case nameChanged(String)
        case emojiChanged(String)
        case colorChanged(String)
        case addOrganization(String)
        case removeOrganization(String)
        case addRepository(String)
        case removeRepository(String)
        case toggleQuietHours
        case quietHoursStartChanged(Int)
        case quietHoursEndChanged(Int)
        case quietHoursDaysChanged([Int])
        case save
        case saveCompleted
        case cancel
        case errorOccurred(String)
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    if state.scopeId != nil {
                        return .send(.loadScope)
                    }
                    return .none

                case .loadScope:
                    guard let scopeId = state.scopeId else { return .none }
                    state.isLoading = true
                    return .run { send in
                        if let scope = await loadScope(id: scopeId) {
                            await send(.scopeLoaded(scope))
                        }
                    }

                case let .scopeLoaded(scope):
                    state = State(from: scope)
                    state.isLoading = false
                    return .none

                case let .nameChanged(name):
                    state.name = name
                    return .none

                case let .emojiChanged(emoji):
                    state.emoji = emoji
                    return .none

                case let .colorChanged(colorHex):
                    state.colorHex = colorHex
                    return .none

                case let .addOrganization(org):
                    if !state.selectedOrganizations.contains(org) {
                        state.selectedOrganizations.append(org)
                    }
                    return .none

                case let .removeOrganization(org):
                    state.selectedOrganizations.removeAll { $0 == org }
                    return .none

                case let .addRepository(repo):
                    if !state.selectedRepositories.contains(repo) {
                        state.selectedRepositories.append(repo)
                    }
                    return .none

                case let .removeRepository(repo):
                    state.selectedRepositories.removeAll { $0 == repo }
                    return .none

                case .toggleQuietHours:
                    state.quietHoursEnabled.toggle()
                    return .none

                case let .quietHoursStartChanged(hour):
                    state.quietHoursStart = hour
                    return .none

                case let .quietHoursEndChanged(hour):
                    state.quietHoursEnd = hour
                    return .none

                case let .quietHoursDaysChanged(days):
                    state.quietHoursDays = days
                    return .none

                case .save:
                    guard state.canSave else { return .none }
                    state.isSaving = true
                    return .run { [state] send in
                        do {
                            try await saveScope(state)
                            await send(.saveCompleted)
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }

                case .saveCompleted:
                    state.isSaving = false
                    return .run { _ in
                        await dismiss()
                    }

                case .cancel:
                    return .run { _ in
                        await dismiss()
                    }

                case let .errorOccurred(error):
                    state.error = error
                    state.isSaving = false
                    state.isLoading = false
                    return .none
            }
        }
    }
}

// MARK: - Database Operations

@MainActor
private func loadScope(id: String) async -> NotificationScope? {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    let predicate = #Predicate<NotificationScope> { $0.id == id }
    let descriptor = FetchDescriptor<NotificationScope>(predicate: predicate)

    return try? context.fetch(descriptor).first
}

@MainActor
private func saveScope(_ state: ScopeEditorFeature.State) async throws {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext

    let scope: NotificationScope
    if let scopeId = state.scopeId {
        // Edit existing scope
        let predicate = #Predicate<NotificationScope> { $0.id == scopeId }
        let descriptor = FetchDescriptor<NotificationScope>(predicate: predicate)
        guard let existingScope = try context.fetch(descriptor).first else {
            throw NSError(domain: "ScopeEditor", code: 404, userInfo: [NSLocalizedDescriptionKey: "Scope not found"])
        }
        scope = existingScope
    } else {
        // Create new scope
        scope = NotificationScope(
            name: state.name,
            emoji: state.emoji,
            colorHex: state.colorHex
        )
        context.insert(scope)
    }

    // Update scope properties
    scope.name = state.name
    scope.emoji = state.emoji
    scope.colorHex = state.colorHex
    scope.quietHoursEnabled = state.quietHoursEnabled
    scope.quietHoursStart = state.quietHoursStart
    scope.quietHoursEnd = state.quietHoursEnd
    scope.quietHoursDays = state.quietHoursDays
    scope.isDefault = state.isDefault
    scope.updatedAt = Date()

    // Clear existing rules
    if let existingRules = scope.rules {
        for rule in existingRules {
            context.delete(rule)
        }
    }

    // Create rules from organizations
    var newRules: [NotificationRule] = []
    for org in state.selectedOrganizations {
        let rule = NotificationRule(
            organizationPattern: org,
            scope: scope
        )
        context.insert(rule)
        newRules.append(rule)
    }

    // Create rules from repositories
    for repo in state.selectedRepositories {
        let rule = NotificationRule(
            repositoryPattern: repo,
            scope: scope
        )
        context.insert(rule)
        newRules.append(rule)
    }

    scope.rules = newRules.isEmpty ? nil : newRules

    try context.save()
}
