import Foundation

public actor PairingFlowController {
    private let generator: PairingCodeGenerator
    private let auditLogger: AuditLogger

    public init(maxAttempts: Int = 5, ttl: TimeInterval = 120, auditLogger: AuditLogger = AuditLogger()) {
        self.generator = PairingCodeGenerator(maxAttempts: maxAttempts, ttl: ttl)
        self.auditLogger = auditLogger
    }

    public func generateInvitationCode() async throws -> String {
        let code = try await generator.generate()
        await auditLogger.log(.pairingInitiated, details: "Invitation code generated")
        return code
    }

    public func verifyCode(_ code: String, deviceId: UUID) async -> PairingCodeResult {
        let result = await generator.validate(code: code, deviceId: deviceId)
        switch result {
        case .valid:
            await auditLogger.log(.pairingCompleted, deviceId: deviceId, details: "Code verified")
        case .invalid(let remaining):
            await auditLogger.log(.pairingFailed, deviceId: deviceId, details: "Invalid code, \(remaining) attempts remaining")
        case .expired:
            await auditLogger.log(.pairingFailed, deviceId: deviceId, details: "Expired code")
        case .lockedOut:
            await auditLogger.log(.pairingFailed, deviceId: deviceId, details: "Device locked out")
        }
        return result
    }

    public func resetAttempts(for deviceId: UUID) async {
        await generator.resetAttempts(for: deviceId)
    }
}
