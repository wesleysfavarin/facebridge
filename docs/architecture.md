# Architecture

FaceBridge is organized as a Swift Package Manager workspace with eight modules and clear dependency boundaries. Each module has a single area of responsibility, and dependencies flow strictly downward.

## Module Map

```
┌──────────────────────────────────────────────────────────┐
│                      Applications                         │
│   FaceBridgeiOSApp    FaceBridgeMacApp    FaceBridgeMacAgent  │
└────────┬─────────────────┬──────────────────┬────────────┘
         │                 │                  │
         ▼                 ▼                  │
  ┌──────────────────┐                       │
  │  FaceBridgeSharedUI  │                       │
  └────────┬─────────┘                       │
           │                                 │
           ▼                 ▼               ▼
  ┌────────────────────────────────────────────────────┐
  │               FaceBridgeTransport                   │
  │    BLE · Local Network · Fragmentation · Encoder    │
  └──────────────────────┬─────────────────────────────┘
                         │
                         ▼
  ┌────────────────────────────────────────────────────┐
  │               FaceBridgeProtocol                    │
  │    Request · Response · Session · Envelope · Pairing │
  └──────────────────────┬─────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
  ┌──────────────────┐     ┌───────────────────┐
  │  FaceBridgeCrypto │     │   FaceBridgeCore   │
  │  Secure Enclave   │     │   Domain Models    │
  │  Signing · SAS    │     │   Nonce · Session  │
  │  HKDF · Keychain  │     │   Policy · Audit   │
  └──────────────────┘     └───────────────────┘
```

## Module Responsibilities

### FaceBridgeCore

Domain models and business logic with no cryptographic or transport dependencies.

| Type | Responsibility |
|------|----------------|
| `Nonce` | Validated nonce value type — minimum 16 bytes, non-zero, Codable-safe |
| `NonceGenerator` | Secure random nonce generation via `SecRandomCopyBytes` |
| `Session` | Session lifecycle with strict state machine transitions |
| `DeviceIdentity` | Device identity with P-256 public key validation and display name sanitization |
| `TrustRelationship` | Trust record with revocation timestamp |
| `PolicyEngine` | Evaluates biometric, TTL, and proximity policies |
| `AuditLogger` | Actor-isolated audit event pipeline with bounded storage |
| `PairingCodeGenerator` | Secure 6-digit code generation with rate limiting and lockout |
| `ReplayProtector` | Bounded nonce tracking with TTL eviction and future-date rejection |
| `FaceBridgeError` | Typed error enum with 30+ specific error cases |

### FaceBridgeCrypto

All cryptographic operations. Depends only on `FaceBridgeCore`.

| Type | Responsibility |
|------|----------------|
| `SecureEnclaveKeyManager` | P-256 key generation in Secure Enclave with `biometryCurrentSet` binding |
| `SoftwareKeyManager` | CryptoKit-based P-256 keys for simulator and testing |
| `KeyManaging` | Protocol abstracting key operations |
| `SignatureVerifier` | ECDSA-SHA256 signature verification via `SecKeyVerifySignature` |
| `KeychainStore` | Keychain Services integration via `SecureStorage` protocol |
| `ShortAuthenticationStringVerifier` | 6-digit SAS computation from public keys and pairing code |
| `SessionKeyDerivation` | HKDF-SHA256 key derivation with context binding |
| `KeyRotationManager` | Key rotation with audit logging |

### FaceBridgeProtocol

Message schemas and serialization. Depends on `FaceBridgeCore`.

| Type | Responsibility |
|------|----------------|
| `AuthorizationRequest` | Request with canonical length-prefixed `signable` and optional `senderSignature` |
| `AuthorizationResponse` | Response with mandatory `signature` (min 64 bytes) and `signedPayload` |
| `SessionToken` | 32-byte `SecRandomCopyBytes` token, base64-encoded |
| `MessageEnvelope` | Transport envelope with HMAC-SHA256 authentication and sequence numbers |
| `PairingInvitation` / `PairingAcceptance` / `PairingConfirmation` | Signed pairing messages |
| `ProtocolVersion` | Semantic version for protocol compatibility |

