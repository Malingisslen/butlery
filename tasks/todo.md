# Sprint Backlog

## Sprint: autonomous-lane batch (notifications, a11y, voice, search) — 2026-06-29

Pulled 4 `autonomous`/clean tickets. All router `single`-tier, no high-stakes hits → Phase 1.5
plan-gate does not fire for any. Carry-forward BUT-1438 dropped: already Done + archived
2026-06-28 (all 3 export test files exist). `need-malin` legal/consent tickets (BUT-1395/96/99/
1400) left for Malin; BUT-1424 deploy-rollback deferred (Tier-C, unverifiable without a real
failed deploy).

### Agent A: notifications/CF — Stakeholders: Growth Marketer/ASO (single)
- [x] **A1. Dedicated `digest` push category, gated on a digest preference** `[Tier A]` (BUT-1427) — DONE, `11e5b5e80`, closed Done
  - `functions/src/analytics/send-activity-digest.ts` sends FCM as category `reEngagement`; the
    in-app doc gates on `digestFrequency`, so digest opt-out is honored only for the doc, not the push.
  - Files: `functions/src/analytics/send-activity-digest.ts`, the BUT-438 typed push-category contract,
    `functions/src/shared/preference-aware-push.ts`, `lib/models/notification_preferences.dart`.
  - Acceptance: a `digest` category exists in the typed contract + the preference model · the digest
    push is gated on `digest` (passed to evaluateSendGate + sendPushToUserRespectingPreferences), not
    `reEngagement` · a user with digest opted-out but reEngagement on does NOT get the digest push
    (test) · in-app doc gating unchanged; analyze + CF tests green.

### Agent B: accessibility/auth UI — Stakeholders: Accessibility Specialist (single)
- [x] **B1. Registration checkboxes ≥48dp + link Semantics on ToS/Privacy spans** `[Tier B]` (BUT-1426) — DONE, `e84f56538`, In Review. Follow-up BUT-1446 filed (3 more TapGestureRecognizer gaps).
  - Both registration checkboxes pinned to 24x24 (half the 48dp WCAG floor); inline ToS/Privacy
    TextSpans carry no link Semantics; both slip the audit scanner.
  - Files: `lib/views/auth_view.dart`, `tools/audit_unwrapped_tap_targets.dart`.
  - Acceptance: both checkboxes have a ≥48dp tap target · inline ToS/Privacy spans expose link role +
    accessible name · the audit scanner flags TapGestureRecognizer links (or the new affordance passes
    it) · no layout regression vs current screen (preview screenshot) · analyze clean.

### Agent C: voice/i18n — Stakeholders: UX Writer/Content Strategist (single)
- [x] **C1. Reframe ~69 celebration/success strings off exclamation marks** `[Tier B]` (BUT-1431) — DONE, `adc8a5b8d`, In Review. 79 strings (10 more than estimate — embedded-quote strings a naive grep missed).
  - Butler-voice guide rule #1 ("Inga utropstecken. Aldrig.") + rule #4 (bans "Grattis!") violated by
    the highest-visibility success strings.
  - Files: `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb`, `.claude/rules/code-style.md` (voice pointer).
  - Acceptance: the named strings (celebrationFirstRecipeTitle, successItemCreated, recipeSaved,
    profileSaved, profileDeleteIrreversible, urlSuggestionOptimal) + the ~69 `!`-terminated sv strings
    rewritten without `!` in butler register; matching en updated · grep proof: no `!` in the targeted
    set · a voice-guide pointer added to code-style.md (auto-loads on ARB edits) · ARB still valid
    (gen-l10n / analyze clean); ICU placeholders untouched.
  - Negative constraint: don't touch out-of-scope strings; don't alter ICU placeholders/`{counts}`.

### Agent D: search UX — Stakeholders: Data/Integrations Engineer (single)
- [~] **D1. Consume SearchResult.failed for user/friend search** `[Tier B]` (BUT-1442) — DESCOPED (Step-0 plan-stale): the `failed` flag is swallowed upstream (user_service + friends_management return bare lists), so the real fix is a cross-service contract change, not a VM branch. Linear body rewritten with corrected scope; left in Backlog.
  - `algolia_search_repository.searchUsers` flags `SearchResult.failure` on outage, but nothing consumes
    it — friend search still shows a neutral empty list (the bug BUT-1416 fixed for recipe search).
  - Files: `lib/viewmodels/friends/friends_search_manager.dart` (+ the friend-search view empty state).
  - Acceptance: friend/user search branches on `result.failed` → degraded/offline notice, not the
    "no users found" empty state · a successful-but-empty search still shows the normal empty state ·
    test asserts the failed path produces the degraded state · analyze + tests green.

### Needs you (not worked this batch)
- BUT-1395/1396/1399/1400 — `need-malin` legal/consent/PII (Art.15 export gaps, ToS-record persistence,
  consent-toggle, appeals domain). Codeable but reserved for your sign-off.
- BUT-1424 — executable backend-deploy rollback (Tier-C; can't be verified without a real failed deploy).

### Post-Sprint Steps
- [ ] dart analyze --fatal-infos
- [ ] Per-ticket review gates (code-reviewer all; testing-specialist lib/**; cloud-functions-specialist
      BUT-1427; firebase-backend-security BUT-1442 repo path) + markers
- [ ] Commit per-ticket, push to main
- [ ] Linear: BUT-1427 → Done; BUT-1426/1431/1442 → In Review + notify

---

## Sprint: direct unit tests for 3 GDPR-export sub-managers — 2026-06-28
- [~] **A1. BUT-1438** — obsolete: already Done + archived 2026-06-28; all 3 export test files exist.

## Recent shipped (prior session): BUT-1421 (doc fix, Done).
