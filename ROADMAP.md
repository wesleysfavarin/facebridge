# FaceBridge Roadmap

## v0.1.0-alpha — Security Foundation (Current)

Core biometric authorization bridge with hardened security.

- [x] Pairing system with signed messages and SAS verification logic
- [x] Secure Enclave key generation (P-256 ECDSA, biometryCurrentSet)
- [x] Challenge-response authorization flow with canonical signing
- [x] Mac-side request signing for origin authenticity
- [x] Mandatory signatures on all authorization responses
- [x] Trusted device storage via Keychain
- [x] Codable validation on all security-critical types
- [x] Structured audit logging with actor isolation
- [x] Replay protection (bounded memory, future-date rejection)
- [x] Policy engine with biometric enforcement
- [x] BLE transport with encryption-required characteristics
- [x] BLE fragmentation/reassembly integrated
- [x] Local network transport with TLS default
- [x] Message envelope HMAC authentication
- [x] Display sanitization (bidi/control characters)
- [x] Background agent with stuck-state recovery
- [x] 145 tests across 32 suites

## v0.2.0 — Transport Security

End-to-end encryption and forward secrecy.

- [ ] Wire `SessionKeyDerivation` (HKDF-SHA256) into runtime
- [ ] Ephemeral ECDH key exchange for forward secrecy
- [ ] Certificate pinning or PSK-based TLS
- [ ] Wire SAS verification into `PairingFlowController`
- [ ] Trust expiry and revocation propagation
- [ ] End-to-end integration testing on physical devices
- [ ] QR code pairing flow (camera integration)

## v0.3.0 — User Experience

Improved usability and real UI.

- [ ] Wire SwiftUI views to real data managers
- [ ] Menu bar mode (macOS status bar integration)
- [ ] Background approval mode (agent-driven)
- [ ] Proximity improvements (RSSI calibration)
- [ ] Notification support for incoming requests
- [ ] Session history and analytics view
- [ ] Persist `EncryptedAuditLogStore` key in Keychain

## v1.0.0 — Production Release

Production distribution and enterprise features.

- [ ] Code signing and notarization
- [ ] App Store submission (iOS)
- [ ] Third-party security audit
- [ ] XPC service for third-party app integration
- [ ] CLI tool for agent management
- [ ] MDM-compatible trust provisioning
- [ ] Documentation site with API reference
- [ ] Localization support

## Future Considerations

- watchOS authenticator support
- visionOS spatial authorization prompt
- Hardware security key fallback (FIDO2)
- Multi-Mac support from single iPhone
- Multi-device management (multiple iPhones per Mac)
- Audit log export (JSON, CSV)
- Biometric policy per-action granularity
