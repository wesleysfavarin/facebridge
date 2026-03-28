import Testing
import Foundation
import CryptoKit
@testable import FaceBridgeProtocol
@testable import FaceBridgeCore

@Suite("AuthorizationRequest")
struct AuthorizationRequestTests {
    @Test("signable payload is deterministic")
    func signableIsDeterministic() {
        let id = UUID()
        let senderId = UUID()
        let nonce = Data(repeating: 0xAA, count: 32)
        let challenge = Data(repeating: 0xBB, count: 32)
        let date = Date(timeIntervalSince1970: 1700000000)

        let a = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "ble", createdAt: date)
        let b = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "ble", createdAt: date)
        #expect(a.signable == b.signable)
    }

    @Test("signable changes with different nonce")
    func signableChangesWithNonce() {
        let id = UUID()
        let senderId = UUID()
        let date = Date()
        let a = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: Data(repeating: 0x01, count: 32), challenge: Data(repeating: 0, count: 32), reason: "test", createdAt: date)
        let b = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: Data(repeating: 0x02, count: 32), challenge: Data(repeating: 0, count: 32), reason: "test", createdAt: date)
        #expect(a.signable != b.signable)
    }

    @Test("signable changes with different transportType")
    func signableChangesWithTransport() {
        let id = UUID()
        let senderId = UUID()
        let nonce = Data(repeating: 0xAA, count: 32)
        let challenge = Data(repeating: 0xBB, count: 32)
        let date = Date()
        let a = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "ble", createdAt: date)
        let b = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "test", transportType: "lan", createdAt: date)
        #expect(a.signable != b.signable)
    }

    @Test("signable uses length-prefixed fields")
    func signableUsesLengthPrefix() {
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "test"
        )
        let data = request.signable
        #expect(data.count > 0)
        let firstFieldLength = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        #expect(firstFieldLength == 36) // UUID string length
    }

    @Test("request expiry works")
    func requestExpiry() {
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "test",
            createdAt: Date().addingTimeInterval(-60),
            ttl: 1
        )
        #expect(request.isExpired)
    }

    @Test("signable changes with different reason prevents ambiguity")
    func signableFieldBoundaries() {
        let id = UUID()
        let senderId = UUID()
        let nonce = Data(repeating: 0, count: 32)
        let challenge = Data(repeating: 0, count: 32)
        let date = Date()
        let a = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "AB", transportType: "CD", createdAt: date)
        let b = AuthorizationRequest(id: id, senderDeviceId: senderId, nonce: nonce, challenge: challenge, reason: "ABC", transportType: "D", createdAt: date)
        #expect(a.signable != b.signable)
    }
}

@Suite("AuthorizationResponse")
struct AuthorizationResponseTests {
    @Test("response has mandatory signature and payload")
    func mandatoryFields() throws {
        let response = try AuthorizationResponse(
            requestId: UUID(),
            responderDeviceId: UUID(),
            decision: .denied,
            signature: Data(repeating: 0x01, count: 64),
            signedPayload: Data(repeating: 0x02, count: 100)
        )
        #expect(!response.signature.isEmpty)
        #expect(!response.signedPayload.isEmpty)
    }

    @Test("response rejects empty signature via Codable")
    func rejectsEmptySignature() {
        #expect(throws: (any Error).self) {
            try AuthorizationResponse(
                requestId: UUID(),
                responderDeviceId: UUID(),
                decision: .approved,
                signature: Data(),
                signedPayload: Data(repeating: 0x01, count: 50)
            )
        }
    }

    @Test("response rejects empty signedPayload")
    func rejectsEmptyPayload() {
        #expect(throws: (any Error).self) {
            try AuthorizationResponse(
                requestId: UUID(),
                responderDeviceId: UUID(),
                decision: .approved,
                signature: Data(repeating: 0x01, count: 64),
                signedPayload: Data()
            )
        }
    }
}

@Suite("SessionToken")
struct SessionTokenTests {
    @Test("token uses cryptographic random, not UUID")
    func tokenIsCryptoRandom() throws {
        let token = try SessionToken(sessionId: UUID())
        #expect(token.value.count > 36) // base64 of 32 bytes > UUID string length
    }

