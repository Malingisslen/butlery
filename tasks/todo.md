# Sprint Backlog

## Sprint: import flow — multi-recipe wiring + URL/photo/source UX — 2026-06-14 (iter-151)

Focus = `import` area label (per orchestrator). Backlog scan: 9 import-labeled Backlog tickets (Todo / In Progress / Triage all empty). This pool is almost entirely `idea`-labeled UX features — so the batch is mostly **build-review** (worth building, but the user-facing outcome is Malin's to sign off), and two tier-parameterization tickets are flagged **needsApproval** because they presuppose a monetization model that hasn't been decided.

Selected 5 buildable import tickets, all **build-review (Tier B/C)**. Batches are file-disjoint so they run in parallel worktrees without patch collisions. ImportManager / multi-recipe-path edits are owned exclusively by Agent A (text-import) so Agent C (photo) never touches the same files.

### Agent A: import-text — wire text import through the production multi-recipe path + AI-provenance labels `[Tier B]`
- [ ] **A1. Route text import through `ImportManager.autoParseMulti` + reuse the existing multi-recipe picker** `[Tier B]` — `lib/viewmodels/text_import_viewmodel.dart` (route `parseText()` through `autoParseMulti`), `lib/services/import/import_manager.dart` (expose/confirm the multi entrypoint), reuse photo-import picker UI, delete the orphaned `lib/services/parsing/common/recipe_boundary_detector.dart` + its test, l10n keys. (BUT-1040)
  - Acceptance: when `autoParseMulti` detects >1 recipe, `parseText` shows the multi-recipe picker instead of running the single-recipe pipeline · the user can import all OR pick a subset, and each selected block saves as its own Recipe · the orphaned `recipe_boundary_detector.dart` is deleted (or folded into the live path and UTF-8 re-encoded) with zero remaining references · multi-extract shows progress feedback (snackbar/progress dialog) and runs sequentially (no N concurrent LLM calls)
  - Sign-off: picker copy + sequential-vs-parallel choice (ticket recommends sequential for cost/rate-limit safety).
- [ ] **A2. Label AI-suggested vs user-entered content in the line selector + add an `ai` provenance source** `[Tier B]` — `lib/widgets/import/text_line_selector.dart` ("AI-förslag" chip on AI-detected lines), `RecipePersonalTag.sources` model (add an `ai` provenance value). (BUT-931)
  - Acceptance: AI-detected lines in the selector carry a visible "AI-suggested" affordance distinct from user-entered lines · `RecipePersonalTag` provenance can represent an `ai` source distinguishable from user-applied tags · the chip/label follows the square/cream design language (no rounded badges) · existing user-entered lines render unchanged (no false AI labelling)
  - Sign-off: chip wording ("AI-förslag" vs "Föreslaget av AI") + visual treatment of AI vs user lines.

### Agent B: import-url — multiple URLs / recipe-index pages in URL import `[Tier B]`
- [ ] **B1. Accept multiple URLs (and recipe-index listing pages) in URL import** `[Tier B]` — `lib/viewmodels/url_import_viewmodel.dart` (`fetchContentFromUrl` → list-aware), `lib/views/import_via_url_view.dart` (multi-URL input + per-URL result/progress). (BUT-947)
  - Acceptance: the URL field accepts a list of URLs (newline/whitespace-separated) and each is fetched + parsed into its own Recipe · per-URL progress/result feedback is shown (which succeeded, which failed) · a single invalid URL does not abort the whole batch (partial success allowed) · runs sequentially, not N concurrent fetches (cost/rate-limit safety)
  - Sign-off: input affordance (one multiline field vs add-row list) + whether recipe-index listing-page expansion is in scope for v1 vs just a URL list.

### Agent C: import-photo — multi-page recipe import (2–5 photos → one recipe) `[Tier B]`
- [ ] **C1. Multi-page photo import — combine 2–5 photos into one recipe** `[Tier B]` — `lib/viewmodels/photo_import_viewmodel.dart` (collect an ordered photo list, cap 5), `lib/views/photo_import_view.dart` (add/reorder/remove pages UI), `lib/services/ocr_extraction_service.dart` (OCR each page, concatenate in order before the single parse). Does NOT touch `import_manager.dart` / `multi_recipe_splitter.dart` (owned by Agent A). (BUT-903)
  - Acceptance: a user can add 2–5 photos to a single import and the OCR text is concatenated in page order before one parse pass (one Recipe out, not N) · adding more than 5 pages is capped/rejected, not silently truncated · single-photo import behavior is unchanged (no regression to the existing one-image path) · page order is user-controllable (reorder/remove) before extraction
  - Sign-off: page-management UX (reorder/remove affordance) + the 5-page cap.

### Agent D: import-source — re-extract from source + 30-day stale-source banner `[Tier C]`
- [ ] **D1. "Re-extract from source" action + stale-source banner in the source sheet** `[Tier C]` — source-sheet view (from BUT-1079 part 1, commit `881ceac55`), `lib/viewmodels/` source/re-extract wiring, `UrlImportStrategy` / `TextImportStrategy` re-feed by `SourceArtefactType`. Preserves recipe `id` + `createdAt` + `sourceArtefact`. Does NOT touch `import_manager.dart` (Agent A) — re-extract goes through the strategy directly. (BUT-1205)
  - Step 0: fits (part 1 read-only sheet already shipped + Done; this is the sanctioned deferred follow-up).
  - Files touched: source-sheet view + its viewmodel; `UrlImportStrategy`/`TextImportStrategy` invocation seam; confirmation dialog widget.
  - Blast radius: re-extract overwrites parsed fields on an existing Recipe — must preserve identity metadata and be guarded by a confirmation dialog when the recipe has user edits; failure path must leave the recipe untouched.
  - Product-intent flag: the overwrite-vs-append behavior on user-edited recipes is a real UX decision — implement overwrite-with-confirmation (the ticket's stated default) and surface it for sign-off; do NOT silently overwrite.
  - Rollback shape: feature is additive (new action + banner); revert the source-sheet diff to remove it, no data migration.
  - Acceptance: the source sheet has a "Återhämta från källa" action that re-fetches/re-feeds per `SourceArtefactType` and replaces the parsed fields · re-extract preserves the recipe's `id`, `createdAt`, and `sourceArtefact` metadata · a confirmation dialog ("Det här skriver över dina ändringar") gates overwrite when the recipe has user edits · re-extract failure leaves the existing recipe untouched (error toast, no partial write) · the stale-source banner appears when `fetchedAt` is older than 30 days
  - Sign-off: the overwrite confirmation copy + behavior (overwrite vs append) on a recipe the user has hand-edited.

### Needs you (not built — flagged for your call)
- **BUT-653** — parameterize import daily/monthly caps by user *tier*. Presupposes a freemium tier system + `EntitlementService` that doesn't exist; memory says no monetization decisions yet. Recommend: **drop** until monetization is decided — building tier-keyed Remote Config now is speculative scaffolding for an undecided model.
- **BUT-656** — same as above for the OCR monthly cap (`OCRUsageTracker.freeMonthlyLimit`, currently a display-only in-memory counter; server-side limits are authoritative). Recommend: **drop** with BUT-653 — revisit both together when tiers are real.
- **BUT-684** — handwritten-specific OCR path. `idea`; needs a choice between auto-detect-handwriting (heuristic) vs a "this is handwritten" UI toggle, plus prompt tuning that can't be verified without a handwritten-scan corpus. Recommend: **reframe** — decide toggle-vs-autodetect first; the toggle version is a small, verifiable build once you pick it.
- **BUT-941** — accept OS multi-share (Android `SEND_MULTIPLE` + iOS multi-file). Touches native Android manifest + the iOS share extension (platform/ops surface), and demand is speculative. Recommend: **defer** until there's a concrete request — the native-config blast radius isn't worth it for an unvalidated flow.

### Obsolete (done in git, still open in Linear)
- None. No import-labeled ticket appears resolved in the last 7 days of git history.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests (text-import VM, url-import VM, photo-import VM, ocr extraction, import strategies)
- [ ] Phase 2.7 outcome-grading (fresh-context verifier per agent group)
- [ ] Commit, push
- [ ] Linear: all five (BUT-1040, BUT-931, BUT-947, BUT-903, BUT-1205) are build-review → In Review + notify; none auto-close to Done

---
## ARCHIVED — iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266 Tier A, BUT-1220/1000/949 Tier B; BUT-1265 obsolete-closed) · iter-149 (BUT-1265 conflictStream end-to-end delivery test — landed `f37c9af03`) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — HEAD d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path sign-off) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
