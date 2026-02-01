import ComposableArchitecture
import SwiftUI

public struct FocusScopeManagementView: View {
    @Bindable var store: StoreOf<FocusScopeFeature>
    @State private var showOnboarding = false
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<FocusScopeFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                Text(
                    """
                    Configure notification scopes for different Focus modes. \
                    Each scope filters notifications based on organizations and repositories.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if store.isLoading {
                Section {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading scopes...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else if store.scopes.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Scopes", systemImage: "moon.stars")
                    } description: {
                        Text("Create a scope to filter notifications based on Focus modes")
                    } actions: {
                        Button("Reload") {
                            store.send(.loadScopes)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Section("Notification Scopes") {
                    ForEach(store.scopes) { scope in
                        ScopeRow(scope: scope) {
                            store.send(.editScope(scope.id))
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.send(.deleteScope(store.scopes[index].id))
                        }
                    }
                }
            }

            Section("Focus Mode Integration") {
                Text(
                    """
                    Configure each scope in Settings → Focus to filter notifications by organization and repository. \
                    When a Focus mode is active, only matching notifications will appear.
                    """
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = store.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Focus Filters")
        #if os(macOS)
            .navigationSubtitle("\(store.scopes.count) \(store.scopes.count == 1 ? "scope" : "scopes")")
            .frame(minWidth: 600, minHeight: 500)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.createNewScope)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: $showOnboarding) {
                NavigationStack {
                    FocusFilterOnboardingView()
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isCreatingNewScope || store.editingScopeId != nil },
                    set: { if !$0 { store.send(.dismissScopeEditor) } }
                )
            ) {
                NavigationStack {
                    if store.isCreatingNewScope {
                        ScopeEditorView(
                            store: Store(initialState: ScopeEditorFeature.State()) {
                                ScopeEditorFeature()
                            }
                        )
                    } else if let editingScopeId = store.editingScopeId {
                        ScopeEditorView(
                            store: Store(initialState: ScopeEditorFeature.State(scopeId: editingScopeId)) {
                                ScopeEditorFeature()
                            }
                        )
                    }
                }
            }
    }
}

struct ScopeRow: View {
    let scope: FocusScopeFeature.State.ScopeState
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(scope.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scope.name)
                        .font(.headline)

                    if scope.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                if scope.ruleCount > 0 {
                    Text("\(scope.ruleCount) \(scope.ruleCount == 1 ? "rule" : "rules")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No rules")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let focusId = scope.focusModeIdentifier {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption2)
                        Text("Linked to Focus")
                            .font(.caption2)
                    }
                    .foregroundStyle(.purple)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    NavigationStack {
        FocusScopeManagementView(
            store: Store(
                initialState: FocusScopeFeature.State(
                    scopes: [
                        .init(
                            from: .init(
                                name: "Work",
                                emoji: "💼",
                                colorHex: "#007AFF"
                            )
                        ),
                        .init(
                            from: .init(
                                name: "Personal",
                                emoji: "🏠",
                                colorHex: "#34C759"
                            )
                        ),
                    ]
                )
            ) {
                FocusScopeFeature()
            }
        )
    }
}
