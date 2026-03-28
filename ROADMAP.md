# Roadmap

## v0.1.0-alpha — Security Foundation (Current Release)

Core biometric authorization bridge with security-hardened primitives.

- [x] Secure Enclave P-256 ECDSA key generation with biometric binding
- [x] Signed authorization requests (Mac signs with device key)
- [x] Signed authorization responses (all decision types)
- [x] Canonical length-prefixed binary signing payload
- [x] Cryptographically random nonces with validation (min 16 bytes, non-zero)
- [x] Cryptographically random session tokens (32-byte SecRandomCopyBytes)
- [x] Replay protection with bounded memory, TTL eviction, future-date rejection
- [x] Session state machine with strict transitions
- [x] Atomic session consumption
- [x] Policy engine with biometric, TTL, and proximity enforcement
- [x] TLS-default local network transport
- [x] BLE transport with encryption-required characteristics
- [x] BLE fragmentation/reassembly integrated into transport
- [x] HMAC-SHA256 message envelope authentication with sequence numbers
- [x] Codable deserialization validation on all security types
- [x] Pairing flow with signed messages and SAS verification primitives
- [x] Device identity validation (P-256 X9.63 format)
- [x] Display sanitization (bidi/control characters)
- [x] Rate limiting and queue overflow protection
- [x] Background agent with graceful shutdown and stuck recovery
- [x] Audit logging pipeline (actor-isolated)
- [x] 145 tests across 32 suites

## v0.2.0 — Transport Encryption Upgrade

End-to-end message confidentiality and stronger transport binding.

- [ ] ECDH ephemeral key exchange for session key establishment
- [ ] Wire `SessionKeyDerivation` (HKDF-SHA256) into runtime transport path
- [ ] AES-256-GCM encryption of message payloads at application layer
- [ ] TLS certificate pinning to pairing-derived key material
- [ ] Make `senderSignature` mandatory on `AuthorizationRequest`
- [ ] Enforce `MessageEnvelope` MAC verification at transport level
- [ ] Caller-managed sequence numbers with monotonic enforcement
- [ ] End-to-end integration testing on physical devices
- [ ] QR code pairing flow (camera integration)

## v0.3.0 — Forward Secrecy and Trust Lifecycle

Session-level forward secrecy and trust relationship management.

- [ ] Ephemeral session keys with forward secrecy guarantees
- [ ] Trust relationship TTL with periodic re-verification
- [ ] Trust revocation propagation via transport notification
- [ ] Wire `TrustRelationship` struct into runtime trust checks
- [ ] Key rotation with automatic peer notification
- [ ] Trust expiry enforcement

## v0.4.0 — Pairing and UI Completion

Full pairing UX and live application data.

- [ ] Wire SAS verification into pairing UI flow (both platforms)
- [ ] SwiftUI views connected to real data managers
- [ ] Session history and analytics view
- [ ] Notification support for incoming authorization requests
- [ ] Proximity improvements (RSSI calibration, distance estimation)
- [ ] `EncryptedAuditLogStore` key persistence in Keychain

## v0.5.0 — Distribution Readiness

macOS agent ready for notarized distribution.

- [ ] Code signing and notarization for macOS agent and app
- [ ] LaunchAgent/LaunchDaemon packaging
- [ ] CLI tool for agent management
- [ ] Audit log export (JSON, CSV)
- [ ] Localization support
- [ ] Privacy nutrition label generation

## v1.0.0 — Production Security Target

Production-ready release with external validation.

- [ ] Third-party security audit by independent firm
- [ ] App Store submission (iOS app)
- [ ] Formal threat model review
- [ ] XPC service for third-party Mac app integration
- [ ] MDM-compatible trust provisioning
- [ ] Documentation site with API reference
- [ ] Performance benchmarking and optimization

## Future Considerations

These are exploratory ideas, not committed features:

- watchOS authenticator support
- visionOS spatial authorization prompt
- Hardware security key fallback (FIDO2)
- Multi-Mac support from single iPhone
- Multi-iPhone management per Mac
- Biometric policy per-action granularity
- Plugin/extension API for third-party integrations
