import Foundation
import FaceBridgeCore

public struct PairingInvitation: Codable, Sendable {
    public let id: UUID
    public let version: ProtocolVersion
    public let deviceId: UUID
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let pairingCode: String
    public let createdAt: Date
    public let expiresAt: Date

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        id: UUID = UUID(),
        version: ProtocolVersion = .current,
        deviceId: UUID,
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        pairingCode: String,
        createdAt: Date = Date(),
        ttl: TimeInterval = 120
    ) {
        self.id = id
        self.version = version
        self.deviceId = deviceId
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.pairingCode = pairingCode
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttl)
    }
}

public struct PairingAcceptance: Codable, Sendable {
    public let invitationId: UUID
    public let version: ProtocolVersion
    public let deviceId: UUID
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let acceptedAt: Date

    public init(
        invitationId: UUID,
        version: ProtocolVersion = .current,
        deviceId: UUID,
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        acceptedAt: Date = Date()
    ) {
        self.invitationId = invitationId
        self.version = version
        self.deviceId = deviceId
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.acceptedAt = acceptedAt
    }
}

public struct PairingConfirmation: Codable, Sendable {
    public let invitationId: UUID
    public let confirmed: Bool
    public let confirmedAt: Date

    public init(invitationId: UUID, confirmed: Bool, confirmedAt: Date = Date()) {
        self.invitationId = invitationId
        self.confirmed = confirmed
        self.confirmedAt = confirmedAt
    }
}
