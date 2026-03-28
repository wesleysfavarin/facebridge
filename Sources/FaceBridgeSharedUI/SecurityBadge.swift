import SwiftUI

public enum SecurityStatus: Sendable {
    case trusted
    case untrusted
    case pending
    case revoked

    var label: String {
        switch self {
        case .trusted: return "Trusted"
        case .untrusted: return "Untrusted"
        case .pending: return "Pending"
        case .revoked: return "Revoked"
        }
    }

    var iconName: String {
        switch self {
        case .trusted: return "checkmark.shield.fill"
        case .untrusted: return "exclamationmark.shield.fill"
        case .pending: return "clock.badge.questionmark"
        case .revoked: return "xmark.shield.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .trusted: return .green
        case .untrusted: return .orange
        case .pending: return .blue
        case .revoked: return .red
        }
    }
}

public struct SecurityBadge: View {
    let status: SecurityStatus

    public init(status: SecurityStatus) {
        self.status = status
    }

    public var body: some View {
        Label(status.label, systemImage: status.iconName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(status.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tintColor.opacity(0.12))
            .clipShape(Capsule())
    }
}
