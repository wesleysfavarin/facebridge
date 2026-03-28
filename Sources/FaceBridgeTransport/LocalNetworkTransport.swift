import Foundation
import Network
import FaceBridgeCore
import FaceBridgeProtocol

public final class LocalNetworkTransport: Transport, @unchecked Sendable {
    public let transportType: TransportType = .localNetwork
    public private(set) var connectionState: ConnectionState = .disconnected
    public weak var delegate: TransportDelegate?

    private let bonjourType = "_facebridge._tcp"
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var endpointToDevice: [NWEndpoint: UUID] = [:]
    private let encoder = MessageEncoder()
    private let queue = DispatchQueue(label: "com.facebridge.network", qos: .userInitiated)

    public init() {}

    public func startDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: bonjourType, domain: nil), using: parameters)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleBrowseResults(results)
        }
        browser?.start(queue: queue)
    }

    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    public func startListening() throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        listener = try NWListener(using: parameters)
        listener?.service = NWListener.Service(type: bonjourType)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleIncoming(connection)
        }

        listener?.start(queue: queue)
    }

    public func connect(to deviceId: UUID) async throws {
        throw FaceBridgeError.transportUnavailable
    }

    public func disconnect(from deviceId: UUID) async throws {
        connections[deviceId]?.cancel()
        connections.removeValue(forKey: deviceId)
        connectionState = connections.isEmpty ? .disconnected : .connected
    }

    public func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {
        guard let connection = connections[deviceId] else {
            throw FaceBridgeError.transportUnavailable
        }

        let data = try encoder.encodeEnvelope(envelope)
        let lengthPrefix = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
        let framed = lengthPrefix + data

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framed, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: FaceBridgeError.signingFailed(underlying: error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            let deviceId = UUID()
            endpointToDevice[result.endpoint] = deviceId
            let device = DiscoveredDevice(
                id: deviceId,
                displayName: result.endpoint.debugDescription,
                rssi: 0,
                transportType: .localNetwork
            )
            delegate?.transport(self, didDiscover: device)
        }
    }

    private func handleIncoming(_ connection: NWConnection) {
        let deviceId = UUID()
        connections[deviceId] = connection
        connectionState = .connected

        connection.start(queue: queue)
        receiveLoop(on: connection, deviceId: deviceId)
        delegate?.transport(self, didConnect: deviceId)
    }

    private func receiveLoop(on connection: NWConnection, deviceId: UUID) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] lengthData, _, _, error in
            guard let self, let lengthData, error == nil else { return }

            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] data, _, _, error in
                guard let self, let data, error == nil else { return }

                do {
                    let envelope = try self.encoder.decodeEnvelope(from: data)
                    self.delegate?.transport(self, didReceive: envelope, from: deviceId)
                } catch {
                    self.delegate?.transport(self, didFailWithError: .decodingFailed)
                }

                self.receiveLoop(on: connection, deviceId: deviceId)
            }
        }
    }
}
