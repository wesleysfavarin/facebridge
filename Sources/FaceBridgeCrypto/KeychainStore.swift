import Foundation
import Security
import FaceBridgeCore

public protocol SecureStorage: Sendable {
    func save(data: Data, for key: String) throws
    func load(for key: String) throws -> Data?
    func delete(for key: String) throws
}

public struct KeychainStore: SecureStorage, Sendable {
    private let service: String

    public init(service: String = "com.facebridge") {
        self.service = service
    }

    public func save(data: Data, for key: String) throws {
        try? delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw FaceBridgeError.keychainError(status: status)
        }
    }

    public func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw FaceBridgeError.keychainError(status: status)
        }
    }

    public func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FaceBridgeError.keychainError(status: status)
        }
    }
}
