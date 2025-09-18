# Contributing to Stork P2P

Thank you for your interest in contributing to Stork P2P! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- **Flutter**: Version 3.32.8 or later
- **Dart**: Version 3.10.7 or later  
- **Visual Studio Build Tools**: 2019 or later (for Windows development)
- **Git**: For version control

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/stork-p2p.git
   cd stork-p2p
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```
4. **Verify setup**:
   ```bash
   flutter doctor
   flutter analyze
   ```

## 🏗️ Development Workflow

### Code Style

- **Follow Dart/Flutter conventions**: Use `dart format` and `flutter analyze`
- **Material Design 3**: Follow Material 3 design principles for UI
- **Comments**: Document complex logic and public APIs
- **Naming**: Use descriptive, camelCase names for variables and methods

### Architecture Guidelines

- **Service Layer Pattern**: Business logic goes in `lib/services/`
- **Clean Architecture**: Maintain separation between UI, services, and models
- **Error Handling**: Use comprehensive error handling with user-friendly messages
- **Security First**: All new features should consider security implications

### Branch Strategy

- **main**: Production-ready code
- **develop**: Integration branch for features
- **feature/**: Feature development branches
- **bugfix/**: Bug fix branches
- **hotfix/**: Critical production fixes

Example branch naming:
```bash
git checkout -b feature/android-support
git checkout -b bugfix/file-transfer-timeout
git checkout -b hotfix/security-vulnerability
```

## 🧪 Testing

### Running Tests

```bash
# Run all Flutter tests
flutter test

# Run specific test file
flutter test test/services/security_manager_test.dart

# Run integration tests
flutter test integration_test/

# Test coverage
flutter test --coverage
```

### Test Requirements

- **Unit tests** for all services and utilities
- **Widget tests** for custom widgets and screens
- **Integration tests** for critical user flows
- **Security tests** for encryption and authentication features

### Manual Testing

```bash
# Test core services
dart run test_core_services.dart

# Test security features
dart run test_phase4_security.dart

# Test file transfers
dart run test_receiver.dart
```

## 📝 Commit Guidelines

### Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```bash
git commit -m "feat(security): add biometric authentication support"
git commit -m "fix(transfer): resolve file corruption on large transfers"
git commit -m "docs(readme): update installation instructions"
```

## 🔒 Security Considerations

### Security-Related Changes

- **Encryption**: Changes to encryption must maintain AES-256-GCM standard
- **Authentication**: PIN and biometric features require thorough testing
- **Key Management**: RSA-2048 minimum for key exchange
- **Privacy**: Ensure no sensitive data is logged or stored unnecessarily

### Reporting Security Issues

Please **DO NOT** create public issues for security vulnerabilities. Instead:
1. Email security issues to: [security@stork-p2p.com]
2. Include detailed description and reproduction steps
3. Allow reasonable time for fix before public disclosure

## 🐛 Bug Reports

### Before Submitting

1. **Check existing issues**: Search for similar problems
2. **Update dependencies**: Ensure you're using latest versions
3. **Test on clean environment**: Verify the issue persists

### Bug Report Template

```markdown
**Describe the bug**
A clear description of the bug.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
 - OS: [e.g. Windows 11]
 - Flutter version: [e.g. 3.32.8]
 - App version: [e.g. 1.0.0]

**Additional context**
Any other context about the problem.
```

## 🚀 Feature Requests

### Before Submitting

1. **Check roadmap**: Review existing roadmap and planned features
2. **Search existing requests**: Look for similar feature requests
3. **Consider scope**: Ensure feature aligns with project goals

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Alternative solutions or features you've considered.

**Platform considerations**
Which platforms should this feature support?

**Additional context**
Screenshots, mockups, or other context.
```

## 🔄 Pull Request Process

### Before Submitting

1. **Update from main**: Ensure your branch is up-to-date
2. **Run tests**: All tests must pass
3. **Check code quality**: Run `flutter analyze` with no issues
4. **Update documentation**: Update README, docs, or comments as needed

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review of code changes completed
- [ ] Tests added/updated for new functionality
- [ ] Documentation updated where necessary
- [ ] No breaking changes (or clearly documented)
- [ ] Security considerations addressed

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots for UI changes.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added/updated
- [ ] Documentation updated
```

## 📱 Platform-Specific Development

### Windows
- **Build Tools**: Visual Studio Build Tools 2019+
- **Testing**: Test on Windows 10 and 11
- **Performance**: Monitor memory usage during large transfers

### Android (Future)
- **API Level**: Target API 34+
- **Permissions**: File system and network permissions
- **Testing**: Test on various screen sizes

### macOS (Future)
- **Xcode**: Latest stable version
- **Code Signing**: Apple Developer account required
- **Permissions**: File system access permissions

## 🎯 Areas for Contribution

### High Priority

1. **Cross-Platform Support**: Android, macOS, Linux implementations
2. **Mobile Features**: QR code pairing, NFC support
3. **Performance**: Transfer speed optimizations
4. **Accessibility**: Screen reader support, keyboard navigation

### Medium Priority

1. **Advanced Features**: Transfer scheduling, bandwidth control
2. **UI/UX**: Animation improvements, better empty states
3. **Documentation**: Video tutorials, API documentation
4. **Testing**: Automated testing, performance benchmarks

### Low Priority

1. **Integrations**: Cloud storage integration
2. **Advanced Security**: Hardware security module support
3. **Analytics**: Privacy-focused usage analytics
4. **Themes**: Custom theme support

## 📚 Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides/language)
- [Material Design 3](https://m3.material.io/)

### Project Resources
- [Architecture Overview](docs/architecture.md)
- [Security Implementation](docs/security.md)
- [Testing Guide](docs/testing.md)

### Community
- [GitHub Discussions](https://github.com/yourusername/stork-p2p/discussions)
- [Issue Tracker](https://github.com/yourusername/stork-p2p/issues)

## 🙏 Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes for significant contributions
- Annual contributor appreciation

---

Thank you for contributing to Stork P2P! Your efforts help make secure file sharing accessible to everyone.