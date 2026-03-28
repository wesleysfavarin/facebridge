# Limitations

This document provides an honest and complete list of known limitations in FaceBridge v0.1.0-alpha. These are not bugs — they represent architectural boundaries, incomplete features, or deliberate design trade-offs in the current alpha release.

## Cryptographic Limitations

### No Forward Secrecy

FaceBridge does not implement forward secrecy. If a device's long-term signing key is compromised, past authorization sessions that were observed by an attacker could potentially be replayed or analyzed.

**Current state:** `SessionKeyDerivation` provides an HKDF-SHA256 abstraction for deriving session-specific keys, but no ephemeral Diffie-Hellman key exchange is wired into the runtime. This is a v0.2.0 priority.

### No Full End-to-End Encryption

Message confidentiality relies entirely on transport-layer protection:
- **LAN:** TLS (system defaults, no certificate pinning)
- **BLE:** Link-layer encryption via Apple's BLE stack (encryption-required characteristic permissions)

There is no application-layer encryption of message payloads. An attacker who compromises the TLS session or BLE link can read message contents.

### No Certificate Pinning

TLS connections use system-default certificate validation. This means:
- A compromised or rogue Certificate Authority could issue a valid certificate
- A sufficiently privileged network attacker could perform MITM
- There is no binding between TLS identity and pairing-established trust

**Planned:** Pin to pairing-derived key material in v0.2.0.

### Software Key Fallback

When the Secure Enclave is unavailable (iOS Simulator, macOS without Touch ID), `SoftwareKeyManager` is used instead of `SecureEnclaveKeyManager`. Software keys:
- Are stored in Keychain, not in hardware
- Do not benefit from hardware isolation
- Can be extracted by an attacker with Keychain access
- Are intended for development and testing only

## Transport Limitations

### BLE Proximity Spoofing

BLE RSSI values used for proximity detection can be spoofed:
- An attacker can amplify or relay BLE signals
- RSSI does not provide reliable distance measurement
- The proximity policy (`requireProximity`, `minimumRSSI`) is a soft control, not a security boundary

### LAN Transport `connect(to:)` Not Implemented

`LocalNetworkTransport.connect(to:)` always throws `transportUnavailable`. The transport only supports:
- Listening for incoming connections (server mode)
- Bonjour discovery
- Sending to established connections

Outbound connection initiation is not yet implemented.

### BLE MTU Constraints

BLE fragmentation/reassembly is wired into `BLETransport`, but:
- Fragment ordering depends on BLE stack delivery guarantees
- No application-layer retransmission for lost fragments
- Reassembly timeout is 30 seconds (stale buffers pruned)

## Trust and Revocation Limitations

### No Trust Revocation Propagation

Removing a device from the trust store on one device does not notify the peer. This means:
- If Mac removes iPhone from trusted devices, iPhone still considers Mac trusted
- There is no revocation notification mechanism
- Trust removal is strictly local

### `TrustRelationship` Not Used at Runtime

The `TrustRelationship` struct exists with `revokedAt` and `isActive` fields, but runtime trust checks use `DeviceTrustManager` and `TrustedDeviceVerifier`, which operate on `[DeviceIdentity]` arrays without revocation metadata.

### No Trust Expiry

Trust relationships do not expire. Once paired, devices remain trusted indefinitely until manually removed.

## Protocol Limitations

### Sender Signature Not Mandatory

`AuthorizationRequest.senderSignature` is optional (`Data?`). If the Mac sends a request without a signature:
- The iPhone still processes the request if `senderDeviceId` is in the trust store
- Request authenticity is based on trust-store presence, not cryptographic proof
- This is a defense-in-depth gap; a local attacker who knows a trusted device ID can forge requests

### SAS Not Wired in UI

`ShortAuthenticationStringVerifier` is implemented and tested (5 tests), but:
- No SwiftUI view displays the SAS during pairing
- No user confirmation step is integrated into `PairingFlowController`
- MITM protection during pairing depends on the pairing code alone

### MessageEnvelope MAC Optional

`MessageEnvelope.mac` is optional (`Data?`). Messages can be sent without HMAC authentication. The protocol does not enforce MAC verification at the transport level — callers must explicitly use `authenticatedCopy` and `verifyMAC`.

### Sequence Number Default Zero

`MessageEnvelope.sequenceNumber` defaults to 0 in both `init` and `MessageEncoder.encode`. Without caller-managed sequence numbers, anti-reordering protection is inactive.

## Application Limitations

### SwiftUI Views Are Scaffolds

All SwiftUI views (`MacDevicesView`, `MacAuditLogView`, `iOSDevicesView`, etc.) initialize with empty `@State` arrays and do not load data from `PairedDeviceManager`, `DeviceTrustManager`, or `AuditLogger` on appear. They are UI structure only.

### EncryptedAuditLogStore Key Not Persisted

`EncryptedAuditLogStore` generates an in-memory `SymmetricKey` if no `keyData` is provided. This key is lost when the actor is deallocated, making encrypted logs permanently unrecoverable. The store is not used in the runtime path.

### macOS Secure Enclave Parity

macOS Secure Enclave support differs from iOS:
- Requires Apple Silicon or T2 chip with Touch ID
- Key access patterns differ from Face ID flow
- `biometryCurrentSet` behavior varies by hardware configuration

## Operational Limitations

### No Production Hardening Guarantee

FaceBridge has not undergone:
- Third-party penetration testing
- Formal security audit by an external firm
- App Store review
- Code signing or notarization for macOS distribution

### Signal Handler Race Condition

The `gracefulShutdown` function in `main.swift` calls `await auditLogger.log()` and `await listener.stop()` before `exit(0)`. If the process is killed during these awaits, shutdown may be incomplete. This is a known limitation of signal-based cleanup in Swift concurrency.

### Fire-and-Forget in Non-Critical Paths

While critical security events (pairing, revocation) now use `await` for audit logging, some informational log calls in transport delegates and discovery handlers may still use fire-and-forget patterns due to synchronous callback constraints.
