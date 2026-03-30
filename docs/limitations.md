# Limitations

This document provides a complete list of known limitations in FaceBridge. These are not bugs — they represent architectural boundaries, incomplete features, or deliberate design trade-offs in the current alpha release.

> FaceBridge is an experimental alpha project — an app-level authorization prototype, not a production security system. It has not undergone a third-party security audit.

## Scope Boundaries

FaceBridge does **not** do any of the following:

- **Intercept native macOS Touch ID prompts.** FaceBridge cannot replace or redirect system-level biometric prompts such as App Store purchases, `sudo` authentication, FileVault unlock, Safari password autofill, or Apple Pay.
- **Replace macOS login or screen unlock.** FaceBridge operates entirely at the application layer.
- **Intercept or modify Keychain access prompts.** System keychain dialogs are outside FaceBridge's control.
- **Use private or undocumented Apple APIs.** All functionality is built on public frameworks.
- **Operate over the public internet.** FaceBridge is designed for local network and BLE communication only.
- **Provide production-grade security guarantees.** This is an experimental alpha project that has not undergone third-party security auditing.

## Cryptographic Limitations

### No Forward Secrecy

If a device's long-term signing key is compromised, past authorization sessions that were observed by an attacker could potentially be analyzed. `SessionKeyDerivation` provides an HKDF-SHA256 abstraction, but no ephemeral Diffie-Hellman key exchange is wired into the runtime.

### No Application-Layer End-to-End Encryption

Message confidentiality relies entirely on transport-layer protection:

- **LAN:** TLS with system-default certificate validation
- **BLE:** Link-layer encryption via Apple's BLE stack

There is no application-layer encryption of message payloads. An attacker who compromises the TLS session or BLE link can read message contents.

### No Certificate Pinning

TLS connections use system-default certificate validation. A compromised Certificate Authority could issue a valid certificate for MITM. There is no binding between TLS identity and pairing-established trust.

### Software Key Fallback

When the Secure Enclave is unavailable (iOS Simulator, macOS without Touch ID), `SoftwareKeyManager` is used. Software keys are stored in Keychain, not in hardware, and can be extracted by an attacker with Keychain access. This fallback is intended for development and testing only.

## Transport Limitations

### BLE Proximity Is Not a Security Boundary

BLE RSSI values used for proximity detection can be spoofed or relayed. The proximity policy (`requireProximity`, `minimumRSSI`) is a soft control, not a cryptographic guarantee.

### LAN Outbound Connection Initiation

`LocalNetworkTransport.connect(to:)` throws `transportUnavailable`. The transport supports listening for incoming connections, Bonjour discovery, and sending to established connections. Outbound connection initiation from the Mac to the iPhone is handled at the coordinator level.

### BLE Fragment Ordering

BLE fragmentation and reassembly depend on BLE stack delivery guarantees. There is no application-layer retransmission for lost fragments. Reassembly timeout is 30 seconds.

## Trust and Revocation Limitations

### No Trust Revocation Propagation

Removing a device from the trust store on one device does not notify the peer. Trust removal is strictly local.

### `TrustRelationship` Not Used at Runtime

The `TrustRelationship` struct exists with `revokedAt` and `isActive` fields, but runtime trust checks use `DeviceTrustManager` and `TrustedDeviceVerifier`, which operate on `[DeviceIdentity]` arrays without revocation metadata.

### No Trust Expiry

Trust relationships do not expire. Once paired, devices remain trusted indefinitely until manually removed.

## Protocol Limitations

### Sender Signature Not Mandatory

`AuthorizationRequest.senderSignature` is optional. If the Mac sends a request without a signature, the iPhone still processes it if the `senderDeviceId` is in the trust store. This is a defense-in-depth gap.

### SAS Not Wired in UI

`ShortAuthenticationStringVerifier` is implemented and tested, but no UI displays the SAS during pairing. MITM protection during pairing currently depends on the pairing code alone.

### MessageEnvelope MAC Optional

`MessageEnvelope.mac` is optional. Messages can be sent without HMAC authentication. MAC verification is not enforced at the transport level.

### Sequence Number Default

`MessageEnvelope.sequenceNumber` defaults to 0. Without caller-managed sequence numbers, anti-reordering protection is inactive.

## Application Limitations

### macOS Secure Enclave Parity

macOS Secure Enclave support differs from iOS. It requires Apple Silicon or T2 chip with Touch ID. Key access patterns differ from the Face ID flow, and `biometryCurrentSet` behavior varies by hardware configuration.

### EncryptedAuditLogStore Key Not Persisted

`EncryptedAuditLogStore` generates an in-memory `SymmetricKey` if no `keyData` is provided. This key is lost when the actor is deallocated, making encrypted logs unrecoverable. The store is not currently used in the runtime path.

## Operational Limitations

### No Production Hardening

FaceBridge has not undergone:

- Third-party penetration testing
- Formal security audit
- App Store review
- Code signing or notarization for macOS distribution

### No Apple Platform Integration Promise

FaceBridge is an independent experiment. There is no endorsement from Apple, no guarantee of continued platform compatibility, and no commitment to future Apple platform support.
