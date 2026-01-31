# HubWorks Project Guidelines

## Project Overview
HubWorks is a cross-platform GitHub notification app for iOS, macOS, and watchOS. It uses on-device polling (no backend) with SwiftData for persistence and TCA (Composable Architecture) for state management.

## Build System
- **XcodeGen** for project generation - run `make generate` after modifying `project.yml`
- **Swift 6.0** with complete strict concurrency checking
- **Deployment targets**: iOS 26.0, macOS 26.0, watchOS 26.0

## Key Commands
```bash
make generate    # Generate Xcode project
make build-ios   # Build iOS target
make build-macos # Build macOS target
make test        # Run tests
make lint        # Run SwiftLint
make format      # Run SwiftFormat
```

## Architecture

### Module Structure
- `HubWorksCore` - Models, Services, API Client (all platforms)
- `HubWorksFeatures` - TCA Features (iOS, macOS only)
- `HubWorksUI` - Shared SwiftUI components (all platforms)

### Patterns
- **TCA (Composable Architecture)** for state management
- **SwiftData** with CloudKit sync for persistence
- **Dependency injection** via TCA's `@Dependency` system
- **On-device polling** with `BGAppRefreshTask` (iOS) and Timer (macOS)

### Data Flow
1. `GitHubAPIClient` polls GitHub REST API
2. `NotificationPollingService` manages polling schedule
3. `LocalNotificationService` triggers local notifications for new items
4. TCA reducers process state changes

## Important Files
- `project.yml` - XcodeGen project configuration
- `Sources/HubWorksCore/Services/OAuthService.swift` - OAuth configuration (needs client ID)
- `Sources/HubWorksFeatures/App/AppFeature.swift` - Root TCA feature

## Code Style
- Follow SwiftLint and SwiftFormat configurations
- Use semantic commits
- Prefer `@Sendable` closures and actors for concurrency safety
- Use explicit access control (`public`, `private`, etc.)

## Testing
- Unit tests use Swift Testing framework
- TCA features should use `TestStore` for reducer testing
- Mock dependencies via `withDependencies` or `.testValue`

## Before Committing
1. Run `make lint` to check for issues
2. Run `make format` to format code
3. Run `make test` to verify tests pass
