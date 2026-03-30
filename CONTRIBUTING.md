# Contributing to FaceBridge

Thank you for your interest in contributing to FaceBridge. This document outlines the guidelines, workflows, and areas where help is most needed.

## How to File Issues

- **Bug reports** — use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md). Include steps to reproduce, expected vs actual behavior, device/OS versions, and relevant logs.
- **Feature requests** — use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md). Explain the use case and why it fits FaceBridge's scope.
- **Security vulnerabilities** — do NOT open a public issue. See [SECURITY.md](SECURITY.md#reporting-security-issues) for private reporting.
- **Questions and discussion** — use GitHub Discussions or file an issue with a clear description.

All bug reports should be reproducible. Include device model, OS version, Xcode version, and whether you are using a physical device or simulator.

## Where Help Is Most Needed

### High Impact

- **Transport reliability** — connection stability, reconnection logic, fallback between BLE and LAN
- **End-to-end encryption** — ephemeral ECDH key exchange + AES-256-GCM message encryption
- **Trust model hardening** — trust expiry, revocation propagation, `TrustRelationship` runtime integration
- **Certificate pinning** — binding TLS identity to pairing-derived key material

### Moderate Impact

- **Test coverage** — edge cases, real-device scenarios, negative paths
- **SAS UI integration** — wiring existing SAS verification into the pairing user interface
- **UX improvements** — status feedback, accessibility, platform-native design patterns
- **Documentation** — developer guides, API documentation, example integrations

### Good First Contributions

If you are new to the project, these are approachable starting points:

- **Documentation** — fix typos, improve clarity, add examples
- **UI polish** — SwiftUI view improvements, accessibility labels, layout refinements
- **Test coverage** — add test cases for existing functionality (see `Tests/` for examples)
- **Error messaging** — improve error messages and log clarity throughout the codebase
- **Transport reliability** — connection recovery and retry improvements
- **Onboarding UX** — first-launch experience, pairing flow guidance

## Security-Sensitive Areas

These areas require extra review rigor. Changes must include negative-path tests and document any new attack surface:

| Area | Files | Why it matters |
|------|-------|----------------|
| Cryptographic operations | `Sources/FaceBridgeCrypto/` | Key generation, signing, verification |
| Nonce generation and validation | `Sources/FaceBridgeCore/Nonce.swift`, `ReplayProtection.swift` | Replay protection integrity |
| Session lifecycle | `Sources/FaceBridgeCore/Session.swift` | State machine correctness |
| Trust verification | `Sources/FaceBridgeiOSApp/DeviceTrustManager.swift`, agent `TrustedDeviceVerifier.swift` | Identity validation |
| Transport security | `Sources/FaceBridgeTransport/` | TLS configuration, BLE permissions |
| Codable `init(from:)` on security types | Protocol and Core types | Deserialization bypass prevention |
| Policy evaluation | `Sources/FaceBridgeCore/PolicyEngine.swift` | Authorization gating logic |

**Do not make casual changes** to cryptographic operations, signature verification, nonce handling, or trust verification without thorough testing and review. These areas directly affect the security model.

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
4. **Update documentation** if your change affects public API, behavior, or security model.
5. **Write a clear PR description** explaining what changed and why.
6. **No force pushes** to shared branches.
7. **Reproducible bug reports** for bug fix PRs — include the issue number.

## Expectations

- **Tests are required** for all non-trivial changes. See `Tests/` for the existing test structure.
- **Documentation updates** are expected when changing behavior, adding features, or modifying security properties.
- **Security model changes** must update [docs/security-model.md](docs/security-model.md), [docs/threat-model.md](docs/threat-model.md), or [docs/limitations.md](docs/limitations.md) as appropriate.
- **Breaking changes** must be clearly documented in the PR description and CHANGELOG.

## Development Setup

```bash
git clone https://github.com/wesleysfavarin/facebridge.git
cd facebridge
swift build
swift test
```

For Xcode development, open `Package.swift` and select the appropriate scheme.

See [docs/real-device-testing.md](docs/real-device-testing.md) for physical device setup.

## Architecture Guidelines

Dependencies flow downward: **Apps → UI/Transport → Protocol → Crypto → Core**.

- **FaceBridgeCore** owns domain models and business logic
- **FaceBridgeCrypto** handles all cryptographic operations
- **FaceBridgeProtocol** defines message schemas and serialization
- **FaceBridgeTransport** abstracts communication channels
- **FaceBridgeSharedUI** provides reusable SwiftUI components
- **App targets** orchestrate module interactions

Cross-cutting concerns (like `AuditLogger`) are injected, not imported directly.

See [docs/architecture.md](docs/architecture.md) for the full module breakdown and [docs/repository-map.md](docs/repository-map.md) for a codebase navigation guide.

## Security Contributions

For security-sensitive changes:

- Include negative-path tests (invalid input, tampered data, replay attempts)
- Verify Codable deserialization cannot bypass validation
- Document any new attack surface in the PR description
- Consider impact on [docs/security-model.md](docs/security-model.md) and [docs/threat-model.md](docs/threat-model.md)

**Do not open public issues for security vulnerabilities.** Use GitHub's [private security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) or contact the maintainer directly. See [SECURITY.md](SECURITY.md).

## Documentation

If your change affects the security model, trust chain, or known limitations, update the relevant document:

| Document | Location |
|----------|----------|
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Security Model | [docs/security-model.md](docs/security-model.md) |
| Threat Model | [docs/threat-model.md](docs/threat-model.md) |
| Trust Model | [docs/trust-model.md](docs/trust-model.md) |
| Limitations | [docs/limitations.md](docs/limitations.md) |
| Protocol | [docs/protocol-overview.md](docs/protocol-overview.md) |
| Release Status | [docs/release-status.md](docs/release-status.md) |

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