    @Test("tokens are unique")
    func tokensAreUnique() throws {
        let sessionId = UUID()
        let a = try SessionToken(sessionId: sessionId)
        let b = try SessionToken(sessionId: sessionId)
        #expect(a.value != b.value)
    }

    @Test("token expiry works")
    func tokenExpiry() throws {
        let token = try SessionToken(sessionId: UUID(), issuedAt: Date().addingTimeInterval(-60), ttl: 1)
        #expect(token.isExpired)
    }
}

@Suite("MessageEnvelope Authentication")
struct MessageEnvelopeTests {
    @Test("envelope MAC authentication roundtrip")
    func macRoundtrip() {
        let key = SymmetricKey(size: .bits256)
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 1,
            payload: Data("test payload".utf8)
        )
        let authenticated = envelope.authenticatedCopy(key: key)
        #expect(authenticated.mac != nil)
        #expect(authenticated.verifyMAC(key: key))
    }

    @Test("tampered payload fails MAC verification")
    func tamperedPayloadFails() {
        let key = SymmetricKey(size: .bits256)
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 1,
            payload: Data("original".utf8)
        )
        let authenticated = envelope.authenticatedCopy(key: key)

        let tampered = MessageEnvelope(
            id: authenticated.id,
            type: authenticated.type,
            version: authenticated.version,
            sequenceNumber: authenticated.sequenceNumber,
            payload: Data("tampered".utf8),
            timestamp: authenticated.timestamp,
            mac: authenticated.mac
        )
        #expect(!tampered.verifyMAC(key: key))
    }

    @Test("wrong key fails MAC verification")
    func wrongKeyFails() {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 1,
            payload: Data("test".utf8)
        )
        let authenticated = envelope.authenticatedCopy(key: key1)
        #expect(!authenticated.verifyMAC(key: key2))
    }

    @Test("reordered sequence number fails MAC")
    func reorderedSequenceFails() {
        let key = SymmetricKey(size: .bits256)
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 1,
            payload: Data("test".utf8)
        )
        let authenticated = envelope.authenticatedCopy(key: key)

        let reordered = MessageEnvelope(
            id: authenticated.id,
            type: authenticated.type,
            version: authenticated.version,
            sequenceNumber: 2,
            payload: authenticated.payload,
            timestamp: authenticated.timestamp,
            mac: authenticated.mac
        )
        #expect(!reordered.verifyMAC(key: key))
    }

    @Test("envelope without MAC fails verification")
    func noMacFails() {
        let key = SymmetricKey(size: .bits256)
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 1,
            payload: Data("test".utf8)
        )
        #expect(!envelope.verifyMAC(key: key))
    }

    @Test("encoder roundtrip")
    func encoderRoundtrip() throws {
        let encoder = MessageEncoder()
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test"
        )
        let envelope = try encoder.encode(request, type: .authorizationRequest, sequenceNumber: 42)
        let data = try encoder.encodeEnvelope(envelope)
        let decoded = try encoder.decodeEnvelope(from: data)
        #expect(decoded.type == .authorizationRequest)
        #expect(decoded.sequenceNumber == 42)
    }
}

@Suite("PairingMessage Signatures")
struct PairingMessageTests {
    @Test("invitation has signable representation")
    func invitationSignable() {
        let invitation = PairingInvitation(
            deviceId: UUID(),
            displayName: "Mac",
            platform: .macOS,
            publicKeyData: Data(repeating: 0x04, count: 65),
            pairingCode: "123456",
            signature: Data(repeating: 0x01, count: 64)
        )
        #expect(!invitation.signable.isEmpty)
    }

    @Test("acceptance has signable representation")
    func acceptanceSignable() {
        let acceptance = PairingAcceptance(
            deviceId: UUID(),
            displayName: "iPhone",
            platform: .iOS,
            publicKeyData: Data(repeating: 0x04, count: 65),
            invitationDeviceId: UUID(),
            signature: Data(repeating: 0x01, count: 64)
        )
        #expect(!acceptance.signable.isEmpty)
    }

    @Test("confirmation has SAS and signable")
    func confirmationSignable() {
        let confirmation = PairingConfirmation(
            deviceId: UUID(),
            peerDeviceId: UUID(),
            confirmed: true,
            sas: "123456",
            signature: Data(repeating: 0x01, count: 64)
        )
        #expect(!confirmation.signable.isEmpty)
        #expect(confirmation.sas == "123456")
    }
}
