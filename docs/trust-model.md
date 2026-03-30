# Trust Model

This document describes how FaceBridge establishes, verifies, and manages trust between paired devices.

## Overview

Trust in FaceBridge is explicit and ceremony-based. No silent or automatic trust establishment occurs. Two devices become trusted only after completing a pairing flow that exchanges signed messages and cryptographic identities.

## Pairing Ceremony

### Steps

1. **Invitation.** The Mac generates a 6-digit pairing code using `SecRandomCopyBytes` and creates a `PairingInvitation` containing its device ID, P-256 public key, the pairing code, and a digital signature.

2. **Code entry.** The iPhone user enters the pairing code. The code is validated against the Mac's stored code with rate limiting (configurable max attempts per time window) and lockout protection.

3. **Acceptance.** The iPhone creates a `PairingAcceptance` with its device ID, P-256 public key, and a signature bound to the invitation's device ID.

4. **SAS verification.** Both devices independently compute a 6-digit Short Authentication String from `SHA-256(initiatorPublicKey || responderPublicKey || pairingCode)`. This allows visual confirmation that both sides see the same public keys, defending against key substitution by a man-in-the-middle.

   > **Current status.** SAS computation and verification are implemented and tested. The UI flow to display and confirm the SAS is not yet wired.

5. **Confirmation.** Both devices create signed `PairingConfirmation` messages indicating mutual agreement.

6. **Persistence.** Each device stores the peer's `DeviceIdentity` (including public key) in Keychain.

### What Is Not Verified During Pairing

- No Certificate Authority involvement
- No out-of-band verification channel (beyond SAS, when wired)
- No hardware attestation of the peer's Secure Enclave
- No verification that the peer is running an unmodified FaceBridge binary

## Device Identity

Each device is represented by a `DeviceIdentity`:

| Field | Description |
|-------|-------------|
| `id` | Stable UUID identifier |
| `displayName` | Sanitized string (control characters stripped, max 100 characters) |
| `platform` | `.iOS` or `.macOS` |
| `publicKeyData` | P-256 X9.63 uncompressed format (65 bytes, `0x04` prefix) |
| `createdAt` | Timestamp of identity creation |

**Validation rules** (enforced on both `init` and Codable deserialization):

- Public key must be exactly 65 bytes
- First byte must be `0x04` (uncompressed point prefix)
- Empty keys are rejected
- Display name is sanitized for bidirectional and control characters

## Signature Trust Chain

### Authorization Request (Mac → iPhone)

1. Mac builds `AuthorizationRequest` with nonce, challenge, reason, transport type, and timestamp
2. Mac computes canonical `signable` — a length-prefixed binary encoding of all fields
3. Mac signs `signable` with its device key, producing `senderSignature`
4. iPhone verifies the signature against the stored public key (when both signature and key are present)

**Gap.** If `senderSignature` is nil, the request is still processed when `senderDeviceId` is in the trust store. Request authenticity in this case depends on trust-store presence rather than cryptographic proof.

### Authorization Response (iPhone → Mac)

1. iPhone computes the same canonical `signable` from the request
2. iPhone signs it with its device key (Secure Enclave on hardware, software key in simulator)
3. Response includes a mandatory `signature` (minimum 64 bytes) and `signedPayload`
4. Mac verifies: `requestId` match, `signedPayload` integrity against the original signable, and signature validity

All response types (approved, denied, expired) are signed. Unsigned responses are structurally impossible due to throwing initializers and Codable validation.

## Trusted vs. Nearby Devices

FaceBridge distinguishes between two categories of discovered devices:

| Category | Description |
|----------|-------------|
| **Trusted** | Device whose identity was persisted during a pairing ceremony |
| **Nearby** | Device discovered via Bonjour or BLE but not necessarily trusted |

A nearby device may represent the same physical device as a trusted entry. The Mac coordinator uses fuzzy name matching and transport ID correlation to merge these into a unified view. Authorization requests are only sent to trusted devices.

### Multiple Transport Discovery

One physical device may be discovered through multiple transports simultaneously. BLE and LAN report devices with different transport-level identifiers, but both may represent the same trusted device.

The Mac coordinator uses fuzzy name matching and transport ID correlation to merge these into a unified view. Authorization requests are routed via the best available transport for a given trusted device, regardless of which transport discovered it.

Transport-level identity is not cryptographically bound to pairing-level identity. The binding is based on device ID matching, not on transport authentication.

### Why Duplicates Can Appear

- A device reinstalled FaceBridge generates a new `localDeviceId`
- BLE and LAN discovery may report the same device with different transport identifiers
- The Mac may retain stale trust entries from previous pairings

Stale entries can be removed manually through the device management UI on both platforms.

## Revocation

### Current Implementation

- **Manual removal only.** Calling `removeTrustedDevice` or `removePairedDevice` deletes the device identity from Keychain.
- **No propagation.** Removing trust on one device does not notify the peer.
- **No expiry.** Trust relationships do not have a TTL or automatic expiration.
- **`TrustRelationship` struct exists** with a `revokedAt` field and `isActive` computed property, but this struct is not currently used in runtime trust checks.

### Implications

- If a device is removed from the trust store on the Mac, the iPhone still considers the Mac trusted
- There is no mechanism to invalidate trust remotely
- Key rotation generates new keys but does not propagate the new public key to peers

### Planned Improvements

- Trust relationship TTL with periodic re-verification
- Revocation notification via transport
- Integration of `TrustRelationship` into runtime trust checks

## Session Validation

### Session Creation

`SecureSessionHandler.createSession` generates a session with a unique ID, associated trust relationship, fresh nonce, and configurable TTL (default: 30 seconds).

### Session Consumption

`validateAndConsume(sessionId)` atomically looks up the session, removes it from active sessions, and returns it. A session can only be consumed once. Second attempts return nil.

### State Machine

Only `pending` sessions can transition:

- `pending` → `approved` (if not expired)
- `pending` → `denied`
- `pending` → `expired`

If `approve()` is called on an expired session, the state is set to `expired` and `sessionExpired` is thrown. All other invalid transitions throw `invalidStateTransition`.

## Biometric Proof

The biometric proof chain:

1. `PolicyEngine.evaluate` checks if `requireBiometric` is set
2. `PolicyEnforcer.enforce` passes `biometricVerified` to the engine
3. On the iPhone, `BiometricAuthenticator.authenticate` calls `LAContext.evaluatePolicy` with `.deviceOwnerAuthenticationWithBiometrics`
4. The Secure Enclave key usage is gated by biometric evaluation

**What biometric proof means:**

- The `LocalAuthentication` framework confirmed a biometric match
- The Secure Enclave key usage was gated by biometric evaluation
- No biometric data was transmitted or stored by FaceBridge

**What it does not prove:**

- The specific biometric template used
- That the biometric was evaluated at the exact moment of signing
- That the device hardware has not been tampered with
