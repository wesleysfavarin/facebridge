# FaceBridge

**Privacy-First Biometric Authorization Bridge for iPhone and macOS**

FaceBridge enables secure biometric authorization requests between a paired Mac and iPhone using Secure Enclave keys, signed requests, replay protection, and authenticated transports.

---

> **Alpha Software**
>
> FaceBridge is currently in **security-hardened alpha** (v0.1.0-alpha).
> It is intended for research, experimentation, and community review.
> It is **NOT** a replacement for macOS login, Touch ID, FileVault, or Apple Pay.
> See [LIMITATIONS.md](LIMITATIONS.md) for a complete list of known constraints.

---

## Features Implemented

### Cryptographic Foundation
- Secure Enclave-backed P-256 ECDSA signing (iOS, with `biometryCurrentSet` binding)
- Software key fallback for simulator and testing environments
- Cryptographically random nonce generation with validation (minimum 16 bytes, non-zero)
- Cryptographically random session tokens (32 bytes via `SecRandomCopyBytes`)
- HKDF-SHA256 session key derivation primitives
- Key rotation primitives
- Short Authentication String (SAS) verification primitives

### Authorization Protocol
- Signed authorization requests (Mac signs with device key, proving origin)
- Signed authorization responses (iPhone signs all decisions: approved, denied, expired)
- Canonical length-prefixed binary payload for deterministic signing
- Replay protection with bounded memory, TTL eviction, and future-date rejection
- Session lifecycle enforcement with strict state machine transitions
- Atomic session consumption (prevents double-use)
- Codable deserialization validation on all security-critical types

### Transport Security
- TLS-enabled local network transport (TLS is the default; plaintext requires explicit `allowInsecure: true`)
- BLE transport with encryption-required characteristic permissions
- BLE fragmentation and reassembly layer for large payloads
- Message envelope with HMAC-SHA256 authentication and sequence numbers
- Per-device connection state tracking
- Connection limits, idle timeouts, and message size caps

### Trust and Policy
- Explicit device pairing with signed invitation, acceptance, and confirmation messages
- Device identity validation (P-256 X9.63 uncompressed key format, 65 bytes)
- Trust relationship persistence in Keychain
- Policy engine with biometric enforcement, session TTL, and proximity checks
- Display sanitization (bidi override, control character stripping, length capping)
- Rate limiting and queue overflow protection

### Operations
- Structured audit logging pipeline (actor-isolated)
- macOS background agent with graceful shutdown and stuck-state recovery
- Signal handling (SIGTERM, SIGINT)

## Architecture

FaceBridge uses a modular Swift Package Manager architecture with clear dependency boundaries:

```
FaceBridgeCore          Domain models, nonce, session, policy, audit
FaceBridgeCrypto        Secure Enclave, software keys, signing, SAS, HKDF
FaceBridgeProtocol      Authorization/pairing message schemas, envelope
FaceBridgeTransport     BLE + local network transport, fragmentation
FaceBridgeSharedUI      Shared SwiftUI components, display sanitizer
FaceBridgeiOSApp        iOS authenticator application
FaceBridgeMacApp        macOS companion application
FaceBridgeMacAgent      macOS background authorization agent
```

Dependencies flow downward: Apps -> UI/Transport -> Protocol -> Crypto -> Core.

See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed module breakdown.

## Security Model

| Protection | Implementation |
|-----------|---------------|
| Request authenticity | Mac signs `AuthorizationRequest` with device key (`senderSignature`) |
| Response authenticity | iPhone signs all responses with Secure Enclave key (min 64-byte signature enforced) |
| Replay protection | Nonce validation + bounded replay window + future-date rejection |
| Trust verification | Device identity validated (key format, Keychain persistence) |
| Session tokens | 32 bytes `SecRandomCopyBytes`, not UUID |
| Transport integrity | HMAC-SHA256 message envelope with sequence numbers |
| LAN transport | TLS by default (system defaults; no certificate pinning yet) |
| BLE transport | Encryption-required characteristic permissions |
| Input validation | All security types validate on Codable deserialization |

