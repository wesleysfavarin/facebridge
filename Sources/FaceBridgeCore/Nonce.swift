import Foundation

public struct Nonce: Codable, Hashable, Sendable {
    public let value: Data
    public let createdAt: Date

    public init(value: Data, createdAt: Date = Date()) {
        self.value = value
        self.createdAt = createdAt
    }
}

public struct NonceGenerator: Sendable {
    private let byteCount: Int

    public init(byteCount: Int = 32) {
        precondition(byteCount >= 16, "Nonce must be at least 16 bytes")
        self.byteCount = byteCount
    }

    public func generate() -> Nonce {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "Failed to generate cryptographically secure random bytes")
        return Nonce(value: Data(bytes))
    }
}
