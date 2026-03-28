import Foundation
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol

public actor AuthorizationRequester {
    private let nonceGenerator: NonceGenerator
    private let verifier: SignatureVerifying
    private let auditLogger: AuditLogger
    private let replayProtector: ReplayProtector

    public init(
        nonceGenerator: NonceGenerator = NonceGenerator(),
        verifier: SignatureVerifying = SignatureVerifier(),
        auditLogger: AuditLogger = AuditLogger(),
        replayProtector: ReplayProtector = ReplayProtector()
    ) {
        self.nonceGenerator = nonceGenerator
        self.verifier = verifier
        self.auditLogger = auditLogger
        self.replayProtector = replayProtector
    }

    public func createRequest(
        senderDeviceId: UUID,
        reason: String,
        ttl: TimeInterval = 30
    ) -> AuthorizationRequest {
        let nonce = nonceGenerator.generate()
        let challenge = nonceGenerator.generate()

        return AuthorizationRequest(
            senderDeviceId: senderDeviceId,
            nonce: nonce.value,
            challenge: challenge.value,
            reason: reason,
            ttl: ttl
        )
    }

    public func verify(
        response: AuthorizationResponse,
        originalRequest: AuthorizationRequest,
        trustedPublicKey: Data
    ) async throws -> Bool {
        guard response.decision == .approved else {
            await auditLogger.log(.authorizationDenied, sessionId: originalRequest.id)
            return false
        }

        guard let signature = response.signature,
              let signedPayload = response.signedPayload else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: originalRequest.id)
            return false
        }

        let valid = try verifier.verify(
            signature: signature,
            data: signedPayload,
            publicKeyData: trustedPublicKey
        )

        if valid {
            await auditLogger.log(.authorizationApproved, sessionId: originalRequest.id)
        } else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: originalRequest.id)
        }

        return valid
    }
}