### FaceBridgeTransport

Communication layer. Depends on `FaceBridgeCore` and `FaceBridgeProtocol`.

| Type | Responsibility |
|------|----------------|
| `LocalNetworkTransport` | Bonjour discovery and TLS listener with length-prefixed framing |
| `BLETransport` | CoreBluetooth with encryption-required characteristics and peer authorization |
| `BLEFragmentationManager` | MTU-aware fragmentation with CRC-32 integrity and reassembly timeout |
| `ConnectionManager` | Multi-transport coordinator |
| `Transport` protocol | Abstraction for discovery, connection, send, and receive |

### FaceBridgeSharedUI

Shared SwiftUI components. Depends on `FaceBridgeCore` and `FaceBridgeProtocol`.

| Type | Responsibility |
|------|----------------|
| `ApprovalPromptView` | Authorization approval UI with trust indicator |
| `TrustedDevicesListView` | Device management list |
| `DisplaySanitizer` | Strips bidi/control characters, normalizes whitespace, caps length |

### FaceBridgeiOSApp

iOS authenticator application. Receives authorization requests and responds with biometric proof.

| Type | Responsibility |
|------|----------------|
| `iOSCoordinator` | Orchestrates transport, trust, and authorization on iOS |
| `AuthorizationResponder` | Verifies sender signature, prompts biometrics, signs responses |
| `BiometricAuthenticator` | `LocalAuthentication` wrapper with error mapping |
| `DeviceTrustManager` | Manages trusted device identities in Keychain |

### FaceBridgeMacApp

macOS companion application. Initiates authorization requests for protected actions.

| Type | Responsibility |
|------|----------------|
| `MacCoordinator` | Orchestrates transport, trust, protected actions, and routing on Mac |
| `AuthorizationRequester` | Creates and signs authorization requests, verifies responses |
| `PairedDeviceManager` | Manages paired device identities in Keychain |

### FaceBridgeMacAgent

macOS background agent (headless daemon).

| Type | Responsibility |
|------|----------------|
| `BackgroundListener` | Request queue with rate limiting, overflow protection, stuck recovery |
| `SecureSessionHandler` | Session creation, validation, and atomic consumption |
| `AuthorizationExecutor` | Full verification pipeline: request binding, identity, payload, biometric proof |
| `PolicyEnforcer` | Bridges `PolicyEngine` with biometric proof propagation |
| `TrustedDeviceVerifier` | Reads trusted devices from Keychain for verification |

## Application Roles

### Mac as Requester

The Mac app acts as the **authorization requester**. When the user triggers a protected action, the Mac:

1. Creates an `AuthorizationRequest` with a fresh nonce, challenge, and reason
2. Signs the request with its device key
3. Routes the request to the paired iPhone via the best available transport
4. Waits for the signed response
5. Verifies the response and executes the protected action if approved

### iPhone as Authenticator

The iPhone app acts as the **biometric authenticator**. When a request arrives, the iPhone:

1. Verifies the sender's signature against the stored public key
2. Checks the trust store for the sender device
3. Validates the nonce against replay protection
4. Presents the authorization prompt to the user
5. Authenticates with Face ID or Touch ID
6. Signs the canonical response payload with its Secure Enclave key
7. Returns the signed response to the Mac

### Mac Agent as Background Processor

The Mac agent runs as a headless daemon for background authorization processing. It handles the full verification pipeline without a GUI.

## Pairing Flow

```
Mac                                        iPhone
 │                                           │
 │  1. Generate 6-digit pairing code         │
 │  2. Create PairingInvitation              │
 │     (deviceId, publicKey, code, sig)      │
 │ ────────────────────────────────────────> │
 │                                           │  3. Verify invitation signature
 │                                           │  4. Validate pairing code
 │                                           │  5. Create PairingAcceptance
 │                                           │     (deviceId, publicKey, sig)
 │ <──────────────────────────────────────── │
 │  6. Verify acceptance signature           │
 │  7. Compute SAS (both sides)              │  7. Compute SAS (both sides)
 │  8. Display SAS for confirmation          │  8. Display SAS for confirmation
 │  9. Create PairingConfirmation (sig)      │  9. Create PairingConfirmation (sig)
 │ <────────────────────────────────────────>│
 │ 10. Store trust in Keychain               │ 10. Store trust in Keychain
```

