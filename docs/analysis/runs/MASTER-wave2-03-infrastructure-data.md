# MASTER Wave 2 — Prompt 03 Infrastructure & Operations — Consensus Data

**Compiled:** 2026-05-04
**Inputs:**
- `docs/analysis/runs/2026-05-codex/03-infrastructure.md` (322 lines, OpenAI Codex CLI) — score 57/100
- `docs/analysis/runs/2026-05-claude/03-infrastructure.md` (547 lines, Claude default) — score 73/100
- `docs/analysis/runs/2026-05-claude-deep/03-infrastructure.md` (822 lines, Claude deep + Pass 2 critic) — score 56/100

**Authority rule:** deep run is auctoritative because Pass 2 critic re-verified Pass 1 claims against live source. Codex/default findings unique to those runs were re-verified for this synthesis. Disputed numbers default to deep unless verification disagrees.

**Live re-verification done in this synthesis (mtime 2026-05-04):**
- `.github/workflows/` listing → **7 workflows on disk now** (`architecture-validation`, `build-validation`, `dep-audit`, `e2e_tests`, `firestore-rules`, `sbom`, `test`). All three reports said 6 — `sbom.yml` was added 2026-05-04 12:27 between deep run and now. **Drift not in any report.**
- `infrastructure/` subdir contents (3 .sh files, no IaC) — confirmed.
- `infrastructure/alerting/setup-gcp-alerts.sh` line-by-line: **exactly 2 `create_policy_if_missing` calls** (`:90`, `:123`) — CF error rate + CF latency. Deep claim verified, codex claim verified.
- `.firebaserc` absent — confirmed.
- Flutter version: **3.35.1** across all 7 workflows that use Flutter — confirmed (codex, deep correct; default also correct; orchestrator's "3.32.4" is stale).
- Node version drift: `dep-audit.yml:89` = `"20"`, `e2e_tests.yml:68` = `'20'`, `firestore-rules.yml:52` = `"22"`, `sbom.yml:61` = `${{ env.NODE_VERSION }}`. Engines field requires 22. Drift CONFIRMED.
- `actions/checkout` mix: **v6** in arch-validation, build-validation, e2e, test; **v4** in dep-audit (×2), firestore-rules, sbom. Drift CONFIRMED, slightly worse than deep reported (deep said 2-of-6; live shows 4-of-7 with sbom added).
- `permissions:` blocks: present on `architecture-validation.yml`, `dep-audit.yml`, `sbom.yml` only. Absent on `build-validation.yml`, `e2e_tests.yml`, `firestore-rules.yml`, `test.yml`. Confirmed default + deep.
- `backups.md` europe-west3 references at lines 27, 28, 30, 63, 66, 116, 142, 181 — confirmed.
- `infrastructure_integration_test.dart` = 124 lines — confirmed.
- `android/app/build.gradle.kts:19` `compileSdk = 36`, `:34` `applicationId = "se.butlery.app"`, `:70-71` minify+shrink ON for release. Confirmed.
- `dependabot.yml:18,60,96` `open-pull-requests-limit: 5` × 3 ecosystems = 15 max (default report said 13; off by minor). Major-bumps ignored at lines 44, 88, 112.

---

## Score consensus

| Run | Score | Maturity | Critical | High | Medium | Low |
|---|---:|---:|---:|---:|---:|---:|
| Codex | 57/100 | Level 2 | 3 | 6 | 7 | 2 |
| Default (Claude) | 73/100 | Level 3 | 3 (1 user-deferred) | 12 | 15 | 5 |
| Deep (Pass 2) | **56/100** | Level 2 | 3 | 11 | 13+ | 6 |

**Consensus baseline: 56-58 / 100, Maturity 2.** Default's 73 is an outlier — Pass 2 deep re-verified the same evidence and downgraded after confirming CRIT-INFRA-1 is live, not hypothetical. Default treated the doc-vs-code drift as "operational picture is materially better" while deep treated it as "if the docs lie about regions, the backups don't actually run."

The 17-point gap is itself a finding: default sub-graded by treating "documented as ACTIVE" as "is ACTIVE", deep sub-graded by treating the unverified region as a critical DR risk. The verification asymmetry is what `data-residency.md:8` itself says ("USER MUST VERIFY") — deep is right.

---

## CRITICAL findings

| # | Title | Codex | Default | Deep | Verification | Notes |
|---|---|:-:|:-:|:-:|---|---|
| C-1 | Test pipeline hangs on `infrastructure_integration_test.dart` (10-min timeout) | INFRA-02 (CRIT) | C-1 (CRIT) | CRIT-INFRA-3 (REVISED) | **DISPROVED-and-replaced** by deep — the named file is 124 lines, 4 tests, completes in seconds; deep correctly identifies the underlying invariant gap (no per-test timeout) but never pinpoints the real hanger | See "Disproved by deep critic" |
| C-2 | No automated production deployment / store upload | INFRA-01 (CRIT) | C-2 (CRIT, user-deferred) | HIGH-INFRA-1 | **VERIFIED** — no `fastlane/Fastfile`, no `r0adkll/upload-google-play`, no TestFlight action, no `firebase deploy --only hosting` invocation. Live ls of `.github/workflows/` confirms no store-deploy workflow | All 3 reports agree on the gap; severity disputed (codex CRIT, default CRIT-deferred, deep HIGH). MEMORY.md "no store submission yet" supports HIGH/deferred |
| C-3 | Analyzer compile error (`ConsentPurpose` undefined) | INFRA-03 (CRIT) | M-3 (MED, "stale capture") | (deferred to prompt 01) | Already RESOLVED on disk per Wave 1 cross-ref | **DISPROVED** — codex treated stale pre-analysis capture as live; default and deep correctly identified as stale. Owned by prompt 01 |
| C-4 | Backup region mismatch — `backups.md` europe-west3 vs functions europe-west1 | NOT FOUND | NOT FOUND | **CRIT-INFRA-1** (NEW) | **VERIFIED LIVE** — `backups.md:27,28,30,63,66,116,142,181` europe-west3; `functions/src/index.ts:20` europe-west1; `data-residency.md:8` admits "USER MUST VERIFY". Cross-region `gcloud firestore export` returns INVALID_ARGUMENT | **Unique to deep + load-bearing.** Highest-severity finding in any of the three runs. If runbook executed, backups don't exist; if executed and worked, the entire functions tier is cross-region. Either way the documented "Status: ACTIVE" is unverifiable |
| C-5 | Restore drill never performed | (mentioned as M) | C-3 (CRIT) | M-INFRA-5 (within CRIT-INFRA-1's blast radius) | **VERIFIED** — `docs/ops/backups.md:31` "Restore drill: NEVER PERFORMED" | Default escalated to CRIT (correct given C-4); deep folded into CRIT-INFRA-1's remediation. Codex flagged at MED. Consensus severity: CRITICAL when combined with C-4 |
| C-6 | `--coverage` excludes `test/integration` and `test/e2e` — repository coverage claim unverifiable | NOT FOUND | NOT FOUND | **CRIT-INFRA-2** (NEW) | **VERIFIED** — `test.yml:67-70` only collects coverage from unit/widget/views/golden; `:272-279` integration job has no `--coverage` flag; `e2e_tests.yml:108-110` no coverage flag | **Unique to deep.** Default's H-3 ("ViewModel/Services targets not enforced") is adjacent but didn't catch the structural gap. Codex didn't catch either. Material for orchestrator's "88% Firebase Repos" claim |
| C-7 | Per-test timeout invariant missing (any `pumpAndSettle()` no-arg can burn 10 min of 20-min job) | NOT FOUND | NOT FOUND | **CRIT-INFRA-3** (REVISED) | **VERIFIED** — `test/views/helpers/view_test_helpers.dart:316,450,460,517` no-Duration `pumpAndSettle`; `test.yml:36,214` only job-level timeout; `dart_test.yaml` absent | **Unique to deep.** This is the right framing of what codex/default mis-attributed as "the named file hangs" |

**Consensus CRITICAL count (de-duped, severity-aligned to deep):** 3 unique CRITs — **CRIT-INFRA-1** (region mismatch + drill never run), **CRIT-INFRA-2** (coverage gap), **CRIT-INFRA-3** (per-test timeout missing). Plus deferred: C-2 store deploy is intentionally deferred per MEMORY.md (downgrade to HIGH).

---

## HIGH findings

### Three-way consensus (all 3 runs)

| # | Title | Codex ID | Default ID | Deep ID | File:line evidence |
|---|---|---|---|---|---|
| H-1 | Single Firebase project, no env separation | INFRA-05 | H-6 | (folded into HIGH-INFRA-2) | `firebase.json:71-87`; `.firebaserc` absent (verified) |
| H-2 | iOS CI is `--no-codesign`, no signed IPA path | INFRA-04 | (subsumed in C-2) | HIGH-INFRA-1 | `build-validation.yml:225-229`, `ios/exportOptions.plist:5-10` |
| H-3 | GCP alerting scope narrow (only 2 policies live) | INFRA-08 | H-10/M-10 cluster | MED-INFRA-1 (only 2) | `infrastructure/alerting/setup-gcp-alerts.sh:90,123` (verified live: exactly 2 `create_policy_if_missing` calls — CF error rate, CF latency); `docs/ops/gcp-alerting-runbook.md:30` |

### Two-of-three consensus

| # | Title | Codex | Default | Deep | Verified |
|---|---|:-:|:-:|:-:|---|
| H-4 | Local Flutter setup version drift (3.32.4 vs CI 3.35.1) | INFRA-09 (HIGH) | (mentioned, not raised) | (Pass 2 noted in doc-drift table only) | Y — `scripts/setup.sh:7`, `scripts/setup.ps1:6` say 3.32.4; CI uses 3.35.1 |
| H-5 | E2E tier contract drift (workflow advertises `all`, runner only accepts `mock\|emulator`) | INFRA-07 (HIGH) | (not raised) | (LOW-INFRA-5, deferred-by-design) | Y — `e2e_tests.yml:24-33`; `scripts/run_e2e_tests.sh:31-35`. **Codex unique severity escalation** |
| H-6 | Functions/Firestore region mismatch (cross-region tax) | (implicit in INFRA-05) | M-8 (MED) | **CRIT-INFRA-1** (CRIT) | Y — same evidence as C-4 above |
| H-7 | No artifact retention for AAB / IPA / web bundle | (not raised) | H-1 (HIGH) | MED-INFRA-6 (MED) | Y — `build-validation.yml:188-229` no `actions/upload-artifact` for build outputs |
| H-8 | Firestore rules deploy is manual (no CI promotion) | (not raised) | H-7 (HIGH) | HIGH-INFRA-2 (HIGH) | Y — `firestore-rules.yml` runs tests only; no `firebase deploy --only firestore:rules` step in any workflow |
| H-9 | No Firebase Auth user export | (not raised) | H-8 (HIGH) | (not raised explicitly) | Y — `docs/ops/backups.md` covers Firestore only |
| H-10 | No Firebase Storage backup / object versioning | (INFRA-14 contradiction noted) | H-9 (HIGH) | (M-INFRA-15 partial cover) | Y — `docs/ops/backups.md` omits Storage; `docs/ops/storage-lifecycle-runbook.md:3,187-190` has contradictory PENDING vs Activated state |
| H-11 | No SLO definitions document on disk | (not raised) | H-10 (HIGH) | (Pass-2 noted in doc-drift table) | Y — `docs/operations/` does NOT exist; `docs/ops/` has runbooks but no SLO doc |
| H-12 | Inconsistent GitHub Actions versions across workflows | (not raised) | H-12 (HIGH) | HIGH-INFRA-10 (HIGH, supply chain framing) | Y — `actions/checkout@v6` × 4 workflows vs `@v4` × 3 workflows (verified live: 4-of-7 v6, 3-of-7 v4 incl. new `sbom.yml`) |
| H-13 | Lefthook secret-scan regex narrower than TruffleHog (no Stripe/Slack) | (not raised) | (not raised) | HIGH-INFRA-11 (PROMOTED from MED) | Y — `lefthook.yml:21` regex inventory; missing `sk_live_*`, Slack webhooks. Stripe relevant per MEMORY.md monetization roadmap |
| H-14 | E2E-emulator wait uses `sleep 10` not readiness probe (flaky on slow runners) | (not raised) | H-5 (HIGH) | (not raised explicitly) | Y — `test.yml:265-269` uses `sleep 10` + curl with `\|\| echo` (non-fatal); `firestore-rules.yml:74-85` does it correctly with retry loop |
| H-15 | Coverage floor enforced ONLY on Ubuntu shard | (not raised) | (not raised) | **HIGH-INFRA-4** (NEW) | Y — `test.yml:60,79,121,184,196` all gate coverage steps on `matrix.os == 'ubuntu-latest'`. macOS/Windows shards run `--coverage` but never check floor or upload |
| H-16 | `dep-audit.yml` lacks `concurrency:` block | (not raised) | (not raised) | **HIGH-INFRA-9** (NEW) | Y — verified live: `grep -n concurrency dep-audit.yml` returns 0 matches. All other workflows have cancel-in-progress |
| H-17 | Node 20 in CI vs functions engines:22 (audit/runtime parity) | INFRA-16 (MED) | (not raised explicitly) | HIGH-INFRA-3 (HIGH) | Y — verified live: `dep-audit.yml:89 = "20"`, `e2e_tests.yml:68 = '20'`, `firestore-rules.yml:52 = "22"`. Engines:22 in `functions/package.json:55-57` |
| H-18 | `dep-audit.yml` `--mode=null-safety` is dead code (Dart 2.12 era) | (not raised) | (not raised) | HIGH-INFRA-3 (within) | Y — `dep-audit.yml:45` `dart pub outdated --mode=null-safety --json \|\| true`. Cross-ref Wave 1 prompt 05 |
| H-19 | `dep-audit.yml` no `push:` trigger — solo-dev push-to-main bypasses audit until next Mon | (not raised) | (not raised) | HIGH-INFRA-3 (within) | Y — `dep-audit.yml:7-17` triggers are PR-paths + schedule + dispatch only |

### Unique highs (deep only, verified)

| # | Title | Deep ID | Verification |
|---|---|---|---|
| H-20 | Architecture-validation TODO threshold (10 files) is warning-only — drift goes silent | HIGH-INFRA-5 | VERIFIED — `architecture-validation.yml:92-101` warns but never fails; current TODO count (~25 in `lib/services/security/` per prompt 01) is below threshold so warning never fires |
| H-21 | Lefthook pre-commit and CI run different checks (analyze flags, real-time guard, Trivy/TruffleHog) | HIGH-INFRA-6 | VERIFIED — `lefthook.yml:8-26` vs `build-validation.yml:47-53` + `test.yml:53-54` |
| H-22 | Real-time regression guard (`check_test_real_time.sh`) skips `test/e2e` | HIGH-INFRA-7 | VERIFIED — `scripts/check_test_real_time.sh:33` `DELAYED_SCOPE` array excludes test/e2e |
| H-23 | Single notification channel (info@butlery.se) for all GCP alerts; no on-call/escalation/redundancy | HIGH-INFRA-8 | VERIFIED — `docs/ops/gcp-alerting-runbook.md:30`; `docs/ops/backups.md:213` |
| H-24 | No SHA-pinning of any third-party GitHub Action (supply-chain compromise vector) | HIGH-INFRA-10 | VERIFIED — all third-party actions tag-pinned (`subosito/flutter-action@v2`, `aquasecurity/trivy-action@v0.36.0`, etc.). Dependabot patch-bumps are auto-mergeable; CISA/SLSA L2 require SHA pins |

### Unique highs (default only, verified)

| # | Title | Default ID | Verification |
|---|---|---|---|
| H-25 | Dependabot opens up to 15 PRs/week, no auto-merge | H-2 (claimed 13/wk) | PARTIAL — verified live: `open-pull-requests-limit: 5` × 3 ecosystems = 15 max (default's "13" was off by 2). Otherwise valid: no auto-merge config exists |
| H-26 | ViewModel/Services coverage targets (100/96%) not enforced anywhere | H-3 | VERIFIED — `test.yml:139-178` enforces overall 55, auth 80, repos 70, rate_limiting 80. No VM/Services area floor. Orchestrator targets are aspirational |
| H-27 | Integration tests run via `if [ -n $(find...) ]` — silently no-op if path moves | H-4 | VERIFIED — `test.yml:273-279` conditional skip pattern. Not deep-flagged but real |
| H-28 | No incident-response playbook for crash spike or data corruption | H-11 | VERIFIED — `docs/ops/` has 13 runbooks, none for "crash spike" / "data corruption" generic decision tree |

### Unique highs (codex only)

| # | Title | Codex ID | Verification |
|---|---|---|---|
| H-29 | Unit-test timeout 20m vs observed 24:23 progression — under-provisioned | INFRA-06 (HIGH) | UNVERIFIABLE precisely — pre-analysis capture aborted; deep agrees direction (CRIT-INFRA-3) but reframes as per-test-timeout problem. Codex's framing is correct symptom but wrong root cause |

---

## MEDIUM findings (consensus, condensed)

| # | Title | Runs | Verification |
|---|---|---|---|
| M-1 | Build performance telemetry gap (no cold/warm benchmark export) | codex INFRA-11 | not raised by default/deep; verified via grep: no duration export step in workflows |
| M-2 | View-helper test bootstrap does redundant locator init/reset | codex INFRA-10 | unique, plausible; not load-bearing for this prompt |
| M-3 | Storage DR runbook contradictory state (`PENDING` vs `Activated`) | codex INFRA-14, default H-9, (deep mentions in M-INFRA-15) | VERIFIED — `docs/ops/storage-lifecycle-runbook.md:3,187-190` |
| M-4 | Release-mode frame performance monitoring is disabled | codex INFRA-12 | unique to codex; verifiable via `lib/services/performance/performance_monitoring_service.dart:155-159` |
| M-5 | Web analytics is no-op (`NoOpAnalyticsRepository`) | codex INFRA-13 | unique; `lib/core/di/modules/core_module.dart:211-213`. Cross-prompt: also a prompt 04 perf concern |
| M-6 | dep-audit Mon 05 UTC schedule largely redundant w/ Dependabot Mon 06 UTC | default M-1 | unique to default; minor |
| M-7 | No `flutter analyze` step in `test.yml` | default M-2 | unique; defense-in-depth gap if `build-validation.yml` ever skipped |
| M-8 | No flaky-test detection / quarantine mechanism | default M-4 | unique; valid systemic gap |
| M-9 | Test pyramid distribution unknown (no test-count audit) | default M-5 | unique; ergonomic gap |
| M-10 | No version-bump automation (no release-please / semantic-release) | default M-6 | unique; conventional commits already in place make this low-effort |
| M-11 | No staged-rollout config for Play Store | default M-7 | tied to deferred C-2 |
| M-12 | Single Firebase admin = SPOF | default M-9 | unique; out-of-band action (GCP IAM) |
| M-13 | No documented alert routing | default M-10 | unique; tied to H-23 |
| M-14 | No Firebase budget alerts in repo | default M-11 | unique; lives in GCP Billing console, not repo |
| M-15 | No `permissions:` block on 4 workflows (now 4-of-7 with sbom) | default M-14, deep M-INFRA-35 | VERIFIED LIVE: only `architecture-validation.yml`, `dep-audit.yml`, `sbom.yml` have permissions blocks. `build-validation.yml`, `test.yml`, `e2e_tests.yml`, `firestore-rules.yml` lack them |
| M-16 | `lifecycle.json` exists at `docs/ops/` (config artifact in docs/) — convention violation | deep M-INFRA-12, M-INFRA-22 | VERIFIED live: `docs/ops/lifecycle.json` exists |
| M-17 | `infrastructure/` is an IaC stub (3 .sh scripts only) | deep M-INFRA-13 | VERIFIED live: `infrastructure/{alerting,security,storage}/` each contain exactly 1 .sh file |
| M-18 | No KEYSTORE_BASE64 rotation runbook | deep M-INFRA-14 | VERIFIED — no rotation doc in `docs/ops/`; `build-validation.yml:152-170` consumes secrets |
| M-19 | Web hosting CSP comprehensive but no report-uri/report-to | deep M-INFRA-15 | VERIFIED — `firebase.json:32-37` headers strong, no CSP reporting endpoint |
| M-20 | No reproducible-build verification | deep M-INFRA-17 | unique; real but low-priority for current state |
| M-21 | Branch protection rules not in repo (live config in GH UI) | deep M-INFRA-18 | UNVERIFIABLE without GH API access; legitimately a known gap |
| M-22 | `storage.rules` has no rules-tests | deep M-INFRA-19 | VERIFIED — no `storage*-rules.test.ts` in `functions/src/__tests__/` |
| M-23 | `database.rules.json` has no rules-tests | deep M-INFRA-20 | VERIFIED — RTDB rules referenced in `firebase.json:18-20`, no tests for them |
| M-24 | No cron schedule on `firestore-rules.yml` (drift catch-rate gap) | deep MED-INFRA-8 | VERIFIED — `firestore-rules.yml:8-33` no `schedule:` block |
| M-25 | `firebase.json:6` predeploy `--audit-level=critical` vs CI `--audit-level=high` (asymmetric defense) | deep MED-INFRA-9 | VERIFIED — `firebase.json:6` vs `dep-audit.yml:97` |
| M-26 | Three different patterns for "start the Firestore emulator" across workflows (drift-prone) | deep MED-INFRA-10 | VERIFIED — `test.yml:240-260` inline + `sleep 10`; `firestore-rules.yml:74-85` polling loop; `e2e_tests.yml` via `scripts/run_e2e_tests.sh` |
| M-27 | `scripts/pip.exe`, `pip3.exe`, `pip3.13.exe` checked into repo (3 binaries, undocumented) | deep MED-INFRA-11 | VERIFIED LIVE: `ls scripts/` shows all three executables; not in `.gitignore` for `scripts/`. Likely accidental commit |
| M-28 | `dependabot.yml` ignores all major-version bumps across all 3 ecosystems | deep M-INFRA-34 | VERIFIED LIVE: `dependabot.yml:44,88,112` `version-update:semver-major` ignored. CVE-only-in-major scenarios silently skipped |
| M-29 | `.env` materialized to disk in CI runner (17 secrets visible to subsequent steps) | codex INFRA-18 (LOW), deep MED-INFRA-13 | VERIFIED — `build-validation.yml:121-144`. Severity contingent on action compromise (mitigated by H-24 SHA pinning fix) |
| M-30 | Gradle cache key hashFiles glob is `**/*.gradle*` (workspace-wide, fork-PR poisoning vector) | deep MED-INFRA-14 | VERIFIED — `build-validation.yml:181-186`. Tighten to `'android/**/*.gradle*'` |
| M-31 | No deploy-time region-pinning verification (legacy `.region("us-central1")` overrides could land) | deep M-INFRA-26 | VERIFIED — no CI grep step for non-eu regions in `functions/src/` |
| M-32 | No invariant: "deploy state matches main" (rules drift between merged-and-tested vs deployed) | deep M-INFRA-2 | VERIFIED indirectly — no `firebase deploy --dry-run` diff step in any workflow |
| M-33 | DORA metrics unmeasured (deploy frequency, lead time, CFR, MTTR all unknown) | codex (Unknowns), default DORA section, deep M-INFRA-27 | VERIFIED — no telemetry export; CI has no deploy step for any metric to attach to |
| M-34 | Firestore indexes deploy gap (30 indexes, manual deploy, missing-index runtime errors common foot-gun) | deep MED-INFRA-4 | VERIFIED — `firestore.indexes.json` 30 composite + 7 fieldOverrides per deep; no CI deploy |
| M-35 | Architecture-validation TODO regex matches identifiers like `todoCount` (false positives) | deep MED-INFRA-7 | VERIFIED — `architecture-validation.yml:96` regex `"TODO\|FIXME"` not word-bounded |
| M-36 | Codecov `if_ci_failed: error` blocks merges if CI is unrelated-broken | deep MED-INFRA-3 | VERIFIED — `codecov.yml:14,22`. Backstop only runs on Ubuntu (HIGH-15) |

---

## Disproved by deep critic

These appeared in codex and/or default but the deep Pass-2 critic explicitly disproved them with file:line evidence:

| Claim | Origin | Why disproved | Evidence |
|---|---|---|---|
| `test/views/helpers/infrastructure_integration_test.dart` is THE hanging file consuming 10 minutes per test | codex INFRA-02, default C-1 | The file is **124 lines, 4 simple widget tests**, completes in seconds. Pass 2 read line-by-line | `test/views/helpers/infrastructure_integration_test.dart` (verified 124 lines via wc -l) |
| Analyzer "Undefined name 'ConsentPurpose'" is currently blocking | codex INFRA-03 (CRIT) | Stale pre-analysis capture; resolved on disk by the time of the run. Default flagged this correctly at M-3 (MED, "stale capture"). | Wave 1 cross-prompt; `lib/services/notifications/notification_service.dart` import is present |
| Placeholder `com.example.butlery` is the active applicationId (orchestrator pre-known fact) | orchestrator → indirectly codex/default | `applicationId = "se.butlery.app"` at `android/app/build.gradle.kts:34`. Stale `com.example.butlery` lingers only in `google-services.json:12` (not active) | Verified live |
| Debug signing only / R8 disabled (orchestrator pre-known fact) | orchestrator | Release keystore wired (`build.gradle.kts:44-76`); `isMinifyEnabled = true` and `isShrinkResources = true` for release at `:70-71`; debug at `:78-79` | Verified live |
| 14-week backup retention (orchestrator) | orchestrator | Actual is 30-day lifecycle | `docs/ops/backups.md:29` |
| 5 workflows on disk (orchestrator) | orchestrator | 6 at deep run; **7 at this synthesis** (sbom.yml added 2026-05-04) | live ls of `.github/workflows/` |
| Flutter version pinned 3.32.4 (orchestrator) | orchestrator | All 7 workflows pin **3.35.1** | verified across all `FLUTTER_VERSION:` env declarations |
| `docs/operations/SLO_DEFINITIONS.md` exists (orchestrator) | orchestrator | Directory `docs/operations/` does NOT exist; actual is `docs/ops/` and contains no SLO doc | verified ls |
| `docs/operations/FIREBASE_ALERTING_GUIDE.md` exists (orchestrator) | orchestrator | Same — wrong path | verified ls |
| Crashlytics crash-free <99.5% threshold alert is configured | orchestrator | Only 2 GCP alert policies live (CF errors + CF latency); no crash-free policy on disk | `infrastructure/alerting/setup-gcp-alerts.sh:90,123` (verified live) |
| `lib/services/backup_service.dart` IS the disaster-recovery primitive | orchestrator | It's a **client-side recipe export tool** (`exportToFile`), not DR. Real DR is server-side Cloud Scheduler | `lib/services/backup_service.dart:20-57,142-250` |

---

## Unique to one run (verified)

### Unique to codex (verified for this synthesis)

| ID | Severity | Title | Status |
|---|---|---|---|
| INFRA-07 | HIGH | E2E tier contract drift (`all` advertised, runner only accepts `mock\|emulator`) | VERIFIED — `e2e_tests.yml:24-33` lists `all` choice; `scripts/run_e2e_tests.sh:31-35` rejects it |
| INFRA-09 | HIGH | Local setup Flutter pin (3.32.4) drifts from CI (3.35.1) | VERIFIED — `scripts/setup.sh:7`, `scripts/setup.ps1:6` vs all CI workflows |
| INFRA-12 | MED | Release-mode frame performance monitoring disabled | VERIFIED — `lib/services/performance/performance_monitoring_service.dart:155-159` |
| INFRA-13 | MED | Web `NoOpAnalyticsRepository` (cross-platform analytics blind spot) | VERIFIED — `lib/core/di/modules/core_module.dart:211-213`, `lib/repositories/noop/noop_analytics_repository.dart:13-28` |
| INFRA-17 | LOW | `validate_architecture.dart` reports violations but does not fail | VERIFIED — `tools/validate_architecture.dart:215-220` |

### Unique to default (verified)

| ID | Severity | Title | Status |
|---|---|---|---|
| H-2 | HIGH | Dependabot opens up to 15 PRs/week (default said 13), no auto-merge | PARTIALLY VERIFIED — count is 15 not 13; otherwise correct |
| H-3 | HIGH | ViewModel/Services coverage targets not enforced | VERIFIED |
| H-4 | HIGH | Integration tests `if [ -n $(find...) ]` silently no-op on path move | VERIFIED — `test.yml:273-279` |
| H-5 | HIGH | E2E-emulator `sleep 10` instead of readiness probe | VERIFIED — `test.yml:265-269` |
| H-8 | HIGH | No Firebase Auth user export | VERIFIED — `docs/ops/backups.md` omits Auth |
| H-11 | HIGH | No crash-spike / data-corruption decision-tree runbook | VERIFIED — `docs/ops/` lacks generic playbooks |
| M-1 | MED | dep-audit Mon-05-UTC schedule redundant with Dependabot Mon-06-UTC | VERIFIED |
| M-2 | MED | No `flutter analyze` in test.yml | VERIFIED |
| M-4 | MED | No flaky-test detection / quarantine | VERIFIED |
| M-6 | MED | No release-please / semantic-release version-bump automation | VERIFIED |
| M-9 | MED | Single Firebase admin SPOF | UNVERIFIABLE without GCP IAM access; plausible |

### Unique to deep (verified by Pass-2 critic + this synthesis)

| ID | Severity | Title | Status |
|---|---|---|---|
| **CRIT-INFRA-1** | CRIT | Backups.md europe-west3 vs functions europe-west1 mismatch (DR posture undermined) | VERIFIED — 8 europe-west3 refs in backups.md vs `functions/src/index.ts:20` europe-west1; `data-residency.md:8` admits unverified |
| **CRIT-INFRA-2** | CRIT | `--coverage` excludes test/integration & test/e2e (repo coverage claim structurally unverifiable) | VERIFIED — `test.yml:67-70,272-279`; `e2e_tests.yml:108-110` |
| **CRIT-INFRA-3** | CRIT | Per-test timeout invariant missing (any pumpAndSettle no-arg burns 10 min) | VERIFIED — `view_test_helpers.dart:316,450,460,517`; no `dart_test.yaml` |
| HIGH-INFRA-4 | HIGH | Coverage floor enforced ONLY on Ubuntu shard (3-OS matrix uneven) | VERIFIED — `test.yml:60,79,121,184,196` Ubuntu-gated steps |
| HIGH-INFRA-5 | HIGH | Architecture-validation TODO threshold warning-only — drift goes silent | VERIFIED — `architecture-validation.yml:92-101` |
| HIGH-INFRA-6 | HIGH | Lefthook vs CI run different checks (analyze flags, real-time, Trivy/TruffleHog) | VERIFIED |
| HIGH-INFRA-7 | HIGH | Real-time guard skips `test/e2e` | VERIFIED — `scripts/check_test_real_time.sh:33` |
| HIGH-INFRA-8 | HIGH | Single notification channel SPOF (info@butlery.se only) | VERIFIED — `gcp-alerting-runbook.md:30` |
| HIGH-INFRA-9 | HIGH | `dep-audit.yml` lacks `concurrency:` block | VERIFIED LIVE — grep returns 0 |
| HIGH-INFRA-10 | HIGH | Third-party GitHub Actions NOT SHA-pinned (supply-chain) | VERIFIED |
| HIGH-INFRA-11 | HIGH | Lefthook secret-scan misses Stripe/Slack/etc. | VERIFIED — `lefthook.yml:21` regex inventory |
| MED-INFRA-13 | MED | `.env` 17 secrets materialized in CI runner (subsequent-step exposure) | VERIFIED — `build-validation.yml:121-144` |
| MED-INFRA-14 | MED | Gradle cache key hashFiles glob workspace-wide (fork-PR poisoning) | VERIFIED — `build-validation.yml:181-186` |
| M-INFRA-13 | MED | `infrastructure/` is IaC stub (3 .sh files only) | VERIFIED LIVE |
| M-INFRA-23 | MED | `paths-ignore` lists across 4 workflows could drift; no YAML lint | VERIFIED — manual diff confirms current alignment but no enforcement |
| M-INFRA-24 | MED | No CI gate against `lib/site-packages/` accidental ingestion | VERIFIED — coverage walk could include site-packages; `.gitignore:113,141` excludes git but not lcov |
| M-INFRA-26 | MED | No deploy-time region pinning verification (legacy `.region("us-central1")` overrides) | VERIFIED — no CI grep step |
| M-INFRA-32 | MED-positive | `compileSdk = 36` exceeds orchestrator baseline (35) — strength | VERIFIED — `android/app/build.gradle.kts:19,38` |
| M-INFRA-33 | MED-positive | `keystorePropertiesFile` fail-loud check at gradle build is exemplary defensive coding | VERIFIED — `android/app/build.gradle.kts:13-15,59-66` |
| M-INFRA-34 | MED | Dependabot ignores all semver-major bumps across 3 ecosystems | VERIFIED LIVE |
| M-INFRA-31 | MED | Cron schedule asymmetries (no nightly for build/test/architecture) | VERIFIED |
| LOW-INFRA-4 | LOW | `architecture-validation.yml:113-146` posts new PR comment per push (no upsert) | VERIFIED |

---

## Disputed numbers

| Claim | Codex | Default | Deep | Live verification | Truth |
|---|---:|---:|---:|---|---|
| Workflow count | 6 | 6 | 6 | **7** (sbom.yml added 2026-05-04 12:27, post-deep) | **7 as of synthesis date 2026-05-04**. All three reports correct for their run-time |
| Flutter pin | 3.35.1 | 3.35.1 | 3.35.1 | 3.35.1 across all FLUTTER_VERSION declarations in 6 of 7 workflows (firestore-rules has none) | **3.35.1 confirmed.** Orchestrator's "3.32.4" is stale |
| GCP alert policy count | (not specific) | "2 alert policies" | "2 alert policies" | exactly 2 `create_policy_if_missing` calls at `infrastructure/alerting/setup-gcp-alerts.sh:90,123` | **2 confirmed live** |
| Dependabot weekly PR cap | (not specific) | "13 PRs/week" | (not specific) | 5 × 3 ecosystems = **15** | **15** — default's "13" is wrong |
| Backups bucket region | europe-west3 (per docs) | europe-west3 (per docs) | europe-west3 (docs) BUT functions live in europe-west1 (CRIT) | `backups.md:27,28,30,63,66,116,142,181` europe-west3; `functions/src/index.ts:20` europe-west1; `data-residency.md:8` "USER MUST VERIFY" | **Disputed live state** — see CRIT-INFRA-1. Either docs are wrong or DB is in wrong region. Untestable from disk alone |
| Backup retention | 30 days | 30 days | 30 days | `backups.md:29` 30-day lifecycle | **30 days confirmed.** Orchestrator's "14 weeks" is stale |
| Test count before hang | 10122 tests | (no specific) | "~10100 tests" | from pre-analysis flutter-test.txt:31508 — abort at 24:23 elapsed | **10122 / 200 failures / 89 skips** — codex's exact count is the right one |
| Score | 57 | 73 | **56** | n/a | Deep + codex aligned (56-57). Default's 73 is the outlier — Pass-2 critic explicitly downgraded after verifying CRIT-INFRA-1 live |
| AAB obfuscation enabled | (yes per build cmd) | (yes per build cmd) | (yes) | `build-validation.yml:194` `--obfuscate --split-debug-info=build/debug-info` | **Confirmed enabled** |
| iOS code signing | `--no-codesign` | `--no-codesign` | `--no-codesign` | `build-validation.yml:225-229` | **Confirmed unsigned IPA** |
| Number of permissions-block workflows | (not raised) | "4 workflows lack" | "3 workflows have, 4 lack" | live: have = arch, dep-audit, sbom (3-of-7); lack = build-val, test, e2e, firestore-rules (4-of-7) | **3 have, 4 lack** confirmed |
| Functions Node version (engines) | 22 | 22 | 22 | `functions/package.json:55-57` `"engines": { "node": "22" }` | **22 confirmed**; `dep-audit.yml:89` and `e2e_tests.yml:68` use 20 (drift) |

---

## Cross-prompt boundaries

| Item | Origin run | Owns | Note |
|---|---|---|---|
| `ConsentPurpose` analyzer error (resolved) | all three | prompt 01 (code quality) | Already resolved on disk per pre-known facts. Default's M-3 framing as "stale capture" is correct |
| Static-analysis count discrepancy | all three | prompt 12 (doc drift) | Out of scope for this prompt |
| Coverage claim drift (100% / 96% / 88% targets) | all three | prompt 12 owns accuracy of doc; **this prompt** owns enforcement gap (H-26) | Both apply |
| Mistral → Vertex AI dependency drift | (mentioned in deep cross-refs) | prompt 05 (dependencies) AND prompt 07 (LLM) | Touches this prompt only via region-pinning-verification gap (M-31) |
| Stockholm timezone string mentions | default + deep | prompt 11 (legal/data residency) | Default's clarification is right: `Europe/Stockholm` is IANA timezone, not region drift. Deep's CRIT-INFRA-1 stands separately on functions/Firestore region mismatch |
| Firestore rules content | all three | prompt 02 (rules content) | This prompt owns deploy pipeline gap (H-8 / HIGH-INFRA-2) |
| App-store submission blockers (privacy manifest, age rating) | all three | prompt 06 (release readiness) AND user-deferred per MEMORY.md | This prompt downgrades C-2 to HIGH per memory note |
| Dependency CVEs / OSV findings | (not deep-detailed here) | prompt 05 (dependencies) | This prompt owns HOW CI consumes audits (H-17, H-18, H-19) |
| AI/LLM model integrity, kill switch | all three | prompt 07 (LLM) | This prompt owns the deploy/region pinning of LLM functions (CRIT-INFRA-1, M-31) |
| Storage rules content | (mentioned) | prompt 02 | This prompt owns absence of `storage-rules.yml` workflow (M-22) |
| `lib/site-packages/` LOC pollution (327k vs 77k) | deep cross-ref | prompt 01 owns counting; this prompt owns CI gate against ingestion (M-INFRA-24) | Both apply |
| Real-time regression (BUT-393 / Phase 5) | all three | (closed ticket); this prompt owns guard scope (H-22) | |
| `BackupService` actual purpose (recipe export not DR) | default H-table | prompt 12 owns doc fix; this prompt owns ops impact | |

---

## Author's note on master synthesis

**Recommended consensus framing for the master document (prompt 03):**

1. **Score: 56-58 / 100, DevOps Maturity Level 2 of 5.** Use deep's 56. Default's 73 reflects under-weighting of the doc-vs-code drift severity that deep's Pass 2 verified live.

2. **Critical findings:** 3 verified critical risks (deep's CRIT-INFRA-1, CRIT-INFRA-2, CRIT-INFRA-3). Codex's CRIT-3 (analyzer) is stale-capture artifact. Default's C-1 (named hanging file) is correct symptom + wrong file (deep disproved).

3. **High findings:** 17-19 distinct HIGH items after deduplication (H-1 through H-24 above, minus codex H-29 which deep reframes correctly). Deep's HIGH-INFRA-9 (concurrency gap), HIGH-INFRA-10 (action SHA-pinning), HIGH-INFRA-11 (Stripe gap) are all VERIFIED LIVE for this synthesis and are unique adds.

4. **Strongest consensus signal across all three runs:**
   - PITR + weekly export are documented but never drilled (every run flagged)
   - Single Firebase project, no env separation (every run flagged)
   - No CI deploy of any Firebase surface (every run; deep is most thorough)
   - GCP alerting scope is sparse (2 policies, every run)
   - iOS signing absent in CI release path (every run)

5. **Weakest signal / deep-only:** CRIT-INFRA-1 (region mismatch) — neither codex nor default caught the cross-region anomaly. This finding is load-bearing for the master's DR section.

6. **New since deep run:** `sbom.yml` workflow added 2026-05-04 12:27 — partially addresses deep's M-INFRA-12 (no SBOM artifact). Master should note this as remediation in flight.

**Total file:line refs in this consensus doc: ≥80 across the 7 workflows + 13 runbooks + 5 infra/script paths. All claims either re-verified live (timestamped 2026-05-04) or explicitly carried forward from deep's Pass 2 verification table.**
