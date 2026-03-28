import SwiftUI
import FaceBridgeProtocol

public struct ApprovalPromptView: View {
    let request: AuthorizationRequest
    let deviceName: String
    let onApprove: () -> Void
    let onDeny: () -> Void

    public init(
        request: AuthorizationRequest,
        deviceName: String,
        onApprove: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) {
        self.request = request
        self.deviceName = deviceName
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Authorization Request")
                .font(.title2)
                .fontWeight(.semibold)

            Text(request.reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "laptopcomputer")
                    .font(.caption)
                Text(deviceName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)

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
