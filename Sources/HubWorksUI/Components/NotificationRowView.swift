import HubWorksCore
import SwiftUI

public struct NotificationRowView: View {
    public let notification: NotificationRowState
    public let onTap: () -> Void
    public let onMarkAsRead: () -> Void
    public let onArchive: () -> Void
    public let onSnooze: (Date) -> Void

    public init(
        notification: NotificationRowState,
        onTap: @escaping () -> Void,
        onMarkAsRead: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onSnooze: @escaping (Date) -> Void
    ) {
        self.notification = notification
        self.onTap = onTap
        self.onMarkAsRead = onMarkAsRead
        self.onArchive = onArchive
        self.onSnooze = onSnooze
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leadingContent
                mainContent
                trailingContent
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Button {
                onMarkAsRead()
            } label: {
                Label("Read", systemImage: "checkmark")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onSnooze(Date.now.addingTimeInterval(3600))
            } label: {
                Label("Snooze", systemImage: "clock")
            }
            .tint(.orange)
        }
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var leadingContent: some View {
        ZStack {
            if let avatarURL = notification.repositoryAvatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: notification.subjectType.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }

            if notification.isUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                    .offset(x: 15, y: -15)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.body)
                .fontWeight(notification.isUnread ? .semibold : .regular)
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Image(systemName: notification.reason.systemImage)
                    .font(.caption2)
                Text(notification.reason.displayName)
                    .font(.caption)

                Text("•")
                    .font(.caption)

                Text(notification.repositoryFullName)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(notification.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: notification.subjectType.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if notification.isUnread {
            Button {
                onMarkAsRead()
            } label: {
                Label("Mark as Read", systemImage: "checkmark.circle")
            }
        }

        Menu("Snooze") {
            Button {
                onSnooze(Date.now.addingTimeInterval(3600))
            } label: {
                Label("1 Hour", systemImage: "clock")
            }

            Button {
                onSnooze(Date.now.addingTimeInterval(3600 * 3))
            } label: {
                Label("3 Hours", systemImage: "clock")
            }

            Button {
                onSnooze(Date.now.addingTimeInterval(86400))
            } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }

            Button {
                onSnooze(Date.now.addingTimeInterval(86400 * 7))
            } label: {
                Label("Next Week", systemImage: "calendar")
            }
        }

        Button {
            onArchive()
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Divider()

        if let webURL = notification.webURL {
            Link(destination: webURL) {
                Label("Open in GitHub", systemImage: "safari")
            }
        }

        Button {
            if let webURL = notification.webURL {
                #if os(iOS)
                UIPasteboard.general.url = webURL
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(webURL.absoluteString, forType: .string)
                #endif
            }
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }
    }
}

#Preview {
    List {
        NotificationRowView(
            notification: NotificationRowState(
                id: "1",
                threadId: "1",
                title: "Fix critical bug in authentication flow that causes crashes on iOS 17",
                repositoryFullName: "apple/swift",
                repositoryOwner: "apple",
                repositoryAvatarURL: URL(string: "https://avatars.githubusercontent.com/u/10639145"),
                subjectType: .pullRequest,
                reason: .reviewRequested,
                isUnread: true,
                updatedAt: .now.addingTimeInterval(-3600),
                webURL: URL(string: "https://github.com/apple/swift/pull/123")
            ),
            onTap: {},
            onMarkAsRead: {},
            onArchive: {},
            onSnooze: { _ in }
        )

        NotificationRowView(
            notification: NotificationRowState(
                id: "2",
                threadId: "2",
                title: "Add new feature for handling notifications",
                repositoryFullName: "pointfreeco/swift-composable-architecture",
                repositoryOwner: "pointfreeco",
                repositoryAvatarURL: nil,
                subjectType: .issue,
                reason: .mention,
                isUnread: false,
                updatedAt: .now.addingTimeInterval(-86400),
                webURL: URL(string: "https://github.com/pointfreeco/swift-composable-architecture/issues/456")
            ),
            onTap: {},
            onMarkAsRead: {},
            onArchive: {},
            onSnooze: { _ in }
        )
    }
}
