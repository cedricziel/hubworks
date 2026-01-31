import ComposableArchitecture
import HubWorksCore
import HubWorksFeatures
import SwiftData
import SwiftUI

@main
struct HubWorksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        // Main window - opens on launch
        WindowGroup {
            MainWindowView(store: store)
                .modelContainer(HubWorksCore.modelContainer)
        }
        .defaultSize(width: 900, height: 650)
        .windowResizability(.automatic)

        // Menu bar extra for quick access
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarIcon(store: store)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .modelContainer(HubWorksCore.modelContainer)
        }
    }
}

// MARK: - Main Window View

struct MainWindowView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.isAuthenticated {
                InboxView(
                    store: store.scope(state: \.inbox, action: \.inbox)
                )
            } else {
                AuthView(
                    store: store.scope(state: \.auth, action: \.auth)
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Menu Bar Views

struct MenuBarIcon: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: store.inbox.unreadCount > 0 ? "bell.badge.fill" : "bell")
            if store.inbox.unreadCount > 0 {
                Text("\(store.inbox.unreadCount)")
                    .font(.caption2)
            }
        }
    }
}

struct MenuBarContentView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if store.isAuthenticated {
                // Quick notification list
                if store.inbox.notifications.isEmpty {
                    ContentUnavailableView {
                        Label("No Notifications", systemImage: "tray")
                    } description: {
                        Text("You're all caught up!")
                    }
                    .frame(width: 300, height: 200)
                } else {
                    List {
                        ForEach(store.inbox.notifications.prefix(10)) { notification in
                            NotificationMenuRowView(notification: notification)
                                .onTapGesture {
                                    store.send(.inbox(.notificationTapped(notification.id)))
                                }
                        }
                    }
                    .listStyle(.plain)
                    .frame(width: 350, height: 400)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("Sign in to see notifications")
                        .font(.headline)
                    Text("Open the main window to sign in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 300, height: 200)
            }

            Divider()

            HStack {
                Button("Open Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "HubWorks" || $0.isKeyWindow }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }
}

// MARK: - Menu Bar Notification Row

struct NotificationMenuRowView: View {
    let notification: NotificationRowState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: notification.subjectType.systemImage)
                .foregroundStyle(notification.isUnread ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.caption)
                    .fontWeight(notification.isUnread ? .semibold : .regular)
                    .lineLimit(1)

                Text(notification.repositoryFullName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if notification.isUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}
