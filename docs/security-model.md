# Security Model

This document describes the security model of FaceBridge: the threats it addresses, the assumptions it makes, the protections it implements, and the gaps that remain.

> **FaceBridge is experimental alpha software.** It has not undergone a third-party security audit. It is not intended for production use, financial authorization, or any context where compromise has safety or financial consequences.

## Design Intent

FaceBridge explores whether biometric authorization can be securely delegated from an iPhone to a Mac using only public Apple APIs. The security model is designed for a **local, paired-device context** — two devices owned by the same user, on the same network or within BLE range.

## Trust Assumptions

The security model depends on these assumptions being true:

1. The Secure Enclave on the iPhone is not compromised
2. The Keychain on both devices is not compromised
3. The pairing ceremony was performed in a physically secure environment
4. The user reviews and confirms authorization prompts before authenticating
5. Apple's `LocalAuthentication` framework correctly gates biometric access
6. The local network or BLE link is not under active, sophisticated attack during the initial pairing

## Threat Model

### Replay Attacks

**Threat.** An attacker captures a valid authorization response and replays it to gain unauthorized access.

**Mitigations.**

- Every request includes a cryptographically random nonce (minimum 16 bytes, generated via `SecRandomCopyBytes`)
- Nonces are validated at creation: minimum byte count, non-zero value
- `ReplayProtector` maintains a bounded set (maximum 10,000 entries) with TTL-based eviction
- Future-dated nonces are rejected with a configurable clock skew tolerance (default: 30 seconds)
- Transport type is bound into the signed payload, preventing cross-transport replay
- `MessageEnvelope` supports sequence numbers for anti-reordering
- Sessions are consumed atomically; a second consumption attempt returns nil

### Forged Authorization Requests

**Threat.** An attacker on the local network sends a fabricated authorization request to the iPhone.

**Mitigations.**

- `AuthorizationRequest` includes a `senderSignature` field; the Mac signs requests with its device key
- `AuthorizationResponder` verifies the sender signature against the stored public key when both the signature and key are present
- Untrusted device IDs are rejected before processing

**Residual risk.** If `senderSignature` is nil or the sender's public key is not in the trust store, the request is still processed if the `senderDeviceId` matches a trusted entry. This is a defense-in-depth gap documented in [limitations.md](limitations.md).

### Forged Authorization Responses

**Threat.** An attacker forges an approval or denial response.

**Mitigations.**

- All response types (approved, denied, expired) require a non-empty signature (minimum 64 bytes) and non-empty signed payload
- Codable deserialization enforces these constraints; empty or undersized values are rejected at decode time
- `AuthorizationRequester` verifies: request ID binding, signed payload integrity against the original signable, and signature validity against the stored public key

### Device Impersonation

**Threat.** An attacker pretends to be a trusted device.

**Mitigations.**

- Device identity includes a P-256 public key validated at creation (65 bytes, X9.63 uncompressed, `0x04` prefix)
- Public key validation runs on both `init` and Codable deserialization
- Trust is stored in Keychain, verified by device ID and public key match

### Man-in-the-Middle During Pairing

**Threat.** An attacker intercepts the pairing ceremony to substitute public keys.

**Mitigations.**

- Pairing invitation, acceptance, and confirmation messages all include digital signatures
- SAS (Short Authentication String) verification: both devices compute a 6-digit code from `SHA-256(initiatorPublicKey || responderPublicKey || pairingCode)`, allowing visual confirmation of key integrity
- Rate limiting on pairing code verification with configurable max attempts and time-windowed lockout

**Residual risk.** SAS verification logic is implemented and tested but not yet wired into the pairing UI flow. Until wired, MITM protection during pairing depends on the pairing code alone.

### Transport Interception

**Threat.** An attacker intercepts messages in transit over BLE or the local network.

**Mitigations.**

- **Local network:** TLS is enabled by default. Plaintext TCP requires an explicit `allowInsecure: true` flag.
- **BLE:** Characteristics are published with `readEncryptionRequired` and `writeEncryptionRequired` permissions.
- **Message layer:** `MessageEnvelope` supports HMAC-SHA256 authentication over a canonical encoding.
- BLE fragmentation uses CRC-32 integrity checks per fragment.

