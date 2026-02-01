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
    public static let liveValue = URLOpenerService { url in
        #if os(macOS)
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        await MainActor.run {
            await UIApplication.shared.open(url)
        }
        #else
        false
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
