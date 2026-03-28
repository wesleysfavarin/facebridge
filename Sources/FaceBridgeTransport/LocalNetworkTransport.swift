import Foundation
import Network
import os
import FaceBridgeCore
import FaceBridgeProtocol

public final class LocalNetworkTransport: Transport, @unchecked Sendable {
    public static let maxMessageSize: UInt32 = 1_048_576
    public static let maxConnections = 10
    public static let idleTimeout: TimeInterval = 120

    public let transportType: TransportType = .localNetwork
    public weak var delegate: TransportDelegate?

    private struct MutableState {
        var connectionState: ConnectionState = .disconnected
        var browser: NWBrowser?
        var listener: NWListener?
        var connections: [UUID: NWConnection] = [:]
        var endpointToDevice: [NWEndpoint: UUID] = [:]
        var connectionTimestamps: [UUID: Date] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: MutableState())
    private let bonjourType = "_facebridge._tcp"
    private let encoder = MessageEncoder()
    private let queue = DispatchQueue(label: "com.facebridge.network", qos: .userInitiated)
    private let useTLS: Bool
    private let tlsOptions: NWProtocolTLS.Options?
    private let allowInsecure: Bool

    public var connectionState: ConnectionState {
        state.withLock { $0.connectionState }
    }

    /// - Parameters:
    ///   - tlsOptions: Custom TLS options. If nil, uses default TLS with insecure local identity.
    ///   - allowInsecure: If true, allows plaintext TCP. Debug/test use ONLY.
    public init(tlsOptions: NWProtocolTLS.Options? = nil, allowInsecure: Bool = false) {
        self.allowInsecure = allowInsecure
        if let tlsOptions {
            self.tlsOptions = tlsOptions
            self.useTLS = true
        } else if !allowInsecure {
            self.tlsOptions = NWProtocolTLS.Options()
            self.useTLS = true
        } else {
            self.tlsOptions = nil
            self.useTLS = false
        }
    }

    public func startDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: bonjourType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleBrowseResults(results)
        }
        browser.start(queue: queue)
        state.withLock { $0.browser = browser }
    }

    public func stopDiscovery() {
        state.withLock { s in
            s.browser?.cancel()
            s.browser = nil
        }
    }

    public func startListening() throws {
        let parameters: NWParameters
        if let tlsOptions {
            parameters = NWParameters(tls: tlsOptions)
        } else if allowInsecure {
            parameters = NWParameters.tcp
        } else {
            parameters = NWParameters(tls: NWProtocolTLS.Options())
        }
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(type: bonjourType)

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleIncoming(connection)
        }

        listener.start(queue: queue)
        state.withLock { $0.listener = listener }
    }

    public func connect(to deviceId: UUID) async throws {
        throw FaceBridgeError.transportUnavailable
    }

    public func disconnect(from deviceId: UUID) async throws {
        state.withLock { s in
            s.connections[deviceId]?.cancel()
            s.connections.removeValue(forKey: deviceId)
            s.connectionTimestamps.removeValue(forKey: deviceId)
            s.connectionState = s.connections.isEmpty ? .disconnected : .connected
        }
    }

    public func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {
        let data = try encoder.encodeEnvelope(envelope)
        guard data.count <= Self.maxMessageSize else {
            throw FaceBridgeError.messageTooLarge(size: data.count, max: Int(Self.maxMessageSize))
        }
        let lengthPrefix = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
        let framed = lengthPrefix + data

        let connection: NWConnection? = state.withLock { $0.connections[deviceId] }
        guard let connection else {
            throw FaceBridgeError.transportUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framed, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: FaceBridgeError.transportUnavailable)
                    _ = error
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func pruneIdleConnections() {
        let now = Date()
        state.withLock { s in
            let idle = s.connectionTimestamps.filter { now.timeIntervalSince($0.value) > Self.idleTimeout }
            for (deviceId, _) in idle {
                s.connections[deviceId]?.cancel()
                s.connections.removeValue(forKey: deviceId)
                s.connectionTimestamps.removeValue(forKey: deviceId)
            }
            s.connectionState = s.connections.isEmpty ? .disconnected : .connected
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            let deviceId = UUID()
            state.withLock { $0.endpointToDevice[result.endpoint] = deviceId }
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
        let connectionCount = state.withLock { $0.connections.count }
        guard connectionCount < Self.maxConnections else {
            connection.cancel()
            delegate?.transport(self, didFailWithError: .connectionLimitExceeded)
            return
        }

        let deviceId = UUID()
        state.withLock { s in
            s.connections[deviceId] = connection
            s.connectionTimestamps[deviceId] = Date()
            s.connectionState = .connected
        }

        connection.start(queue: queue)
        receiveLoop(on: connection, deviceId: deviceId)
        delegate?.transport(self, didConnect: deviceId)
    }

    private func receiveLoop(on connection: NWConnection, deviceId: UUID) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] lengthData, _, _, error in
            guard let self, let lengthData, error == nil else {
                self?.cleanupConnection(deviceId)
                return
            }
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            guard length > 0, length <= Self.maxMessageSize else {
                connection.cancel()
                self.cleanupConnection(deviceId)
                self.delegate?.transport(self, didFailWithError: .messageTooLarge(size: Int(length), max: Int(Self.maxMessageSize)))
                return
            }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] data, _, _, error in
                guard let self, let data, error == nil else {
                    self?.cleanupConnection(deviceId)
                    return
                }
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

    private func cleanupConnection(_ deviceId: UUID) {
        state.withLock { s in
            s.connections[deviceId]?.cancel()
            s.connections.removeValue(forKey: deviceId)
            s.connectionTimestamps.removeValue(forKey: deviceId)
            s.connectionState = s.connections.isEmpty ? .disconnected : .connected
        }
    }
}
