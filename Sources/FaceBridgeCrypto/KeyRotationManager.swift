import Foundation
import FaceBridgeCore

public actor KeyRotationManager {
    private let keyManager: KeyManaging
    private let keychainStore: SecureStorage
    private let auditLogger: AuditLogger

    private static let activeKeyTagKey = "com.facebridge.active-key-tag"

    public init(
        keyManager: KeyManaging,
        keychainStore: SecureStorage = KeychainStore(),
        auditLogger: AuditLogger = AuditLogger()
    ) {
        self.keyManager = keyManager
        self.keychainStore = keychainStore
        self.auditLogger = auditLogger
    }

    public func rotateKeyPair(currentTag: String) async throws -> KeyRotationResult {
        let newTag = "\(currentTag)-\(UUID().uuidString.prefix(8))"
        let newPublicKey = try keyManager.generateKeyPair(tag: newTag)

        try keychainStore.save(data: Data(newTag.utf8), for: Self.activeKeyTagKey)

        await auditLogger.log(.keyRotated, details: "Key rotated from \(currentTag) to \(newTag)")

        return KeyRotationResult(
            previousTag: currentTag,
            newTag: newTag,
            newPublicKey: newPublicKey
        )
    }

    public func activeKeyTag() throws -> String? {
        guard let data = try keychainStore.load(for: Self.activeKeyTagKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func cleanupOldKey(tag: String) async throws {
        try keyManager.deleteKey(tag: tag)
        await auditLogger.log(.deviceRevoked, details: "Old key deleted: \(tag)")
    }
}

public struct KeyRotationResult: Sendable {
    public let previousTag: String
    public let newTag: String
    public let newPublicKey: Data
}
