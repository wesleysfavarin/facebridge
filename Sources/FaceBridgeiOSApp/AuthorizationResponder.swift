import Foundation
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol

public actor AuthorizationResponder {
    private let localDeviceId: UUID
    private let authenticator: BiometricAuthenticator
    private let keyManager: KeyManaging
    private let trustManager: DeviceTrustManager
    private let auditLogger: AuditLogger
    private let replayProtector: ReplayProtector
    private let signatureVerifier: SignatureVerifying

    public init(
        localDeviceId: UUID,
        authenticator: BiometricAuthenticator = BiometricAuthenticator(),
        keyManager: KeyManaging,
        trustManager: DeviceTrustManager,
        auditLogger: AuditLogger = AuditLogger(),
        replayProtector: ReplayProtector = ReplayProtector(),
        signatureVerifier: SignatureVerifying = SignatureVerifier()
    ) {
        self.localDeviceId = localDeviceId
        self.authenticator = authenticator
        self.keyManager = keyManager
        self.trustManager = trustManager
        self.auditLogger = auditLogger
        self.replayProtector = replayProtector
        self.signatureVerifier = signatureVerifier
    }

    public func respond(to request: AuthorizationRequest, keyTag: String) async throws -> AuthorizationResponse {
        let localReceiptTime = Date()
        let payload = request.signable

        guard !request.isExpired else {
            await auditLogger.log(.sessionExpired, sessionId: request.id)
            let signature = try keyManager.sign(data: payload, keyTag: keyTag)
            return try AuthorizationResponse(
                requestId: request.id,
                responderDeviceId: localDeviceId,
                decision: .expired,
                signature: signature,
                signedPayload: payload,
                respondedAt: localReceiptTime
            )
        }

        guard await trustManager.isTrusted(request.senderDeviceId) else {
            await auditLogger.log(.authorizationDenied, deviceId: request.senderDeviceId, details: "Untrusted device")
            throw FaceBridgeError.untrustedDevice
        }

        if let senderSig = request.senderSignature {
            let senderPublicKey = await trustManager.publicKey(for: request.senderDeviceId)
            if let pubKey = senderPublicKey {
                let validOrigin = try signatureVerifier.verify(signature: senderSig, data: payload, publicKeyData: pubKey)
                guard validOrigin else {
                    await auditLogger.log(.signatureVerificationFailed, deviceId: request.senderDeviceId, details: "Request origin signature invalid")
                    throw FaceBridgeError.pairingSignatureInvalid
                }
            }
        }

        let nonce = try Nonce(value: request.nonce, createdAt: localReceiptTime)
        guard await replayProtector.validate(nonce) else {
            await auditLogger.log(.replayDetected, sessionId: request.id)
            throw FaceBridgeError.replayDetected
        }

        let authenticated = try await authenticator.authenticate(reason: request.reason)

        guard authenticated else {
            await auditLogger.log(.authorizationDenied, sessionId: request.id)
            let signature = try keyManager.sign(data: payload, keyTag: keyTag)
            return try AuthorizationResponse(
                requestId: request.id,
                responderDeviceId: localDeviceId,
                decision: .denied,
                signature: signature,
                signedPayload: payload,
                respondedAt: localReceiptTime
            )
        }

        let signature = try keyManager.sign(data: payload, keyTag: keyTag)
        await auditLogger.log(.authorizationApproved, sessionId: request.id)

        return try AuthorizationResponse(
            requestId: request.id,
            responderDeviceId: localDeviceId,
            decision: .approved,
            signature: signature,
            signedPayload: payload,
            respondedAt: localReceiptTime
        )
    }
}
