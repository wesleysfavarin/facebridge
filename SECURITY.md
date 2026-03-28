# Security Policy

## Threat Model

FaceBridge is designed to defend against the following threats in a local biometric authorization context.

### Replay Attacks

**Threat:** An attacker captures a valid authorization response and replays it to gain unauthorized access.

**Mitigation:**
- Every authorization request includes a cryptographically secure nonce (32 bytes from `SecRandomCopyBytes`)
- Nonces have strict expiration windows (default: 30 seconds)
- Used nonces are tracked and rejected on reuse
- The `ReplayProtector` actor maintains a sliding window of consumed nonces

### Device Theft

**Threat:** An attacker gains physical access to a paired Mac or iPhone.

**Mitigation:**
- Private keys are stored in the Secure Enclave and require biometric authentication for use
- Keychain items are marked `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Trust relationships can be revoked from either device
- Session tokens expire quickly (default: 30 seconds)
- No biometric data is stored — only key references

### Man-in-the-Middle on LAN

**Threat:** An attacker intercepts or modifies messages between devices on the local network.

**Mitigation:**
- All authorization payloads are cryptographically signed using Secure Enclave keys
- Signature verification uses the pre-exchanged public key from pairing
- Tampered payloads fail verification and are rejected
- Transport layer supports BLE (short range) as primary channel

### Unauthorized Pairing

**Threat:** An attacker attempts to pair a rogue device without user consent.

**Mitigation:**
- Pairing requires explicit confirmation on both devices
- Pairing invitations have short TTL (default: 120 seconds)
- Pairing codes are generated from cryptographically secure random bytes
- Public key exchange happens only after mutual confirmation
- Users can review and revoke all trusted devices

### Signature Spoofing

**Threat:** An attacker forges a valid signature without access to the private key.

**Mitigation:**
- Keys are P-256 ECDSA generated in the Secure Enclave
- Private keys cannot be exported from the Secure Enclave
- Signature verification uses `SecKeyVerifySignature` with `.ecdsaSignatureMessageX962SHA256`
- Invalid signatures are logged as audit events

## Security Architecture

```
┌─────────────┐                    ┌─────────────┐
│   macOS      │   BLE / Network   │   iPhone     │
│              │◄──────────────────►│              │
│  Verify      │                    │  Sign        │
│  Public Key  │                    │  Private Key │
│  (Keychain)  │                    │  (Secure     │
│              │                    │   Enclave)   │
│  Nonce Gen   │                    │  Face ID     │
│  Replay Det  │                    │  Touch ID    │
│  Policy Eng  │                    │              │
│  Audit Log   │                    │  Audit Log   │
└─────────────┘                    └─────────────┘
```

## Key Management

| Property | Value |
|----------|-------|
| Algorithm | P-256 ECDSA |
| Key storage | Secure Enclave (hardware) |
| Key access | Biometric-gated via LocalAuthentication |
| Key export | Not possible (Secure Enclave) |
| Fallback | Software CryptoKit keys for testing/simulator |
| Keychain protection | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |

## Audit Logging

All security-relevant events are logged locally:

- `pairingInitiated` / `pairingCompleted` / `pairingRejected`
- `deviceRevoked`
- `authorizationRequested` / `authorizationApproved` / `authorizationDenied`
- `signatureVerificationFailed`
- `sessionExpired`
- `replayDetected`

## Reporting a Vulnerability

If you discover a security vulnerability in FaceBridge, please report it responsibly:

1. **Do not** open a public issue
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include a description of the vulnerability, steps to reproduce, and potential impact
4. Allow reasonable time for a fix before public disclosure

## Scope

FaceBridge operates exclusively within application-level authorization. It does not interact with:

- macOS system authentication (PAM, OpenDirectory)
- FileVault or disk encryption
- Apple Pay or Wallet
- System Keychain Access prompts
- Kernel extensions or system extensions

All functionality uses public Apple APIs only. No private APIs are used.
