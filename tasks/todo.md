# Sprint Backlog

## Sprint: import-quality heuristic + gesture discoverability — 2026-06-04 (iter-107)

Clean tree on main (prior commit 9c8946120, CI green/pending). Clean Tier-A backlog is drained
(iter-103→106); leaning into a coherent Tier-B-leaning batch per the autonomy policy. Two
tickets, both low-design-risk (one reuses the shipped SwipeHintBanner; one is a standard confirm
dialog + a pure heuristic).

### Agent A: import-quality — stop paid LLM calls on non-recipe text
- [→] **A1. BUT-1037** `[Tier A heuristic + Tier B dialog]` — CARRIED to next iter (left in Todo,
      groomed). Step-0 done: premise holds (`parseText()` called from `fran_sociala_medier_view`
      `_parseAndNavigate`; VM exposes `inputText`; telemetry via `analytics/trackers/import_events_tracker`;
      existing `looksLikeRecipeContent` in html_sanitizer to reference). Deferred to keep this commit
      coherent (discoverability hints ≠ import cost-guard) and give the dialog UX + telemetry a focused pass.

### Agent B: discoverability — gesture hints (reuse BUT-982 SwipeHintBanner)
- [x] **B1. BUT-1199** `[Tier B]` — generalized `SwipeHintBanner` (per-gesture seenKey/icon/message,
      back-compat defaults) + hints on cooking-mode step list (long-press→timer) + collaborative
      shopping (swipe→claim). l10n sv/en. 6 banner tests green (incl. per-gesture isolation). → In Review.

### Needs you (Tier D / deferred — flagged, not worked)
- BUT-1169 — drop legacy meat_fish/fruit_veg shopping constants: BLOCKED — needs a prod telemetry
  read + a one-time Cloud Function backfill first; removing constants while old docs exist breaks
  rendering. Ops-gated.
- BUT-838 — recipe_cook_events log: deferred — crosses firestore.rules + composite index + a
  GDPR-cascade Cloud Function (needs deploy + rules-tester sign-off). Too heavy for a clean loop
  iter; pick up as a dedicated Tier-C sprint.
- BUT-1187 — phone import runtime-verify (carried). onRecipeDeleted gen-2 deploy ticket (carried).

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit/widget tests
- [ ] Commit, push
- [ ] Linear: In Review + notify for Tier B (1037 dialog, 1199); heuristic logic green

---

## ARCHIVED — iter-106: post-refactor testability + import-UX (2026-06-04, shipped 9c8946120)

5 Tier-A Done (BUT-1195 OcrErrorMessageBuilder tests, BUT-1196 ConfidenceIndicator widget test,
BUT-1194 getCommentLikers test, BUT-1197 SmartImportView mount smoke test, BUT-1028 recipe-list
scroll persistence). BUT-1198 allergen import banner → In Review. Follow-up BUT-1200 (photo surface).
