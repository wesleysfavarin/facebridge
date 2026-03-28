import Testing
import Foundation
@testable import FaceBridgeCore

@Suite("NonceGenerator")
struct NonceTests {
    @Test("generates nonce with correct byte count")
    func generatesCorrectByteCount() {
        let generator = NonceGenerator(byteCount: 32)
        let nonce = generator.generate()
        #expect(nonce.value.count == 32)
    }

    @Test("generates unique nonces")
    func generatesUniqueNonces() {
        let generator = NonceGenerator()
        let a = generator.generate()
        let b = generator.generate()
        #expect(a.value != b.value)
    }

    @Test("nonce has creation timestamp")
    func hasTimestamp() {
        let before = Date()
        let nonce = NonceGenerator().generate()
        let after = Date()
        #expect(nonce.createdAt >= before)
        #expect(nonce.createdAt <= after)
    }

    @Test("minimum byte count enforced")
    func minimumByteCount() {
        let generator = NonceGenerator(byteCount: 16)
        let nonce = generator.generate()
        #expect(nonce.value.count == 16)
    }
}

@Suite("ReplayProtector")
struct ReplayProtectorTests {
    @Test("accepts fresh nonce")
    func acceptsFreshNonce() async {
        let protector = ReplayProtector()
        let nonce = NonceGenerator().generate()
        let valid = await protector.validate(nonce)
        #expect(valid)
    }

    @Test("rejects duplicate nonce")
    func rejectsDuplicate() async {
        let protector = ReplayProtector()
        let nonce = NonceGenerator().generate()
        _ = await protector.validate(nonce)
        let second = await protector.validate(nonce)
        #expect(!second)
    }

    @Test("rejects expired nonce")
    func rejectsExpired() async {
        let protector = ReplayProtector(windowDuration: 1)
        let expiredNonce = Nonce(value: Data(repeating: 0xAB, count: 32), createdAt: Date().addingTimeInterval(-10))
        let valid = await protector.validate(expiredNonce)
        #expect(!valid)
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
