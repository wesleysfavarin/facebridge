import Testing
import Foundation
import CryptoKit
@testable import FaceBridgeCrypto
@testable import FaceBridgeCore

@Suite("SoftwareKeyManager")
struct SoftwareKeyManagerTests {
    private func makeTestStore() -> InMemoryStore {
        InMemoryStore()
    }

    @Test("generates key pair and returns valid P-256 public key")
    func generatesKeyPair() throws {
        let store = makeTestStore()
        let manager = SoftwareKeyManager(store: store)
        let publicKey = try manager.generateKeyPair(tag: "test-key")
        #expect(publicKey.count == 65)
        #expect(publicKey[0] == 0x04)
    }

    @Test("signs and verifies data")
    func signsAndVerifies() throws {
        let store = makeTestStore()
        let manager = SoftwareKeyManager(store: store)
        let publicKeyData = try manager.generateKeyPair(tag: "test-sign")
        let data = Data("Hello FaceBridge".utf8)
        let signature = try manager.sign(data: data, keyTag: "test-sign")

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: signature, data: data, publicKeyData: publicKeyData)
        #expect(valid)
    }

    @Test("verification fails for tampered data")
    func tamperedDataFails() throws {
        let store = makeTestStore()
        let manager = SoftwareKeyManager(store: store)
        let publicKeyData = try manager.generateKeyPair(tag: "tamper-test")
        let data = Data("Original".utf8)
        let signature = try manager.sign(data: data, keyTag: "tamper-test")

        let verifier = SignatureVerifier()
        let tampered = Data("Tampered".utf8)
        let valid = try verifier.verify(signature: signature, data: tampered, publicKeyData: publicKeyData)
        #expect(!valid)
    }

    @Test("verification fails for wrong key")
    func wrongKeyFails() throws {
        let store = makeTestStore()
        let manager = SoftwareKeyManager(store: store)
        _ = try manager.generateKeyPair(tag: "key-a")
        let keyB = try manager.generateKeyPair(tag: "key-b")

        let data = Data("test".utf8)
        let signature = try manager.sign(data: data, keyTag: "key-a")

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: signature, data: data, publicKeyData: keyB)
        #expect(!valid)
    }

    @Test("deletes key")
    func deletesKey() throws {
        let store = makeTestStore()
        let manager = SoftwareKeyManager(store: store)
        _ = try manager.generateKeyPair(tag: "delete-me")
        try manager.deleteKey(tag: "delete-me")
        #expect(throws: Error.self) {
            _ = try manager.sign(data: Data(), keyTag: "delete-me")
        }
    }
}

@Suite("SignatureVerifier")
struct SignatureVerifierTests {
    @Test("rejects invalid public key size")
    func rejectsInvalidKeySize() throws {
        let verifier = SignatureVerifier()
        #expect(throws: FaceBridgeError.self) {
            _ = try verifier.verify(signature: Data(), data: Data(), publicKeyData: Data(repeating: 0, count: 10))
        }
    }

    @Test("rejects corrupted public key data")
    func rejectsCorruptedKey() throws {
        let verifier = SignatureVerifier()
        var badKey = Data(count: 65)
        badKey[0] = 0x04
        #expect(throws: FaceBridgeError.self) {
            _ = try verifier.verify(signature: Data(repeating: 0, count: 64), data: Data("test".utf8), publicKeyData: badKey)
        }
    }
}

@Suite("ShortAuthenticationStringVerifier")
struct SASVerificationTests {
    @Test("computes 6-digit SAS")
    func computesSAS() {
        let verifier = ShortAuthenticationStringVerifier()
        let sas = verifier.computeSAS(
            initiatorPublicKey: Data(repeating: 0x01, count: 65),
            responderPublicKey: Data(repeating: 0x02, count: 65),
            pairingCode: "123456"
        )
        #expect(sas.count == 6)
        #expect(Int(sas) != nil)
    }

    @Test("SAS is deterministic")
    func sasIsDeterministic() {
        let verifier = ShortAuthenticationStringVerifier()
        let key1 = Data(repeating: 0xAA, count: 65)
        let key2 = Data(repeating: 0xBB, count: 65)
        let a = verifier.computeSAS(initiatorPublicKey: key1, responderPublicKey: key2, pairingCode: "111111")
        let b = verifier.computeSAS(initiatorPublicKey: key1, responderPublicKey: key2, pairingCode: "111111")
        #expect(a == b)
    }

    @Test("SAS differs with different keys")
    func sasDiffersWithDifferentKeys() {
        let verifier = ShortAuthenticationStringVerifier()
        let key1 = Data(repeating: 0xAA, count: 65)
        let key2 = Data(repeating: 0xBB, count: 65)
        let key3 = Data(repeating: 0xCC, count: 65)
        let a = verifier.computeSAS(initiatorPublicKey: key1, responderPublicKey: key2, pairingCode: "123456")
        let b = verifier.computeSAS(initiatorPublicKey: key1, responderPublicKey: key3, pairingCode: "123456")
        #expect(a != b)
    }

