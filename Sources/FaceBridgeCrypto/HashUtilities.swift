import Foundation
import CryptoKit

public struct HashUtilities: Sendable {
    public init() {}

    public func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    public func sha256(_ string: String) -> Data {
        sha256(Data(string.utf8))
    }

    public func sha384(_ data: Data) -> Data {
        Data(SHA384.hash(data: data))
    }

    public func sha512(_ data: Data) -> Data {
        Data(SHA512.hash(data: data))
    }
}
