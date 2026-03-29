import Foundation
import SwiftUI
import os
import LocalAuthentication
import UserNotifications
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol
import FaceBridgeTransport

@MainActor
public final class iOSCoordinator: ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    @Published public var discoveredDevices: [DiscoveredDevice] = []
    @Published public var trustedDevices: [DeviceIdentity] = []
    @Published public var mergedNearbyDevices: [NearbyDevice] = []

    @Published public var connectionStatus: ConnectionStatus = .searching
    @Published public var pairingState: PairingPhase = .idle
    @Published public var pendingAuthRequest: AuthorizationRequest?
    @Published public var pendingAuthDeviceId: UUID?
    @Published public var lastAuthResult: String = ""
    @Published public var lastAuthTimestamp: Date?
    @Published public var logMessages: [LogEntry] = []

    @Published public var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "fb_onboarding_done") }
    }
    @Published public var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: "fb_developer_mode") }
    }

    // MARK: - Types

    public enum ConnectionStatus: String {
        case searching = "Searching…"
        case deviceNearby = "Device nearby"
        case paired = "Paired"
        case connectedSecurely = "Connected securely"
    }

    public enum PairingPhase: String {
        case idle, confirmingDevice, sendingAcceptance, completed, failed
    }

    public struct NearbyDevice: Identifiable, Hashable {
        public let id: UUID
        public let friendlyName: String
        public let platform: DevicePlatform?
        public let isTrusted: Bool
        public let transportIds: Set<UUID>
        public var isConnected: Bool

        public static func == (lhs: NearbyDevice, rhs: NearbyDevice) -> Bool {
            lhs.id == rhs.id
        }
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp = Date()
        public let category: String
        public let message: String
    }

    // MARK: - Private

    private let localDeviceId = UUID()
    private let keyTag = "com.facebridge.ios.device-key"

    private let lanTransport: LocalNetworkTransport
    private let bleTransport: BLETransport
    private let connectionManager = ConnectionManager()
    private let trustManager: DeviceTrustManager
    private let keyManager: SoftwareKeyManager
    private let responder: AuthorizationResponder
    private let auditLogger = AuditLogger()
    private let encoder = MessageEncoder()
    private var transportBridge: iOSTransportBridge?

    public var localPublicKeyData: Data?
    private var deviceTransportMap: [UUID: any Transport] = [:]

    // MARK: - Init

    public init() {
        let store = KeychainStore()
        let km = SoftwareKeyManager(store: store)
        self.keyManager = km
        let tm = DeviceTrustManager(keychainStore: store, auditLogger: AuditLogger())
        self.trustManager = tm
        self.responder = AuthorizationResponder(localDeviceId: UUID(), keyManager: km, trustManager: tm)
        self.lanTransport = LocalNetworkTransport(allowInsecure: true)
        self.bleTransport = BLETransport()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "fb_onboarding_done")
        self.developerModeEnabled = UserDefaults.standard.bool(forKey: "fb_developer_mode")
    }

    // MARK: - Lifecycle

    public func start() {
        log("lifecycle", "iOS coordinator starting")
        do {
            localPublicKeyData = try keyManager.generateKeyPair(tag: keyTag)
            log("crypto", "Device key pair generated")
        } catch {
            log("crypto", "Key generation: using existing key")
            localPublicKeyData = try? keyManager.publicKeyData(for: keyTag)
        }

        let bridge = iOSTransportBridge(coordinator: self)
        self.transportBridge = bridge
        lanTransport.delegate = bridge
        bleTransport.delegate = bridge

        Task { await connectionManager.register(lanTransport) }
        Task { await connectionManager.register(bleTransport) }

        lanTransport.startDiscovery()
        do { try lanTransport.startListening() } catch { log("transport", "LAN listener failed: \(error)") }
        bleTransport.startDiscovery()
        bleTransport.startAdvertising(displayName: UIDevice.current.name)

        Task {
            try? await trustManager.loadTrustedDevices()
            let devices = await trustManager.allTrustedDevices()
            await MainActor.run { self.trustedDevices = devices }
            log("lifecycle", "Loaded \(devices.count) trusted device(s)")
            if !devices.isEmpty { connectionStatus = .paired }
        }

        requestNotificationPermission()
        log("lifecycle", "iOS coordinator ready")
    }

    // MARK: - Smart Pairing (no numeric code)

    public func confirmPairing(with device: NearbyDevice) {
        pairingState = .confirmingDevice
        guard let transportId = device.transportIds.first else {
            pairingState = .failed
            log("pairing", "[ERROR] No transport ID for device")
            return
        }
        pairingState = .sendingAcceptance
        Task {
            do {
                guard let pubKey = localPublicKeyData else { throw FaceBridgeError.keyGenerationFailed }
                log("pairing", "[stage_1] Connecting to \(device.friendlyName)…")
                try await ensureConnected(to: transportId)
                log("pairing", "[stage_1] Connected — sending PairingAcceptance")

                let signable = Data(localDeviceId.uuidString.utf8)
                    + Data(UIDevice.current.name.utf8)
                    + Data(DevicePlatform.iOS.rawValue.utf8)
                    + pubKey
                    + Data(transportId.uuidString.utf8)
                let signature = try keyManager.sign(data: signable, keyTag: keyTag)

                let acceptance = PairingAcceptance(
                    deviceId: localDeviceId,
                    displayName: UIDevice.current.name,
                    platform: .iOS,
                    publicKeyData: pubKey,
                    invitationDeviceId: transportId,
                    signature: signature
                )
                let envelope = try encoder.encode(acceptance, type: .pairingAcceptance, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: transportId)
                log("pairing", "[stage_2] PairingAcceptance sent — waiting for PairingConfirmation from Mac…")
            } catch {
                await MainActor.run { self.pairingState = .failed }
                log("pairing", "[ERROR] Pairing failed: \(error)")
            }
        }
    }

    public func submitPairingCode(_ code: String, toDeviceId deviceId: UUID) {
        pairingState = .sendingAcceptance
        Task {
            do {
                guard let pubKey = localPublicKeyData else { throw FaceBridgeError.keyGenerationFailed }
                log("pairing", "[stage_1] Connecting to \(deviceId)…")
                try await ensureConnected(to: deviceId)
                let signable = Data(localDeviceId.uuidString.utf8)
                    + Data(UIDevice.current.name.utf8)
                    + Data(DevicePlatform.iOS.rawValue.utf8)
                    + pubKey + Data(deviceId.uuidString.utf8)
                let signature = try keyManager.sign(data: signable, keyTag: keyTag)
                let acceptance = PairingAcceptance(
                    deviceId: localDeviceId, displayName: UIDevice.current.name,
                    platform: .iOS, publicKeyData: pubKey,
                    invitationDeviceId: deviceId, signature: signature
                )
                let envelope = try encoder.encode(acceptance, type: .pairingAcceptance, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)
                log("pairing", "[stage_2] Acceptance sent — waiting for confirmation…")
            } catch {
                await MainActor.run { self.pairingState = .failed }
                log("pairing", "[ERROR] Failed to send acceptance: \(error)")
            }
        }
    }

    // MARK: - Authorization with Face ID

    public func approveAuth() {
        guard let request = pendingAuthRequest, let deviceId = pendingAuthDeviceId else { return }
        Task {
            do {
                log("authorization", "Requesting Face ID…")
                try await authenticateWithBiometrics(reason: request.reason)
                log("authorization", "Face ID succeeded")

                try await ensureConnected(to: deviceId)
                let response = try await responder.respond(to: request, keyTag: keyTag)
                let envelope = try encoder.encode(response, type: .authorizationResponse, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)

                await MainActor.run {
                    self.lastAuthResult = "Approved"
                    self.lastAuthTimestamp = Date()
                    self.pendingAuthRequest = nil
                    self.pendingAuthDeviceId = nil
                }
                log("authorization", "Response sent: \(response.decision.rawValue)")
            } catch let error as LAError where error.code == .userCancel || error.code == .userFallback {
                log("authorization", "Face ID cancelled")
                await MainActor.run {
                    self.lastAuthResult = "Cancelled"
                    self.pendingAuthRequest = nil
                    self.pendingAuthDeviceId = nil
                }
            } catch let error as LAError {
                log("authorization", "Face ID failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.lastAuthResult = "Face ID failed"
                    self.pendingAuthRequest = nil
                    self.pendingAuthDeviceId = nil
                }
            } catch {
                log("authorization", "Failed: \(error)")
                await MainActor.run {
                    self.lastAuthResult = "Error: \(error.localizedDescription)"
                    self.pendingAuthRequest = nil
                }
            }
        }
    }

    public func denyAuth() {
        pendingAuthRequest = nil
        pendingAuthDeviceId = nil
        lastAuthResult = "Denied"
        log("authorization", "Denied by user")
    }

    private func authenticateWithBiometrics(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? LAError(.biometryNotAvailable) as NSError
        }
        let sanitized = String(reason.prefix(200))
        try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: sanitized.isEmpty ? "Authorize request from your Mac" : sanitized
        )
    }

    // MARK: - Device Deduplication

    public func rebuildMergedDevices() {
        var merged: [String: NearbyDevice] = [:]

        for device in discoveredDevices {
            let key = friendlyName(for: device.displayName)
            if var existing = merged[key] {
                var ids = existing.transportIds
                ids.insert(device.id)
                existing = NearbyDevice(
                    id: existing.id, friendlyName: existing.friendlyName,
                    platform: existing.platform, isTrusted: existing.isTrusted,
                    transportIds: ids, isConnected: existing.isConnected || deviceTransportMap[device.id] != nil
                )
                merged[key] = existing
            } else {
                let isTrusted = trustedDevices.contains { $0.displayName == key || friendlyName(for: $0.displayName) == key }
                merged[key] = NearbyDevice(
                    id: device.id, friendlyName: key,
                    platform: isTrusted ? trustedDevices.first(where: { friendlyName(for: $0.displayName) == key })?.platform : nil,
                    isTrusted: isTrusted, transportIds: [device.id],
                    isConnected: deviceTransportMap[device.id] != nil
                )
            }
        }

        mergedNearbyDevices = Array(merged.values).sorted { ($0.isTrusted ? 0 : 1) < ($1.isTrusted ? 0 : 1) }
        updateConnectionStatus()
    }

    private func friendlyName(for rawName: String) -> String {
        var name = rawName
        name = name.replacingOccurrences(of: "\\032", with: " ")
        if let range = name.range(of: "._facebridge._tcp.local.") { name = String(name[..<range.lowerBound]) }
        if let range = name.range(of: "._tcp.local.") { name = String(name[..<range.lowerBound]) }
        if let range = name.range(of: ".local.") { name = String(name[..<range.lowerBound]) }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown Device" : name
    }

    private func updateConnectionStatus() {
        if mergedNearbyDevices.contains(where: { $0.isTrusted && $0.isConnected }) {
            connectionStatus = .connectedSecurely
        } else if !trustedDevices.isEmpty && mergedNearbyDevices.contains(where: { $0.isTrusted }) {
            connectionStatus = .connectedSecurely
        } else if !trustedDevices.isEmpty {
            connectionStatus = .paired
        } else if !mergedNearbyDevices.isEmpty {
            connectionStatus = .deviceNearby
        } else {
            connectionStatus = .searching
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Transport Helpers

    private func ensureConnected(to deviceId: UUID) async throws {
        if deviceTransportMap[deviceId] != nil { return }
        try await lanTransport.connect(to: deviceId)
        deviceTransportMap[deviceId] = lanTransport
        log("transport", "Connected to \(deviceId)")
    }

    private func sendToDevice(_ envelope: MessageEnvelope, deviceId: UUID) async throws {
        if let transport = deviceTransportMap[deviceId] {
            try await transport.send(envelope, to: deviceId)
        } else {
            try await lanTransport.send(envelope, to: deviceId)
        }
    }

    // MARK: - Transport Delegate Handlers

    func handleDiscovery(_ device: DiscoveredDevice) {
        let localName = UIDevice.current.name.lowercased()
        let deviceFriendly = friendlyName(for: device.displayName).lowercased()
        if deviceFriendly == localName || device.displayName.lowercased().contains(localName) {
            log("transport", "Filtered self-discovery: \(device.displayName)")
            return
        }
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
                rebuildMergedDevices()
            }
        }
        log("transport", "Discovered: \(device.displayName)")
    }

    func handleConnect(_ deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Connected: \(deviceId)")
        if let transport { deviceTransportMap[deviceId] = transport }
        bleTransport.authorizePeer(deviceId)
        rebuildMergedDevices()
    }

    func handleDisconnect(_ deviceId: UUID) {
        log("transport", "Disconnected: \(deviceId)")
        deviceTransportMap.removeValue(forKey: deviceId)
        rebuildMergedDevices()
    }

    func handleReceive(_ envelope: MessageEnvelope, from deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Received type=\(envelope.type.rawValue)")
        if let transport, deviceTransportMap[deviceId] == nil {
            deviceTransportMap[deviceId] = transport
        }
        switch envelope.type {
        case .authorizationRequest:
            handleIncomingAuthRequest(envelope, from: deviceId)
        case .pairingConfirmation:
            handlePairingConfirmation(envelope, from: deviceId)
        case .pairingInvitation:
            log("pairing", "Invitation from \(deviceId)")
        default:
            log("transport", "Unhandled: \(envelope.type.rawValue)")
        }
    }

    func handleError(_ error: FaceBridgeError) {
        log("transport", "Error: \(error.localizedDescription)")
    }

    private func handlePairingConfirmation(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                let confirmation = try JSONDecoder().decode(PairingConfirmation.self, from: envelope.payload)
                log("pairing", "[stage_3] Received PairingConfirmation from \(confirmation.displayName)")

                guard confirmation.confirmed else {
                    log("pairing", "[stage_3] Mac rejected pairing")
                    await MainActor.run { self.pairingState = .failed }
                    return
                }

                log("pairing", "[stage_4] Validating Mac public key…")
                let macIdentity = try DeviceIdentity(
                    id: confirmation.deviceId,
                    displayName: confirmation.displayName,
                    platform: confirmation.platform,
                    publicKeyData: confirmation.publicKeyData
                )
                log("pairing", "[stage_4] Mac identity valid — storing trust…")

                try await trustManager.addTrustedDevice(macIdentity)
                let devices = await trustManager.allTrustedDevices()
                await MainActor.run {
                    self.trustedDevices = devices
                    self.pairingState = .completed
                    self.connectionStatus = .connectedSecurely
                }
                rebuildMergedDevices()
                log("pairing", "[stage_5] Pairing COMPLETE — \(confirmation.displayName) is now trusted (\(devices.count) total)")
            } catch {
                log("pairing", "[ERROR] Failed to process PairingConfirmation: \(error)")
                await MainActor.run { self.pairingState = .failed }
            }
        }
    }

    private func handleIncomingAuthRequest(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                let request = try JSONDecoder().decode(AuthorizationRequest.self, from: envelope.payload)
                log("authorization", "Auth request: \(request.reason)")
                sendLocalNotification(
                    title: "Authorization Request",
                    body: "Your Mac requests authorization"
                )
                await MainActor.run {
                    self.pendingAuthRequest = request
                    self.pendingAuthDeviceId = deviceId
                }
            } catch {
                log("authorization", "Decode failed: \(error)")
            }
        }
    }

    // MARK: - Logging

    func log(_ category: String, _ message: String) {
        let entry = LogEntry(category: category, message: message)
        DebugLogger.lifecycle.info("[\(category)] \(message)")
        Task { @MainActor in
            self.logMessages.append(entry)
            if self.logMessages.count > 200 { self.logMessages.removeFirst(50) }
        }
    }
}

// MARK: - Transport Bridge

final class iOSTransportBridge: TransportDelegate, @unchecked Sendable {
    private weak var coordinator: iOSCoordinator?
    init(coordinator: iOSCoordinator) { self.coordinator = coordinator }

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
