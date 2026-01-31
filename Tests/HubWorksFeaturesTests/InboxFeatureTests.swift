import ComposableArchitecture
import Testing
@testable import HubWorksCore
@testable import HubWorksFeatures

@Suite("InboxFeature Tests")
struct InboxFeatureTests {
    @Test("Filters notifications correctly")
    func filterNotifications() async {
        let store = TestStore(
            initialState: InboxFeature.State(
                notifications: [
                    NotificationRowState(
                        id: "1",
                        threadId: "1",
                        title: "Test notification",
                        repositoryFullName: "owner/repo",
                        repositoryOwner: "owner",
                        repositoryAvatarURL: nil,
                        subjectType: .issue,
                        reason: .mention,
                        isUnread: true,
                        updatedAt: .now,
                        webURL: nil
                    ),
                    NotificationRowState(
                        id: "2",
                        threadId: "2",
                        title: "Read notification",
                        repositoryFullName: "owner/repo",
                        repositoryOwner: "owner",
                        repositoryAvatarURL: nil,
                        subjectType: .pullRequest,
                        reason: .subscribed,
                        isUnread: false,
                        updatedAt: .now,
                        webURL: nil
                    ),
                ]
            )
        ) {
            InboxFeature()
        }

        await store.send(.filterChanged(.unread)) {
            $0.filter = .unread
        }

        #expect(store.state.filteredNotifications.count == 1)
        #expect(store.state.filteredNotifications.first?.id == "1")
    }

    @Test("Groups notifications by repository")
    func groupByRepository() {
        let state = InboxFeature.State(
            notifications: [
                NotificationRowState(
                    id: "1",
                    threadId: "1",
                    title: "First",
                    repositoryFullName: "owner/repo-a",
                    repositoryOwner: "owner",
                    repositoryAvatarURL: nil,
                    subjectType: .issue,
                    reason: .mention,
                    isUnread: true,
                    updatedAt: .now,
                    webURL: nil
                ),
                NotificationRowState(
                    id: "2",
                    threadId: "2",
                    title: "Second",
                    repositoryFullName: "owner/repo-b",
                    repositoryOwner: "owner",
                    repositoryAvatarURL: nil,
                    subjectType: .pullRequest,
                    reason: .subscribed,
                    isUnread: true,
                    updatedAt: .now,
                    webURL: nil
                ),
            ],
            groupByRepository: true
        )

        let grouped = state.groupedNotifications
        #expect(grouped.count == 2)
    }

    @Test("Marks notification as read")
    func markAsRead() async {
        let store = TestStore(
            initialState: InboxFeature.State(
                notifications: [
                    NotificationRowState(
                        id: "1",
                        threadId: "1",
                        title: "Test",
                        repositoryFullName: "owner/repo",
                        repositoryOwner: "owner",
                        repositoryAvatarURL: nil,
                        subjectType: .issue,
                        reason: .mention,
                        isUnread: true,
                        updatedAt: .now,
                        webURL: nil
                    ),
                ]
            )
        ) {
            InboxFeature()
        } withDependencies: {
            $0.keychainService.loadToken = { _ in "test-token" }
            $0.gitHubAPIClient.markAsRead = { _, _ in }
        }

        await store.send(.markAsRead("1"))
        await store.receive(.markAsReadCompleted("1")) {
            $0.notifications[id: "1"]?.isUnread = false
        }
    }
}
