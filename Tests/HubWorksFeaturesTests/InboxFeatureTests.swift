import ComposableArchitecture
import Testing
@testable import HubWorksCore
@testable import HubWorksFeatures

@Suite("InboxFeature Tests")
struct InboxFeatureTests {
    @Test("Changes filter state")
    @MainActor
    func filterChanged() async {
        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        }

        await store.send(.filterChanged(.unread)) {
            $0.filter = .unread
        }

        #expect(store.state.filter == .unread)
    }

    @Test("Selects repository")
    @MainActor
    func repositorySelected() async {
        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        }

        await store.send(.repositorySelected("owner/repo")) {
            $0.selectedRepository = "owner/repo"
        }

        #expect(store.state.selectedRepository == "owner/repo")

        await store.send(.repositorySelected(nil)) {
            $0.selectedRepository = nil
        }

        #expect(store.state.selectedRepository == nil)
    }

    @Test("Toggles group by repository")
    @MainActor
    func toggleGroupByRepository() async {
        let store = TestStore(
            initialState: InboxFeature.State(groupByRepository: true)
        ) {
            InboxFeature()
        }

        await store.send(.toggleGroupByRepository) {
            $0.groupByRepository = false
        }

        #expect(store.state.groupByRepository == false)
    }

    @Test("Marks notification as read")
    @MainActor
    func markAsRead() async {
        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        } withDependencies: {
            $0.keychainService.loadToken = { _ in "test-token" }
            $0.gitHubAPIClient.markAsRead = { _, _ in }
        }

        await store.send(.markAsRead("1"))
        await store.receive(.markAsReadCompleted("1"))
    }
}
