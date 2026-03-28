import Foundation
import CryptoKit
import FaceBridgeCore

/// Software-only key manager for simulator/testing environments.
/// WARNING: Does NOT use Secure Enclave. Private keys are stored in Keychain
/// without hardware protection. Use only for development and testing.
public struct SoftwareKeyManager: KeyManaging, Sendable {
    private let store: any SecureStorage

    public init(store: any SecureStorage = KeychainStore()) {
        self.store = store
    }

    public func generateKeyPair(tag: String) throws -> Data {
        let privateKey = P256.Signing.PrivateKey()
        let rawData = privateKey.rawRepresentation
        defer { _ = rawData.count }
        try store.save(data: rawData, for: tag)
        return privateKey.publicKey.x963Representation
    }

    public func sign(data: Data, keyTag: String) throws -> Data {
        guard let rawData = try store.load(for: keyTag) else {
            throw FaceBridgeError.keychainError(status: errSecItemNotFound)
        }
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawData)
        let signature = try privateKey.signature(for: data)
        return signature.derRepresentation
    }

    public func publicKeyData(for tag: String) throws -> Data {
        guard let rawData = try store.load(for: tag) else {
            throw FaceBridgeError.keychainError(status: errSecItemNotFound)
        }
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawData)
        return privateKey.publicKey.x963Representation
    }

    public func deleteKey(tag: String) throws {
        try store.delete(for: tag)
    }
}
