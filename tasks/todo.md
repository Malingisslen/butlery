# Sprint Backlog

## Sprint: mixed batch (test-gap + tooling + photo-import gating) — 2026-05-19 (Tu) wave 5

Theme: 5 small/medium tickets after Step 0 triage shrunk the initial 9 → 5 (premise-gone closures + 1 deferred). Heavy on wave-3/wave-4 follow-ups (BUT-872/865/866/873) plus one user-facing photo-import gating change (BUT-660).

### Agent A: testing-specialist — test-gap closure (3)
- [ ] **A1. BUT-872** — extend `test/unit/services/parsing/model_manager_integrity_test.dart` with a transient `FirebaseException` mid-download scenario. Custom throwing `Reference` (subclass `MockReference` from `firebase_storage_mocks`). Assert `ensureModelAvailable()` returns `null` and cache dir has no committed/`.tmp` files. Both `NerModelManager` and `LineClassifierModelManager`.
- [ ] **A2. BUT-865** — extend `test/unit/services/account/data_export_service_test.dart` with a "page #1 succeeds, page #2 throws transient" scenario. Inspect current behavior in `compliance_export_manager.dart:92-178` — the `try/catch` wraps the whole pagination loop, so any throw discards partial rows. Test pins this contract (or surfaces a refactor opportunity if partial-recovery preferred).
- [ ] **A3. BUT-866** — add a doc comment + `assert(T == Map<dynamic, dynamic>)` to `_EmptyHttpsCallable.call<T>` in `data_export_service_test.dart` (line ~54). Trivial test-only hardening.

### Agent B: backend hygiene — tools/measure_adoption.dart (1)
- [ ] **B1. BUT-873** — extend `tools/measure_adoption.dart` to count `with PermissionValidationMixin` across `lib/repositories/firebase/*_repository.dart` (mirror the existing `ErrorHandlingMixin` pattern). Add a row in the generated `docs/architecture/adoption-status.md` table next to `BaseFirebaseRepository`.

### Agent C: photo-import gating (1)
- [ ] **C1. BUT-660** — convert image-quality advisory thresholds in `lib/services/ocr_extraction_service.dart` (`assessImageQuality` at line 548) into a hard reject for the worst tier (resolution < 600px short edge OR quality score < 0.3). Wire the rejection through `PhotoImportStrategy` so OCR is skipped. Surface a Swedish error: "Bilden är för suddig eller för liten — försök igen i bättre ljus." Keep mid-tier (0.3–0.6) advisory-only.

### Step 0 — obsolete tickets to close (3)
- [~] **BUT-479** — premise gone. File `lib/repositories/firebase/friend_relationship_repository.dart:342` doesn't exist; `firebase_friends_repository.dart` has zero `.limit(1000)` calls. The repo was refactored away from the pattern the audit cited.
- [~] **BUT-843** — premise gone. Re-grep of `lib/repositories/firebase/` for `FieldValue.serverTimestamp()` yields only 2 sites (`base_metadata_repository.dart:101`, `firebase_category_preferences_repository.dart:221`), both inside single `.set(...)` calls — neither is a batch write. The pattern the audit cited no longer exists.
- [~] **BUT-858** — premise gone. Strict `Center(child: CircularProgressIndicator())` pattern returns 0 matches in `lib/views/`. The 5 specific sites cited in the ticket body (`moderator_review_view`, `community_guidelines_view`, `terms_of_service_view`, `recipe_detail_view:173, 273`, `notifications_view:83`) either no longer contain `CircularProgressIndicator` or are contextual placeholders (image-load spinner inside hero container, pagination footer) — not screen-level loading states. Phase 1 of BUT-798 is effectively complete in views.

### Step 0 — deferred (1)
- BUT-840 — needs `algoliasearch` npm dep in `functions/package.json` + a CF secret `ALGOLIA_ADMIN_API_KEY` set via Firebase console (external ops). Half-shipping the code without the secret would break the CF trigger. Deferring to its own bundled sprint when Algolia admin setup is in scope.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews — code-reviewer (.dart), testing-specialist (lib/*.dart) — markers written before commit
- [ ] File follow-ups in Linear (mandatory before commit, see Follow-up rule)
- [ ] Commit (inline) + push direct to main (solo workflow)
- [ ] Close Linear tickets BUT-872/865/866/873/660 (done) + BUT-479/843/858 (obsolete)
- [ ] CI watcher

---

## Archived prior sprint (commit b115d7519 / 90d88cfca)

wave-3 follow-ups + UI consolidation continuation — 2026-05-19 (Tu) wave 4 — BUT-868/869/870/871/867/776/864 shipped. Golden test path_provider + sqflite stubs added. Follow-ups BUT-872/873 filed (now this sprint).

## Archived two-sprints-ago (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — 2026-05-19 (Tu) wave 3 — BUT-861/579/801/841/825/823 shipped.
