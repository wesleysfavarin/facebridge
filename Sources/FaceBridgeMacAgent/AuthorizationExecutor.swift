import Foundation
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol

public actor AuthorizationExecutor {
    private let verifier: SignatureVerifying
    private let policyEngine: PolicyEngine
    private let auditLogger: AuditLogger

    public init(
        verifier: SignatureVerifying = SignatureVerifier(),
        policyEngine: PolicyEngine = PolicyEngine(),
        auditLogger: AuditLogger = AuditLogger()
    ) {
        self.verifier = verifier
        self.policyEngine = policyEngine
        self.auditLogger = auditLogger
    }

    public func execute(
        response: AuthorizationResponse,
        originalRequest: AuthorizationRequest,
        trustedPublicKey: Data,
        trustedDeviceId: UUID,
        session: Session,
        biometricVerified: Bool,
        rssi: Int? = nil
    ) async throws -> Bool {
        guard response.requestId == originalRequest.id else {
            await auditLogger.log(.authorizationDenied, sessionId: session.id, details: "Request ID binding mismatch")
            throw FaceBridgeError.requestBindingMismatch
        }

        let decision = policyEngine.evaluate(session: session, biometricVerified: biometricVerified, rssi: rssi)
        guard decision == .allowed else {
            await auditLogger.log(.authorizationDenied, sessionId: session.id, details: "Policy denied")
            return false
        }

        guard response.responderDeviceId == trustedDeviceId else {
            await auditLogger.log(.authorizationDenied, sessionId: session.id, details: "Device identity mismatch")
            throw FaceBridgeError.deviceIdentityMismatch
        }

        let expectedPayload = originalRequest.signable
        guard response.signedPayload == expectedPayload else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: session.id, details: "Payload integrity mismatch")
            throw FaceBridgeError.payloadIntegrityMismatch
        }

        guard response.decision == .approved else {
            let verified = try verifier.verify(
                signature: response.signature,
                data: response.signedPayload,
                publicKeyData: trustedPublicKey
            )
            guard verified else {
                await auditLogger.log(.signatureVerificationFailed, sessionId: session.id, details: "Denied response has invalid signature")
                return false
            }
            await auditLogger.log(.authorizationDenied, sessionId: session.id)
            return false
        }

        let valid = try verifier.verify(
            signature: response.signature,
            data: response.signedPayload,
            publicKeyData: trustedPublicKey
        )

        if valid {
            await auditLogger.log(.authorizationApproved, sessionId: session.id)
        } else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: session.id)
        }

        return valid
    }
}
