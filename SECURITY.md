# Security Policy

> **FaceBridge is experimental alpha software.** It has not undergone a third-party security audit. It is not intended for production use, financial authorization, or any context where compromise has safety or financial consequences.

## Reporting Security Issues

If you discover a security vulnerability in FaceBridge:

1. **Do NOT open a public GitHub issue.**
2. Use GitHub's [private security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability), or
3. Contact the maintainer directly via the channels listed in the README.

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Suggested remediation if known

We will acknowledge receipt within 48 hours and provide a timeline for remediation.

## Security Documentation

| Document | Description |
|----------|-------------|
| [Security Model](docs/security-model.md) | Full threat model, mitigations, and residual risks |
| [Trust Model](docs/trust-model.md) | Pairing, identity binding, and revocation semantics |
| [Limitations](docs/limitations.md) | Known constraints and scope boundaries |
| [Protocol Overview](docs/protocol-overview.md) | Request/response format, signing, and replay protection |

## Non-Goals

FaceBridge explicitly does **not** attempt to:

- Replace macOS system authentication (login, `sudo`, FileVault)
- Provide financial-grade authorization security
- Defend against nation-state adversaries
- Replace Apple's Touch ID, Face ID, or Optic ID system prompts
- Operate over the public internet
