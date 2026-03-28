# Security Policy

> FaceBridge is **experimental alpha software**.
> It is not intended for authentication bypass of macOS login, financial authorization, or any use case where compromise has safety or financial consequences.

## Reporting Security Issues

If you discover a security vulnerability in FaceBridge:

1. **Do NOT open a public GitHub issue.**
2. Use GitHub's [private security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability), or
3. Contact the maintainer directly via the channels listed in README.md.

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Suggested remediation if known

We will acknowledge receipt within 48 hours and provide a timeline for remediation.

## Threat Model

FaceBridge operates in a **local biometric authorization** context. The system assumes:

- Two devices (Mac + iPhone) on the same local network or BLE range
- An explicit pairing ceremony has been completed
- The iPhone has Face ID or Touch ID with enrolled biometrics
- The user physically confirms authorization prompts

### Threats Addressed

#### Replay Attacks

**Threat:** Attacker captures a valid authorization response and replays it.

**Mitigations:**
- Every request includes a cryptographically random nonce (minimum 16 bytes, `SecRandomCopyBytes`)
- Nonces validated at creation: minimum byte count, non-zero value
- `ReplayProtector` maintains a bounded set (max 10,000) with TTL-based eviction
- Future-dated nonces rejected (clock skew tolerance: 30 seconds)
- Transport type bound into signed payload (prevents cross-transport replay)
- `MessageEnvelope` supports sequence numbers for anti-reordering
- Sessions consumed atomically; double-use returns nil

#### Forged Authorization Requests

**Threat:** Attacker on local network sends a fake authorization request to iPhone.

**Mitigations:**
- `AuthorizationRequest` supports `senderSignature` field; Mac signs requests with its device key
- `AuthorizationResponder` verifies sender signature against stored public key when both signature and key are present
- Untrusted device IDs rejected before processing

**Limitation:** If `senderSignature` is nil or the sender's public key is not stored, the request is still processed if the `senderDeviceId` is in the trust store. This is a defense-in-depth gap documented in [LIMITATIONS.md](LIMITATIONS.md).

#### Forged Authorization Responses

**Threat:** Attacker forges a denial or approval response.

**Mitigations:**
- All response types (approved, denied, expired) require a non-empty signature (minimum 64 bytes) and non-empty signed payload
- Codable deserialization enforces these constraints; empty or undersized values are rejected
- `AuthorizationRequester` verifies: request ID binding, signed payload integrity against original signable, signature validity against stored public key

#### Device Impersonation

**Threat:** Attacker pretends to be a trusted device.

**Mitigations:**
- Device identity includes P-256 public key validated at creation (65 bytes, X9.63 uncompressed, 0x04 prefix)
- Public key validation runs on both `init` and Codable deserialization
- Trust stored in Keychain, verified by device ID + public key match

#### Man-in-the-Middle During Pairing

**Threat:** Attacker intercepts pairing to substitute public keys.

**Mitigations:**
- Pairing invitation, acceptance, and confirmation messages all include signature fields
- SAS (Short Authentication String) verification: both devices compute a 6-digit code from SHA-256 of both public keys + pairing code
- Rate limiting on pairing code verification (max attempts + time-windowed lockout)

**Limitation:** SAS verification logic is implemented and tested but not yet wired into the pairing UI flow. See [LIMITATIONS.md](LIMITATIONS.md).

#### Transport Interception

**Threat:** Attacker intercepts messages on BLE or local network.

**Mitigations:**
- **Local network:** TLS enabled by default. Plaintext TCP requires explicit `allowInsecure: true` flag.
- **BLE:** Characteristics published with `readEncryptionRequired` and `writeEncryptionRequired` permissions.
- **Message layer:** `MessageEnvelope` supports HMAC-SHA256 authentication over canonical encoding.
- BLE fragmentation uses CRC-32 integrity checks per fragment.

**Limitations:** No TLS certificate pinning. No full end-to-end encryption layer. See [LIMITATIONS.md](LIMITATIONS.md).

#### UI Spoofing

**Threat:** Attacker crafts malicious reason strings to mislead user.

**Mitigations:**
- `DisplaySanitizer` strips bidi override characters (U+202E, U+202D, etc.), isolate characters, and control characters
- Length capping and whitespace normalization
- Trust indicator distinguishes trusted vs unknown devices in approval prompt

#### Session Manipulation

**Threat:** Attacker attempts to reuse or transition sessions illegally.

**Mitigations:**
- Session state machine enforces: `pending` -> `approved`/`denied`/`expired` only
- Invalid transitions throw typed errors
- `SecureSessionHandler` atomically consumes sessions; second attempt returns nil
- Session tokens are 32-byte `SecRandomCopyBytes` (not UUID)
- Policy engine enforces biometric proof, TTL, and proximity requirements

### Trust Assumptions

1. The Secure Enclave on both devices is not compromised
2. The Keychain on both devices is not compromised
3. The pairing ceremony was performed in a physically secure environment
4. The user verifies the approval prompt before authenticating
5. LocalAuthentication framework correctly gates biometric access

### Device Compromise Model

- If the **iPhone** is compromised: the attacker could sign arbitrary responses. Biometric binding (`biometryCurrentSet`) means re-enrollment invalidates existing keys.
- If the **Mac** is compromised: the attacker could forge requests (if they extract the signing key from Keychain). Trust verification on the iPhone side limits impact.
- If **both** are compromised: the entire trust model is invalidated.

### Non-Goals

FaceBridge explicitly does **not** attempt to:

- Replace macOS system authentication (login, sudo, FileVault)
- Provide financial-grade authorization security
- Defend against nation-state adversaries
- Provide anonymity or metadata protection
- Operate over the internet (designed for local network/BLE only)
- Replace Apple's Touch ID or Optic ID system prompts

## Cryptographic Primitives

| Operation | Algorithm | Source |
|-----------|-----------|--------|
| Key generation | P-256 ECDSA | Secure Enclave (`SecureEnclaveKeyManager`) or CryptoKit (`SoftwareKeyManager`) |
| Signing | ECDSA-SHA256 | `SecKeyCreateSignature` / CryptoKit `P256.Signing` |
| Verification | ECDSA-SHA256 | `SecKeyVerifySignature` |
| Hashing | SHA-256 | CryptoKit |
| Message authentication | HMAC-SHA256 | CryptoKit |
| Key derivation | HKDF-SHA256 | CryptoKit |
| Random generation | `SecRandomCopyBytes` | Security framework |
| Encryption (audit log) | AES-256-GCM | CryptoKit |
| SAS computation | SHA-256 truncation | CryptoKit |

## Known Limitations

See [LIMITATIONS.md](LIMITATIONS.md) for the complete and honest list of current security constraints.
