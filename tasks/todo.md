# Sprint Backlog

## Sprint: ops-docs + square-snackbars + parse-confidence-surface + large-file-decomp — 2026-06-13 (iter-142)

Full backlog scan: 98 workable tickets (36 A-CLEAN / 38 B-UI / 8 C-REFACTOR / 16 D-BLOCKED). Tier-A clean work is scarce (drained iter-103→141); this batch is docs + UI + refactor, the volume areas.

### Agent A: ops-docs reconciliation — observability & residency docs
- [x] **A1. SLO_DEFINITIONS.md with numeric targets** `[Tier A]` — create `docs/operations/SLO_DEFINITIONS.md`: 6 SLO targets (Firestore p50/p95 latency, crash-free sessions, FCM delivery, OCR success, Vertex success, signup-funnel) each with numeric value + target source + burn-rate alert threshold + measuring query/dashboard. (BUT-879)
  - Acceptance: all 6 targets have a numeric value AND a named source (historical-p95 / business-commitment / Google-default) · each target names a burn-rate alert threshold · each target names the dashboard/query that measures it · any number requiring a 30-day metrics baseline is explicitly flagged "provisional — confirm against baseline" rather than presented as measured
- [x] **A2. Reconcile retention + residency doc drift** `[Tier A]` — grep `europe-west3` across `docs/` → reconcile to canonical `europe-west1`; consolidate duplicate `data-residency.md` (delete/redirect stale `docs/ops/` copy toward canonical `docs/operations/`); remove "USER MUST VERIFY" placeholders; confirm `docs/security/audit-logs-retention.md` matches `functions/src/audit_logs/` scheduler config. (BUT-881)
  - Acceptance: zero `europe-west3` references remain in `docs/` (grep proves it) · only one canonical `data-residency.md` survives, stale copy deleted or redirected · zero "USER MUST VERIFY" placeholders remain · backup-retention number reconciled to one value across docs, with the one needing console confirmation explicitly flagged

### Agent C: design-system — square the global SnackBar (continues BUT-1237 dialog work)
- [x] **C1. Square global SnackBar shape** `[Tier B]` — set square shape in the global `snackBarTheme` (`lib/theme/components/feedback_themes.dart:19`); remove/square the per-call `RoundedRectangleBorder` override in `lib/core/utils/snackbar_utils.dart:330`; verify mockup §4.18 colors (green-dark bg, cream text) while in there. (BUT-1243)
  - Acceptance: global snackBarTheme.shape is square (RoundedRectangleBorder zero radius or square) · grep shows zero rounded `borderRadius` on SnackBar shape anywhere · §4.18 toast colors confirmed/noted in In-Review comment · HTML preview of representative snackbars (undo flow, success toast) → In Review

### Agent D: import feature — surface per-ingredient parse confidence
- [x] **D1. Thread ParsedIngredient confidence to a review UI** `[Tier B]` — Step 0: confirm which live import path emits `ParsedIngredient` with `.confidence` (CRF path produces it). Thread `List<ParsedIngredient>` (not flattened strings) into a review widget on that flow; render green/amber/grey confidence pill per item + original line on expand. (BUT-925)
  - Acceptance: a real import flow exposes `ParsedIngredient` to the UI with `.confidence` intact (not flattened to String) · a confidence pill renders per ingredient in the review surface · the original parsed line is viewable per item (expand/long-press) · widget test pins the pill renders the correct color per ParseConfidence enum value · HTML preview → In Review

### Agent E: refactor — decompose 2 drifted large files `[Tier C]` (always risk-gated)
- [x] **E1. Decompose smart_import_view + user_profile_edit_view** `[Tier C]` — `lib/views/smart_import_view.dart` (817→under baseline 620) and `lib/views/social/user_profile_edit_view.dart` (832→under baseline 634) via facade/sub-widget extraction (pattern: `lib/views/mina_recept/`, `lib/viewmodels/recipe_form/`); update `ACCEPTED_LARGE_FILES.md`. (BUT-1154)
  - Acceptance: both files dropped under their original baseline (620 / 634) OR a much-tightened justification recorded · `ACCEPTED_LARGE_FILES.md` reflects post-decomp sizes · `dart analyze --fatal-infos` clean · existing tests still pass; no behavioral change (pure extraction)

### Needs you (Tier D — flagged, not worked)
- BUT-840 — Algolia search-index freshness needs an Algolia **admin** API key provisioned as a backend secret (functions/ has zero Algolia client today; index is written client-side). Both ticket options require backend admin write access to Algolia. Action: provision `ALGOLIA_ADMIN_KEY` secret + decide CF-vs-scheduled-reindex, then it's workable.
- Prior ops cluster (BUT-451/486/492/813/814/880/889/1166/1229) — console/creds/enrollment, unchanged.

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos`
- [x] Run relevant unit tests
- [x] Phase 2.7 outcome-grading per agent group
- [x] Follow-ups → Linear BEFORE commit
- [x] Commit, push
- [x] Linear: Tier A (879, 881) → Done; Tier B/C (1243, 925, 1154) → In Review + notify

---
## ARCHIVED — iter-141 (BUT-1238/1005/1237/928/604/954 done; 4 Done-bound, 2 In-Review-bound) · iter-140 (BUT-1235/1236/839/877 Done, BUT-999 In Review; follow-ups BUT-1238/1239) · iter-139 (BUT-838/694/1234 Done) · iter-138 (BUT-956 In Review, 3 Done) · äldre i git-historiken
