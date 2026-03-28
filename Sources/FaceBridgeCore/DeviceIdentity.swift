import Foundation

public struct DeviceIdentity: Codable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.createdAt = createdAt
    }
}

public enum DevicePlatform: String, Codable, Hashable, Sendable {
    case iOS
    case macOS
}
