# Dependency Management Guide

**Last Updated**: October 30, 2025
**Status**: Production Ready
**Audience**: DevOps, Developers, Technical Leads

---

## Overview

This guide establishes best practices for managing dependencies in the Butlery Flutter application, including automated updates via Dependabot, security monitoring, and manual update procedures.

## Automated Dependency Updates (Dependabot)

### Configuration

Dependabot is configured in `.github/dependabot.yml` to automatically:
- Check for Flutter/Dart package updates weekly (Mondays at 09:00 CET)
- Check for GitHub Actions updates weekly
- Create pull requests for security and version updates
- Group related updates (Firebase packages, Flutter tooling)
- Limit to 5 concurrent PRs to avoid overwhelming review process

### Review Process

When Dependabot creates a PR:

1. **Automated Checks**
   - CI/CD pipeline runs automatically
   - All tests must pass before merging
   - Flutter analyze must show zero issues

2. **Manual Review Checklist**
   - [ ] Review changelog/release notes for breaking changes
   - [ ] Verify no deprecated APIs introduced
   - [ ] Check Firebase compatibility (if Firebase packages updated)
   - [ ] Test critical user flows manually if major update
   - [ ] Review dependency tree for new transitive dependencies

3. **Merge Strategy**
   - **Patch updates**: Auto-merge if tests pass (bug fixes only)
   - **Minor updates**: Review within 48 hours (new features, backwards compatible)
   - **Major updates**: Thorough review + manual testing (breaking changes possible)

### Grouped Updates

Dependabot groups related packages for easier review:

**Firebase Group** (firebase_*, cloud_firestore):
- All Firebase packages updated together
- Ensures compatibility across Firebase SDK
- Test: Auth, Firestore CRUD, Storage operations

**Flutter Tooling Group** (flutter_*, build_runner, json_serializable):
- Code generation and build tools
- Test: Run `flutter pub run build_runner build --delete-conflicting-outputs`
- Verify generated code compiles without errors

## Manual Dependency Updates

### Monthly Audit

First Monday of each month, perform manual dependency audit:

```bash
# Check for outdated packages
flutter pub outdated

# Review security advisories
flutter pub outdated --mode=null-safety

# Check for deprecated packages
flutter analyze | grep -i deprecated
```

### Update Procedure

```bash
# 1. Update specific package
flutter pub upgrade package_name

# 2. Run tests
flutter test

# 3. Update lock file
flutter pub get

# 4. Verify analyze is clean
flutter analyze

# 5. Commit changes
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): update package_name to vX.Y.Z"
```

### Major Version Updates

For major version updates (breaking changes):

1. **Create feature branch**
   ```bash
   git checkout -b deps/update-firebase-v7
   ```

2. **Review breaking changes**
   - Read package changelog/migration guide
   - Document required code changes

3. **Update code**
   - Fix deprecation warnings
   - Update API calls to new patterns
   - Run full test suite

4. **Test thoroughly**
   - Manual testing of affected features
   - Integration tests
   - Performance regression testing

5. **Create PR**
   - Document changes in PR description
   - Link to package changelog
   - Note any behavioral changes

## Security Monitoring

### Security Advisories

1. **GitHub Security Alerts**
   - Enabled for this repository
   - Notifies of known vulnerabilities
   - Dependabot creates PRs for security patches

2. **pub.dev Security**
   - Monitor pub.dev security advisories
   - Subscribe to package security mailing lists
   - Check Dart/Flutter security announcements

### Emergency Security Updates

For critical security vulnerabilities:

1. **Immediate Action** (within 24 hours)
   - Update vulnerable package
   - Run full test suite
   - Deploy emergency patch

2. **Communication**
   - Notify team of security update
   - Document vulnerability and fix
   - Update deployment notes

## Critical Package Management

### Firebase Packages

**Update Strategy**: Conservative (test thoroughly before updating)

Critical packages:
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`

**Testing Checklist**:
- [ ] Authentication flows (sign up, sign in, sign out)
- [ ] Firestore CRUD operations
- [ ] Real-time listeners
- [ ] File upload/download
- [ ] Push notifications

### Flutter SDK

**Update Strategy**: Monthly minor updates, quarterly major updates

```bash
# Check current version
flutter --version

# Update Flutter SDK
flutter upgrade

# Clean project
flutter clean
flutter pub get

# Verify
flutter doctor
flutter analyze
```

## Dependency Pinning

### When to Pin

Pin specific versions for:
- Critical production dependencies (Firebase)
- Packages with frequent breaking changes
- Packages affecting security

### Pinning Syntax

```yaml
dependencies:
  # Exact version (use sparingly)
  critical_package: 1.2.3

  # Caret syntax (default, allows patches + minor)
  most_packages: ^1.2.3  # Allows 1.2.4, 1.3.0, but not 2.0.0

  # Compatible syntax (major + minor, not patches)
  some_package: ">=1.2.3 <2.0.0"
```

## Troubleshooting

### Version Conflicts

If dependency resolution fails:

```bash
# 1. Clean cache
flutter pub cache repair

# 2. Remove lock file
rm pubspec.lock

# 3. Get dependencies fresh
flutter pub get

# 4. If still failing, check constraints
flutter pub deps
```

### Breaking Changes

If update introduces breaking changes:

1. Check migration guide in package changelog
2. Search codebase for deprecated API usage: `flutter analyze`
3. Update code incrementally
4. Run tests after each change
5. Document changes for team

## Dependabot Configuration Reference

Key settings in `.github/dependabot.yml`:

```yaml
# Update frequency
schedule:
  interval: "weekly"  # or "daily", "monthly"

# PR limits (avoid overwhelming review queue)
open-pull-requests-limit: 5

# Automatic grouping
groups:
  firebase:
    patterns: ["firebase_*"]
```

## Related Documentation

- **Deployment Guide**: `/docs/operations/DEPLOYMENT_GUIDE.md`
- **CI/CD Guide**: `.github/workflows/` (workflow files)
- **Security Policies**: `/docs/security/` (if exists)

---

**Questions?** Contact DevOps team or refer to:
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Flutter Package Versioning](https://dart.dev/tools/pub/dependencies)
- [pub.dev Security](https://pub.dev/help/security)
