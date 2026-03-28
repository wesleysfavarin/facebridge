import Foundation
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol

public actor AuthorizationRequester {
    private let nonceGenerator: NonceGenerator
    private let keyManager: KeyManaging
    private let verifier: SignatureVerifying
    private let auditLogger: AuditLogger
    private let replayProtector: ReplayProtector

    public init(
        nonceGenerator: NonceGenerator = NonceGenerator(),
        keyManager: KeyManaging,
        verifier: SignatureVerifying = SignatureVerifier(),
        auditLogger: AuditLogger = AuditLogger(),
        replayProtector: ReplayProtector = ReplayProtector()
    ) {
        self.nonceGenerator = nonceGenerator
        self.keyManager = keyManager
        self.verifier = verifier
        self.auditLogger = auditLogger
        self.replayProtector = replayProtector
    }

    public func createRequest(
        senderDeviceId: UUID,
        keyTag: String,
        reason: String,
        transportType: String = "unknown",
        ttl: TimeInterval = 30
    ) throws -> AuthorizationRequest {
        let nonce = try nonceGenerator.generate()
        let challenge = try nonceGenerator.generate()

        let unsigned = AuthorizationRequest(
            senderDeviceId: senderDeviceId,
            nonce: nonce.value,
            challenge: challenge.value,
            reason: reason,
            transportType: transportType,
            ttl: ttl
        )

        let signature = try keyManager.sign(data: unsigned.signable, keyTag: keyTag)

        return AuthorizationRequest(
            id: unsigned.id,
            senderDeviceId: senderDeviceId,
            nonce: nonce.value,
            challenge: challenge.value,
            reason: reason,
            transportType: transportType,
            createdAt: unsigned.createdAt,
            ttl: ttl,
            senderSignature: signature
        )
    }

    public func verify(
        response: AuthorizationResponse,
        originalRequest: AuthorizationRequest,
        trustedPublicKey: Data
    ) async throws -> Bool {
        guard response.requestId == originalRequest.id else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: originalRequest.id, details: "Request ID mismatch")
            throw FaceBridgeError.requestBindingMismatch
        }

        let expectedPayload = originalRequest.signable
        guard response.signedPayload == expectedPayload else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: originalRequest.id, details: "Payload mismatch")
            throw FaceBridgeError.payloadIntegrityMismatch
        }

        let valid = try verifier.verify(
            signature: response.signature,
            data: response.signedPayload,
            publicKeyData: trustedPublicKey
        )

        if valid && response.decision == .approved {
            await auditLogger.log(.authorizationApproved, sessionId: originalRequest.id)
        } else if valid {
            await auditLogger.log(.authorizationDenied, sessionId: originalRequest.id)
        } else {
            await auditLogger.log(.signatureVerificationFailed, sessionId: originalRequest.id)
        }

        return valid && response.decision == .approved
    }
}
