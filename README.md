# HubWorks

A cross-device (iOS, macOS, watchOS) app for managing GitHub notifications with **scopes** that map to Apple Focus modes, multi-account support, and intelligent filtering.

## Features

- **Multi-account support** - Manage work, personal, and OSS GitHub accounts
- **Smart filtering** - Filter notifications by reason, repository, or scope
- **Scopes with Focus integration** - Link notification groups to Apple Focus modes
- **Quiet hours** - Define when you don't want to be disturbed
- **Quick actions** - Mark as read, snooze, or archive without opening GitHub
- **Cross-device sync** - iCloud Keychain for tokens, CloudKit for preferences

## Architecture

HubWorks is built with:

- **SwiftUI** - Native UI across all platforms
- **SwiftData** - Local persistence with CloudKit sync
- **Composable Architecture (TCA)** - Predictable state management
- **On-device polling** - No backend required, full privacy

```
HubWorks/
├── Sources/
│   ├── HubWorksCore/        # Models, Services, API Client
│   ├── HubWorksFeatures/    # TCA Features (App, Inbox, Settings, Auth)
│   └── HubWorksUI/          # Shared SwiftUI components
├── Apps/
│   ├── HubWorks-iOS/        # iOS app target
│   ├── HubWorks-macOS/      # macOS menu bar app
│   └── HubWorks-watchOS/    # watchOS app
└── Tests/
```

## Requirements

- Xcode 16.0+
- iOS 26.0+ / macOS 26.0+ / watchOS 26.0+
- Swift 6.0+
- XcodeGen

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/hubworks.git
   cd hubworks
   ```

2. Generate the Xcode project:
   ```bash
   make generate
   ```

3. Open the project:
   ```bash
   make open
   ```

4. Configure your GitHub OAuth app:
   - Create a new OAuth App at https://github.com/settings/developers
   - Set the callback URL to `hubworks://oauth/callback`
   - Update the client ID in `Sources/HubWorksCore/Services/OAuthService.swift`

## Development

```bash
# Generate Xcode project
make generate

# Build iOS
make build-ios

# Build macOS
make build-macos

# Run tests
make test

# Lint code
make lint

# Format code
make format
```

## How It Works

### On-Device Polling

Since GitHub doesn't offer real-time notification subscriptions, HubWorks polls the GitHub API:

| Platform | Mechanism | Frequency |
|----------|-----------|-----------|
| **iOS** | BGAppRefreshTask | 15min - hours (iOS-managed) |
| **iOS** | Foreground polling | Every 60s when app is open |
| **macOS** | Menu bar app | Every 60s (always running) |
| **watchOS** | Complication refresh | System-managed |

### Local Notifications

When new notifications are detected during background refresh, HubWorks schedules local notifications to alert you.

### Sync Strategy

| Data | Storage | Syncs? |
|------|---------|--------|
| OAuth tokens | iCloud Keychain | Yes |
| Account metadata | CloudKit | Yes |
| Scopes & rules | CloudKit | Yes |
| Read/archive state | CloudKit | Yes |
| Notification cache | Local SwiftData | No |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.
