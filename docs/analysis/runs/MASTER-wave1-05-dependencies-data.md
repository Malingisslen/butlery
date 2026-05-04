# MASTER-Wave1-05 — Dependencies & Supply Chain — Three-Run Consensus Data

**Purpose:** Consensus matrix across three forensic runs of prompt 05.
**Date:** 2026-05-02
**Authoritative baseline:** `2026-05-claude-deep` (Pass 1 + Pass 2 critic; live pub.dev fetches; sister-run cross-checked).
**Sources:**
- Run A (Codex / GPT-5):    `docs/analysis/runs/2026-05-codex/05-dependencies.md` (262 lines)
- Run B (Claude default):   `docs/analysis/runs/2026-05-claude/05-dependencies.md` (435 lines)
- Run C (Claude deep+critic): `docs/analysis/runs/2026-05-claude-deep/05-dependencies.md` (757 lines)

Run C is **authoritative** where runs disagree. Run C performed live pub.dev fetches for `sqlcipher_flutter_libs`, `http_certificate_pinning`, `freerasp`, `flutter_onnxruntime`, `algoliasearch`, AND a Pass-2 critic re-verified Pass-1 against live source. Where Run A or Run B has a finding unique to that run, this document marks it VERIFIED / DISPROVED / UNVERIFIABLE against the codebase.

---

## Score consensus

| Run | Score | Status label |
|---|---|---|
| A — Codex | **69 / 100** | "Needs Attention" |
| B — Claude default | **71 / 100** | "Acceptable; remediation in 2 sprints" |
| C — Claude deep (Pass 2) | **62 / 100** | "Acceptable; remediation in 2 sprints" |
| C — Pass 2 critic adjusted | 65 / 100 (sensitivity range ±3) | Same |

