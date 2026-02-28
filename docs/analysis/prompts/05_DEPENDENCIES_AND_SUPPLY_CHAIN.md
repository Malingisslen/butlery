# 05 - Dependencies & Supply Chain Security Analysis

**Analyst:** Claude (Opus 4.6)
**Mission:** Secure, maintainable dependency stack with zero known CVEs.
**Orchestrator weight:** 12% of overall codebase health score.

---

## Two-Phase Approach

- **Phase 1: Investigation only.** No code changes, no `pub upgrade`, no pubspec.yaml edits. Produce findings with package names, versions, and file:line references where applicable.
- **Phase 2: Upgrade plan.** Prioritized remediation roadmap based on Phase 1 findings.

**Cross-prompt note:** This prompt's CVE findings feed into 02 (Security & Compliance). This prompt is independent and can run first or in parallel with all other prompts.

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart
Codebase size:       ~850+ .dart files in lib/, ~150k+ lines of hand-written code
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase
DI system:           ServiceLocator.get<T>(), modular DI modules
                     (Core, Content, Social, Messaging, Collaboration, Performance, UI)
                     Constructor injection in DI modules, ServiceLocator in widgets/ViewModels

Key patterns:
  - BaseService              (pre-flight checks, caching)
  - BaseFirebaseRepository   (CRUD + audit logging)
  - ErrorHandlingMixin       (async error handling, retries) -- 100% adopted
  - SerializationUtils       (Firestore parsing)            -- 100% adopted
  - AsyncOperationMixin      (loading/error states)
  - PermissionValidationMixin (security on all repositories)

Firebase services:   Firestore, Auth, Storage, FCM, Cloud Functions
Platforms:           Android, iOS, Web, macOS, Windows
CI/CD:               GitHub Actions -- 5 workflows
                     (analyze.yml, test.yml, build-validation.yml,
                      architecture-validation.yml, e2e_tests.yml)
                     Dependabot enabled
Security:            Firestore rules: 1465 lines, 74 match rules
                     Storage rules: 61 lines
                     34 composite Firestore indexes
GDPR:                Phase 1 complete (Articles 7, 15, 17, 30)
Test coverage:       ViewModels 100%, Services 96%, Firebase Repos 88%

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Pre-Analysis Commands

Run these before starting. Attach output as context.

```bash
flutter pub outdated
flutter pub deps --style=compact
flutter pub audit
osv-scanner --lockfile=pubspec.lock   # if installed
```

If a tool is not installed, note its absence. The prompt works without optional tooling.

---

## Known Dependency Context

- **~80+ direct dependencies estimated** (verify against live pubspec.yaml)
- **Dependabot configured:** weekly updates (Monday 06:00 CET), grouped (firebase_*, testing, minor), PR limit (5 pub, 3 GitHub Actions), reviewer assignment
- **pubspec.lock committed** to version control
- **No pubspec_overrides.yaml or dependency_overrides section**
- **Caret syntax (^)** used for version constraints

### Security-Critical Packages

These form the defense-in-depth layer. Assess each individually:

| Package | Purpose |
|---------|---------|
| sqlcipher_flutter_libs | Encrypted SQLite via SQLCipher |
| http_certificate_pinning | MITM protection via SSL/TLS pinning |
| flutter_jailbreak_detection | Root and jailbreak detection |
| flutter_secure_storage | Encrypted keychain/keystore storage |
| pointycastle | AES and other encryption primitives |
| firebase_app_check | App attestation to prevent API abuse |
| crypto | SHA-256 hashing and HMAC |

### Packages Requiring Extra Scrutiny

- **algoliasearch**: Third-party search SDK. Verify publisher, maintenance, license.
- **drift + sqlcipher_flutter_libs**: Encrypted local database. `build_runner` is intentionally constrained for `drift_dev` compatibility -- do not flag build_runner version without checking drift_dev requirements.
- **receive_intent**: Android-only deep linking. Check maintenance status.
- **flutter_inappwebview**: Large native dependency with significant attack surface. Verify CVE history.

---

## Analysis Framework: 7 Dimensions (100 Points)

