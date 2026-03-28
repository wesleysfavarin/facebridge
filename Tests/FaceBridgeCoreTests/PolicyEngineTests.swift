import Testing
import Foundation
@testable import FaceBridgeCore

@Suite("PolicyEngine")
struct PolicyEngineTests {
    private func makeSession(ttl: TimeInterval = 30) throws -> Session {
        let nonce = try NonceGenerator().generate()
        return Session(trustRelationshipId: UUID(), nonce: nonce, ttl: ttl)
    }

    @Test("allows valid session with biometric verified")
    func allowsValidSession() throws {
        let engine = PolicyEngine()
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: true)
        #expect(decision == .allowed)
    }

    @Test("denies when biometric required but not verified")
    func deniesWithoutBiometric() throws {
        let engine = PolicyEngine(policy: .default)
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: false)
        #expect(decision == .denied(reason: .biometricRequired))
    }

    @Test("allows when biometric not required")
    func allowsWithoutBiometricWhenNotRequired() throws {
        let policy = AuthorizationPolicy(
            requireBiometric: false,
            maxSessionTTL: 30,
            requireProximity: false,
            minimumRSSI: -70
        )
        let engine = PolicyEngine(policy: policy)
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: false)
        #expect(decision == .allowed)
    }

    @Test("denies expired session")
    func deniesExpiredSession() throws {
        let engine = PolicyEngine()
        let nonce = try NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce, createdAt: Date().addingTimeInterval(-60), ttl: 1)
        let decision = engine.evaluate(session: session, biometricVerified: true)
        #expect(decision == .denied(reason: .sessionExpired))
    }

    @Test("denies session TTL exceeding policy max")
    func deniesExcessiveTTL() throws {
        let policy = AuthorizationPolicy(
            requireBiometric: false,
            maxSessionTTL: 10,
            requireProximity: false,
            minimumRSSI: -70
        )
        let engine = PolicyEngine(policy: policy)
        let session = try makeSession(ttl: 30)
        let decision = engine.evaluate(session: session, biometricVerified: false)
        #expect(decision == .denied(reason: .sessionTTLExceeded))
    }

    @Test("denies when proximity required but no RSSI")
    func deniesNoRSSI() throws {
        let policy = AuthorizationPolicy(
            requireBiometric: false,
            maxSessionTTL: 30,
            requireProximity: true,
            minimumRSSI: -70
        )
        let engine = PolicyEngine(policy: policy)
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: false, rssi: nil)
        #expect(decision == .denied(reason: .proximityRequired))
    }

    @Test("denies when device too far")
    func deniesDeviceTooFar() throws {
        let policy = AuthorizationPolicy(
            requireBiometric: false,
            maxSessionTTL: 30,
            requireProximity: true,
            minimumRSSI: -50
        )
        let engine = PolicyEngine(policy: policy)
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: false, rssi: -80)
        #expect(decision == .denied(reason: .deviceTooFar))
    }

    @Test("allows when proximity met")
    func allowsProximityMet() throws {
        let policy = AuthorizationPolicy(
            requireBiometric: false,
            maxSessionTTL: 30,
            requireProximity: true,
            minimumRSSI: -70
        )
        let engine = PolicyEngine(policy: policy)
        let session = try makeSession()
        let decision = engine.evaluate(session: session, biometricVerified: false, rssi: -40)
        #expect(decision == .allowed)
    }
}

@Suite("DeviceIdentity Validation")
struct DeviceIdentityTests {
    @Test("accepts valid P-256 public key")
    func acceptsValidKey() throws {
        var keyData = Data(count: 65)
        keyData[0] = 0x04
        for i in 1..<65 { keyData[i] = UInt8(i) }
        let identity = try DeviceIdentity(displayName: "Test", platform: .iOS, publicKeyData: keyData)
        #expect(identity.publicKeyData.count == 65)
    }

    @Test("rejects empty public key")
    func rejectsEmptyKey() {
        #expect(throws: FaceBridgeError.self) {
            _ = try DeviceIdentity(displayName: "Test", platform: .iOS, publicKeyData: Data())
        }
    }

    @Test("rejects wrong-size public key")
    func rejectsWrongSize() {
        #expect(throws: FaceBridgeError.self) {
            _ = try DeviceIdentity(displayName: "Test", platform: .iOS, publicKeyData: Data(repeating: 0x04, count: 33))
        }
    }

    @Test("rejects key without uncompressed point prefix")
    func rejectsMissingPrefix() {
        var keyData = Data(count: 65)
        keyData[0] = 0x02
        #expect(throws: FaceBridgeError.self) {
            _ = try DeviceIdentity(displayName: "Test", platform: .iOS, publicKeyData: keyData)
        }
    }

    @Test("sanitizes display name with bidi characters")
    func sanitizesDisplayName() throws {
        var keyData = Data(count: 65)
        keyData[0] = 0x04
        for i in 1..<65 { keyData[i] = UInt8(i) }
        let identity = try DeviceIdentity(displayName: "Evil\u{202E}Device", platform: .iOS, publicKeyData: keyData)
        #expect(!identity.displayName.contains("\u{202E}"))
    }
}
