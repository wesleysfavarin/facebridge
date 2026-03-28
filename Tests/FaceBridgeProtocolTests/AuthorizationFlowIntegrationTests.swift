import Testing
import Foundation
import CryptoKit
@testable import FaceBridgeProtocol
@testable import FaceBridgeCrypto
@testable import FaceBridgeCore

final class TestSecureStorage: SecureStorage, @unchecked Sendable {
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

@Suite("Full Authorization Flow")
struct AuthorizationFlowIntegrationTests {
    @Test("sign and verify roundtrip succeeds")
    func signAndVerify() throws {
        let store = TestSecureStorage()
        let keyManager = SoftwareKeyManager(store: store)
        let publicKeyData = try keyManager.generateKeyPair(tag: "test-flow")

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "Approve file access",
            transportType: "ble"
        )

        let payload = request.signable
        let signature = try keyManager.sign(data: payload, keyTag: "test-flow")

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: signature, data: payload, publicKeyData: publicKeyData)
        #expect(valid)
    }

    @Test("tampered payload fails verification")
    func tamperedPayloadFails() throws {
        let store = TestSecureStorage()
        let keyManager = SoftwareKeyManager(store: store)
        let publicKeyData = try keyManager.generateKeyPair(tag: "tamper-flow")

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "Original reason"
        )

        let payload = request.signable
        let signature = try keyManager.sign(data: payload, keyTag: "tamper-flow")

        let tamperedRequest = AuthorizationRequest(
            id: request.id,
            senderDeviceId: request.senderDeviceId,
            nonce: request.nonce,
            challenge: request.challenge,
            reason: "Tampered reason",
            createdAt: request.createdAt
        )

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: signature, data: tamperedRequest.signable, publicKeyData: publicKeyData)
        #expect(!valid)
    }

    @Test("replay protection rejects duplicate nonces")
    func replayProtection() async throws {
        let protector = ReplayProtector()
        let nonce = try NonceGenerator().generate()

        let first = await protector.validate(nonce)
        let second = await protector.validate(nonce)

        #expect(first)
        #expect(!second)
    }

    @Test("cross-transport replay prevented by transportType in signable")
    func crossTransportReplay() {
        let id = UUID()
        let senderId = UUID()
        let nonce = Data(repeating: 0xAA, count: 32)
        let challenge = Data(repeating: 0xBB, count: 32)
        let date = Date()

        let bleRequest = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "ble", createdAt: date)
        let lanRequest = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "lan", createdAt: date)

        #expect(bleRequest.signable != lanRequest.signable)
    }

    @Test("full response with mandatory signatures")
    func fullResponseWithSignatures() throws {
        let store = TestSecureStorage()
        let keyManager = SoftwareKeyManager(store: store)
        let publicKeyData = try keyManager.generateKeyPair(tag: "resp-flow")

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test"
        )

        let payload = request.signable
        let signature = try keyManager.sign(data: payload, keyTag: "resp-flow")

        let response = try AuthorizationResponse(
            requestId: request.id,
            responderDeviceId: UUID(),
            decision: .approved,
            signature: signature,
            signedPayload: payload
        )

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: response.signature, data: response.signedPayload, publicKeyData: publicKeyData)
        #expect(valid)
    }

    @Test("denied response also has valid signature")
    func deniedResponseSigned() throws {
        let store = TestSecureStorage()
        let keyManager = SoftwareKeyManager(store: store)
        let publicKeyData = try keyManager.generateKeyPair(tag: "denied-flow")

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test"
        )

        let payload = request.signable
        let signature = try keyManager.sign(data: payload, keyTag: "denied-flow")

        let response = try AuthorizationResponse(
            requestId: request.id,
            responderDeviceId: UUID(),
            decision: .denied,
            signature: signature,
            signedPayload: payload
        )

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(signature: response.signature, data: response.signedPayload, publicKeyData: publicKeyData)
        #expect(valid)
    }

    @Test("requestId binding mismatch detectable")
    func requestIdBinding() throws {
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "test"
        )

        let response = try AuthorizationResponse(
            requestId: UUID(),
            responderDeviceId: UUID(),
            decision: .approved,
            signature: Data(repeating: 0x01, count: 64),
            signedPayload: request.signable
        )

        #expect(response.requestId != request.id)
    }

    @Test("future-dated nonce rejected by replay protector")
    func futureNonceRejected() async throws {
        let protector = ReplayProtector(clockSkewTolerance: 30)
        let futureDate = Date().addingTimeInterval(120)
        let nonce = try Nonce(value: Data(repeating: 0xAA, count: 32), createdAt: futureDate)
        let result = await protector.validate(nonce)
        #expect(!result)
    }

    @Test("AuthorizationResponse Codable rejects empty signature")
    func codableRejectsEmptySignature() {
        let json = """
        {"requestId":"\(UUID().uuidString)","version":"1.0","responderDeviceId":"\(UUID().uuidString)","decision":"approved","signature":"","signedPayload":"dGVzdA==","respondedAt":0}
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(AuthorizationResponse.self, from: Data(json.utf8))
        }
    }

    @Test("SessionToken Codable rejects short token")
    func sessionTokenCodableRejectsShort() {
        let json = """
        {"value":"abc","sessionId":"\(UUID().uuidString)","issuedAt":0,"expiresAt":999999999999}
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SessionToken.self, from: Data(json.utf8))
        }
    }

    @Test("DeviceIdentity Codable validates public key")
    func deviceIdentityCodableValidates() {
        let json = """
        {"id":"\(UUID().uuidString)","displayName":"test","platform":"iOS","publicKeyData":"AQID","createdAt":0}
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(DeviceIdentity.self, from: Data(json.utf8))
        }
    }

    @Test("Nonce Codable rejects zero-filled data")
    func nonceCodableRejectsZeros() {
        let zeroData = Data(count: 32).base64EncodedString()
        let json = """
        {"value":"\(zeroData)","createdAt":0}
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Nonce.self, from: Data(json.utf8))
        }
    }

    @Test("Nonce init rejects short data")
    func nonceRejectsShort() {
        #expect(throws: (any Error).self) {
            try Nonce(value: Data(repeating: 0x01, count: 4))
        }
    }

    @Test("Nonce init rejects all-zero data")
    func nonceRejectsAllZero() {
        #expect(throws: (any Error).self) {
            try Nonce(value: Data(count: 32))
        }
    }

    @Test("Mac request signing and verification roundtrip")
    func macRequestSigning() throws {
        let store = TestSecureStorage()
        let keyManager = SoftwareKeyManager(store: store)
        let pubKey = try keyManager.generateKeyPair(tag: "mac-sign")

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test"
        )

        let signature = try keyManager.sign(data: request.signable, keyTag: "mac-sign")
        let signedRequest = AuthorizationRequest(
            id: request.id,
            senderDeviceId: request.senderDeviceId,
            nonce: request.nonce,
            challenge: request.challenge,
            reason: request.reason,
            transportType: request.transportType,
            createdAt: request.createdAt,
            ttl: 30,
            senderSignature: signature
        )

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(
            signature: signedRequest.senderSignature!,
            data: signedRequest.signable,
            publicKeyData: pubKey
        )
        #expect(valid)
    }

    @Test("forged request from unknown device rejected")
    func forgedRequestRejected() throws {
        let store = TestSecureStorage()
        let legitimateKeyManager = SoftwareKeyManager(store: store)
        let legitimatePubKey = try legitimateKeyManager.generateKeyPair(tag: "legit")

        let attackerStore = TestSecureStorage()
        let attackerKeyManager = SoftwareKeyManager(store: attackerStore)
        _ = try attackerKeyManager.generateKeyPair(tag: "attacker")

        let forgedRequest = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "Evil request"
        )
        let attackerSig = try attackerKeyManager.sign(data: forgedRequest.signable, keyTag: "attacker")
        let signedForgedRequest = AuthorizationRequest(
            id: forgedRequest.id,
            senderDeviceId: forgedRequest.senderDeviceId,
            nonce: forgedRequest.nonce,
            challenge: forgedRequest.challenge,
            reason: forgedRequest.reason,
            createdAt: forgedRequest.createdAt,
            ttl: 30,
            senderSignature: attackerSig
        )

        let verifier = SignatureVerifier()
        let valid = try verifier.verify(
            signature: signedForgedRequest.senderSignature!,
            data: signedForgedRequest.signable,
            publicKeyData: legitimatePubKey
        )
        #expect(!valid)
    }
}