### Dimension 1: Vulnerability Scanning & CVEs (25 points)

**Gold standard:** Zero known vulnerabilities, active monitoring in place.

Investigate:

1. **Known vulnerabilities**
   - Run `flutter pub audit` and check pub.dev security advisories
   - Run `osv-scanner --lockfile=pubspec.lock` if available
   - Cross-reference with National Vulnerability Database (NVD)
   - For each vulnerability: CVE ID, CVSS score, affected package and version, exploit status

2. **CVSS categorization**
   - CRITICAL (9.0-10.0): Immediate remediation required
   - HIGH (7.0-8.9): Remediation within current sprint
   - MEDIUM (4.0-6.9): Scheduled remediation
   - LOW (0.1-3.9): Monitor and track

3. **Transitive dependency tree**
   - Run `flutter pub deps` for the full resolved tree
   - Identify vulnerable transitive dependencies
   - Determine if direct dependency upgrade resolves transitive CVEs
   - Check for version constraint conflicts preventing fixes

4. **Feature impact mapping**
   - Map each vulnerability to the Butlery features it affects
   - Assess exploitability in context (network-exposed vs local-only)
   - Evaluate attack surface reduction from existing mitigations

**Output:** Table of all CVEs with CVSS scores, affected packages, remediation paths, and feature impact.

---

### Dimension 2: Version Currency & Maintenance (20 points)

**Gold standard:** All packages within 1-2 minor versions of latest, all actively maintained.

Investigate:

1. **Version currency** (run `flutter pub outdated`)
   - Classify each package: current, upgradable, resolvable, behind major version
   - Version lag categories:
     - Current (same major, 0-2 minor behind): OK
     - Outdated (1 major behind): MONITOR
     - Severely outdated (2+ major behind): HIGH risk

2. **Maintenance status**
   - Last published date on pub.dev
   - GitHub activity: commits, issues, PRs in last 6 months
   - Open issues count and response time
   - Classification:
     - Active: updated within 6 months
     - Monitor: 6-12 months since update
     - At risk: 12-24 months since update
     - Abandoned: >24 months since update, >6 months no commits

3. **Deprecation and discontinuation**
   - Packages marked deprecated on pub.dev
   - Packages marked discontinued
   - Recommended replacements available

4. **SDK compatibility**
   - Flutter SDK: verify all packages support Flutter 3.32.4
   - Dart SDK: verify all packages support Dart ^3.5.0
   - 2026 platform requirements: compileSdk 35, targetSdk 35 (Android)

**Output:** Full dependency table with current version, latest version, gap, maintenance status, last updated date.

---

### Dimension 3: License Compliance (18 points)

**Gold standard:** All licenses commercial-safe, attribution complete, zero GPL/AGPL.

Investigate:

1. **License inventory**
   - Audit every direct and transitive dependency license
   - Categorize:
     - Permissive (MIT, BSD-2, BSD-3, Apache 2.0): commercial-safe
     - Weak copyleft (LGPL, MPL): review required, usually safe for dynamic linking
     - Strong copyleft (GPL, AGPL): source disclosure required -- CRITICAL risk
     - Custom/proprietary: legal review needed
     - No license specified: all rights reserved -- CRITICAL risk

2. **License compatibility matrix**
   - Check for conflicts across the transitive tree (e.g., GPL + proprietary)
   - Verify multi-license packages and which license applies
   - Review patent clauses (Apache 2.0 patent grant)
   - Check sublicensing requirements

3. **Commercial use restrictions**
   - Verify all licenses permit commercial distribution
   - Identify packages with non-commercial clauses
   - Check for export control restrictions

4. **Attribution requirements**
   - Identify packages requiring attribution in binary distribution
   - Verify LICENSES/NOTICE file exists and is complete
   - Check in-app license screen compliance (Flutter LicensePage)
   - Confirm app store license disclosure requirements met

**Output:** License compliance matrix grouped by license type, with any GPL/AGPL/no-license packages flagged as CRITICAL.

---

### Dimension 4: Dependency Bloat (15 points)

**Gold standard:** Every dependency justified, no unused packages, no overlapping functionality.

