import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import ComposableArchitecture

public struct URLOpenerService: Sendable {
    public var open: @Sendable (URL) async -> Bool
}

extension URLOpenerService: DependencyKey {
    public static let liveValue = URLOpenerService { @MainActor url in
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #elseif os(iOS)
        return await UIApplication.shared.open(url)
        #else
        return false
        #endif
    }

    public static let testValue = URLOpenerService { _ in
        true
    }
}

extension DependencyValues {
    public var urlOpener: URLOpenerService {
        get { self[URLOpenerService.self] }
        set { self[URLOpenerService.self] = newValue }
    }
}
