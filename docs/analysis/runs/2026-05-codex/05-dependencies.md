### Executive Summary

```
BUTLERY DEPENDENCIES & SUPPLY CHAIN SECURITY ANALYSIS - PHASE 1
================================================================
Analysis Date: 2026-05-02
Analyst: Codex (GPT-5)
Total Dependencies: 61 direct, 18 dev, 289 total resolved
Flutter SDK: 3.35.1 | Dart SDK: 3.9.0

OVERALL DEPENDENCY HEALTH SCORE: 69/100
|-- Vulnerability Scanning & CVEs:   17/25
|-- Version Currency & Maintenance:  13/20
|-- License Compliance:              10/18
|-- Dependency Bloat:                13/15
|-- Supply Chain Integrity:          9/12
|-- Platform Compatibility:          4/5
|-- Upgrade Path & Migration:        3/5

SECURITY STATUS: Needs Attention

CRITICAL ISSUES: 0 (active CVEs, GPL licenses, abandoned packages)
HIGH PRIORITY:   4 (scan blind spots, inactive pinning, discontinued transitive tooling, EOL signal)
MEDIUM PRIORITY: 7 (major version lag, constrained upgrades, incomplete license metadata)
LOW PRIORITY:    4 (optimization opportunities)
```

Evidence:
- Flutter/Dart runtime snapshot: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-version.txt:1-4`.
- Dependency graph snapshot and versions: `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:1-298`.
- Outdated analysis + constraints/discontinued markers: `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:89-218`.
- Lockfile with hashes/sources and SDK constraints: `pubspec.lock:1-3`, `pubspec.lock:8-11`, `pubspec.lock:2292-2294`.

### Package Health Dashboard

```markdown
| Package | Current | Latest | Gap | License | Pub Points | Last Updated | Maintenance | Platform | Evidence |
|---------|---------|--------|-----|---------|------------|--------------|-------------|----------|----------|
| algoliasearch | 1.46.2 | 1.49.0 | 1.46.2 -> 1.49.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:6; pub-outdated.txt:95 |
| app_links | 6.4.1 | 7.0.0 | 6.4.1 -> 7.0.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:7; pub-outdated.txt:96 |
| archive | 3.6.1 | 4.0.9 | 3.6.1 -> 4.0.9 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:8; pub-outdated.txt:97 |
| cached_network_image | 3.4.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:9; pub-outdated.txt:92 |
| clock | 1.1.2 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:10; pub-outdated.txt:92 |
| cloud_firestore | 6.2.0 | 6.3.0 | 6.2.0 -> 6.3.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:11; pub-outdated.txt:98 |
| cloud_functions | 6.1.0 | 6.2.0 | 6.1.0 -> 6.2.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:12; pub-outdated.txt:99 |
| collection | 1.19.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:13; pub-outdated.txt:92 |
| connectivity_plus | 7.0.0 | 7.1.1 | 7.0.0 -> 7.1.1 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:14; pub-outdated.txt:100 |
| crypto | 3.0.7 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:15; pub-outdated.txt:92 |
| csv | 6.0.0 | 8.0.0 | 6.0.0 -> 8.0.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:16; pub-outdated.txt:101 |
| cupertino_icons | 1.0.9 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:17; pub-outdated.txt:92 |
| device_info_plus | 12.3.0 | 13.1.0 | 12.3.0 -> 13.1.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:18; pub-outdated.txt:102 |
| drift | 2.29.0 | 2.32.1 | 2.29.0 -> 2.32.1 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:19; pub-outdated.txt:103 |
| excel | 4.0.6 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:20; pub-outdated.txt:92 |
| file_picker | 11.0.2 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:21; pub-outdated.txt:92 |
| firebase_analytics | 12.2.0 | 12.3.0 | 12.2.0 -> 12.3.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:22; pub-outdated.txt:104 |
| firebase_app_check | 0.4.2 | 0.4.3 | 0.4.2 -> 0.4.3 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:23; pub-outdated.txt:105 |
| firebase_auth | 6.3.0 | 6.4.0 | 6.3.0 -> 6.4.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:24; pub-outdated.txt:106 |
| firebase_core | 4.6.0 | 4.7.0 | 4.6.0 -> 4.7.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:25; pub-outdated.txt:107 |
| firebase_crashlytics | 5.1.0 | 5.2.0 | 5.1.0 -> 5.2.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:26; pub-outdated.txt:108 |
| firebase_database | 12.2.0 | 12.3.0 | 12.2.0 -> 12.3.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:27; pub-outdated.txt:109 |
| firebase_messaging | 16.1.3 | 16.2.0 | 16.1.3 -> 16.2.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:28; pub-outdated.txt:110 |
| firebase_performance | 0.11.2 | 0.11.3 | 0.11.2 -> 0.11.3 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:29; pub-outdated.txt:111 |
| firebase_remote_config | 6.3.0 | 6.4.0 | 6.3.0 -> 6.4.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:30; pub-outdated.txt:112 |
| firebase_storage | 13.2.0 | 13.3.0 | 13.2.0 -> 13.3.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:31; pub-outdated.txt:113 |
| flutter | 0.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:32; pub-outdated.txt:92 |
| flutter_image_compress | 2.4.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:33; pub-outdated.txt:92 |
| flutter_inappwebview | 6.1.5 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:34; pub-outdated.txt:92 |
| flutter_local_notifications | 20.1.0 | 21.0.0 | 20.1.0 -> 21.0.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:35; pub-outdated.txt:114 |
| flutter_localizations | 0.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:36; pub-outdated.txt:92 |
| flutter_onnxruntime | 1.6.4 | 1.7.0 | 1.6.4 -> 1.7.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:37; pub-outdated.txt:115 |
| flutter_secure_storage | 10.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:38; pub-outdated.txt:92 |
| flutter_web_plugins | 0.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:39; pub-outdated.txt:92 |
| freerasp | 7.5.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:40; pub-outdated.txt:92 |
| get_it | 9.2.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:41; pub-outdated.txt:92 |
| html | 0.15.6 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:42; pub-outdated.txt:92 |
| html_unescape | 2.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:43; pub-outdated.txt:92 |
| http | 1.6.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:44; pub-outdated.txt:92 |
| http_certificate_pinning | 3.0.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:45; pub-outdated.txt:92 |
| image | 4.3.0 | 4.8.0 | 4.3.0 -> 4.8.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:46; pub-outdated.txt:116 |
| image_cropper | 12.2.0 | 12.2.1 | 12.2.0 -> 12.2.1 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:47; pub-outdated.txt:117 |
| image_picker | 1.2.1 | 1.2.2 | 1.2.1 -> 1.2.2 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:48; pub-outdated.txt:118 |
| in_app_review | 2.0.11 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:49; pub-outdated.txt:92 |
| intl | 0.20.2 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:50; pub-outdated.txt:92 |
| package_info_plus | 9.0.1 | 10.1.0 | 9.0.1 -> 10.1.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:51; pub-outdated.txt:119 |
| path | 1.9.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:52; pub-outdated.txt:92 |
| path_provider | 2.1.5 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:53; pub-outdated.txt:92 |
| permission_handler | 12.0.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:54; pub-outdated.txt:92 |
| provider | 6.1.5+1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:55; pub-outdated.txt:92 |
| rxdart | 0.28.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:56; pub-outdated.txt:92 |
| sembast_web | 2.4.2 | 2.4.4+1 | 2.4.2 -> 2.4.4+1 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:57; pub-outdated.txt:120 |
| share_plus | 12.0.2 | 13.1.0 | 12.0.2 -> 13.1.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:58; pub-outdated.txt:121 |
| shared_preferences | 2.5.5 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:59; pub-outdated.txt:92 |
| sqlcipher_flutter_libs | 0.6.8 | 0.7.0+eol | 0.6.8 -> 0.7.0+eol | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:60; pub-outdated.txt:122 |
| sqlite3 | 2.9.4 | 3.3.1 | 2.9.4 -> 3.3.1 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:61; pub-outdated.txt:123 |
| timeago | 3.7.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:62; pub-outdated.txt:92 |
| url_launcher | 6.3.2 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:63; pub-outdated.txt:92 |
| uuid | 4.5.3 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:64; pub-outdated.txt:92 |
| wakelock_plus | 1.4.0 | 1.6.0 | 1.4.0 -> 1.6.0 | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:65; pub-outdated.txt:124 |
| web | 1.1.1 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | See platform matrix | pub-deps.txt:66; pub-outdated.txt:92 |
| build_resolvers (transitive) | 3.0.3 | 3.0.4 | 3.0.3 -> 3.0.4 | Not captured | Not captured | Not captured | Discontinued | Build tooling | pub-deps.txt:105; pub-outdated.txt:198 |
| build_runner_core (transitive) | 9.3.1 | 9.3.2 | 9.3.1 -> 9.3.2 | Not captured | Not captured | Not captured | Discontinued | Build tooling | pub-deps.txt:106; pub-outdated.txt:199 |
| dio (transitive) | 5.9.2 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | Networking transport (Algolia SDK) | pub-deps.txt:129; lib/repositories/algolia/algolia_pinning_interceptor.dart:5-8 |
| pointycastle (transitive) | 4.0.0 | Not listed | No newer version reported in snapshot | Not captured | Not captured | Not captured | Unknown | Crypto primitives | pub-deps.txt:238 |
| algolia_client_core (transitive) | 1.46.2 | 1.49.0 | 1.46.2 -> 1.49.0 | Not captured | Not captured | Not captured | Unknown | Search SDK internals | pub-deps.txt:91; pub-outdated.txt:138 |
| algolia_client_search (transitive) | 1.46.2 | 1.49.0 | 1.46.2 -> 1.49.0 | Not captured | Not captured | Not captured | Unknown | Search SDK internals | pub-deps.txt:93; pub-outdated.txt:140 |
| algolia_client_insights (transitive) | 1.46.2 | 1.49.0 | 1.46.2 -> 1.49.0 | Not captured | Not captured | Not captured | Unknown | Search SDK internals | pub-deps.txt:92; pub-outdated.txt:139 |
| sqflite (transitive) | 2.4.2 | 2.4.2+1 | 2.4.2 -> 2.4.2+1 | Not captured | Not captured | Not captured | Unknown | Local DB infra | pub-deps.txt:261; pub-outdated.txt:178 |
| _flutterfire_internals (transitive) | 1.3.68 | 1.3.69 | 1.3.68 -> 1.3.69 | Not captured | Not captured | Not captured | Unknown | Firebase internals | pub-deps.txt:90; pub-outdated.txt:137 |
```

### Vulnerability Report

No confirmed CVE IDs were present in the captured artifacts.

1. Scan signal quality is degraded in the provided `pub-outdated` run because advisory decoding failed for multiple packages (`archive`, `dio`, `http`, `shared_preferences_android`), so this snapshot cannot prove zero known CVEs by itself (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:1-88`).
2. The pre-analysis artifact inventory does not include `flutter pub audit` output or a saved `osv-scanner.txt` result, so vulnerability triage evidence is incomplete in this run (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`, `docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:33`).
3. CI does have dependency-audit gates: OSV on `pubspec.lock` and `npm audit --audit-level=high`, with workflow failure on scanner failure (`.github/workflows/dep-audit.yml:50-57`, `.github/workflows/dep-audit.yml:69-73`, `.github/workflows/dep-audit.yml:96-97`).
4. `http_certificate_pinning` is integrated, but host pin lists are currently TODO/empty; the code explicitly falls through to platform trust store when pin list is empty (`lib/services/security/cert_pin_config.dart:34-71`, `lib/services/security/cert_pin_config.dart:12-14`, `lib/services/security/pinned_http_client.dart:87-93`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:79-82`).

