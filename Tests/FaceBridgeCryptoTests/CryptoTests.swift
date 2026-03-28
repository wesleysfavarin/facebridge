import Testing
import Foundation
import CryptoKit
@testable import FaceBridgeCrypto
@testable import FaceBridgeCore

@Suite("SoftwareKeyManager")
struct SoftwareKeyManagerTests {
    @Test("generate and sign round-trip")
    func generateAndSign() throws {
        let store = InMemoryStore()
        let manager = SoftwareKeyManager(store: store)
        let tag = "test-key-\(UUID().uuidString)"

        let publicKeyData = try manager.generateKeyPair(tag: tag)
        #expect(!publicKeyData.isEmpty)

        let data = Data("test payload".utf8)
        let signature = try manager.sign(data: data, keyTag: tag)
        #expect(!signature.isEmpty)

        try manager.deleteKey(tag: tag)
    }

    @Test("signature verifies with correct key")
    func signatureVerifies() throws {
        let store = InMemoryStore()
        let manager = SoftwareKeyManager(store: store)
        let verifier = SignatureVerifier()
        let tag = "test-verify-\(UUID().uuidString)"

        let publicKeyData = try manager.generateKeyPair(tag: tag)
        let data = Data("verify this".utf8)
        let signature = try manager.sign(data: data, keyTag: tag)

        let valid = try verifier.verify(signature: signature, data: data, publicKeyData: publicKeyData)
        #expect(valid)

        try manager.deleteKey(tag: tag)
    }

    @Test("signature fails with wrong data")
    func signatureFailsWrongData() throws {
        let store = InMemoryStore()
        let manager = SoftwareKeyManager(store: store)
        let verifier = SignatureVerifier()
        let tag = "test-wrong-\(UUID().uuidString)"

        let publicKeyData = try manager.generateKeyPair(tag: tag)
        let data = Data("original".utf8)
        let signature = try manager.sign(data: data, keyTag: tag)

        let tampered = Data("tampered".utf8)
        let valid = try verifier.verify(signature: signature, data: tampered, publicKeyData: publicKeyData)
        #expect(!valid)

        try manager.deleteKey(tag: tag)
    }
}

@Suite("HashUtilities")
struct HashUtilitiesTests {
    @Test("SHA256 produces 32-byte hash")
    func sha256Length() {
        let hash = HashUtilities().sha256("hello")
        #expect(hash.count == 32)
    }

    @Test("SHA256 is deterministic")
    func sha256Deterministic() {
        let h = HashUtilities()
        let a = h.sha256("test")
        let b = h.sha256("test")
        #expect(a == b)
    }

    @Test("SHA256 differs for different inputs")
    func sha256Differs() {
        let h = HashUtilities()
        let a = h.sha256("one")
        let b = h.sha256("two")
        #expect(a != b)
    }
}

final class InMemoryStore: SecureStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func save(data: Data, for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    func load(for key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func delete(for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
