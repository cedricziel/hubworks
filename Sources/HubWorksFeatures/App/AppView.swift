import ComposableArchitecture
import HubWorksCore
import HubWorksUI
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading...")
            } else if store.isAuthenticated {
                authenticatedContent
            } else {
                AuthView(
                    store: store.scope(state: \.auth, action: \.auth)
                )
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        #if os(iOS)
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            InboxView(
                store: store.scope(state: \.inbox, action: \.inbox)
            )
            .tabItem {
                Label("Inbox", systemImage: "tray")
            }
            .tag(AppFeature.State.Tab.inbox)

            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(AppFeature.State.Tab.settings)
        }
        #elseif os(macOS)
        NavigationSplitView {
            List(selection: $store.selectedTab.sending(\.tabSelected)) {
                Label("Inbox", systemImage: "tray")
                    .tag(AppFeature.State.Tab.inbox)
                Label("Settings", systemImage: "gear")
                    .tag(AppFeature.State.Tab.settings)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch store.selectedTab {
            case .inbox:
                InboxView(
                    store: store.scope(state: \.inbox, action: \.inbox)
                )
            case .settings:
                SettingsView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
        #endif
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
