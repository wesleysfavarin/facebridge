import Foundation

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
    public let payload: Data
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        type: MessageType,
        version: ProtocolVersion = .current,
        payload: Data,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.version = version
        self.payload = payload
        self.timestamp = timestamp
    }
}

public struct MessageEncoder: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func encode<T: Encodable & Sendable>(_ value: T, type: MessageType) throws -> MessageEnvelope {
        let payload = try encoder.encode(value)
        return MessageEnvelope(type: type, payload: payload)
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
