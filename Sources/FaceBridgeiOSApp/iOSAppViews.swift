import SwiftUI
import FaceBridgeCore
import FaceBridgeProtocol
import FaceBridgeSharedUI
import FaceBridgeTransport

// MARK: - Root View

public struct iOSMainView: View {
    @EnvironmentObject var coordinator: iOSCoordinator

    public init() {}

    public var body: some View {
        Group {
            if !coordinator.hasCompletedOnboarding {
                OnboardingView()
            } else {
                iOSHomeTabView()
            }
        }
        .sheet(item: Binding(
            get: { coordinator.pendingAuthRequest },
            set: { coordinator.pendingAuthRequest = $0 }
        )) { _ in
            FaceIDAuthSheet()
                .presentationDetents([.medium])
                .interactiveDismissDisabled()
        }
    }
}

extension AuthorizationRequest: @retroactive Identifiable {}

// MARK: - Onboarding (Phase 8)

struct OnboardingView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "faceid",
                    title: "Unlock your Mac\nwith Face ID",
                    subtitle: "Use your iPhone to authorize requests on your Mac — no Touch ID needed."
                ).tag(0)

                OnboardingPage(
                    icon: "lock.shield",
                    title: "Secure & Private",
                    subtitle: "FaceBridge uses encrypted device pairing and cryptographic authorization. Your biometric data never leaves your iPhone."
                ).tag(1)

                OnboardingPage(
                    icon: "link",
                    title: "Pair your devices\nto begin",
                    subtitle: "Connect your iPhone and Mac over your local network. It only takes a moment."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button {
                if currentPage < 2 {
                    currentPage += 1
                } else {
                    coordinator.hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < 2 ? "Next" : "Start Pairing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: true)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Home Tab View

struct iOSHomeTabView: View {
    @EnvironmentObject var coordinator: iOSCoordinator

    var body: some View {
        TabView {
            iOSDashboardView()
                .tabItem { Label("Home", systemImage: "house") }

            iOSDevicesView()
                .tabItem { Label("Devices", systemImage: "laptopcomputer.and.iphone") }

            iOSSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

// MARK: - Dashboard (Phase 6)

struct iOSDashboardView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var showPairingSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ConnectionStatusCard(status: coordinator.connectionStatus)

                    if !coordinator.trustedDevices.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Trusted Devices", systemImage: "checkmark.shield")
                                    .font(.headline)

                                ForEach(coordinator.trustedDevices, id: \.id) { device in
                                    HStack(spacing: 12) {
                                        Image(systemName: device.platform == .macOS ? "laptopcomputer" : "iphone")
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.displayName)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text(device.platform.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
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
                                        .font(.body)
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

                    if !coordinator.mergedNearbyDevices.isEmpty && coordinator.trustedDevices.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Nearby Devices", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.headline)

                                ForEach(coordinator.mergedNearbyDevices) { device in
                                    NearbyDeviceRow(device: device) {
                                        coordinator.confirmPairing(with: device)
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }

                    Button {
                        showPairingSheet = true
                    } label: {
                        Label("Pair New Device", systemImage: "link.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("FaceBridge")
            .sheet(isPresented: $showPairingSheet) {
                PairingSheet()
                    .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Connection Status Card (Phase 9)

struct ConnectionStatusCard: View {
    let status: iOSCoordinator.ConnectionStatus

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        switch status {
        case .searching: return .orange
        case .deviceNearby: return .blue
        case .paired: return .green
        case .connectedSecurely: return .green
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

// MARK: - Nearby Device Row

struct NearbyDeviceRow: View {
    let device: iOSCoordinator.NearbyDevice
    let onPair: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "laptopcomputer")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.friendlyName)
                    .font(.body)
                Text("nearby")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Pair", action: onPair)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pairing Sheet (Phase 3)

struct PairingSheet: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if coordinator.mergedNearbyDevices.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Searching for devices…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Make sure FaceBridge is running on your Mac")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else if coordinator.mergedNearbyDevices.count == 1, let device = coordinator.mergedNearbyDevices.first {
                    Spacer()
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    Text("Pair with \(device.friendlyName)?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("This will allow your iPhone to authorize requests from this Mac.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                    HStack(spacing: 16) {
                        Button("Cancel") { dismiss() }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        Button("Approve") {
                            coordinator.confirmPairing(with: device)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                } else {
                    List(coordinator.mergedNearbyDevices) { device in
                        Button {
                            coordinator.confirmPairing(with: device)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "laptopcomputer")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text(device.friendlyName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("nearby")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                if coordinator.pairingState == .sendingAcceptance || coordinator.pairingState == .waitingConfirmation {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(coordinator.pairingState == .sendingAcceptance ? "Connecting…" : "Waiting for Mac to confirm…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if coordinator.pairingState == .completed {
                    Label("Paired successfully!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                        .padding()
                }

                if coordinator.pairingState == .failed {
                    Label("Pairing failed. Try again.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Face ID Auth Sheet (Phase 7)

struct FaceIDAuthSheet: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var authTriggered = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: !authTriggered)

            Text("Authorization Request")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Authorize request from your Mac")
                .font(.body)
                .foregroundStyle(.secondary)

            if let request = coordinator.pendingAuthRequest {
                Text(String(request.reason.prefix(200)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button {
                    coordinator.denyAuth()
                } label: {
                    Text("Deny")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    coordinator.approveAuth()
                } label: {
                    Label("Authorize", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
        .onAppear {
            guard !authTriggered else { return }
            authTriggered = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                coordinator.approveAuth()
            }
        }
    }
}

// MARK: - Devices View

struct iOSDevicesView: View {
    @EnvironmentObject var coordinator: iOSCoordinator

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.trustedDevices.isEmpty {
                    ContentUnavailableView(
                        "No Trusted Devices",
                        systemImage: "iphone.slash",
                        description: Text("Pair a device to get started.")
                    )
                } else {
                    List {
                        ForEach(coordinator.trustedDevices, id: \.id) { device in
                            HStack(spacing: 12) {
                                Image(systemName: device.platform == .macOS ? "laptopcomputer" : "iphone")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Paired \(device.createdAt, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Trusted Devices")
        }
    }
}

// MARK: - Settings (Phase 10)

struct iOSSettingsView: View {
    @EnvironmentObject var coordinator: iOSCoordinator

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    HStack {
                        Label("Connection Status", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(coordinator.connectionStatus.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Developer") {
                    Toggle(isOn: $coordinator.developerModeEnabled) {
                        Label("Developer Mode", systemImage: "hammer")
                    }
                    if coordinator.developerModeEnabled {
                        NavigationLink {
                            iOSDebugView()
                        } label: {
                            Label("Debug Console", systemImage: "ant")
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0-alpha")
                            .foregroundStyle(.secondary)
                    }
                    Button("Reset Onboarding") {
                        coordinator.hasCompletedOnboarding = false
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Debug Console (Developer Mode)

struct iOSDebugView: View {
    @EnvironmentObject var coordinator: iOSCoordinator
    @State private var pairingCode = ""
    @State private var selectedDeviceId: UUID?
    @FocusState private var isPairingFieldFocused: Bool

    var body: some View {
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
                                    Text(device.displayName).font(.caption)
                                    Text(device.id.uuidString.prefix(8))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Select") { selectedDeviceId = device.id }
                                    .font(.caption).buttonStyle(.bordered)
                                    .tint(selectedDeviceId == device.id ? .green : .blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                GroupBox("Manual Pairing") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State: \(coordinator.pairingState.rawValue)").font(.caption)
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
                        if let id = selectedDeviceId {
                            Text("Selected: \(id.uuidString.prefix(8))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(8)
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
