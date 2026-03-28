import Foundation
import CryptoKit
import FaceBridgeCore

public struct ShortAuthenticationStringVerifier: Sendable {
    public init() {}

    public func computeSAS(
        initiatorPublicKey: Data,
        responderPublicKey: Data,
        pairingCode: String
    ) -> String {
        var input = Data()
        input.append(initiatorPublicKey)
        input.append(responderPublicKey)
        input.append(Data(pairingCode.utf8))

        let hash = SHA256.hash(data: input)
        let hashBytes = Array(hash)

        let numericValue = hashBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }

        let sixDigit = numericValue % 1_000_000
        return String(format: "%06d", sixDigit)
    }

    public func verify(
        localSAS: String,
        remoteSAS: String
    ) -> Bool {
        guard localSAS.count == 6, remoteSAS.count == 6 else { return false }
        return localSAS == remoteSAS
    }
}
