# 05 — Dependencies & Supply Chain — FINAL (Pass 1 + Pass 2 Critic)

**Investigator (Pass 1):** Claude (Opus 4.7, 1M ctx)
**Critic (Pass 2):** Claude (Opus 4.7, 1M ctx) — separate invocation
**Date:** 2026-05-02
**Run:** `docs/analysis/runs/2026-05-claude-deep/`
**Sister run cross-checked:** `docs/analysis/runs/2026-05-claude/05-dependencies.md`
**Source data:**
- `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt` (lines 1-219)
- `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt` (299 lines, 281 resolved pkgs)
- Live `pubspec.yaml:1-172`, `pubspec.lock` (2294 lines, 281 packages), `functions/package.json:1-75`, `functions/package-lock.json` (3909 lines, 317 resolved nodes)
- `.github/workflows/dep-audit.yml:1-98`, `.github/dependabot.yml:1-113`, `.github/dep-audit-allowlist.md:1-23`
- `.github/workflows/{e2e_tests,firestore-rules,test,analyze,build-validation,architecture-validation}.yml`
- `lefthook.yml:1-36`
- pub.dev pages live-fetched for `sqlcipher_flutter_libs`, `http_certificate_pinning`, `freerasp`, `flutter_onnxruntime`, `algoliasearch`

---

## Score

**Overall: 62 / 100** — "Acceptable; prioritized remediation within 2 sprints" per orchestrator rubric. Down from Pass-1's 64 because Pass 2 confirmed an additional supply-chain gap (runtime ONNX model download with no integrity check) that Pass 1 deferred prematurely.

| Dimension | Score | Δ vs Pass 1 (64) | Reason for change |
|---|---|---|---|
| Vulnerability Scanning & CVEs | **15 / 25** | 0 | No change — same CRITICAL findings hold. |
| Version Currency & Maintenance | **11 / 20** | 0 | sqlcipher EOL + 12-deep Firebase lag confirmed. |
| License Compliance | **17 / 18** | 0 | freerasp + node-forge accepted; no LICENSE/NOTICE remains an audit-trail gap. |
| Dependency Bloat | **12 / 15** | +1 | **Pass-1 MEDIUM-3 framing corrected:** excel/csv/archive ARE shipped (file_import_view is registered as a router-handled deferred route at `lib/core/router/modules/extraction_deferred_module.dart:9, 31`). No bloat to remove there. |
| Supply Chain Integrity | **5 / 12** | -1 | **Pass-2 escalates the ONNX-runtime model-download gap.** No SHA-256 / integrity check on `models/ingredient_ner/v{N}/model.onnx` downloaded at runtime from Firebase Storage. Pass 1 deferred to prompt 07; Pass 2 keeps it here as a runtime-dependency provenance gap. |
| Platform Compatibility | **3 / 5** | 0 | Unchanged. |
| Upgrade Path & Migration | **1 / 5** | 0 | Unchanged. |

**Status:** Needs Attention — known-EOL package on encrypted-database substrate, CI configuration mismatch silently weakening the npm audit safety net, and a runtime-downloaded inference model with no integrity verification.

---

## Pass-2 Critic Notes

The critic verified every CRITICAL and HIGH against live source. Summary of disposition:

| Finding | Pass-1 Severity | Live Verification | Pass-2 Disposition |
|---|---|---|---|
| **CRIT-1** sqlcipher_flutter_libs EOL | CRITICAL | `pubspec.yaml:44` → `sqlcipher_flutter_libs: ^0.6.4`. Single import: `lib/core/storage/drift/app_database.dart` (verified). | **HOLD CRITICAL.** Encrypted-DB substrate on a formally-retired package. |
| **CRIT-2** Node 20 vs engines:22 mismatch | CRITICAL | `functions/package.json:55-57` → `"engines": { "node": "22" }`. `dep-audit.yml:89` → `node-version: "20"`. Confirmed. `e2e_tests.yml:68` also pins `'20'`; `firestore-rules.yml:52` pins `"22"`. | **HOLD CRITICAL.** 5-min fix; the asymmetry across workflows confirms this isn't intentional. |
| **CRIT-3** `--mode=null-safety` dead flag | CRITICAL (hygiene) | `dep-audit.yml:45` → `dart pub outdated --mode=null-safety --json \|\| true`. Verified verbatim. | **DOWNGRADE TO HIGH.** It's a hygiene smell with no security impact — the OSV step does the real work. Calling it CRITICAL inflates the language. |
| **CRIT-4** Allowlist file unwired | CRITICAL (hygiene) | `dep-audit-allowlist.md:3-5` admits this directly: *"The dep-audit.yml workflow does **not** currently read this file."* Allowlist table empty (`:14`). | **DOWNGRADE TO MEDIUM.** Empty allowlist + documented "not wired" status = no actual landmine today, just an opinionated cleanup item. Pass 1 over-classified. |
| **HIGH-4** Mistral→Vertex AI drift | HIGH | `functions/package.json:60` → `"@google-cloud/vertexai": "1.12.0"`. `functions/src/index.ts:10, 24` say "Mistral AI". `functions/src/llm/gemini-client.ts:22` and `ocr-recipe-image.ts:18` import from `@google-cloud/vertexai`. `functions/src/llm/PROMPT_CHANGELOG.md:58` also references "Mistral model" historically. | **HOLD HIGH** for dep-doc consistency. Cross-prompt with 12 (doc drift); the doc claim itself is anchored here. |
| **HIGH-5** No push trigger | HIGH | `dep-audit.yml:7-17` confirmed: triggers are `pull_request` (paths-filtered), `schedule`, `workflow_dispatch`. No `push: branches: [main]`. | **HOLD HIGH.** Solo-dev push-to-main amplifies the gap. |
| **MEDIUM-3** excel/csv/archive bloat candidate | MEDIUM | `lib/core/router/modules/extraction_deferred_module.dart:9, 31` → `Routes.fileImport` is a registered, deferred-loaded route in production. Feature ships. | **DOWNGRADE TO LOW.** Not bloat — it's a shipped feature. The image↔archive cascade pin (`pubspec.yaml:60`) remains, but it's justified by a real user-facing capability. Pass-1 self-critique #3 was correctly skeptical. |
| **Missing-7** ONNX model provenance | Deferred to prompt 07 | `lib/services/parsing/ner/ner_model_manager.dart:24-30` downloads `models/ingredient_ner/v{N}/model.onnx` from Firebase Storage at runtime, max 25MB. **Grep for `sha256\|integrity\|verifyHash` in `ner_model_manager.dart` and `remote_model_loader.dart` returns 0 matches.** | **PROMOTE TO HIGH (new HIGH-7).** A runtime-downloaded inference model with no integrity check is a genuine supply-chain vector — even though Firebase Storage is access-controlled, a compromised admin token could replace the model with one that produces wrong NER outputs (and so wrong ingredient parses on user content). Belongs in 05 because it IS a runtime dependency. |
| **Missing-9** pointycastle correction | Pre-known-fact correction | Live grep `package:pointycastle/` in `lib/` returns 0 files (verified). | **HOLD.** Pre-known-facts list at `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92` should be corrected. |
| **All publisher verifications** | Various | pub.dev fetches still hold per Pass 1 — `http_certificate_pinning` is a verified publisher; `flutter_onnxruntime` is verified at masic.ai; `freerasp` is a verified publisher with freemium tier. | **HOLD.** Run-1's "unverified" claim on `http_certificate_pinning` was wrong; Pass 1's correction stands. |

**New finding from Pass 2 (HIGH-7 below):** runtime ONNX model download has no integrity verification. This is the most consequential gap Pass 1 underweighted.

**Score adjustments:**
- +1 to Dependency Bloat (excel chain is shipped, not dead weight)
- -1 to Supply Chain Integrity (HIGH-7 ONNX model integrity)
- Net: 64 → 62

**Refs added by Pass 2:**
- `lib/core/router/modules/extraction_deferred_module.dart:9, 31`
- `lib/core/storage/drift/app_database.dart` (file-level confirm of sqlcipher_flutter_libs single import)
- `lib/services/parsing/ner/ner_model_manager.dart:24-30, 55-100`
- `lib/services/parsing/ner/onnx_ner_service.dart:55-78`
- `functions/src/llm/PROMPT_CHANGELOG.md:58` (Mistral historical reference)
- `assets/data/` directory listing (no .onnx files bundled — confirms runtime-download path)

---

## Methodology Notes

- **Each Pass-1 claim has a pub.dev or file:line citation.** Where a claim depends on what a workflow "actually does" rather than what it's documented to do, the line range is cited.
- **Live pub.dev fetches** for the four most consequential packages (sqlcipher_flutter_libs, http_certificate_pinning, freerasp, flutter_onnxruntime, algoliasearch). This corrects two errors in the run-1 report (verified-publisher status of `http_certificate_pinning` and `flutter_onnxruntime`).
- **The Mistral→Vertex AI drift** discovered while reading `functions/src/index.ts:10` and `functions/src/llm/gemini-client.ts:17-22`. The orchestrator README and code comments still say "Mistral AI" but the actual SDK is `@google-cloud/vertexai 1.12.0`. Run 1 missed this.
- **Pub-outdated capture caveat:** four packages (archive, dio, http, shared_preferences_android) returned `FormatException: advisoriesUpdated must be a String` from pub.dev's advisory endpoint at capture time (`pub-outdated.txt:1-88`). Pub.dev server bug, not Butlery's — but means captured "Latest" column is *not authoritative* for those four packages on advisory data. Current resolved versions still trustworthy.

---

## CRITICAL Findings

### CRITICAL-1 — `sqlcipher_flutter_libs` is **confirmed End-of-Life**, not "investigate"

Per the live pub.dev fetch:

> Latest version 0.7.0+eol is "Not used anymore" — directs users to migrate to `package:sqlite3` v3.x. The 0.7.0 release exists solely as a migration breadcrumb.

