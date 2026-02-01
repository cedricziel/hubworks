import ComposableArchitecture
import SwiftUI

public struct OrganizationRepositoryPickerView: View {
    @Bindable var store: StoreOf<OrganizationRepositoryPickerFeature>

    public init(store: StoreOf<OrganizationRepositoryPickerFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            if store.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Section {
                    ForEach(filteredItems, id: \.self) { item in
                        Button {
                            store.send(.toggleItem(item))
                        } label: {
                            HStack {
                                Text(item)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.selectedItems.contains(item) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(store.pickerType == .organizations ? "Organizations" : "Repositories")
                } footer: {
                    Text(footerText)
                }
            }
        }
        .searchable(text: $store.searchText.sending(\.searchTextChanged))
        .navigationTitle(navigationTitle)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.send(.done)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
    }

    private var filteredItems: [String] {
        if store.searchText.isEmpty {
            store.items
        } else {
            store.items.filter { item in
                item.localizedCaseInsensitiveContains(store.searchText)
            }
        }
    }

    private var navigationTitle: String {
        store.pickerType == .organizations ? "Select Organizations" : "Select Repositories"
    }

    private var footerText: String {
        switch store.pickerType {
            case .organizations:
                """
                Select organizations to include in this scope. Only notifications from these organizations \
                will be shown when this Focus mode is active.
                """
            case .repositories:
                """
                Select repositories to include in this scope. Only notifications from these repositories \
                will be shown when this Focus mode is active.
                """
        }
    }
}

#Preview("Organizations") {
    NavigationStack {
        OrganizationRepositoryPickerView(
            store: Store(
                initialState: OrganizationRepositoryPickerFeature.State(
                    pickerType: .organizations,
                    selectedItems: ["mycompany"]
                )
            ) {
                OrganizationRepositoryPickerFeature()
            }
        )
    }
}

#Preview("Repositories") {
    NavigationStack {
        OrganizationRepositoryPickerView(
            store: Store(
                initialState: OrganizationRepositoryPickerFeature.State(
                    pickerType: .repositories,
                    selectedItems: ["mycompany/backend"]
                )
            ) {
                OrganizationRepositoryPickerFeature()
            }
        )
    }
}
