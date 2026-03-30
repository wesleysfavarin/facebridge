# Repository Map

A guide for first-time contributors and reviewers to navigate the FaceBridge codebase.

## Top-Level Structure

```
facebridge/
├── Sources/                 Swift source code (8 modules)
├── Tests/                   Unit and integration tests (8 files, 145 tests)
├── App/                     Xcode app target configuration (entitlements, plists)
├── Resources/               Shared entitlements, privacy manifest, agent plist
├── docs/                    Architecture, security, trust, protocol, and testing docs
├── .github/                 CI workflows, issue templates, PR template
├── Package.swift            Swift Package Manager manifest
├── project.yml              Xcode project generation (xcodegen)
├── README.md                Project overview and entry point
├── SECURITY.md              Security policy and reporting
├── CONTRIBUTING.md          Contribution guidelines
├── CHANGELOG.md             Version history
├── CODE_OF_CONDUCT.md       Contributor Covenant
└── LICENSE                  MIT License
```

## Source Modules

Dependencies flow strictly downward: **Apps → UI/Transport → Protocol → Crypto → Core**.

### FaceBridgeCore — `Sources/FaceBridgeCore/`

Foundation layer with no external dependencies. Start here to understand domain types.

| File | What it defines |
|------|----------------|
| `DeviceIdentity.swift` | Device identity with P-256 public key validation |
| `Session.swift` | Session lifecycle state machine |
| `TrustRelationship.swift` | Trust record with revocation support |
| `Nonce.swift` | Validated nonce value type |
| `ReplayProtection.swift` | Bounded nonce tracking with TTL eviction |
| `PolicyEngine.swift` | Biometric, TTL, and proximity policy evaluation |
| `PairingFlowController.swift` | Pairing state machine |
| `PairingCodeGenerator.swift` | Secure 6-digit code with rate limiting |
| `AuditLog.swift` | Audit event pipeline |
| `Errors.swift` | `FaceBridgeError` enum (30+ cases) |

### FaceBridgeCrypto — `Sources/FaceBridgeCrypto/`

All cryptographic operations. Depends on Core.

| File | What it defines |
|------|----------------|
| `SecureEnclaveKeyManager.swift` | Secure Enclave P-256 key generation |
| `SoftwareKeyManager.swift` | CryptoKit fallback for simulator |
| `SignatureService.swift` | ECDSA-SHA256 signing and verification |
| `KeychainStore.swift` | Keychain Services integration |
| `ShortAuthenticationStringVerifier.swift` | SAS computation for pairing |
| `SessionKeyDerivation.swift` | HKDF-SHA256 key derivation |
| `KeyRotationManager.swift` | Key rotation with audit logging |

### FaceBridgeProtocol — `Sources/FaceBridgeProtocol/`

Message schemas. Depends on Core.

| File | What it defines |
|------|----------------|
| `AuthorizationRequest.swift` | Request with canonical signable and sender signature |
| `AuthorizationResponse.swift` | Response with mandatory signature validation |
| `PairingMessage.swift` | Invitation, acceptance, and confirmation messages |
| `MessageEnvelope.swift` | Transport envelope with HMAC and sequence numbers |
| `SessionToken.swift` | 32-byte cryptographic session token |
| `ProtocolVersion.swift` | Semantic versioning for protocol compatibility |

### FaceBridgeTransport — `Sources/FaceBridgeTransport/`

Communication layer. Depends on Core and Protocol.

| File | What it defines |
|------|----------------|
| `TransportProtocol.swift` | `Transport` protocol abstraction |
| `LocalNetworkTransport.swift` | Bonjour discovery + TLS listener |
| `BLETransport.swift` | CoreBluetooth with encrypted characteristics |
| `BLEFragmentationManager.swift` | MTU-aware fragmentation with CRC-32 |
| `ConnectionManager.swift` | Multi-transport coordinator |

### FaceBridgeSharedUI — `Sources/FaceBridgeSharedUI/`

Shared SwiftUI components. Depends on Core and Protocol.

### FaceBridgeiOSApp — `Sources/FaceBridgeiOSApp/`

iPhone authenticator. Start with `iOSCoordinator.swift` for the orchestration logic.

### FaceBridgeMacApp — `Sources/FaceBridgeMacApp/`

macOS companion app. Start with `MacCoordinator.swift` for orchestration.

### FaceBridgeMacAgent — `Sources/FaceBridgeMacAgent/`

Background daemon. Start with `BackgroundListener.swift` for the request queue.

## Tests

```
Tests/
├── FaceBridgeCoreTests/        Nonce, pairing flow, policy engine
├── FaceBridgeCryptoTests/      Key generation, signing, verification
├── FaceBridgeProtocolTests/    Protocol integrity, authorization flow integration
├── FaceBridgeTransportTests/   Transport abstraction tests
└── FaceBridgeMacAgentTests/    Agent pipeline tests
```

## App Configuration

```
App/
├── iOS/          FaceBridgeiOS.entitlements, Info.plist
├── macOS/        FaceBridgeMac.entitlements, Info.plist
└── macOSAgent/   FaceBridgeAgent.entitlements, Info.plist
```

## Where to Start Reading

| Goal | Start here |
|------|-----------|
| Understand the domain types | `Sources/FaceBridgeCore/DeviceIdentity.swift`, `Session.swift`, `Errors.swift` |
| Understand cryptographic operations | `Sources/FaceBridgeCrypto/SecureEnclaveKeyManager.swift`, `SignatureService.swift` |
| Understand the authorization protocol | `Sources/FaceBridgeProtocol/AuthorizationRequest.swift`, `AuthorizationResponse.swift` |
| Understand transport | `Sources/FaceBridgeTransport/TransportProtocol.swift`, `ConnectionManager.swift` |
| Understand the Mac authorization flow | `Sources/FaceBridgeMacApp/MacCoordinator.swift`, `AuthorizationRequester.swift` |
| Understand the iPhone authentication flow | `Sources/FaceBridgeiOSApp/iOSCoordinator.swift`, `AuthorizationResponder.swift` |
| Understand the pairing ceremony | `Sources/FaceBridgeCore/PairingFlowController.swift` |
| Run and test the project | [docs/real-device-testing.md](real-device-testing.md) |

## Documentation

| Document | What it covers |
|----------|---------------|
| [Architecture](architecture.md) | Module map, authorization flow, pairing flow, session lifecycle |
| [Security Model](security-model.md) | Threat model, mitigations, cryptographic primitives, residual risks |
| [Threat Model](threat-model.md) | Protected assets, addressed/unaddressed threats, security boundaries |
| [Trust Model](trust-model.md) | Pairing ceremony, identity binding, revocation |
| [Protocol Overview](protocol-overview.md) | Request/response format, signing, replay protection |
| [Limitations](limitations.md) | Known constraints and scope boundaries |
| [Real-Device Testing](real-device-testing.md) | Setup, test scenarios, troubleshooting |
| [Release Status](release-status.md) | Current maturity, roadmap |
