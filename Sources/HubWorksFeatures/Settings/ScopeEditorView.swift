import ComposableArchitecture
import SwiftUI

public struct ScopeEditorView: View {
    @Bindable var store: StoreOf<ScopeEditorFeature>

    public init(store: StoreOf<ScopeEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            if store.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Section("Scope Details") {
                    TextField("Name", text: $store.name.sending(\.nameChanged))
                        .textContentType(.name)

                    TextField("Emoji", text: $store.emoji.sending(\.emojiChanged))
                        .font(.title2)

                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: store.colorHex) ?? .blue },
                        set: { newColor in
                            store.send(.colorChanged(newColor.toHex() ?? "#007AFF"))
                        }
                    ))
                }

                Section {
                    ForEach(store.selectedOrganizations, id: \.self) { org in
                        HStack {
                            Text(org)
                            Spacer()
                            Button {
                                store.send(.removeOrganization(org))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        // Show organization picker
                        // This will be implemented when navigation is added
                    } label: {
                        Label("Add Organization", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Organizations")
                } footer: {
                    Text("Filter notifications from specific organizations (e.g., \"mycompany\", \"work-org\")")
                }

                Section {
                    ForEach(store.selectedRepositories, id: \.self) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.components(separatedBy: "/").last ?? repo)
                                    .font(.body)
                                if repo.contains("/") {
                                    Text(repo.components(separatedBy: "/").first ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                store.send(.removeRepository(repo))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        // Show repository picker
                        // This will be implemented when navigation is added
                    } label: {
                        Label("Add Repository", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Repositories")
                } footer: {
                    Text("Filter notifications from specific repositories (e.g., \"owner/repo\")")
                }

                Section {
                    Toggle("Enable Quiet Hours", isOn: Binding(
                        get: { store.quietHoursEnabled },
                        set: { _ in store.send(.toggleQuietHours) }
                    ))

                    if store.quietHoursEnabled {
                        DatePicker(
                            "Start",
                            selection: Binding(
                                get: { dateFromHour(store.quietHoursStart) },
                                set: { store.send(.quietHoursStartChanged(hourFromDate($0))) }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        DatePicker(
                            "End",
                            selection: Binding(
                                get: { dateFromHour(store.quietHoursEnd) },
                                set: { store.send(.quietHoursEndChanged(hourFromDate($0))) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Quiet Hours")
                } footer: {
                    if store.quietHoursEnabled {
                        Text("Notifications will be silenced during these hours")
                    }
                }

                if let error = store.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(store.isNewScope ? "New Scope" : "Edit Scope")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.save)
                    }
                    .disabled(!store.canSave || store.isSaving)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.cancel)
                    }
                    .disabled(store.isSaving)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
    }

    private func dateFromHour(_ hour: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func hourFromDate(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

extension Color {
    func toHex() -> String? {
        #if os(macOS)
        guard let components = NSColor(self).cgColor.components else { return nil }
        #else
        guard let components = UIColor(self).cgColor.components else { return nil }
        #endif

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)
        )
    }
}

#Preview("New Scope") {
    NavigationStack {
        ScopeEditorView(
            store: Store(initialState: ScopeEditorFeature.State()) {
                ScopeEditorFeature()
            }
        )
    }
}

#Preview("Edit Scope") {
    NavigationStack {
        ScopeEditorView(
            store: Store(
                initialState: ScopeEditorFeature.State(
                    scopeId: "123",
                    name: "Work",
                    emoji: "💼",
                    selectedOrganizations: ["mycompany", "work-org"],
                    selectedRepositories: ["mycompany/backend", "mycompany/frontend"],
                    quietHoursEnabled: true
                )
            ) {
                ScopeEditorFeature()
            }
        )
    }
}
