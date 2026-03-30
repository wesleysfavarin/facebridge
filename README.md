# FaceBridge

Experimental biometric authorization bridge between macOS and iPhone using Secure Enclave and public Apple APIs.

### Project Topics

`Swift` · `iOS` · `macOS` · `Secure Enclave` · `Face ID` · `Touch ID` · `Cryptography` · `Bluetooth` · `Local Network` · `Authentication` · `Security Engineering` · `Open Source`

---

FaceBridge explores whether biometric authorization can be securely delegated from an iPhone to a Mac using only public Apple APIs. It pairs a Mac with an iPhone, establishes a cryptographic trust relationship, and allows the Mac to request Face ID or Touch ID approval for application-defined protected actions.

> **Project Status: Experimental Alpha**
>
> - Real-device tested on Mac and iPhone
> - Built entirely with public Apple APIs
> - Alpha-quality — not production-ready
> - No third-party security audit performed
> - Published for research, experimentation, and community review

## What FaceBridge Can Do Today

- **Pair a Mac and iPhone** through an explicit pairing ceremony with signed message exchange
- **Establish trust** between devices using P-256 ECDSA keys backed by the Secure Enclave
- **Send signed authorization requests** from Mac to iPhone over local network or BLE
- **Approve requests with Face ID** on the iPhone, producing a cryptographically signed response
- **Verify signed responses** on the Mac using the iPhone's stored public key
- **Execute protected actions** on the Mac only after successful biometric approval
- **Reject replayed, expired, and forged requests** using nonce validation, TTL enforcement, and signature verification

### Protected Actions

FaceBridge includes three built-in protected actions that demonstrate the authorization flow:

| Action | What Happens After Approval |
|--------|----------------------------|
| **Unlock Secure Vault** | Reveals a protected content panel in the Mac app |
| **Run Protected Command** | Executes a predefined command (e.g., opens Safari) |
| **Reveal Protected File** | Displays hidden content in the Mac app |

## What FaceBridge Does NOT Do

- Does not replace macOS login, FileVault, or screen unlock
- Does not intercept App Store Touch ID prompts
- Does not intercept Safari or system password prompts
- Does not replace Apple Pay or Keychain authentication
- Does not intercept any native macOS or iOS system dialogs
- Does not use private or undocumented Apple APIs
- Does not operate over the public internet

## Design Goals

FaceBridge was built to explore a specific question: *can biometric authorization be delegated from one Apple device to another in a secure, verifiable way, using only public APIs?*

The project prioritizes:

- **Transparency** — all security properties and limitations are documented honestly
- **Verifiability** — authorization is based on signed messages, not trust-on-first-use
- **Separation of concerns** — the Mac requests, the iPhone authenticates, neither trusts the other implicitly
- **Public APIs only** — no private frameworks, no entitlement hacks, no system-level integration

### Non-Goals

- Production deployment
- System-level authentication replacement
- Financial or safety-critical authorization
- Cross-internet operation
- Apple platform endorsement

## Architecture

FaceBridge is organized as a Swift Package Manager workspace with eight modules:

```
FaceBridgeCore           Domain models, nonce, session, policy, audit
FaceBridgeCrypto         Secure Enclave, software keys, signing, SAS, HKDF
FaceBridgeProtocol       Authorization/pairing message schemas, envelope
FaceBridgeTransport      BLE + local network transport, fragmentation
FaceBridgeSharedUI       Shared SwiftUI components, display sanitizer
FaceBridgeiOSApp         iPhone authenticator application
FaceBridgeMacApp         macOS companion application
FaceBridgeMacAgent       macOS background authorization agent
```

Dependencies flow strictly downward: **Apps → UI/Transport → Protocol → Crypto → Core**.

See [docs/architecture.md](docs/architecture.md) for module responsibilities, flow diagrams, and the complete authorization sequence.

## Security

FaceBridge implements a defense-in-depth security model:

| Protection | Implementation |
|------------|----------------|
| Request authenticity | Mac signs requests with device key (ECDSA-SHA256) |
| Response authenticity | iPhone signs all responses with Secure Enclave key |
| Replay protection | Cryptographic nonces, bounded replay window, future-date rejection |
| Trust verification | Device identity validated by P-256 public key in Keychain |
| Session tokens | 32-byte `SecRandomCopyBytes`, atomically consumed |
| Transport integrity | HMAC-SHA256 message envelope with sequence numbers |
| LAN transport | TLS by default |
| BLE transport | Encryption-required characteristic permissions |
| Input validation | All security types validate on Codable deserialization |

