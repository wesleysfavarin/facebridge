import Foundation

public enum FaceBridgeError: Error, Sendable {
    case keyGenerationFailed
    case cryptographicFailure(detail: String)
    case signingFailed(underlying: String)
    case verificationFailed(detail: String)
    case invalidPublicKey(reason: String)
    case nonceExpired
    case replayDetected
    case untrustedDevice
    case sessionExpired
    case invalidStateTransition(from: String, to: String)
    case pairingRejected
    case pairingCodeInvalid
    case pairingCodeExpired
    case pairingLockedOut
    case pairingSignatureInvalid
    case transportUnavailable
    case messageTooLarge(size: Int, max: Int)
    case connectionLimitExceeded
    case encodingFailed
    case decodingFailed
    case envelopeAuthenticationFailed
    case keychainError(status: Int32)
    case biometricUnavailable
    case biometricFailed
    case biometricUserCancelled
    case biometricLockout
    case biometricSystemCancelled
    case biometricNotEnrolled
    case biometricProofRequired
    case payloadIntegrityMismatch
    case deviceIdentityMismatch
    case requestBindingMismatch
    case policyDenied(reason: PolicyDenialReason)
    case queueOverflow
    case rateLimited
}

extension FaceBridgeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key pair."
        case .cryptographicFailure(let detail):
            return "Cryptographic operation failed: \(detail)"
        case .signingFailed(let underlying):
            return "Signing operation failed: \(underlying)"
        case .verificationFailed(let detail):
            return "Signature verification failed: \(detail)"
        case .invalidPublicKey(let reason):
            return "Invalid public key: \(reason)"
        case .nonceExpired:
            return "Nonce has expired."
        case .replayDetected:
            return "Replay attack detected."
        case .untrustedDevice:
            return "Device is not trusted."
        case .sessionExpired:
            return "Session has expired."
        case .invalidStateTransition(let from, let to):
            return "Invalid session state transition from \(from) to \(to)."
        case .pairingRejected:
            return "Pairing was rejected by the remote device."
        case .pairingCodeInvalid:
            return "Pairing code is invalid."
        case .pairingCodeExpired:
            return "Pairing code has expired."
        case .pairingLockedOut:
            return "Too many pairing attempts. Temporarily locked."
        case .pairingSignatureInvalid:
            return "Pairing message signature verification failed."
        case .transportUnavailable:
            return "No transport layer available."
        case .messageTooLarge(let size, let max):
            return "Message size \(size) exceeds maximum \(max) bytes."
        case .connectionLimitExceeded:
            return "Maximum connection limit exceeded."
        case .encodingFailed:
            return "Failed to encode payload."
        case .decodingFailed:
            return "Failed to decode payload."
        case .envelopeAuthenticationFailed:
            return "Message envelope authentication failed."
        case .keychainError(let status):
            return "Keychain operation failed with status: \(status)"
        case .biometricUnavailable:
            return "Biometric authentication is not available on this device."
        case .biometricFailed:
            return "Biometric authentication failed."
        case .biometricUserCancelled:
            return "Biometric authentication was cancelled by the user."
        case .biometricLockout:
            return "Biometric authentication is locked out."
        case .biometricSystemCancelled:
            return "Biometric authentication was cancelled by the system."
        case .biometricNotEnrolled:
            return "No biometrics enrolled on this device."
        case .biometricProofRequired:
            return "Biometric proof is required by policy."
        case .payloadIntegrityMismatch:
            return "Authorization payload integrity check failed."
        case .deviceIdentityMismatch:
            return "Responder device identity does not match trusted record."
        case .requestBindingMismatch:
            return "Response request ID does not match original request."
        case .policyDenied(let reason):
            return "Policy denied authorization: \(reason.rawValue)"
        case .queueOverflow:
            return "Request queue capacity exceeded."
        case .rateLimited:
            return "Rate limit exceeded for this device."
        }
    }
}