**Spread: 7 points (62-69).** Run C is lowest because it (a) escalated ONNX model integrity to HIGH (others deferred to prompt 07 or didn't surface it), (b) added CI Node 20-vs-22 mismatch as CRITICAL (uniquely surfaced by C), (c) verified sqlcipher EOL definitively (others said "investigate"). **For master-doc purposes: 62/100** — Run C is the most accurate because it verified more facts.

### Per-dimension comparison

| Dimension | A (Codex) | B (default) | C (deep, Pass 2) | Notes |
|---|---|---|---|---|
| 1. Vulnerability Scanning & CVEs | 17/25 | 18/25 | 15/25 | C deducts more for Node-version + ONNX-integrity. Critic recovers +1 (Trivy/TruffleHog) |
| 2. Version Currency & Maintenance | 13/20 | 13/20 | 11/20 | C verified sqlcipher EOL is confirmed (not "marker") + 12-deep Firebase lag |
| 3. License Compliance | 10/18 | 17/18 | 17/18 | A heavily under-scored — A captured zero license metadata; B and C agree no GPL/AGPL in tree |
| 4. Dependency Bloat | 13/15 | 12/15 | 12/15 | C corrected B's "excel/csv/archive bloat" claim — feature ships via deferred route |
| 5. Supply Chain Integrity | 9/12 | 10/12 | 5/12 (critic: 4/12) | Largest spread. C verified ONNX-model integrity gap (HIGH-7), action-tag mutability, etc. |
| 6. Platform Compatibility | 4/5 | 4/5 | 3/5 | All converge on BUT-750 pin posture being a future-iOS gate |
| 7. Upgrade Path & Migration | 3/5 | 3/5 | 1/5 (critic: 1.5/5) | C harshest — calls out cascade complexity (sqlcipher→drift→build_runner→SDK floor) |

---

## CRITICAL findings (consensus matrix + verification)

| # | Finding | Run A | Run B | Run C | Verification | Master severity |
|---|---|---|---|---|---|---|
| C1 | `sqlcipher_flutter_libs 0.7.0+eol` is **confirmed EOL** by upstream maintainer | HIGH (counted as "EOL signal", not CRIT) | HIGH ("possibly CRITICAL pending investigation") | **CRITICAL** (live pub.dev verified: "Not used anymore"; migrate to `sqlite3 ^3.x`) | **VERIFIED** — `pubspec.yaml:44` `sqlcipher_flutter_libs: ^0.6.4` (resolved 0.6.8 per `pub-deps.txt:60`); single import at `lib/core/storage/drift/app_database.dart`; pub.dev page (Run C live fetch) confirms 0.7.0+eol release exists solely as migration breadcrumb | **CRITICAL** |
| C2 | CI Node-version mismatch: `dep-audit.yml:89` pins `"20"` while `functions/package.json:55-57` declares `engines.node: "22"` — npm-audit auditing wrong package graph | NOT FOUND | NOT FOUND | **CRITICAL** | **VERIFIED LIVE** — `functions/package.json:55-57` literal `"engines": { "node": "22" }`; `.github/workflows/dep-audit.yml:89` literal `node-version: "20"`; `.github/workflows/firestore-rules.yml:52` correctly uses `"22"` (asymmetry confirms unintentional drift) | **CRITICAL** (5-min fix; configuration error not tradeoff) |
| C3 | `dart pub outdated --mode=null-safety` is a dead-flag invocation in `dep-audit.yml:45` | NOT FOUND | Mentioned in passing as "stale flag usage" (LOW context) | Pass 1: CRITICAL (hygiene) → **Pass 2 critic: HIGH → MEDIUM** | **VERIFIED** — `.github/workflows/dep-audit.yml:45` literal `dart pub outdated --mode=null-safety --json \|\| true`. `--mode=null-safety` was meaningful for the Dart 2.12 nullable migration (~2021), now no-op | **MEDIUM** (per Pass 2 disposition; downgraded — `\|\| true` swallows; OSV step does the real work) |
| C4 | `.github/dep-audit-allowlist.md` documents allowlist mechanism `dep-audit.yml` does not read | NOT FOUND | NOT FOUND | Pass 1: CRITICAL → **Pass 2 critic: MEDIUM** | **VERIFIED** — file exists at `.github/dep-audit-allowlist.md`; lines 3-5 self-document "The dep-audit.yml workflow does **not** currently read this file"; `dep-audit.yml` end-to-end review shows no reference | **MEDIUM** (Run C downgrade is correct: empty allowlist + self-flagging unwired status = future anti-pattern risk, not current landmine) |

**Consensus on CRITICAL:** Only 1 finding (C1) is shared 3-way as a high-impact item, and only Run C correctly classified it as CRITICAL after live pub.dev verification. C2/C3/C4 are unique to Run C and all VERIFIED against live source. Runs A and B both reported "0 CRITICAL" or "1 CRITICAL" but missed the runtime supply-chain configuration class entirely.

---

## HIGH findings (consensus matrix + verification)

| # | Finding | A | B | C | Verification | Master severity |
|---|---|---|---|---|---|---|
| H1 | `build_resolvers` + `build_runner_core` marked DISCONTINUED upstream (transitive via `build_runner 2.7.1`, 8 minors behind 2.15.0) | HIGH | HIGH | HIGH | **VERIFIED 3-way** — `pub-outdated.txt:198-199, 217-218`; `pubspec.yaml:113` "Downgraded for drift_dev compatibility" | HIGH |
| H2 | Firebase suite uniformly **one minor behind** (12 packages: firebase_core/auth/app_check/crashlytics/messaging/remote_config/storage/analytics/database/performance + cloud_firestore + cloud_functions) | NOT EXPLICITLY (folded into "44 packages locked older") | HIGH (aggregate); MEDIUM (each) | HIGH | **VERIFIED 3-way** — `pub-outdated.txt:98-113` confirms 12 packages, all one minor behind. `dependabot.yml:25-31` groups them under `firebase` weekly | HIGH |
| H3 | Certificate pinning **not active** for configured high-value hosts because fingerprint lists are TODO/empty | HIGH (unique to A) | NOT FOUND as HIGH (different framing — listed `http_certificate_pinning` publisher concern instead) | NOT FOUND as HIGH | **VERIFIED unique to A** — `lib/services/security/cert_pin_config.dart:34-71` (empty pin lists, falls through to platform trust store); `lib/services/security/pinned_http_client.dart:87-93` confirms pass-through. Real and shippable. | HIGH (this is a real hardening gap — Run A caught it; B/C missed it) |
| H4 | Mistral→Vertex AI documentation drift — code uses `@google-cloud/vertexai 1.12.0` but `functions/src/index.ts:10, 24` still says "Mistral AI" | NOT FOUND | NOT FOUND | HIGH (Run C original) | **VERIFIED** — `functions/package.json:60` `"@google-cloud/vertexai": "1.12.0"`; `functions/src/index.ts:10, 24` literal "Mistral AI"; `functions/src/llm/gemini-client.ts:22` imports from `@google-cloud/vertexai`; `functions/src/llm/PROMPT_CHANGELOG.md:58` historical Mistral reference | HIGH (cross-prompt with 12 doc drift) |
| H5 | `dep-audit.yml` does not run on `push: branches: [main]` — only PR + schedule + dispatch — solo-dev push-to-main bypasses audit until next Monday | NOT FOUND | LOW ("could add ... push-to-main trigger") | HIGH (Pass 1) → **Pass 2 critic: MEDIUM** (Trivy in build-validation.yml partially mitigates) | **VERIFIED** — `dep-audit.yml:7-17` literal triggers: `pull_request` (path-filtered to lockfiles), `schedule` (Mon 05:00 UTC), `workflow_dispatch`. No push trigger. Critic correctly notes `build-validation.yml:69-75` runs Trivy on every push, which catches dep CVEs via different scanner | HIGH (Run C original) / MEDIUM (Run C critic adjusted) — keep HIGH because Trivy and OSV scan different things |
| H6 | Caret-loose pin posture (72/74 carets, 2 exact) on solo-dev push-to-main amplifies surprise-bump risk on security-critical packages | NOT FOUND | NOT FOUND | HIGH (Run C, narrow exact-pin recommendation: `firebase_app_check`, `freerasp`, `http_certificate_pinning`) | **VERIFIED** — `pubspec.yaml` end-to-end: 74 deps, 72 caret, 2 exact pins (`device_info_plus 12.3.0` at `:34`, `connectivity_plus 7.0.0` at `:52` — both BUT-750-justified) | HIGH (Run C original) |
| H7 | **NEW Pass 2 finding:** Runtime-downloaded ONNX inference models (`models/ingredient_ner/v{N}/model.onnx`, max 25MB) have **no SHA-256 / integrity verification**. Same gap in `line_classifier_model_manager.dart` | NOT FOUND | NOT FOUND | HIGH (Pass 2 promoted from "deferred to prompt 07") | **VERIFIED** — `lib/services/parsing/ner/ner_model_manager.dart:24-30, 55-100`; `lib/services/parsing/ner/onnx_ner_service.dart:55-78`; Pass-2 grep `sha256\|integrity\|verifyHash\|checksum` across both manager files returns 0 matches. Models live at Firebase Storage `models/ingredient_ner/v{N}/model.onnx` (`assets/data/` confirmed not bundled) | HIGH (defense in depth — runtime-downloaded artifact influences user-content parsing decisions) |
| H8 | **NEW Pass 2 critic finding:** All 37 GitHub Actions invocations use mutable major-tag refs (`@v4`, `@v6`, `@v0.36.0`), zero SHA pinning. tj-actions/changed-files March 2025 attack vector | NOT FOUND | NOT FOUND | HIGH (Pass 2 critic only) | **VERIFIED** — Critic enumeration of 37 `uses:` refs across `.github/workflows/*.yml` shows all major-tag refs, no SHA pins. `actions/checkout@v4` AND `@v6` inconsistency between workflows confirms mutability is real | HIGH (Run C critic original) — third-party `subosito/flutter-action`, `aquasecurity/trivy-action`, `codecov/codecov-action`, `trufflesecurity/trufflehog` carry largest blast radius |
| H9 | `node-forge 1.4.0` (transitive in firebase-admin) is dual-licensed `(BSD-3-Clause OR GPL-2.0)`; election undocumented; no LICENSE/NOTICE file at repo root | NOT FOUND (A scored license dimension low generally but didn't name this) | NOT FOUND | HIGH (Run C original; Pass-2 disposition: HIGH for audit-trail gap, LOW for actual compliance) | **VERIFIED** — `functions/package-lock.json` contains node-forge with `(BSD-3-Clause OR GPL-2.0)` SPDX expression; `ls C:/Butlery/butlery/{LICENSE*,NOTICE*}` returns "No such file or directory" (re-verified by master) | HIGH (Run C original) — election unambiguous (BSD-3 standard for commercial), but audit trail missing |

**Severity-disputed within Run C:** C3 (downgraded from CRITICAL→HIGH→MEDIUM by Pass 2 critic) and C4 (CRITICAL→MEDIUM by Pass 2 critic). Both downgrades are **endorsed** by master because the underlying findings are hygiene/process risks not active landmines.

---

## MEDIUM/LOW findings (compact)

### MEDIUM — three-way consensus
- **44 packages locked older than upgradable** (mostly minor-version Firebase lag — already covered as H2 in aggregate). Pub-outdated.txt:209-210.
- **2 direct deps constraint-blocked:** `connectivity_plus 7.0.0` exact, `device_info_plus 12.3.0` exact — both BUT-750-pinned; pubspec.yaml:34, 52 with inline justification. **Good hygiene, not a problem.**
- **Major-version lag (8 packages):** `csv 6→8`, `archive 3→4`, `flutter_local_notifications 20→21`, `share_plus 12→13`, `package_info_plus 9→10`, `app_links 6→7`, `image 4.3→4.8`, `wakelock_plus 1.4→1.6`. `csv` and `flutter_local_notifications` justified by Dart 3.10+ floor. Three (`share_plus`, `package_info_plus`, `app_links`) **have no inline hold reason** — Run B and C flagged.
- **Drift toolchain coupling:** drift 2.29 ↔ drift_dev 2.29 ↔ build_runner 2.7.1 — single SDK-floor bump unblocks the cascade. Run A, B, C all flagged.
- **Dependabot ignores all semver-major bumps globally** (`.github/dependabot.yml:41-44, 85-88, 109-112`). Justified for solo dev (BUT-562 `:6-7`) but means major bumps need manual handling. Run A flagged; Run C noted unticketed major-bump candidates.

### MEDIUM — two-of-three
- **`http_certificate_pinning` publisher concern** — Run B flagged as MEDIUM ("unverified single-maintainer"). Run C **corrected this:** Pass 1 live pub.dev fetch shows `softarch.dev` IS a verified publisher. Run B's "unverified" claim is **DISPROVED**.
- **Bloat candidates:** Run B flagged `excel`, `csv`, `archive`, `sembast` as MEDIUM possible-bloat. Run C **DISPROVED** the excel/csv/archive part (deferred-route shipped feature). Sembast still informational.

### MEDIUM — unique to Run C
- `dio 5.9.2` advisory feed broken at capture (pub-outdated.txt:1-88) — visibility gap, not a vuln. Pass-2 critic disposition: "appears current per available data; CI advisory check would confirm" — verification certainty downgraded.
- `dep-audit.yml` does not run `dart pub audit` (second-source CVE check) — LOW-gap.
- No license-scanning step (`osv-scanner --experimental-licenses` or `licensee`) in CI — license drift is unmonitored.
- `intl 0.20.2` major-bump cliff awareness (locale data drift can be silent UX regression — defer to prompt 06).
- Lockfile-churn pattern: 65 commits total on `pubspec.lock`, year buckets 2024=36, 2025=0, 2026=29 (LOW-3, anomalous gap).
- Single-maintainer concentration risk: simolus3 maintains drift, drift_dev, sqlcipher_flutter_libs, sqlite3 — entire encrypted-DB substrate (Missing-6).

### LOW — three-way
- `wakelock_plus 1.4→1.6` minor lag (no inline reason).
- `very_good_analysis 10.0→10.2`.
- Various 1-patch-behind transitive packages (~30 in count).

### LOW — unique to Run C
- `pointycastle 4.0.0` is in resolved tree (transitive via `dart_jsonwebtoken`) but **zero direct imports in lib/** (Pass-2 grep verified). Pre-known-facts list at `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92` should be corrected (defer to prompt 12).
- `meta 1.16.0 → 1.18.2`, `cli_util 0.4.2 → 0.5.0` dev-side lag.
- `lefthook.yml:21` secret-scan regex doesn't include Firebase Admin SDK service-account JSON beyond `"type": "service_account"` (defer to prompt 02).
- `excel/csv/archive` chain SHIPS via deferred route (corrected from Pass-1 framing).

---

## Disproved by deep critic

These findings were claimed by Run A or Run B but Run C's Pass 2 critic verified against live source and **disproved**:

| Claim | Origin run | Disposition | Evidence |
|---|---|---|---|
| **`excel`, `csv`, `archive` are likely dead-weight** ("MEDIUM" bloat in Run B) | B (Dimension 4 finding) | **DISPROVED.** File-import feature SHIPS as a deferred-loaded production route. | `lib/core/router/modules/extraction_deferred_module.dart:9` (`deferred as file_import`), `:31` (`Routes.fileImport` registered in `handledRoutes`). Run C downgraded to LOW-6 informational. |
| **`http_certificate_pinning` is from an unverified single-maintainer publisher** ("MEDIUM" supply-chain risk in Run B) | B (Dimension 5 supply-chain finding) | **DISPROVED.** pub.dev live fetch (Run C Pass 1) confirms `softarch.dev` IS a verified publisher; package is Apache-2.0; last release 13 months ago. | Run C live pub.dev fetch table at line 376. |
| **`flutter_onnxruntime` publisher status uncertain** ("Need to confirm") | B (Dimension 5) | **DISPROVED.** pub.dev live fetch confirms `masic.ai` is verified publisher; MIT licensed; 1.7.0 released 21 days ago at capture. | Run C live pub.dev fetch table at line 377. (But ONNX model-integrity gap remains as HIGH-7 — separate concern.) |
| **`freerasp` "mixed/proprietary" license** ("LOW" in Run B; same framing in Run A) | A and B | **PARTIALLY DISPROVED.** pub.dev live fetch confirms verified publisher (talsec.app); SDK is MIT for the open-source part; Talsec ships freemium fair-use policy on top. For commercial use the free tier covers Butlery. | Run C live pub.dev fetch + line 379 verdict. Re-eval at scale milestones recommended. |
| **`pointycastle` is on the security-critical runtime cryptography path** (carried forward as pre-known-fact) | Pre-known-facts list | **DISPROVED.** Pass-2 grep `package:pointycastle/` in `lib/` returns 0 files. Only used transitively by `dart_jsonwebtoken` (a dev dep used in `firebase_auth_mocks`). Butlery uses `crypto` for SHA hashing and platform-native crypto everywhere else. | Run C Missing-9 + master grep re-verification. Pre-known-facts at `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92` is wrong; correct via prompt 12. |
| **Dependency Bloat: `sembast`/`sembast_web` likely a stub** ("LOW" in Run B) | B (Dimension 4) | **NEITHER VERIFIED NOR DISPROVED.** Run C left as "informational, audit candidate." Single import at `lib/core/cache/cache_dao_stub.dart:1`. Master treats as **UNVERIFIED**. |
| **`http_certificate_pinning` migration recommendation** ("MEDIUM"; "single-maintainer unverified — migrate to dio interceptors") | B (Dimension 5) | **CONTEXT-CORRECTED.** Run B's recommendation rested on the disproved publisher claim. The remaining gap (empty pin lists at `lib/services/security/cert_pin_config.dart:34-71`, Run A's HIGH H3) is the actual issue. Don't migrate the library; fill the fingerprints. |

---

## Unique to one run (verified)

### Unique to Run A (Codex), VERIFIED
- **Certificate pinning fingerprint lists are empty** — `lib/services/security/cert_pin_config.dart:34-71`, `lib/services/security/pinned_http_client.dart:87-93`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:79-82`. Falls through to platform trust store. **VERIFIED real and shippable.** This is master HIGH-3.
- **Vulnerability evidence gap** — Pre-analysis bundle missing saved `osv-scanner.txt` + `flutter pub audit` output; `pub-outdated.txt:1-88` shows advisory-decode FormatException for archive/dio/http/shared_preferences_android. Run B also noted this; Run C noted it. **VERIFIED 3-way actually**, but Run A scored highest deduction for it.
- **`flutter pub test` infrastructure timeout** — `flutter-test.txt:31508-31518` documents 10-min timeout in `test/views/helpers/infrastructure_integration_test.dart` blocks full-suite run. **UNVERIFIABLE here** — defer to prompt 04 (testing).

### Unique to Run B (default), VERIFIED
- **`protobufjs ^7.5.5` override** in `functions/package.json:71-73` — defensive override against CVE-2023-36665 prototype-pollution chain. **VERIFIED.** Master notes Run C critic recommends adding inline comment with CVE rationale (Pass 2 critic Missing-17).
- **`firebase_app_check` activated at app startup** — `lib/main.dart:117, 213-223`. **VERIFIED indirectly via codebase context** (not load-bearing for any severity finding).
- **Pubspec inline pin-justification comments are excellent** — pubspec.yaml:33, 34, 43, 52, 60, 81, 87, 113. **VERIFIED.** Run B recommended consolidating into `docs/dependency-constraints.md`. Master agrees.
- **`flutter_local_notifications` linux/windows sub-plugins are 1 major behind** — bound to held-back parent. **VERIFIED.**

### Unique to Run B (default), DISPROVED
- See Disproved by deep critic table above (excel/archive/csv bloat; http_certificate_pinning unverified publisher; flutter_onnxruntime publisher uncertain).

### Unique to Run C (deep + critic), VERIFIED
- **CRITICAL-2** (Node 20-vs-22 mismatch) — VERIFIED.
- **HIGH-4** (Mistral→Vertex doc drift) — VERIFIED.
- **HIGH-7** (ONNX model integrity gap) — VERIFIED.
- **HIGH-8** (Action-tag mutability) — VERIFIED via Pass-2 critic enumeration.
- **HIGH-9** (node-forge dual license + missing LICENSE/NOTICE) — VERIFIED via `ls` re-check.
- **C1 critic** (`functions/.npmrc:1-5` already has `ignore-scripts=true, save-exact=true, package-lock=true`) — VERIFIED. Strongest piece of supply-chain hygiene in the entire dep stack; uncited in Runs A and B.
- **C2 critic** (Trivy + TruffleHog in `build-validation.yml:69-75, 87-90` provide additional supply-chain coverage uncited elsewhere) — VERIFIED.
- **C4 critic** (Zero `id-token: write` / OIDC across all workflows; only 2 `permissions:` blocks) — VERIFIED.
- **C5 critic** (Empty `dependency_overrides` in pubspec.yaml; no `pubspec_overrides.yaml` anywhere) — VERIFIED via master read.
- **C6 critic** (Cloud Functions deps are tightly scoped; 4 prod deps all exact-pinned at `functions/package.json:59-64`) — VERIFIED via master read.
- **No `LICENSE`, `NOTICE`, `LICENSES.md`, `SECURITY.md` files exist at repo root** — VERIFIED via `ls` (master).

---

## Disputed severity classifications

| Finding | Run A | Run B | Run C Pass 1 | Run C Pass 2 critic | Master verdict |
|---|---|---|---|---|---|
| sqlcipher_flutter_libs EOL | HIGH | HIGH (potentially CRITICAL) | CRITICAL | CRITICAL | **CRITICAL** (per Pass 2 live pub.dev verification) |
| `--mode=null-safety` dead flag | NOT FOUND | LOW (passing mention) | CRITICAL (Pass 1) | **HIGH → MEDIUM** (downgrade) | **MEDIUM** (per Pass 2 disposition; OSV does the real work) |
| Allowlist file unwired | NOT FOUND | NOT FOUND | CRITICAL (Pass 1) | **MEDIUM** (downgrade — empty + self-flagging) | **MEDIUM** (per Pass 2) |
| Cert pinning fingerprints empty | HIGH | NOT AS HIGH (different framing) | NOT MENTIONED | NOT MENTIONED | **HIGH** (Run A original; missed by B and C) |
| Firebase 12-deep minor lag | (counted as 44 outdated) | HIGH (aggregate) | HIGH | HIGH | **HIGH** (3-way) |
| build_runner discontinued chain | HIGH | HIGH | HIGH | HIGH | **HIGH** (3-way) |
| ONNX model integrity | NOT FOUND | NOT FOUND | Deferred to prompt 07 (Pass 1) | **HIGH-7** (Pass 2 promotion) | **HIGH** (per Pass 2) |
| Push-trigger gap on dep-audit | NOT FOUND | LOW | HIGH (Pass 1) | MEDIUM (critic — Trivy partial mitigation) | **HIGH** (Trivy and OSV scan different targets; gap real) |
| node-forge dual-license | NOT FOUND | NOT FOUND | HIGH | HIGH (audit-trail) / LOW (compliance) | **HIGH** for audit-trail; LOW for compliance |
| Action-tag mutability | NOT FOUND | NOT FOUND | NOT IN PASS 1 | HIGH (critic NEW-C3) | **HIGH** (industry best practice; tj-actions Mar 2025 incident) |

---

## Live pub.dev-verified facts (Run C only)

These are the **authoritative-grade** facts in this analysis because Run C performed live pub.dev fetches. Runs A and B did not.

| Fact | Verdict | Source |
|---|---|---|
| `sqlcipher_flutter_libs` is END-OF-LIFE | **CONFIRMED** — pub.dev page (Run C live fetch) shows latest `0.7.0+eol` is "Not used anymore"; directs users to migrate to `package:sqlite3` v3.x. The 0.7.0 release exists solely as a migration breadcrumb. | Run C, Pass 1, lines 84-87 |
| `http_certificate_pinning` publisher status | **VERIFIED publisher (`softarch.dev`)** — Run B's "unverified single-maintainer" claim is wrong. Apache-2.0. Last release 13 months ago. | Run C, line 376 |
| `freerasp` license + publisher | **VERIFIED publisher (talsec.app); MIT for SDK + freemium fair-use policy** — Talsec freemium tier covers Butlery commercial use. Re-evaluate at scale milestones. | Run C, line 379 |
| `flutter_onnxruntime` publisher | **VERIFIED publisher (masic.ai); MIT licensed; 1.7.0 released 21 days before capture.** Run B's "Need to confirm" is resolved. | Run C, line 377 |
| `algoliasearch` publisher | **VERIFIED (algolia.com); 1.49.0 released 3 days before capture.** | Run C, line 378 |
| `drift` maintainer concentration | **VERIFIED — same human (simolus3) maintains `drift`, `drift_dev`, `sqlcipher_flutter_libs`, `sqlite3`.** Concentration risk for the encrypted-DB substrate. Sponsored by Google but a single point of failure. | Run C, line 380, Missing-6 |
| `flutter_inappwebview` publisher | **VERIFIED (inappwebview.dev); single maintainer (pichillilorenzo).** Concentration risk; large native attack surface. | Run C, line 381 |

---

## Master severity rollup

**CRITICAL (2):**
1. `sqlcipher_flutter_libs` EOL (substrate replacement project, 0.5d invest + 2-3d migration; gated on `sqlite3 ^3.x` + drift 2.32 + SDK floor bump cascade).
2. CI Node-version mismatch in `dep-audit.yml:89` (5-min fix; `npm-audit` auditing wrong package graph).

**HIGH (8):**
1. (H1) `build_resolvers` + `build_runner_core` discontinued (transitive via `build_runner 2.7.1`, gated on drift_dev).
2. (H2) Firebase suite 12-deep minor lag.
3. (H3) Certificate pinning fingerprint lists empty (Run A unique).
4. (H4) Mistral→Vertex AI documentation drift.
5. (H5) `dep-audit.yml` no `push: branches: [main]` trigger.
6. (H6) Caret-loose pin posture (72/74) — recommend exact-pinning 3 most security-critical (`firebase_app_check`, `freerasp`, `http_certificate_pinning`).
7. (H7) Runtime ONNX model downloads have no integrity verification (`ner_model_manager.dart`, `line_classifier_model_manager.dart`).
8. (H8) All 37 GitHub Actions invocations use mutable major-tag refs (no SHA pinning).
9. (H9) `node-forge (BSD-3-Clause OR GPL-2.0)` dual-license election undocumented; no LICENSE/NOTICE/SECURITY files at repo root.

(That's 9 HIGH; H8 was net-add-after-cancel via critic adjustments — keep as 9-count for master.)

**MEDIUM (10+):**
- 44 packages locked older than upgradable (most are H2 minor-lag).
- 8 packages with major-version lag (3 unticketed: `share_plus`, `package_info_plus`, `app_links`).
- `--mode=null-safety` dead flag (downgraded).
- Allowlist file unwired (downgraded; recommend delete).
- License-scanning unmonitored in CI.
- `dart pub audit` second-source check missing.
- Yanked-package detection unenforced (Critic NEW C9).
- Drift toolchain SDK-floor coupling.
- Dependabot major-bump global ignore (justified but means manual handling needed).
- BUT-750 pin posture (informational; pins are correct, but track to upstream resolution).

**LOW (10+):**
- Per-package patch lag (~30 transitives).
- Cleanup items (excel/csv/archive single-import sites informational; pointycastle pre-known-facts correction; sembast audit candidate).
- `wakelock_plus`, `intl`, `meta`, `cli_util` minor lags.
- LOW positive findings (`functions/.npmrc` hygiene; empty `dependency_overrides`; tightly scoped Functions deps; Trivy + TruffleHog uncited coverage).

**Aggregate issue count: ~32 issues across all runs after dedup.**
**Aggregate remediation effort: 13-19 days** (Run B) to **~20 days** (Run C with critic additions).

---

## Methodology notes for master doc consumers

1. **Run C is authoritative** because it (a) performed live pub.dev fetches, (b) ran a Pass-2 critic that re-verified Pass-1 against live source, (c) cross-checked sister run Run B and corrected B's errors.
2. **Run A is most conservative** on severity (4 HIGH only) and missed the entire CI configuration class of findings (Node mismatch, allowlist, push trigger).
3. **Run B has the most polished narrative** but several factual errors (publisher claims, bloat-candidate framing) — corrected by Run C.
4. **Run A uniquely caught the empty-pinning-fingerprints HIGH** — others missed it. Master keeps as HIGH H3.
5. **Run C uniquely caught:** Node-version CI mismatch, Mistral doc drift, ONNX integrity gap, action-tag mutability, node-forge dual-license + no-LICENSE-file, `.npmrc` hygiene praise, Trivy/TruffleHog coverage, OIDC absence, lockfile-churn anomaly, `pointycastle` pre-known-fact correction.
6. **Three-way consensus** on: sqlcipher EOL (severity disputed → CRITICAL per Run C live verification), build_runner discontinued chain, Firebase 12-deep lag, drift toolchain coupling, Dependabot major-ignore.

---

## Reference index

All file:line references in this master document, deduplicated across runs:

- `pubspec.yaml`: 4, 19, 22-33, 34 (exact pin), 35, 38, 39, 42, 43 (drift hold), 44 (sqlcipher_flutter_libs), 48, 51, 52 (exact pin), 55, 60 (image-archive cascade pin), 67, 76, 79, 80, 81 (csv hold), 83 (flutter_onnxruntime), 87 (app_links migration), 88, 91, 93 (sqlite3), 96, 97, 113 (build_runner hold), 128. (~30 distinct lines)
- `pubspec.lock`: top-level integrity, package count = 281.
- `functions/package.json`: 55-57 (engines:22), 59-64 (4 prod deps), 60 (vertexai), 65-69 (4 dev deps), 71-73 (protobufjs override).
- `functions/.npmrc`: 1-5 (ignore-scripts, save-exact, package-lock, fund=false, update-notifier=false).
- `functions/src/index.ts`: 10, 24 (Mistral comments).
- `functions/src/llm/gemini-client.ts`: 17-22, 22 (vertexai imports).
- `functions/src/llm/ocr-recipe-image.ts`: 18, 394.
- `functions/src/llm/PROMPT_CHANGELOG.md`: 58.
- `.github/workflows/dep-audit.yml`: 7-17 (triggers — no push), 19, 38 (Flutter version), 45 (dead flag), 50-58 (OSV), 69-73 (failure assertion), 89 (Node 20 — CRITICAL-2), 97.
- `.github/workflows/firestore-rules.yml`: 52 (Node 22 — correct).
- `.github/workflows/e2e_tests.yml`: 68 (Node 20 — also stale).
- `.github/workflows/build-validation.yml`: 69-75 (Trivy fs scan), 87-90 (TruffleHog).
- `.github/dependabot.yml`: 6-7 (BUT-562 comment), 13-22 (pub block), 18 (PR limit 5), 25-31 (firebase group), 32-40 (flutter-deps group), 41-44 (major-ignore), 46-52 (BUT-750 ignore), 54-84 (npm block), 67-73 (firebase-admin group), 90-112 (github-actions block), 109-112 (major-ignore on actions).
- `.github/dep-audit-allowlist.md`: 3-5 (self-document unwired status), 14 (empty allowlist).
- `lefthook.yml`: 21 (secret-scan regex).
- `pub-outdated.txt`: 1-88 (advisory-decode FormatException), 89-218 (full outdated table), 92-124 (key direct deps), 122 (sqlcipher EOL marker), 127 (build_runner 2.7.1 vs 2.15.0), 130, 134, 137-140 (algolia client), 198-199 + 217-218 (build_resolvers/build_runner_core discontinued).
- `pub-deps.txt`: 6-66 (direct dep tree), 60 (sqlcipher_flutter_libs 0.6.8), 69 (build_runner), 75 (dart_jsonwebtoken), 90-298 (transitive), 129 (dio 5.9.2), 165-171 (flutter_inappwebview platforms), 197-203 (image_picker platforms), 238 (pointycastle 4.0.0).
- `lib/core/storage/drift/app_database.dart`: file-level + 9 (flutter_secure_storage import), 10-11, 121-124, 133-155, 166-172.
- `lib/core/router/modules/extraction_deferred_module.dart`: 9 (deferred as file_import), 31 (Routes.fileImport in handledRoutes).
- `lib/services/parsing/ner/ner_model_manager.dart`: 24-30, 55-100, 153-157.
- `lib/services/parsing/ner/onnx_ner_service.dart`: 55-78.
- `lib/services/parsing/line_classifier/line_classifier_model_manager.dart`: file-level (parallel structure).
- `lib/services/security/cert_pin_config.dart`: 12-14, 34-71 (empty pin lists).
- `lib/services/security/pinned_http_client.dart`: 25, 87-93 (pass-through on empty pins).
- `lib/repositories/algolia/algolia_pinning_interceptor.dart`: 5-8, 21-22, 30, 79-82.
- `lib/services/import/file_import_strategy.dart`: 3 (excel + csv + archive imports).
- `lib/main.dart`: 117 (firebase_app_check activation), 213-223.
- `lib/core/cache/cache_dao_stub.dart`: 1 (sembast import).
- `lib/services/device_integrity_service.dart`: 8 (freerasp).
- `lib/services/extraction/web_scraper.dart`: 5 (flutter_inappwebview).
- `lib/core/utils/crypto_utils.dart`: 2 (crypto package).
- `lib/services/ocr_extraction_service.dart`: 7 (crypto package).
- `lib/views/settings/account_security_view.dart`: 377-380 (showLicensePage).
- `assets/data/`: directory listing — no `.onnx` files bundled (confirms HIGH-7 runtime download path).
- `android/app/build.gradle.kts`: 19 (compileSdk 36), 38 (targetSdk 36).
- `ios/Podfile`: 1, 50 (iOS 17.0 deployment).

**Pub.dev live-fetch references (Run C only, authoritative):** `sqlcipher_flutter_libs`, `http_certificate_pinning`, `freerasp`, `flutter_onnxruntime`, `algoliasearch`.

---

## End of master consensus data
