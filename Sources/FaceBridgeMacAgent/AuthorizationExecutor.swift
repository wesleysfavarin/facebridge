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
        session: Session,
        rssi: Int? = nil
    ) async throws -> Bool {
        let decision = policyEngine.evaluate(session: session, rssi: rssi)
        guard decision == .allowed else {
            await auditLogger.log(.authorizationDenied, sessionId: session.id, details: "Policy denied")
            return false
        }

        guard response.decision == .approved,
              let signature = response.signature,
              let payload = response.signedPayload else {
            await auditLogger.log(.authorizationDenied, sessionId: session.id)
            return false
        }

        let valid = try verifier.verify(
            signature: signature,
            data: payload,
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
