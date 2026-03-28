import Foundation
import FaceBridgeCore

public struct SessionToken: Hashable, Sendable {
    public static let tokenByteCount = 32
    public static let minimumValueLength = 40

    public let value: String
    public let sessionId: UUID
    public let issuedAt: Date
    public let expiresAt: Date

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        sessionId: UUID,
        issuedAt: Date = Date(),
        ttl: TimeInterval = 30
    ) throws {
        var bytes = [UInt8](repeating: 0, count: Self.tokenByteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw FaceBridgeError.cryptographicFailure(detail: "Failed to generate session token")
        }
        guard bytes.contains(where: { $0 != 0 }) else {
            throw FaceBridgeError.cryptographicFailure(detail: "Session token was all zeros")
        }
        self.value = Data(bytes).base64EncodedString()
        self.sessionId = sessionId
        self.issuedAt = issuedAt
        self.expiresAt = issuedAt.addingTimeInterval(ttl)
    }

    private init(value: String, sessionId: UUID, issuedAt: Date, expiresAt: Date) throws {
        guard value.count >= Self.minimumValueLength else {
            throw FaceBridgeError.cryptographicFailure(detail: "Token value too short: \(value.count)")
        }
        guard Data(base64Encoded: value) != nil else {
            throw FaceBridgeError.cryptographicFailure(detail: "Token value is not valid base64")
        }
        self.value = value
        self.sessionId = sessionId
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
}

extension SessionToken: Codable {
    enum CodingKeys: String, CodingKey {
        case value, sessionId, issuedAt, expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            value: container.decode(String.self, forKey: .value),
            sessionId: container.decode(UUID.self, forKey: .sessionId),
            issuedAt: container.decode(Date.self, forKey: .issuedAt),
            expiresAt: container.decode(Date.self, forKey: .expiresAt)
        )
    }
}
