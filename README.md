# FaceBridge

**Privacy-first biometric authorization bridge between iPhone and macOS.**

> **Status: Public Alpha** — Security-hardened, tested, not yet production-ready. See [RELEASE_READINESS.md](RELEASE_READINESS.md).

FaceBridge allows users to securely approve actions on macOS using Face ID or Touch ID from their iPhone, leveraging the Secure Enclave for cryptographic key management and challenge-response authorization.

## What FaceBridge Is

FaceBridge is a **secure authorization bridge** — not an authentication replacement. It provides a mechanism for applications and companion agents running on macOS to request biometric authorization from a trusted iPhone nearby.

Every authorization is backed by:

- Cryptographically signed challenge-response protocol (ECDSA P-256)
- Secure Enclave key generation with biometric binding
- Nonce-based replay protection with expiration and future-date rejection
- Explicit device pairing with Keychain-stored trust
- Mac-side request signing for origin authenticity
- HMAC-SHA256 message envelope authentication
- Validated Codable deserialization for all security-critical types

## What FaceBridge Is NOT

FaceBridge does **not** replace:

- macOS login authentication
- FileVault unlock
- Apple Pay authorization
- Secure Enclave system identity
- Native Touch ID / Optic ID behavior

FaceBridge only provides authorization workflows inside supported applications using **public Apple APIs**.

## How It Works

### Pairing

1. Mac generates a signed pairing invitation (code + signature)
2. iPhone scans or enters the pairing code
3. Public keys are exchanged (P-256, Secure Enclave on device / Software keys in simulator)
4. SAS (Short Authentication String) verification confirms key material matches
5. Both devices confirm trust explicitly with signed confirmation
6. Trust relationship stored in Keychain

### Authorization

1. Mac generates a cryptographic nonce
2. Mac creates and **signs** an authorization request (proving Mac identity)
3. Request sent to iPhone via BLE (encrypted characteristics) or local network (TLS default)
4. iPhone **verifies sender signature** against stored public key
5. iPhone prompts Face ID / Touch ID
6. iPhone signs the canonical challenge payload using Secure Enclave key
7. Mac verifies the response signature, request binding, and payload integrity
8. Mac executes the approved action
9. Event logged to audit trail

### Transport Security

| Transport | Default Mode | Encryption |
|-----------|-------------|------------|
| BLE | Encrypted characteristics | Link-layer encryption required |
| Local Network | TLS (default) | Plaintext only with explicit `allowInsecure: true` flag |

BLE messages are fragmented/reassembled transparently via `BLEFragmentationManager` for payloads exceeding MTU.

All messages use `MessageEnvelope` with optional HMAC-SHA256 authentication and sequence numbers for anti-reordering.

## Privacy Guarantees

- **No biometric data is ever stored or transmitted.** Biometric authentication only unlocks Secure Enclave key usage via LocalAuthentication.
- **All keys are device-bound.** Private keys never leave the Secure Enclave.
- **All communication is local.** No cloud servers, no internet required.
- **Explicit pairing required.** No silent trust establishment.
- **Full audit trail.** Every authorization event is logged locally.

## Security Architecture

| Layer | Technology |
|-------|-----------|
| Key generation | Secure Enclave (P-256 ECDSA, biometryCurrentSet) |
| Signing | ECDSA with SHA-256 |
| Key storage | Keychain Services (device-only) |
| Biometric gate | LocalAuthentication framework |
| Replay protection | Nonce + expiration + future-date rejection |
| Message integrity | HMAC-SHA256 with sequence numbers |
| Transport (BLE) | Encryption-required characteristics + fragmentation |
| Transport (LAN) | TLS by default |
| Request authenticity | Mac signs requests, iPhone verifies |
| Trust model | Explicit pairing with revocation support |
| Input validation | Codable deserialization validates all security fields |
| UI safety | DisplaySanitizer strips bidi/control characters |

## Canonical Code Paths

Each security responsibility has exactly one canonical implementation:

