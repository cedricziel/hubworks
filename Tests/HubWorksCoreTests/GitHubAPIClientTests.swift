import ComposableArchitecture
import Testing
@testable import HubWorksCore

@Suite("GitHubAPIClient Tests")
struct GitHubAPIClientTests {
    @Test("Fetch notifications returns parsed data")
    func fetchNotifications() {
        let client = withDependencies {
            $0.gitHubAPIClient = .testValue
        } operation: {
            @Dependency(\.gitHubAPIClient) var client
            return client
        }

        // Test would go here with mocked responses
    }

    @Test("Mark as read succeeds")
    func markAsRead() {
        // Test implementation
    }

    @Test("Handles rate limiting")
    func rateLimiting() {
        // Test implementation
    }
}
