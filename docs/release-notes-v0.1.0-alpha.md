# Release Notes — v0.1.0-alpha

**Release date:** March 28, 2026
**Status:** Public alpha — security-hardened, not production-ready

---

## Summary

FaceBridge v0.1.0-alpha is the first public release of the privacy-first biometric authorization bridge for iPhone and macOS. This release has undergone two comprehensive security remediation passes, resulting in a hardened foundation suitable for research, experimentation, and community review.

**This is alpha software.** It is not intended for production use, financial authorization, or as a replacement for macOS system authentication.

## Test Coverage

**145 tests across 32 suites, all passing.**

Test suites cover every security-critical code path:
- Nonce generation, validation, and Codable bypass prevention
- Replay protection including future-dated nonce rejection
- Session state machine (all valid and invalid transitions)
- Policy engine with biometric, TTL, and proximity enforcement
- Authorization request/response signing roundtrips
- Mac request origin signing and forged request rejection
- Codable deserialization validation for Nonce, DeviceIdentity, AuthorizationResponse, SessionToken
- BLE fragmentation, reassembly, and CRC integrity
- Transport configuration (TLS default, connection limits, idle timeout)
- Display sanitization (bidi, control characters, isolates)
- Key format consistency across Secure Enclave and software key paths
- Background listener queue protection and stuck-state recovery
- SAS computation and verification
- HKDF session key derivation

## Security Remediation

### Audit 1 Fixes (17 Findings)

All 17 critical and high-priority findings from the first security audit were resolved:

1. Nonce generation: `precondition` replaced with throwing error handling
2. Policy engine: `requireBiometric` enforcement implemented
3. Replay protector: bounded memory with max entries and TTL eviction
4. Session state machine: strict transition validation
5. Device identity: P-256 public key format validation
6. Session token: UUID replaced with 32-byte `SecRandomCopyBytes`
7. Message envelope: HMAC-SHA256 authentication with sequence numbers
8. Authorization response: mandatory signature and signed payload
9. Authorization request: canonical length-prefixed binary signable
10. Pairing messages: signed invitation, acceptance, confirmation
11. Local network transport: TLS-capable with documented limitations
12. Incoming message size: validated before allocation
13. BLE characteristics: encryption-required permissions
14. Secure session handler: atomic session consumption
15. Authorization executor: request binding, device identity, payload integrity verification
16. Authorization responder: persistent device identity
17. Local timestamp: `localReceiptTime` used for all local security decisions

### Audit 2 Fixes (18 Findings)

All confirmed findings from the second audit were resolved:

1. **Nonce init validation**: Public `init` now throws; validates minimum 16 bytes and non-zero
2. **DeviceIdentity Codable hardening**: Custom `init(from:)` runs `validatePublicKey` on deserialization
3. **AuthorizationResponse Codable hardening**: Custom `init(from:)` enforces minimum 64-byte signature
4. **SessionToken Codable hardening**: Custom `init(from:)` validates minimum length and base64 format
5. **Future-dated nonce rejection**: `ReplayProtector` enforces clock skew tolerance (default 30s)
6. **Mac request signing**: `AuthorizationRequest.senderSignature` added; Mac signs requests
7. **Sender signature verification**: `AuthorizationResponder` verifies when signature and key present
8. **Dead code removal**: `.claude/worktrees` directories removed
9. **Fire-and-forget logging fixed**: `DeviceTrustManager` and `PairedDeviceManager` methods now `async`
10. **BLE fragmentation integrated**: `BLEFragmentationManager` wired into `BLETransport` send/receive
11. **Stuck-state recovery**: `BackgroundListener.recoverIfStuck()` added with 120s timeout
12. **SecRandomCopyBytes error handling**: BLE fragmentation manager handles generation failure
13. **Connection cleanup**: `LocalNetworkTransport` cleans up connections on receive errors
14. **TLS as default**: `LocalNetworkTransport` defaults to TLS; plaintext requires `allowInsecure: true`
15. **Per-device BLE state**: `BLETransport` uses per-device `connectionStates` dictionary
16. **Peer authorization**: BLE rejects data from unauthorized peers before processing

## Architecture Changes

- All security-critical types (`Nonce`, `DeviceIdentity`, `AuthorizationResponse`, `SessionToken`) now validate on both construction and Codable deserialization
- `AuthorizationRequest` includes optional `senderSignature` for Mac origin authenticity
- `LocalNetworkTransport` defaults to TLS; plaintext is debug-only
- `BLETransport` integrates `BLEFragmentationManager` for transparent large message handling
- `BLETransport` tracks connection state per device, not globally
- `BackgroundListener` includes stuck-state recovery with configurable timeout

## Known Limitations

These limitations are documented in detail in [LIMITATIONS.md](LIMITATIONS.md):

- **No forward secrecy**: HKDF abstraction exists; ephemeral ECDH not wired
- **No E2E encryption**: Relies on transport-layer protection (TLS/BLE encryption)
- **No certificate pinning**: TLS uses system defaults
- **SAS not in UI**: Verification logic exists but pairing UI does not display SAS
- **Sender signature optional**: Requests without `senderSignature` still processed if sender is trusted
- **MessageEnvelope MAC optional**: Not enforced at transport level
- **Trust revocation local only**: No propagation to peer device
- **SwiftUI views are scaffolds**: No live data loading
- **macOS Secure Enclave parity**: Differs from iOS hardware capabilities
- **No third-party security audit**: Not externally validated

## File Changes

| Area | Files Modified |
|------|---------------|
| Core | `Nonce.swift`, `DeviceIdentity.swift`, `Session.swift`, `PolicyEngine.swift`, `ReplayProtection.swift`, `Errors.swift`, `AuditLog.swift` |
| Crypto | `SecureEnclaveKeyManager.swift`, `SoftwareKeyManager.swift`, `SignatureService.swift` |
| Protocol | `AuthorizationRequest.swift`, `AuthorizationResponse.swift`, `SessionToken.swift`, `MessageEnvelope.swift`, `PairingMessage.swift` |
| Transport | `BLETransport.swift`, `LocalNetworkTransport.swift`, `BLEFragmentationManager.swift` |
| macOS Agent | `BackgroundListener.swift`, `main.swift`, `SecureSessionHandler.swift`, `AuthorizationExecutor.swift`, `PolicyEnforcer.swift` |
| macOS App | `AuthorizationRequester.swift`, `PairedDeviceManager.swift`, `MenuBarController.swift`, `MacAppViews.swift` |
| iOS App | `AuthorizationResponder.swift`, `DeviceTrustManager.swift`, `BiometricAuthenticator.swift` |
| Shared UI | `ApprovalPromptView.swift` |
| Tests | 8 test files, 145 tests across 32 suites |
| Documentation | `README.md`, `SECURITY.md`, `ARCHITECTURE.md`, `TRUST_MODEL.md`, `LIMITATIONS.md`, `ROADMAP.md`, `CONTRIBUTING.md`, `RELEASE_READINESS.md`, `SECURITY_REMEDIATION_REPORT.md`, `RELEASE_NOTES_v0.1.0-alpha.md` |
| Removed | `.claude/worktrees/` (dead code) |

## Recommended Next Steps

For contributors and reviewers:

1. Read [SECURITY.md](SECURITY.md) and [TRUST_MODEL.md](TRUST_MODEL.md) for the security model
2. Read [LIMITATIONS.md](LIMITATIONS.md) for known constraints
3. Run `swift test` to verify all 145 tests pass
4. Review [ARCHITECTURE.md](ARCHITECTURE.md) for module structure
5. Check [ROADMAP.md](ROADMAP.md) for v0.2.0 priorities
