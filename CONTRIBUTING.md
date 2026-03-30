# Contributing to FaceBridge

Thank you for your interest in contributing to FaceBridge. This document outlines the guidelines, workflows, and areas where help is most needed.

## Where Help Is Needed

### High Impact

- **Transport reliability** — improving connection stability, reconnection logic, and fallback behavior between BLE and LAN
- **End-to-end encryption** — wiring ephemeral ECDH key exchange and AES-256-GCM into the transport layer
- **Trust model hardening** — trust expiry, revocation propagation, and runtime integration of `TrustRelationship`
- **Certificate pinning** — binding TLS identity to pairing-derived key material

### Moderate Impact

- **Testing** — additional test coverage for edge cases, real-device scenarios, and negative paths
- **SAS UI integration** — wiring the existing SAS verification logic into the pairing user interface
- **UX improvements** — better status feedback, accessibility, and platform-native design patterns
- **Documentation** — developer guides, API documentation, and example integrations

### Good First Contributions

- Adding test cases for existing functionality
- Improving error messages and log clarity
- Documentation typo fixes and clarifications
- SwiftUI view improvements

### Security-Sensitive Areas

These areas require extra review rigor. Changes should include negative-path tests and document any new attack surface:

- Cryptographic operations (key generation, signing, verification)
- Nonce generation and validation
- Session lifecycle and state machine
- Trust verification and revocation
- Transport security (TLS configuration, BLE permissions)
- Codable `init(from:)` on security types
- Policy evaluation logic

## Code Style

- Modern Swift syntax (5.9+)
- Prefer `async/await` over callbacks
- Protocol-oriented architecture
- Dependency injection for testability
- Keep types `Sendable` where applicable
- Clear, descriptive naming over abbreviations
- Single-responsibility files

### Formatting

- Xcode default formatting (4-space indentation)
- Maximum line length: 120 characters (soft limit)
- Group imports logically
- Use `// MARK: -` for section organization in larger files

## Branch Naming

| Prefix | Purpose |
|--------|---------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `security/` | Security-related changes |
| `refactor/` | Code refactoring |
| `docs/` | Documentation changes |
| `test/` | Test additions or improvements |

## Pull Request Requirements

1. **One concern per PR.** Keep changes focused and reviewable.
2. **All tests must pass.** Run `swift test` before submitting.
3. **Add tests for new functionality.** Untested code will not be merged.
4. **Update documentation** if your change affects public API or behavior.
5. **Write a clear PR description** explaining what changed and why.
6. **No force pushes** to shared branches.

## Development Setup

```bash
git clone https://github.com/wesleysfavarin/facebridge.git
cd facebridge
swift build
swift test
```

For Xcode development, open `Package.swift` and select the appropriate scheme.

## Architecture Guidelines

Dependencies flow downward: **Apps → UI/Transport → Protocol → Crypto → Core**.

- **FaceBridgeCore** owns domain models and business logic
- **FaceBridgeCrypto** handles all cryptographic operations
- **FaceBridgeProtocol** defines message schemas and serialization
- **FaceBridgeTransport** abstracts communication channels
- **FaceBridgeSharedUI** provides reusable SwiftUI components
- **App targets** orchestrate module interactions

Cross-cutting concerns (like `AuditLogger`) are injected, not imported directly.

See [docs/architecture.md](docs/architecture.md) for the full module breakdown.

## Security Contributions

For security-sensitive changes:

- Include negative-path tests (invalid input, tampered data, replay attempts)
- Verify Codable deserialization cannot bypass validation
- Document any new attack surface in the PR description
- Consider impact on [docs/security-model.md](docs/security-model.md) and [docs/trust-model.md](docs/trust-model.md)

**Do not open public issues for security vulnerabilities.** Use GitHub's [private security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) or contact the maintainer directly. See [SECURITY.md](SECURITY.md).

## Documentation

If your change affects the security model, trust chain, or known limitations, update the relevant document:

| Document | Location |
|----------|----------|
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Security Model | [docs/security-model.md](docs/security-model.md) |
| Trust Model | [docs/trust-model.md](docs/trust-model.md) |
| Limitations | [docs/limitations.md](docs/limitations.md) |
| Protocol | [docs/protocol-overview.md](docs/protocol-overview.md) |
| Release Status | [docs/release-status.md](docs/release-status.md) |

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
