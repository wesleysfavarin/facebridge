# Release Status

## Current Release: v0.3.0-alpha

**Maturity level:** Experimental alpha
**Last updated:** March 2026

FaceBridge is published as an experimental open-source project. It demonstrates a working biometric authorization bridge between macOS and iPhone using public Apple APIs.

## What Is Verified Working

The following features have been implemented, tested, and verified on real hardware:

- Device pairing with signed message exchange
- Trust persistence in Keychain on both platforms
- Secure Enclave key generation with biometric binding (iOS)
- Signed authorization requests from Mac to iPhone
- Face ID approval on iPhone with signed response
- Signed response verification on Mac
- Protected action execution after successful authorization
- Denial and expiration flows
- Anti-replay protection with bounded nonce tracking
- Session state machine with strict transitions
- Deterministic transport routing with fallback
- BLE and local network transport with encryption

**Test suite:** 145 tests across 32 suites, all passing.

## What Is Experimental

These features are implemented but have known limitations or incomplete integration:

| Feature | Status |
|---------|--------|
| SAS verification | Logic implemented and tested; not wired into pairing UI |
| BLE transport | Functional but less tested than LAN in real-device scenarios |
| Mac agent (headless daemon) | Functional with stuck recovery; not notarized |
| Encrypted audit log storage | Primitives exist; key not persisted |
| Trust revocation | Manual removal only; no propagation |
| Key rotation | Manager exists; no automatic peer notification |

## What Still Needs Work

| Area | Description |
|------|-------------|
| End-to-end encryption | Application-layer message encryption not implemented |
| Certificate pinning | TLS uses system defaults |
| Forward secrecy | HKDF exists; ephemeral ECDH not wired |
| Mandatory sender signatures | `senderSignature` still optional on requests |
| SAS in pairing UI | Verification display not wired |
| Trust lifecycle | No expiry, no propagation, no TTL |
| Code signing | Not notarized for macOS distribution |

## What Would Be Required Before Production

1. **End-to-end encryption** — Ephemeral ECDH key exchange + AES-256-GCM message encryption
2. **Certificate pinning** — Bind TLS identity to pairing-derived key material
3. **Forward secrecy** — Ephemeral session keys that cannot be derived from long-term keys
4. **Mandatory request signatures** — Remove optional `senderSignature`
5. **SAS in pairing UI** — Visual confirmation of key integrity during pairing
6. **Trust lifecycle management** — Expiry, revocation propagation, re-verification
7. **Third-party security audit** — Independent penetration testing and code review
8. **Code signing and notarization** — Apple Developer Program compliance
9. **App Store submission** — iOS app review and approval

## Why This Project Is Published Now

FaceBridge is published as an alpha to:

- Share the architectural approach for peer review and community feedback
- Demonstrate that biometric authorization delegation is feasible with public Apple APIs
- Provide a foundation for contributors interested in device trust and mobile security
- Document the security model, limitations, and trade-offs honestly

It is not published because it is production-ready. It is published because the design and implementation have reached a point where external review is valuable.

## Roadmap

| Version | Focus |
|---------|-------|
| **v0.3.0-alpha** (current) | Stable protected actions, robust transport routing, polished documentation |
| v0.4.0 | ECDH ephemeral keys, certificate pinning, mandatory sender signatures |
| v0.5.0 | Forward secrecy, trust lifecycle management |
| v0.6.0 | SAS in pairing UI, full SwiftUI data wiring |
| v0.7.0 | Code signing, notarization, distribution packaging |
| v1.0.0 | Third-party audit, App Store submission, production target |

See [CHANGELOG.md](../CHANGELOG.md) for version history.
