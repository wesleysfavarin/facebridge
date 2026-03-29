#if os(macOS)
import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI
import FaceBridgeTransport

public struct MacMainView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var selectedSection: MacSection = .debug

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationTitle("FaceBridge")
        } detail: {
            switch selectedSection {
            case .debug:
                MacDebugView()
            case .devices:
                MacDevicesView()
            case .pairing:
                MacPairingView()
            case .auditLog:
                MacAuditLogView()
            case .settings:
                MacSettingsView()
            }
        }
    }
}

enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case debug
    case devices
    case pairing
    case auditLog
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debug: return "Debug Console"
        case .devices: return "Paired Devices"
        case .pairing: return "Pair New Device"
        case .auditLog: return "Audit Log"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .devices: return "iphone.and.arrow.forward"
        case .pairing: return "link.badge.plus"
        case .auditLog: return "list.clipboard"
        case .settings: return "gear"
        }
    }
}

struct MacDebugView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var authReason = "Unlock screen saver"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Transport Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Discovered Devices: \(coordinator.discoveredDevices.count)", systemImage: "antenna.radiowaves.left.and.right")
                        Label("Paired Devices: \(coordinator.pairedDevices.count)", systemImage: "checkmark.shield")

                        if !coordinator.discoveredDevices.isEmpty {
                            ForEach(coordinator.discoveredDevices, id: \.id) { device in
                                HStack {
                                    Image(systemName: device.transportType == .ble ? "wave.3.right" : "wifi")
                                    Text(device.displayName)
                                        .font(.caption)
                                    Text("RSSI: \(device.rssi)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Send Auth") {
                                        coordinator.sendAuthorizationRequest(to: device.id, reason: authReason)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                GroupBox("Pairing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("State: \(coordinator.pairingState.rawValue)")
                                .font(.caption)
                            Spacer()
                            Button("Generate Pairing Code") {
                                coordinator.generatePairingCode()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if !coordinator.pairingCode.isEmpty {
                            Text(coordinator.pairingCode)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                                .tracking(6)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                }

                GroupBox("Authorization") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Reason", text: $authReason)
                            .textFieldStyle(.roundedBorder)

                        if !coordinator.lastAuthResult.isEmpty {
                            Label(coordinator.lastAuthResult, systemImage: coordinator.lastAuthResult.contains("APPROVED") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(coordinator.lastAuthResult.contains("APPROVED") ? .green : .red)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Console Log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(coordinator.logMessages) { entry in
                                    HStack(alignment: .top, spacing: 8) {
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
                        .frame(height: 250)
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

struct MacDevicesView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        TrustedDevicesListView(devices: coordinator.pairedDevices) { _ in }
            .navigationTitle("Paired Devices")
    }
}

struct MacPairingView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        VStack {
            PairingCodeView(code: coordinator.pairingCode)

            Button("Generate New Code") {
                coordinator.generatePairingCode()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Pair New Device")
    }
}

struct MacAuditLogView: View {
    @State private var entries: [AuditEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "list.clipboard",
                    description: Text("Authorization events will appear here.")
                )
            } else {
                Table(entries) {
                    TableColumn("Time") { entry in
                        Text(entry.timestamp, style: .time)
                    }
                    TableColumn("Event") { entry in
                        Text(entry.event.rawValue)
                    }
                    TableColumn("Details") { entry in
                        Text(entry.details ?? "—")
                    }
                }
            }
        }
        .navigationTitle("Audit Log")
    }
}

struct MacSettingsView: View {
    @State private var requireProximity = false
    @State private var sessionTimeout: Double = 30
    @State private var minimumRSSI: Double = -70

    var body: some View {
        PolicySettingsView(
            requireProximity: $requireProximity,
            sessionTimeout: $sessionTimeout,
            minimumRSSI: $minimumRSSI
        )
        .navigationTitle("Settings")
    }
}
#endif
