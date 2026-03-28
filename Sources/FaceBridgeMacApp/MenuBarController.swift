import Foundation
import FaceBridgeCore

public final class MenuBarController: @unchecked Sendable {
    public enum MenuBarState: Sendable {
        case idle
        case waitingForApproval
        case approved
        case denied
        case error
    }

    public private(set) var state: MenuBarState = .idle
    private let auditLogger: AuditLogger

    public init(auditLogger: AuditLogger = AuditLogger()) {
        self.auditLogger = auditLogger
    }

    public func setWaiting() {
        state = .waitingForApproval
    }

    public func setApproved() {
        state = .approved
        resetAfterDelay()
    }

    public func setDenied() {
        state = .denied
        resetAfterDelay()
    }

    public func setError() {
        state = .error
        resetAfterDelay()
    }

    private func resetAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.state = .idle
        }
    }
}
