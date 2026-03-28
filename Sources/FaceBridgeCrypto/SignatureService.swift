import Foundation
import CryptoKit
import Security
import FaceBridgeCore

public protocol SignatureVerifying: Sendable {
    func verify(signature: Data, data: Data, publicKeyData: Data) throws -> Bool
}

public struct SignatureVerifier: SignatureVerifying, Sendable {
    public init() {}

    public func verify(signature: Data, data: Data, publicKeyData: Data) throws -> Bool {
        guard publicKeyData.count == DeviceIdentity.expectedP256PublicKeySize else {
            throw FaceBridgeError.verificationFailed(detail: "Invalid public key size: \(publicKeyData.count)")
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256,
        ]

        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(
            publicKeyData as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            let detail = error?.takeRetainedValue().localizedDescription ?? "Unknown"
            throw FaceBridgeError.verificationFailed(detail: "Failed to create public key: \(detail)")
        }

        var verifyError: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &verifyError
        )

        return result
    }
}
