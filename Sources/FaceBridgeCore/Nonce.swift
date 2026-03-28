import Foundation

public struct Nonce: Hashable, Sendable {
    public static let minimumByteCount = 16
    public static let clockSkewTolerance: TimeInterval = 30

    public let value: Data
    public let createdAt: Date

    public init(value: Data, createdAt: Date = Date()) throws {
        guard value.count >= Self.minimumByteCount else {
            throw FaceBridgeError.cryptographicFailure(detail: "Nonce too short: \(value.count) bytes, minimum \(Self.minimumByteCount)")
        }
        guard value.contains(where: { $0 != 0 }) else {
            throw FaceBridgeError.cryptographicFailure(detail: "Nonce is all zeros")
        }
        self.value = value
        self.createdAt = createdAt
    }
}

extension Nonce: Codable {
    enum CodingKeys: String, CodingKey {
        case value, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Data.self, forKey: .value)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        try self.init(value: value, createdAt: createdAt)
    }
}

public struct NonceGenerator: Sendable {
    private let byteCount: Int

    public init(byteCount: Int = 32) {
        self.byteCount = max(byteCount, Nonce.minimumByteCount)
    }

    public func generate() throws -> Nonce {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw FaceBridgeError.cryptographicFailure(detail: "SecRandomCopyBytes failed with status \(status)")
        }
        return try Nonce(value: Data(bytes))
    }
}
