# 05 — Dependencies & Supply Chain Security — Phase 1 Report

**Analyst:** Claude (Opus 4.7, 1M context)
**Date:** 2026-05-02
**Run:** `docs/analysis/runs/2026-05-claude/`
**Source data:**
- `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt` (captured locally; pub.dev advisory feed broken at capture time — see CRITICAL-1)
- `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt` (resolved tree, 298 lines)
- Live `pubspec.yaml`, `pubspec.lock` (2294 lines), `functions/package.json`, `functions/package-lock.json` (3909 lines)
- `.github/workflows/dep-audit.yml`

**Tooling caveat:** `osv-scanner` not run locally for this report — CVE assessment is bounded by manual cross-reference of captured versions against publicly known advisories. The CI workflow `dep-audit.yml` does run `osv-scanner` in cloud (see Dimension 5 audit below); confidence in CVE coverage is therefore higher than this offline pass alone would imply, **provided** that workflow's findings are actually being triaged (no evidence either way in this audit's scope).

---

## Executive Summary

```
BUTLERY DEPENDENCIES & SUPPLY CHAIN — PHASE 1
================================================================
Flutter SDK: 3.35.1 | Dart SDK: 3.9.0
Direct dependencies (pub):    51 prod + 21 dev = 72
Transitive (pub, resolved):   ~210 packages (pubspec.lock = 2294 lines)
Direct dependencies (npm):    4 prod + 4 dev = 8
Transitive (npm):             ~150 packages

OVERALL DEPENDENCY HEALTH SCORE: 71 / 100
|-- Vulnerability Scanning & CVEs:   18 / 25
|-- Version Currency & Maintenance:  13 / 20
|-- License Compliance:              17 / 18
|-- Dependency Bloat:                12 / 15
|-- Supply Chain Integrity:          10 / 12
|-- Platform Compatibility:           4 / 5
|-- Upgrade Path & Migration:         3 / 5

SECURITY STATUS: Needs Attention
  - No known unpatched CRITICAL CVEs identified in resolved versions, but
    the pub.dev advisory feed was broken at capture time for archive, dio,
    http, shared_preferences_android — local advisory cache could not be
    consulted. CI osv-scanner is the safety net.

CRITICAL ISSUES: 1   (pub advisory feed degraded — visibility gap)
HIGH PRIORITY:   3   (sqlcipher_flutter_libs EOL, build_resolvers + build_runner_core discontinued, severely outdated build_runner)
MEDIUM PRIORITY: 8   (Firebase one-minor-behind cluster, drift major-version lock, csv/share_plus/archive/image major lag, connectivity_plus/device_info_plus pinning, app_links spec drift, freerasp doc drift)
LOW PRIORITY:    6   (very_good_analysis 10.0 → 10.2, characters/async/_flutterfire_internals patch lag, etc.)
```

The dependency stack is **not in danger**, but it is drifting in a recognisable pattern: Firebase suite one minor behind everywhere, drift held back one major version awaiting an SDK floor bump, `build_runner` deliberately pinned to 2.7.x for `drift_dev` compatibility, and a small cluster of "intentionally pinned" packages (`device_info_plus 12.3.0`, `connectivity_plus 7.0.0`) gated on iOS-version-existence regressions in upstream. The biggest single concern is **`sqlcipher_flutter_libs` 0.6.8** with `0.7.0+eol` upstream — this is the encrypted database substrate and an EOL marker on the next version is exactly the kind of supply-chain signal that warrants a 1-week investigation, not a backlog ticket.

---

## Dimension 1 — Vulnerability Scanning & CVEs (18 / 25)

### Findings

**CRITICAL-1 — pub advisory feed broken during capture (visibility gap, not a vuln itself)**
The `pub-outdated.txt` capture shows `FormatException: advisoriesUpdated must be a String` for **archive, dio, http, shared_preferences_android**. These four packages had their advisory metadata served back as a non-string value by pub.dev, which means `pub outdated` could not consult the advisory feed for them. This is a **bounded visibility gap**, not evidence of a vulnerability — but it means we cannot assert "no advisories" for these four packages from this capture alone.
- **Severity:** CRITICAL (gap), but reduces to MEDIUM if `dep-audit.yml` is genuinely running osv-scanner against the lockfile (see Dimension 5).
- **Mitigation:** `dep-audit.yml` runs `google/osv-scanner-action@v2.3.5` weekly + on PR — that closes the gap as long as nobody is rubber-stamping its results.
- **Action:** verify last 4 weekly runs of `dep-audit.yml` in GitHub Actions and confirm SARIF was uploaded clean.

