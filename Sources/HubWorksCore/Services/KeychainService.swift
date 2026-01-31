import ComposableArchitecture
import Foundation
import Security

public struct KeychainError: Error, Equatable, Sendable, LocalizedError {
    public let status: OSStatus
    public let message: String

    public init(status: OSStatus, message: String = "") {
        self.status = status
        self.message = message.isEmpty ? Self.message(for: status) : message
    }

    public var errorDescription: String? {
        message
    }

    private static func message(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        case errSecParam:
            return "Invalid parameter"
        case errSecMissingEntitlement:
            return "Missing entitlement for keychain access"
        default:
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error (OSStatus: \(status))"
        }
    }
}

@DependencyClient
public struct KeychainService: Sendable {
    public var save: @Sendable (_ key: String, _ data: Data, _ synchronizable: Bool) throws -> Void
    public var load: @Sendable (_ key: String) throws -> Data?
    public var delete: @Sendable (_ key: String) throws -> Void
    public var exists: @Sendable (_ key: String) -> Bool = { _ in false }

    public func saveToken(_ token: String, forKey key: String, synchronizable: Bool = true) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError(status: errSecParam, message: "Failed to encode token")
        }
        try save(key, data, synchronizable)
    }

    public func loadToken(forKey key: String) throws -> String? {
        guard let data = try load(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension KeychainService: DependencyKey {
    public static let liveValue: KeychainService = {
        // Use the app's bundle ID as the service identifier
        let service = Bundle.main.bundleIdentifier ?? "com.cedricziel.hubworks"

        @Sendable
        func baseQuery(for key: String) -> [CFString: Any] {
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
            ]
        }

        return KeychainService(
            save: { key, data, synchronizable in
                // First, try to delete any existing item to avoid conflicts
                let deleteQuery = baseQuery(for: key)
                SecItemDelete(deleteQuery as CFDictionary)

                var query = baseQuery(for: key)
                query[kSecValueData] = data
                // Use kSecAttrAccessibleWhenUnlocked for better compatibility
                query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked

                // Only enable sync if explicitly requested and iCloud is available
                // For now, disable sync to avoid iCloud Keychain issues
                // query[kSecAttrSynchronizable] = synchronizable ? kCFBooleanTrue : kCFBooleanFalse

                let status = SecItemAdd(query as CFDictionary, nil)

                guard status == errSecSuccess else {
                    throw KeychainError(status: status)
                }
            },

            load: { key in
                var query = baseQuery(for: key)
                query[kSecReturnData] = true
                query[kSecMatchLimit] = kSecMatchLimitOne

                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                switch status {
                case errSecSuccess:
                    return result as? Data
                case errSecItemNotFound:
                    return nil
                default:
                    throw KeychainError(status: status)
                }
            },

            delete: { key in
                let query = baseQuery(for: key)
                let status = SecItemDelete(query as CFDictionary)

                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw KeychainError(status: status)
                }
            },

            exists: { key in
                var query = baseQuery(for: key)
                query[kSecReturnData] = false

                let status = SecItemCopyMatching(query as CFDictionary, nil)
                return status == errSecSuccess
            }
        )
    }()

    public static let testValue = KeychainService()
}

extension DependencyValues {
    public var keychainService: KeychainService {
        get { self[KeychainService.self] }
        set { self[KeychainService.self] = newValue }
    }
}
