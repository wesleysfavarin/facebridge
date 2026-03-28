import Testing
import Foundation
@testable import FaceBridgeMacAgent
@testable import FaceBridgeCore
@testable import FaceBridgeCrypto
@testable import FaceBridgeProtocol
@testable import FaceBridgeTransport

@Suite("SecureSessionHandler")
struct SecureSessionHandlerTests {
    @Test("creates session successfully")
    func createsSession() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())
        #expect(session.state == .pending)
    }

    @Test("retrieves session by ID")
    func retrievesSession() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())
        let found = await handler.session(for: session.id)
        #expect(found?.id == session.id)
    }

    @Test("validateAndConsume removes session atomically")
    func validateAndConsumeRemoves() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())

        let validated = await handler.validateAndConsume(session.id)
        #expect(validated != nil)

        let secondAttempt = await handler.validateAndConsume(session.id)
        #expect(secondAttempt == nil)
    }

    @Test("double consume returns nil")
    func doubleConsume() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())

        _ = try await handler.approveAndConsume(session.id)
        let second = try await handler.approveAndConsume(session.id)
        #expect(second == nil)
    }

    @Test("approveAndConsume removes from active sessions")
    func approveConsumes() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())

        let approved = try await handler.approveAndConsume(session.id)
        #expect(approved?.state == .approved)

        let count = await handler.activeSessionCount()
        #expect(count == 0)
    }

    @Test("denyAndConsume removes from active sessions")
    func denyConsumes() async throws {
        let handler = SecureSessionHandler()
        let session = try await handler.createSession(trustRelationshipId: UUID())

        let denied = try await handler.denyAndConsume(session.id)
        #expect(denied?.state == .denied)

        let count = await handler.activeSessionCount()
        #expect(count == 0)
    }

    @Test("prune expired removes expired sessions")
    func pruneExpired() async throws {
        let handler = SecureSessionHandler()
        _ = try await handler.createSession(trustRelationshipId: UUID(), ttl: 0)
        try await Task.sleep(for: .milliseconds(50))
        await handler.pruneExpired()
        let count = await handler.activeSessionCount()
        #expect(count == 0)
    }
}

@Suite("BackgroundListener Queue Protection")
struct BackgroundListenerTests {
    @Test("rejects expired requests")
    func rejectsExpired() async {
        let listener = BackgroundListener(connectionManager: ConnectionManager())
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "test",
            createdAt: Date().addingTimeInterval(-60),
            ttl: 1
        )
        let result = await listener.enqueue(request)
        if case .rejected(.sessionExpired) = result {
            // expected
        } else {
            Issue.record("Expected .rejected(.sessionExpired)")
        }
    }

    @Test("enforces queue size limit")
    func enforceQueueLimit() async {
        let listener = BackgroundListener(connectionManager: ConnectionManager(), maxQueueSize: 3)
        for i in 0..<3 {
            let request = AuthorizationRequest(
                senderDeviceId: UUID(),
                nonce: Data(repeating: UInt8(i), count: 32),
                challenge: Data(repeating: 0, count: 32),
                reason: "test"
            )
            let result = await listener.enqueue(request)
            if case .accepted = result {} else {
                Issue.record("Expected .accepted for request \(i)")
            }
        }

        let overflow = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xFF, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "overflow"
        )
        let result = await listener.enqueue(overflow)
        if case .rejected(.queueOverflow) = result {
            // expected
        } else {
            Issue.record("Expected .rejected(.queueOverflow)")
        }
    }

    @Test("enforces per-device rate limit")
    func enforceDeviceRateLimit() async {
        let listener = BackgroundListener(
            connectionManager: ConnectionManager(),
            maxRequestsPerDevice: 2,
            rateLimitWindow: 60
        )
        let deviceId = UUID()
        for i in 0..<2 {
            let request = AuthorizationRequest(
                senderDeviceId: deviceId,
                nonce: Data(repeating: UInt8(i), count: 32),
                challenge: Data(repeating: 0, count: 32),
                reason: "test"
            )
            _ = await listener.enqueue(request)
        }

        let thirdRequest = AuthorizationRequest(
            senderDeviceId: deviceId,
            nonce: Data(repeating: 0xFF, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "rate-limited"
        )
        let result = await listener.enqueue(thirdRequest)
        if case .rejected(.rateLimited) = result {
            // expected
        } else {
            Issue.record("Expected .rejected(.rateLimited)")
        }
    }

    @Test("prune expired removes old requests")
    func pruneExpiredRequests() async {
        let listener = BackgroundListener(connectionManager: ConnectionManager())
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0, count: 32),
            challenge: Data(repeating: 0, count: 32),
            reason: "will-expire",
            ttl: 0
        )
        _ = await listener.enqueue(request)
        try? await Task.sleep(for: .milliseconds(50))
        await listener.pruneExpired()
        let count = await listener.pendingRequestCount()
        #expect(count == 0)
    }
}

