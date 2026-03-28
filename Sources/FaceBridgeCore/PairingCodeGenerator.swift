import Foundation

public actor PairingCodeGenerator {
    private var activeCodes: [String: Date] = [:]
    private var attemptCounts: [UUID: (count: Int, windowStart: Date)] = [:]
    private let maxAttempts: Int
    private let ttl: TimeInterval

    public init(maxAttempts: Int = 5, ttl: TimeInterval = 120) {
        self.maxAttempts = maxAttempts
        self.ttl = ttl
    }

    public func generate() throws -> String {
        pruneExpired()
        var bytes = [UInt8](repeating: 0, count: 4)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw FaceBridgeError.cryptographicFailure(detail: "SecRandomCopyBytes failed for pairing code")
        }
        let value = bytes.withUnsafeBytes { $0.load(as: UInt32.self) } % 1_000_000
        let code = String(format: "%06d", value)
        activeCodes[code] = Date()
        return code
    }

    public func validate(code: String, deviceId: UUID) -> PairingCodeResult {
        let now = Date()
        var record = attemptCounts[deviceId] ?? (count: 0, windowStart: now)
        if now.timeIntervalSince(record.windowStart) > ttl {
            record = (count: 0, windowStart: now)
        }

        guard record.count < maxAttempts else {
            let remaining = ttl - now.timeIntervalSince(record.windowStart)
            return .lockedOut(remainingSeconds: max(0, remaining))
        }

        guard let createdAt = activeCodes[code] else {
            pruneExpired()
            record.count += 1
            attemptCounts[deviceId] = record
            return .invalid(attemptsRemaining: maxAttempts - record.count)
        }

        guard now.timeIntervalSince(createdAt) <= ttl else {
            activeCodes.removeValue(forKey: code)
            record.count += 1
            attemptCounts[deviceId] = record
            return .expired
        }

        activeCodes.removeValue(forKey: code)
        attemptCounts.removeValue(forKey: deviceId)
        pruneExpired()
        return .valid
    }

    public func resetAttempts(for deviceId: UUID) {
        attemptCounts.removeValue(forKey: deviceId)
    }

    private func pruneExpired() {
        let now = Date()
        activeCodes = activeCodes.filter { now.timeIntervalSince($0.value) <= ttl }
        attemptCounts = attemptCounts.filter { now.timeIntervalSince($0.value.windowStart) <= ttl }
    }
}

public enum PairingCodeResult: Sendable, Equatable {
    case valid
    case invalid(attemptsRemaining: Int)
    case expired
    case lockedOut(remainingSeconds: TimeInterval)
}
