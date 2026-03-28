import Testing
import Foundation
@testable import FaceBridgeCore

@Suite("PairingCodeGenerator")
struct PairingCodeGeneratorTests {
    @Test("generates 6-digit code")
    func generatesSixDigitCode() async throws {
        let gen = PairingCodeGenerator()
        let code = try await gen.generate()
        #expect(code.count == 6)
        #expect(Int(code) != nil)
    }

    @Test("validates correct code")
    func validatesCorrectCode() async throws {
        let gen = PairingCodeGenerator()
        let code = try await gen.generate()
        let result = await gen.validate(code: code, deviceId: UUID())
        #expect(result == .valid)
    }

    @Test("rejects invalid code")
    func rejectsInvalidCode() async {
        let gen = PairingCodeGenerator()
        let result = await gen.validate(code: "999999", deviceId: UUID())
        if case .invalid = result {
            // expected
        } else {
            Issue.record("Expected .invalid, got \(result)")
        }
    }

    @Test("locks out after max attempts")
    func locksOutAfterMaxAttempts() async throws {
        let gen = PairingCodeGenerator(maxAttempts: 3, ttl: 120)
        let deviceId = UUID()
        for _ in 0..<3 {
            _ = await gen.validate(code: "000000", deviceId: deviceId)
        }
        let result = await gen.validate(code: "000000", deviceId: deviceId)
        if case .lockedOut = result {
            // expected
        } else {
            Issue.record("Expected .lockedOut, got \(result)")
        }
    }

    @Test("code expires after TTL")
    func codeExpiresAfterTTL() async throws {
        let gen = PairingCodeGenerator(maxAttempts: 5, ttl: 0.1)
        let code = try await gen.generate()
        try await Task.sleep(for: .milliseconds(200))
        let result = await gen.validate(code: code, deviceId: UUID())
        #expect(result == .expired)
    }

    @Test("reset allows retries after lockout")
    func resetAllowsRetries() async throws {
        let gen = PairingCodeGenerator(maxAttempts: 1, ttl: 120)
        let deviceId = UUID()
        _ = await gen.validate(code: "000000", deviceId: deviceId)
        await gen.resetAttempts(for: deviceId)
        let code = try await gen.generate()
        let result = await gen.validate(code: code, deviceId: deviceId)
        #expect(result == .valid)
    }
}

@Suite("PairingFlowController")
struct PairingFlowControllerTests {
    @Test("generates invitation code and verifies it")
    func generatesAndVerifies() async throws {
        let controller = PairingFlowController()
        let code = try await controller.generateInvitationCode()
        let result = await controller.verifyCode(code, deviceId: UUID())
        #expect(result == .valid)
    }

    @Test("audit logs pairing events")
    func auditsEvents() async throws {
        let auditLogger = AuditLogger()
        let controller = PairingFlowController(auditLogger: auditLogger)
        let code = try await controller.generateInvitationCode()
        _ = await controller.verifyCode(code, deviceId: UUID())
        let entries = await auditLogger.allEntries()
        #expect(entries.count >= 2)
    }
}