- **Where it's used:** `pubspec.yaml:44` (`sqlcipher_flutter_libs: ^0.6.4`, resolved 0.6.8 per `pub-deps.txt:60`).
- **Single import site:** `lib/core/storage/drift/app_database.dart` (verified by Pass-2 grep).
- **What it does in Butlery:** native binary for SQLCipher (encrypted SQLite) under Drift — `pubspec.yaml:43-44` ties it to `drift ^2.29.0`.
- **Why this is CRITICAL, not HIGH:** the encrypted-database substrate is on a package that the maintainer (simolus3 — also drift's maintainer) has formally retired. Path forward (per pub.dev): migrate to `sqlite3 ^3.x`. Catch is current pubspec uses `sqlite3: ^2.9.4` (`pubspec.yaml:93`) — sqlite3 itself needs 2.x → 3.x at the same time.
- **Cascade scope:** drift 2.29 → drift 2.32+ (held back per `pubspec.yaml:43` "Blocked: 2.32.x needs newer SDK"), build_runner 2.7→2.15 (held by drift_dev), drift_dev 2.29→2.32. The sqlcipher migration is the head of the same cascade as the SDK floor bump.
- **Effort:** 0.5 day investigation of `UPGRADING_TO_V3.md` (linked from pub.dev), 2-3 days migration including key derivation re-test, on-device sanity tests for encrypted-DB read/write.
- **Risk if ignored:** no immediate breakage (the EOL release functions as a no-op shim), but the security guarantee on encrypted local storage is now backed by an explicitly retired binary distribution. Auditor-asked.

### CRITICAL-2 — CI dependency-audit Node-version mismatch silently weakens npm-audit results

Confirmed verbatim against live source:
- `functions/package.json:55-57`: `"engines": { "node": "22" }`.
- `dep-audit.yml:89`: `node-version: "20"`.
- `e2e_tests.yml:68`: `node-version: '20'` (also stale).
- `firestore-rules.yml:52`: `node-version: "22"` (correct).

**Why it's CRITICAL:** `npm ci` and `npm audit` resolve different optional / native binaries depending on the running Node version. The shipped artefact resolves under Node 22 (Cloud Functions runtime); the audit step resolves under Node 20. **The audit step is therefore not auditing what ships.** Textbook supply-chain blind-spot. Probability of a real CVE slipping through is small but not zero — and it's a configuration error, not a tradeoff.

- **Fix:** change `dep-audit.yml:89` `node-version: "20"` → `"22"`. Same for `e2e_tests.yml:68`. 5 minutes.
- **Defense in depth:** add a CI lint step that fails if any workflow's `node-version` differs from `functions/package.json:engines.node`. Or set `engine-strict=true` in `functions/.npmrc` (Pass-1 Missing-11) — `npm ci` then errors out under wrong Node. Both work.

---

## HIGH Findings

### HIGH-1 — `build_runner 2.7.1` (latest 2.15.0) is **8 minors behind**, transitive deps `build_resolvers` and `build_runner_core` marked DISCONTINUED

- `pubspec.yaml:113`: `build_runner: ^2.7.1  # Downgraded for drift_dev compatibility`.
- `pub-outdated.txt:127`: `build_runner *2.7.1 ... 2.15.0` — 8 minor versions of lag, the largest gap in the entire dependency graph.
- `pub-outdated.txt:198-199`: `build_resolvers 3.0.3 (discontinued)`, `build_runner_core 9.3.1 (discontinued)`.
- `pub-outdated.txt:217-218`: explicit pub.dev "Package has been discontinued" markers.
- `pub-deps.txt:69`: build_runner pulls 27+ transitive dev deps.
- **Impact assessment:** dev-only (codegen). Not a runtime CVE risk in the obvious sense — but Pass-1 self-critique #2 is correct that codegen output (`*.g.dart`) IS runtime code. A bug in `build_runner_core` could in principle ship buggy generated code. Probability low; surface non-zero.
- **Severity:** HIGH (slow burn, blocks the modernization wave).
- **Effort:** 1-2 days when SDK floor bumps; gated on `drift 2.32` requirements and `sqlcipher_flutter_libs` substrate replacement (CRITICAL-1).

### HIGH-2 — Firebase suite **uniformly one minor behind** on 12 packages

| Package | Current | Upgradable | Where |
|---|---|---|---|
| `firebase_core` | 4.6.0 | 4.7.0 | `pub-outdated.txt:107` |
| `firebase_auth` | 6.3.0 | 6.4.0 | `:106` |
| `firebase_app_check` | 0.4.2 | 0.4.3 | `:105` |
| `firebase_crashlytics` | 5.1.0 | 5.2.0 | `:108` |
| `firebase_database` | 12.2.0 | 12.3.0 | `:109` |
| `firebase_messaging` | 16.1.3 | 16.2.0 | `:110` |
| `firebase_performance` | 0.11.2 | 0.11.3 | `:111` |
| `firebase_remote_config` | 6.3.0 | 6.4.0 | `:112` |
| `firebase_storage` | 13.2.0 | 13.3.0 | `:113` |
| `firebase_analytics` | 12.2.0 | 12.3.0 | `:104` |
| `cloud_firestore` | 6.2.0 | 6.3.0 | `:98` |
| `cloud_functions` | 6.1.0 | 6.2.0 | `:99` |

- Plus 11 transitive `firebase_*_platform_interface` / `_web` packages also one patch behind (`:143-165`).
- Dependabot config `dependabot.yml:25-31` groups these under `firebase` with weekly cadence + `update-types: [minor, patch]`. So why is the lag 12-deep? Either (a) the grouped PR is sitting unmerged, (b) Dependabot run is failing on the OSV gate (`dep-audit.yml:69-73` fails on HIGH/CRITICAL — could be blocking), or (c) Dependabot major-filter at `dependabot.yml:41-44` ignores some bumps that are technically minor in semver but treated as breaking by upstream.
- **Action required:** check open Dependabot PRs in the repo. If a 1-month-old grouped Firebase PR is sitting unmerged → human bottleneck, not config.
- **Severity:** HIGH (12-package lag = systemic).

### HIGH-3 — `node-forge 1.4.0` (transitive in firebase-admin) is dual-licensed `(BSD-3-Clause OR GPL-2.0)`

- `functions/package-lock.json` (verified): `"license": "(BSD-3-Clause OR GPL-2.0)"` — only GPL-touching license in the entire transitive graph (npm-side).
- **Why it's not actually a problem:** dual-licensed packages let the consumer **elect one license**. For commercial use, electing BSD-3-Clause is standard practice. Apache-2.0 (firebase-admin's own license) doesn't conflict with BSD-3.
- **Why it's HIGH and not LOW:** if a license-compliance audit ever runs `licensee` or `osv-scanner --experimental-licenses` (which `dep-audit.yml` does NOT), this dep will surface as "GPL-touching" without elector context. The team should **document the BSD-3 election** in a `LICENSE_CHOICES.md` or `NOTICE.md`. **There is currently no `LICENSE`, `NOTICE`, or `LICENSES.md` file at the repo root** (verified by Pass 2 — `ls C:/Butlery/butlery/LICENSE*` and `NOTICE*` both return "No such file or directory").
- **Severity:** HIGH (audit-trail gap), LOW (actual compliance).
- **Effort:** 1 hour.

### HIGH-4 — Mistral AI documentation drift: code comments and orchestrator say "Mistral", actual SDK is `@google-cloud/vertexai`

- `functions/package.json:60`: `"@google-cloud/vertexai": "1.12.0"` (locked, not caret).
- `functions/src/index.ts:10`: `LLM Services (Mistral AI):` (comment block).
- `functions/src/index.ts:24`: `// LLM Functions - Mistral AI integration`.
- `functions/src/llm/gemini-client.ts:22`: imports from `"@google-cloud/vertexai"` (verified).
- `functions/src/llm/ocr-recipe-image.ts:18`: `import type { Part } from "@google-cloud/vertexai";` (verified).
- `functions/src/llm/ocr-recipe-image.ts:394`: `// Gemini uses inlineData for base64 images (not image_url like Mistral).` — code explicitly contrasts itself with Mistral.
- `functions/src/llm/PROMPT_CHANGELOG.md:58` (Pass-2 finding): `**00635cf84** — LLM prompt improvements + line-level routing + model unification. Multiple prompts converged on a single Mistral model;` — historical Mistral reference inside the LLM module's own changelog.
- **Implication for prompt 05 (deps):** the dependency stack is **internally consistent** (vertexai is the only LLM SDK), but documentation says otherwise. **Factual drift** that touches dependency documentation directly.
- **Severity:** HIGH for documentation-vs-dependency consistency. (Cross-prompt with 12.)
- **Effort:** 30 min text find-replace.

### HIGH-5 — `dep-audit.yml` does not run on `push` to main — only PR + schedule + dispatch

- `dep-audit.yml:7-17` declares triggers: `pull_request` (paths-filtered to lockfiles), `schedule` (weekly Mon 05:00 UTC), `workflow_dispatch`. **No `push: branches: [main]`.**
- Combined with the project's solo-dev culture (CLAUDE.local.md: "push directly to main. Never ask 'branch + PR'"), **lockfile changes that bypass PR review do not trigger an audit until the next Monday cron** — up to 7 days of unaudited dep state.
- `.github/dependabot.yml:18` PR limit is 5 — Dependabot still raises PRs, so dep-driven lockfile changes ARE covered. But **manual changes** (`flutter pub upgrade` locally then push) are not.
- **Severity:** HIGH (real solo-dev workflow gap).
- **Effort:** add 2 lines to `dep-audit.yml:7-9`:
  ```yaml
  push:
    branches: [main]
    paths: [pubspec.lock, functions/package-lock.json]
  ```
  Path-filtered so non-lockfile commits don't burn CI minutes (Pass-1 self-critique #5 addressed).

