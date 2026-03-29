import Foundation
import os

public enum DebugLogger {
    private static let subsystem = "com.facebridge"

    public static let transport = Logger(subsystem: subsystem, category: "transport")
    public static let pairing = Logger(subsystem: subsystem, category: "pairing")
    public static let auth = Logger(subsystem: subsystem, category: "authorization")
    public static let crypto = Logger(subsystem: subsystem, category: "crypto")
    public static let session = Logger(subsystem: subsystem, category: "session")
    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
