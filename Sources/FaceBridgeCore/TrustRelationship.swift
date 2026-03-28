import Foundation

public struct TrustRelationship: Codable, Hashable, Sendable {
    public let id: UUID
    public let localDevice: DeviceIdentity
    public let remoteDevice: DeviceIdentity
    public let establishedAt: Date
    public var revokedAt: Date?

    public var isActive: Bool { revokedAt == nil }

    public init(
        id: UUID = UUID(),
        localDevice: DeviceIdentity,
        remoteDevice: DeviceIdentity,
        establishedAt: Date = Date(),
        revokedAt: Date? = nil
    ) {
        self.id = id
        self.localDevice = localDevice
        self.remoteDevice = remoteDevice
        self.establishedAt = establishedAt
        self.revokedAt = revokedAt
    }

    public func revoked() -> TrustRelationship {
        var copy = self
        copy.revokedAt = Date()
        return copy
    }
}