Security-critical package assessment:
- `sqlcipher_flutter_libs` (0.6.8): Used with Drift + SQLCipher open override and secure key management (`pubspec.lock:1956-1963`, `lib/core/storage/drift/app_database.dart:10-11`, `lib/core/storage/drift/app_database.dart:133-155`).
- `http_certificate_pinning` (3.0.1): Wired in two client layers, but currently no active fingerprints in config (`pubspec.lock:1218-1225`, `lib/services/security/pinned_http_client.dart:25`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:30`, `lib/services/security/cert_pin_config.dart:34-71`).
- `flutter_secure_storage` (10.0.0): Stores DB encryption key (`pubspec.lock:1027-1034`, `lib/core/storage/drift/app_database.dart:9`, `lib/core/storage/drift/app_database.dart:121-124`, `lib/core/storage/drift/app_database.dart:166-172`).
- `firebase_app_check` (0.4.2): Activated at app startup with platform providers (`pubspec.lock:604-611`, `lib/main.dart:117`, `lib/main.dart:213-223`).
- `crypto` (3.0.7): Used for hashing/parsing/cache flows (`pubspec.lock:380-387`, `lib/core/utils/crypto_utils.dart:2`, `lib/services/ocr_extraction_service.dart:7`).
- `pointycastle` (4.0.0): Transitive only in this snapshot (`pubspec.lock:1687-1694`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:238`).
- `flutter_jailbreak_detection`: Not present; project uses `freerasp` for device integrity (`pubspec.yaml:35`, `pubspec.lock:1085-1092`, `lib/services/device_integrity_service.dart:8`).