Investigate:

1. **Dependency counts**
   - Total direct dependencies
   - Total transitive dependencies (from pubspec.lock)
   - Ratio: transitive-to-direct (high ratio suggests heavy packages)

2. **Unused dependencies**
   - Grep codebase for `import 'package:<name>/` for each direct dependency
   - Flag any package with zero imports in lib/
   - Check if any dev_dependencies are incorrectly listed as dependencies

3. **Overlapping functionality**
   - Multiple packages serving the same purpose (e.g., path + path_provider overlap, collection vs dart:collection)
   - Multiple HTTP clients or serialization libraries
   - Packages whose functionality exists in Dart stdlib

4. **Bundle size impact**
   - Identify largest dependencies by compiled size
   - Heavy packages to assess: flutter_inappwebview, excel, drift + sqlcipher_flutter_libs, firebase suite
   - Evaluate tree-shaking effectiveness for partially-used packages

5. **Replacement candidates**
   - Packages that could be replaced with stdlib or a few lines of code
   - Heavy packages with lighter alternatives
   - Dev dependencies: necessary for testing/tooling or removable?

**Output:** Unused dependency list, overlapping packages, bundle size ranking, replacement recommendations.

---

### Dimension 5: Supply Chain Integrity (12 points)

**Gold standard:** Verified publishers, locked dependencies, reproducible builds.

Investigate:

1. **Lock file and pinning**
   - Confirm pubspec.lock is committed to version control
   - Review pinning strategy: caret (^) vs exact vs range
   - Build reproducibility: same lock file produces same build
   - Check for any dependency_overrides section

2. **Publisher verification**
   - Check verified publisher status on pub.dev for each direct dependency
   - Flag unverified publishers for security-critical packages
   - Review publisher reputation: downloads, pub points, number of packages
   - Special attention: algoliasearch, receive_intent, http_certificate_pinning, flutter_jailbreak_detection

3. **Dependabot configuration audit**
   - Weekly updates confirmed (Monday 06:00 CET)
   - Grouping strategy: firebase_* together, testing together, minor updates grouped
   - PR limit: 5 for pub, 3 for GitHub Actions
   - Reviewer assignment configured
   - Verify alerts are being triaged (not just accumulating)

4. **Checksum and integrity**
   - pubspec.lock contains content hashes for resolved packages
   - Verify no manually edited lock file entries
   - Check for dependency confusion attack vectors (private vs public package names)

**Output:** Supply chain risk assessment with publisher verification table and Dependabot audit results.

---

### Dimension 6: Platform Compatibility (5 points)

**Gold standard:** All packages support all target platforms with no restrictions.

Investigate:

1. **Platform support matrix**
   - Check each direct dependency against target platforms: Android, iOS, Web, macOS, Windows
   - Identify platform-specific packages (e.g., receive_intent is Android-only)
   - Flag packages missing support for any target platform
   - Web compatibility: check for dart:io usage, platform channels, FFI

2. **Native code dependencies**
   - Packages with native/platform code: sqlcipher_flutter_libs, flutter_inappwebview, local_auth, firebase_*, image_picker, flutter_image_compress
   - CocoaPods/Gradle version requirements
   - Native build configuration issues
   - Platform-specific permissions required

3. **2026 platform requirements**
   - Android: compileSdk 35, targetSdk 35 mandatory for Play Store
   - Android: AAB format mandatory
   - iOS: minimum deployment target compatibility with native plugins
   - Verify all native plugins build successfully on current SDK targets

**Output:** Platform compatibility matrix with any gaps or restrictions noted.

---

### Dimension 7: Upgrade Path & Migration (5 points)

**Gold standard:** Clear, sequenced upgrade roadmap with effort estimates and rollback plans.

Investigate:

1. **Major version upgrades pending**
   - List all packages with major version upgrades available
   - Breaking changes assessment from CHANGELOG.md
   - Migration guide availability for each upgrade
   - Automated migration tools (dart fix, codemods)

2. **Cascade dependencies**
   - Firebase packages that must upgrade together (firebase_core triggers all others)
   - drift + drift_dev + build_runner version coupling
   - Other packages with linked version requirements

