import Foundation
import CryptoKit

public actor EncryptedAuditLogStore {
    private let fileURL: URL
    private let encryptionKey: SymmetricKey

    public init(directory: URL = FileManager.default.temporaryDirectory, keyData: Data? = nil) {
        self.fileURL = directory.appendingPathComponent("facebridge-audit.encrypted")
        if let keyData, keyData.count == 32 {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            self.encryptionKey = SymmetricKey(size: .bits256)
        }
    }

    public func persist(_ entries: [AuditEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(entries)

        let sealed = try AES.GCM.seal(plaintext, using: encryptionKey)
        guard let combined = sealed.combined else {
            throw FaceBridgeError.encodingFailed
        }
        try combined.write(to: fileURL)
    }

    public func load() throws -> [AuditEntry] {
        let combined = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(box, using: encryptionKey)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AuditEntry].self, from: plaintext)
    }

    public func deleteStore() throws {
        try FileManager.default.removeItem(at: fileURL)
    }
}
