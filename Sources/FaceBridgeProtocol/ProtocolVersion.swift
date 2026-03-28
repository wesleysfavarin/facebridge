import Foundation

public struct ProtocolVersion: Codable, Hashable, Sendable, Comparable {
    public let major: Int
    public let minor: Int

    public static let v1_0 = ProtocolVersion(major: 1, minor: 0)

    public static let current: ProtocolVersion = .v1_0

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public var description: String { "\(major).\(minor)" }

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }

    public func isCompatible(with other: ProtocolVersion) -> Bool {
        major == other.major
    }
}
