import ComposableArchitecture
import HubWorksCore
import SwiftUI

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                accountsSection
                notificationsSection
                displaySection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    private var accountsSection: some View {
        Section("Accounts") {
            ForEach(store.accounts) { account in
                HStack {
                    AsyncImage(url: account.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(account.username)
                            .font(.headline)
                        if let email = account.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        store.send(.removeAccount(account.id))
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            if store.accounts.isEmpty {
                Text("No accounts connected")
                    .foregroundStyle(.secondary)
            }

            Button {
                store.send(.addAccountTapped)
            } label: {
                Label("Add Account", systemImage: "plus.circle")
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(
                "Enable Notifications",
                isOn: $store.notificationsEnabled.sending(\.notificationsEnabledChanged)
            )

            Toggle(
                "Show Unread Badge",
                isOn: $store.showUnreadBadge.sending(\.showUnreadBadgeChanged)
            )

            Picker(
                "Poll Interval",
                selection: $store.pollInterval.sending(\.pollIntervalChanged)
            ) {
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
                Text("5 minutes").tag(300)
            }
        }
    }

    @ViewBuilder
    private var displaySection: some View {
        Section("Display") {
            Toggle(
                "Group by Repository",
                isOn: $store.groupByRepository.sending(\.groupByRepositoryChanged)
            )
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(store.appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/your-username/hubworks")!) {
                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: URL(string: "https://github.com/your-username/hubworks/issues")!) {
                Label("Report an Issue", systemImage: "ladybug")
            }

            Button(role: .destructive) {
                store.send(.signOutTapped)
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
    )
}
