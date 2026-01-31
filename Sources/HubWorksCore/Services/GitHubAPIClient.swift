import ComposableArchitecture
import Foundation

public struct GitHubNotification: Codable, Equatable, Sendable {
    public let id: String
    public let unread: Bool
    public let reason: String
    public let updatedAt: String
    public let lastReadAt: String?
    public let subject: Subject
    public let repository: Repository
    public let url: String

    enum CodingKeys: String, CodingKey {
        case id, unread, reason, subject, repository, url
        case updatedAt = "updated_at"
        case lastReadAt = "last_read_at"
    }

    public struct Subject: Codable, Equatable, Sendable {
        public let title: String
        public let url: String?
        public let latestCommentUrl: String?
        public let type: String

        enum CodingKeys: String, CodingKey {
            case title, url, type
            case latestCommentUrl = "latest_comment_url"
        }
    }

    public struct Repository: Codable, Equatable, Sendable {
        public let id: Int
        public let name: String
        public let fullName: String
        public let owner: Owner
        public let `private`: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, owner
            case fullName = "full_name"
            case `private`
        }

        public struct Owner: Codable, Equatable, Sendable {
            public let login: String
            public let avatarUrl: String?

            enum CodingKeys: String, CodingKey {
                case login
                case avatarUrl = "avatar_url"
            }
        }
    }
}

public struct GitHubUser: Codable, Equatable, Sendable {
    public let id: Int
    public let login: String
    public let name: String?
    public let email: String?
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login, name, email
        case avatarUrl = "avatar_url"
    }
}

public struct NotificationFetchResult: Equatable, Sendable {
    public let notifications: [GitHubNotification]
    public let lastModified: String?
    public let pollInterval: Int?
    public let wasModified: Bool

    public init(
        notifications: [GitHubNotification],
        lastModified: String?,
        pollInterval: Int?,
        wasModified: Bool
    ) {
        self.notifications = notifications
        self.lastModified = lastModified
        self.pollInterval = pollInterval
        self.wasModified = wasModified
    }
}

public enum GitHubAPIError: Error, Equatable, Sendable {
    case invalidURL
    case unauthorized
    case rateLimited(resetAt: Date?)
    case notModified
    case networkError(String)
    case decodingError(String)
    case serverError(Int, String)
}

@DependencyClient
public struct GitHubAPIClient: Sendable {
    public var fetchNotifications: @Sendable (
        _ token: String,
        _ lastModified: String?,
        _ all: Bool,
        _ participating: Bool
    ) async throws -> NotificationFetchResult

    public var markAsRead: @Sendable (_ token: String, _ threadId: String) async throws -> Void
    public var markAllAsRead: @Sendable (_ token: String, _ lastReadAt: Date?) async throws -> Void
    public var fetchCurrentUser: @Sendable (_ token: String) async throws -> GitHubUser
    public var unsubscribe: @Sendable (_ token: String, _ threadId: String) async throws -> Void
}

