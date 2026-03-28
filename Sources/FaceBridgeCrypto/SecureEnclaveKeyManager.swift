import Foundation
import CryptoKit
import Security
import FaceBridgeCore

public protocol KeyManaging: Sendable {
    func generateKeyPair(tag: String) throws -> Data
    func sign(data: Data, keyTag: String) throws -> Data
    func publicKeyData(for tag: String) throws -> Data
    func deleteKey(tag: String) throws
}

public struct SecureEnclaveKeyManager: KeyManaging, Sendable {
    public init() {}

    public func generateKeyPair(tag: String) throws -> Data {
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        )

        guard let accessControl = access else {
            throw FaceBridgeError.keyGenerationFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl,
            ] as [String: Any],
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw FaceBridgeError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw FaceBridgeError.keyGenerationFailed
        }

        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw FaceBridgeError.keyGenerationFailed
        }

        return publicKeyData
    }

    public func sign(data: Data, keyTag: String) throws -> Data {
        let privateKey = try loadPrivateKey(tag: keyTag)

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Unknown"
            throw FaceBridgeError.signingFailed(underlying: message)
        }

        return signature
    }

    public func publicKeyData(for tag: String) throws -> Data {
        let privateKey = try loadPrivateKey(tag: tag)

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw FaceBridgeError.keyGenerationFailed
        }

        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw FaceBridgeError.keyGenerationFailed
        }

        return data
    }

    public func deleteKey(tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FaceBridgeError.keychainError(status: status)
        }
    }

    private func loadPrivateKey(tag: String) throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else {
            throw FaceBridgeError.keychainError(status: status)
        }

        return key as! SecKey
    }
}
