# Sprint Backlog

## Sprint: backend cost/correctness + UGC safety — 2026-06-27

Three High-priority `autonomous` Tier-A bug fixes. Stakeholder concerns folded into acceptance
criteria (ticket descriptions already stamp owners); Phase 3 commit gate runs the owning
specialists (firebase-backend-security on functions/, code-reviewer+testing-specialist on Dart),
so a separate pre-build full panel would be disproportionate for mechanical fixes.

### Agent A: backend cleanup/index (cloud-functions-specialist) — Stakeholders: DBA/Data-layer, FinOps, Privacy/GDPR
- [x] **A1. Repoint rate-limit cleanup cron to live `system_rate_limits` + range query** `[Tier A]` (BUT-1390)
  - Files: `functions/src/cleanup/cleanup-rate-limits.ts`, its integration test, `rate_limiter.ts:9` header, `docs/ops/llm-kill-switch-runbook.md`
  - Acceptance: `cleanupOldRateLimitsCore` scans `system_rate_limits` with a single `where('updatedAt','<',cutoff)` range query (no per-user N+1 `.get()` loop) · batch-deletes stale buckets · integration test seeds + asserts `system_rate_limits` (not the dead `users/*/rate_limits`) · runbook + `rate_limiter.ts:9` header describe the live path + fail-closed behavior · GDPR cross-check: confirm whether account-deletion-cascade + reset-user-data should also target `system_rate_limits` (do it or file follow-up).
- [x] **A2. Add missing `ingredients` composite index (status ASC, deletedAt ASC)** `[Tier A]` (BUT-1391)
  - Files: `firestore.indexes.json`
  - Acceptance: `firestore.indexes.json` contains an `ingredients` composite covering `status ==` + `deletedAt <` (and the `orderBy deletedAt` stats variant) · field order matches the query (status ASC, deletedAt ASC) · this is NOT mislabelled as the equality-only accepted deviation.

### Agent B: UGC profanity gate (flutter-developer / direct) — Stakeholders: Trust & Safety
- [x] **B1. Run `ContentFilterService.ensureClean` on comment + chat write paths + remove dead getters** `[Tier A]` (BUT-1393)
  - Files: `lib/services/social/social_comments_manager.dart`, `lib/services/social/comment_crud_operations.dart`, `lib/viewmodels/chat_viewmodel.dart`
  - Acceptance: `postComment` calls `ensureClean(text, fieldName:'comment')` and aborts + surfaces `result.reason` when not clean (mirrors cook_snap_service) · `sendTextMessage` gated on the filter before send · dead `hasProfanityWarning` / unused `containsProfanity` getters removed · existing comment/chat tests still pass + a new test proves a profane comment + message are rejected.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` (Dart) + `cd functions && npm run build` (TS)
- [ ] Relevant tests: CF cleanup-rate-limits test, Dart social/chat tests
- [ ] Phase 2.7 outcome verifier per agent group
- [ ] Commit (code-reviewer + testing-specialist + firebase-backend-security gates), push
- [ ] BUT-1390/1391/1393 → Done (Tier A) + comments
- [ ] File follow-ups (GDPR cross-check if deferred, etc.)

---

## Sprint: ADR-0002 age-enforcement server layer (BUT-1386) — 2026-06-27 — SHIPPED (commit 07fa820d0, In Review)

BUT-1386 implemented + verified + shipped to main, parked In Review for legal-copy/store-rating/App-Check
sign-offs. Follow-ups filed: BUT-1435/1436/1437 (and BUT-1389/1388 pre-existing for correction-CF + pre-Auth
intercept; my dup BUT-1433/1434 closed as duplicates). All gates green: tsc, dart analyze, 7/7 CF tests,
78 rules tests, 105 Dart tests, 5 specialist reviews clean.

- [x] A1. verifySignupAge CF + rate config + index export + CF unit tests
- [x] B1. isAgeCompliant() claim gate + client birthYear write denial + 4 UGC paths
- [x] C1. Onboarding calls verifySignupAge + forceRefresh + butler-voice reject
