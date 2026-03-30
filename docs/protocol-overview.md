# Protocol Overview

This document describes the FaceBridge authorization protocol — how devices identify themselves, establish trust, exchange authorization requests and responses, and protect against common attacks.

## Device Identity

Each device generates a persistent identity when FaceBridge is first launched:

- A **UUID** serves as the stable device identifier
- A **P-256 ECDSA key pair** is generated in the Secure Enclave (on physical devices) or via CryptoKit (in simulator)
- The **public key** is exported in X9.63 uncompressed format (65 bytes, `0x04` prefix)
- A **display name** is sanitized and stored alongside the identity

The device identity is persisted in Keychain and remains stable across app launches.

## Trust Establishment

Trust is established through an explicit pairing ceremony:

```
┌─────────────────────────────────────────────┐
│  1. Mac generates pairing code              │
│  2. Mac sends signed PairingInvitation      │
│  3. iPhone verifies invitation signature    │
│  4. iPhone sends signed PairingAcceptance   │
│  5. Mac verifies acceptance signature       │
│  6. Both compute SAS for visual comparison  │
│  7. Both send signed PairingConfirmation    │
│  8. Both persist peer identity in Keychain  │
└─────────────────────────────────────────────┘
```

After pairing, each device holds the other's public key and device ID. These are used to verify all subsequent messages.

## Authorization Request

When the user triggers a protected action on the Mac, an `AuthorizationRequest` is created:

| Field | Description |
|-------|-------------|
| `id` | Unique request identifier (UUID) |
| `senderDeviceId` | Mac's device identity UUID |
| `nonce` | Cryptographically random nonce (minimum 16 bytes) |
| `challenge` | Application-defined challenge string |
| `reason` | Human-readable reason displayed to the user |
| `transportType` | Transport used for delivery (BLE or LAN) |
| `createdAt` | Timestamp of request creation |
| `expiresAt` | Expiration timestamp (default: 60 seconds from creation) |
| `senderSignature` | ECDSA-SHA256 signature over the canonical signable |

### Canonical Signable

The signable payload is a deterministic binary encoding using length-prefixed fields:

```
[4-byte length][field bytes] for each field:
  requestId, senderDeviceId, nonce, challenge, reason,
  transportType, timestamp (8-byte big-endian seconds)
```

This eliminates field boundary ambiguity and ensures identical byte sequences on sender and receiver.

## Authorization Response

The iPhone creates an `AuthorizationResponse` after processing the request:

| Field | Description |
|-------|-------------|
| `requestId` | Matches the original request ID |
| `decision` | `.approved`, `.denied`, or `.expired` |
| `signature` | ECDSA-SHA256 signature (minimum 64 bytes) |
| `signedPayload` | The canonical signable from the original request |
| `respondedAt` | Timestamp of the response |

All decision types are signed. The protocol does not permit unsigned responses — Codable deserialization rejects empty or undersized signatures.

## Signature Verification

### Request Verification (on iPhone)

When the iPhone receives a request:

1. Check if `senderDeviceId` is in the trust store
2. If `senderSignature` and stored public key are both present, verify the signature against the canonical signable
3. Validate the nonce against the replay protector

### Response Verification (on Mac)

When the Mac receives a response:

1. Verify `requestId` matches the pending request
2. Verify `signedPayload` matches the original request's signable
3. Verify `signature` against the iPhone's stored public key

## Session Validation

Sessions enforce a strict lifecycle:

1. A session is created in `pending` state with a fresh nonce and TTL
2. The session can transition to `approved`, `denied`, or `expired`
3. No other transitions are permitted
4. Sessions are consumed atomically — once consumed, they cannot be reused

## Replay Protection

The `ReplayProtector` prevents nonce reuse:

- Maintains a bounded set of seen nonces (maximum 10,000)
- Evicts entries based on TTL
- Rejects nonces with timestamps more than 30 seconds in the future
- Rejects previously seen nonces

## Transport Layer

Messages are wrapped in a `MessageEnvelope` before transmission:

| Field | Description |
|-------|-------------|
| `payload` | Serialized message bytes |
| `type` | Message type identifier |
| `mac` | Optional HMAC-SHA256 over the canonical encoding |
| `sequenceNumber` | Monotonic counter for ordering |

Two transport channels are available:

| Transport | Discovery | Security |
|-----------|-----------|----------|
| **Local Network** | Bonjour (`_facebridge._tcp`) | TLS by default |
| **BLE** | CoreBluetooth | Encryption-required characteristics |

The Mac coordinator selects the best available transport using deterministic routing: active connections are preferred, then trusted nearby devices, then any reachable device.

## Protocol Versioning

`ProtocolVersion` provides semantic versioning for protocol compatibility. Both devices exchange version information and can reject incompatible protocol versions.
