# Scan — Role 9: DevOps / SRE

Date: 2026-06-27 · Reviewer lens: CI/CD reliability, alerting, backups/DR, deploy safety, env separation.
Owned paths: `.github/workflows/**`, `docs/ops/**`, `firebase.json`, `infrastructure/alerting/setup-gcp-alerts.sh`, `lefthook.yml`.

Recently-modified `firestore-rules.yml` reviewed: the only change is adding `account-maturity-rules.test.ts` and `recipe-comments-rules.test.ts` to the `paths:` triggers (both `pull_request` and `push`). Correct and benign — keeps the rules gate firing when those new rules-tests change. No gap introduced.

---

## PASS 1 — deploy/alerting/backup/DR/env

### Already-tracked (NOT new — do not file)
- Automated deploy pipeline exists (`deploy-firebase.yml`, BUT-486) with `production` manual-approval environment + pre-deploy rules-unit gate. Mobile pipeline (Fastlane/App Distribution) still open = **BUT-420**.
- GCP alerting live (2 CF policies, BUT-450); budget alerts manual-Console = **BUT-492**.
- Backups: PITR + weekly export (BUT-418); restore drill NEVER PERFORMED = dossier watch-item + dedup **BUT-452 follow-up (PITR restore drill)**.
- Storage versioning/lifecycle = **BUT-419** (runbook header/activation contradiction is a dossier watch-item, not new).
- Staging Firebase project = **BUT-451**. DORA metrics = **BUT-496**. Runbooks/rollback doc = **BUT-452**. Integration-test emulator health gate = **BUT-489** (now actually implemented in `test.yml` lines 529-546).

### NEW (verified, not in dedup/tracker/deviations)

**N1 — Backend deploy has NO post-deploy verification/smoke gate (functions + storage deploy blind).**
`deploy-firebase.yml` runs the rules-unit suite *before* deploy (lines 99-134), but after `firebase deploy` (lines 143-168) there is no post-deploy check at all — no callable-function smoke, no `firebase functions:list` health probe, no storage-rules sanity read. A deploy that succeeds at the CLI level but ships a broken Cloud Function (bad env, failed cold start) or a storage-rules regression goes green and unnoticed until a user hits it. BUT-486 covers *automating* the deploy; BUT-489 covers the *integration-test* emulator gate. Neither covers verifying the **live** deploy landed healthy.
_Evidence: `.github/workflows/deploy-firebase.yml:143-181` (deploy step is terminal; only a static "Summary" follows, no live probe)._

**N2 — No rollback path for the backend deploy (no previous-revision capture, no auto-revert on failure).**
The deploy step (lines 143-168) is fire-and-forget. Cloud Functions keeps prior revisions, but the workflow never records the pre-deploy revision/version, and there is no rollback step or `firebase functions:delete`/redeploy-previous on failure. Firestore rules likewise overwrite in place with no captured prior ruleset. BUT-452 is the *runbook doc* for "deploy rollback" — there is no *executable* rollback in CI. Under incident pressure a bad rules/functions deploy must be hand-reverted from memory.
_Evidence: `.github/workflows/deploy-firebase.yml:143-168` (no revision capture / no failure-branch revert); `docs/ops/backups.md` covers data DR only, not deploy-artifact rollback._

---

## PASS 2 — CI reliability / storage / secrets / health-alert coverage

### Confirmed-healthy (no finding)
- CI long-job posture is deliberate and documented: per-commit unit sharded 3× (compile-bound ~12 min floor, BUT-1193/1182), coverage + cross-OS moved nightly. Flake absorbers present (cross-os 2-attempt retry, BUT-1192; views-windows off critical path). Duration budgets emit `::warning::`. This is well-reasoned, not a gap.
- Secrets in workflows: `FIREBASE_SERVICE_ACCOUNT` fail-loud check (deploy lines 92-95), SA JSON written to `$RUNNER_TEMP` not echoed; actions SHA-pinned (flutter-action, codecov — BUT-790); lefthook secret-scan covers staged files. Good.
- `permissions:` scoped per workflow (deploy `contents: read`; health-alert `issues: write, actions: read`; release `contents: write`). Good.

### NEW (verified)

**N3 — Health-alert workflow does not watch the deploy, rules, E2E, dep-audit, or golden-LLM workflows.**
`main-health-alert.yml` re-checks only three gates — `Run Tests`, `Build Validation`, `Architecture & Code Quality Validation` (lines 30-34). A red `Firestore Rules`, `Deploy Firebase`, `e2e_tests`, `dep-audit`, `golden-llm`, `model-version-guard`, `sbom`, or `prompt-changelog-gate` run on `main` opens **no** tracking issue. The exact failure mode BUT-435 was built to kill (red main unnoticed by a solo dev) is still live for ~8 of the ~14 workflows — most notably a failed production **Deploy Firebase** raises no auto-issue.
_Evidence: `.github/workflows/main-health-alert.yml:12-16` (`workflow_run.workflows` lists 3) + `:30-34` (`gates` array lists the same 3); workflow dir has 14 yml files._

### Worth-noting (NOT filing — judgment calls / single-user posture)
- Deploy `all` target runs `firebase deploy --only firestore,functions,storage` as one command (line 162): a mid-way failure leaves a partial/mixed state with no isolation. Real but low-likelihood at current scale; folds naturally into N1/N2 (verify + rollback) rather than a separate ticket.
- `firebase deploy` for functions has no explicit `--force` or per-function timeout; default behavior is acceptable for the current small function set.
- GCP alerting deliberately omits Firestore read-rate + Auth-failure policies (metric-schema churn) — documented intentional gaps in `gcp-alerting-runbook.md:39-61`; covered by budget-alert ticket BUT-492. Not new.

---

COVERAGE: deploy pipeline (pre/post-deploy gates, rollback, atomicity) · all 14 workflows incl. recently-modified firestore-rules.yml · alerting script + runbook · backups/PITR/export/storage-lifecycle runbooks · firebase.json target scope · lefthook gates (format/secret-scan/analyze/arch-guard/real-time) · secret handling + permissions + SHA-pinning · health-alert coverage · CI long-job/flake posture. NEW: 3 (N1 post-deploy verify gate, N2 executable rollback, N3 health-alert workflow coverage). All cross-checked against `_scan_dedup_titles.txt`, `linear-tracker.json`, `accepted-deviations.md`, and the role-9 dossier watch-items.
