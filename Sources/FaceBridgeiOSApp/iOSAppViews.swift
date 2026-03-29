import SwiftUI
import FaceBridgeCore
import FaceBridgeProtocol
import FaceBridgeSharedUI
import FaceBridgeTransport

public struct iOSMainView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            iOSDebugView()
                .tabItem {
                    Label("Debug", systemImage: "ant")
                }
                .tag(0)

            iOSDevicesView()
                .tabItem {
                    Label("Devices", systemImage: "laptopcomputer.and.iphone")
                }
                .tag(1)

            iOSPairingScannerView()
                .tabItem {
                    Label("Pair", systemImage: "qrcode.viewfinder")
                }
                .tag(2)

            iOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .sheet(item: Binding(
            get: { coordinator.pendingAuthRequest },
            set: { coordinator.pendingAuthRequest = $0 }
        )) { request in
            ApprovalPromptView(
                request: request,
                deviceName: "Paired Mac",
                isTrustedDevice: true,
                onApprove: { coordinator.approveAuth() },
                onDeny: { coordinator.denyAuth() }
            )
            .presentationDetents([.medium])
            .onAppear {
                coordinator.approveAuth()
            }
        }
    }
}

extension AuthorizationRequest: Identifiable {}

struct iOSDebugView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var pairingCode = ""
    @State private var selectedDeviceId: UUID?
    @FocusState private var isPairingFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Transport Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Discovered: \(coordinator.discoveredDevices.count)", systemImage: "antenna.radiowaves.left.and.right")
                            Label("Trusted: \(coordinator.trustedDevices.count)", systemImage: "checkmark.shield")

                            ForEach(coordinator.discoveredDevices, id: \.id) { device in
                                HStack {
                                    Image(systemName: device.transportType == .ble ? "wave.3.right" : "wifi")
                                    VStack(alignment: .leading) {
                                        Text(device.displayName)
                                            .font(.caption)
                                        Text(device.id.uuidString.prefix(8))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Select") {
                                        selectedDeviceId = device.id
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(selectedDeviceId == device.id ? .green : .blue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }

                    GroupBox("Pairing") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("State: \(coordinator.pairingState.rawValue)")
                                .font(.caption)

                            HStack {
                                TextField("Enter pairing code", text: $pairingCode)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isPairingFieldFocused)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif

                                Button("Pair") {
                                    guard let deviceId = selectedDeviceId else { return }
                                    isPairingFieldFocused = false
                                    coordinator.submitPairingCode(pairingCode, toDeviceId: deviceId)
                                    pairingCode = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(pairingCode.count != 6 || selectedDeviceId == nil)
                            }

                            if selectedDeviceId != nil {
                                Text("Selected device: \(selectedDeviceId!.uuidString.prefix(8))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                    }

                    if coordinator.pendingAuthRequest != nil {
                        GroupBox("Pending Authorization") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Request from: \(coordinator.pendingAuthRequest!.senderDeviceId.uuidString.prefix(8))")
                                    .font(.caption)
                                Text("Reason: \(coordinator.pendingAuthRequest!.reason)")
                                    .font(.caption)

                                HStack {
                                    Button("Deny") { coordinator.denyAuth() }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    Button("Approve (FaceID)") { coordinator.approveAuth() }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(8)
                        }
                    }

                    if !coordinator.lastAuthResult.isEmpty {
                        GroupBox("Last Result") {
                            Text(coordinator.lastAuthResult)
                                .font(.caption)
                                .padding(8)
                        }
                    }

                    GroupBox("Console Log") {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(coordinator.logMessages) { entry in
                                        HStack(alignment: .top, spacing: 4) {
                                            Text(entry.timestamp, style: .time)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                            Text("[\(entry.category)]")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(colorForCategory(entry.category))
                                            Text(entry.message)
                                                .font(.system(.caption2, design: .monospaced))
                                        }
                                        .id(entry.id)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .onChange(of: coordinator.logMessages.count) { _, _ in
                                if let last = coordinator.logMessages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Console")
        }
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "transport": return .blue
        case "pairing": return .orange
        case "authorization": return .green
        case "crypto": return .purple
        case "lifecycle": return .gray
        default: return .primary
        }
    }
}

struct iOSDevicesView: View {
    @EnvironmentObject var coordinator: iOSCoordinator

    var body: some View {
        NavigationStack {
            TrustedDevicesListView(devices: coordinator.trustedDevices) { _ in }
                .navigationTitle("Trusted Devices")
        }
    }
}

struct iOSPairingScannerView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PairingCodeView(code: "", isScanning: coordinator.discoveredDevices.isEmpty)

                Text("Discovered \(coordinator.discoveredDevices.count) device(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Pair Device")
        }
    }
}

struct iOSSettingsView: View {
    @State private var requireProximity = false
    @State private var sessionTimeout: Double = 30
    @State private var minimumRSSI: Double = -70

    var body: some View {
        NavigationStack {
            PolicySettingsView(
                requireProximity: $requireProximity,
                sessionTimeout: $sessionTimeout,
                minimumRSSI: $minimumRSSI
            )
            .navigationTitle("Settings")
        }
    }
}