See [SECURITY.md](SECURITY.md) for the full threat model and [TRUST_MODEL.md](TRUST_MODEL.md) for trust chain details.

## Known Limitations

- No forward secrecy (HKDF abstraction exists; ephemeral ECDH not wired)
- No full end-to-end encryption layer (relies on transport-level protection)
- No TLS certificate pinning (uses system defaults)
- SAS verification logic exists and is tested but not fully wired into pairing UI flow
- Trust revocation is manual removal only; no propagation mechanism
- macOS Secure Enclave parity differs from iOS (Touch ID binding vs Face ID)
- Software key fallback used in simulator/testing (not hardware-protected)
- SwiftUI views are scaffolds (no live data loading)
- `AuthorizationResponder` does not reject requests missing `senderSignature` if sender is in trust store

See [LIMITATIONS.md](LIMITATIONS.md) for the complete list.

## Supported Platforms

| Platform | Minimum Version |
|----------|----------------|
| iOS | 17.0+ |
| macOS | 14.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

## Building

### Swift Package Manager

```bash
git clone https://github.com/wesleysfavarin/facebridge.git
cd facebridge
swift build
```

### Xcode

1. Open `Package.swift` in Xcode 15+
2. Select the desired scheme (`FaceBridgeMacApp`, `FaceBridgeiOSApp`, or `FaceBridgeMacAgent`)
3. Build with Cmd+B

### Running the macOS Agent

```bash
swift build --product FaceBridgeMacAgent
.build/debug/FaceBridgeMacAgent
```

The agent listens for authorization requests, handles signal-based shutdown, and runs a periodic health check loop.

### Running the iOS App

Open the project in Xcode, select the `FaceBridgeiOSApp` scheme, and run on a device with Face ID or Touch ID (Secure Enclave requires physical hardware).

### Pairing

1. Launch the Mac app and generate a pairing invitation
2. On the iPhone app, enter or scan the pairing code
3. Both devices exchange P-256 public keys
4. (Future) Confirm SAS match on both screens
5. Trust relationship is persisted in Keychain on both devices

## Testing

```bash
swift test
```

**Current status:** 145 tests across 32 suites, all passing.

Tests cover:
- Nonce generation, validation, and Codable bypass prevention
- Replay protection including future-dated nonce rejection
- Session state machine transitions (valid and invalid)
- Policy engine with biometric, TTL, and proximity enforcement
- Authorization request/response signing and verification roundtrips
- Mac request signing and forged request rejection
- Codable deserialization validation for all security types
- BLE fragmentation and reassembly
- Transport configuration (TLS default, connection limits)
- Display sanitization
- Key format consistency across components
- Background listener queue protection and stuck recovery

## Roadmap

| Version | Focus |
|---------|-------|
| **v0.1.0-alpha** (current) | Security-hardened foundation, 145 tests |
| v0.2.0 | ECDH ephemeral session keys, certificate pinning |
| v0.3.0 | Forward secrecy, trust revocation propagation |
| v0.4.0 | Pairing SAS UI integration, SwiftUI data wiring |
| v0.5.0 | Notarization-ready macOS agent |
| v1.0.0 | Production security target, third-party audit |

See [ROADMAP.md](ROADMAP.md) for details.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting pull requests.

Security vulnerabilities should be reported privately — see [SECURITY.md](SECURITY.md#reporting-security-issues).

## Author

Created and maintained by **Wesley Favarin**.

- GitHub: [github.com/wesleysfavarin](https://github.com/wesleysfavarin)
- LinkedIn: [linkedin.com/in/wesley-s-favarin-61249755](https://www.linkedin.com/in/wesley-s-favarin-61249755)
- Medium: [medium.com/@wesleysfavarin](https://medium.com/@wesleysfavarin)

## License

MIT License — see [LICENSE](LICENSE) for details.
