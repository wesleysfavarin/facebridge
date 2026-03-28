import Foundation

public enum FaceBridgeError: Error, Sendable {
    case keyGenerationFailed
    case signingFailed(underlying: String)
    case verificationFailed
    case nonceExpired
    case replayDetected
    case untrustedDevice
    case sessionExpired
    case pairingRejected
    case transportUnavailable
    case encodingFailed
    case decodingFailed
    case keychainError(status: Int32)
    case biometricUnavailable
    case biometricFailed
    case policyDenied(reason: PolicyDenialReason)
}

extension FaceBridgeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key pair."
        case .signingFailed(let underlying):
            return "Signing operation failed: \(underlying)"
        case .verificationFailed:
            return "Signature verification failed."
        case .nonceExpired:
            return "Nonce has expired."
        case .replayDetected:
            return "Replay attack detected."
        case .untrustedDevice:
            return "Device is not trusted."
        case .sessionExpired:
            return "Session has expired."
        case .pairingRejected:
            return "Pairing was rejected by the remote device."
        case .transportUnavailable:
            return "No transport layer available."
        case .encodingFailed:
            return "Failed to encode payload."
        case .decodingFailed:
            return "Failed to decode payload."
        case .keychainError(let status):
            return "Keychain operation failed with status: \(status)"
        case .biometricUnavailable:
            return "Biometric authentication is not available on this device."
        case .biometricFailed:
            return "Biometric authentication failed."
        case .policyDenied(let reason):
            return "Policy denied authorization: \(reason.rawValue)"
        }
    }
}