3. **Upgrade risk assessment**
   - Simple: minor version bump, no breaking changes, drop-in replacement
   - Medium: major version with documented migration, limited API changes
   - Complex: major version with extensive API changes, data migration, or multi-package cascade

4. **Recommended upgrade sequence**
   - Dependencies before dependents
   - Smallest blast radius first
   - Security-critical upgrades prioritized
   - Rollback strategy for each upgrade tier

5. **Testing requirements per upgrade**
   - Which test suites must pass after each upgrade
   - Manual testing areas for behavior changes
   - Data migration concerns (drift database schemas, SharedPreferences keys)

**Output:** Prioritized upgrade roadmap with sequence, effort/risk estimates, and rollback plans.

---

## Investigation Process

### Stage 1: Automated Scanning

1. Verify dependencies from pubspec.yaml
2. Run `flutter pub deps --style=compact` (full tree)
3. Run `flutter pub outdated` (version currency)
4. Run `flutter pub audit` (vulnerability scan)
5. Run `osv-scanner --lockfile=pubspec.lock` if available
6. Document current state and any discrepancies

### Stage 2: Manual Review

1. **Vulnerability audit:** Cross-reference CVE databases, check security advisories, assess transitive vulnerabilities
2. **Maintenance review:** Check pub.dev for each package (last updated, pub points, publisher)
3. **License audit:** Extract and categorize licenses for all resolved packages
4. **Bloat analysis:** Grep for imports, identify unused/overlapping packages
5. **Supply chain review:** Publisher verification, Dependabot audit, lock file integrity
6. **Compatibility check:** Platform matrix, 2026 requirements, native dependencies

### Stage 3: Report Compilation

Compile all findings into the output format below with scores, severity classifications, and upgrade roadmap.

---

## Output Format

### Executive Summary

```
BUTLERY DEPENDENCIES & SUPPLY CHAIN SECURITY ANALYSIS - PHASE 1
================================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.6)
Total Dependencies: [X] direct, [Y] dev, [Z] total resolved
Flutter SDK: [version] | Dart SDK: [version]

OVERALL DEPENDENCY HEALTH SCORE: X/100
|-- Vulnerability Scanning & CVEs:   X/25
|-- Version Currency & Maintenance:  X/20
|-- License Compliance:              X/18
|-- Dependency Bloat:                X/15
|-- Supply Chain Integrity:          X/12
|-- Platform Compatibility:          X/5
|-- Upgrade Path & Migration:        X/5

SECURITY STATUS: [Secure | Needs Attention | Critical Vulnerabilities]

CRITICAL ISSUES: X (active CVEs, GPL licenses, abandoned packages)
HIGH PRIORITY:   X (severely outdated, unverified security packages)
MEDIUM PRIORITY: X (minor version lag, bloat, compatibility gaps)
LOW PRIORITY:    X (optimization opportunities)
```

### Package Health Dashboard

```markdown
| Package | Current | Latest | Gap | License | Pub Points | Last Updated | Maintenance | Platform |
|---------|---------|--------|-----|---------|------------|--------------|-------------|----------|
| [name]  | [ver]   | [ver]  | [n] | [type]  | [score]    | [date]       | [status]    | [flags]  |
```

Include all direct dependencies and key transitive dependencies.

### Vulnerability Report

For each vulnerability found:
- CVE ID
- CVSS score and severity category
- Affected package and version range
- Exploitability in Butlery context
- Remediation: upgrade path or workaround
- Feature impact

### License Compliance Matrix

Group by license type with package counts:
- Permissive (safe): MIT, BSD, Apache 2.0
- Weak copyleft (review): LGPL, MPL
- Strong copyleft (CRITICAL): GPL, AGPL
- Unknown/missing (CRITICAL): packages with no license

### Bloat Analysis

- Unused dependencies (zero imports in lib/)
- Overlapping packages (same functionality, multiple packages)
- Heaviest packages by estimated bundle impact
- Replacement candidates

### Supply Chain Assessment

- Publisher verification summary
- Dependabot configuration audit results
- Lock file integrity status
- Build reproducibility assessment

