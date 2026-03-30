# Threat Model

This document describes what FaceBridge protects, what threats it addresses, what threats remain partially addressed, and what is explicitly out of scope.

> **FaceBridge is a research prototype.** This threat model documents the intended security properties of an experimental system. It is not a claim of production-grade security.

## Protected Assets

| Asset | Description |
|-------|-------------|
| Authorization approval flow | The end-to-end sequence from Mac request to iPhone biometric approval to Mac action execution |
| Trust relationships | The cryptographic identities exchanged during pairing, stored in Keychain |
| Device identity keys | P-256 ECDSA key pairs generated in the Secure Enclave (iOS) or CryptoKit (simulator/macOS) |
| Protected action gating | The enforcement that application-defined actions execute only after verified biometric approval |
| Session integrity | The guarantee that sessions are consumed atomically and cannot be replayed or reused |

## Threats Addressed

### Request Forgery

An attacker on the local network sends a fabricated authorization request to the iPhone.

**Mitigations.** The Mac signs requests with its device key. The iPhone verifies the sender signature against the stored public key. Untrusted device IDs are rejected before processing.

### Response Forgery

An attacker forges an approval or denial response.

**Mitigations.** All responses require a non-empty ECDSA signature (minimum 64 bytes) and a non-empty signed payload. Codable deserialization enforces these constraints at decode time. The Mac verifies request ID binding, signed payload integrity, and signature validity.

### Replay Attacks

An attacker captures a valid response and replays it.

**Mitigations.** Every request includes a cryptographic nonce (minimum 16 bytes via `SecRandomCopyBytes`). The `ReplayProtector` maintains a bounded set of seen nonces with TTL eviction. Future-dated nonces are rejected. Transport type is bound into signed payloads. Sessions are consumed atomically — a second consumption returns nil.

### Stale Session Reuse

An attacker attempts to reuse a previously consumed session.

**Mitigations.** `SecureSessionHandler` removes sessions from active storage upon consumption. The session state machine enforces `pending` → `approved` / `denied` / `expired` only. Expired sessions cannot be approved. Invalid transitions throw typed errors.

### Unauthorized Peer Approval

A device not part of the trust relationship attempts to respond to an authorization request.

**Mitigations.** The Mac verifies the response signature against the stored public key of the specific paired iPhone. Device identity includes a validated P-256 public key (65 bytes, X9.63 format). Trust is verified by device ID and public key match in Keychain.

### Device Impersonation

An attacker pretends to be a trusted device.

**Mitigations.** Device identity includes a P-256 public key validated at creation and on Codable deserialization. Pairing messages are signed. Trust is stored in Keychain and verified by public key match.

### Man-in-the-Middle During Pairing

An attacker intercepts the pairing ceremony to substitute public keys.

**Mitigations.** Pairing invitation, acceptance, and confirmation messages are digitally signed. SAS verification allows visual confirmation of key integrity. Rate limiting with lockout protects pairing code brute force.

**Residual risk.** SAS verification is implemented but not yet displayed in the pairing UI.

## Threats Partially Addressed

### Transport Interception

Messages in transit over BLE or local network could be intercepted.

**Current state.** LAN uses TLS by default. BLE characteristics require encryption. `MessageEnvelope` supports HMAC-SHA256 authentication.

**Gaps.** No TLS certificate pinning. No application-layer end-to-end encryption. `MessageEnvelope` MAC is optional and not enforced at the transport level.

### Transport Routing Ambiguity

A single logical device may appear through multiple transports (BLE and LAN) with different identifiers.

**Current state.** The Mac coordinator uses fuzzy name matching and transport ID correlation to merge discovered devices. Deterministic routing selects the best available transport.

**Gaps.** Transport-level identity is not cryptographically bound to pairing-level identity. Stale transport entries may persist.

### Local Network Assumptions

FaceBridge assumes devices operate on a trusted local network or within BLE range.

**Current state.** FaceBridge does not operate over the public internet. Bonjour discovery and BLE scanning are local by design.

**Gaps.** Network-level attacks (ARP spoofing, DNS poisoning, rogue access points) within the local network are not fully mitigated at the application layer.

### Proximity Assumptions

BLE RSSI is used for proximity detection.

**Current state.** `PolicyEngine` supports `requireProximity` and `minimumRSSI` policies.

**Gaps.** RSSI values can be spoofed or relayed. Proximity is a soft control, not a cryptographic guarantee.

## Threats Out of Scope

The following threats are explicitly outside the FaceBridge threat model:

| Threat | Rationale |
|--------|-----------|
| Fully compromised Mac | If the Mac is compromised at the OS level, the attacker controls the application layer |
| Fully compromised iPhone | If the iPhone is compromised at the OS level, biometric gating and Secure Enclave protections are invalidated |
| Both devices compromised | The entire trust model is invalidated when both endpoints are compromised |
| Kernel-level or system-level compromise | FaceBridge operates at the application layer and cannot defend against kernel exploits |
| Apple private authentication channels | FaceBridge does not interact with system authentication (login, FileVault, App Store, Apple Pay) |
| Native system prompt interception | FaceBridge cannot intercept or replace native Touch ID, Face ID, or Optic ID system dialogs |
| Nation-state adversaries | The project does not claim to defend against advanced persistent threats |
| Public internet operation | FaceBridge is designed for local network and BLE only |

## Security Boundaries

FaceBridge operates within a clearly defined boundary:

```
┌─────────────────────────────────────────────────────────┐
│                    Apple Platform Layer                   │
│  macOS login · FileVault · App Store · Apple Pay · sudo  │
│  Safari passwords · Keychain prompts · system Touch ID   │
│                                                          │
│  FaceBridge CANNOT access, intercept, or replace any     │
│  of these system-level authentication mechanisms.        │
├─────────────────────────────────────────────────────────┤
│                  FaceBridge Application Layer             │
│                                                          │
│  Pairing ceremony ──► Trust establishment                │
│  Authorization request ──► Biometric approval            │
│  Signed response ──► Protected action execution          │
│                                                          │
│  FaceBridge controls ONLY its own protected actions:     │
│  Unlock Secure Vault · Run Protected Command ·           │
│  Reveal Protected File                                   │
├─────────────────────────────────────────────────────────┤
│                     Transport Layer                       │
│  Local Network (TLS) · BLE (encrypted characteristics)   │
│                                                          │
│  FaceBridge relies on transport-layer security.          │
│  No application-layer end-to-end encryption yet.         │
└─────────────────────────────────────────────────────────┘
```

The boundary between FaceBridge and the Apple platform is absolute. FaceBridge does not hook into, extend, or replace any native authentication mechanism. It is a standalone application-layer authorization system.

## Experimental Status

This threat model describes the security properties of a research prototype. Key caveats:

- No third-party security audit has been performed
- Several mitigations are implemented but not fully wired (SAS UI, mandatory sender signatures)
- Transport security has known gaps (no certificate pinning, no E2E encryption)
- Trust lifecycle management is incomplete (no expiry, no revocation propagation)

The threat model is published for transparency and to support informed evaluation by security engineers and researchers. See [security-model.md](security-model.md) for implementation details and [limitations.md](limitations.md) for the complete list of known constraints.
