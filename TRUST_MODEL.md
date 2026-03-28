# Trust Model

This document describes how FaceBridge establishes, verifies, and manages trust between paired devices.

## Pairing Trust Establishment

Trust is established through an explicit pairing ceremony. No silent or automatic trust establishment occurs.

### Steps

1. **Invitation:** The Mac generates a 6-digit pairing code using `SecRandomCopyBytes` and creates a `PairingInvitation` containing its device ID, P-256 public key, the code, and a digital signature.

2. **Code verification:** The iPhone user enters the pairing code. The code is validated against the Mac's stored code with rate limiting (configurable max attempts per time window) and lockout protection.

3. **Acceptance:** The iPhone creates a `PairingAcceptance` with its device ID, P-256 public key, and a signature, binding it to the invitation's device ID.

4. **SAS verification (primitive):** Both devices independently compute a 6-digit Short Authentication String from `SHA-256(initiatorPublicKey || responderPublicKey || pairingCode)`. This allows visual confirmation that both sides see the same public keys, defending against MITM key substitution.

   > **Current status:** SAS computation and verification logic is implemented and tested (`ShortAuthenticationStringVerifier`), but the UI flow to display and confirm the SAS is not yet wired.

5. **Confirmation:** Both devices create signed `PairingConfirmation` messages indicating mutual agreement.

6. **Persistence:** Each device stores the peer's `DeviceIdentity` (including public key) in Keychain.

### What is NOT verified during pairing

- No Certificate Authority involvement
- No out-of-band verification channel (beyond SAS, when wired)
- No hardware attestation of the peer's Secure Enclave
- No verification that the peer is running an unmodified FaceBridge binary

## Device Identity Binding

Each device is represented by a `DeviceIdentity`:

- `id`: UUID (stable identifier)
- `displayName`: Sanitized string (control characters stripped, max 100 chars)
- `platform`: `.iOS` or `.macOS`
- `publicKeyData`: P-256 X9.63 uncompressed format (65 bytes, `0x04` prefix)
- `createdAt`: Timestamp

**Validation rules (enforced on both init and Codable deserialization):**
- Public key must be exactly 65 bytes
- First byte must be `0x04` (uncompressed point prefix)
- Empty keys rejected
- Display name sanitized for bidi/control characters

## Signature Trust Chain

### Authorization Request (Mac -> iPhone)

1. Mac builds `AuthorizationRequest` with nonce, challenge, reason, transport type, and timestamp
2. Mac computes canonical `signable` (length-prefixed binary encoding of all fields)
3. Mac signs `signable` with its device key, producing `senderSignature`
4. iPhone receives request and (if `senderSignature` and stored public key are both present) verifies the signature

**Gap:** If `senderSignature` is nil, the request is still processed if `senderDeviceId` is in the trust store. This means request authenticity depends on trust-store presence rather than cryptographic proof in the nil-signature case.

### Authorization Response (iPhone -> Mac)

1. iPhone computes the same canonical `signable` from the request
2. iPhone signs with its device key (Secure Enclave on hardware, software key in simulator)
3. Response includes mandatory `signature` (min 64 bytes) and `signedPayload`
4. Mac verifies: `requestId` match, `signedPayload == originalRequest.signable`, signature validity

All response types (approved, denied, expired) are signed. Unsigned responses are structurally impossible due to throwing init and Codable validation.

## Revocation Semantics

### Current Implementation

- **Manual removal only:** Calling `removeTrustedDevice` / `removePairedDevice` deletes the device identity from Keychain
- **No propagation:** Removing trust on one device does not notify the peer
- **No expiry:** Trust relationships do not have a TTL or automatic expiration
- **`TrustRelationship` struct exists** with a `revokedAt` field and `isActive` computed property, but this struct is not currently used in runtime trust checks

### What This Means

- If a device is removed from the trust store on the Mac, the iPhone still considers the Mac trusted
- There is no mechanism to invalidate trust remotely
- Key rotation (`KeyRotationManager`) generates new keys but does not propagate the new public key to peers

### Planned Improvements

- Trust relationship TTL with periodic re-verification
- Revocation notification via transport
- Integration of `TrustRelationship` into runtime trust checks

## Session Validation Logic

### Session Creation

`SecureSessionHandler.createSession` generates a session with:
- Unique ID
- Associated trust relationship ID
- Fresh nonce from `NonceGenerator`
- Configurable TTL (default 30 seconds)

### Session Consumption

`validateAndConsume(sessionId)` atomically:
1. Looks up the session
2. Removes it from active sessions
3. Returns the session (or nil if not found)

A session can only be consumed once. Second attempts return nil.

### State Machine

Only `pending` sessions can transition:
- `pending` -> `approved` (if not expired)
- `pending` -> `denied`
- `pending` -> `expired`

All other transitions throw `invalidStateTransition`.

If `approve()` is called on an expired session, the state is set to `expired` and `sessionExpired` is thrown.

## Biometric Proof Propagation

The biometric proof chain:

1. `PolicyEngine.evaluate` checks if `requireBiometric` is set in the policy
2. If required, `biometricVerified` parameter must be `true`
3. `PolicyEnforcer.enforce` passes `biometricVerified` to the engine
4. `AuthorizationExecutor` receives `biometricVerified` from the approval flow
5. On the iPhone side, `BiometricAuthenticator.authenticate` calls `LAContext.evaluatePolicy` with `.deviceOwnerAuthenticationWithBiometrics`

**What biometric proof means:**
- The LocalAuthentication framework confirmed biometric match
- The Secure Enclave key usage was gated by biometric evaluation
- No biometric data was transmitted or stored by FaceBridge

**What it does NOT prove:**
- The specific biometric template used
- That the biometric was evaluated at the exact moment of signing (there is a time window)
- That the device hardware has not been tampered with
