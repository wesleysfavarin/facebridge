# Contributing to FaceBridge

Thank you for your interest in contributing to FaceBridge. This document outlines the guidelines and workflows for contributing.

## Code Style

- Use modern Swift syntax (5.9+)
- Prefer `async/await` over callback-based patterns
- Follow protocol-oriented architecture
- Use dependency injection for testability
- Keep types `Sendable` where applicable
- Minimal comments — code should be self-documenting
- Use clear, descriptive naming over abbreviations
- Keep files focused on a single responsibility

### Formatting

- Use Xcode's default formatting (4-space indentation)
- Maximum line length: 120 characters (soft limit)
- Group related imports logically
- Use `// MARK: -` for section organization in larger files

## Branch Naming

Use the following prefixes:

| Prefix | Purpose |
|--------|---------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `security/` | Security-related changes |
| `refactor/` | Code refactoring |
| `docs/` | Documentation changes |
| `test/` | Test additions or improvements |

Examples:
- `feature/proximity-auto-approve`
- `fix/nonce-expiration-edge-case`
- `security/replay-window-hardening`

## Pull Request Requirements

1. **One concern per PR.** Keep changes focused and reviewable.
2. **All tests must pass.** Run `swift test` before submitting.
3. **Add tests for new functionality.** Untested code will not be merged.
4. **Update documentation** if your change affects public API or behavior.
5. **Write a clear PR description** explaining what changed and why.
6. **No force pushes** to shared branches.

### PR Template

```
## Summary

Brief description of the change.

## Motivation

Why is this change needed?

## Changes

- List of specific changes

## Testing

- How was this tested?
- Any edge cases considered?

## Security Considerations

- Does this change affect the security model?
- Any new attack surface?
```

## Security Reporting

**Do not open public issues for security vulnerabilities.**

If you discover a security issue:

1. Use GitHub's private vulnerability reporting feature, or
2. Contact the maintainer directly
3. Include detailed reproduction steps
4. Allow reasonable time for remediation before disclosure

See [SECURITY.md](SECURITY.md) for the full security policy.

## Issue Templates

### Bug Report

When filing a bug, include:

- Platform and OS version
- Swift and Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or error messages

### Feature Request

When proposing a feature:

- Describe the use case
- Explain the expected behavior
- Consider security implications
- Note any alternative approaches considered

## Feature Proposal Workflow

1. **Open a discussion** (not an issue) for the initial proposal
2. **Gather feedback** from maintainers and community
3. **Create an issue** once the approach is agreed upon
4. **Submit a PR** referencing the issue
5. **Iterate** based on code review feedback

## Development Setup

```bash
# Clone the repository
git clone https://github.com/wesleysfavarin/FaceBridge.git
cd FaceBridge

# Build
swift build

# Run tests
swift test
```

For full Xcode workspace development:

1. Open `Package.swift` in Xcode
2. Select the appropriate scheme
3. Build and run tests

## Architecture Guidelines

- **FaceBridgeCore** owns domain models and business logic
- **FaceBridgeCrypto** handles all cryptographic operations
- **FaceBridgeProtocol** defines message schemas and serialization
- **FaceBridgeTransport** abstracts communication channels
- **FaceBridgeSharedUI** provides reusable SwiftUI components
- **App targets** orchestrate module interactions

Dependencies flow downward: Apps → UI/Transport → Protocol → Crypto → Core.

Cross-cutting concerns (like `AuditLogger`) are injected, not imported directly.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