    @Test("verify matching SAS")
    func verifyMatch() {
        let verifier = ShortAuthenticationStringVerifier()
        #expect(verifier.verify(localSAS: "123456", remoteSAS: "123456"))
    }

    @Test("verify rejects mismatched SAS")
    func verifyMismatch() {
        let verifier = ShortAuthenticationStringVerifier()
        #expect(!verifier.verify(localSAS: "123456", remoteSAS: "654321"))
    }

    @Test("verify rejects wrong length")
    func verifyWrongLength() {
        let verifier = ShortAuthenticationStringVerifier()
        #expect(!verifier.verify(localSAS: "12345", remoteSAS: "123456"))
    }
}

@Suite("SessionKeyDerivation")
struct SessionKeyDerivationTests {
    @Test("derives consistent key from same inputs")
    func consistentDerivation() {
        let deriver = SessionKeyDerivation()
        let secret = Data(repeating: 0x42, count: 32)
        let salt = Data(repeating: 0x01, count: 16)
        let info = deriver.buildInfo(sessionId: UUID(), transportType: "ble", initiatorId: UUID(), responderId: UUID())
        let key1 = deriver.deriveKey(sharedSecret: secret, salt: salt, info: info)
        let key2 = deriver.deriveKey(sharedSecret: secret, salt: salt, info: info)
        #expect(key1 == key2)
    }

    @Test("different secrets produce different keys")
    func differentSecrets() {
        let deriver = SessionKeyDerivation()
        let salt = Data(repeating: 0x01, count: 16)
        let info = Data("test-info".utf8)
        let key1 = deriver.deriveKey(sharedSecret: Data(repeating: 0x01, count: 32), salt: salt, info: info)
        let key2 = deriver.deriveKey(sharedSecret: Data(repeating: 0x02, count: 32), salt: salt, info: info)
        #expect(key1 != key2)
    }
}

@Suite("HashUtilities")
struct HashUtilitiesTests {
    @Test("SHA256 produces consistent hash")
    func sha256Consistent() {
        let utils = HashUtilities()
        let data = Data("hello".utf8)
        let a = utils.sha256(data)
        let b = utils.sha256(data)
        #expect(a == b)
    }

    @Test("SHA256 produces 32 bytes")
    func sha256Size() {
        let utils = HashUtilities()
        let hash = utils.sha256(Data("test".utf8))
        #expect(hash.count == 32)
    }
}

@Suite("Key Format Consistency")
struct KeyFormatConsistencyTests {
    @Test("software key produces valid P-256 X9.63 public key format")
    func softwareKeyFormat() throws {
        let store = InMemoryStore()
        let manager = SoftwareKeyManager(store: store)
        let pubKey = try manager.generateKeyPair(tag: "format-test")
        #expect(pubKey.count == DeviceIdentity.expectedP256PublicKeySize)
        #expect(pubKey[0] == DeviceIdentity.uncompressedPointPrefix)
    }

    @Test("software key signs, SignatureVerifier validates")
    func crossComponentVerification() throws {
        let store = InMemoryStore()
        let keyManager = SoftwareKeyManager(store: store)
        let pubKey = try keyManager.generateKeyPair(tag: "cross-verify")
        let data = Data("cross-component test".utf8)
        let sig = try keyManager.sign(data: data, keyTag: "cross-verify")

        let verifier = SignatureVerifier()
        let result = try verifier.verify(signature: sig, data: data, publicKeyData: pubKey)
        #expect(result)
    }

    @Test("public key export/import roundtrip via DeviceIdentity")
    func publicKeyRoundtrip() throws {
        let store = InMemoryStore()
        let manager = SoftwareKeyManager(store: store)
        let pubKey = try manager.generateKeyPair(tag: "roundtrip")

        let identity = try DeviceIdentity(displayName: "Test", platform: .macOS, publicKeyData: pubKey)
        let encoded = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(DeviceIdentity.self, from: encoded)
        #expect(decoded.publicKeyData == pubKey)
        #expect(decoded.publicKeyData.count == 65)
        #expect(decoded.publicKeyData[0] == 0x04)
    }

    @Test("incompatible key format rejected by SignatureVerifier")
    func incompatibleFormatRejected() {
        let verifier = SignatureVerifier()
        let ed25519Key = Data(repeating: 0xFF, count: 32)
        #expect(throws: FaceBridgeError.self) {
            _ = try verifier.verify(signature: Data(repeating: 0, count: 64), data: Data("test".utf8), publicKeyData: ed25519Key)
        }
    }
}

final class InMemoryStore: SecureStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func save(data: Data, for key: String) throws {
        storage[key] = data
    }

    func load(for key: String) throws -> Data? {
        storage[key]
    }

    func delete(for key: String) throws {
        storage.removeValue(forKey: key)
    }
}
