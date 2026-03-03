import ComposableArchitecture
import Foundation
import Testing
@testable import HubWorksCore

/// Thread-safe storage actor for test isolation
private actor TestStorage {
    private var value: String?

    func get() -> String? {
        value
    }

    func set(_ newValue: String?) {
        value = newValue
    }

    func clear() {
        value = nil
    }
}

@Suite("FocusFilterService Tests")
struct FocusFilterServiceTests {
    @Test("Service with nil storage returns nil")
    func getActiveScopeReturnsNil() async {
        // Given: A service with no stored value
        let storage = TestStorage()
        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { await storage.set($0) },
            clearActiveScope: { await storage.clear() }
        )

        // When: Getting active scope
        let result = await service.getActiveScope()

        // Then: Should return nil
        #expect(result == nil)
    }

    @Test("Service returns stored scope ID")
    func getActiveScopeReturnsStoredValue() async {
        // Given: A service with a stored value
        let storage = TestStorage()
        let expectedScopeId = "work-scope-123"
        await storage.set(expectedScopeId)

        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { await storage.set($0) },
            clearActiveScope: { await storage.clear() }
        )

        // When: Getting active scope
        let result = await service.getActiveScope()

        // Then: Should return the stored scope ID
        #expect(result == expectedScopeId)
    }

    @Test("setActiveScope stores value and posts notification")
    func setActiveScopeStoresAndNotifies() async {
        // Given: Storage and notification tracking
        let storage = TestStorage()
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .activeFocusScopeChanged,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }

        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { scopeId in
                await storage.set(scopeId)
                NotificationCenter.default.post(name: .activeFocusScopeChanged, object: nil)
            },
            clearActiveScope: { await storage.clear() }
        )

        // When: Setting a scope ID
        let scopeId = "personal-scope-456"
        await service.setActiveScope(scopeId)

        // Then: Should store value and post notification
        let storedValue = await storage.get()
        #expect(storedValue == scopeId)
        #expect(notificationReceived == true)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    @Test("setActiveScope with nil clears value")
    func setActiveScopeWithNilClearsValue() async {
        // Given: Storage with existing value
        let storage = TestStorage()
        await storage.set("existing-scope")

        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { scopeId in
                await storage.set(scopeId)
                NotificationCenter.default.post(name: .activeFocusScopeChanged, object: nil)
            },
            clearActiveScope: { await storage.clear() }
        )

        // When: Setting scope to nil
        await service.setActiveScope(nil)

        // Then: Should clear the stored value
        let storedValue = await storage.get()
        #expect(storedValue == nil)
    }

    @Test("clearActiveScope removes value and posts notification")
    func clearActiveScopeClearsAndNotifies() async {
        // Given: Storage with value and notification tracking
        let storage = TestStorage()
        await storage.set("some-scope")

        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .activeFocusScopeChanged,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }

        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { await storage.set($0) },
            clearActiveScope: {
                await storage.clear()
                NotificationCenter.default.post(name: .activeFocusScopeChanged, object: nil)
            }
        )

        // When: Clearing active scope
        await service.clearActiveScope()

        // Then: Should clear value and post notification
        let storedValue = await storage.get()
        #expect(storedValue == nil)
        #expect(notificationReceived == true)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    @Test("Multiple set operations maintain latest value")
    func multipleSetOperationsWork() async {
        // Given: Storage for testing multiple operations
        let storage = TestStorage()
        let service = FocusFilterService(
            getActiveScope: { await storage.get() },
            setActiveScope: { await storage.set($0) },
            clearActiveScope: { await storage.clear() }
        )

        // When: Setting multiple values
        await service.setActiveScope("scope-1")
        let value1 = await service.getActiveScope()

        await service.setActiveScope("scope-2")
        let value2 = await service.getActiveScope()

        await service.setActiveScope(nil)
        let value3 = await service.getActiveScope()

        // Then: Each operation should be reflected correctly
        #expect(value1 == "scope-1")
        #expect(value2 == "scope-2")
        #expect(value3 == nil)
    }

    @Test("testValue returns nil for getActiveScope")
    func valueReturnsNil() async {
        // Given: Test value service
        let service = FocusFilterService.testValue

        // When: Getting active scope
        let result = await service.getActiveScope()

        // Then: Should return nil
        #expect(result == nil)
    }

    @Test("testValue closures are no-ops")
    func valueClosuresAreNoOps() async {
        // Given: Test value service
        let service = FocusFilterService.testValue

        // When: Calling setActiveScope and clearActiveScope
        await service.setActiveScope("test")
        await service.clearActiveScope()

        // Then: No errors should occur (they're no-ops)
        #expect(true)
    }

    @Test("liveValue integration with actual UserDefaults")
    func liveValueIntegration() async {
        // Given: Live service with clean UserDefaults
        let testKey = "active_focus_scope_id"
        UserDefaults.standard.removeObject(forKey: testKey)

        let service = FocusFilterService.liveValue

        // When: Setting and getting a scope
        await service.setActiveScope("integration-test-scope")
        let result1 = await service.getActiveScope()

        // Then: Should persist to UserDefaults
        #expect(result1 == "integration-test-scope")
        #expect(UserDefaults.standard.string(forKey: testKey) == "integration-test-scope")

        // When: Clearing the scope
        await service.clearActiveScope()
        let result2 = await service.getActiveScope()

        // Then: Should be removed from UserDefaults
        #expect(result2 == nil)
        #expect(UserDefaults.standard.string(forKey: testKey) == nil)
    }
}