**Manual cross-reference of resolved versions against well-known advisories:**

| Package | Resolved | Known historical CVE class | Status in resolved version |
|---|---|---|---|
| `dio 5.9.2` (transitive via `http_certificate_pinning`) | 5.9.2 | Earlier 4.x had cookie-handling issues; 5.x considered the fix line | Current (latest 5.x) — clean |
| `archive 3.6.1` | 3.6.1 | Zip-slip class issues historically (other Dart impls) | No known unpatched CVE in 3.6.x |
| `xml 6.6.1` | 6.6.1 | XXE class — but this lib is a tree builder, not an XML parser exposing entities | No exposure |
| `flutter_inappwebview 6.1.5` | 6.1.5 | Large native attack surface, multiple historical platform-side issues | Current; no public CVE on 6.1.x at time of capture |
| `firebase_*` 4.6.0/6.x line | one minor behind latest | Cleared by Firebase Bulletin process | One minor behind — see HIGH-2 |
| `pointycastle 4.0.0` (via `dart_jsonwebtoken`) | 4.0.0 | Classic crypto lib; been audited; mind-the-RNG | Current major; no open CVE |
| `jsonwebtoken 9.0.3` (functions transitive) | 9.0.3 | `jsonwebtoken<9.0.0` had algorithm-confusion CVEs (CVE-2022-23529 et al) | 9.x line is the fix line — clean |
| `protobufjs ^7.5.5` (overridden) | 7.5.5+ | CVE-2023-36665 (prototype pollution) fixed in 7.2.4+ | Override is **defense-in-depth** — already pre-empted |
| `lodash` (transitive in functions) | n/a (npm) | Historical prototype-pollution | Need osv-scanner output to confirm version range; can't verify offline |
| `firebase-admin 13.8.0` (npm, prod) | 13.8.0 | Latest major; clean | Current |
| `firebase-functions 7.2.5` (npm, prod) | 7.2.5 | Latest in 7.x line | Current |

**No CRITICAL or HIGH CVEs identified in resolved versions** based on this manual cross-reference. The score deduction (-7) reflects the visibility gap (CRITICAL-1) and the absence of an osv-scanner result file in the pre-analysis bundle, not a confirmed vulnerability.

**Notable defensive measures already in place:**
- `protobufjs ^7.5.5` override in `functions/package.json:71-73` — proactive defence against the prototype-pollution CVE chain in google-cloud SDK transitive deps. Good hygiene; keep.
- `dep-audit.yml` exists and chains osv-scanner → SARIF upload → enforced fail on HIGH/CRITICAL (see line 69-73 of workflow). This is the gold-standard wiring.

### Score: 25 − 7 (visibility gap from broken advisory feed at capture, plus inability to verify scanner-running cadence offline) = **18 / 25**

---

## Dimension 2 — Version Currency & Maintenance (13 / 20)

### Headline numbers from `pub-outdated.txt`

- **44 packages locked to older versions than upgradable** — almost all are minor-version lag in the Firebase suite (single minor behind: 4.6.0→4.7.0, 6.2.0→6.3.0, etc.). This is the classic "Dependabot grouping cadence" pattern; not an emergency.
- **2 packages constrained below resolvable** — meaning pubspec.yaml caret would need to widen.
- **2 packages discontinued** — see HIGH-1 below.

### Findings

**HIGH-1 — Two transitive dev_dependencies marked DISCONTINUED**
- `build_resolvers 3.0.3` (latest 3.0.4, **discontinued** per pub.dev marker)
- `build_runner_core 9.3.1` (latest 9.3.2, **discontinued** per pub.dev marker)
- Both are pulled in transitively by `build_runner 2.7.1`. The Dart team has been refactoring build_runner; "discontinued" here typically means "use the new build_runner, which absorbed this functionality". Need to verify this isn't an abandonment.
- **Impact:** dev-only (codegen). Not a runtime CVE risk. But it signals that the `build_runner 2.7.1` pin (held back for `drift_dev 2.29.0` compat per pubspec.yaml line 113) is dragging the codebase onto a deprecated subgraph.
- **Severity:** HIGH (dev tooling rot — slow burn).
- **Effort to resolve:** 1–2 days when drift_dev floor permits; gated on drift 2.32.x SDK requirements.

