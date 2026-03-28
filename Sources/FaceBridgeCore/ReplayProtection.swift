import Foundation

public actor ReplayProtector {
    private var usedNonces: Set<Data> = []
    private var nonceTimestamps: [Data: Date] = [:]
    private let windowDuration: TimeInterval

    public init(windowDuration: TimeInterval = 300) {
        self.windowDuration = windowDuration
    }

    public func validate(_ nonce: Nonce) -> Bool {
        pruneExpired()

        guard !usedNonces.contains(nonce.value) else {
            return false
        }

        let age = Date().timeIntervalSince(nonce.createdAt)
        guard age <= windowDuration else {
            return false
        }

        usedNonces.insert(nonce.value)
        nonceTimestamps[nonce.value] = nonce.createdAt
        return true
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-windowDuration)
        let expired = nonceTimestamps.filter { $0.value < cutoff }.map(\.key)
        for key in expired {
            usedNonces.remove(key)
            nonceTimestamps.removeValue(forKey: key)
        }
    }
}
