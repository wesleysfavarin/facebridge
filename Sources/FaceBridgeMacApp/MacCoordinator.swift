import Foundation
import SwiftUI
import os
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol
import FaceBridgeTransport

@MainActor
public final class MacCoordinator: ObservableObject, @unchecked Sendable {
    @Published public var discoveredDevices: [DiscoveredDevice] = []
    @Published public var pairedDevices: [DeviceIdentity] = []
    @Published public var pairingCode: String = ""
    @Published public var pairingState: PairingPhase = .idle
    @Published public var lastAuthResult: String = ""
    @Published public var logMessages: [LogEntry] = []

    public enum PairingPhase: String {
        case idle, generatingCode, waitingForAcceptance, verifyingSAS, completed, failed
    }

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp = Date()
        public let category: String
        public let message: String
    }

    private let localDeviceId = UUID()
    private let keyTag = "com.facebridge.mac.device-key"

    private let lanTransport: LocalNetworkTransport
    private let bleTransport: BLETransport
    private let connectionManager = ConnectionManager()
    private let pairingController = PairingFlowController()
    private let deviceManager: PairedDeviceManager
    private let keyManager: SoftwareKeyManager
    private let requester: AuthorizationRequester
    private let auditLogger = AuditLogger()
    private let encoder = MessageEncoder()
    private var transportBridge: MacTransportBridge?

    public var localPublicKeyData: Data?
    private var pendingRequests: [UUID: AuthorizationRequest] = [:]
    private var deviceTransportMap: [UUID: any Transport] = [:]

    public init() {
        let store = KeychainStore()
        self.keyManager = SoftwareKeyManager(store: store)
        self.deviceManager = PairedDeviceManager(keychainStore: store, auditLogger: auditLogger)
        self.requester = AuthorizationRequester(keyManager: keyManager, auditLogger: auditLogger)
        self.lanTransport = LocalNetworkTransport(allowInsecure: true)
        self.bleTransport = BLETransport()
    }

    public func start() {
        log("lifecycle", "Mac coordinator starting")
        do {
            localPublicKeyData = try keyManager.generateKeyPair(tag: keyTag)
            log("crypto", "Device key pair generated (or loaded)")
        } catch {
            log("crypto", "Key generation: using existing key")
            localPublicKeyData = try? keyManager.publicKeyData(for: keyTag)
        }

        let bridge = MacTransportBridge(coordinator: self)
        self.transportBridge = bridge
        lanTransport.delegate = bridge
        bleTransport.delegate = bridge

        Task {
            await connectionManager.register(lanTransport)
            await connectionManager.register(bleTransport)
        }

        do {
            try lanTransport.startListening()
            log("transport", "LAN listener started (Bonjour: _facebridge._tcp)")
        } catch {
            log("transport", "LAN listener failed: \(error)")
        }
        lanTransport.startDiscovery()
        log("transport", "LAN discovery started")

        bleTransport.startDiscovery()
        log("transport", "BLE discovery started (scanning)")

        bleTransport.startAdvertising(displayName: "FaceBridge-Mac")
        log("transport", "BLE advertising started")

        Task {
            try? await deviceManager.loadPairedDevices()
            let devices = await deviceManager.allPairedDevices()
            await MainActor.run { self.pairedDevices = devices }
            log("lifecycle", "Loaded \(devices.count) paired device(s)")
        }

        log("lifecycle", "Mac coordinator ready — local device ID: \(localDeviceId)")
    }

    public func generatePairingCode() {
        pairingState = .generatingCode
        Task {
            do {
                let code = try await pairingController.generateInvitationCode()
                await MainActor.run {
                    self.pairingCode = code
                    self.pairingState = .waitingForAcceptance
                }
                log("pairing", "Pairing code generated: \(code)")
            } catch {
                await MainActor.run { self.pairingState = .failed }
                log("pairing", "Code generation failed: \(error)")
            }
        }
    }

    public func sendAuthorizationRequest(to deviceId: UUID, reason: String) {
        Task {
            do {
                log("authorization", "Connecting to device \(deviceId)…")
                try await ensureConnected(to: deviceId)

                let request = try await requester.createRequest(
                    senderDeviceId: localDeviceId,
                    keyTag: keyTag,
                    reason: reason,
                    transportType: "lan",
                    ttl: 30
                )

                let envelope = try encoder.encode(request, type: .authorizationRequest, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)

                pendingRequests[request.id] = request
                log("authorization", "Authorization request sent to \(deviceId) — reason: \(reason)")
                await MainActor.run { self.lastAuthResult = "Request sent…" }
            } catch {
                log("authorization", "Failed to send request: \(error)")
                await MainActor.run { self.lastAuthResult = "Send failed: \(error.localizedDescription)" }
            }
        }
    }

    private func ensureConnected(to deviceId: UUID) async throws {
        if deviceTransportMap[deviceId] != nil { return }
        try await lanTransport.connect(to: deviceId)
        deviceTransportMap[deviceId] = lanTransport
        log("transport", "Outgoing connection established to \(deviceId)")
    }

    private func sendToDevice(_ envelope: MessageEnvelope, deviceId: UUID) async throws {
        if let transport = deviceTransportMap[deviceId] {
            try await transport.send(envelope, to: deviceId)
        } else {
            try await lanTransport.send(envelope, to: deviceId)
        }
    }

    func handleDiscovery(_ device: DiscoveredDevice) {
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
            }
        }
        log("transport", "Discovered: \(device.displayName) via \(device.transportType.rawValue) (RSSI: \(device.rssi))")
    }

    func handleConnect(_ deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Connected: \(deviceId)")
        if let transport {
            deviceTransportMap[deviceId] = transport
        }
    }

    func handleDisconnect(_ deviceId: UUID) {
        log("transport", "Disconnected: \(deviceId)")
        deviceTransportMap.removeValue(forKey: deviceId)
    }

    func handleReceive(_ envelope: MessageEnvelope, from deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Received envelope type=\(envelope.type.rawValue) from \(deviceId)")
        if let transport, deviceTransportMap[deviceId] == nil {
            deviceTransportMap[deviceId] = transport
        }

        switch envelope.type {
        case .pairingAcceptance:
            handlePairingAcceptance(envelope, from: deviceId)
        case .authorizationResponse:
            handleAuthorizationResponse(envelope, from: deviceId)
        default:
            log("transport", "Unhandled envelope type: \(envelope.type.rawValue)")
        }
    }

    func handleError(_ error: FaceBridgeError) {
        log("transport", "Transport error: \(error.localizedDescription)")
    }

    private func handlePairingAcceptance(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                let acceptance = try JSONDecoder().decode(PairingAcceptance.self, from: envelope.payload)
                log("pairing", "Received acceptance from \(acceptance.displayName) (\(acceptance.platform.rawValue))")

                let peerIdentity = try DeviceIdentity(
                    id: acceptance.deviceId,
                    displayName: acceptance.displayName,
                    platform: acceptance.platform,
                    publicKeyData: acceptance.publicKeyData
                )

                try await deviceManager.addPairedDevice(peerIdentity)
                let devices = await deviceManager.allPairedDevices()
                await MainActor.run {
                    self.pairedDevices = devices
                    self.pairingState = .completed
                }
                log("pairing", "Trust established with \(acceptance.displayName)")
            } catch {
                log("pairing", "Failed to process acceptance: \(error)")
                await MainActor.run { self.pairingState = .failed }
            }
        }
    }

    private func handleAuthorizationResponse(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                let response = try JSONDecoder().decode(AuthorizationResponse.self, from: envelope.payload)
                log("authorization", "Received response: \(response.decision.rawValue) from \(response.responderDeviceId)")

                guard let originalRequest = pendingRequests.removeValue(forKey: response.requestId) else {
                    log("authorization", "No pending request for response \(response.requestId)")
                    return
                }

                let pubKey = await deviceManager.publicKey(for: response.responderDeviceId)
                guard let trustedKey = pubKey else {
                    log("authorization", "No trusted key for responder \(response.responderDeviceId)")
                    await MainActor.run { self.lastAuthResult = "FAILED: Unknown responder" }
                    return
                }

                let valid = try await requester.verify(
                    response: response,
                    originalRequest: originalRequest,
                    trustedPublicKey: trustedKey
                )

                await MainActor.run {
                    self.lastAuthResult = valid ? "APPROVED (verified)" : "DENIED (signature valid)"
                }
                log("authorization", "Authorization result: \(valid ? "APPROVED" : "DENIED")")
            } catch {
                log("authorization", "Response verification failed: \(error)")
                await MainActor.run { self.lastAuthResult = "FAILED: \(error.localizedDescription)" }
            }
        }
    }

    func log(_ category: String, _ message: String) {
        let entry = LogEntry(category: category, message: message)
        DebugLogger.lifecycle.info("[\(category)] \(message)")
        Task { @MainActor in
            self.logMessages.append(entry)
            if self.logMessages.count > 200 {
                self.logMessages.removeFirst(50)
            }
        }
    }
}

final class MacTransportBridge: TransportDelegate, @unchecked Sendable {
    private weak var coordinator: MacCoordinator?

    init(coordinator: MacCoordinator) {
        self.coordinator = coordinator
    }

    func transport(_ transport: any Transport, didDiscover device: DiscoveredDevice) {
        Task { @MainActor in coordinator?.handleDiscovery(device) }
    }

    func transport(_ transport: any Transport, didConnect deviceId: UUID) {
        Task { @MainActor in coordinator?.handleConnect(deviceId, transport: transport) }
    }

    func transport(_ transport: any Transport, didDisconnect deviceId: UUID) {
        Task { @MainActor in coordinator?.handleDisconnect(deviceId) }
    }

    func transport(_ transport: any Transport, didReceive envelope: MessageEnvelope, from deviceId: UUID) {
        Task { @MainActor in coordinator?.handleReceive(envelope, from: deviceId, transport: transport) }
    }

    func transport(_ transport: any Transport, didFailWithError error: FaceBridgeError) {
        Task { @MainActor in coordinator?.handleError(error) }
    }
}
