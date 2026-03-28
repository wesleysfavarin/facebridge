import Foundation
import CryptoKit

public enum MessageType: String, Codable, Sendable {
    case pairingInvitation
    case pairingAcceptance
    case pairingConfirmation
    case authorizationRequest
    case authorizationResponse
    case protocolError
}

public struct MessageEnvelope: Codable, Sendable {
    public let id: UUID
    public let type: MessageType
    public let version: ProtocolVersion
    public let sequenceNumber: UInt64
    public let payload: Data
    public let timestamp: Date
    public let mac: Data?

    public init(
        id: UUID = UUID(),
        type: MessageType,
        version: ProtocolVersion = .current,
        sequenceNumber: UInt64 = 0,
        payload: Data,
        timestamp: Date = Date(),
        mac: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.version = version
        self.sequenceNumber = sequenceNumber
        self.payload = payload
        self.timestamp = timestamp
        self.mac = mac
    }

    public func authenticatedCopy(key: SymmetricKey) -> MessageEnvelope {
        let canonical = computeCanonicalData()
        let tag = HMAC<SHA256>.authenticationCode(for: canonical, using: key)
        return MessageEnvelope(
            id: id, type: type, version: version,
            sequenceNumber: sequenceNumber, payload: payload,
            timestamp: timestamp, mac: Data(tag)
        )
    }

    public func verifyMAC(key: SymmetricKey) -> Bool {
        guard let mac else { return false }
        let canonical = computeCanonicalData()
        return HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: canonical, using: key)
    }

    private func computeCanonicalData() -> Data {
        var data = Data()
        data.append(Data(id.uuidString.utf8))
        data.append(Data(type.rawValue.utf8))
        data.append(Data("\(version.major).\(version.minor)".utf8))
        var seq = sequenceNumber.bigEndian
        data.append(Data(bytes: &seq, count: 8))
        data.append(payload)
        var ts = UInt64(timestamp.timeIntervalSince1970 * 1000).bigEndian
        data.append(Data(bytes: &ts, count: 8))
        return data
    }
}

public struct MessageEncoder: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func encode<T: Encodable & Sendable>(_ value: T, type: MessageType, sequenceNumber: UInt64 = 0) throws -> MessageEnvelope {
        let payload = try encoder.encode(value)
        return MessageEnvelope(type: type, sequenceNumber: sequenceNumber, payload: payload)
    }

    public func decode<T: Decodable>(_ type: T.Type, from envelope: MessageEnvelope) throws -> T {
        try decoder.decode(type, from: envelope.payload)
    }

    public func encodeEnvelope(_ envelope: MessageEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public func decodeEnvelope(from data: Data) throws -> MessageEnvelope {
        try decoder.decode(MessageEnvelope.self, from: data)
    }
}
