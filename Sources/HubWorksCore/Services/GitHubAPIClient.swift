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

public enum GitHubAPIError: Error, Equatable, Sendable {
    case invalidURL
    case unauthorized
    case rateLimited(resetAt: Date?)
    case notModified
    case networkError(String)
    case decodingError(String)
    case serverError(Int, String)
}

/// Rate limit information from GitHub API
public struct RateLimitInfo: Equatable, Sendable {
    public let limit: Int // Total requests allowed per hour
    public let remaining: Int // Requests remaining
    public let reset: Date // When the limit resets
    public let used: Int // Requests used this hour

    public init(limit: Int, remaining: Int, reset: Date, used: Int) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
        self.used = used
    }

    /// Percentage of rate limit remaining (0.0 to 1.0)
    public var percentRemaining: Double {
        guard limit > 0 else { return 1.0 }
        return Double(remaining) / Double(limit)
    }

    /// Time until rate limit resets
    public var timeUntilReset: TimeInterval {
        reset.timeIntervalSinceNow
    }

    /// Whether we're running low on requests (< 10%)
    public var isLow: Bool {
        percentRemaining < 0.1
    }
}

/// Result for a single page of notifications
public struct NotificationPageResult: Equatable, Sendable {
    public let notifications: [GitHubNotification]
    public let lastModified: String?
    public let pollInterval: Int?
    public let hasMorePages: Bool
    public let isFirstPage: Bool
    public let rateLimit: RateLimitInfo?

    public init(
        notifications: [GitHubNotification],
        lastModified: String?,
        pollInterval: Int?,
        hasMorePages: Bool,
        isFirstPage: Bool,
        rateLimit: RateLimitInfo? = nil
    ) {
        self.notifications = notifications
        self.lastModified = lastModified
        self.pollInterval = pollInterval
        self.hasMorePages = hasMorePages
        self.isFirstPage = isFirstPage
        self.rateLimit = rateLimit
    }
}

@DependencyClient
public struct GitHubAPIClient: Sendable {
    /// Stream notifications page by page for progressive loading
    public var fetchNotificationsStream: @Sendable (
        _ token: String,
        _ lastModified: String?,
        _ all: Bool,
        _ participating: Bool
    ) -> AsyncThrowingStream<NotificationPageResult, Error> = { _, _, _, _ in
        AsyncThrowingStream { $0.finish() }
    }

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

        /// Parses rate limit headers from GitHub API response
        @Sendable
        func parseRateLimit(from response: HTTPURLResponse) -> RateLimitInfo? {
            guard
                let limitStr = response.value(forHTTPHeaderField: "X-RateLimit-Limit"),
                let limit = Int(limitStr),
                let remainingStr = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
                let remaining = Int(remainingStr),
                let resetStr = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
                let resetTimestamp = TimeInterval(resetStr),
                let usedStr = response.value(forHTTPHeaderField: "X-RateLimit-Used"),
                let used = Int(usedStr)
            else {
                return nil
            }

            return RateLimitInfo(
                limit: limit,
                remaining: remaining,
                reset: Date(timeIntervalSince1970: resetTimestamp),
                used: used
            )
        }

        return GitHubAPIClient(
            fetchNotificationsStream: { token, lastModified, all, participating in
                AsyncThrowingStream { continuation in
                    Task {
                        var currentLastModified: String?
                        var pollInterval: Int?

                        // Build initial URL with per_page=100 (GitHub's maximum)
                        var queryItems: [URLQueryItem] = [
                            URLQueryItem(name: "per_page", value: "100"),
                        ]

                        if all {
                            queryItems.append(URLQueryItem(name: "all", value: "true"))
                        }
                        if participating {
                            queryItems.append(URLQueryItem(name: "participating", value: "true"))
                        }

                        var urlComponents = URLComponents(
                            url: baseURL.appendingPathComponent("/notifications"),
                            resolvingAgainstBaseURL: false
                        )!
                        urlComponents.queryItems = queryItems

                        guard var currentURL = urlComponents.url else {
                            continuation.finish(throwing: GitHubAPIError.invalidURL)
                            return
                        }

                        var isFirstPage = true

                        while true {
                            var request = URLRequest(url: currentURL)
                            request.httpMethod = "GET"
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

                            // Only use If-Modified-Since on first request
                            if isFirstPage, let lastModified {
                                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
                            }

                            do {
                                let (data, response) = try await URLSession.shared.data(for: request)

                                guard let httpResponse = response as? HTTPURLResponse else {
                                    continuation.finish(throwing: GitHubAPIError.networkError("Invalid response type"))
                                    return
                                }

                                // Capture headers from first response
                                if isFirstPage {
                                    currentLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
                                    let pollIntervalString = httpResponse.value(forHTTPHeaderField: "X-Poll-Interval")
                                    pollInterval = pollIntervalString.flatMap { Int($0) }
                                }

                                // Parse rate limit from every response
                                let rateLimit = parseRateLimit(from: httpResponse)

                                switch httpResponse.statusCode {
                                    case 200:
                                        let decoder = JSONDecoder()
                                        decoder.dateDecodingStrategy = .iso8601
                                        let notifications = try decoder.decode([GitHubNotification].self, from: data)

                                        // Check for next page
                                        let linkHeader = httpResponse.value(forHTTPHeaderField: "Link")
                                        let hasMorePages = parseNextPageURL(from: linkHeader) != nil

                                        // Yield this page immediately
                                        continuation.yield(NotificationPageResult(
                                            notifications: notifications,
                                            lastModified: currentLastModified,
                                            pollInterval: pollInterval,
                                            hasMorePages: hasMorePages,
                                            isFirstPage: isFirstPage,
                                            rateLimit: rateLimit
                                        ))

                                        isFirstPage = false

                                        if let nextURL = parseNextPageURL(from: linkHeader) {
                                            currentURL = nextURL
                                        } else {
                                            // No more pages - finish successfully
                                            continuation.finish()
                                            return
                                        }

                                    case 304:
                                        // Not modified - yield empty result and finish
                                        continuation.yield(NotificationPageResult(
                                            notifications: [],
                                            lastModified: currentLastModified ?? lastModified,
                                            pollInterval: pollInterval,
                                            hasMorePages: false,
                                            isFirstPage: true,
                                            rateLimit: rateLimit
                                        ))
                                        continuation.finish()
                                        return

                                    case 401:
                                        continuation.finish(throwing: GitHubAPIError.unauthorized)
                                        return

                                    case 403:
                                        let resetHeader = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                                        let resetDate = resetHeader
                                            .flatMap { TimeInterval($0) }
                                            .map { Date(timeIntervalSince1970: $0) }
                                        continuation.finish(throwing: GitHubAPIError.rateLimited(resetAt: resetDate))
                                        return

                                    default:
                                        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                                        continuation.finish(throwing: GitHubAPIError.serverError(httpResponse.statusCode, message))
                                        return
                                }
                            } catch {
                                continuation.finish(throwing: error)
                                return
                            }
                        }
                    }
                }
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

                guard (200...299).contains(httpResponse.statusCode) else {
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

                guard (200...299).contains(httpResponse.statusCode) else {
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

                guard (200...299).contains(httpResponse.statusCode) else {
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
