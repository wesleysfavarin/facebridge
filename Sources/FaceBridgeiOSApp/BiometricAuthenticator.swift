import Foundation
import LocalAuthentication
import FaceBridgeCore

public actor BiometricAuthenticator {
    public enum BiometricType: Sendable {
        case faceID
        case touchID
        case none
    }

    private static let reasonPrefix = "FaceBridge authorization request: "
    private static let maxReasonLength = 200

    public init() {}

    public func availableBiometric() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    public func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError {
                throw mapLAError(laError)
            }
            throw FaceBridgeError.biometricUnavailable
        }

        let sanitized = sanitizeReason(reason)
        let sanitizedReason = Self.reasonPrefix + sanitized

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: sanitizedReason
            )
            return success
        } catch let laError as LAError {
            throw mapLAError(laError)
        } catch {
            throw FaceBridgeError.biometricFailed
        }
    }

    private func sanitizeReason(_ reason: String) -> String {
        let cleaned = String(reason.unicodeScalars.filter { scalar in
            !scalar.properties.isBidiControl &&
            scalar.value != 0x202E && // RTL override
            scalar.value != 0x202D && // LTR override
            scalar.value != 0x200F && // RTL mark
            scalar.value != 0x200E && // LTR mark
            scalar.value != 0x2066 && // LTR isolate
            scalar.value != 0x2067 && // RTL isolate
            scalar.value != 0x2068 && // first strong isolate
            scalar.value != 0x2069 && // pop directional isolate
            !scalar.properties.isDefaultIgnorableCodePoint
        })
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(normalized.prefix(Self.maxReasonLength))
    }

    private func mapLAError(_ error: LAError) -> FaceBridgeError {
        switch error.code {
        case .userCancel:
            return .biometricUserCancelled
        case .biometryLockout:
            return .biometricLockout
        case .systemCancel:
            return .biometricSystemCancelled
        case .biometryNotAvailable:
            return .biometricUnavailable
        case .biometryNotEnrolled:
            return .biometricNotEnrolled
        case .authenticationFailed:
            return .biometricFailed
        default:
            return .biometricFailed
        }
    }
}
