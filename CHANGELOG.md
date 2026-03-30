# Changelog

All notable changes to FaceBridge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0-alpha] - 2026-03-29

### Added

- Three stable protected actions: Unlock Secure Vault, Run Protected Command, Reveal Protected File
- `ProtectedAction` enum and `activeAction` tracking for response dispatch
- Deterministic transport routing via `bestAvailableTransportId()` with 4-level fallback
- Authorization Lab panel for developer testing
- Unpair functionality on both Mac and iPhone (remove individual or all devices)
- Enhanced iOS authorization sheet with action-specific icons and confirmation state
- Protected Actions section on Mac dashboard with status cards
- Comprehensive `/docs` folder with architecture, security model, trust model, protocol overview, limitations, real-device testing guide, and release status documentation
- Pull request template (`.github/PULL_REQUEST_TEMPLATE.md`)

### Changed

- Expanded `AuthorizationPhase` with specific error states: `noTrustedDevice`, `transportUnavailable`, `sendFailed`, `peerDisconnected`, `verificationFailed`
- Fixed `AuthorizationRequest.signable` timestamp to use whole seconds (prevents ISO 8601 encode/decode mismatch)
- Removed auto-approve on iOS `FaceIDAuthSheet` — user must tap Authorize manually
- Increased authorization request TTL from 30s to 60s for real-device latency
- README completely rewritten as a polished project landing page
- CONTRIBUTING.md enhanced with contribution categories and security guidance
- SECURITY.md streamlined to policy document linking to detailed security model
- Moved detailed documentation to `/docs` folder for cleaner repository root
- Updated `.gitignore` with comprehensive exclusion patterns

### Removed

- Redundant top-level documentation files (`ARCHITECTURE.md`, `TRUST_MODEL.md`, `LIMITATIONS.md`, `ROADMAP.md`) — content consolidated into `/docs`

## [0.1.0-alpha] - 2026-03-28

### Added

- FaceBridgeCore module with domain models, nonce generation, replay protection, audit logging, and policy engine
- FaceBridgeCrypto module with Secure Enclave key management, ECDSA signing/verification, Keychain persistence, and SAS verification
- FaceBridgeProtocol module with authorization request/response schemas, pairing messages, message envelope, and protocol versioning
- FaceBridgeTransport module with BLE transport, local network transport with TLS support, BLE fragmentation layer, and connection manager
- FaceBridgeSharedUI module with device cards, security badges, approval prompts, pairing views, and settings components
- FaceBridgeiOSApp module with Face ID/Touch ID authentication, device trust management, and authorization responder
- FaceBridgeMacApp module with authorization requester, paired device management, menu bar controller, and audit log viewer
- FaceBridgeMacAgent module with background listener, authorization executor, secure session handler, trusted device verifier, and policy enforcer
- Secure pairing code generator with rate limiting and TTL expiration
- Short Authentication String (SAS) verification protocol for pairing
- Length-prefixed canonical payload encoding for cross-platform determinism
- BLE message fragmentation and reassembly layer
- Session consumption after authorization to prevent reuse
- Background listener queue protection with rate limiting and burst detection
- Granular biometric error mapping (LAError to FaceBridgeError)
- Biometric prompt reason sanitization
- Thread-safe transport layers using OSAllocatedUnfairLock
- TLS support for local network transport
- Transport type binding in signed payloads
- Big-endian timestamp encoding for cross-platform safety
- Secure Enclave key rotation protocol
- Encrypted audit log disk persistence option
- Integration test suite for pairing, authorization, and session lifecycle
- macOS agent test suite
- GitHub Actions CI workflow
- GitHub issue templates for bugs, features, and security vulnerabilities
- Info.plist templates with privacy usage descriptions
- PrivacyInfo.xcprivacy manifest
- LaunchAgent plist template for macOS agent
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- CHANGELOG.md

### Security

- Secure Enclave key generation now requires biometryCurrentSet for hardware-enforced biometric gating
- Authorization responder uses persistent device identity instead of dynamic UUID generation
- Authorization executor validates responder device identity against trusted record
- Signed payload integrity verification before signature check
- Canonical length-prefixed binary encoding eliminates field boundary ambiguity
- Sessions are consumed (removed) after authorization to prevent reuse
- Background listener enforces queue limits and per-device rate limiting