@Suite("PolicyEnforcer")
struct PolicyEnforcerTests {
    @Test("allows valid session with biometric")
    func allowsValid() async throws {
        let enforcer = PolicyEnforcer()
        let nonce = try NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce)
        let decision = await enforcer.enforce(session: session, biometricVerified: true)
        #expect(decision == .allowed)
    }

    @Test("denies expired session")
    func deniesExpired() async throws {
        let enforcer = PolicyEnforcer()
        let nonce = try NonceGenerator().generate()
        let session = Session(
            trustRelationshipId: UUID(),
            nonce: nonce,
            createdAt: Date().addingTimeInterval(-60),
            ttl: 1
        )
        let decision = await enforcer.enforce(session: session, biometricVerified: true)
        #expect(decision == .denied(reason: .sessionExpired))
    }

    @Test("denies without biometric when required")
    func deniesNoBiometric() async throws {
        let enforcer = PolicyEnforcer()
        let nonce = try NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce)
        let decision = await enforcer.enforce(session: session, biometricVerified: false)
        #expect(decision == .denied(reason: .biometricRequired))
    }
}

@Suite("BackgroundListener Recovery")
struct BackgroundListenerRecoveryTests {
    @Test("recoverIfStuck resets to listening after timeout")
    func recoverIfStuck() async {
        let listener = BackgroundListener(connectionManager: ConnectionManager())
        await listener.start()
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test",
            ttl: 300
        )
        _ = await listener.enqueue(request)
        let state1 = await listener.state
        #expect(state1 == .processing)

        await listener.recoverIfStuck()
        let state2 = await listener.state
        #expect(state2 == .processing)
    }

    @Test("dequeue returns request and resets state")
    func dequeueReturnsAndResets() async {
        let listener = BackgroundListener(connectionManager: ConnectionManager())
        await listener.start()
        let request = AuthorizationRequest(
            senderDeviceId: UUID(),
            nonce: Data(repeating: 0xAA, count: 32),
            challenge: Data(repeating: 0xBB, count: 32),
            reason: "test",
            ttl: 300
        )
        _ = await listener.enqueue(request)
        let dequeued = await listener.dequeue(request.id)
        #expect(dequeued?.id == request.id)
        let stateAfter = await listener.state
        #expect(stateAfter == .listening)
    }
}

@Suite("TrustedDeviceVerifier")
struct TrustedDeviceVerifierTests {
    @Test("verify returns false for unknown device")
    func verifyUnknown() async throws {
        let store = TestMacSecureStorage()
        let verifier = TrustedDeviceVerifier(keychainStore: store)
        let result = try await verifier.verify(deviceId: UUID())
        #expect(!result)
    }

    @Test("publicKey returns nil for unknown device")
    func publicKeyUnknown() async throws {
        let store = TestMacSecureStorage()
        let verifier = TrustedDeviceVerifier(keychainStore: store)
        let key = try await verifier.publicKey(for: UUID())
        #expect(key == nil)
    }
}

final class TestMacSecureStorage: SecureStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    func save(data: Data, for key: String) throws { storage[key] = data }
    func load(for key: String) throws -> Data? { storage[key] }
    func delete(for key: String) throws { storage.removeValue(forKey: key) }
}
