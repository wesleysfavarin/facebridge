import Foundation
import os
import FaceBridgeCore

public final class MenuBarController: @unchecked Sendable {
    public enum MenuBarState: Sendable {
        case idle
        case waitingForApproval
        case approved
        case denied
        case error
    }

    private struct MutableState {
        var menuState: MenuBarState = .idle
    }

    private let lock = OSAllocatedUnfairLock(initialState: MutableState())
    private let auditLogger: AuditLogger

    public var state: MenuBarState {
        lock.withLock { $0.menuState }
    }

    public init(auditLogger: AuditLogger = AuditLogger()) {
        self.auditLogger = auditLogger
    }

    public func setWaiting() {
        lock.withLock { $0.menuState = .waitingForApproval }
    }

    public func setApproved() {
        lock.withLock { $0.menuState = .approved }
        resetAfterDelay()
    }

    public func setDenied() {
        lock.withLock { $0.menuState = .denied }
        resetAfterDelay()
    }

    public func setError() {
        lock.withLock { $0.menuState = .error }
        resetAfterDelay()
    }

    private func resetAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.lock.withLock { $0.menuState = .idle }
        }
    }
}
