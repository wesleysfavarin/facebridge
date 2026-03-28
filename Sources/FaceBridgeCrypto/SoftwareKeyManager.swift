import Foundation
import CryptoKit
import FaceBridgeCore

/// Fallback key manager for environments without Secure Enclave (e.g. simulator, testing).
public struct SoftwareKeyManager: KeyManaging, Sendable {
    private let store: SecureStorage

    public init(store: SecureStorage = KeychainStore(service: "com.facebridge.software-keys")) {
        self.store = store
    }

    public func generateKeyPair(tag: String) throws -> Data {
        let privateKey = P256.Signing.PrivateKey()
        let privateKeyData = privateKey.rawRepresentation

        try store.save(data: privateKeyData, for: tag)

        return privateKey.publicKey.x963Representation
    }

    public func sign(data: Data, keyTag: String) throws -> Data {
        guard let keyData = try store.load(for: keyTag) else {
            throw FaceBridgeError.keychainError(status: errSecItemNotFound)
        }

        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        let signature = try privateKey.signature(for: data)
        return signature.derRepresentation
    }

    public func publicKeyData(for tag: String) throws -> Data {
        guard let keyData = try store.load(for: tag) else {
            throw FaceBridgeError.keychainError(status: errSecItemNotFound)
        }

        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        return privateKey.publicKey.x963Representation
    }

    public func deleteKey(tag: String) throws {
        try store.delete(for: tag)
    }
}
