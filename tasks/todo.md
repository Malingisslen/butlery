# Sprint Backlog

## Sprint: wave-8 — LLM golden-set foundation + cascade-audit sweep + UI migration P1 + privacy drafts — 2026-05-21 (Th)

Theme: clear wave-7 follow-ups (BUT-886, BUT-887, BUT-882 all filed today) + start the Urgent LLM-quality gate (BUT-784) scoped to a foundation pass. Defers BUT-782 (660-line FCM refactor) and BUT-877 (model fail-close, blocked on prod) to wave-9.

### Agent A: testing-specialist — LLM golden-set foundation (1)
- [ ] **A1. BUT-784 (URGENT — rescoped)** — build foundation, not full corpus.
  - Create `test/golden/llm/` with `_runner.dart` harness + JSON-schema for golden cases.
  - Build 2 cheapest corpora first (run on-device, no LLM cost):
    - `ner/` — 50 sentences + expected entity spans (use existing `_expected_model_hashes.dart` model)
    - `categorize_ingredient/` — 100 ingredient strings + expected category (use existing classifier)
  - Add `.github/workflows/golden-llm.yml` — nightly cron, runs the 2 corpora, posts results to Crashlytics non-fatal on regression.
  - Cost-guard placeholder: scaffold tokens_in + tokens_out tracking shape, even though current 2 corpora are on-device (free).
  - Docs: `docs/testing/llm-golden-tests.md` — how to add cases, update expected outputs, interpret regressions.
  - **File follow-up Linear ticket** for remaining 4 corpora (`recipe_from_url`, `ocr_recipe`, `enhance_recipe`, `generate_menu`) — each requires real LLM calls + tolerance windows + cost-guard wiring.

### Agent B: firebase-backend-security — cascade-audit + Dart repo gaps (1)
- [ ] **B1. BUT-886 (MEDIUM)** — two-part follow-up to BUT-455.
  - **Part A:** Wire `stageCascadeAuditEntry` into 10 remaining ops in `functions/src/cleanup/on-user-deleted.ts`:
    - `cleanupSocialRequests` (line 396), `cleanupGroupMemberships` (442), `updateFriendCounts` (455), `cleanupPresenceRows` (507), `cleanupNotificationQueues` (308), `cleanupLegacySharedWithArrays` (264), `cleanupContentGuardSubcollections` (213), `tombstoneSharedByDisplayName` (158), `anonymizeReportsByContentOwner` (563), `cleanupFeedback` (594).
    - Extend `cascadeArrayRemove` in `shared/batch-update` with optional `onChunkOp(batch, doc)` callback so chunked ops emit audit rows in the same write batch.
    - Operations: most are `cascade_delete`; `tombstoneSharedByDisplayName` + `anonymizeReportsByContentOwner` are `cascade_anonymize`.
    - Add at least one Firestore emulator integration test exercising end-to-end cascade.
  - **Part B:** Close 4 Dart repo gaps from wave-7 audit:
    - `lib/repositories/firestore_repository.dart` — biggest gap, add `PermissionValidationMixin` + `logPermissionCheck` at each write site
    - `lib/repositories/parsing_correction_repository.dart` — verify write surface, add mixin or document bypass
    - `lib/repositories/site_config_repository.dart` — verify write surface, add mixin or document bypass
    - `lib/repositories/algolia/algolia_search_repository.dart` — feature-flagged off; add mixin scaffold or document deferred until enable

### Agent C: flutter-developer — UI migration Phase 1 (1)
- [ ] **C1. BUT-882 (MEDIUM)** — Phase 1 of BUT-798 coordinator.
  - Grep all `Center(child: CircularProgressIndicator())` in `lib/views/` (~25 sites).
  - Replace with `StateWidget.loading()` (full-screen) or `LoadingIndicator()` (inline) per decision tree in `lib/widgets/CLAUDE.md`.
  - Visual smoke on 3 representative screens (recipe-list, friends-list, account-deletion).
  - Confirm zero new raw `CircularProgressIndicator(` introduced in `lib/views/`.
  - Do not touch `lib/widgets/` — that's Phases 2-4.

### Agent D: claude (inline) — privacy policy drafts (rescoped) (1)
- [ ] **D1. BUT-887 (MEDIUM — rescoped)** — write the policy text NOW; defer hosting.
  - Create `docs/legal/privacy_policy.md` (English) + `docs/legal/privacy_policy_sv.md` (Swedish):
    - LEGAL8: on-device ONNX disclosure section (ingredient NER + line classifier — text/images NOT transmitted)
    - LEGAL9: processor list — Google Cloud (Firestore, Auth, Storage, CF, Vertex, Vision, reCAPTCHA), Crashlytics, Firebase Analytics/GA4. Mark Algolia + RevenueCat as "deferred — not yet active".
  - Create `docs/legal/tos.md` + `docs/legal/tos_sv.md`:
    - LEGAL5: deletion timeline section ("30 days; audit logs 365 days; backups 30 days").
  - **File follow-up Linear ticket** for hosting (depends on BUT-680 web landing) + in-app URL wiring.

### Step 0 — defer / re-check (2)
- [~] **BUT-782 (Urgent)** — DEFER to wave-9. 660-line static-singleton refactor needs a dedicated focused sprint; bundling with the 4 above creates review fatigue. Will leave in Todo state. **Step 0 verification before wave-9 starts:** re-grep `fcm_service.dart` mutable static fields to confirm scope.
- [~] **BUT-877 (Backlog)** — Still blocked (no Firebase Storage access this session to verify `latest_version.txt` registries). Leave in Backlog. **Step 0 verification before re-pick:** check whether a CI job has been added that enforces hash-registry coverage.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 reviewer markers — `code-reviewer` (.dart files), `testing-specialist` (lib/*.dart), `firebase-backend-security` (B1 repos + cascade CFs), `firestore-rules-tester` (if rules touched — unlikely in wave-8)
- [ ] File follow-up Linear tickets (mandatory before commit):
  - BUT-784 4 remaining LLM corpora
  - BUT-887 hosting + URL wiring (depends BUT-680)
  - Any reviewer-flagged "out-of-scope" findings
- [ ] Commit (inline) + push direct to main
- [ ] Close Linear tickets BUT-784/886/882/887 (done)
- [ ] CI watcher

---

## Archived prior sprint (commit 5bd98f8e8 / 7ed82246c)

wave-7 — analytics wiring + repo-audit security + privacy docs + dedup pass — 2026-05-21 (Th) — BUT-878/455/811/798 shipped. BUT-875/829/859 closed as obsolete/duplicate. BUT-877 still open (blocked on prod).

## Archived two-sprints-ago (commit 273152149)

wave-6 — model-integrity test contract fix + cooking-mode analytics + ops runbooks — BUT-876/802/452 shipped. BUT-874 closed as premise-gone.

## Archived three-sprints-ago (commit b66f5892f)

wave-5 — image-quality OCR gate + test-gap closures + adoption metric — BUT-660/872/865/866/873 shipped.

## Archived four-sprints-ago (commit 90d88cfca / b115d7519)

wave-3 follow-ups + UI consolidation continuation — BUT-868/869/870/871/867/776/864.

## Archived five-sprints-ago (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
