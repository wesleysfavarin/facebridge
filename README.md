# FaceBridge

**Privacy-first biometric authorization bridge between iPhone and macOS.**

FaceBridge allows users to securely approve actions on macOS using Face ID or Touch ID from their iPhone, leveraging the Secure Enclave for cryptographic key management and challenge-response authorization.

## What FaceBridge Is

FaceBridge is a **secure authorization bridge** — not an authentication replacement. It provides a mechanism for applications and companion agents running on macOS to request biometric authorization from a trusted iPhone nearby.

Every authorization is backed by:

- Cryptographically signed challenge-response protocol
- Secure Enclave key generation (P-256 ECDSA)
- Nonce-based replay protection with expiration
- Explicit device pairing with Keychain-stored trust

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

1. Mac generates a pairing invitation (code or QR)
2. iPhone scans or enters the pairing code
3. Public keys are exchanged (P-256, Secure Enclave)
4. Both devices confirm trust explicitly
5. Trust relationship stored in Keychain

### Authorization

1. Mac generates a cryptographic nonce
2. Mac creates a signed authorization request
3. Request sent to iPhone via BLE or local network
4. iPhone prompts Face ID / Touch ID
5. iPhone signs the challenge payload using Secure Enclave key
6. Mac verifies the signature against the stored trusted public key
7. Mac executes the approved action
8. Event logged to audit trail

### Proximity Mode

FaceBridge uses BLE RSSI threshold detection. When a trusted device is nearby, a quick approval UI is presented. **Biometric confirmation is always required for sensitive operations.** FaceBridge never silently unlocks a macOS login session.

## Privacy Guarantees

- **No biometric data is ever stored or transmitted.** Biometric authentication only unlocks Secure Enclave key usage via LocalAuthentication.
- **All keys are device-bound.** Private keys never leave the Secure Enclave.
- **All communication is local.** No cloud servers, no internet required.
- **Explicit pairing required.** No silent trust establishment.
- **Full audit trail.** Every authorization event is logged locally.

## Security Architecture

| Layer | Technology |
|-------|-----------|
| Key generation | Secure Enclave (P-256 ECDSA) |
| Signing | ECDSA with SHA-256 |
| Key storage | Keychain Services (device-only) |
| Biometric gate | LocalAuthentication framework |
| Replay protection | Nonce + expiration window |
| Transport | BLE + Network framework (local only) |
| Trust model | Explicit pairing with revocation support |

## Limitations vs Touch ID

- FaceBridge cannot replace macOS system authentication prompts
- It requires an iPhone with Face ID or Touch ID
- BLE/network connectivity is required between devices
- It provides application-level authorization, not OS-level
- Latency depends on transport and biometric prompt speed

## Local-First Philosophy

FaceBridge is built on the principle that biometric authorization should be:

- **Local** — no cloud dependencies
- **Private** — no biometric data leaves the device
- **Transparent** — full audit logging
- **Revocable** — trust can be removed at any time
- **Open** — fully open-source, public APIs only

## Project Structure

```
FaceBridge/
├── Sources/
│   ├── FaceBridgeCore/          # Domain models, nonce, audit, policy
│   ├── FaceBridgeCrypto/        # Secure Enclave, signing, Keychain
│   ├── FaceBridgeProtocol/      # Authorization & pairing schemas
│   ├── FaceBridgeTransport/     # BLE + network transport
│   ├── FaceBridgeSharedUI/      # Shared SwiftUI components
│   ├── FaceBridgeiOSApp/        # iOS authenticator app
│   ├── FaceBridgeMacApp/        # macOS companion app
│   └── FaceBridgeMacAgent/      # macOS background agent
├── Tests/
│   ├── FaceBridgeCoreTests/
│   ├── FaceBridgeCryptoTests/
│   ├── FaceBridgeProtocolTests/
│   └── FaceBridgeTransportTests/
├── Package.swift
├── README.md
├── SECURITY.md
├── CONTRIBUTING.md
├── ROADMAP.md
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
