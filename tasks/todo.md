# Sprint Backlog

## Sprint: ADR-0002 age-enforcement server layer (BUT-1386) — 2026-06-27

Single high-stakes Tier-C ticket — the authoritative server-side age gate that backs Butlery's
public "15+" claim. Design settled by ADR-0001 (age=15) + ADR-0002 (dual-layer). Full stakeholder
panel ran 2026-06-27 (Security, Privacy/GDPR, FinOps, Software Architect, Legal, QA) — all
approve-with-conditions, no blocks. Conditions folded into acceptance below. Ships to main, parks
**In Review** (legal-copy + policy-disclosure sign-offs + store-rating awareness).

### ★ Risky-ticket plan ─ BUT-1386 (Tier C, full-panel) ──────────────────
Classification: **fits** (ADR-0002 as specced) with one panel-driven refinement:
isAgeCompliant() reads a **custom auth claim**, NOT a server doc + get() (unanimous 4/4:
Security/FinOps/Architect — unspoofable + zero extra reads/UGC-write). Under-15 sequencing =
**Auth-first + synchronous account deletion** (Malin chose this 2026-06-27 over the bigger
pre-Auth Identity-Platform rebuild).

Files touched:
- `functions/src/account/verify-signup-age.ts` — NEW. onCall v2, enforceAppCheck, withRateLimit,
  authoritative birthYear writer + ageCompliant claim setter + consent audit event; under-15 →
  synchronous auth delete + minimized non-identifying rejection record. DI seam (runWithDeps).
- `functions/src/middleware/rate_limiter.ts` — add `verifySignupAge` rate config + tighter signup
  global cap consideration.
- `functions/src/index.ts` — export verifySignupAge.
- `functions/src/__tests__/verify-signup-age.test.ts` — NEW. CF unit tests via DI seam.
- `firestore.rules` — add isAgeCompliant() (claim-based, fail-closed); DENY client birthYear
  writes on settings create+update; gate 4 UGC create paths (recipe_comments, messages,
  social_requests, recipe_ratings) with && isAgeCompliant().
- `functions/src/__tests__/age-gate-rules.test.ts` — replace settings-birthYear contract with
  client-birthYear-denied + add isAgeCompliant 4-path matrix (~24 cases), per-run path suffix.
- `functions/src/__tests__/*comment*/*message*/*rating*` rules tests — seed `ageCompliant:true`
  claim on authed contexts so existing create tests don't flip to deny.
- `lib/viewmodels/onboarding_viewmodel.dart` + onboarding service — call verifySignupAge instead
  of writing birthYear directly; forceRefresh token on compliant; butler-voice reject + back-to-start
  on under-15.

Blast radius: signup/onboarding critical path + 4 UGC write rules. Pre-launch (~1 user w/ birthYear)
→ low migration risk; atomic deploy (CF + rule-deny same commit, per Security — no field clients to
phase for). Existing UGC rules tests fail-closed until claim seeded → fixture updates required.

Rollback shape: single commit; revert restores client-birthYear-write + old settings floor rule +
client-side-only gate. Claim is additive (no data migration); CF can be left deployed harmlessly.

### Agent A: signup-age Cloud Function (cloud-functions-specialist)
- [x] **A1. verifySignupAge CF + rate config + index export + CF unit tests** `[Tier C]` (BUT-1386 items 1,5)
  - Acceptance: CF is the only `birthYear` writer · sets `ageCompliant` claim only at ≥15 ·
    under-15 → synchronous `auth.deleteUser` + rejection record stores NO uid/email/birthYear
    (timestamp + decision + basis only) · consent-category audit event w/ 730-day `expireAt`,
    stores derived fact (isAgeCompliant + birthDecade) + hashUid, NOT raw birthYear · idempotent
    retry (claim/birthYear already set → no-op success) · enforceAppCheck + withRateLimit +
    per-IP audit-write cap ≤5/h · DI seam parity with request-account-deletion · CF unit tests
    green (idempotency, appcheck, ratelimit, invalid input, reject-deletes-auth).

### Agent B: Firestore rules + rules tests (firestore-rules-tester)
- [x] **B1. isAgeCompliant() claim gate + client birthYear write denial + 4 UGC paths** `[Tier C]` (BUT-1386 items 2,3)
  - Acceptance: `isAgeCompliant()` = `request.auth.token.ageCompliant == true`, fails CLOSED on
    missing/false · client writes containing `birthYear` DENIED on settings create+update · each of
    recipe_comments/messages/social_requests/recipe_ratings create requires isAgeCompliant() ·
    rules suite: ≥15-claim allowed / no-claim denied on all 4 paths + client-birthYear-write denied,
    per-run path suffix · existing comment/message/rating rules tests seed the claim and stay green.

### Agent C: onboarding client rewrite (flutter-developer)
- [x] **C1. Onboarding calls verifySignupAge + forceRefresh + butler-voice reject** `[Tier C]` (BUT-1386 item 4,5)
  - Acceptance: onboarding no longer writes `birthYear` into preferences directly · calls the CF,
    on compliant forceRefreshes the ID token BEFORE first UGC-capable screen · under-15 → butler-voice
    message (quiet, non-punitive, no "try again with another year", no birthYear echoed) + returns to
    start (account already deleted server-side) · analyze clean.

### Needs you — sign-off at In Review (not blockers)
- Privacy policy: add an explicit line that birthYear + an age-verification record are collected at
  signup (policy currently discloses the 15 floor + basis but not the collection point). Legal item.
- Store-rating: confirm App Store / Play content-rating answers reflect the 15+ social-feature gate.
- (Decided) Under-15 sequencing = Auth-first + instant delete; pre-Auth Identity-Platform intercept
  filed as post-launch follow-up.

### Post-Sprint Steps
- [ ] `cd functions && npm run build` (tsc) + `dart analyze --fatal-infos`
- [ ] Emulator rules suite + CF unit tests green
- [ ] firestore-rules-tester + firebase-backend-security + cloud-functions-specialist + code-reviewer
- [ ] Commit, push
- [ ] BUT-1386 → In Review + comment (panel conditions met, sign-off items) + PushNotification
- [ ] File follow-ups: birth-year correction CF (admitted-user edit) + pre-Auth intercept upgrade

---

_(Prior sprint 2026-06-27 BUT-1384 age-floor-15 — Done, commit 30fe7e51e. That todo archived to git.)_
