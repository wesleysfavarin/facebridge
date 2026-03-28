# Architecture

FaceBridge is organized as a Swift Package Manager workspace with eight targets and clear dependency boundaries.

## Module Map

```
┌─────────────────────────────────────────────────────┐
│                    Applications                      │
│  FaceBridgeiOSApp  FaceBridgeMacApp  FaceBridgeMacAgent │
└──────┬──────────────────┬──────────────────┬────────┘
       │                  │                  │
       ▼                  ▼                  │
┌──────────────┐  ┌──────────────┐           │
│ FaceBridgeSharedUI │              │           │
└──────┬───────┘              │           │
       │                      │           │
       ▼                      ▼           ▼
┌──────────────────────────────────────────────┐
│            FaceBridgeTransport                │
│  (BLE, Local Network, Fragmentation, Encoder)│
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│            FaceBridgeProtocol                 │
│  (Request, Response, SessionToken, Envelope, │
│   Pairing Messages, Protocol Version)        │
└──────────────────┬───────────────────────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌──────────────┐     ┌──────────────────┐
│ FaceBridgeCrypto │  │  FaceBridgeCore  │
│ (SE, Software, │  │  (Models, Nonce, │
│  Signing, SAS, │  │  Session, Policy,│
│  HKDF, Keychain)│  │  Audit, Errors)  │
└──────────────┘     └──────────────────┘
```

## Module Responsibilities

### FaceBridgeCore

Domain models and business logic that have no cryptographic or transport dependencies.

| Type | Responsibility |
|------|---------------|
| `Nonce` | Validated nonce value type (min 16 bytes, non-zero, Codable-safe) |
| `NonceGenerator` | Secure random nonce generation via `SecRandomCopyBytes` |
| `Session` | Session lifecycle with strict state machine (pending -> approved/denied/expired) |
| `DeviceIdentity` | Device info with P-256 public key validation and display name sanitization |
| `TrustRelationship` | Trust record with revocation timestamp |
| `PolicyEngine` | Evaluates biometric, TTL, and proximity policies |
| `AuditLogger` | Actor-isolated audit event pipeline with bounded storage |
| `EncryptedAuditLogStore` | AES-256-GCM encrypted log persistence (primitives only) |
| `PairingCodeGenerator` | Secure 6-digit code generation with rate limiting and lockout |
| `PairingFlowController` | Orchestrates pairing code lifecycle |
| `ReplayProtector` | Bounded nonce tracking with TTL eviction and future-date rejection |
| `FaceBridgeError` | Typed error enum with 30+ specific error cases |

### FaceBridgeCrypto

All cryptographic operations. Depends only on FaceBridgeCore.

| Type | Responsibility |
|------|---------------|
| `SecureEnclaveKeyManager` | P-256 key generation in Secure Enclave with `biometryCurrentSet` binding |
| `SoftwareKeyManager` | CryptoKit-based P-256 keys for simulator/testing (stores in Keychain via protocol) |
| `KeyManaging` | Protocol abstracting key operations (generate, sign, export, delete) |
| `SignatureVerifier` | Verifies ECDSA-SHA256 signatures using `SecKeyVerifySignature` |
| `KeychainStore` | `SecureStorage` protocol implementation for Keychain Services |
| `ShortAuthenticationStringVerifier` | Computes and verifies 6-digit SAS from public keys + pairing code |
| `SessionKeyDerivation` | HKDF-SHA256 key derivation with context binding |
| `HashUtilities` | SHA-256 hashing utility |
| `KeyRotationManager` | Key rotation with audit logging |

### FaceBridgeProtocol

Message schemas and serialization. Depends on FaceBridgeCore.

| Type | Responsibility |
|------|---------------|
| `AuthorizationRequest` | Request with canonical length-prefixed `signable` and optional `senderSignature` |
| `AuthorizationResponse` | Response with mandatory `signature` (min 64 bytes) and `signedPayload` |
| `SessionToken` | Cryptographically random token (32-byte `SecRandomCopyBytes`, base64) |
| `MessageEnvelope` | Transport envelope with HMAC-SHA256 authentication and sequence numbers |
| `MessageEncoder` | JSON-based envelope serialization |
| `PairingInvitation/Acceptance/Confirmation` | Signed pairing messages with `signable` representations |
| `ProtocolVersion` | Semantic version for protocol compatibility |

### FaceBridgeTransport

Communication layer. Depends on FaceBridgeCore and FaceBridgeProtocol.

| Type | Responsibility |
|------|---------------|
| `LocalNetworkTransport` | Bonjour discovery + TLS listener (default) with length-prefixed framing |
| `BLETransport` | CoreBluetooth with encryption-required characteristics and peer authorization |
| `BLEFragmentationManager` | MTU-aware fragmentation with CRC-32 integrity and reassembly timeout |
| `ConnectionManager` | Multi-transport coordinator |
| `Transport` protocol | Abstraction for discovery, connection, send/receive |

### FaceBridgeSharedUI