### License Compliance Matrix

Per orchestrator dedup, legal-grade license compliance ownership belongs to Prompt 11; this report records only dependency-evidence-level observations (`docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:226-228`).

- Permissive (safe): Not verified from provided artifacts.
- Weak copyleft (review): Not verified from provided artifacts.
- Strong copyleft (CRITICAL): No evidence captured in this artifact set.
- Unknown/missing (CRITICAL): License metadata was not included in pre-analysis outputs; `pubspec.lock` contains package hashes/sources/versions but no license fields (`pubspec.lock:6-11`, `pubspec.lock:2292-2294`), and no dedicated license-audit artifact is listed (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).

Attribution implementation exists in-app via `showLicensePage` (`lib/views/settings/account_security_view.dart:377-380`).

### Bloat Analysis

- Dependency counts: 61 direct + 18 dev + 210 transitive = 289 resolved packages (derived from `pubspec.lock` dependency classifications and package map; examples: `pubspec.lock:45`, `pubspec.lock:165`, `pubspec.lock:157`, package block starts at `pubspec.lock:3`).
- Unused direct dependencies: no clear runtime dead package identified from artifact review; `cupertino_icons` appears unimported by `package:` path but icon symbols are actively used through Flutter Cupertino APIs (`pubspec.yaml:19`, `lib/widgets/common/icons/adaptive_icon.dart:77`, `lib/widgets/common/icons/adaptive_icon.dart:549`).
- Overlap check: direct `http` + transitive `dio` is intentional, with `dio` constrained to Algolia integration glue (`pubspec.yaml:51`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:5-8`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:21-22`).
- Heaviest/riskier native deps (justified by feature scope):
  - `flutter_inappwebview` used for extraction/scraping (`pubspec.yaml:80`, `lib/services/extraction/web_scraper.dart:5`).
  - `drift` + `sqlcipher_flutter_libs` + `sqlite3` used for encrypted local database (`pubspec.yaml:43-45`, `pubspec.yaml:93`, `lib/core/storage/drift/app_database.dart:5-11`).
  - Firebase package suite drives core backend features (`pubspec.yaml:22-33`).
