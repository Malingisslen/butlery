# Sprint Backlog

## Sprint: cleanup foundation + backend security + perf — 2026-05-06 (R)

Theme: post-forensic-audit cleanup. Three batches: pre-analysis hygiene + doc reconcile (Batch A), backend security + integrity (Batch B), social perf + decision artifacts (Batch C).

### Step 0 results
- **BUT-775 obsolete** — `dart_test.yaml` already exists at root with `timeout: 30s` exactly as ticket asked. Close as premise-gone.
- **BUT-774 plan-stale** — ticket cites three docs (`audit-logs-retention.md`, `data-residency.md`, `backups.md`) that don't exist in `docs/operations/`. Re-scope to: decide canonical region (the actionable part); leave the backup drill as a separate ops follow-up since it requires production access.
- **BUT-789 plan-stale** — full sqlcipher → sqlite3 migration is a 3-5 day data-touching project per ticket's own remediation plan. Per the "max one large arch piece per sprint" rule + risk profile (botched migration = user data loss), re-scope to: produce migration ADR + blast-radius audit (decision artifact). Execution lands in a follow-up sprint.

### Agent A: Cleanup foundation

- [x] **A1. BUT-768** — Delete `lib/site-packages/` (PIL, pillow, pip artifacts). Add CI guard `tools/check_no_python_artifacts.sh` that fails if `lib/site-packages/` reappears or `*.py`/`*.pyc` lands under `lib/`. Wire into existing CI workflow.
- [x] **A2. BUT-775** (closed obsolete) — Close as obsolete; `dart_test.yaml` already has 30s timeout default + per-tag opt-outs. No code change.
- [x] **A3. BUT-807** — Recompute large-file count via a one-shot script. Update `.claude/rules/code-style.md` "33 files" claim to actual count. Reconcile any internal inconsistency in `ACCEPTED_LARGE_FILES.md`. Optional: small CI guard scripted.

### Agent B: Backend security & integrity

- [x] **B1. BUT-780** (SafeSearch deferred — separate ticket) — New `functions/src/storage/moderate-upload.ts` `onObjectFinalized` trigger. Magic-byte verification (JPEG/PNG/WebP/HEIC), reject SVG/BMP/TIFF/AVIF, format whitelist. SafeSearch via Vision API → quarantine bucket on adult/violence/racy ≥ LIKELY. Audit-log entry per reject/quarantine. CF unit tests for happy + adversarial paths.
- [x] **B2. BUT-808** — Reconcile audit-log retention to a single source. Decision: 365 days canonical (matches GDPR best-practice + the model's existing `expireAt` math). CF (`purge-expired.ts`, `cleanup-audit-logs.ts`) becomes authoritative; align constants. Document in code comments + a single retention.md doc. Arch-test guards future drift.

### Agent C: Social perf + decision artifacts

- [x] **C1. BUT-778** (full server-side replacement; healer module deleted) — Replace per-conversation `onSnapshot` listeners in `conversation_auto_healer_module.dart` with a single `array-contains` query on `participantUserIds`. Feature-flag `conversation_auto_healer_v2` for cohort rollout. Listener-count metric. Old code-path retained until v2 verified.
- [x] **C2. BUT-774 (rescoped)** — `docs/operations/data-residency.md`: capture the canonical region decision based on actual Firebase console state. Skip the multi-doc reconcile (those docs don't exist). Backup drill deferred to ops task.
- [x] **C3. BUT-789 (rescoped)** — `docs/architecture/ADR-002-sqlcipher-migration.md` — `docs/architecture/ADR-002-sqlcipher-migration.md`: blast-radius audit (where sqlcipher_flutter_libs is used in lib/), evaluate sqlite3 + manual cipher PRAGMA vs drift's encrypted backend, KDF compatibility note, migration cycle plan, rollback strategy. Decision artifact only — no code migration this sprint.

### Tier-2 agent reviews (commit hook gate)
- [ ] code-reviewer
- [ ] testing-specialist
- [ ] firebase-backend-security
- [ ] firestore-rules-tester (only if firestore.rules touched)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] `npx tsc --noEmit` clean in functions/
- [ ] Relevant unit tests pass
- [ ] /simplify pass
- [ ] Commit + push
- [ ] Linear: 8 tickets → Done with summaries (5 fully shipped + 3 ADR/closure)

### What this means in plain language
- **Tidying up + raising the floor**: a stray Python directory got committed and is corrupting every audit script's percentages → delete it. The "33 files >500 lines" doc claim is years out of date → fix it. CI was running tests with no per-test timeout (default is 30 minutes!) → the file already exists, just needs closure.
- **Three real fixes**: (1) every uploaded image now gets server-side magic-byte + SafeSearch checks before it reaches anyone else's screen, (2) the audit-log retention finally has a single 365-day answer instead of three contradictory numbers, (3) the DM auto-healer stops opening 50+ Firestore listeners per active user.
- **Two decisions written down, not executed**: (1) what region the database lives in, (2) the plan for replacing the unmaintained encrypted-database library. Each becomes a doc this sprint; execution happens in a future sprint with proper testing time.
- **Risk**: low for the five ship items (each is well-bounded). The two ADRs are purely documentation — zero runtime risk.

---

## Archived prior sprint (completed in commit 13417b801)

Security/perf/GDPR sweep (BUT-771/769/779/797/773/781/785/770) — 2026-05-06 (Q).

## Archived prior sprint (completed in commit 709ea672f)

BUT-536 firebase_recipe_repository module extraction — 2026-05-06 (P).

## Archived prior sprint (completed in commit 1c82cee20)

BUT-441 mina_recept_view facade extraction — 2026-05-06 (O).
