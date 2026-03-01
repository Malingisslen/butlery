# Phase 1: Postponed Items

Items that require infrastructure setup, external accounts, or content creation outside the codebase.

## P1-02: Release Signing Configuration
**Reason:** Requires Apple Developer account enrollment and Google Play Console setup. Signing keys and provisioning profiles are environment-specific and cannot be committed to the repository. Will be configured during release pipeline setup.

## P1-09: Apple Sign-In Implementation
**Reason:** Deferred to Phase 10 (nice-to-haves). Requires Apple Developer account with Sign in with Apple capability enabled. Current email/password auth is sufficient for initial release.

## P1-10: Demo Account for App Review
**Reason:** Requires a dedicated test account with seeded data. Must be created after the app's data model and onboarding flow are finalized. Needed only at submission time.

## P1-11: Store Metadata (Screenshots, Descriptions)
**Reason:** Content creation task — app store listings, screenshots, and descriptions are prepared outside the codebase. Depends on final UI being stable.