- Replacement candidates:
  - `receive_intent` migration already completed to `app_links` (cross-platform) (`pubspec.yaml:87`).
  - No immediate low-effort replacements identified for high-impact native packages without feature loss.

### Supply Chain Assessment

- Publisher verification summary: Not captured in pre-analysis artifacts (no pub.dev publisher export present) (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).
- Dependabot configuration audit:
  - Weekly Monday cadence for `pub`, `npm`, and `github-actions` (`.github/dependabot.yml:16-18`, `.github/dependabot.yml:57-60`, `.github/dependabot.yml:94-96`).
  - PR limits are set to 5 for all three ecosystems (`.github/dependabot.yml:18`, `.github/dependabot.yml:60`, `.github/dependabot.yml:96`).
  - Grouping exists for Firebase and non-Firebase pub dependencies (`.github/dependabot.yml:25-40`).
  - All major updates are globally ignored across ecosystems (`.github/dependabot.yml:41-44`, `.github/dependabot.yml:85-88`, `.github/dependabot.yml:109-112`).
  - Known pinning exceptions for `device_info_plus` and `connectivity_plus` are documented (`.github/dependabot.yml:45-52`).
- Lock file integrity status:
  - Lockfile is generated by pub and includes per-package SHA256 + source URL (`pubspec.lock:1-2`, `pubspec.lock:8-10`).
  - Resolved package sources are hosted pub.dev or Flutter SDK entries (`pubspec.lock:10`, `pubspec.lock:839`, `pubspec.lock:1083`).
