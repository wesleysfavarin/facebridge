import Testing
import Foundation
@testable import FaceBridgeCore

@Suite("NonceGenerator")
struct NonceTests {
    @Test("generates nonce with correct byte count")
    func generatesCorrectByteCount() throws {
        let generator = NonceGenerator(byteCount: 32)
        let nonce = try generator.generate()
        #expect(nonce.value.count == 32)
    }

    @Test("generates unique nonces")
    func generatesUniqueNonces() throws {
        let generator = NonceGenerator()
        let a = try generator.generate()
        let b = try generator.generate()
        #expect(a.value != b.value)
    }

    @Test("nonce has creation timestamp")
    func hasTimestamp() throws {
        let before = Date()
        let nonce = try NonceGenerator().generate()
        let after = Date()
        #expect(nonce.createdAt >= before)
        #expect(nonce.createdAt <= after)
    }

    @Test("minimum byte count enforced at 16")
    func minimumByteCount() throws {
        let generator = NonceGenerator(byteCount: 8)
        let nonce = try generator.generate()
        #expect(nonce.value.count == 16)
    }

    @Test("nonce is not all zeros")
    func notAllZeros() throws {
        let generator = NonceGenerator()
        for _ in 0..<100 {
            let nonce = try generator.generate()
            #expect(nonce.value.contains(where: { $0 != 0 }))
        }
    }

    @Test("generate() is throwing, not precondition")
    func generateIsThrowing() {
        let generator = NonceGenerator()
        #expect(throws: Never.self) {
            _ = try generator.generate()
        }
    }

    @Test("nonce entropy check - 1000 nonces all unique")
    func entropyCheck() throws {
        let generator = NonceGenerator()
        var seen = Set<Data>()
        for _ in 0..<1000 {
            let nonce = try generator.generate()
            #expect(!seen.contains(nonce.value))
            seen.insert(nonce.value)
        }
    }
}

@Suite("Nonce Init Validation")
struct NonceInitValidationTests {
    @Test("rejects nonce shorter than minimum")
    func rejectsShortNonce() {
        #expect(throws: FaceBridgeError.self) {
            try Nonce(value: Data(repeating: 0x01, count: 4))
        }
    }

    @Test("rejects all-zero nonce")
    func rejectsAllZero() {
        #expect(throws: FaceBridgeError.self) {
            try Nonce(value: Data(count: 32))
        }
    }

    @Test("accepts valid nonce via init")
    func acceptsValidNonce() throws {
        let nonce = try Nonce(value: Data(repeating: 0xAA, count: 32))
        #expect(nonce.value.count == 32)
    }

    @Test("Codable roundtrip preserves validation")
    func codableRoundtrip() throws {
        let valid = try Nonce(value: Data(repeating: 0xBB, count: 32))
        let encoded = try JSONEncoder().encode(valid)
        let decoded = try JSONDecoder().decode(Nonce.self, from: encoded)
        #expect(decoded.value == valid.value)
    }
}

@Suite("ReplayProtector")
struct ReplayProtectorTests {
    @Test("accepts fresh nonce")
    func acceptsFreshNonce() async throws {
        let protector = ReplayProtector()
        let nonce = try NonceGenerator().generate()
        let valid = await protector.validate(nonce)
        #expect(valid)
    }

    @Test("rejects duplicate nonce")
    func rejectsDuplicate() async throws {
        let protector = ReplayProtector()
        let nonce = try NonceGenerator().generate()
        _ = await protector.validate(nonce)
        let second = await protector.validate(nonce)
        #expect(!second)
    }

    @Test("rejects expired nonce")
    func rejectsExpired() async throws {
        let protector = ReplayProtector(windowDuration: 1)
        let expiredNonce = try Nonce(value: Data(repeating: 0xAB, count: 32), createdAt: Date().addingTimeInterval(-10))
        let valid = await protector.validate(expiredNonce)
        #expect(!valid)
    }

    @Test("rejects future-dated nonce beyond clock skew tolerance")
    func rejectsFutureNonce() async throws {
        let protector = ReplayProtector(clockSkewTolerance: 30)
        let futureNonce = try Nonce(value: Data(repeating: 0xCD, count: 32), createdAt: Date().addingTimeInterval(120))
        let valid = await protector.validate(futureNonce)
        #expect(!valid)
    }

