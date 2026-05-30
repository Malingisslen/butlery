# Sprint Backlog

## Sprint: iter-104 — 2 clean code-only tech-debt tickets — 2026-05-30 (Sat)

**Context:** iter-103 exhausted the obviously-clean backlog. Re-triaged the full 160-ticket
backlog (both pages). Most remaining = UI-visual (needs human eyes), ops-blocked (CF deploy /
store / MFA / prod access), dependency-upgrades blocked on the Dart SDK bump, or large EPICs.
Found 2 genuinely code-only, verifiable-without-UI/ops picks. Both P4, neither risk-gated
(no Bug/security label, single-module) → no Phase 1.5 expansion.

### Batch A — arch-test guard (test-only, zero risk)

- [x] **A1. BUT-1066: extend CPI arch-guard to `lib/views/`** — `test/architecture/architecture_test.dart`.
  Step 0: the `lib/widgets/` CPI guard ALREADY exists (BUT-885, `architecture_test.dart:502-579`).
  `lib/views/` has **zero** `CircularProgressIndicator(` sites → add a sibling guard with a
  **zero allowlist** (pure regression-prevention for the views layer). `lib/core/` (4 infra sites:
  dialog_factory, snackbar_utils, application_provider, base_action_handler) is the infra layer —
  out of this ticket's UI-layer scope. **plan-stale → rescoped.** (BUT-1066, P4)

### Batch B — tagging performance (code + test)

- [x] **B1. BUT-1055: migrate personal-tag display off always-on snapshot listener** —
  `lib/services/tagging/personal_tag_crud_service.dart`, `personal_tag_service.dart`,
  `lib/widgets/tagging/personal_tag_selector.dart`.
  Step 0 correction: the ticket's "per-widget snapshot listener at personal_tag_selector.dart:512"
  is stale — the `watchTags().listen` lives in `AutoPersonalTagDisplay` and is already a SINGLE
  shared, ref-counted static subscription (not per-widget). Intent still valid: even one
  `.snapshots()` listener stays open continuously whenever any tagged recipe card is visible.
  Change: (1) add a `tagsMutated` broadcast `Stream<void>` to `PersonalTagCrudService`, emitted at
  every `clearCache(tagsCacheKey)` site via a `_invalidateTagsCache()` helper; close the controller
  in `onDispose`. (2) Re-export `tagsMutated` through the `PersonalTagService` facade. (3) Rewrite
  `AutoPersonalTagDisplay._subscribe` to `getAllTags()` on first subscribe + a `tagsMutated`
  subscription that re-fetches (cache was just cleared → fresh read) and notifies all listeners.
  Preserve the shared-state + ref-count + "all instances see same data" invariant. (4) Add a
  service test pinning: tagsMutated fires on CRUD mutation; getAllTags re-fetches after.
  **plan-stale → rescoped.** (BUT-1055, P4)

### Deferred (heavier — left in Backlog, NOT this sprint)

- BUT-969 (P4) — typed models in account_deletion (GDPR cascade): code-only but security-sensitive,
  needs 3 new models + strong tests + firebase-backend-security review. Own focused pass.
- BUT-1044 (P4) — custom_lint package for un-disposed StreamSubscription: real infra setup
  (custom_lint dep + analyzer plugin + CI wiring); rabbit-hole risk. Own pass.
- BUT-581 (P4) — 224-site `?? ''` → `.orEmpty` codemod: blocked on reconciling two divergent
  extensions (silent behavior-change risk). Large + risky.

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` clean.
- [ ] Run `flutter test test/architecture/architecture_test.dart` + the new tagging service test.
- [ ] code-reviewer + testing-specialist on staged Dart (commit-gate hooks).
- [ ] Commit (conventional; footer Co-Authored-By Claude Opus 4.8), push to main.
- [ ] Close BUT-1066, BUT-1055 in Linear with the commit SHA + edit ticket bodies for the rescopes.

---

## Sprint: iter-103 — 4 code-only tech-debt tickets (SHIPPED) — 2026-05-29 (Fri)

All of iter-103a–g shipped + closed — see git history (`0a265fed5`, `8fd2ee656`, `9b71e0546`,
`0bb29128d`, `a7364fd2e`, `f1d63be31`). Closed: BUT-1165, BUT-472, BUT-1164, BUT-1111, BUT-1121,
BUT-1123, BUT-1075, BUT-1058. BUT-520 + BUT-1122 left as `[~]` (EPIC refined / premise-gone).
This file is sprint-scratch; the durable record is Linear + git.
