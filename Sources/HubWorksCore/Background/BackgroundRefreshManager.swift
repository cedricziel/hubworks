import ComposableArchitecture
import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

public enum BackgroundRefreshIdentifier {
    public static let refresh = "com.cedricziel.hubworks.refresh"
}

@DependencyClient
public struct BackgroundRefreshManager: Sendable {
    public var scheduleRefresh: @Sendable () throws -> Void
    public var cancelRefresh: @Sendable () -> Void
    public var registerHandler: @Sendable (@escaping @Sendable () async -> Bool) -> Void
}

extension BackgroundRefreshManager: DependencyKey {
    public static let liveValue: BackgroundRefreshManager = {
        #if os(iOS)
        return BackgroundRefreshManager(
            scheduleRefresh: {
                let request = BGAppRefreshTaskRequest(identifier: BackgroundRefreshIdentifier.refresh)
                request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
                try BGTaskScheduler.shared.submit(request)
            },

            cancelRefresh: {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundRefreshIdentifier.refresh)
            },

            registerHandler: { handler in
                BGTaskScheduler.shared.register(
                    forTaskWithIdentifier: BackgroundRefreshIdentifier.refresh,
                    using: nil
                ) { task in
                    guard let refreshTask = task as? BGAppRefreshTask else {
                        task.setTaskCompleted(success: false)
                        return
                    }

                    // Capture handler in a local constant for Sendable compliance
                    let backgroundHandler = handler
                    let taskRunner = Task { @Sendable in
                        let success = await backgroundHandler()
                        refreshTask.setTaskCompleted(success: success)
                    }

                    refreshTask.expirationHandler = {
                        taskRunner.cancel()
                    }

                    try? BGTaskScheduler.shared.submit(
                        BGAppRefreshTaskRequest(identifier: BackgroundRefreshIdentifier.refresh)
                    )
                }
            }
        )
        #else
        return BackgroundRefreshManager(
            scheduleRefresh: {},
            cancelRefresh: {},
            registerHandler: { _ in }
        )
        #endif
    }()

    public static let testValue = BackgroundRefreshManager()
}

extension DependencyValues {
    public var backgroundRefreshManager: BackgroundRefreshManager {
        get { self[BackgroundRefreshManager.self] }
        set { self[BackgroundRefreshManager.self] = newValue }
    }
}
