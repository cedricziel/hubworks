import ComposableArchitecture
import HubWorksCore
import SwiftUI

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView {
            AccountsTab(store: store)
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }

            NotificationsTab(store: store)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            DisplayTab(store: store)
                .tabItem {
                    Label("Display", systemImage: "rectangle.3.group")
                }

            GeneralTab(store: store)
                .tabItem {
                    Label("General", systemImage: "info.circle")
                }
        }
        .frame(width: 700, height: 550)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Accounts Tab

private struct AccountsTab: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
            Section {
                if store.isLoadingUser {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading account...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if let error = store.userLoadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unable to load account", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            store.send(.loadCurrentUser)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                } else if store.accounts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No accounts connected")
                            .foregroundStyle(.secondary)
                        Button {
                            store.send(.addAccountTapped)
                        } label: {
                            Label("Add GitHub Account...", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(store.accounts) { account in
                        AccountRow(account: account) {
                            store.send(.removeAccount(account.id))
                        }
                    }
                }
            } header: {
                Text("Connected Accounts")
            } footer: {
                Text("Your GitHub account is used to fetch notifications.")
            }

            if !store.accounts.isEmpty {
                Section {
                    Button(role: .destructive) {
                        store.send(.signOutTapped)
                    } label: {
                        Label("Sign Out of All Accounts", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: SettingsFeature.State.AccountState
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.separator, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.username)
                    .font(.headline)
                if let email = account.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove account")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notifications Tab

private struct NotificationsTab: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var showFocusFilters = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Enable Notifications",
                    isOn: $store.notificationsEnabled.sending(\.notificationsEnabledChanged)
                )

                Toggle(
                    "Show Unread Badge in Dock",
                    isOn: $store.showUnreadBadge.sending(\.showUnreadBadgeChanged)
                )
                .disabled(!store.notificationsEnabled)
            } header: {
                Text("Alerts")
            } footer: {
                Text("""
                When enabled, HubWorks will show notifications for new GitHub \
                activity and display an unread count badge on the app icon.
                """)
            }

            Section {
                Picker(
                    "Poll Interval",
                    selection: $store.pollInterval.sending(\.pollIntervalChanged)
                ) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("15 minutes").tag(900)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Polling")
            } footer: {
                Text("How often HubWorks checks GitHub for new notifications. More frequent polling uses more battery and API quota.")
            }

            Section {
                Button {
                    showFocusFilters = true
                } label: {
                    HStack {
                        Label("Focus Filters", systemImage: "moon.stars")
                        Spacer()
                        Text("Configure...")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Focus Modes")
            } footer: {
                Text("""
                Configure notification filters for different Focus modes. \
                Filter notifications by organizations and repositories based on your active Focus.
                """)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showFocusFilters) {
            NavigationStack {
                FocusScopeManagementView(
                    store: store.scope(state: \.focusScopes, action: \.focusScopes)
                )
            }
        }
    }
}

// MARK: - Display Tab

private struct DisplayTab: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @AppStorage("menubar_notification_limit") private var menubarNotificationLimit = 10

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Group Notifications by Repository",
                    isOn: $store.groupByRepository.sending(\.groupByRepositoryChanged)
                )
            } header: {
                Text("Organization")
            } footer: {
                Text("When enabled, notifications are grouped by their repository. Otherwise, they appear in chronological order.")
            }

            Section {
                Picker("Maximum Notifications", selection: $menubarNotificationLimit) {
                    Text("10 notifications").tag(10)
                    Text("20 notifications").tag(20)
                    Text("50 notifications").tag(50)
                    Text("Show All").tag(999)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("""
                The maximum number of notifications to display in the menu bar dropdown. \
                Choose "Show All" to display all matching notifications.
                """)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var store: StoreOf<SettingsFeature>

    private enum URLs {
        // swiftlint:disable:next force_unwrapping
        static let sourceCode = URL(string: "https://github.com/cedricziel/hubworks")!
        // swiftlint:disable:next force_unwrapping
        static let issues = URL(string: "https://github.com/cedricziel/hubworks/issues")!
        // swiftlint:disable:next force_unwrapping
        static let releases = URL(string: "https://github.com/cedricziel/hubworks/releases")!
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: store.appVersion)
                LabeledContent("Build", value: store.buildNumber)
            } header: {
                Text("About")
            }

            Section {
                Link(destination: URLs.sourceCode) {
                    HStack {
                        Label("View Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URLs.issues) {
                    HStack {
                        Label("Report an Issue", systemImage: "ladybug")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URLs.releases) {
                    HStack {
                        Label("Release Notes", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Links")
            }

            Section {
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("HubWorks")
                        .font(.headline)

                    Text("Your GitHub notifications, everywhere.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
    )
}

#Preview("With Account") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(
                accounts: [
                    .init(
                        id: "default",
                        username: "octocat",
                        avatarURL: URL(string: "https://github.com/octocat.png"),
                        email: "octocat@github.com"
                    ),
                ]
            )
        ) {
            SettingsFeature()
        }
    )
}

#Preview("Loading") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(isLoadingUser: true)
        ) {
            SettingsFeature()
        }
    )
}

#Preview("Error") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(userLoadError: "Network connection failed")
        ) {
            SettingsFeature()
        }
    )
}