- Build reproducibility assessment: `pubspec.lock` + CI dependency audit and deterministic `flutter pub get` steps support reproducibility (`.github/workflows/dep-audit.yml:41-43`, `.github/workflows/dep-audit.yml:50-57`).

### Platform Compatibility Matrix

| Area | Evidence | Status |
|------|----------|--------|
| Android API target requirements | `compileSdk = 36`, `targetSdk = 36` (`android/app/build.gradle.kts:19`, `android/app/build.gradle.kts:38`) | Meets 2026 floor (>=35) |
| Android AAB requirement | CI builds app bundle (`flutter build appbundle`) and verifies release signing (`.github/workflows/build-validation.yml:188-195`, `.github/workflows/build-validation.yml:196-214`) | Compliant |
| iOS deployment target | Podfile pins iOS 17.0 globally (`ios/Podfile:1`, `ios/Podfile:50`) | Compatible with current plugin set |
| Deep-linking package choice | `app_links` declared and explicitly replaces Android-only `receive_intent` (`pubspec.yaml:87`) | Improved cross-platform posture |
| `flutter_inappwebview` platform breadth | Android/iOS/macOS/web/windows platform packages are resolved (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:34`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:165-171`) | Broad coverage for target platforms |
| `image_picker` platform breadth | Android/iOS/linux/macos/web/windows implementations resolved (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:48`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:197-203`) | Broad coverage |

### Upgrade Roadmap

Prioritized upgrade list grouped by complexity:

```markdown
## Simple Upgrades (drop-in, no breaking changes)
| Package | From | To | Effort |
|---------|------|----|--------|
| firebase_core | 4.6.0 | 4.7.0 | 1h |
| firebase_auth | 6.3.0 | 6.4.0 | 1h |
| firebase_app_check | 0.4.2 | 0.4.3 | 0.5h |
| firebase_storage | 13.2.0 | 13.3.0 | 1h |
| image_picker | 1.2.1 | 1.2.2 | 0.5h |
| image_cropper | 12.2.0 | 12.2.1 | 0.5h |
| wakelock_plus | 1.4.0 | 1.6.0 | 0.5h |

## Medium Upgrades (documented migration, limited changes)
| Package | From | To | Breaking Changes | Effort |
|---------|------|----|-----------------|--------|
| app_links | 6.4.1 | 7.0.0 | Major-version API review likely required | 1-2d |
| archive | 3.6.1 | 4.0.9 | Major-version serialization/archive API deltas | 0.5-1d |
| flutter_local_notifications | 20.1.0 | 21.0.0 | Major plugin changes + platform behavior checks | 1-2d |
| package_info_plus | 9.0.1 | 10.1.0 | Major plugin API/Platform interface updates | 0.5-1d |
| share_plus | 12.0.2 | 13.1.0 | Major plugin API/Platform interface updates | 0.5-1d |
| sqlite3 | 2.9.4 | 3.3.1 | Major native DB ABI/API validation | 1d |

## Complex Upgrades (major migration, cascade effects)
| Package Group | From | To | Risk | Effort | Notes |
|--------------|------|----|------|--------|-------|
| csv + Dart SDK | csv 6.0.0 | csv 8.0.0 | High | 2-3d | csv is 2 majors behind and pubspec comments state 7/8 require newer Dart (`pubspec.yaml:81`, `pub-outdated.txt:101`) |
| drift toolchain | drift/drift_dev 2.29.0 + build_runner 2.7.1 | drift 2.32.x line | High | 2-4d | Version coupling is explicit; maintain drift_dev compatibility gate (`pubspec.yaml:43`, `pubspec.yaml:113-114`, `pub-outdated.txt:103`, `pub-outdated.txt:127`, `pub-outdated.txt:129`) |
| device_info_plus + connectivity_plus | 12.3.0 / 7.0.0 | 13.1.0 / 7.1.1 | High | 1-2d | Explicitly pinned due iOS validation regressions (BUT-750) (`pubspec.yaml:34`, `pubspec.yaml:52`, `.github/dependabot.yml:45-52`) |
| pinning hardening | http_certificate_pinning 3.0.1 | n/a (config completion) | High | 0.5-1d | Populate real SPKI fingerprints for pinned hosts to activate protection (`lib/services/security/cert_pin_config.dart:34-71`) |
```

