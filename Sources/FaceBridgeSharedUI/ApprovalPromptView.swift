import SwiftUI
import FaceBridgeCore
import FaceBridgeProtocol

public struct ApprovalPromptView: View {
    let request: AuthorizationRequest
    let deviceName: String
    let isTrustedDevice: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void

    public init(
        request: AuthorizationRequest,
        deviceName: String,
        isTrustedDevice: Bool = false,
        onApprove: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) {
        self.request = request
        self.deviceName = deviceName
        self.isTrustedDevice = isTrustedDevice
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    private var sanitizedReason: String {
        DisplaySanitizer.sanitize(request.reason, maxLength: 200)
    }

    private var sanitizedDeviceName: String {
        DisplaySanitizer.sanitize(deviceName, maxLength: 50)
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Authorization Request")
                .font(.title2)
                .fontWeight(.semibold)

            Text(sanitizedReason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)

            HStack(spacing: 4) {
                Image(systemName: isTrustedDevice ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .font(.caption)
                    .foregroundStyle(isTrustedDevice ? .green : .orange)
                Text(sanitizedDeviceName)
                    .font(.caption)
                    .fontWeight(.medium)
                if isTrustedDevice {
                    Text("Trusted")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("Unknown")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 16) {
                Button(action: onDeny) {
                    Text("Deny")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: onApprove) {
                    Text("Approve")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

public enum DisplaySanitizer {
    public static func sanitize(_ input: String, maxLength: Int = 100) -> String {
        let cleaned = String(input.unicodeScalars.filter { scalar in
            !scalar.properties.isBidiControl &&
            scalar.value != 0x202E &&
            scalar.value != 0x202D &&
            scalar.value != 0x200F &&
            scalar.value != 0x200E &&
            scalar.value != 0x2066 &&
            scalar.value != 0x2067 &&
            scalar.value != 0x2068 &&
            scalar.value != 0x2069 &&
            !scalar.properties.isDefaultIgnorableCodePoint &&
            (scalar.value >= 0x20 || scalar.value == 0x0A)
        })
        let normalized = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(normalized.prefix(maxLength))
    }
}
