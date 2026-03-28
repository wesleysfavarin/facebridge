import Foundation
import CryptoKit
import FaceBridgeCore

/// HKDF-based session key derivation bound to pairing context.
public struct SessionKeyDerivation: Sendable {
    public init() {}

    /// Derive a symmetric key for a session using HKDF-SHA256.
    /// - Parameters:
    ///   - sharedSecret: Input keying material (e.g., from ECDH or pairing secret)
    ///   - salt: Context-specific salt (e.g., combined device IDs)
    ///   - info: Additional context binding (e.g., transport type, session ID)
    ///   - outputByteCount: Key length in bytes (default 32 for AES-256)
    public func deriveKey(
        sharedSecret: Data,
        salt: Data,
        info: Data,
        outputByteCount: Int = 32
    ) -> SymmetricKey {
        let ikm = SymmetricKey(data: sharedSecret)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: salt,
            info: info,
            outputByteCount: outputByteCount
        )
    }

    /// Build info parameter from structured context data.
    public func buildInfo(
        sessionId: UUID,
        transportType: String,
        initiatorId: UUID,
        responderId: UUID
    ) -> Data {
        var info = Data()
        info.append(Data("FaceBridge-v1".utf8))
        info.append(Data(sessionId.uuidString.utf8))
        info.append(Data(transportType.utf8))
        info.append(Data(initiatorId.uuidString.utf8))
        info.append(Data(responderId.uuidString.utf8))
        return info
    }
}
