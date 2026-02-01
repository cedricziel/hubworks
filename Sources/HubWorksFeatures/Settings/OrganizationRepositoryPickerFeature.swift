import ComposableArchitecture
import Foundation
import HubWorksCore
import SwiftData

@Reducer
public struct OrganizationRepositoryPickerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var pickerType: PickerType
        public var items: [String] = []
        public var selectedItems: Set<String> = []
        public var searchText: String = ""
        public var isLoading: Bool = false

        public enum PickerType: Equatable, Sendable {
            case organizations
            case repositories
        }

        public init(
            pickerType: PickerType,
            selectedItems: Set<String> = []
        ) {
            self.pickerType = pickerType
            self.selectedItems = selectedItems
        }
    }

    public enum Action: Sendable {
        case onAppear
        case itemsLoaded([String])
        case toggleItem(String)
        case searchTextChanged(String)
        case done
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    state.isLoading = true
                    return .run { [pickerType = state.pickerType] send in
                        let items = await loadItemsFromDatabase(pickerType: pickerType)
                        await send(.itemsLoaded(items))
                    }

                case let .itemsLoaded(items):
                    state.items = items
                    state.isLoading = false
                    return .none

                case let .toggleItem(item):
                    if state.selectedItems.contains(item) {
                        state.selectedItems.remove(item)
                    } else {
                        state.selectedItems.insert(item)
                    }
                    return .none

                case let .searchTextChanged(text):
                    state.searchText = text
                    return .none

                case .done:
                    return .none
            }
        }
    }
}

// MARK: - Database Operations

@MainActor
private func loadItemsFromDatabase(pickerType: OrganizationRepositoryPickerFeature.State.PickerType) async -> [String] {
    let container = HubWorksCore.modelContainer
    let context = container.mainContext
    let descriptor = FetchDescriptor<CachedNotification>()

    guard let notifications = try? context.fetch(descriptor) else {
        return []
    }

    let items: Set<String> = switch pickerType {
        case .organizations:
            Set(notifications.map(\.repositoryOwner))
        case .repositories:
            Set(notifications.map(\.repositoryFullName))
    }

    return items.sorted()
}
