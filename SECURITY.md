# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in FaceBridge, please report it responsibly:

- Email: security@facebridge.dev (or open a private security advisory on GitHub)
- Do NOT open public issues for security vulnerabilities
- We will acknowledge receipt within 48 hours

## Threat Model

FaceBridge defends against the following threats in a local biometric authorization context.

### Replay Attacks

**Threat:** Attacker captures a valid response and replays it.

**Mitigation:**
- Every request includes a cryptographically secure nonce (32+ bytes from `SecRandomCopyBytes`)
- Nonces validated on creation: minimum 16 bytes, non-zero, via throwing `Nonce.init`
- Strict expiration window (default 30s) with future-date rejection (clock skew tolerance 30s)
- Used nonces tracked and rejected via `ReplayProtector` (bounded: max 10,000 entries with TTL eviction)
- Transport type bound into canonical signable to prevent cross-transport replay
- Sequence numbers in `MessageEnvelope` for anti-reordering
- Sessions consumed atomically — double-use rejected

### Forged Requests (Mac Origin Authenticity)

**Threat:** Attacker on local network sends a forged authorization request to iPhone.

**Mitigation:**
- `AuthorizationRequest` includes `senderSignature` — Mac signs the request with its device key
- iPhone verifies sender signature against stored public key before prompting biometrics
- Unsigned or incorrectly signed requests from unknown devices are rejected

### Device Impersonation

**Threat:** Attacker pretends to be a trusted device.

**Mitigation:**
- Device identity includes P-256 public key validated at creation (65 bytes, X9.63 uncompressed, 0x04 prefix)
- All pairing messages (invitation, acceptance, confirmation) are signed
- SAS (Short Authentication String) verification during pairing prevents MITM key substitution
- Trust stored in Keychain, verified by device ID + public key

### Man-in-the-Middle (Pairing)

**Threat:** Attacker intercepts and modifies pairing messages to substitute keys.

**Mitigation:**
- Pairing invitation, acceptance, and confirmation all include digital signatures
- SAS verification: both devices compute and display a 6-digit code derived from both public keys + pairing code
- Users must visually confirm SAS match before trust is established
- Pairing code has rate limiting (max attempts + time-windowed lockout)

### Transport Interception

**Threat:** Attacker intercepts messages on BLE or local network.

**Mitigation:**
- **BLE**: Characteristics use `readEncryptionRequired` / `writeEncryptionRequired` permissions. Unauthorized peers rejected before message processing.
- **Local Network**: TLS enabled by default. Plaintext TCP requires explicit `allowInsecure: true` flag.
- **Message layer**: `MessageEnvelope` supports HMAC-SHA256 authentication with canonical encoding
- BLE messages fragmented/reassembled transparently with CRC integrity checks

### Session & Payload Security

- `AuthorizationResponse` requires non-empty signature (minimum 64 bytes) and non-empty signedPayload — enforced by throwing init and Codable
- `SessionToken` uses 32 bytes of `SecRandomCopyBytes`, not UUID — enforced by Codable validation
- Session state machine enforces valid transitions only (pending → approved/denied/expired)
- `AuthorizationExecutor` verifies: requestId binding, responderDeviceId match, signedPayload integrity, trust status, biometric proof

### Input Validation & Codable Security

All security-critical types validate on deserialization:
- `Nonce`: minimum byte count, non-zero
- `DeviceIdentity`: public key format (65 bytes, 0x04 prefix), display name sanitized
- `AuthorizationResponse`: minimum signature size, non-empty payload
- `SessionToken`: minimum value length, valid base64

This prevents validation bypass through crafted JSON payloads.

### UI Spoofing

**Threat:** Attacker crafts a malicious reason string to trick user.

**Mitigation:**
- `DisplaySanitizer` strips bidi override characters (U+202E, U+202D, etc.), isolate characters, and control characters
- Length capping on displayed text
- Whitespace normalization
- Trust indicator in approval prompt distinguishes trusted vs unknown devices

### Policy Engine

- `PolicyEngine` enforces `requireBiometric`, `maxSessionTTL`, and proximity policies
- Biometric proof representation propagated end-to-end through `PolicyEnforcer` → `AuthorizationExecutor`
- Expired sessions rejected before any cryptographic operations

### Audit Logging

- All security events logged via `AuditLogger` actor (thread-safe)
- Critical events (pairing, revocation) use `await` — not fire-and-forget
- Agent lifecycle events (start/stop) logged with signal handling

## Known Limitations

| Limitation | Risk | Mitigation Plan |
|-----------|------|----------------|
| TLS uses system defaults, no certificate pinning | MITM if CA compromised | Future: pin to pairing-derived key material |
| No full E2E encryption | Relies on transport-layer protection | `SessionKeyDerivation` abstraction ready for E2E |
| Software keys in simulator/test | Private keys in Keychain, not hardware | Document as test-only; production requires Secure Enclave |
| No forward secrecy | Session compromise exposes past sessions | Future: ephemeral ECDH key exchange |
| `EncryptedAuditLogStore` key not persisted | Encrypted logs unrecoverable after restart | Future: persist key in Keychain |
| SwiftUI views are scaffolds | No real data displayed | Future: wire to data managers |

## Cryptographic Primitives

| Operation | Algorithm | Implementation |
|-----------|-----------|---------------|
| Key generation | P-256 ECDSA | Secure Enclave (`SecureEnclaveKeyManager`) or CryptoKit (`SoftwareKeyManager`) |
| Signing | ECDSA SHA-256 | `SecKeyCreateSignature` / CryptoKit |
| Verification | ECDSA SHA-256 | `SecKeyVerifySignature` |
| Hashing | SHA-256 | CryptoKit |
| Message auth | HMAC-SHA256 | CryptoKit |
| Key derivation | HKDF-SHA256 | CryptoKit |
| Random generation | `SecRandomCopyBytes` | Security framework |
| Encryption | AES-256-GCM | CryptoKit (audit log) |

## Supported Platforms

- iOS 17+ (Face ID / Touch ID required)
- macOS 14+ (companion app + background agent)
