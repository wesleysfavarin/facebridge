#if os(macOS)
import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI
import FaceBridgeTransport

// MARK: - Root View

public struct MacMainView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var selectedSection: MacSection = .dashboard

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(MacSection.allCases(developerMode: coordinator.developerModeEnabled), selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationTitle("FaceBridge")
        } detail: {
            switch selectedSection {
            case .dashboard:
                MacDashboardView()
            case .devices:
                MacDevicesView()
            case .pairing:
                MacPairingView()
            case .settings:
                MacSettingsView()
            case .debug:
                MacDebugView()
            }
        }
    }
}

// MARK: - Sections

enum MacSection: String, Identifiable, Hashable {
    case dashboard, devices, pairing, settings, debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .devices: return "Trusted Devices"
        case .pairing: return "Pair New Device"
        case .settings: return "Settings"
        case .debug: return "Debug Console"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .devices: return "iphone.and.arrow.forward"
        case .pairing: return "link.badge.plus"
        case .settings: return "gear"
        case .debug: return "ant"
        }
    }

    static func allCases(developerMode: Bool) -> [MacSection] {
        var sections: [MacSection] = [.dashboard, .devices, .pairing, .settings]
        if developerMode { sections.append(.debug) }
        return sections
    }
}

// MARK: - Dashboard (Phase 6)

struct MacDashboardView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MacConnectionStatusCard(status: coordinator.connectionStatus)

                if !coordinator.pairedDevices.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Trusted Devices", systemImage: "checkmark.shield")
                                .font(.headline)

                            ForEach(coordinator.pairedDevices, id: \.id) { device in
                                HStack(spacing: 12) {
                                    Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.displayName)
                                            .fontWeight(.medium)
                                        Text(device.platform.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()

                                    let nearby = coordinator.mergedNearbyDevices.first(where: {
                                        coordinator.friendlyNamePublic(for: device.displayName) == $0.friendlyName
                                    })
                                    if nearby != nil {
                                        Button("Send Auth Request") {
                                            if let tid = nearby?.transportIds.first {
                                                coordinator.sendAuthorizationRequest(to: tid, reason: "Unlock Mac")
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }

                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(4)
                    }
                }

                if let timestamp = coordinator.lastAuthTimestamp {
                    GroupBox {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Authorization")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(timestamp, style: .relative)
                                    .font(.body)
                                + Text(" ago")
                            }
                            Spacer()
                            Text(coordinator.lastAuthResult)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(coordinator.lastAuthResult == "Approved" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundStyle(coordinator.lastAuthResult == "Approved" ? .green : .orange)
                                .clipShape(Capsule())
                        }
                        .padding(4)
                    }
                }

                if !coordinator.mergedNearbyDevices.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Nearby Devices", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.headline)
                            ForEach(coordinator.mergedNearbyDevices) { device in
                                HStack(spacing: 12) {
                                    Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 32)
                                    Text(device.friendlyName)
                                    Spacer()
                                    if device.isTrusted {
                                        Text("Trusted")
                                            .font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundStyle(.green)
                                            .clipShape(Capsule())
                                    }
                                    if device.isConnected {
                                        Circle().fill(.green).frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Connection Status Card (Phase 9)

struct MacConnectionStatusCard: View {
    let status: MacCoordinator.ConnectionStatus

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("FaceBridge Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(status.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.5), radius: 4)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch status {
        case .searching: return .orange
        case .deviceNearby: return .blue
        case .paired, .connectedSecurely: return .green
        }
    }

    private var statusIcon: String {
        switch status {
        case .searching: return "magnifyingglass"
        case .deviceNearby: return "antenna.radiowaves.left.and.right"
        case .paired: return "link"
        case .connectedSecurely: return "lock.shield.fill"
        }
    }
}

// MARK: - Devices View

struct MacDevicesView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        Group {
            if coordinator.pairedDevices.isEmpty {
                ContentUnavailableView(
                    "No Trusted Devices",
                    systemImage: "iphone.slash",
                    description: Text("Pair a device to get started.")
                )
            } else {
                List {
                    ForEach(coordinator.pairedDevices, id: \.id) { device in
                        HStack(spacing: 12) {
                            Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                                .font(.title3).foregroundStyle(.blue).frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.displayName).fontWeight(.medium)
                                Text("Paired \(device.createdAt, style: .relative) ago")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Trusted Devices")
    }
}

// MARK: - Pairing View

struct MacPairingView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "link.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Pair a New Device")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Generate a pairing code and enter it on your iPhone, or use one-tap pairing from the iPhone app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !coordinator.pairingCode.isEmpty {
                Text(coordinator.pairingCode)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(8)
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("State: \(coordinator.pairingState.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Generate Pairing Code") {
                coordinator.generatePairingCode()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
        .navigationTitle("Pair New Device")
    }
}

// MARK: - Settings (Phase 10)

struct MacSettingsView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(coordinator.connectionStatus.rawValue)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Developer") {
                Toggle("Developer Mode", isOn: $coordinator.developerModeEnabled)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0-alpha").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

// MARK: - Debug Console (Developer Mode)

struct MacDebugView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var authReason = "Unlock screen saver"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Transport Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Discovered: \(coordinator.discoveredDevices.count)", systemImage: "antenna.radiowaves.left.and.right")
                        Label("Paired: \(coordinator.pairedDevices.count)", systemImage: "checkmark.shield")

                        ForEach(coordinator.discoveredDevices, id: \.id) { device in
                            HStack {
                                Image(systemName: device.transportType == .ble ? "wave.3.right" : "wifi")
                                Text(device.displayName).font(.caption)
                                Text("RSSI: \(device.rssi)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("Send Auth") {
                                    coordinator.sendAuthorizationRequest(to: device.id, reason: authReason)
                                }.font(.caption).buttonStyle(.bordered)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                GroupBox("Pairing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("State: \(coordinator.pairingState.rawValue)").font(.caption)
                            Spacer()
                            Button("Generate Code") { coordinator.generatePairingCode() }
                                .buttonStyle(.borderedProminent)
                        }
                        if !coordinator.pairingCode.isEmpty {
                            Text(coordinator.pairingCode)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold).tracking(6)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(8)
                }

                GroupBox("Authorization") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Reason", text: $authReason).textFieldStyle(.roundedBorder)
                        if !coordinator.lastAuthResult.isEmpty {
                            Label(coordinator.lastAuthResult,
                                  systemImage: coordinator.lastAuthResult.contains("Approved") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(coordinator.lastAuthResult.contains("Approved") ? .green : .red)
                        }
                    }.padding(8)
                }

                GroupBox("Console Log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(coordinator.logMessages) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(entry.timestamp, style: .time)
                                            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                        Text("[\(entry.category)]")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(colorForCategory(entry.category))
                                        Text(entry.message)
                                            .font(.system(.caption2, design: .monospaced))
                                    }.id(entry.id)
                                }
                            }
                        }
                        .frame(height: 250)
                        .onChange(of: coordinator.logMessages.count) { _, _ in
                            if let last = coordinator.logMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }.padding(8)
                }
            }.padding()
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
#endif