    @Test("accepts nonce within clock skew tolerance")
    func acceptsWithinClockSkew() async throws {
        let protector = ReplayProtector(clockSkewTolerance: 30)
        let slightlyFuture = try Nonce(value: Data(repeating: 0xEF, count: 32), createdAt: Date().addingTimeInterval(10))
        let valid = await protector.validate(slightlyFuture)
        #expect(valid)
    }

    @Test("bounded memory - evicts oldest when full")
    func boundedMemory() async throws {
        let protector = ReplayProtector(windowDuration: 300, maxEntries: 10)
        for _ in 0..<20 {
            let nonce = try NonceGenerator().generate()
            _ = await protector.validate(nonce)
        }
        let count = await protector.entryCount()
        #expect(count <= 10)
    }

    @Test("repeated replay attempts all fail")
    func repeatedReplayFails() async throws {
        let protector = ReplayProtector()
        let nonce = try NonceGenerator().generate()
        _ = await protector.validate(nonce)
        for _ in 0..<10 {
            let result = await protector.validate(nonce)
            #expect(!result)
        }
    }
}

@Suite("Session State Machine")
struct SessionStateMachineTests {
    private func makeSession(ttl: TimeInterval = 30) throws -> Session {
        let nonce = try NonceGenerator().generate()
        return Session(trustRelationshipId: UUID(), nonce: nonce, ttl: ttl)
    }

    @Test("pending -> approved is valid")
    func pendingToApproved() throws {
        var session = try makeSession()
        #expect(session.state == .pending)
        try session.approve()
        #expect(session.state == .approved)
    }

    @Test("pending -> denied is valid")
    func pendingToDenied() throws {
        var session = try makeSession()
        try session.deny()
        #expect(session.state == .denied)
    }

    @Test("pending -> expired is valid")
    func pendingToExpired() throws {
        var session = try makeSession()
        try session.expire()
        #expect(session.state == .expired)
    }

    @Test("approved -> denied is INVALID")
    func approvedToDenied() throws {
        var session = try makeSession()
        try session.approve()
        #expect(throws: FaceBridgeError.self) {
            try session.deny()
        }
    }

    @Test("denied -> approved is INVALID")
    func deniedToApproved() throws {
        var session = try makeSession()
        try session.deny()
        #expect(throws: FaceBridgeError.self) {
            try session.approve()
        }
    }

    @Test("expired -> approved is INVALID")
    func expiredToApproved() throws {
        var session = try makeSession()
        try session.expire()
        #expect(throws: FaceBridgeError.self) {
            try session.approve()
        }
    }

    @Test("expired -> denied is INVALID")
    func expiredToDenied() throws {
        var session = try makeSession()
        try session.expire()
        #expect(throws: FaceBridgeError.self) {
            try session.deny()
        }
    }

    @Test("approved -> expired is INVALID")
    func approvedToExpired() throws {
        var session = try makeSession()
        try session.approve()
        #expect(throws: FaceBridgeError.self) {
            try session.expire()
        }
    }

    @Test("approve expired session sets state to expired")
    func approveExpiredSession() async throws {
        var session = try makeSession(ttl: 0)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(throws: FaceBridgeError.self) {
            try session.approve()
        }
        #expect(session.state == .expired)
    }
}

@Suite("AuditLogger")
struct AuditLoggerTests {
    @Test("logs entries")
    func logsEntries() async {
        let logger = AuditLogger()
        await logger.log(.pairingCompleted, deviceId: UUID())
        await logger.log(.authorizationApproved, sessionId: UUID())
        let entries = await logger.allEntries()
        #expect(entries.count == 2)
    }

    @Test("filters by event")
    func filtersByEvent() async {
        let logger = AuditLogger()
        await logger.log(.pairingCompleted)
        await logger.log(.authorizationApproved)
        await logger.log(.pairingCompleted)
        let pairings = await logger.entries(for: .pairingCompleted)
        #expect(pairings.count == 2)
    }

    @Test("respects max entries")
    func respectsMaxEntries() async {
        let logger = AuditLogger(maxEntries: 3)
        for _ in 0..<5 {
            await logger.log(.authorizationRequested)
        }
        let entries = await logger.allEntries()
        #expect(entries.count == 3)
    }
}
