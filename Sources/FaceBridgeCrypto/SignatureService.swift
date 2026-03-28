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
            throw FaceBridgeError.verificationFailed
        }

        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &error
        )

        return result
    }
}
