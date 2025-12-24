# Changelog

All notable changes to Butlery will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CI/CD improvements: Flutter version env variable, consistent caching, view tests in CI
- CODEOWNERS for automatic PR reviewer assignment
- PR template for standardized pull requests
- Architecture validation tool (`tools/validate_architecture.dart`)
- E2E test runner script (`scripts/run_e2e_tests.sh`)

### Changed
- All GitHub Actions workflows now use centralized `FLUTTER_VERSION` env variable

## [1.0.0] - 2024-12-20

### Added
- Smart recipe import system with multi-strategy parsing
- Social features: friends, sharing, comments, ratings, groups
- GDPR compliance (Articles 7, 15, 17, 30)
- Responsive design for 10 Tier 1 views
- Security with PermissionValidationMixin and audit logging
- FCM push notifications
- Menu sharing with visual indicators
- Filter toggle for imported items in SharedWithMe view

### Fixed
- Journey 3 menu sharing bugs
- Auto-load race condition in SharedWithMeView
- Shared content visibility and tab bar overflow

---

## Release Process

1. Update version in `pubspec.yaml`
2. Move [Unreleased] items to new version section
3. Commit: `git commit -m "chore: release vX.Y.Z"`
4. Tag: `git tag vX.Y.Z`
5. Push: `git push && git push --tags`