**Residual risk.** No TLS certificate pinning — connections use system-default certificate validation. No application-layer end-to-end encryption — message confidentiality relies entirely on transport-layer protection.

### UI Spoofing

**Threat.** An attacker crafts malicious reason strings to mislead the user into approving a request.

**Mitigations.**

- `DisplaySanitizer` strips bidirectional override characters (U+202E, U+202D), isolate characters, and control characters
- Length capping and whitespace normalization prevent visual overflow attacks
- Trust indicator in the approval prompt distinguishes trusted from unknown devices

### Session Manipulation

**Threat.** An attacker reuses or illegally transitions sessions.

**Mitigations.**

- Session state machine enforces: `pending` → `approved` / `denied` / `expired` only
- Invalid transitions throw typed errors
- `SecureSessionHandler` atomically consumes sessions; a second attempt returns nil
- Session tokens are 32-byte `SecRandomCopyBytes` values (not UUIDs)
- Policy engine enforces biometric proof, TTL, and proximity requirements

## Device Compromise Model

| Scenario | Impact | Mitigation |
|----------|--------|------------|
| **iPhone compromised** | Attacker could sign arbitrary responses | Biometric binding (`biometryCurrentSet`) means re-enrollment invalidates existing keys |
| **Mac compromised** | Attacker could forge requests | Trust verification on the iPhone limits impact; user must still approve via Face ID |
| **Both compromised** | The entire trust model is invalidated | No additional mitigation — this is outside the threat model |

## Cryptographic Primitives

| Operation | Algorithm | Source |
|-----------|-----------|--------|
| Key generation | P-256 ECDSA | Secure Enclave or CryptoKit |
| Signing | ECDSA-SHA256 | `SecKeyCreateSignature` / CryptoKit `P256.Signing` |
| Verification | ECDSA-SHA256 | `SecKeyVerifySignature` |
| Hashing | SHA-256 | CryptoKit |
| Message authentication | HMAC-SHA256 | CryptoKit |
| Key derivation | HKDF-SHA256 | CryptoKit |
| Random generation | `SecRandomCopyBytes` | Security framework |
| Encryption (audit) | AES-256-GCM | CryptoKit |
| SAS computation | SHA-256 truncation | CryptoKit |

## What Is Out of Scope

FaceBridge explicitly does **not** attempt to:

- Replace macOS system authentication (login, `sudo`, FileVault)
- Intercept or replace native Touch ID, Face ID, or Optic ID system prompts
- Intercept App Store purchase approval, Apple Pay, or Safari password prompts
- Provide financial-grade authorization security
- Defend against nation-state adversaries
- Provide anonymity or metadata protection
- Operate over the public internet (designed for local network and BLE only)
- Use private or undocumented Apple APIs

## Residual Risks

These are known gaps in the current alpha release. Each is documented in detail in [limitations.md](limitations.md).

| Risk | Severity | Notes |
|------|----------|-------|
| No forward secrecy | Medium | HKDF abstraction exists; ephemeral ECDH not wired |
| No application-layer E2E encryption | High | Relies on transport-layer protection only |
| No TLS certificate pinning | Medium | System-default validation; no binding to pairing trust |
| SAS not wired into pairing UI | Medium | Logic exists and is tested; needs UI integration |
| `senderSignature` optional on requests | Medium | Requests without signature still processed if sender is trusted |
| `MessageEnvelope` MAC optional | Low | Not enforced at transport level |
| Trust revocation is local only | Medium | No propagation to peer device |
| No third-party security audit | High | Not externally validated |

## What Would Be Required Before Production

1. Application-layer end-to-end encryption (ephemeral ECDH + AES-256-GCM)
2. TLS certificate pinning to pairing-derived key material
3. Forward secrecy via ephemeral session keys
4. Mandatory `senderSignature` on all requests
5. SAS verification wired into the pairing UI
6. Trust expiry and revocation propagation
7. Third-party penetration testing and security audit
8. Code signing, notarization, and App Store review
