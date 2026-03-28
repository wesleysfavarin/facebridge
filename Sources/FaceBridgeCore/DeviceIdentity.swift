import Foundation

/// P-256 public key in X9.63 uncompressed format: 0x04 || X (32 bytes) || Y (32 bytes) = 65 bytes total
public struct DeviceIdentity: Hashable, Sendable {
    public static let expectedP256PublicKeySize = 65
    public static let uncompressedPointPrefix: UInt8 = 0x04
    public static let maxDisplayNameLength = 100

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
    ) throws {
        try Self.validatePublicKey(publicKeyData)
        self.id = id
        self.displayName = Self.sanitizeDisplayName(displayName)
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.createdAt = createdAt
    }

    public static func validatePublicKey(_ data: Data) throws {
        guard !data.isEmpty else {
            throw FaceBridgeError.invalidPublicKey(reason: "Empty key data")
        }
        guard data.count == expectedP256PublicKeySize else {
            throw FaceBridgeError.invalidPublicKey(reason: "Expected \(expectedP256PublicKeySize) bytes for P-256 X9.63, got \(data.count)")
        }
        guard data[data.startIndex] == uncompressedPointPrefix else {
            throw FaceBridgeError.invalidPublicKey(reason: "Missing 0x04 uncompressed point prefix")
        }
    }

    static func sanitizeDisplayName(_ name: String) -> String {
        String(name.unicodeScalars.filter {
            !$0.properties.isBidiControl &&
            $0.value != 0x202E && $0.value != 0x202D &&
            $0.value != 0x200F && $0.value != 0x200E &&
            $0.value != 0x2066 && $0.value != 0x2067 &&
            $0.value != 0x2068 && $0.value != 0x2069 &&
            !$0.properties.isDefaultIgnorableCodePoint &&
            ($0.value >= 0x20 || $0.value == 0x0A)
        }.prefix(maxDisplayNameLength).map { Character($0) })
    }
}

extension DeviceIdentity: Codable {
    enum CodingKeys: String, CodingKey {
        case id, displayName, platform, publicKeyData, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let platform = try container.decode(DevicePlatform.self, forKey: .platform)
        let publicKeyData = try container.decode(Data.self, forKey: .publicKeyData)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        try self.init(id: id, displayName: displayName, platform: platform, publicKeyData: publicKeyData, createdAt: createdAt)
    }
}

public enum DevicePlatform: String, Codable, Hashable, Sendable {
    case iOS
    case macOS
}
