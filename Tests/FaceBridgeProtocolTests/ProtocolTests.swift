import Testing
import Foundation
@testable import FaceBridgeProtocol
@testable import FaceBridgeCore

@Suite("MessageEnvelope")
struct MessageEnvelopeTests {
    @Test("encode and decode round-trip")
    func encodeDecode() throws {
        let encoder = MessageEncoder()

        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "Test authorization"
        )

        let envelope = try encoder.encode(request, type: .authorizationRequest)
        let data = try encoder.encodeEnvelope(envelope)
        let decoded = try encoder.decodeEnvelope(from: data)
        let decodedRequest = try encoder.decode(AuthorizationRequest.self, from: decoded)

        #expect(decodedRequest.id == request.id)
        #expect(decodedRequest.reason == request.reason)
        #expect(decodedRequest.nonce == request.nonce)
    }

    @Test("envelope preserves message type")
    func preservesType() throws {
        let encoder = MessageEncoder()
        let response = AuthorizationResponse(
            requestId: UUID(),
            responderDeviceId: UUID(),
            decision: .approved
        )

        let envelope = try encoder.encode(response, type: .authorizationResponse)
        #expect(envelope.type == .authorizationResponse)
    }
}

@Suite("AuthorizationRequest")
struct AuthorizationRequestTests {
    @Test("request expires")
    func requestExpires() {
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

    @Test("fresh request is not expired")
    func freshNotExpired() {
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "test"
        )
        #expect(!request.isExpired)
    }

    @Test("signable payload is deterministic")
    func signableIsDeterministic() {
        let id = UUID()
        let nonce = Data(repeating: 0xCC, count: 32)
        let challenge = Data(repeating: 0xDD, count: 32)
        let date = Date(timeIntervalSince1970: 1000)

        let a = AuthorizationRequest(
            id: id, senderDeviceId: UUID(), nonce: nonce,
            challenge: challenge, reason: "test", createdAt: date
        )
        let b = AuthorizationRequest(
            id: id, senderDeviceId: UUID(), nonce: nonce,
            challenge: challenge, reason: "test", createdAt: date
        )

        #expect(a.signable == b.signable)
    }
}

@Suite("PairingInvitation")
struct PairingInvitationTests {
    @Test("invitation expires")
    func invitationExpires() {
        let invitation = PairingInvitation(
            deviceId: UUID(),
            displayName: "MacBook",
            platform: .macOS,
            publicKeyData: Data(repeating: 0, count: 65),
            pairingCode: "123456",
            createdAt: Date().addingTimeInterval(-300),
            ttl: 1
        )
        #expect(invitation.isExpired)
    }
}

@Suite("ProtocolVersion")
struct ProtocolVersionTests {
    @Test("compatibility check")
    func compatibility() {
        let v1_0 = ProtocolVersion(major: 1, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        let v2_0 = ProtocolVersion(major: 2, minor: 0)

        #expect(v1_0.isCompatible(with: v1_1))
        #expect(!v1_0.isCompatible(with: v2_0))
    }

    @Test("ordering")
    func ordering() {
        let v1_0 = ProtocolVersion(major: 1, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        let v2_0 = ProtocolVersion(major: 2, minor: 0)

        #expect(v1_0 < v1_1)
        #expect(v1_1 < v2_0)
    }
}