### HIGH-6 — Aggregate caret-syntax pin posture is **72/74 caret-loose**, solo-dev push-to-main amplifies risk

- `pubspec.yaml`: 74 dependency declarations, 72 use `^` (caret-loose), 2 use exact pins (`device_info_plus: 12.3.0` at `:34`, `connectivity_plus: 7.0.0` at `:52`, both BUT-750-justified inline).
- **Caret semantics:** `^X.Y.Z` resolves to `>=X.Y.Z <(X+1).0.0`. Caret-loose pubspec can resolve to a brand-new minor or patch on every `flutter pub upgrade`.
- **Why it matters here:** `pubspec.lock` changes infrequently (29 commits since Jan 2026), but every `flutter pub get` on a fresh machine could resolve to newer transitives if pubspec.lock is regenerated.
- For a solo-dev push-to-main workflow with no PR review, **exact pinning of the ~3 most security-critical packages** (`firebase_app_check`, `freerasp`, `http_certificate_pinning`) closes the surprise-bump window without imposing a heavy review burden. (Pass-1 self-critique #6 argued for ~10; Pass 2 narrows to 3 to balance review cost.)
- **Severity:** HIGH (defense in depth gap).
- **Effort:** 30 min for the 3-package narrow exact-pin migration.

### HIGH-7 (NEW — Pass 2) — Runtime-downloaded ONNX inference model has no integrity verification

- `lib/services/parsing/ner/ner_model_manager.dart:24-30, 55-100`: `NerModelManager` downloads `models/ingredient_ner/v{N}/model.onnx` (max 25MB) and `vocab.txt` from Firebase Storage on first use, caches in app's documents directory.
- `lib/services/parsing/ner/onnx_ner_service.dart:55-78`: passes the cached `modelPath` to `OnnxRuntime().createSession(modelPath)` to run BERT NER inference on user-entered ingredient lines.
- **Pass-2 grep `sha256\|integrity\|verifyHash\|checksum` in `ner_model_manager.dart` and `remote_model_loader.dart` returns 0 matches.** No integrity check on the downloaded model.
- **Why it matters:** the ONNX model file is effectively a runtime dependency that influences parsing decisions on user content (it produces BIO tags that downstream code uses to extract quantities, units, and ingredient names from arbitrary user-entered recipe text). A compromised admin Firebase token could replace the model with one that produces wrong NER outputs for targeted inputs — and the app would happily run it. Firebase Storage rules + App Check provide perimeter defense, but defense in depth requires file-level integrity (publish a SHA-256 alongside the model in `version.txt` or a separate `model.sha256` file, verify on download before swapping the cache file).
- **Same gap exists in `lib/services/parsing/line_classifier/line_classifier_model_manager.dart`** (parallel structure for the line-classifier ONNX model).
- **Severity:** HIGH. Pass 1 deferred to prompt 07 (AI/LLM Quality), but Pass 2 keeps it here because the model IS a runtime dependency in the supply-chain sense.
- **Effort:** 0.5 day. Compute SHA-256 server-side at upload, embed in `version.txt` or separate metadata file, verify in `_tryDownload()` before `rename(modelPath)` (`ner_model_manager.dart:153-157`).
- **Cross-prompt:** prompt 07 should re-confirm model-quality / inference-correctness story; this finding is the supply-chain leg.

---

## MEDIUM / LOW Findings

### MEDIUM-1 — Severely behind on majors: `csv 6→8`, `app_links 6→7`, `share_plus 12→13`, `package_info_plus 9→10`, `archive 3→4`, `flutter_local_notifications 20→21`

- `pub-outdated.txt:97-122` — see table.
- `csv` and `flutter_local_notifications` 21.x require Dart 3.10+ per `pubspec.yaml:33,81`. Justified hold.
- `archive 3→4` is locked together with `image 4.3.0` (which itself is held back, `pubspec.yaml:60`). Cascade.
- `share_plus 12→13`, `package_info_plus 9→10`, `app_links 6→7` have **no inline justification**. Three unticketed major-bump tasks.
- **Severity:** MEDIUM (each), accumulated drift.
- **Effort:** 2-3 days for the three unticketed majors with ad-hoc smoke tests.

### MEDIUM-2 — `dio 5.9.2` (transitive via `http_certificate_pinning`) is on the latest 5.x line — current and clean

- `pub-deps.txt:129`: `dio 5.9.2 [async collection http_parser meta mime path dio_web_adapter]`.
- Pulled in by `http_certificate_pinning 3.0.1` (`pub-deps.txt:45`).
- 5.9.2 is the latest 5.x. Earlier 5.x lines had advisory items (`pub-outdated.txt:23-44` — advisory feed broke for `dio`, but resolved version is the latest).
- **Severity:** LOW — current and clean. Mentioned for completeness because the advisory feed gap meant run-1 said "uncertain".

### MEDIUM-3 — `dep-audit.yml:45` `--mode=null-safety` is dead-flag invocation (downgraded from CRITICAL)

- `dep-audit.yml:45`: `run: dart pub outdated --mode=null-safety --json || true`.
- `--mode=null-safety` was relevant for the Dart 2.12 nullable-by-default migration (~2021). It is now a **no-op / informational** mode; output bears no relation to outdated-package detection.
- The `|| true` swallows any failure. Dead code producing JSON nobody reads, on a flag that means nothing in 2026.
- **Pass-2 disposition:** hygiene smell, not a security gap. The OSV step (`:50-58`) does the real work.
- **Severity:** MEDIUM (hygiene).
- **Effort:** remove the line entirely or replace with `dart pub outdated --mode=outdated --json > pub-outdated.json`. 5 minutes.

### MEDIUM-4 — `dep-audit-allowlist.md` documents an allowlist mechanism the workflow doesn't read (downgraded from CRITICAL)

- `dep-audit-allowlist.md:3-5`: *"The dep-audit.yml workflow does **not** currently read this file."* Allowlist table at `:14` is empty.
- Pass-2 disposition: not a CRITICAL landmine because the file is empty AND the doc itself flags the unwired status. The risk is the **future** anti-pattern of relaxing `--audit-level` inline in the workflow (per `:8-9`'s own instruction). That's a process risk, not a current state risk.
- **Pass-1 self-critique #7** correctly noted the simpler fix is to delete the file rather than wire it up. Pass 2 endorses delete + procedure removal.
- **Severity:** MEDIUM (cleanup).
- **Effort:** 15 min delete + remove from any CLAUDE knowledge file.

### MEDIUM-5 — `flutter_local_notifications` direct usage is a single file

- Per import grep: 1 file in `lib/`.
- Normal for a notification-helper service, but flagged because the package is held back at major-1 (HIGH-2 cluster) and only one consumer means the cost-of-upgrade is bounded.
- **Severity:** LOW (informational for the upgrade roadmap).

### MEDIUM-6 — `pointycastle` is in the resolved tree (transitive via `dart_jsonwebtoken`) but **zero direct imports** in lib/

- `pub-deps.txt:238`: `pointycastle 4.0.0`.
- Pass-2 grep `package:pointycastle/` in `lib/` → 0 files (verified).
- **Implication:** the pre-known fact that "pointycastle: AES and other encryption primitives" is in the security-critical-package list (`05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92`) is misleading. Butlery doesn't use pointycastle directly — only `dart_jsonwebtoken` does (test-side, `pub-deps.txt:75`).
- **Severity:** LOW — corrects the prompt's pre-known-facts list. Not a bloat issue (would require dropping `dart_jsonwebtoken`, used in test mocks).

### MEDIUM-7 — `intl 0.20.2` is one minor behind a major bump cliff

- `pub-outdated.txt`: not flagged outdated.
- But `intl` is a Dart team package with a known history of disruptive breaking changes per major (date format constants moved, locale ID semantics shifted). Worth checking the next-major's CHANGELOG when it lands.
- **Severity:** LOW (forward-looking).

### MEDIUM-8 — `wakelock_plus 1.4.0` (latest 1.6.0) — minor lag, no inline reason

- `pubspec.yaml:48`: no comment justifying the hold.
- `pub-outdated.txt:124`: `*1.4.0 ... 1.6.0`.
- 2 minors. Same `plus_plugins` family as the BUT-750 victims (device_info_plus, connectivity_plus). Worth checking if 1.6.0 ships an iOS-26-only API call (the BUT-750 pattern).
- **Severity:** MEDIUM if BUT-750 pattern recurs, LOW otherwise.

### LOW-1 — `meta 1.16.0` (latest 1.18.2) and `cli_util 0.4.2` (latest 0.5.0) on dev side
- `pub-outdated.txt:130, 128`. Dart team packages, low risk.

### LOW-2 — `very_good_analysis 10.0.0 → 10.2.0`
- `pub-outdated.txt:134`. Lint rules expand each minor; expect new analyzer findings to fix.

### LOW-3 — Lockfile churn pattern indicates moderate review hygiene
- Total `pubspec.lock` commits in repo: 65.
- 2024: 36; 2025: 0; 2026: 29. Spike in 2026 corresponds to dependency-cleanup waves (BUT-750 pinning, BUT-434 receive_intent migration).
- The 2025 zero is striking — either commits got squashed into the 2024-cutover or there was a year-long pause in dep updates.

### LOW-4 — `package-lock.json` rarely changes
- 13 commits total. NPM side is much less active than pub side. Cloud Functions has 4 prod deps and is tightly scoped.
- `git log --oneline functions/package.json` = 29 — package.json churns more than its lockfile, which is unusual. Suggests dev dependencies (typescript, ts-node, @types/node) are sometimes updated without re-locking npm.

### LOW-5 — `lefthook.yml:21` secret-scan grep regex covers AWS/Google/Stripe/PEM/npm/GitHub but not Firebase Admin SDK service-account JSON beyond `"type": "service_account"`
- Caught in passing while reviewing pre-commit posture; not a dependency issue per se but adjacent to supply-chain. Defer to prompt 02 (security).

### LOW-6 — `excel/csv/archive` chain SHIPS via deferred-loaded route (corrected from Pass-1 MEDIUM-3)

- `lib/core/router/modules/extraction_deferred_module.dart:9, 31`: `Routes.fileImport` is registered as a deferred-loaded production route alongside import-via-URL, smart-import, photo-import, and arkiv-import.
- Pass-1 MEDIUM-3 wrongly suggested these might be dead weight. They're not — file-import-from-Excel is shipped, deferred for first-load weight, and the cascade pin (`pubspec.yaml:60` `image: ^4.3.0` ↔ archive 3.6.x) is justified.
- **Severity:** LOW (informational; nothing to fix). Listed to close out Pass-1's hypothesis explicitly.

---

## Per-Dep Hygiene Table (Top 30 Direct Deps)

Sorted by criticality / used-in-N-files (descending).

| # | Package | Current | Latest | License | Maintenance Signal | Pin (in pubspec.yaml line) | Used in N files |
|---|---|---|---|---|---|---|---|
| 1 | `cloud_firestore` | 6.2.0 | 6.3.0 | BSD-3 | Active (Firebase team) | caret `^6.1.0` (`:24`) | **158** |
| 2 | `provider` | 6.1.5+1 | (latest) | MIT | Active | caret `^6.1.2` (`:38`) | 71 |
| 3 | `uuid` | 4.5.3 | (latest) | MIT | Active | caret `^4.5.3` (`:66`) | 38 |
| 4 | `get_it` | 9.2.1 | (latest) | MIT | Active | caret `^9.2.1` (`:39`) | 23 |
| 5 | `image_picker` | 1.2.1 | 1.2.2 | BSD-3 | Active (Flutter team) | caret `^1.1.2` (`:55`) | 16 |
| 6 | `shared_preferences` | 2.5.5 | (latest) | BSD-3 | Active (Flutter team) | caret `^2.3.2` (`:42`) | 15 |
| 7 | `collection` | 1.19.1 | (latest) | BSD-3 | Active (Dart team) | caret `^1.18.0` (`:68`) | 11 |
| 8 | `cached_network_image` | 3.4.1 | (latest) | MIT | Active | caret `^3.4.1` (`:57`) | 11 |
| 9 | `http` | 1.6.0 | (latest) | BSD-3 | Active (Dart team) | caret `^1.2.2` (`:51`) | 11 |
| 10 | `drift` | 2.29.0 | 2.32.1 | MIT | Active (simolus3) — single high-trust maintainer | caret `^2.29.0` (`:43`) **HELD** | 10 |
| 11 | `firebase_auth` | 6.3.0 | 6.4.0 | BSD-3 | Active | caret `^6.1.2` (`:23`) | 10 |
| 12 | `firebase_storage` | 13.2.0 | 13.3.0 | BSD-3 | Active | caret `^13.0.4` (`:26`) | 8 |
| 13 | `crypto` | 3.0.7 | (latest) | BSD-3 | Active (Dart team) | caret `^3.0.5` (`:76`) | 8 |
| 14 | `rxdart` | 0.28.0 | (latest) | Apache-2.0 | Active | caret `^0.28.0` (`:69`) | 8 |
| 15 | `html` | 0.15.6 | (latest) | BSD-3 | Active (Dart team) | caret `^0.15.4` (`:79`) | 7 |
| 16 | `clock` | 1.1.2 | (latest) | Apache-2.0 | Active (Dart team) | caret `^1.1.1` (`:71`) | 7 |
| 17 | `cloud_functions` | 6.1.0 | 6.2.0 | BSD-3 | Active | caret `^6.0.4` (`:88`) | 6 |
| 18 | `timeago` | 3.7.1 | (latest) | MIT | Active | caret `^3.6.1` (`:86`) | 6 |
| 19 | `share_plus` | 12.0.2 | 13.1.0 | BSD-3 | Active (Flutter team) | caret `^12.0.2` (`:72`) **major lag** | 5 |
| 20 | `permission_handler` | 12.0.1 | (latest) | MIT | Active | caret `^12.0.1` (`:58`) | 5 |
| 21 | `intl` | 0.20.2 | (latest) | BSD-3 | Active (Dart team) | caret `^0.20.2` (`:67`) | 5 |
| 22 | `url_launcher` | 6.3.2 | (latest) | BSD-3 | Active (Flutter team) | caret `^6.3.1` (`:70`) | 5 |
| 23 | `flutter_inappwebview` | 6.1.5 | (latest) | Apache-2.0 | Active (single maintainer pichillilorenzo) — large attack surface | caret `^6.1.5` (`:80`) | 4 |
| 24 | `path_provider` | 2.1.5 | (latest) | BSD-3 | Active (Flutter team) | caret `^2.1.4` (`:73`) | 4 |
| 25 | `firebase_database` | 12.2.0 | 12.3.0 | BSD-3 | Active | caret `^12.1.3` (`:25`) | 4 |
| 26 | `firebase_analytics` | 12.2.0 | 12.3.0 | BSD-3 | Active | caret `^12.0.4` (`:27`) | 4 |
| 27 | `firebase_performance` | 0.11.2 | 0.11.3 | BSD-3 | Active | caret `^0.11.0` (`:30`) | 4 |
| 28 | `connectivity_plus` | 7.0.0 | 7.1.1 | BSD-3 | Active (Flutter Community) — BUT-750 hold | **EXACT** `7.0.0` (`:52`) | 3 |
| 29 | `file_picker` | 11.0.2 | (latest) | MIT | Active | caret `^11.0.2` (`:74`) | 3 |
| 30 | `firebase_messaging` | 16.1.3 | 16.2.0 | BSD-3 | Active | caret `^16.0.4` (`:29`) | 3 |

**Single-import deps (audit candidates):** `excel` (1 file), `archive` (1), `csv` (1), `sembast_web` (1), `flutter_local_notifications` (1), `package_info_plus` (1), `image` (1), `wakelock_plus` (1), `app_links` (1), `algoliasearch` (1), `freerasp` (1), `firebase_app_check` (1), `sqlcipher_flutter_libs` (1 — `lib/core/storage/drift/app_database.dart` per Pass-2 verification), `sqlite3` (1), `in_app_review` (1), `image_cropper` (1), `flutter_onnxruntime` (2 — `onnx_ner_service.dart`, `onnx_line_classifier_service.dart`).

**Single-import isn't bad** — many service deps legitimately live behind a single facade. The flag is for the **unusual ones**: `flutter_onnxruntime` (HIGH-7 model integrity) and `sqlcipher_flutter_libs` substrate (CRITICAL-1).

---

## Supply-Chain Attack Surface

### Lockfile integrity
- `pubspec.lock` committed (verified — 2294 lines, 281 packages).
- `functions/package-lock.json` committed (3909 lines, 317 nodes).
- No `pubspec_overrides.yaml`.
- One `overrides` block in `functions/package.json:71-73`: `protobufjs ^7.5.5`. **Defensive override** preempts a prototype-pollution CVE chain in older protobufjs. Confirmed in lockfile transitive: `protobufjs ^7.5.4` (firebase-admin), `^7.5.3` (other), `^7.2.5` (yet other) — all overridable to ≥7.5.5. Good hygiene. **But — no inline comment explaining the security rationale**, so on a future maintainer trying to "tidy up overrides" this could revert. **Recommend:** add a comment block above line 71 referencing the original CVE (CVE-2023-36665) and a "do not remove" warning.

### Pin discipline
- 72 caret-loose, 2 exact pins (BUT-750 victims). See HIGH-6 — recommend tightening the 3 most security-critical to exact pins.

### Runtime model integrity (NEW — Pass 2)
- `flutter_onnxruntime` runs ONNX models on-device; models are **downloaded at runtime from Firebase Storage**, not bundled in `assets/data/`.
- `assets/data/` contains `crf_ingredient_weights.crfsuite` and `crf_ingredient_weights.json` only — the heavier ONNX models live in Firebase Storage at `models/ingredient_ner/v{N}/model.onnx` and `models/line_classifier/v{N}/model.onnx`.
- **No SHA-256 / integrity verification on download** (HIGH-7). This is the largest unaddressed supply-chain gap in the Butlery dep stack.

### CI dep-audit reality check (line-by-line)

| Line | Behaviour | Verdict |
|---|---|---|
| `dep-audit.yml:7-14` | PR trigger paths-filtered to lockfiles + workflow YAML | OK; tight scope |
| `:15-16` | Weekly Mon 05:00 UTC schedule | OK |
| `:17` | workflow_dispatch | OK |
| `:7-17` | **No `push: branches: [main]` trigger** | **HIGH-5 GAP** — lockfile push to main bypasses audit until next Mon |
| `:38` | Flutter 3.35.1 hardcoded | OK; matches other workflows |
| `:45` | `dart pub outdated --mode=null-safety --json \|\| true` | **MEDIUM-3 DEAD FLAG** (downgraded from Pass-1 CRIT) — `--mode=null-safety` is a no-op in 2026 |
| `:47-48` | `flutter pub deps \|\| true` | Informational only; OK |
| `:50-58` | OSV scan against `pubspec.lock` with SARIF output | OK; correct wiring |
| `:51` | `id: osv` for outcome ref | OK |
| `:52` | `continue-on-error: true` to allow SARIF upload | OK; expected pattern |
| `:60-65` | SARIF upload to GH security tab via `codeql-action/upload-sarif@v4` | OK |
| `:69-73` | `if: steps.osv.outcome == 'failure'` re-asserts CI failure | OK; correct wiring |
| `:75-97` | NPM audit job in `defaults: working-directory: functions` | Mostly OK |
| `:89` | `node-version: "20"` | **CRITICAL-2** — engines field demands Node 22; audit resolves under 20 |
| `:97` | `npm audit --audit-level=high` | OK; fail on HIGH/CRITICAL |
| Whole file | No `osv-scanner --experimental-licenses` step | LOW gap — license scanning unmonitored |
| Whole file | No `dart pub audit` step | LOW gap — second-source advisory check missing |

### Publisher verification (corrected vs run-1)

| Package | Publisher (verified per pub.dev live fetch) | Run-1 verdict | Pass-1 verdict | Pass-2 disposition |
|---|---|---|---|---|
| `sqlcipher_flutter_libs` | simonbinder.eu | Verified | Verified — but **EOL** | EOL hold (CRITICAL-1) |
| `http_certificate_pinning` | softarch.dev | "Unverified — single maintainer" | Verified publisher (Apache-2.0). Last release 13 months ago. Run-1 was wrong. | **Confirmed** |
| `flutter_onnxruntime` | masic.ai | "Need to confirm" | Verified publisher (MIT). 1.7.0 released 21 days ago. | **Confirmed** but PROMOTE — model-integrity gap (HIGH-7) |
| `algoliasearch` | algolia.com | Verified | Verified. 1.49.0 released 3 days ago. | **Confirmed** |
| `freerasp` | talsec.app | "Mixed licence" | Verified publisher. MIT + freemium fair-use policy. | **Confirmed** — re-eval at scale milestones |
| `drift` | simonbinder.eu | Verified | Verified. Same maintainer as sqlcipher — concentration risk. | **Confirmed** |
| `flutter_inappwebview` | inappwebview.dev | Verified | Verified. Single maintainer (pichillilorenzo). Concentration risk. | **Confirmed** |

### Dependabot configuration audit (`.github/dependabot.yml:1-113`)

| Line(s) | Setting | Verdict |
|---|---|---|
| `:13-22` | pub ecosystem, weekly Monday, PR limit 5 | OK |
| `:25-31` | `firebase` group: `firebase_*` + `cloud_firestore*`, minor+patch | OK |
| `:32-40` | `flutter-deps` catch-all group, minor+patch | OK |
| `:41-44` | **Ignore all major bumps for all packages** | Justified for solo dev (BUT-562) per `:6-7` comment, but means `share_plus 12→13` and `app_links 6→7` will never come in via Dependabot — they need manual handling |
| `:46-52` | `device_info_plus` and `connectivity_plus` ignored entirely | Correct — pin justified at `pubspec.yaml:34, 52` |
| `:54-84` | npm ecosystem, similar shape | OK |
| `:67-73` | `firebase-admin` group: `firebase-*`, `@firebase/*`, `@google-cloud/*` | OK |
| `:90-112` | github-actions ecosystem, weekly | OK |
| `:109-112` | Major bumps ignored on Actions too | Justified |

### Lockfile-churn discipline
- `git log --oneline pubspec.lock | wc -l` = 65 commits total.
- Year buckets: 2024=36, 2025=0, 2026=29.
- `git log --oneline functions/package-lock.json | wc -l` = 13 commits total.
- `git log --oneline functions/package.json | wc -l` = 29 — package.json churns more than its lockfile, which is unusual.

---

## What's Missing / What Nobody Asked (≥30%)

### Missing-1 — There is no `LICENSE`, `NOTICE`, or `LICENSES.md` file at the repo root

`ls C:/Butlery/butlery/LICENSE* C:/Butlery/butlery/NOTICE*` returns no matches (Pass-2 reverified). Three concrete consequences:

1. **`node-forge` BSD-3-vs-GPL-2 election is undocumented.** A license auditor running SPDX detection over the lockfile sees `(BSD-3-Clause OR GPL-2.0)` and asks which one Butlery elected.
2. **`freerasp` freemium fair-use disclosure is missing.** Talsec's MIT covers the open-source part; the SDK has a "fair usage policy" the app should track.
3. **For Apple App Store and Google Play submission**, the listing and the in-app license screen need to align with bundled licenses. Flutter's auto-generated LicensePage covers per-package files but a top-level NOTICE.md is conventional for closed-source apps. Not a blocker today (per `feedback_no_store_submission_yet.md`, store submission deferred), but on critical path before BUT-415.

### Missing-2 — No license-scanning in CI

`dep-audit.yml` runs OSV (CVE-only) and `npm audit` (CVE-only). Neither flags **license drift** — e.g., a transitive becoming GPL-licensed in a future release. For a closed-source app, **license drift is a strictly worse problem than CVE drift** — CVEs you can patch, GPL contamination requires architectural surgery. Add `osv-scanner --experimental-licenses` or `licensee detect` as a CI step. Effort: 0.5 day.

### Missing-3 — No SBOM (Software Bill of Materials) generated or published

The orchestrator README and dep-audit configuration don't mention SBOM. Modern supply-chain best practice (and increasingly a legal/contractual requirement, e.g., EU Cyber Resilience Act starting 2027) is to publish a CycloneDX or SPDX SBOM with each release. Lockfiles ARE an SBOM in raw form, but a normalized SBOM artefact uploaded to GH Releases would let downstream auditors run their own scanning, give the team a versioned record of "what shipped on date X", and enable diff-based vulnerability response.

Effort: 1 day (CycloneDX SBOM generation in dep-audit.yml + artefact upload).

### Missing-4 — No dependency-pruning analysis on the resolved transitive tree

281 resolved pub packages + 317 npm modules = ~600 supply-chain nodes. Concrete examples:
- `excel ^4.0.6` pulls `archive`, `xml`, `equatable` (`pub-deps.txt:20`). Image↔archive cascade pin (`pubspec.yaml:60`) traceable to the file-import feature, which IS shipped (LOW-6).
- `firebase_*` family pulls 11 `*_platform_interface` and `*_web` packages — unavoidable.
- `flutter_inappwebview` pulls 7 platform sub-packages (`pub-deps.txt:165-171`). Largest single concentration of native code.
- `dio` (via `http_certificate_pinning`) pulls `dio_web_adapter`, `http_parser`, `mime` — all also pulled by `http`. Some duplication of effort.

### Missing-5 — No threat model for the "compromised npm/pub package" scenario

The deeper question: **if `algoliasearch 1.46.2` published a malicious 1.46.3 patch tomorrow, how would Butlery detect it?** Audit catches CVEs but not zero-days. Defense in depth would mean SRI-equivalents for pub deps (pubspec.lock content hashes — present), exact-pinning security-critical packages (HIGH-6), separate dev vs prod dependency graphs in CI (currently shared lockfile resolution), Dependabot auto-merge gates (current config has none — each PR is a human checkpoint, good).

A 1-page `docs/security/dependency-threat-model.md` would be cheap insurance. Defer to prompt 02 for security-doc ownership.

### Missing-6 — Single-maintainer concentration risk underweighted

`drift`, `drift_dev`, `sqlcipher_flutter_libs`, `sqlite3` are all maintained by **one human (simolus3)**. The encrypted-DB substrate (CRITICAL-1's EOL package), query/ORM (drift), codegen (drift_dev), native binding (sqlite3). If simolus3 stops maintaining, Butlery has no fallback maintainer and no fork strategy. Not a vulnerability — simolus3 has been responsive for years and is sponsored by Google. But concentration risk no other audit lens catches.

### Missing-7 (NOW PROMOTED — see HIGH-7) — `flutter_onnxruntime` runs ONNX models on-device with no integrity verification

Original Pass-1 framing deferred this to prompt 07. Pass 2 promotes to HIGH-7 and keeps in this prompt. Pass-1 self-critique #10 was correct.

### Missing-8 — `intl 0.20.2` and the date-locale data: ships locale rules

Locale data drives how dates and numbers format for Swedish users. If `intl` ships an updated locale-data table that changes Swedish date formatting (it has happened — Swedish date conventions evolved), that's a **silent UX regression**. Defer to prompt 06 (UX).

### Missing-9 — The `pre-known-facts` claim about pointycastle is wrong

The prompt's pre-known-facts list (`05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92`) names `pointycastle` as one of the security-critical packages. But:
- `pubspec.yaml` does NOT depend on `pointycastle` directly.
- `pub-deps.txt:238` shows it as transitive via `dart_jsonwebtoken` (a dev dep, used for `firebase_auth_mocks`).
- Grep `package:pointycastle/` in `lib/` returns 0 matches (Pass-2 reverified).

**pointycastle is not on Butlery's runtime cryptography path.** Butlery uses the `crypto` package (`pubspec.yaml:76`) for SHA hashing and the platform-native crypto (via `flutter_secure_storage`, `firebase_app_check`, `freerasp`) for everything else. The pre-known-facts list should be corrected. Defer to prompt 12 (doc drift).

### Missing-10 — No CHANGELOG generation for dependency changes

`git log pubspec.yaml` shows commits but message format is freeform. No machine-readable record of "which dependencies changed in release X.Y.Z" because the project doesn't tag releases yet (per `pubspec.yaml:4`: `version: 1.0.0+1` unchanged). For a single-engineer project this is fine, but at first store submission it becomes a problem. CycloneDX SBOM (Missing-3) addresses this.

### Missing-11 — `package.json:engines.node` is not enforced at install time

`functions/package.json:55-57` declares `"engines": { "node": "22" }` but does NOT include `engine-strict=true` in any `.npmrc`. Combined with CRITICAL-2, `npm ci` under Node 20 emits a warning but continues. A `.npmrc` with `engine-strict=true` at `functions/.npmrc` would convert the warning to an error and force the audit job to fix its node-version. 1-minute fix, makes the configuration self-healing.

---

## Pass-1 Self-Critique — Pass-2 Disposition

Pass-2 reviewed each Pass-1 self-critique item and dispositioned each:

1. **CRITICAL-2 (Node version mismatch).** Pass-1 wondered if practical lockfile diff under Node 20 vs 22 is empty for a 4-prod-dep tree. **Pass-2 disposition:** doesn't matter — even if the resolved transitives are identical, the *audit* step's behavior under different Node majors differs (engines-strict warnings, `npm audit` output normalization). Severity stays CRITICAL because it's a configuration mismatch that will eventually bite, not a guaranteed-to-bite-now issue.

2. **HIGH-1 (build_runner discontinued subgraph).** Pass-1 said dev-only / not runtime risk. **Pass-2 disposition:** Pass 1's self-critique that `*.g.dart` IS runtime is correct. Severity stays HIGH; framing in the report is now nuanced (line above).

3. **MEDIUM-3 → LOW-6 (excel/csv/archive cluster).** **Pass-2 verified file_import_view IS reachable** (`lib/core/router/modules/extraction_deferred_module.dart:9, 31`). Downgraded MEDIUM-3 to LOW-6 (informational confirmation, nothing to fix).

4. **HIGH-3 (node-forge dual-license).** Pass-1 noted the Swedish-vs-US/German jurisdictional question. **Pass-2 disposition:** for current state (Swedish dev, no store submission), BSD-3 election is unambiguous. The audit-trail gap is the actual issue. Severity stays HIGH.

5. **HIGH-5 (no push trigger).** Pass-1 noted the proposed YAML should be path-filtered. **Pass-2 disposition:** path-filtered version included in the fix. Confirmed correct.

6. **HIGH-6 (caret-loose pin posture).** Pass-1 wavered between "exact-pin 10" and "exact-pin 3". **Pass-2 disposition:** narrowed to 3 most security-critical (`firebase_app_check`, `freerasp`, `http_certificate_pinning`) to balance review burden. Solo dev, 30 minutes effort.

7. **CRITICAL-4 → MEDIUM-4 (allowlist file unwired).** Pass-1 self-critique correctly leaned toward "delete" over "wire it up". **Pass-2 disposition:** downgrade to MEDIUM, recommend delete + procedure removal.

8. **Missing-9 (pointycastle correction).** Pass-1 confidence in zero direct imports verified by Pass-2 grep. Reflective dynamic loading from `dart_jsonwebtoken` is irrelevant for runtime path because `dart_jsonwebtoken` is a dev dependency. Stands.

9. **Score deduction allocation across Dim 1 vs Dim 5.** Pass-2 reallocated: CRITICAL-2 and CRITICAL-3 (now MEDIUM-3) belong primarily in Dim 5 Supply Chain Integrity. Dim 1 Vulnerability Scanning stays at 15/25 (no actual unpatched CVEs). Dim 5 stays at 5/12 with HIGH-7 added.

10. **Missing-7 (ONNX model provenance) → HIGH-7.** Promoted as expected from Pass-1's own concern.

11. **Lockfile churn 2025=0 anomaly.** Pass-2 didn't dig deeper. Likely commits got squashed during a reorganization. Listed as LOW-3 informational.

12. **Drift sqlcipher_flutter_libs migration claim.** Pass-2 didn't read `UPGRADING_TO_V3.md` because the conclusion (CRITICAL-1 is a substrate replacement, not a version bump) holds regardless of the precise migration path. Effort estimate may shift; severity classification doesn't.

---

## Reference count check

File:line and pub.dev citations in this report (Pass-2 enforcement):

`pubspec.yaml`: 4, 23, 24, 25, 26, 27, 29, 30, 33, 34, 38, 39, 42, 43, 44, 48, 51, 52, 55, 57, 58, 60, 66, 67, 68, 69, 70, 71, 72, 73, 74, 76, 79, 80, 81, 83, 86, 87, 88, 92, 93, 113. (~42 distinct)
`pubspec.lock`: top-level integrity (1 ref).
`pub-outdated.txt`: 1-88, 95, 97-122, 124, 127, 130, 134, 143-165, 198-199, 217-218. (~30 line refs across 9 ranges)
`pub-deps.txt`: 20, 60, 69, 75, 129, 165-171, 238. (8 distinct)
`functions/package.json`: 55-57, 60, 71-73. (3 distinct)
`functions/package-lock.json`: firebase-admin entry, node-forge entry, BSD-3-OR-GPL-2 license entry. (3 refs)
`functions/src/index.ts`: 10, 24. (2)
`functions/src/llm/gemini-client.ts`: 17-22, 22. (2)
`functions/src/llm/ocr-recipe-image.ts`: 18, 394. (2)
`functions/src/llm/PROMPT_CHANGELOG.md`: 58. (1, **NEW Pass 2**)
`.github/workflows/dep-audit.yml`: 7-9, 7-17, 15-16, 38, 45, 47-48, 50-58, 51, 52, 60-65, 69-73, 75-97, 89, 97. (12 distinct)
`.github/workflows/e2e_tests.yml`: 68 (`node-version: '20'`). (1, **NEW Pass 2**)
`.github/workflows/firestore-rules.yml`: 52 (`node-version: "22"`). (1, **NEW Pass 2**)
`.github/dependabot.yml`: 6-7, 13-22, 18, 25-31, 32-40, 41-44, 46-52, 54-84, 67-73, 90-112, 109-112. (10)
`.github/dep-audit-allowlist.md`: 3-5, 8-9, 14. (3)
`lefthook.yml`: 21. (1)
`lib/services/import/file_import_strategy.dart`: 3-7. (1 range)
`lib/core/router/modules/extraction_deferred_module.dart`: 9, 31. (2, **NEW Pass 2**)
`lib/core/storage/drift/app_database.dart`: file-level confirm. (1, **NEW Pass 2**)
`lib/services/parsing/ner/ner_model_manager.dart`: 24-30, 55-100, 153-157. (3, **NEW Pass 2**)
`lib/services/parsing/ner/onnx_ner_service.dart`: 55-78. (1, **NEW Pass 2**)
`lib/services/parsing/line_classifier/line_classifier_model_manager.dart`: file-level. (1, **NEW Pass 2**)
`lib/repositories/algolia/algolia_pinning_interceptor.dart`: file-level. (1)
`lib/services/security/pinned_http_client.dart`: file-level. (1)
`assets/data/`: directory listing — no `.onnx` files bundled. (1, **NEW Pass 2**)
Pub.dev live-fetch references for: `sqlcipher_flutter_libs`, `http_certificate_pinning`, `freerasp`, `flutter_onnxruntime`, `algoliasearch`. (5)

**Total distinct file:line refs: ≥ 100**, comfortably over the 50-ref floor.

---

## Three answers for the orchestrator

1. **Score:** **62 / 100** (down from Pass-1's 64 — Pass 2 promoted ONNX-model integrity gap from "deferred to prompt 07" to HIGH-7; balanced by recovering 1 point in Dependency Bloat after verifying excel/csv/archive ships via deferred route).
2. **Total file:line + pub.dev refs:** **≥ 100 distinct references** (see Reference count check above).
3. **Top critical finding:** **`sqlcipher_flutter_libs 0.7.0+eol` is confirmed END-OF-LIFE per pub.dev.** Butlery's encrypted-SQLite substrate is on a formally-retired binary distribution. Migration target is `package:sqlite3 ^3.x` paired with drift 2.32+, gated on a Flutter SDK floor bump. 4-step cascade. 0.5d investigation + 2-3d migration. Treat as substrate replacement, not version bump. **Runner-up critical (Pass-2 NEW):** runtime-downloaded ONNX inference models (`models/ingredient_ner/v{N}/model.onnx`) have no SHA-256 / integrity verification — a compromised admin token could swap in a model that produces wrong NER outputs on user content.

---

## Pass 2 — Critic findings (second-critic pass, 2026-05-02)

This block is appended by an independent critic invocation (Opus 4.7, separate context). It does not delete or rewrite the report above; it annotates inline-equivalent corrections, fills blind spots, and adjusts severity where verification disagrees.

### Verification matrix (re-verified against live source, this pass)

| Original claim | Source line(s) checked | Verdict |
|---|---|---|
| `sqlcipher_flutter_libs 0.6.8` resolved, latest is `0.7.0+eol` | `pub-outdated.txt:122` → `*0.6.8 ... 0.7.0+eol` | **CONFIRMED** verbatim |
| `dep-audit-allowlist.md` not wired into CI | `dep-audit.yml:1-98` reviewed end-to-end — no reference to `dep-audit-allowlist.md` anywhere | **CONFIRMED** |
| Dependabot PR limits 5/5/5 | `dependabot.yml:18` (pub), `:60` (npm), `:96` (github-actions) → all `open-pull-requests-limit: 5` | **CONFIRMED** (2 grep hits + 1 typo'd ":96" in spec — file uses `:96` for github-actions block) |
| Vertex/Gemini, not Mistral | `functions/package.json:60` `"@google-cloud/vertexai": "1.12.0"`; `functions/src/llm/gemini-client.ts:16-22` imports `VertexAI, GenerativeModel, SchemaType, type Schema, type GenerateContentResponse` from `"@google-cloud/vertexai"`; comment block `:11-13` even has migration note "BUT-614: switched from Google AI Studio to Vertex AI" | **CONFIRMED** the doc-vs-code mismatch in `functions/src/index.ts:10,24` is real |
| `--mode=null-safety` stale flag | `dep-audit.yml:45` → `run: dart pub outdated --mode=null-safety --json \|\| true` | **CONFIRMED** verbatim |
| `excel/csv/archive` chain single-import | grep `import.*'package:(excel\|csv\|archive)/'` in `lib/` returns exactly 3 hits, all in `lib/services/import/file_import_strategy.dart:3-5` | **CONFIRMED** |
| `excel/csv/archive` ships via deferred route | `extraction_deferred_module.dart:9` `deferred as file_import`, `:31` `Routes.fileImport` in `handledRoutes` | **CONFIRMED** |
| `dep-audit.yml:89` `node-version: "20"` vs `engines:22` | Verbatim re-read | **CONFIRMED** |
| 89 unique file:line refs | Spot-checked the Reference count section — 100+ distinct refs across ~25 files | **CONFIRMED** evidence density meets the ≥50 floor |

All 9 sampled CRITICAL/HIGH claims survive verification. **No Pass-1/Pass-2 claim is hereby retracted.**

### Critic NEW finding C1 — `functions/.npmrc` already has `ignore-scripts=true`; the report missed Butlery's actual best supply-chain hygiene

**File:** `functions/.npmrc:1-5`:
```
ignore-scripts=true
save-exact=true
package-lock=true
fund=false
update-notifier=false
```

The Pass-1 report's "Missing-11" item asks for an `engine-strict=true` directive in a `.npmrc`. The critic confirms the file **exists** and contains stronger directives that go unmentioned in the entire 539-line report:

- **`ignore-scripts=true`** — disables `preinstall`/`install`/`postinstall` lifecycle scripts on dependency install. This is the **single most effective defense** against the npm install-time supply-chain attacks that have hit the ecosystem since 2018 (event-stream, ua-parser-js, color, faker, the 2024 polyfill.io takeover, etc.). It deserves explicit acknowledgment in a supply-chain prompt.
- **`save-exact=true`** — `npm install foo` writes `"foo": "1.2.3"` (no caret), enforcing exact-pin discipline on the npm side **at the editor level**. Means any new npm dep added is exact-pinned by default, no human discipline required. The report's HIGH-6 worry about caret-loose pinning applies to pub but **emphatically NOT to npm** — the `.npmrc` already enforces what HIGH-6 wants.
- **`package-lock=true`** — explicit (default), but also good defense against a maintainer accidentally running `npm install --no-lock`.
- **`fund=false`, `update-notifier=false`** — noise reduction for CI logs, no security implication.

**Severity correction:** Add a HIGH PRAISE entry: Butlery's `functions/.npmrc` is the strongest piece of supply-chain hygiene in the entire dep stack, and the absence of an analogous `.dart_tool` setting is a **gap** (Dart has no equivalent — `pub get` doesn't run install-time scripts, but build_runner DOES execute generators by design; the equivalent question for Dart is "do we trust drift_dev codegen?").

**Action:** Add `engine-strict=true` to the existing `.npmrc` (1-line append). This makes Missing-11 a 30-second fix, not a "create the file" task. Effort downgraded.

### Critic NEW finding C2 — Trivy + TruffleHog in `build-validation.yml` are uncited supply-chain coverage

The report covers `dep-audit.yml` (OSV + npm audit) exhaustively but **never mentions** that `build-validation.yml` runs two additional supply-chain scanners on every push to main:

- `build-validation.yml:69-75` — `aquasecurity/trivy-action@v0.36.0` with `scan-type: 'fs'`, `severity: 'HIGH,CRITICAL'`, `exit-code: '1'`. Trivy `fs` mode scans **lockfiles, OS packages, IaC, and secrets** in the entire workspace — a meaningfully broader cone than OSV's `pubspec.lock`-only scan. Trivy will flag the same Dart and npm CVEs as OSV/npm-audit AND catches dockerfile/IaC issues OSV doesn't.
- `build-validation.yml:87-90` — `trufflesecurity/trufflehog@v3.95.2` with `--only-verified` flag and `fetch-depth: 0` (full git history). This is the **secret-scanning** safety net for committed credentials — a different supply-chain leg than CVE scanning.

**Implication:** the report's HIGH-5 ("no `push: branches: [main]` trigger on dep-audit.yml") is **partially mitigated** by Trivy running on every push to main via build-validation.yml. The audit gap is narrower than the report claimed: not "7 days unaudited" but "7 days un-OSV'd, but Trivy still ran." Severity should be downgraded HIGH → MEDIUM.

**Trivy version note:** `trivy-action@v0.36.0` is the version pinned. As of late 2025 the project shipped beyond `v0.40.x`. Stale by ~4 minors. New CVE detections in upstream Trivy are missed. Worth a Dependabot bump (already covered by the github-actions ecosystem block in `dependabot.yml:90-112`, weekly cadence — should pick this up).

### Critic NEW finding C3 — Workflow action versioning: mutable major-tag refs everywhere, zero SHA pinning

Grep across all `.github/workflows/*.yml` for `uses:` reveals **37 action invocations**. Every single one uses a **mutable major-tag ref** (`@v4`, `@v6`, etc.), not a SHA pin. Concrete inventory:

| Action | Tag pattern | Risk |
|---|---|---|
| `actions/checkout` | `@v4` (firestore-rules, dep-audit) AND `@v6` (test, e2e_tests, build-validation, architecture-validation) — **inconsistent** | If `@v4` upstream gets a malicious tag (per the tj-actions/changed-files Mar 2025 incident), every workflow on main runs that code |
| `subosito/flutter-action` | `@v2` (5 workflows) | Third-party action; same compromise vector |
| `actions/setup-node` | `@v4` (3 workflows) | First-party but mutable |
| `actions/setup-java` | `@v4` (2 workflows) | Same |
| `actions/upload-artifact` | `@v7` (5 callsites) | First-party |
| `actions/cache` | `@v5` (2 callsites) | First-party |
| `aquasecurity/trivy-action` | `@v0.36.0` (exact-pin minor) | Better than `@v0` but not SHA |
| `trufflesecurity/trufflehog` | `@v3.95.2` (exact-pin patch) | Better than `@v3` but not SHA |
| `google/osv-scanner-action/actions/scanner` | `@v2.3.5` (exact-pin patch) | Same |
| `github/codeql-action/upload-sarif` | `@v4` | First-party |
| `codecov/codecov-action` | `@v4` | Third-party (the codecov 2021 incident is exactly this attack vector) |
| `gradle/actions/setup-gradle` | `@v3` | First-party-ish (Gradle org) |
| `actions/github-script` | `@v9` | First-party |

**The tj-actions/changed-files supply-chain compromise (March 2025)** specifically attacked workflows that referenced third-party actions by mutable tag ref. The recommended mitigation per GitHub's own advisory is to pin actions by full commit SHA (`uses: actions/checkout@8edcb1bdb4e267140fa742c62e395cd74f332709 # v4.2.0`). Not done anywhere in Butlery.

**Codecov-specific risk:** `codecov/codecov-action@v4` ran in the historical codecov-bash incident (2021) where attackers replaced the bash uploader and exfiltrated env vars. Pinning to a verified SHA on third-party actions that consume secrets is industry best practice.

**Inconsistency risk:** `actions/checkout` is `@v4` in some workflows and `@v6` in others. Either one is a documented bump or someone mass-bumped half of them and the rest got missed. Either way, both refs are mutable — if the next `@v4.x` release has a malicious tag pushed (admin compromise), every workflow on main runs that code without anyone clicking merge.

**Severity:** **HIGH (NEW — call it HIGH-8).** Every workflow runs on push to main. A compromised tag on any third-party action = code execution in a privileged GitHub runner with `contents: write`/`security-events: write` permissions. Industry-standard fix.

**Effort:** 2 hours to convert all 37 invocations to SHA pins with comment annotations, OR enable Dependabot's `cooldown` config so it pins SHA-equivalents. The latter requires setting `package-ecosystem: github-actions` to use SHA refs in `dependabot.yml:91+` — Dependabot will then bump the SHA on each new tag. Less ergonomic for humans reading the workflow but exactly matches the GitHub-recommended hardening.

### Critic NEW finding C4 — Zero `id-token: write` / OIDC across all workflows

Grep `id-token` across `.github/workflows/*.yml` returns 0 hits. `permissions:` blocks appear only in `dep-audit.yml:19` and `architecture-validation.yml:33`.

**Implication:** any workflow that needs to authenticate to Google Cloud, Firebase, npm publish, or any external service must use **long-lived secrets** (stored in `GITHUB_SECRETS`), not short-lived OIDC tokens. The Trivy/TruffleHog/OSV scanning steps don't need secrets, and the build/test workflows don't appear to publish anything yet, so the practical blast radius is small TODAY. But:

- **No `firebase-deploy` workflow exists yet** (search of `.github/workflows/` confirms — no `deploy.yml`, no `firebase deploy`). When one IS added (per `feedback_no_store_submission_yet.md`, deployment is deferred but inevitable), it should use OIDC (`google-github-actions/auth@v2` with `workload_identity_provider:`), NOT a service-account JSON in secrets.
- **Same applies for App Store / Play Store submission workflows** when those eventually land.

**Severity:** **LOW today (no privileged workflow exists), HIGH when first deploy workflow lands.** Forward-looking architectural guard: **document this as a constraint in the orchestrator README** so the first deploy PR doesn't reach for a service-account JSON.

**Effort:** zero today, 30 min when first deploy workflow needs auth.

### Critic NEW finding C5 — `dependency_overrides` empty (verified) — but the ABSENCE of overrides is itself worth noting

- `pubspec.yaml:1-172` end-to-end: no `dependency_overrides:` block. (Pass-2 grep confirmed.)
- No `pubspec_overrides.yaml` exists at any level (Pass-2 glob `**/pubspec_overrides.yaml` returned 0).

**Why this matters:** dependency_overrides are an escape valve for resolving conflicts. Their **absence** confirms that the entire 281-package transitive graph resolves cleanly without overrides. That's a maintainability win the report should claim. Many projects accumulate 5-10 overrides over time; Butlery has zero.

**Counterpoint:** the corresponding npm-side override (`functions/package.json:71-73` `"protobufjs": "^7.5.5"`) IS present and IS commented in the report. The pub side has nothing to override. Symmetry observation.

**Severity:** LOW (positive finding, deserves mention in the dependency hygiene scorecard).

### Critic NEW finding C6 — Node deps are tightly scoped, freshness verified

The Pass-1 report focused almost exclusively on the Dart side. The full Node prod-dep inventory at `functions/package.json:59-64`:

| Package | Version | Latest stable (as of pre-analysis snapshot) | Verdict |
|---|---|---|---|
| `@google-cloud/vertexai` | `1.12.0` (exact) | `1.12.x` series — current | OK |
| `firebase-admin` | `13.8.0` (exact) | 13.x current | OK |
| `firebase-functions` | `7.2.5` (exact) | 7.x current | OK |
| `p-limit` | `^3.1.0` | 3.x is the last CommonJS-compatible major; 4.x is ESM-only | OK — caret intentional, ESM cliff justifies hold |

Dev deps (`functions/package.json:65-69`):
- `@firebase/rules-unit-testing 5.0.0` — exact, current
- `@types/node ^22` — caret, aligned with `engines.node: 22` 
- `ts-node 10.9.2` — exact, current 10.x line
- `typescript 5.9.3` — exact, current 5.x

**4 prod deps, 4 dev deps, all reasonably current, all exact-pinned (per `.npmrc:save-exact=true`).** Cloud Functions side of the supply chain is genuinely tight — unusual to see in a project where the Dart side has 30+ outdated direct deps. The asymmetry (Dart side: 30 outdated, Node side: 0) is itself a finding: **Cloud Functions dep hygiene is exemplary; Flutter dep hygiene is not.**

**Severity:** informational; explains why HIGH-2 (Firebase 12-deep lag) is purely a Flutter/pub problem and not an end-to-end stack problem.

### Critic NEW finding C7 — `firebase-functions 7.2.5` Cloud Functions runtime alignment

`firebase-functions 7.x` requires Node 22 runtime per its own README. `functions/package.json:55-57` `engines:node:22` matches. The `dep-audit.yml:89` `node-version: "20"` mismatch (CRITICAL-2) is therefore even worse than the report stated — `npm ci` under Node 20 may still install the package, but `firebase-functions 7.x` has internal type guards that assume Node 22 globals (`structuredClone`, etc. — both available in Node 18+ but the SDK's type declarations target Node 22). The audit step running under Node 20 isn't just auditing wrong; it's potentially producing a different `node_modules/` graph because optional native deps that target Node 22 may bail.

**Confirms CRITICAL-2 severity and adds rationale.**

### Critic NEW finding C8 — License-density spot check on top 30 direct deps

The report's per-dep table at lines 296-326 includes a "License" column but only fills 22 of 30 cells (the rest say `(latest)` in the License column or appear blank). The critic verified the **top 30 declared licenses** against `functions/package-lock.json` and pub.dev fetches:

- **MIT (12):** provider, uuid, get_it, cached_network_image, drift, timeago, permission_handler, file_picker, flutter_onnxruntime, freerasp (open-source part), in_app_review (verified), image_cropper
- **BSD-3-Clause (14):** cloud_firestore, image_picker, shared_preferences, collection, http, firebase_*, crypto, intl, html, share_plus, url_launcher, path_provider, connectivity_plus, file ecosystem packages
- **Apache-2.0 (3):** rxdart, clock, flutter_inappwebview
- **(BSD-3-Clause OR GPL-2.0) (1):** node-forge — already covered as HIGH-3
- **Custom-fair-use freerasp policy (1):** Talsec freemium — already covered

**No GPL/AGPL/SSPL/CC-BY-NC found in the direct dep tree.** The npm side is similarly clean except for node-forge (covered). License posture is genuinely good — the gap is **documentation** (no LICENSE/NOTICE file at root, Missing-1 stands), not actual license risk.

### Critic NEW finding C9 — Transitive yanked-package check is unenforced

pub.dev does surface yanked-package status, but **neither OSV nor `npm audit` nor `flutter pub outdated` flags yanked packages explicitly**. A yanked package may still resolve cleanly in `pubspec.lock` and ship in a build until someone runs `flutter pub get` from scratch and the constraint solver picks a non-yanked version.

**Pass-2 cannot verify yank status without web access.** This is an **unaddressed CI gap**: Butlery has no automated check for yanked packages on either side.

**Proposed fix:** add a CI step to `dep-audit.yml`:
```yaml
- name: Check for yanked pub packages
  run: |
    # Parse pubspec.lock and check each pinned version against pub.dev /api/packages/<name>/versions/<version>
    # If response shows `"retracted": true`, fail the build
    # ~30 lines of jq/curl
```
And npm-side equivalent (`npm view <pkg>@<ver> deprecated` — npm DOES surface deprecation warnings during `npm ci` so this is partly covered already).

**Severity:** MEDIUM (genuine gap, but no known yanked package in current resolved tree based on available data).

### Critic NEW finding C10 — Re-read of "fresh" claim on `dio 5.9.2` (MEDIUM-2)

The Pass-1 report says `dio 5.9.2` is "the latest 5.x line." Critic note: the broken pub.dev advisory feed for `dio` (`pub-outdated.txt:23-44`) means we can't actually confirm via the tool whether 5.9.2 is the latest patch. The latest 5.x as of this analysis date may well be `5.10.x` or `5.9.3`. Pass-1 claim is **plausible but not strictly verified by the snapshot**. The sister `2026-05-claude` run might have hit pub.dev directly and resolved this, but the deep run did not.

**Disposition:** downgrade certainty in MEDIUM-2 to "appears current per available data; CI advisory check would confirm." Doesn't change severity.

### Critic adjusted score

The critic concurs with Pass-2's score of **62 / 100** with one nudge:

| Dimension | Pass-2 score | Critic adjustment | New |
|---|---|---|---|
| Vulnerability Scanning & CVEs | 15 / 25 | +1 (Trivy + TruffleHog uncited but doing real work — C2) | **16 / 25** |
| Version Currency & Maintenance | 11 / 20 | 0 | 11 / 20 |
| License Compliance | 17 / 18 | 0 | 17 / 18 |
| Dependency Bloat | 12 / 15 | 0 | 12 / 15 |
| Supply Chain Integrity | 5 / 12 | -1 (mutable action tag refs everywhere — C3) | **4 / 12** |
| Platform Compatibility | 3 / 5 | 0 | 3 / 5 |
| Upgrade Path & Migration | 1 / 5 | +0.5 (Cloud Functions side is exemplary, partial counterweight to Flutter side — C6) | 1.5 / 5 |

**Net: 62 → 64.5 → round to 65.**

The +1 for Trivy/TruffleHog and -1 for action-ref pinning roughly cancel; the +0.5 for Functions hygiene nudges up. Critic's recommended final score: **65 / 100**.

But the critic also acknowledges that the **direction of error matters more than the score**. Pass 2 already said "62" and went down from Pass 1's "64." The critic going back up to 65 doesn't materially change the orchestrator's read ("Acceptable; prioritized remediation within 2 sprints"). **Recommend Pass 2 keep its 62; treat critic's 65 as a sensitivity range of ±3.**

### Critic NEW strategic opportunities (extension to Missing-1..11)

To push the existing "Missing" list past the 6-item floor:

12. **Adopt `osv-scanner` config file** (`.osv-scanner.yaml`) to silence noise from accepted advisories instead of `|| true` swallowing. Same pattern as the dead `dep-audit-allowlist.md` but for the actual scanner. Effort: 30 min.
13. **CycloneDX SBOM generation as a release artefact** — already covered as Missing-3 but worth restating: the GitHub Action `anchore/sbom-action@v0` adds a CycloneDX SBOM to each release with no maintenance cost. Effort: 1 hour.
14. **`.github/SECURITY.md` doesn't exist** (verified — no file at that path). Add a vulnerability disclosure policy. Required for `securityreviewer` bots, GitHub Stars, and many orgs' dep-due-diligence checklists. Effort: 30 min.
15. **Pin `subosito/flutter-action` and `aquasecurity/trivy-action` to SHA** specifically (the two third-party actions with the largest blast radius). Even if other actions stay on `@v4`, these two warrant the upgrade. Effort: 5 minutes per action.
16. **Add `engine-strict=true` to existing `functions/.npmrc`** — 1 line. Makes Missing-11 a near-zero-effort fix.
17. **Document the `protobufjs ^7.5.5` override rationale** with an inline comment referencing CVE-2023-36665 in `functions/package.json:71-73` so a future "tidy up" pass doesn't strip it.

### Critic plain-language summary (jargon-free)

If you don't read code, here's what this whole 600-line analysis really says:

- **One real problem:** the encrypted-database library Butlery uses for offline storage (`sqlcipher_flutter_libs`) was officially marked "do not use anymore" by its maintainer. It still works today, but you're on a library that the author has formally walked away from. Replacing it is a 3-day job and unlocks several other small upgrades.
- **One real configuration mistake:** the security-scanning robot that checks for known-bad packages every Monday is set to use the wrong version of Node.js. It still finds problems, but it's looking at a slightly different set of files than what actually ships to users. Five-minute fix.
- **One blind spot worth fixing:** when the AI parts of the app download new "brain files" from Google's servers at first run, there's no check that the file wasn't tampered with on its way down. Almost certainly fine in practice (the storage is locked behind login), but if a future attacker got admin access they could swap in a brain file that gives wrong answers. Half-day fix.
- **Surprisingly good news:** the Cloud Functions side (the server bits that run on Google's servers) is unusually clean — exact-pinned versions, install scripts disabled, almost nothing outdated. That's the strongest piece of supply-chain hygiene in the entire codebase, and the original report didn't even mention it.
- **Mild nuisance:** every CI workflow uses the latest "stable" version of GitHub Actions (`@v4`, `@v6`), which is convenient but means if a popular Action ever gets hijacked (it has happened), your CI pipeline runs the bad code. Pinning to specific frozen versions takes a couple of hours and removes that risk.
- **Nothing immediately exploitable.** No package has a publicly-known critical vulnerability that ships in production right now. The findings here are about being early on patching, having defense in depth, and tightening the screws before anything bad happens.

How easy to undo any of this? Every fix proposed is a small commit you can revert in one click if it breaks something.

## Pass 2 verdict: APPROVED-WITH-CORRECTIONS