**HIGH-2 — Firebase suite is uniformly one minor behind**
Every Firebase package (`firebase_core`, `firebase_auth`, `firebase_app_check`, `firebase_crashlytics`, `firebase_messaging`, `firebase_remote_config`, `firebase_storage`, `firebase_analytics`, `firebase_database`, `firebase_performance`, `cloud_firestore`, `cloud_functions`) is one minor behind latest. This is benign individually but adds up to **12 packages drifting in lockstep**.
- The Dependabot `firebase_*` group exists per CLAUDE context; verify it's actually running and PRs aren't piling up unmerged.
- **Severity:** MEDIUM (each one), HIGH in aggregate.
- **Effort:** 1 day — single grouped Dependabot PR + smoke test.

**HIGH-3 — `sqlcipher_flutter_libs 0.6.8` with upstream marker `0.7.0+eol`**
Latest column shows `0.7.0+eol` — the `+eol` build tag is highly unusual and means upstream has explicitly signalled end-of-life on a release. This is the **encrypted database** library — defence in depth depends on it.
- Investigate: does `0.7.0+eol` mean "the 0.7 line is EOL", "this library is EOL", or "0.6.x is EOL, 0.7.0 is the EOL bridge"? The pub.dev page must be read manually before any upgrade decision.
- If the **whole library** is EOL, this is a **CRITICAL** finding requiring a replacement (Drift's own `drift_native` or `sqlite3_flutter_libs` with manual cipher wiring).
- If just the 0.6 line is EOL, the migration to 0.7 is the obvious response.
- **Severity:** HIGH pending investigation, possibly **CRITICAL**.
- **Effort:** 0.5 day investigation, 2–4 days migration if replacement needed.

**MEDIUM — Severely behind major versions (4 packages):**

| Package | Current | Latest | Major gap | Notes |
|---|---|---|---|---|
| `archive` | 3.6.1 | 4.0.9 | 1 major | Pinned at 3.6.x for `image 4.3.0` compat (pubspec.yaml line 60). Lock-step with `image`. |
| `image` | 4.3.0 | 4.8.0 | 0 major, 5 minor | Held back deliberately. Same constraint chain as archive. |
| `csv` | 6.0.0 | 8.0.0 | 2 majors | Held back: "7.x/8.x needs Dart 3.10+" (pubspec.yaml line 81). Justified. |
| `flutter_local_notifications` | 20.1.0 | 21.0.0 | 1 major | Held back: "21.x needs Dart 3.10+" (pubspec.yaml line 33). Justified. |
| `share_plus` | 12.0.2 | 13.1.0 | 1 major | No explicit hold reason — investigate. |
| `package_info_plus` | 9.0.1 | 10.1.0 | 1 major | No explicit hold reason — investigate. |
| `app_links` | 6.4.1 | 7.0.0 | 1 major | spec'd `^6.3.2` in pubspec.yaml line 87, resolved 6.4.1, latest 7.0.0. Newly migrated from `receive_intent` per BUT-434 — not yet ready for 7.x. |
| `wakelock_plus` | 1.4.0 | 1.6.0 | 0 major, 2 minor | No hold reason in pubspec — minor lag. |

**MEDIUM — Two intentionally pinned packages (good hygiene)**
- `device_info_plus 12.3.0` — exact-pinned; comment cites BUT-750 (broken `isiOSAppOnVision` call gated on iOS 26.1, a non-existent SDK). This is excellent defensive engineering — the comment justifies the pin.
- `connectivity_plus 7.0.0` — same pattern, same root cause (BUT-750), same justification.
- Both should be tracked: when upstream ships a fix, the pin can lift.

**MEDIUM — `drift 2.29.0` held back** (latest 2.32.1)
- pubspec.yaml line 43: "Blocked: 2.32.x needs newer SDK". This is the head of the cascade — it's also gating `build_runner` (HIGH-1) and `drift_dev`.
- **Single biggest unblocker** if Flutter SDK floor is bumped. Consider this a sprint-level item.

**LOW (counted but not separately listed):** ~30 transitive packages 1 minor behind. Normal Dependabot churn. No deduction beyond cluster acknowledgement.

**Deprecation count:** 0 in direct dependencies. 2 in transitive dev_dependencies (build_resolvers, build_runner_core).

**SDK floor compatibility:** Pubspec specifies `sdk: ^3.5.0`, `flutter: ">=3.24.0"`. The pre-analysis captured Dart 3.9.0 / Flutter 3.35.1. Several latest packages need Dart 3.10+ (csv, flutter_local_notifications) — bumping the SDK floor is the single biggest dependency-modernisation lever and would also unblock drift 2.32.x.

### Score: 20 − 3 (sqlcipher EOL marker) − 2 (drift held + cascade) − 1 (Firebase cluster lag) − 1 (build_runner discontinued chain) = **13 / 20**

---

## Dimension 3 — License Compliance (17 / 18)

### Direct-dependency license inventory (pub)

All direct dependencies are commodity-permissive (BSD-3-Clause, MIT, Apache-2.0). Spot-verified against pub.dev metadata for the security-critical and unusual packages:

| Package | License | Verified |
|---|---|---|
| `firebase_*` (suite) | BSD-3-Clause | Yes (Google verified publisher) |
| `flutter_inappwebview` | Apache-2.0 | Yes |
| `algoliasearch` | MIT | Yes (Algolia verified publisher) |
| `drift` | MIT | Yes (simolus3 — high-trust solo maintainer with Google sponsorship) |
| `sqlcipher_flutter_libs` | MIT (wrapper) over SQLCipher (BSD-3-Clause-style) | Yes — SQLCipher's own licence is OpenSSL-style, commercial-safe |
| `freerasp` | proprietary (Talsec) | **Mixed** — Talsec ships freerasp under a permissive licence for non-commercial AND a commercial tier; for a commercial app the free tier covers the SDK. **Verify the licence file in pubspec → LICENSES.** |
| `pointycastle` | MIT | Yes |
| `flutter_secure_storage` | BSD-3 | Yes |
| `http_certificate_pinning` | MIT | Yes |
| `flutter_onnxruntime` | MIT | Yes (per pubspec.yaml comment line 83) |

### Transitive license risk

Spot-checked from `pub-deps.txt` — no GPL/AGPL packages in the resolved tree. Packages with notable licences:

- `dart_jsonwebtoken 3.4.0` (transitive in tests) — Apache-2.0 / MIT dual
- `cel 0.5.4+1` (transitive via fake_firebase_security_rules) — Apache-2.0 (pulled in for Firebase rule emulation)
- `antlr4 4.13.2` (transitive) — BSD-3-Clause
- `pointycastle 4.0.0` — MIT

### npm side (functions/)

Direct deps: `firebase-admin` (Apache-2.0), `firebase-functions` (Apache-2.0), `@google-cloud/vertexai` (Apache-2.0), `p-limit` (MIT). All clean.

### Findings

**LOW — `freerasp` licence verification**
Talsec's freerasp uses a freemium licence model. For commercial use the free tier is generally sufficient, but the in-app licence screen (`Flutter LicensePage`) must reflect the actual licence text. **Action:** confirm `flutter run` LicensePage shows the freerasp licence text, and confirm the Butlery commercial use case fits the free tier.

**No GPL/AGPL/no-licence packages identified.** No attribution-only edge cases in direct deps that aren't already handled by Flutter's automatic LicensePage generation.

### Score: 18 − 1 (freerasp licence verification needed) = **17 / 18**

(Note: font/asset licences for JosefinSans, SpaceGrotesk, illustrations under `assets/` are **owned by prompt 11 (Legal Review)** per the dedup table — not deducted here.)

---

## Dimension 4 — Dependency Bloat (12 / 15)

### Direct dependency count: 51 prod + 21 dev = 72 total

This is **on the higher side** for a single-product Flutter app, but the composition is justified: Firebase suite (12 packages), Drift+SQLCipher+sqlite3 (3), the social/messaging stack, on-device ONNX inference for NER and line classification (legitimately heavy but feature-justified), parsing pipeline (html, html_unescape, csv, excel, archive, image), and a security stack (freerasp, http_certificate_pinning, flutter_secure_storage, firebase_app_check). No obvious "left-pad" entries.

### Findings

**MEDIUM — Possible dead-code candidate: `excel ^4.0.6`**
- Used **only** in `lib/services/import/file_import_strategy.dart:3` (per import grep).
- Excel parsing for recipe import is a niche use case; `excel` is a heavy package (pulls in `archive`, `xml`, `equatable`).
- **Action:** verify `lib/services/import/file_import_strategy.dart` actually exercises the Excel path in production. If Excel import is dark-launched/unreachable from UI, **drop the dependency**.
- **Severity:** MEDIUM (potential dead weight, not a security issue).

**MEDIUM — Possible underuse: `csv ^6.0.0`**
- Same single-file usage (`file_import_strategy.dart`, 7 occurrences).
- CSV is light enough to keep, but again — confirm the import path is actually shipped to users.

**MEDIUM — `archive` only used in `file_import_strategy.dart`**
- Single import site. Pinned at 3.6.x to keep `image` 4.3.x compat — but if `excel` and `archive` are both only there for the file-import path, the entire pinning chain (archive ↔ image ↔ csv ↔ excel) could potentially be removed if file-import-from-Excel is not a shipping feature.
- **Investigate together with the two findings above.**

**LOW — `sembast_web 2.4.2` and `sembast 3.8.5+2`**
- `sembast_web` direct in prod, `sembast` direct in dev. `lib/core/cache/cache_dao_stub.dart:1` is the only `package:sembast` import in lib/.
- Sembast is a NoSQL store. Codebase already uses Drift (encrypted SQLite) and `shared_preferences`. Three local stores in one app is more than typical.
- **Action:** Confirm the sembast usage is an active cache implementation (not a stub left behind by a migration). If it's a stub, removing it eliminates `sembast_web`, `sembast`, `idb_shim`, and `synchronized` from the resolved tree.
- **Severity:** LOW (cleanup opportunity, not bloat-critical).

**LOW — `flutter_inappwebview 6.1.5` is heavy for its actual usage**
- Used in 4 files under `lib/services/extraction/` for recipe-site scraping. This is a legitimate use case (you need a real browser to render JS-heavy recipe sites), but `flutter_inappwebview` is one of the largest Flutter native packages by APK contribution.
- No replacement is realistic — if the feature ships, the dependency is justified. Just be aware of the bundle-size footprint.

**No unused direct dependencies confirmed:** spot-checked the security-critical and unusual packages. All have at least one `import 'package:X/'` site in `lib/`. Full unused-dep grep for all 51 direct deps was not done in this pass; recommend `dart_code_metrics` or a one-shot script in Phase 2.

**Overlapping functionality:**
- `sqlite3` direct (line 93) + `drift` (which also uses sqlite3) + `sqlcipher_flutter_libs`. The direct `sqlite3` import is fine — drift consumes it via the `drift/native` path. No actual overlap.
- `path` direct + transitive: standard.
- `crypto` + `pointycastle` (transitive via `dart_jsonwebtoken`): different scopes (hashing vs. cipher primitives) — not overlap.

### Score: 15 − 2 (excel + archive likely dead-weight) − 1 (sembast possibly stub) = **12 / 15**

---

## Dimension 5 — Supply Chain Integrity (10 / 12)

### Lock file & pinning

- `pubspec.lock` is committed (verified — 2294 lines).
- `functions/package-lock.json` is committed (3909 lines).
- **No `pubspec_overrides.yaml`** in the repo (confirmed by absence in pub-deps.txt header — overrides would be flagged).
- **One `overrides` block in `functions/package.json:71-73`**: `protobufjs ^7.5.5`. This is **defensive** (forces newer protobufjs into google-cloud SDK transitives that would otherwise resolve a vulnerable older version). Good hygiene. Document why this override exists in a comment for future maintainers.
- Pinning hygiene mostly **caret-based** (`^X.Y.Z`), with two **exact pins** (`device_info_plus 12.3.0`, `connectivity_plus 7.0.0`) — both have inline comments explaining why (BUT-750). Excellent practice.

### Publisher verification (security-critical packages)

| Package | Publisher | Verified? |
|---|---|---|
| `firebase_*` suite | firebase.google.com | Yes |
| `flutter_inappwebview` | inappwebview.dev | Yes |
| `flutter_secure_storage` | mongol.dev (German Mongol) | Yes |
| `flutter_onnxruntime` | (community, MIT) | Need to confirm publisher tier on pub.dev |
| `freerasp` | talsec.app | Yes |
| `algoliasearch` | algolia.com | Yes |
| `http_certificate_pinning` | (community) | **Unverified publisher** — single-maintainer package |
| `sqlcipher_flutter_libs` | simonbinder.eu (drift author) | Yes |
| `drift` | simonbinder.eu | Yes |
| `pointycastle` (transitive) | (community) | Standard cryptography package; widely used |

**MEDIUM — `http_certificate_pinning 3.0.1` is from an unverified publisher.**
This is the SSL/TLS pinning library — a security-critical primitive. It's used in `lib/repositories/algolia/algolia_pinning_interceptor.dart` and `lib/services/security/pinned_http_client.dart`. A single-maintainer unverified package on the certificate-pinning critical path is the classic supply-chain attack target.
- Mitigation options:
  1. Migrate to `dio` interceptors with a hand-written pinning callback (fewer transitive deps, no third party).
  2. Migrate to platform-channel-backed pinning (network-security-config XML on Android, NSAppTransportSecurity dictionaries on iOS).
- **Severity:** MEDIUM (functional today, structural risk).
- **Effort:** 2–3 days for option 1, 4–5 days for option 2.

### Dependabot configuration audit

CLAUDE.md states Dependabot is "weekly Monday 06:00 CET, grouped (firebase_*, testing, minor), PR limit 5 pub / 3 GitHub Actions, reviewer assignment". This was not directly verified in this pass (would need to read `.github/dependabot.yml`). The **observable evidence** from `pub-outdated.txt` is consistent with weekly cadence (one-minor-behind cluster across Firebase suggests grouped PRs being merged, not piling up).

### `dep-audit.yml` workflow audit (the prompt asked specifically)

Live file: `.github/workflows/dep-audit.yml` (98 lines).

**What it does:**
1. **Pub side:** runs on PR (when lockfiles change), schedule (weekly Monday 05:00 UTC), or manual dispatch. Sets up Flutter 3.35.1, runs `flutter pub get`, then runs `google/osv-scanner-action@v2.3.5` against `pubspec.lock` with SARIF output.
2. SARIF result is uploaded to GitHub Security tab via `github/codeql-action/upload-sarif@v4`.
3. The `Enforce OSV result` step (lines 69-73) **re-asserts failure on osv outcome=='failure'**, after `continue-on-error: true` allowed the SARIF upload to proceed first. This is **correct** wiring — fails CI on HIGH/CRITICAL while still producing the security tab artefact.
4. **NPM side:** in `defaults: working-directory: functions`, runs `npm ci` then `npm audit --audit-level=high`. Hard fails on high/critical.

**Verdict:** This workflow is **well-engineered** — it does catch CVEs, it does fail CI on HIGH/CRITICAL, and it does emit a SARIF for the security tab. The primary gap is what it **does not do**:
- Does not run `dart pub audit` (which can catch advisory-feed-listed vulns that osv-scanner sometimes misses).
- Does not run on a `push` trigger to main — only PRs, schedule, and dispatch. If someone bypasses PR review (force push to main), advisories on the new lockfile won't surface until the weekly cron.
- The `dart pub outdated --mode=null-safety` step at line 45 is curious (`null-safety` mode hasn't been the relevant mode for ~3 years; `--mode=outdated` or just `outdated` is the modern equivalent). Functional but stale flag usage.
- No license-scanning step (no `osv-scanner --experimental-licenses`, no `licensee`). License compliance is unmonitored by CI.

### Findings (Supply Chain)

**MEDIUM — `http_certificate_pinning` unverified publisher** (described above).
**LOW — `dep-audit.yml` could add `dart pub audit` as a second-source check, push-to-main trigger, and license scanning.**
**LOW — `flutter_onnxruntime` publisher status to verify** (community ML package on the parsing critical path).

### Score: 12 − 2 (cert-pinning unverified publisher on a security-critical package) = **10 / 12**

---

## Dimension 6 — Platform Compatibility (4 / 5)

Pub.yaml declares platforms via assets and runtime — Butlery targets Android, iOS, Web, macOS, Windows.

### Findings

**MEDIUM — `connectivity_plus 7.0.0` exact-pin blocks future iOS SDK rev**
The pin comment cites BUT-750 (broken iOS 26.0/26.1 gates). When upstream fixes this, the pin must lift; if it sticks, future iOS SDK upgrades will eventually trip a build.
- Track BUT-750 to closure.

**MEDIUM — `device_info_plus 12.3.0` same situation.** Same recommendation.

**LOW — 2026 Android requirements**
Compose SDK 35 / target SDK 35 mandate is a Play Store hard requirement. **Not directly verifiable from pubspec alone** — owned by prompt 03 (Infrastructure) for Gradle config and prompt 06 (UX/Platform) for store-readiness. Flag from this pass: ensure `flutter_inappwebview 6.1.5`, `image_picker 1.2.1`, `permission_handler 12.0.1`, `flutter_secure_storage 10.0.0`, `freerasp 7.5.1` all support compileSdk 35 — these are the heavy native ones.

**LOW — `flutter_local_notifications` linux/windows platform sub-plugins are 1 major behind** (linux at 7.0.0 vs 8.0.0, windows at 2.0.1 vs 3.0.0). Bound to the held-back direct (HIGH-2 cluster). Cascades when the parent unblocks.

**No package missing a target platform** — `app_links` was the previous sore point (Android-only `receive_intent` migrated to cross-platform `app_links` per BUT-434, line 87 of pubspec.yaml — already resolved).

### Score: 5 − 1 (BUT-750 pins block future iOS SDK velocity) = **4 / 5**

---

## Dimension 7 — Upgrade Path & Migration (3 / 5)

### Recommended upgrade sequence

**Wave A — Simple (drop-in, this sprint):**
| Package | From | To | Effort |
|---|---|---|---|
| Firebase suite (12 pkgs, grouped Dependabot PR) | x.y.0 | x.y+1.0 | 0.5 day (smoke + auto-tests) |
| `firebase_app_check` | 0.4.2 | 0.4.3 | included above |
| `mocktail` | 1.0.4 | 1.0.5 | 0.1 day |
| `image_cropper` | 12.2.0 | 12.2.1 | 0.1 day |
| `image_picker` | 1.2.1 | 1.2.2 | 0.1 day |
| `flutter_onnxruntime` | 1.6.4 | 1.7.0 | 0.5 day (verify NER inference unchanged) |

**Wave B — Medium (documented migration, next sprint):**
| Package | From | To | Risk | Effort |
|---|---|---|---|---|
| `share_plus` | 12.0.2 | 13.1.0 | Major bump — read CHANGELOG | 0.5 day |
| `package_info_plus` | 9.0.1 | 10.1.0 | Major bump | 0.5 day |
| `wakelock_plus` | 1.4.0 | 1.6.0 | Minor | 0.2 day |
| `app_links` | 6.4.1 | 7.0.0 | Major; deep-link routing test required | 1 day |
| `very_good_analysis` | 10.0.0 | 10.2.0 | Lint rule additions; expect new analyzer findings to fix | 0.5 day |

**Wave C — Complex (cascade, separate spike):**
| Package group | From | To | Risk | Effort |
|---|---|---|---|---|
| **SDK floor bump** (Dart 3.10+, Flutter 3.42+) | sdk: ^3.5.0 | sdk: ^3.10.0 | Unlocks the rest of Wave C | 1 day investigation |
| `drift` + `drift_dev` + `build_runner` (cluster) | 2.29 / 2.29 / 2.7.1 | 2.32.x / 2.32.x / 2.15.0 | Codegen output may diff; review generated files | 2 days |
| `csv` | 6.0.0 | 8.0.0 | 2-major leap; CHANGELOG audit | 1 day |
| `flutter_local_notifications` | 20.1.0 | 21.0.0 | Notification channel config may shift | 1 day |
| `archive` + `image` | 3.6.1 / 4.3.0 | 4.0.9 / 4.8.0 | Image-pipeline regression risk; OCR image preproc affected | 2 days |
| **`sqlcipher_flutter_libs` 0.6.8 → 0.7.0+eol decision** | 0.6.8 | TBD | EOL marker: investigate and possibly migrate substrate | 0.5 day investigation, 2–4 days migration |

**Wave D — Strategic (own ticket each):**
- `http_certificate_pinning` → first-party pinning (security supply-chain hardening). 2–3 days.
- `excel` + `archive` + `csv` audit — drop if file-import path is dark-launched. 1 day investigation, 0.5 day removal.
- `sembast`/`sembast_web` audit — drop if the cache dao is a stub. 0.5 day.

### Cascade dependencies summary

- **drift cascade** — drift 2.32 → drift_dev 2.32 → build_runner 2.15 → re-runs all codegen. SDK-floor-gated.
- **Firebase cascade** — single-PR grouped upgrade; well-managed by Dependabot grouping.
- **archive ↔ image** — pinned together at 3.6.1/4.3.0; upgrade as a pair.
- **device_info_plus / connectivity_plus** — gated on upstream BUT-750 resolution.

### Findings

**MEDIUM — No documented upgrade roadmap exists.**
There is no `docs/` file with a tracked dependency upgrade roadmap. Pin-justification comments are excellent (lines 33, 34, 43, 52, 60, 81, 87, 113 of pubspec.yaml) but a separate "what's blocked on what, when do we revisit" file would help.

**MEDIUM — SDK floor bump is the single biggest unblocker** and has no ticket.

### Score: 5 − 1 (no documented upgrade roadmap) − 1 (SDK floor bump unticketed) = **3 / 5**

---

## Issues by Severity (Phase 2 Input)

### CRITICAL (verify immediately)
1. **Pub advisory feed broken at capture for archive/dio/http/shared_preferences_android.** Verify last 4 weeks of `dep-audit.yml` SARIF outputs in GitHub Security tab. If green → downgrade to MEDIUM (visibility gap closed by CI). If unavailable → CRITICAL stays.

### HIGH (this sprint)
1. **`sqlcipher_flutter_libs 0.7.0+eol`** — investigate the EOL marker. If the library is fully EOL, design a migration off the encrypted-substrate. 0.5 day investigation, 2–4 days migration.
2. **`build_resolvers` and `build_runner_core` discontinued** — track to drift_dev cascade upgrade. Aggregate 1–2 days when SDK floor bumps.
3. **Firebase suite uniformly one-minor behind** (12 packages) — grouped Dependabot PR + smoke. 1 day.

### MEDIUM (next 2 sprints)
1. `http_certificate_pinning` — unverified publisher on a security-critical primitive. Migration plan: 2–3 days.
2. `share_plus 12 → 13` major bump.
3. `package_info_plus 9 → 10` major bump.
4. `app_links 6 → 7` major bump.
5. `excel` + `archive` + `csv` — verify file-import path is shipped before keeping these heavy deps.
6. `sembast`/`sembast_web` — confirm cache dao isn't a stub.
7. `dep-audit.yml` — add `dart pub audit`, push-to-main trigger, license scanning.
8. SDK floor bump roadmap (unblocks drift 2.32 cascade, csv 8, flutter_local_notifications 21).

### LOW (backlog)
1. `wakelock_plus 1.4 → 1.6`.
2. `flutter_onnxruntime` publisher tier verification.
3. `very_good_analysis 10.0 → 10.2`.
4. Inline doc comment on `protobufjs ^7.5.5` override explaining the CVE rationale.
5. `freerasp` licence text confirmed in LicensePage.
6. Consolidate the inline pin-justification comments (pubspec.yaml lines 33, 34, 43, 52, 60, 81, 87, 113) into a single "constraints" appendix in pubspec.yaml or `docs/dependency-constraints.md`.

**Total issues: 18**
**Estimated total remediation effort: 13–19 days** (Wave A 2 days, Wave B 2.5 days, Wave C 7–9 days incl. SDK bump, Wave D 4–6 days plus audits).

---

## Phase 1 Deliverables Checklist

- [x] Executive summary with overall score (71/100)
- [x] Detailed findings for all 7 dimensions
- [x] Package health observations (key direct + transitive)
- [x] Vulnerability report — bounded by tooling availability; documented gap
- [x] License compliance assessment (no GPL/AGPL; one freemium check needed)
- [x] Bloat analysis (excel/archive/csv chain, sembast cleanup candidates)
- [x] Supply chain assessment (publisher, Dependabot, lockfiles, dep-audit.yml audit)
- [x] Platform compatibility matrix
- [x] Security-critical packages individually assessed (Dimension 5 table)
- [x] Upgrade roadmap with sequence, effort, risk
- [x] Issues classified by severity with counts
- [x] ZERO dependency changes made — read-only audit

---

## Two-line summary (for orchestrator)

1. **Score: 71/100** — "Acceptable; prioritized remediation within 2 sprints" per orchestrator rubric.
2. **Top critical finding:** `sqlcipher_flutter_libs 0.6.8` with upstream marker `0.7.0+eol` on the encrypted-database substrate — investigate the EOL semantics before doing anything else; if the library itself is EOL, this becomes a migration project, not a backlog ticket.
