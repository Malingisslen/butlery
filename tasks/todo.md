# Sprint Backlog

## Sprint: age-floor-15 enforcement (BUT-1384) — 2026-06-27

Single Tier-C ticket. Design fully settled by ADR-0001 (age=15) + ADR-0002 (dual-layer).
Split along ADR boundaries — see Step-0 below. Ships to main, parks **In Review** (legal copy
needs Malin sign-off + rules change needs her awareness).

### ★ Risky-ticket plan ─ BUT-1384 (Tier C) ──────────────────
Classification: **plan-stale → rescoped** (ticket bundles ADR-0001 + ADR-0002; the ADR-0002
"reject client birthYear writes" rule cannot ship before the net-new signup CF exists, or
onboarding breaks). This sprint = ADR-0001 alignment + ADR-0002's rule-layer gate;
ADR-0002's authoritative CF + audit + cost-caps + client rewrite → filed follow-up.

Files touched:
- `assets/legal/terms_of_service_{sv,en}.md` — age 13→15
- `assets/legal/privacy_policy_{sv,en}.md` — age 13→15 + explain why 15 (stricter than statutory 13)
- `lib/l10n/app_sv.arb` — `authAgeConfirmation` 13→15; fix `onboardingAgeGateSubtitle`/`TooYoungBody` citation (GDPR Art 8 → Dataskyddslag 2:4 §)
- `lib/l10n/app_en.arb` — mirror age strings if present
- `lib/viewmodels/onboarding_viewmodel.dart:23-25` — comment cites GDPR Art 8 → correct basis
- `lib/models/user_profile.dart:135-139` — birthYear validation upper bound `currentYear-13` → `currentYear-15`
- `firestore.rules:413-440` — floor 13→15; add `isAgeCompliant()`; gate user-data + UGC write paths
- `functions/src/__tests__/age-gate-rules.test.ts` — update floor + new isAgeCompliant cases
- `SECURITY.md` — COPPA / underage-discovery incident-response runbook

Blast radius: firestore.rules UGC gating (comments, groups, chat, ratings) reads stored
birthYear; fails CLOSED on missing (deny) — safe pre-launch (~1 user, has birthYear). Existing
rules tests for UGC paths that don't seed birthYear will need fixtures updated. Client remains
birthYear writer this phase (with tightened 15 floor).

Product-intent flags: legal wording (ToS/PP Swedish copy + the "why 15" explanation) is drafted
by me for Malin's sign-off at In-Review — flagged, not halted.

Rollback shape: single commit; revert restores 13-floor + old citation. firestore.rules reverts
cleanly (no data migration in this phase).
─────────────────────────────────────────────────────────────

### Agent A: copy + model alignment (me, direct) — all numbers → 15
- [x] **A1. Align every age number to 15 + fix legal citation** `[Tier C]` (BUT-1384 items 1,2)
  - Acceptance: no app-facing age string says 13 (authAgeConfirmation, ToS, PP, ARB gate) ·
    no age string cites "GDPR Art 8" as the basis for 15 (replaced with Dataskyddslag 2:4 § /
    social-ISS) · PP explains why 15 is stricter than the statutory 13 · `user_profile.dart`
    birthYear upper bound = currentYear-15 · gen-l10n regenerates clean · analyze clean.

### Agent B: firestore rule floor (me, direct + firestore-rules-tester) — tighten 13→15
- [x] **B1. settings/preferences age floor 13→15** `[Tier C]` (BUT-1384 item 1, Firestore portion)
  - Scope note: the `isAgeCompliant()` UGC-path gate moved to the ADR-0002 follow-up — it is
    only sound once the CF guarantees birthYear is authoritatively present, and adding it now
    (fail-closed on missing birthYear) would break every comments/chat/ratings rules test that
    doesn't seed birthYear. This pass tightens only the existing client-write floor.
  - Acceptance: settings/preferences create AND update validate `birthYear <= request.time.year()-15`
    (was -13) · stale "hard floor of 13" rule comment corrected to 15 + correct legal basis ·
    age-gate-rules.test.ts proves allow born-≤year-15 / deny born-year-14 on create + update ·
    emulator rules suite green.

### Agent C: SECURITY.md runbook (me, direct)
- [x] **C1. COPPA / underage-discovery incident-response runbook** `[Tier C]` (BUT-1384 item 7)
  - Acceptance: SECURITY.md has an "Underage user discovered" section: suspend → Art 17 deletion
    cascade → 72h IMY-notification assessment → owner + timeline · COPPA scoped "if/when US
    distribution" · no code dependency (doc only).

### Needs you (filed as follow-up, not worked this sprint)
- BUT-1386 — ADR-0002 authoritative enforcement layer (whole ADR as one coherent unit): signup
  Cloud Function (authoritative birthYear writer + age-enforcement audit event w/ 730-day
  retention + App Check + rate-limit + per-IP audit cap) + isAgeCompliant() rule fn gating
  user-data + UGC write paths (comments, groups, chat, ratings) + rules reject client birthYear
  writes + onboarding client rewrite to call the CF + wrongly-blocked recovery path + butler-voice
  rejection. Closes the remaining "skip/null birthYear" self-declaration bypass. Deferred as a
  unit because the gate is only sound once the CF guarantees birthYear presence, and the
  "reject client writes" rule can't ship before the CF exists.

### Tier D (flagged, not worked)
- BUT-889 — 4 paid-API LLM golden corpora (needs paid API keys).
- BUT-1240 — NER golden corpus real-signal lane (needs a physical capture device).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] gen-l10n + relevant unit tests + emulator rules suite
- [ ] firestore-rules-tester + firebase-backend-security + code-reviewer
- [ ] Commit, push
- [ ] BUT-1384 → In Review (legal-copy sign-off) + edit body to reflect shipped vs deferred
- [ ] File ADR-0002 follow-up ticket

---

_(Prior sprint 2026-06-23 BUT-1359/1360 completed — commits cc5bad4dc / c541c9385; that todo
archived to git history.)_
