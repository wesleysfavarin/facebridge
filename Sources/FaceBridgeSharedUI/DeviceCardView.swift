import SwiftUI
import FaceBridgeCore

public struct DeviceCardView: View {
    let device: DeviceIdentity
    let isTrusted: Bool
    let onRevoke: (() -> Void)?

    public init(device: DeviceIdentity, isTrusted: Bool, onRevoke: (() -> Void)? = nil) {
        self.device = device
        self.isTrusted = isTrusted
        self.onRevoke = onRevoke
    }

    public var body: some View {
        HStack(spacing: 12) {
            platformIcon
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(isTrusted ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.headline)

                Text(device.platform.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isTrusted {
                SecurityBadge(status: .trusted)
            }

            if let onRevoke {
                Button("Revoke", role: .destructive, action: onRevoke)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var platformIcon: some View {
        switch device.platform {
        case .iOS:
            Image(systemName: "iphone")
        case .macOS:
            Image(systemName: "laptopcomputer")
        }
    }
}