> **Current status:** Steps 1–6 and 9–10 are implemented and tested. Steps 7–8 (SAS display in the pairing UI) are implemented as primitives but not yet wired into the user interface.

## Authorization Flow

This is the end-to-end flow when a user triggers a protected action on the Mac.

```
Mac (Requester)                             iPhone (Authenticator)
 │                                           │
 │  1. User triggers protected action        │
 │  2. Generate nonce + challenge            │
 │  3. Build AuthorizationRequest            │
 │  4. Sign request (senderSignature)        │
 │  5. Wrap in MessageEnvelope               │
 │  6. Route via best available transport    │
 │ ────────────────────────────────────────> │
 │                                           │  7. Unwrap envelope
 │                                           │  8. Verify sender signature
 │                                           │  9. Check trust store
 │                                           │ 10. Validate nonce (replay + future)
 │                                           │ 11. Present authorization prompt
 │                                           │ 12. Authenticate with Face ID
 │                                           │ 13. Sign canonical payload
 │                                           │ 14. Build AuthorizationResponse
 │ <──────────────────────────────────────── │
 │ 15. Verify requestId binding              │
 │ 16. Verify signedPayload integrity        │
 │ 17. Verify signature                      │
 │ 18. Execute protected action              │
 │ 19. Log to audit trail                    │
```

## Protected Action Flow

FaceBridge defines three protected actions that are controlled entirely within the application:

| Action | What Happens After Approval |
|--------|----------------------------|
| **Unlock Secure Vault** | Reveals a protected content panel in the Mac UI |
| **Run Protected Command** | Executes a predefined command (e.g., opens Safari) |
| **Reveal Protected File** | Displays hidden content in the Mac UI |

Each action follows the same authorization flow. The Mac sets `activeAction` before sending the request, and upon receiving a verified approval response, dispatches the corresponding action handler.

## Session Lifecycle

```
              ┌──────────┐
              │  pending  │
              └─────┬─────┘
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
 ┌──────────┐ ┌──────────┐ ┌──────────┐
 │ approved │ │  denied  │ │ expired  │
 └──────────┘ └──────────┘ └──────────┘
```

- Only `pending` sessions can transition to another state.
- If `approve()` is called on an expired session, the state is set to `expired` and `sessionExpired` is thrown.
- All other invalid transitions throw `invalidStateTransition`.
- Sessions are consumed atomically — a second consumption returns nil.

## Transport Routing

The Mac coordinator uses deterministic routing to select the best available transport for delivering authorization requests:

1. **Active transport connection** — a device with a live entry in `deviceTransportMap`
2. **Trusted and connected nearby device** — a nearby device marked as trusted with an active connection
3. **Any connected nearby device** — a nearby device with an active connection
4. **Any nearby device** — a nearby device that can be reached by initiating a connection

If no transport is available, the request fails with a specific error state indicating the reason.

## Cryptographic Primitives

| Operation | Algorithm | Key Size |
|-----------|-----------|----------|
| Key generation | P-256 ECDSA | 256-bit |
| Signing | ECDSA with SHA-256 | P-256 |
| Message authentication | HMAC-SHA256 | 256-bit |
| Key derivation | HKDF-SHA256 | 256-bit output |
| Hashing | SHA-256 | 256-bit |
| Encryption (audit logs) | AES-256-GCM | 256-bit |
| Random generation | `SecRandomCopyBytes` | Variable |

## Secure Enclave Usage

- Keys generated with `kSecAttrTokenIDSecureEnclave` and access control flags `[.privateKeyUsage, .biometryCurrentSet]`
- Private keys never leave the Secure Enclave hardware
- Key is invalidated if biometric enrollment changes (e.g., new fingerprint or face added)
- Available on physical iOS devices only; simulator falls back to `SoftwareKeyManager`
- macOS Secure Enclave requires Apple Silicon or T2 chip with Touch ID
