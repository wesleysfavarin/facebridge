import Foundation

public enum ProtocolErrorCode: Int, Codable, Sendable {
    case unknown = 0
    case versionMismatch = 100
    case requestExpired = 200
    case nonceReplay = 201
    case signatureInvalid = 300
    case deviceUntrusted = 400
    case pairingExpired = 401
    case pairingRejected = 402
    case biometricFailed = 500
    case biometricUnavailable = 501
    case transportError = 600
    case encodingError = 700
    case decodingError = 701

    public var description: String {
        switch self {
        case .unknown: return "Unknown error"
        case .versionMismatch: return "Protocol version mismatch"
        case .requestExpired: return "Authorization request expired"
        case .nonceReplay: return "Nonce replay detected"
        case .signatureInvalid: return "Signature verification failed"
        case .deviceUntrusted: return "Device is not trusted"
        case .pairingExpired: return "Pairing invitation expired"
        case .pairingRejected: return "Pairing was rejected"
        case .biometricFailed: return "Biometric authentication failed"
        case .biometricUnavailable: return "Biometric authentication unavailable"
        case .transportError: return "Transport layer error"
        case .encodingError: return "Payload encoding error"
        case .decodingError: return "Payload decoding error"
        }
    }
}

public struct ProtocolError: Codable, Sendable {
    public let code: ProtocolErrorCode
    public let message: String?
    public let timestamp: Date

    public init(code: ProtocolErrorCode, message: String? = nil, timestamp: Date = Date()) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}