### Upgrade Roadmap

Prioritized upgrade list grouped by complexity:

```markdown
## Simple Upgrades (drop-in, no breaking changes)
| Package | From | To | Effort |
|---------|------|----|--------|
| [name]  | [v]  | [v]| [hrs]  |

## Medium Upgrades (documented migration, limited changes)
| Package | From | To | Breaking Changes | Effort |
|---------|------|----|-----------------|--------|

## Complex Upgrades (major migration, cascade effects)
| Package Group | From | To | Risk | Effort | Notes |
|--------------|------|----|------|--------|-------|
```

### Issues by Severity (Phase 2 Input)

```markdown
## CRITICAL (fix immediately)
- [List with package names, issue type, remediation]

## HIGH (fix within current sprint)
- [List]

## MEDIUM (scheduled remediation)
- [List]

## LOW (backlog)
- [List]

Total issues: X
Estimated total remediation effort: X days
```

---

## Phase 1 Deliverables Checklist

- [ ] Executive summary with overall score (X/100)
- [ ] Detailed findings for all 7 dimensions
- [ ] Package health dashboard (all direct + key transitive dependencies)
- [ ] Vulnerability report with CVE details and CVSS scores
- [ ] License compliance matrix (all resolved packages)
- [ ] Bloat analysis (unused, overlapping, heavy packages)
- [ ] Supply chain assessment (publishers, Dependabot, lock file)
- [ ] Platform compatibility matrix
- [ ] Security-critical packages individually assessed
- [ ] Upgrade roadmap with sequence, effort, and risk
- [ ] Issues classified by severity with counts
- [ ] ZERO dependency changes made

---

## Scoring Guide

| Score Range | Rating | Interpretation |
|-------------|--------|----------------|
| 90-100 | Excellent | Minor polish only, dependency stack is healthy |
| 75-89 | Good | Targeted improvements, no urgency |
| 60-74 | Acceptable | Prioritized remediation within 2 sprints |
| 40-59 | Needs work | Block new features until resolved |
| 0-39 | Critical | Stop feature work, fix foundations first |

### Per-Dimension Scoring Guidance

**Vulnerability Scanning (25 pts):** Start at 25. Deduct: -10 per CRITICAL CVE, -5 per HIGH CVE, -2 per MEDIUM CVE, -1 per LOW CVE. Floor at 0.

**Version Currency (20 pts):** Start at 20. Deduct: -3 per abandoned package, -2 per severely outdated (2+ major), -1 per deprecated package, -0.5 per package 1 major behind. Floor at 0.

**License Compliance (18 pts):** Start at 18. Deduct: -9 per GPL/AGPL package, -6 per no-license package, -2 per weak copyleft without review, -1 per missing attribution. Floor at 0.

**Dependency Bloat (15 pts):** Start at 15. Deduct: -2 per unused dependency, -1 per overlapping pair, -1 per unjustified heavy dependency. Floor at 0.

**Supply Chain Integrity (12 pts):** Start at 12. Deduct: -4 if lock file not committed, -2 per unverified security-critical publisher, -1 per unverified non-critical publisher, -2 if Dependabot misconfigured. Floor at 0.

**Platform Compatibility (5 pts):** Start at 5. Deduct: -2 per package missing a target platform with no alternative, -1 per 2026 requirement not met. Floor at 0.

**Upgrade Path (5 pts):** Start at 5. Deduct: -2 if no clear upgrade sequence documented, -1 per complex upgrade with no migration guide, -1 if cascade dependencies unresolved. Floor at 0.

---

## Begin Phase 1 Investigation

Execute the dependency and supply chain security investigation across all 7 dimensions. Use automated scanning tools first, then manual review. Compile findings into the output format above.

**Rules:**
- NO dependency changes. Investigation and documentation only.
- Document every finding with package names and versions.
- Categorize all issues by severity (Critical / High / Medium / Low).
- Provide effort estimates for every recommended upgrade or remediation.
- Assess each security-critical package individually.
- Verify 2026 platform requirements (compileSdk 35, targetSdk 35, AAB format).
