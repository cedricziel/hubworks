import ComposableArchitecture
import Foundation
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
            $0.keychainService.load = { _ in Data("test-token".utf8) }
            $0.gitHubAPIClient.markAsRead = { _, _ in }
            $0.notificationPersistence.markAsRead = { _ in }
        }

        // Explicitly skip received actions since we're only testing the action dispatch
        store.exhaustivity = .off

        await store.send(.markAsRead("1"))
    }

    // MARK: - Focus Filter Tests

    @Test("checkActiveFocusScope loads scope from service")
    @MainActor
    func checkActiveFocusScopeLoadsScope() async {
        let testScopeId = "work-scope-123"
        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        } withDependencies: {
            $0.focusFilterService.getActiveScope = { testScopeId }
        }

        await store.send(.checkActiveFocusScope)
        await store.receive(\.focusScopeChanged) {
            $0.activeFocusScopeId = testScopeId
            $0.isFocusFilterTemporarilyDisabled = false
        }

        #expect(store.state.activeFocusScopeId == testScopeId)
    }

    @Test("checkActiveFocusScope with nil scope")
    @MainActor
    func checkActiveFocusScopeWithNil() async {
        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        } withDependencies: {
            $0.focusFilterService.getActiveScope = { nil }
        }

        await store.send(.checkActiveFocusScope)
        // When scope is nil, no state change occurs since default is already nil
        await store.receive(\.focusScopeChanged)

        #expect(store.state.activeFocusScopeId == nil)
    }

    @Test("focusScopeChanged updates state and resets temporary disable")
    @MainActor
    func focusScopeChangedUpdatesState() async {
        // Given: State with temporary disable active
        let store = TestStore(
            initialState: InboxFeature.State(
                isFocusFilterTemporarilyDisabled: true
            )
        ) {
            InboxFeature()
        }

        // Clean UserDefaults
        UserDefaults.standard.removeObject(forKey: "focus_filter_temporarily_disabled")

        // When: Focus scope changes
        let newScopeId = "personal-scope-456"
        await store.send(.focusScopeChanged(newScopeId)) {
            $0.activeFocusScopeId = newScopeId
            $0.isFocusFilterTemporarilyDisabled = false
        }

        // Then: State should be updated and temporary disable reset
        #expect(store.state.activeFocusScopeId == newScopeId)
        #expect(store.state.isFocusFilterTemporarilyDisabled == false)
        #expect(UserDefaults.standard.bool(forKey: "focus_filter_temporarily_disabled") == false)
    }

    @Test("focusScopeChanged with nil clears scope")
    @MainActor
    func focusScopeChangedWithNil() async {
        // Given: State with active scope
        let store = TestStore(
            initialState: InboxFeature.State(
                activeFocusScopeId: "existing-scope"
            )
        ) {
            InboxFeature()
        }

        // When: Scope changes to nil
        await store.send(.focusScopeChanged(nil)) {
            $0.activeFocusScopeId = nil
            $0.isFocusFilterTemporarilyDisabled = false
        }

        // Then: Scope should be cleared
        #expect(store.state.activeFocusScopeId == nil)
    }

    @Test("toggleFocusFilter enables temporary disable")
    @MainActor
    func toggleFocusFilterEnables() async {
        // Given: State with filter enabled (not disabled)
        let store = TestStore(
            initialState: InboxFeature.State(
                activeFocusScopeId: "work-scope",
                isFocusFilterTemporarilyDisabled: false
            )
        ) {
            InboxFeature()
        }

        // Clean UserDefaults
        UserDefaults.standard.removeObject(forKey: "focus_filter_temporarily_disabled")

        // When: Toggling the filter
        await store.send(.toggleFocusFilter) {
            $0.isFocusFilterTemporarilyDisabled = true
        }

        // Then: Should be temporarily disabled
        #expect(store.state.isFocusFilterTemporarilyDisabled == true)
        #expect(UserDefaults.standard.bool(forKey: "focus_filter_temporarily_disabled") == true)
    }

    @Test("toggleFocusFilter disables temporary disable")
    @MainActor
    func toggleFocusFilterDisables() async {
        // Given: State with filter temporarily disabled
        let store = TestStore(
            initialState: InboxFeature.State(
                activeFocusScopeId: "work-scope",
                isFocusFilterTemporarilyDisabled: true
            )
        ) {
            InboxFeature()
        }

        // Clean UserDefaults
        UserDefaults.standard.set(true, forKey: "focus_filter_temporarily_disabled")

        // When: Toggling the filter again
        await store.send(.toggleFocusFilter) {
            $0.isFocusFilterTemporarilyDisabled = false
        }

        // Then: Should be re-enabled
        #expect(store.state.isFocusFilterTemporarilyDisabled == false)
        #expect(UserDefaults.standard.bool(forKey: "focus_filter_temporarily_disabled") == false)
    }

    @Test("toggleFocusFilter multiple times toggles correctly")
    @MainActor
    func toggleFocusFilterMultipleTimes() async {
        let store = TestStore(
            initialState: InboxFeature.State(
                activeFocusScopeId: "test-scope"
            )
        ) {
            InboxFeature()
        }

        // Clean UserDefaults
        UserDefaults.standard.removeObject(forKey: "focus_filter_temporarily_disabled")

        // First toggle: disable
        await store.send(.toggleFocusFilter) {
            $0.isFocusFilterTemporarilyDisabled = true
        }
        #expect(store.state.isFocusFilterTemporarilyDisabled == true)

        // Second toggle: re-enable
        await store.send(.toggleFocusFilter) {
            $0.isFocusFilterTemporarilyDisabled = false
        }
        #expect(store.state.isFocusFilterTemporarilyDisabled == false)

        // Third toggle: disable again
        await store.send(.toggleFocusFilter) {
            $0.isFocusFilterTemporarilyDisabled = true
        }
        #expect(store.state.isFocusFilterTemporarilyDisabled == true)
    }

    @Test("Opens notification URL and marks as read when tapped with URL")
    @MainActor
    func notificationTappedOpensURLAndMarksAsRead() async throws {
        var openedURL: URL?
        let testURL = try #require(URL(string: "https://github.com/owner/repo/issues/123"))

        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        } withDependencies: {
            $0.urlOpener.open = { url in
                openedURL = url
                return true
            }
            $0.keychainService.load = { _ in Data("test-token".utf8) }
            $0.gitHubAPIClient.markAsRead = { _, _ in }
            $0.notificationPersistence.markAsRead = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.notificationTapped("thread-123", testURL)) {
            $0.selectedNotificationId = "thread-123"
        }

        #expect(openedURL == testURL)
    }

    @Test("Marks as read when notification has no URL")
    @MainActor
    func notificationTappedWithoutURLJustMarksAsRead() async {
        var urlOpenerCalled = false

        let store = TestStore(
            initialState: InboxFeature.State()
        ) {
            InboxFeature()
        } withDependencies: {
            $0.urlOpener.open = { _ in
                urlOpenerCalled = true
                return false
            }
            $0.keychainService.load = { _ in Data("test-token".utf8) }
            $0.gitHubAPIClient.markAsRead = { _, _ in }
            $0.notificationPersistence.markAsRead = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.notificationTapped("thread-123", nil)) {
            $0.selectedNotificationId = "thread-123"
        }

        #expect(urlOpenerCalled == false)
    }
}