See [docs/security-model.md](docs/security-model.md) for the full threat model and [docs/trust-model.md](docs/trust-model.md) for trust chain details.

## Real-Device Status

Pairing and authorization flows have been tested on physical Mac and iPhone hardware. The following flows are verified working:

1. Mac pairs with iPhone via signed invitation exchange
2. User triggers a protected action on the Mac
3. iPhone receives the request and displays an authorization prompt
4. User authenticates with Face ID
5. iPhone signs the response and sends it back to the Mac
6. Mac verifies the signature and executes the protected action

See [docs/real-device-testing.md](docs/real-device-testing.md) for setup instructions and troubleshooting.

## Limitations

Key limitations of the current alpha release:

- No application-layer end-to-end encryption (relies on transport-layer protection)
- No TLS certificate pinning
- No forward secrecy (HKDF abstraction exists; ephemeral ECDH not wired)
- SAS verification implemented but not yet displayed in pairing UI
- Trust revocation is manual and local only
- Not externally audited

See [docs/limitations.md](docs/limitations.md) for the complete list.

## Repository Map

```
├── Sources/
│   ├── FaceBridgeCore/          Domain models and business logic
│   ├── FaceBridgeCrypto/        Cryptographic operations
│   ├── FaceBridgeProtocol/      Message schemas and serialization
│   ├── FaceBridgeTransport/     BLE and local network transport
│   ├── FaceBridgeSharedUI/      Shared SwiftUI components
│   ├── FaceBridgeiOSApp/        iPhone authenticator app
│   ├── FaceBridgeMacApp/        macOS companion app
│   └── FaceBridgeMacAgent/      macOS background agent
├── Tests/                       145 tests across 32 suites
├── App/                         Xcode app targets (iOS, macOS, macOS Agent)
├── Resources/                   Entitlements, plists, privacy manifest
├── docs/                        Architecture, security, trust, and testing docs
├── .github/                     CI workflow and issue templates
├── Package.swift                Swift Package Manager manifest
└── project.yml                  Xcode project generation
```

## Getting Started

### Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 14.0+ (Sonoma) |
| iOS | 17.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

### Build with Swift Package Manager

```bash
git clone https://github.com/wesleysfavarin/facebridge.git
cd facebridge
swift build
```

### Build with Xcode

1. Open `Package.swift` in Xcode 15+
2. Select the desired scheme: `FaceBridgeMacApp`, `FaceBridgeiOSApp`, or `FaceBridgeMacAgent`
3. Build with Cmd+B

### Run Tests

```bash
swift test
```

145 tests across 32 suites — covering cryptographic operations, protocol integrity, transport security, session management, and replay protection.

### Run on Physical Devices

See [docs/real-device-testing.md](docs/real-device-testing.md) for complete setup instructions.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Module map, responsibilities, and authorization flow |
| [Security Model](docs/security-model.md) | Threat model, mitigations, and residual risks |
| [Trust Model](docs/trust-model.md) | Pairing, identity binding, and revocation |
| [Protocol Overview](docs/protocol-overview.md) | Request/response format, signing, and replay protection |
| [Limitations](docs/limitations.md) | Known constraints and scope boundaries |
| [Real-Device Testing](docs/real-device-testing.md) | Setup, testing, and troubleshooting guide |
| [Release Status](docs/release-status.md) | Current maturity, roadmap, and production requirements |

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting pull requests.

Security vulnerabilities should be reported privately — see [SECURITY.md](SECURITY.md#reporting-security-issues).

Areas where help is particularly valued:

- Transport reliability improvements
- Trust model hardening
- End-to-end encryption implementation
- Testing on diverse hardware configurations
- Documentation and developer experience

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Created by **Wesley Favarin**.

- GitHub: [github.com/wesleysfavarin](https://github.com/wesleysfavarin)
- LinkedIn: [linkedin.com/in/wesley-s-favarin-61249755](https://www.linkedin.com/in/wesley-s-favarin-61249755)

---

### Keywords

biometric authorization · secure enclave · face id authentication · macos ios trust model · cross device authentication · device pairing security · bluetooth authorization · local network authentication · distributed identity apple platforms