Testing requirements per upgrade wave:
- Re-run `flutter analyze` and `flutter test --coverage` for every wave; current full-suite run is blocked by repeated 10-minute timeouts in `test/views/helpers/infrastructure_integration_test.dart`, so infra stabilization is required for trustworthy upgrade regression gating (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508-31518`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31526-31528`).

### Issues by Severity (Phase 2 Input)

```markdown
## CRITICAL (fix immediately)
- None confirmed from captured artifacts (no CVE IDs or strong-copyleft proofs were present in this run).

## HIGH (fix within current sprint)
- Vulnerability evidence gap: advisory decode failures in outdated output; missing saved pub audit/OSV outputs in this artifact set (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:1-88`, `docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).
- Certificate pinning not active for configured high-value hosts because fingerprints are TODO/empty (`lib/services/security/cert_pin_config.dart:34-71`, `lib/services/security/pinned_http_client.dart:87-93`).
- Transitive discontinued build packages: `build_resolvers` and `build_runner_core` (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:198-199`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:215-218`).
- `sqlcipher_flutter_libs` latest channel marker includes `+eol`, requiring maintenance/replacement decision (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:122`).

## MEDIUM (scheduled remediation)
- 44 dependencies are locked older than available upgrades (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:209-210`).
- 2 direct dependencies are constraint-blocked (`connectivity_plus`, `device_info_plus`) (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:100`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:102`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:212-213`).
- Direct major-version lag on 8 packages (including `csv` at +2 majors) (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:96-97`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:101-102`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:114`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:119`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:121`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:123`).
- License metadata not captured in this pre-analysis run; legal-grade verification remains pending (`pubspec.lock:6-11`, `docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:226-228`).
- Dependabot ignores all semver-major updates globally, increasing latent drift risk (`.github/dependabot.yml:41-44`, `.github/dependabot.yml:85-88`, `.github/dependabot.yml:109-112`).
- No captured publisher-verification evidence for direct dependencies (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).
- Drift toolchain version coupling limits upgrade agility (`pubspec.yaml:43`, `pubspec.yaml:113-114`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:103`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:127`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:129`).

## LOW (backlog)
- Fill package health metadata gaps (pub points, last-updated, verified publisher) in future pre-analysis capture (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).
- Add explicit Dependabot reviewer assignment if governance requires it (`.github/dependabot.yml:11-112`).
- Consider documenting dependency acceptance policy for native-heavy packages (`pubspec.yaml:80`, `pubspec.yaml:43-45`).
- Tighten periodic checks for dormant transitive dependencies (`docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:88-298`).

Total issues: 15
Estimated total remediation effort: 8-14 days
```

---

## Phase 1 Deliverables Checklist

- [x] Executive summary with overall score (69/100)
- [x] Detailed findings for all 7 dimensions
- [x] Package health dashboard (all direct + key transitive dependencies)
- [x] Vulnerability report with CVE details and CVSS scores (none confirmed in captured artifacts)
- [x] License compliance matrix (artifact-level, legal-grade follow-up deferred per dedup)
- [x] Bloat analysis (unused, overlapping, heavy packages)
- [x] Supply chain assessment (publishers/dependabot/lock file)
- [x] Platform compatibility matrix
- [x] Security-critical packages individually assessed
- [x] Upgrade roadmap with sequence, effort, and risk
- [x] Issues classified by severity with counts
- [x] ZERO dependency changes made
