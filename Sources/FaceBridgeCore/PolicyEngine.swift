import Foundation

public struct AuthorizationPolicy: Sendable {
    public let requireBiometric: Bool
    public let maxSessionTTL: TimeInterval
    public let requireProximity: Bool
    public let minimumRSSI: Int

    public static let `default` = AuthorizationPolicy(
        requireBiometric: true,
        maxSessionTTL: 30,
        requireProximity: false,
        minimumRSSI: -70
    )

    public static let strict = AuthorizationPolicy(
        requireBiometric: true,
        maxSessionTTL: 15,
        requireProximity: true,
        minimumRSSI: -50
    )

    public init(
        requireBiometric: Bool,
        maxSessionTTL: TimeInterval,
        requireProximity: Bool,
        minimumRSSI: Int
    ) {
        self.requireBiometric = requireBiometric
        self.maxSessionTTL = maxSessionTTL
        self.requireProximity = requireProximity
        self.minimumRSSI = minimumRSSI
    }
}

public struct PolicyEngine: Sendable {
    private let policy: AuthorizationPolicy

    public init(policy: AuthorizationPolicy = .default) {
        self.policy = policy
    }

    public func evaluate(session: Session, biometricVerified: Bool = false, rssi: Int? = nil) -> PolicyDecision {
        if session.isExpired {
            return .denied(reason: .sessionExpired)
        }

        let sessionDuration = session.expiresAt.timeIntervalSince(session.createdAt)
        if sessionDuration > policy.maxSessionTTL {
            return .denied(reason: .sessionTTLExceeded)
        }

        if policy.requireBiometric && !biometricVerified {
            return .denied(reason: .biometricRequired)
        }

        if policy.requireProximity {
            guard let rssi else {
                return .denied(reason: .proximityRequired)
            }
            if rssi < policy.minimumRSSI {
                return .denied(reason: .deviceTooFar)
            }
        }

        return .allowed
    }
}

public enum PolicyDecision: Sendable, Equatable {
    case allowed
    case denied(reason: PolicyDenialReason)
}

public enum PolicyDenialReason: String, Sendable, Equatable {
    case sessionExpired
    case sessionTTLExceeded
    case biometricRequired
    case proximityRequired
    case deviceTooFar
    case untrustedDevice
    case replayDetected
}
