# FaceBridge Roadmap

## V1 — Foundation

Core biometric authorization bridge between iPhone and macOS.

- [x] Pairing system with explicit confirmation
- [x] Secure Enclave key generation (P-256 ECDSA)
- [x] Challenge-response authorization flow
- [x] Trusted device storage via Keychain
- [x] Structured audit logging
- [x] Replay protection with nonce expiration
- [x] Policy engine for authorization decisions
- [x] BLE transport layer
- [x] Local network transport layer
- [x] Protocol versioning and message envelope
- [ ] End-to-end integration testing on devices
- [ ] QR code pairing flow (camera integration)

## V2 — Enhanced Experience

Improved usability and developer extensibility.

- [ ] Menu bar mode (macOS status bar integration)
- [ ] Background approval mode (agent-driven)
- [ ] Proximity improvements (RSSI calibration, distance estimation)
- [ ] Plugin developer hooks (authorization request callbacks)
- [ ] Multi-device management (multiple iPhones per Mac)
- [ ] Session history and analytics view
- [ ] Notification support for incoming requests
- [ ] Configurable timeout and retry policies

## V3 — Distribution & Enterprise

Production distribution and enterprise features.

- [ ] Direct notarized macOS distribution pipeline
- [ ] App Store safe mode build profile
- [ ] Optional enterprise policy configuration
- [ ] MDM-compatible trust provisioning
- [ ] XPC service for third-party app integration
- [ ] CLI tool for agent management
- [ ] Documentation site with API reference
- [ ] Localization support

## Future Considerations

- watchOS authenticator support
- visionOS spatial authorization prompt
- Hardware security key fallback (FIDO2)
- Multi-Mac support from single iPhone
- Audit log export (JSON, CSV)
- Biometric policy per-action granularity
