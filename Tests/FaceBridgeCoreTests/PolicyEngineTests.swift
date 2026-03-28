import Testing
import Foundation
@testable import FaceBridgeCore

@Suite("PolicyEngine")
struct PolicyEngineTests {
    @Test("allows valid session without proximity")
    func allowsValidSession() {
        let engine = PolicyEngine(policy: .default)
        let nonce = NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce, ttl: 30)
        let decision = engine.evaluate(session: session)
        #expect(decision == .allowed)
    }

    @Test("denies expired session")
    func deniesExpiredSession() {
        let engine = PolicyEngine()
        let nonce = NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce, createdAt: Date().addingTimeInterval(-60), ttl: 1)
        let decision = engine.evaluate(session: session)
        #expect(decision == .denied(reason: .sessionExpired))
    }

    @Test("denies when proximity required but no RSSI")
    func deniesNoRSSI() {
        let policy = AuthorizationPolicy(
            requireBiometric: true,
            maxSessionTTL: 30,
            requireProximity: true,
            minimumRSSI: -70
        )
        let engine = PolicyEngine(policy: policy)
        let nonce = NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce)
        let decision = engine.evaluate(session: session, rssi: nil)
        #expect(decision == .denied(reason: .proximityRequired))
    }

    @Test("denies when RSSI too low")
    func deniesTooFar() {
        let policy = AuthorizationPolicy(
            requireBiometric: true,
            maxSessionTTL: 30,
            requireProximity: true,
            minimumRSSI: -50
        )
        let engine = PolicyEngine(policy: policy)
        let nonce = NonceGenerator().generate()
        let session = Session(trustRelationshipId: UUID(), nonce: nonce)
        let decision = engine.evaluate(session: session, rssi: -80)
        #expect(decision == .denied(reason: .deviceTooFar))
    }
}