Shared SwiftUI components. Depends on FaceBridgeCore and FaceBridgeProtocol.

| Type | Responsibility |
|------|---------------|
| `ApprovalPromptView` | Authorization approval UI with trust indicator |
| `TrustedDevicesListView` | Device management list |
| `DisplaySanitizer` | Strips bidi/control characters, normalizes whitespace, caps length |

### FaceBridgeiOSApp

iOS authenticator application.

| Type | Responsibility |
|------|---------------|
| `AuthorizationResponder` | Receives requests, verifies sender signature, prompts biometrics, signs responses |
| `BiometricAuthenticator` | LocalAuthentication wrapper with error mapping and reason sanitization |
| `DeviceTrustManager` | Manages trusted device identities in Keychain |

### FaceBridgeMacApp

macOS companion application.

| Type | Responsibility |
|------|---------------|
| `AuthorizationRequester` | Creates and signs authorization requests, verifies responses |
| `PairedDeviceManager` | Manages paired device identities in Keychain |
| `MenuBarController` | Menu bar UI state (thread-safe via `OSAllocatedUnfairLock`) |

### FaceBridgeMacAgent

macOS background agent (headless daemon).

| Type | Responsibility |
|------|---------------|
| `BackgroundListener` | Request queue with rate limiting, overflow protection, stuck recovery |
| `SecureSessionHandler` | Session creation, validation, and atomic consumption |
| `AuthorizationExecutor` | Full verification: request binding, device identity, payload integrity, biometric proof |
| `PolicyEnforcer` | Bridges `PolicyEngine` with biometric proof propagation |
| `TrustedDeviceVerifier` | Reads trusted devices from Keychain for verification |

## Pairing Flow

```
Mac                                     iPhone
 │                                        │
 │  1. Generate pairing code              │
 │  2. Create PairingInvitation           │
 │     (deviceId, publicKey, code, sig)   │
 │ ─────────────────────────────────────> │
 │                                        │  3. Verify invitation signature
 │                                        │  4. Validate pairing code
 │                                        │  5. Create PairingAcceptance
 │                                        │     (deviceId, publicKey, sig)
 │ <───────────────────────────────────── │
 │  6. Verify acceptance signature        │
 │  7. Compute SAS from both public keys  │  7. Compute SAS from both public keys
 │  8. Display SAS for user confirmation  │  8. Display SAS for user confirmation
 │  9. Create PairingConfirmation (sig)   │  9. Create PairingConfirmation (sig)
 │ <─────────────────────────────────────>│
 │ 10. Store trust in Keychain            │ 10. Store trust in Keychain
```

**Current status:** Steps 1-6, 9-10 are implemented. Steps 7-8 (SAS display in UI) are not yet wired.

## Authorization Flow

```
Mac (Requester)                          iPhone (Responder)
 │                                        │
 │  1. Generate nonce + challenge         │
 │  2. Build AuthorizationRequest         │
 │  3. Sign request (senderSignature)     │
 │  4. Wrap in MessageEnvelope            │
 │ ─────────────────────────────────────> │
 │                                        │  5. Verify sender signature (if present)
 │                                        │  6. Check trust store
 │                                        │  7. Validate nonce (replay, future-date)
 │                                        │  8. Prompt biometric authentication
 │                                        │  9. Sign canonical payload
 │                                        │ 10. Build AuthorizationResponse
 │ <───────────────────────────────────── │
 │ 11. Verify requestId binding           │
 │ 12. Verify signedPayload integrity     │
 │ 13. Verify signature                   │
 │ 14. Execute authorized action          │
 │ 15. Log to audit trail                 │
```

## Session Lifecycle

```
                 ┌──────────┐
                 │ pending  │
                 └────┬─────┘
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
    ┌──────────┐ ┌─────────┐ ┌─────────┐
    │ approved │ │ denied  │ │ expired │
    └──────────┘ └─────────┘ └─────────┘
```

- Only `pending` can transition to another state.
- If `approve()` is called on an expired session, state is set to `expired` and `sessionExpired` is thrown.
- All other invalid transitions throw `invalidStateTransition`.
- Sessions are consumed atomically by `SecureSessionHandler`; second consumption returns nil.

## Crypto Primitives

| Operation | Algorithm | Key Size |
|-----------|-----------|----------|
| Key generation | P-256 ECDSA | 256-bit |
| Signing | ECDSA with SHA-256 | P-256 |
| Message authentication | HMAC-SHA256 | 256-bit |
| Key derivation | HKDF-SHA256 | 256-bit output |
| Hashing | SHA-256 | 256-bit |
| Encryption (audit) | AES-256-GCM | 256-bit |
| Random generation | `SecRandomCopyBytes` | Variable |

## Secure Enclave Usage

- Keys generated with `kSecAttrTokenIDSecureEnclave` and access control flags `[.privateKeyUsage, .biometryCurrentSet]`
- Private keys never leave the Secure Enclave
- Key invalidated if biometric enrollment changes
- Available on physical iOS devices only; simulator falls back to `SoftwareKeyManager`