| Responsibility | Canonical File |
|---------------|---------------|
| Nonce generation | `FaceBridgeCore/Nonce.swift` (NonceGenerator) |
| Session tokens | `FaceBridgeProtocol/SessionToken.swift` |
| Request signing | `FaceBridgeProtocol/AuthorizationRequest.swift` (length-prefixed signable) |
| Response signing | `FaceBridgeProtocol/AuthorizationResponse.swift` (mandatory signatures) |
| Session handling | `FaceBridgeMacAgent/SecureSessionHandler.swift` |
| Policy enforcement | `FaceBridgeCore/PolicyEngine.swift` + `FaceBridgeMacAgent/PolicyEnforcer.swift` |
| Signature verification | `FaceBridgeCrypto/SignatureService.swift` (SignatureVerifier) |
| Key management | `FaceBridgeCrypto/SecureEnclaveKeyManager.swift` (production) / `SoftwareKeyManager.swift` (test/simulator) |
| BLE transport | `FaceBridgeTransport/BLETransport.swift` + `BLEFragmentationManager.swift` |
| LAN transport | `FaceBridgeTransport/LocalNetworkTransport.swift` (TLS default) |
| Audit logging | `FaceBridgeCore/AuditLog.swift` (AuditLogger actor) |
| Pairing flow | `FaceBridgeCore/PairingFlowController.swift` |

## Known Limitations

- **Software keys in simulator/tests**: `SoftwareKeyManager` is used when Secure Enclave is unavailable. Private keys are stored in Keychain, not hardware-protected.
- **No full E2E encryption yet**: Message confidentiality relies on transport-level protection (BLE link encryption, TLS). Session key derivation abstraction exists (`SessionKeyDerivation.swift`) for future E2E.
- **SwiftUI views are scaffolds**: UI views load empty state; real data loading depends on full app integration.
- **No certificate pinning**: TLS uses system defaults. Future work: pin to pairing-derived key material.
- **Forward secrecy not implemented**: HKDF abstraction exists but ephemeral DH key exchange is not yet wired.

## Project Structure

```
FaceBridge/
├── Sources/
│   ├── FaceBridgeCore/          # Domain models, nonce, audit, policy, session
│   ├── FaceBridgeCrypto/        # Secure Enclave, signing, Keychain, SAS, HKDF
│   ├── FaceBridgeProtocol/      # Authorization & pairing schemas, envelope
│   ├── FaceBridgeTransport/     # BLE + network transport, fragmentation
│   ├── FaceBridgeSharedUI/      # Shared SwiftUI components, sanitizer
│   ├── FaceBridgeiOSApp/        # iOS authenticator app
│   ├── FaceBridgeMacApp/        # macOS companion app
│   └── FaceBridgeMacAgent/      # macOS background agent
├── Tests/
│   ├── FaceBridgeCoreTests/
│   ├── FaceBridgeCryptoTests/
│   ├── FaceBridgeProtocolTests/
│   ├── FaceBridgeTransportTests/
│   └── FaceBridgeMacAgentTests/
├── Package.swift
├── README.md
├── SECURITY.md
├── CONTRIBUTING.md
├── ROADMAP.md
├── RELEASE_READINESS.md
└── LICENSE
```

## Requirements

- iOS 17+ / macOS 14+
- Xcode 15+
- Swift 5.9+

## Building

```bash
swift build
```

## Testing

```bash
swift test
# 145 tests across 32 suites
```

## Why FaceBridge Exists

Modern Macs lack external biometric authorization options outside Apple's Magic Keyboard with Touch ID. Many users already carry an iPhone with Face ID — a device with a Secure Enclave capable of strong biometric-gated cryptographic operations.

FaceBridge explores a **privacy-respecting, open-source alternative** authorization bridge using the iPhone Secure Enclave. It is built entirely on public Apple APIs and designed for transparency, auditability, and developer extensibility.

## Author

**Wesley Favarin**

- GitHub: [github.com/wesleysfavarin](https://github.com/wesleysfavarin)
- Medium: [medium.com/@wesleysfavarin](https://medium.com/@wesleysfavarin)
- LinkedIn: [linkedin.com/in/wesley-s-favarin-61249755](https://www.linkedin.com/in/wesley-s-favarin-61249755)

## License

MIT License — see [LICENSE](LICENSE) for details.
