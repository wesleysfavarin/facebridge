# Security

> **FaceBridge is experimental alpha software.** It has not undergone a third-party security audit. It is not intended for production use, financial authorization, or any context where compromise has safety or financial consequences.

## Security Posture

FaceBridge is an experimental biometric authorization bridge between macOS and iPhone. It uses only public Apple APIs and frameworks — no private entitlements, no undocumented interfaces, no system-level hooks.

The project is alpha-quality. It is published for research, experimentation, and community review, not for production deployment.

## Security Goals

FaceBridge aims to demonstrate the following properties within its experimental scope:

- **Trusted device pairing** — devices establish trust through an explicit pairing ceremony with signed identity exchange
- **Signed authorization requests** — the Mac signs all outgoing authorization requests with its device key (ECDSA-SHA256)
- **Signed authorization responses** — the iPhone signs all responses with its Secure Enclave-backed key
- **Secure Enclave-backed identities** — device keys are generated inside the Secure Enclave where hardware is available, bound to biometric enrollment
- **Replay protection** — cryptographic nonces, bounded replay windows, future-date rejection, and atomic session consumption
- **Protected action gating** — application-defined actions on the Mac execute only after verified biometric approval from the iPhone

## Non-Goals

FaceBridge explicitly does **not** attempt to:

- Replace macOS login, `sudo`, FileVault, or screen unlock
- Intercept or replace native Touch ID or Face ID system prompts
- Intercept App Store purchase approvals
- Intercept Safari or system password prompts
- Replace Apple Pay or Keychain authentication
- Intercept any native macOS or iOS system dialog
- Use private or undocumented Apple APIs
- Provide financial-grade or safety-critical authorization
- Operate over the public internet
- Defend against nation-state adversaries

FaceBridge operates entirely at the application layer. It controls only its own protected actions.

## Trust Assumptions

The security model depends on the following assumptions:

1. Paired devices are under the physical control of the same user
2. Devices are not already compromised at the OS or hardware level
3. The Secure Enclave on the iPhone is functioning correctly
4. The Keychain on both devices has not been compromised
5. The pairing ceremony is performed in a physically secure environment
6. Local transports (Wi-Fi, BLE) are used within expected proximity and network assumptions
7. Apple's `LocalAuthentication` framework correctly gates biometric access

## Residual Risks

These are known limitations of the current alpha release:

| Risk | Severity | Details |
|------|----------|---------|
| No application-layer end-to-end encryption | High | Message confidentiality relies on transport-layer protection |
| No TLS certificate pinning | Medium | System-default validation; no binding to pairing trust |
| No forward secrecy | Medium | HKDF abstraction exists; ephemeral ECDH not wired |
| SAS not wired into pairing UI | Medium | Logic implemented and tested; needs UI integration |
| Sender signature optional on requests | Medium | Requests without signature processed if sender is trusted |
| Trust revocation is local only | Medium | No propagation to peer device |
| No third-party security audit | High | Not externally validated |

See [docs/security-model.md](docs/security-model.md) for the complete threat model and mitigations.
See [docs/limitations.md](docs/limitations.md) for the full list of known constraints.

## Reporting Security Issues

If you discover a security vulnerability in FaceBridge:

1. **Do NOT open a public GitHub issue.**
2. Use GitHub's [private security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability).
3. Or contact the maintainer directly via the channels listed in the README.

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Suggested remediation if known

We will acknowledge receipt within 48 hours and provide a timeline for remediation.

## Security Documentation

| Document | Description |
|----------|-------------|
| [Security Model](docs/security-model.md) | Threat model, mitigations, cryptographic primitives, and residual risks |
| [Threat Model](docs/threat-model.md) | Protected assets, addressed threats, out-of-scope threats, and security boundaries |
| [Trust Model](docs/trust-model.md) | Pairing, identity binding, revocation, and trust lifecycle |
| [Limitations](docs/limitations.md) | Known constraints and scope boundaries |
| [Protocol Overview](docs/protocol-overview.md) | Request/response format, signing, and replay protection |
