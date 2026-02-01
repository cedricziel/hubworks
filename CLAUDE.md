# HubWorks Project Guidelines

## Project Overview
HubWorks is a cross-platform GitHub notification app for iOS, macOS, and watchOS. It uses on-device polling (no backend) with SwiftData for persistence and TCA (Composable Architecture) for state management.

We use git worktrees to manage multiple parallel agents in the same repository. Ask the repository maintainer whether to initialize a worktree from main for your changes. Worktrees live in .claude/worktrees/. After the work is complete and the maintainer confirms, remove the worktree.

## Build System
- **XcodeGen** for project generation - run `make generate` after modifying `project.yml`
- **Swift 6.2** with complete strict concurrency checking
- **Deployment targets**: iOS 26.0, macOS 26.0, watchOS 26.0
- **iOS builds**: use iphone 17 simulator

## Key Commands
```bash
make generate    # Generate Xcode project
make build-ios   # Build iOS target
make build-macos # Build macOS target
make test        # Run tests
make lint        # Run SwiftLint
make format      # Run SwiftFormat
```

## Archiving & Releases
```bash
make archive-ios    # Archive iOS app (auto-increments build number)
make archive-macos  # Archive macOS app (auto-increments build number)
```

### Release Automation
The project uses **release-please** for automated version management:

- **Semantic commits** automatically trigger version bumps:
  - `feat:` → minor version bump (0.1.0 → 0.2.0)
  - `fix:` → patch version bump (0.1.0 → 0.1.1)
  - `feat!:` or `BREAKING CHANGE:` → major version bump (0.1.0 → 1.0.0)

- **Release workflow**:
  1. Push semantic commits to `main` branch
  2. Release-please creates/updates a release PR
  3. PR updates `project.yml` versions and CHANGELOG.md
  4. Merge the release PR
  5. GitHub release is created with macOS DMG attached

- **Custom token (optional)**: Set `RELEASE_PLEASE_TOKEN` secret in repository to allow release PRs to trigger other workflows

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
