import Foundation

public actor ReplayProtector {
    private var usedNonces: Set<Data> = []
    private var nonceTimestamps: [Data: Date] = [:]
    private let windowDuration: TimeInterval
    private let maxEntries: Int
    private let clockSkewTolerance: TimeInterval

    public init(windowDuration: TimeInterval = 300, maxEntries: Int = 10_000, clockSkewTolerance: TimeInterval = 30) {
        self.windowDuration = windowDuration
        self.maxEntries = maxEntries
        self.clockSkewTolerance = clockSkewTolerance
    }

    public func validate(_ nonce: Nonce) -> Bool {
        pruneExpired()

        guard !usedNonces.contains(nonce.value) else {
            return false
        }

        let age = Date().timeIntervalSince(nonce.createdAt)

        guard age >= -clockSkewTolerance else {
            return false
        }

        guard age <= windowDuration else {
            return false
        }

        if usedNonces.count >= maxEntries {
            evictOldest()
        }

        usedNonces.insert(nonce.value)
        nonceTimestamps[nonce.value] = nonce.createdAt
        return true
    }

    public func entryCount() -> Int {
        usedNonces.count
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-windowDuration)
        let expired = nonceTimestamps.filter { $0.value < cutoff }.map(\.key)
        for key in expired {
            usedNonces.remove(key)
            nonceTimestamps.removeValue(forKey: key)
        }
    }

    private func evictOldest() {
        guard let oldest = nonceTimestamps.min(by: { $0.value < $1.value }) else { return }
        usedNonces.remove(oldest.key)
        nonceTimestamps.removeValue(forKey: oldest.key)
    }
}