extension GitHubAPIClient: DependencyKey {
    public static let liveValue: GitHubAPIClient = {
        let baseURL = URL(string: "https://api.github.com")!

        @Sendable
        func makeRequest(
            path: String,
            token: String,
            method: String = "GET",
            additionalHeaders: [String: String] = [:]
        ) -> URLRequest {
            var request = URLRequest(url: baseURL.appendingPathComponent(path))
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

            for (key, value) in additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            return request
        }

        /// Parses the Link header to find the next page URL
        @Sendable
        func parseNextPageURL(from linkHeader: String?) -> URL? {
            guard let linkHeader else { return nil }
            // Link header format: <url>; rel="next", <url>; rel="last"
            let links = linkHeader.components(separatedBy: ",")
            for link in links {
                let parts = link.components(separatedBy: ";")
                guard parts.count >= 2 else { continue }
                let urlPart = parts[0].trimmingCharacters(in: .whitespaces)
                let relPart = parts[1].trimmingCharacters(in: .whitespaces)
                if relPart.contains("rel=\"next\"") {
                    // Extract URL from < >
                    let url = urlPart
                        .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                    return URL(string: url)
                }
            }
            return nil
        }

        return GitHubAPIClient(
            fetchNotifications: { token, lastModified, all, participating in
                var allNotifications: [GitHubNotification] = []
                var currentLastModified: String? = nil
                var pollInterval: Int? = nil

                // Build initial URL with per_page=100 (GitHub's maximum)
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "per_page", value: "100")
                ]

                if all {
                    queryItems.append(URLQueryItem(name: "all", value: "true"))
                }
                if participating {
                    queryItems.append(URLQueryItem(name: "participating", value: "true"))
                }

                var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/notifications"), resolvingAgainstBaseURL: false)!
                urlComponents.queryItems = queryItems

                guard var currentURL = urlComponents.url else {
                    throw GitHubAPIError.invalidURL
                }

                // Paginate through all results until no more pages
                // Safety limit of 50 pages (5000 notifications) to prevent runaway requests
                var pageCount = 0
                let safetyLimit = 50

                while pageCount < safetyLimit {
                    pageCount += 1

                    var request = URLRequest(url: currentURL)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

                    // Only use If-Modified-Since on first request
                    if pageCount == 1, let lastModified {
                        request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
                    }

                    let (data, response) = try await URLSession.shared.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw GitHubAPIError.networkError("Invalid response type")
                    }

                    // Capture headers from first response
                    if pageCount == 1 {
                        currentLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
                        let pollIntervalString = httpResponse.value(forHTTPHeaderField: "X-Poll-Interval")
                        pollInterval = pollIntervalString.flatMap { Int($0) }
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let notifications = try decoder.decode([GitHubNotification].self, from: data)
                        allNotifications.append(contentsOf: notifications)

                        // Check for next page
                        let linkHeader = httpResponse.value(forHTTPHeaderField: "Link")
                        if let nextURL = parseNextPageURL(from: linkHeader) {
                            currentURL = nextURL
                        } else {
                            // No more pages
                            break
                        }

                    case 304:
                        // Not modified - return empty with preserved lastModified
                        return NotificationFetchResult(
                            notifications: [],
                            lastModified: currentLastModified ?? lastModified,
                            pollInterval: pollInterval,
                            wasModified: false
                        )

                    case 401:
                        throw GitHubAPIError.unauthorized

                    case 403:
                        let resetHeader = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                        let resetDate = resetHeader
                            .flatMap { TimeInterval($0) }
                            .map { Date(timeIntervalSince1970: $0) }
                        throw GitHubAPIError.rateLimited(resetAt: resetDate)

                    default:
                        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw GitHubAPIError.serverError(httpResponse.statusCode, message)
                    }
                }

                return NotificationFetchResult(
                    notifications: allNotifications,
                    lastModified: currentLastModified,
                    pollInterval: pollInterval,
                    wasModified: true
                )
            },

            markAsRead: { token, threadId in
                let request = makeRequest(
                    path: "/notifications/threads/\(threadId)",
                    token: token,
                    method: "PATCH"
                )

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.networkError("Invalid response type")
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    throw GitHubAPIError.serverError(httpResponse.statusCode, "Failed to mark as read")
                }
            },

            markAllAsRead: { token, lastReadAt in
                var request = makeRequest(
                    path: "/notifications",
                    token: token,
                    method: "PUT"
                )

                if let lastReadAt {
                    let formatter = ISO8601DateFormatter()
                    let body = ["last_read_at": formatter.string(from: lastReadAt)]
                    request.httpBody = try JSONEncoder().encode(body)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.networkError("Invalid response type")
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    throw GitHubAPIError.serverError(httpResponse.statusCode, "Failed to mark all as read")
                }
            },

            fetchCurrentUser: { token in
                let request = makeRequest(path: "/user", token: token)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.networkError("Invalid response type")
                }

                switch httpResponse.statusCode {
                case 200:
                    return try JSONDecoder().decode(GitHubUser.self, from: data)
                case 401:
                    throw GitHubAPIError.unauthorized
                default:
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw GitHubAPIError.serverError(httpResponse.statusCode, message)
                }
            },

            unsubscribe: { token, threadId in
                let request = makeRequest(
                    path: "/notifications/threads/\(threadId)/subscription",
                    token: token,
                    method: "DELETE"
                )

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.networkError("Invalid response type")
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    throw GitHubAPIError.serverError(httpResponse.statusCode, "Failed to unsubscribe")
                }
            }
        )
    }()

    public static let testValue = GitHubAPIClient()
}

extension DependencyValues {
    public var gitHubAPIClient: GitHubAPIClient {
        get { self[GitHubAPIClient.self] }
        set { self[GitHubAPIClient.self] = newValue }
    }
}
