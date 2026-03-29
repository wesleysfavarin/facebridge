#if os(macOS)
import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI
import FaceBridgeTransport

// MARK: - Root View

public struct MacMainView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var selectedSection: MacSection? = .dashboard

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(MacSection.allCases(developerMode: coordinator.developerModeEnabled), selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationTitle("FaceBridge")
        } detail: {
            switch selectedSection ?? .dashboard {
            case .dashboard:
                MacDashboardView()
            case .vault:
                MacSecureVaultView()
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
    case dashboard, vault, devices, pairing, settings, debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .vault: return "Secure Vault"
        case .devices: return "Trusted Devices"
        case .pairing: return "Pair New Device"
        case .settings: return "Settings"
        case .debug: return "Debug Console"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .vault: return "lock.shield"
        case .devices: return "iphone.and.arrow.forward"
        case .pairing: return "link.badge.plus"
        case .settings: return "gear"
        case .debug: return "ant"
        }
    }

    static func allCases(developerMode: Bool) -> [MacSection] {
        var sections: [MacSection] = [.dashboard, .vault, .devices, .pairing, .settings]
        if developerMode { sections.append(.debug) }
        return sections
    }
}

// MARK: - Dashboard

struct MacDashboardView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MacConnectionStatusCard(status: coordinator.connectionStatus)

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Quick Actions", systemImage: "bolt.fill")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Button {
                                coordinator.requestAuthorization(reason: "Authorize action on your Mac")
                            } label: {
                                Label("Request Authorization", systemImage: "faceid")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(coordinator.pairedDevices.isEmpty)

                            Button {
                                coordinator.requestVaultUnlock()
                            } label: {
                                Label("Unlock Secure Vault", systemImage: "lock.open")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .disabled(coordinator.pairedDevices.isEmpty)
                        }

                        if coordinator.pairedDevices.isEmpty {
                            Label("Pair your iPhone first to use authorization", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                if coordinator.authPhase != .idle {
                    MacAuthStatusCard(phase: coordinator.authPhase)
                }

                if coordinator.isVaultUnlocked, let unlockedAt = coordinator.vaultUnlockedAt {
                    GroupBox {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.open.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Secure Vault Unlocked")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Text("Unlocked \(unlockedAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Lock") { coordinator.lockVault() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(4)
                    }
                }

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
                                        Circle().fill(.green).frame(width: 8, height: 8)
                                    } else {
                                        Circle().fill(.orange).frame(width: 8, height: 8)
                                    }
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

// MARK: - Auth Status Card

struct MacAuthStatusCard: View {
    let phase: MacCoordinator.AuthorizationPhase

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                if phase == .sending || phase == .waitingForApproval {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Authorization")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phase.rawValue)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }
                Spacer()
            }
            .padding(4)
        }
    }

    private var statusColor: Color {
        switch phase {
        case .idle: return .secondary
        case .sending, .waitingForApproval: return .blue
        case .approved: return .green
        case .denied: return .orange
        case .expired, .failed: return .red
        }
    }

    private var statusIcon: String {
        switch phase {
        case .idle: return "minus.circle"
        case .sending: return "arrow.up.circle"
        case .waitingForApproval: return "iphone"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Secure Vault (Protected Feature)

struct MacSecureVaultView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.isVaultUnlocked {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Secure Vault")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let t = coordinator.vaultUnlockedAt {
                                    Text("Unlocked \(t, style: .relative) ago via Face ID")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Lock Vault") { coordinator.lockVault() }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }

                        Divider()

                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Protected Credentials", systemImage: "key.fill")
                                    .font(.headline)

                                VaultCredentialRow(service: "Production Database", username: "admin@facebridge.io", value: "fb-prod-2026-x9k4m")
                                VaultCredentialRow(service: "API Gateway", username: "service-account", value: "sk_live_Rk8f2nVpQm7xJz3L")
                                VaultCredentialRow(service: "Deployment Key", username: "ci/cd-pipeline", value: "deploy-7f3a9c2b-e1d4-48f6")
                            }
                            .padding(4)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Secure Notes", systemImage: "doc.text.fill")
                                    .font(.headline)

                                Text("Recovery Phrase")
                                    .fontWeight(.medium)
                                Text("apple banana cherry delta echo foxtrot golf hotel india juliet kilo lima")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text("Server Root Password")
                                    .fontWeight(.medium)
                                Text("Xk9#mP2$vR7!nL4@qW6")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(4)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Protected Actions", systemImage: "terminal.fill")
                                    .font(.headline)

                                Button {
                                    coordinator.log("vault", "Simulated: Deploy to production executed")
                                } label: {
                                    Label("Deploy to Production", systemImage: "arrow.up.to.line")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)

                                Button {
                                    coordinator.log("vault", "Simulated: Database migration executed")
                                } label: {
                                    Label("Run Database Migration", systemImage: "cylinder.split.1x2")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding(4)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)

                    Text("Secure Vault")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("This vault contains protected credentials, secure notes, and sensitive actions. Unlock it by authorizing with Face ID on your paired iPhone.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)

                    if coordinator.authPhase == .waitingForApproval {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for iPhone approval…")
                                .foregroundStyle(.blue)
                        }
                    }

                    Button {
                        coordinator.requestVaultUnlock()
                    } label: {
                        Label("Unlock with Face ID", systemImage: "faceid")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(coordinator.pairedDevices.isEmpty || coordinator.authPhase == .waitingForApproval)

                    if coordinator.pairedDevices.isEmpty {
                        Label("Pair your iPhone first", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .navigationTitle("Secure Vault")
    }
}

struct VaultCredentialRow: View {
    let service: String
    let username: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(service).fontWeight(.medium)
            HStack {
                Text(username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.blue)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        Divider()
    }
}

// MARK: - Connection Status Card

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

// MARK: - Settings

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
                    Text("0.2.0-alpha").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

// MARK: - Debug Console

struct MacDebugView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var authReason = "Test authorization request"

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
                                Spacer()
                                Button("Send Auth") {
                                    coordinator.sendAuthorizationRequest(to: device.id, reason: authReason)
                                }.font(.caption).buttonStyle(.bordered)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                GroupBox("Authorization") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Reason", text: $authReason).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Request Auth") {
                                coordinator.requestAuthorization(reason: authReason)
                            }.buttonStyle(.borderedProminent)
                            Button("Unlock Vault") {
                                coordinator.requestVaultUnlock()
                            }.buttonStyle(.bordered)
                        }
                        Text("Phase: \(coordinator.authPhase.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                        if !coordinator.lastAuthResult.isEmpty {
                            Label(coordinator.lastAuthResult,
                                  systemImage: coordinator.lastAuthResult == "Approved" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(coordinator.lastAuthResult == "Approved" ? .green : .red)
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
        case "vault": return .mint
        case "lifecycle": return .gray
        default: return .primary
        }
    }
}
#endif
