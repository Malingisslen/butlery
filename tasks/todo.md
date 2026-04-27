# Sprint Backlog

## Sprint: Security rules tighten + repo-layer close-out + OCR fixes — 2026-04-27

Theme: drain the High-priority security/permissions cluster while one agent finishes the Firestore-bypass migration started in BUT-498's sister ticket BUT-501. Cloud Functions agent fixes the OCR fileData URL gap and the no-op preprocess stub. Flutter agent audits user-facing network calls. **4 agents, 8 tasks, isolated file trees** (rules · services/account · functions/src/ocr · widgets/views).

Prior sprint (`6521fff96` + follow-ons `308b87a76`/`eadcd0cdf`/`1127c85a5`/`8ac8e654e`/`5b6fe488a`) shipped. Carry-overs **BUT-498** (5 deletion files) and **BUT-697** (a11y chunk-3) explicitly skipped this sprint per user direction; both stay In Progress in Linear.

Linear hygiene flipped at sprint kickoff: BUT-450, BUT-635, BUT-419 → Done (work shipped in prior commits, status was stale).

### Agent A: firebase-backend-security — Security rules tighten

- [x] **A1. Fix `audit_logs` read rule** — done. `firestore.rules` `audit_logs/{logId}` read changed from `request.auth.uid == resource.data.userId` to `isAdmin()`; create unchanged; update/delete denied. New `functions/src/__tests__/audit-logs-rules.test.ts` with 8 cases (admin allow-read, regular-user deny-read, anon deny-read, anon deny-write, server-side allow-write, self-create regression, forge-uid deny, immutability). Tests not run locally (Java/emulator missing); type-check clean. **Follow-up:** GDPR Art-15 export needs admin-SDK Cloud Function — client `compliance_export_manager.exportAuditLogs(userId)` now perm-denied; outer catch returns `{error, note}` so the broader export job continues. (BUT-424)
- [~] **A2. Tighten `recipe_comments` read rule** — PARTIAL by design. `firestore.rules` `recipe_comments` read rewritten: gate on `authorId || recipeOwnerId || sharedWithUserIds` + admin-moderation override; create rule extended with optional blocking-gate (couples to A3). Model gained `recipeOwnerId: String?` + `sharedWithUserIds: List<String>` (`lib/models/recipe_comment.dart`); `firebase_comments_repository.dart` accepts optional `RecipeOwnershipResolver` typedef and populates fields on `addComment`. New `functions/src/__tests__/recipe-comments-rules.test.ts` with 8 read tests (4 deny, 3 allow, 1 admin moderation). **Deferred (partial-by-design):** (1) DI wiring of production resolver in `lib/core/di/modules/social_module.dart` — until wired, new comments still write without denorm fields and read as author-only; (2) backfill Cloud Function under `functions/src/migrations/` to stamp the new fields on existing comment docs (pattern documented in knowledge file). Reason for partial: shipping rules + backfill in same sprint risks coordinated-deploy race. (BUT-458)
- [x] **A3. Extend `isNotBlockedBy` to comment + notification creates** — done. `firestore.rules`: `recipe_comments` create + `recipe_ratings` create + `user_notifications` create cross-user branch all gated by `isNotBlockedBy(...)`; self-notifications still bypass. `RecipeRating` model gained optional `recipeOwnerId`. 6 new tests in `recipe-comments-rules.test.ts` (block deny + non-block allow per surface; self-notify regression). Backwards-compatible-by-field-presence so legacy comments without `recipeOwnerId` aren't broken. **Follow-up:** `FirebaseRatingsRepository.rateRecipe()` should populate `recipeOwnerId` to actually trigger the gate (gate currently field-presence-conditional). (BUT-459)

### Agent B: firebase-backend-security — Repo-layer + token cleanup

- [~] **B1. BUT-501: data-export managers off direct Firestore (7 files)** — PARTIAL by design (matches BUT-498's 4-of-9 playbook). Migrated 8 collections / 5 repos extended: `recipe_comments`, `recipe_ratings`, `feedback`, `cook_snaps`, `activity_events`, `weekly_menu_plans`, `group_weekly_menu_plans`, `pantry`. Each new repo method has `validateOwnership` guard. **Residual direct-Firestore (28 calls)**: `content_export_manager.dart` (7 — recipes/menus/shopping_lists/personal_tags), `social_export_manager.dart` (11 — friends/social_requests/conversations/messages/blocks), `compliance_export_manager.dart` (3 — audit_logs broken at rules layer per A1, user_consent), `preferences_export_manager.dart` (7 — settings/notifications/fcm_tokens), `data_export_service.dart` (2 — `_exportUserProfile` reads `users/{uid}` + `public_profiles/{uid}`). All documented in knowledge file. `flutter test test/unit/services/account/data_export_service_test.dart` 15/15 green. (BUT-501)
- [x] **B2. Eliminate FCM token SharedPreferences fallback** — done. Audit confirmed `FlutterSecureStorage` was already exclusive (SP risk was historical — `_tokenStorageKey` constant survived). Hardened against regression + added defensive one-time SP→SecureStorage migration helper for older builds, sentinel-gated. Annotated `_saveTokenLocally()` with explicit "MUST NOT mirror to SharedPreferences" contract. 3 new BUT-457 tests (migration scrubs SP + sentinel idempotency + Firestore-failure no-SP-write). 20/20 green. (BUT-457)

### Agent C: cloud-functions-specialist — OCR fileData URL validation

- [x] **C1. Validate OCR Gemini fileData URLs** — done. New `functions/src/shared/ocr-url-validator.ts` (291 lines): host pin to `<project>.firebasestorage.app` + legacy `<project>.appspot.com` (project ID resolved from `GCLOUD_PROJECT` env with `butlery-app-1` literal fallback for test). **Bucket path component pinned** (defeats Google-domain → arbitrary-public-bucket attack). HEAD pre-flight with `redirect: "manual"` (defeats 30x-to-evil-host bypass), Content-Length ≤ 10MB, Content-Type allowlist (`image/jpeg|png|webp|heic`, `application/pdf`). **Audit log omits the URL itself** (Firebase Storage URLs carry `?token=` bearer credentials) — logged: origin + contentType + contentLength + authUidHash. New `functions/src/__tests__/ocr-validation.test.ts` (621 lines, 21 tests, all green). Native Node 22 `fetch` — no new dep. Existing `isAllowedUrl()` SSRF check preserved as fast-fail. Full `npm test` chain green; `npm run build` (tsc strict) zero errors. (BUT-425)

### Agent D: flutter-developer — Client OCR preprocessing + network resilience

- [x] **D1. Implement client-side OCR `_preprocessImage`** — done. Located at `lib/services/ocr_extraction_service.dart:525` (was a no-op stub). All 4 steps applied: `bakeOrientation()` for EXIF rotation, `copyResize` linear interpolation to ≤2048px long edge (aspect preserved, no upscale), `grayscale()` + `contrast(115)` (~1.15×), JPEG re-encode q=85. Defensive: `decodeImage` wrapped in try/catch — corrupted bytes (the existing `OCRTestImages.invalidFormat` fixture) trigger an internal `RangeError` in the `image` package's ICO detector; falls back to original bytes. **Pubspec:** added `image: ^4.3.0` (pinned 4.3.x; 4.5+ requires `archive ^4.0.7` which conflicts with project's `archive: ^3.6.1`). 8 new tests in `test/unit/services/ocr_preprocess_test.dart` including a tagged-orientation-6 sideways JPEG (200×100 → 100×200 after preprocess). Existing 117 OCR tests still green. (BUT-652)
- [x] **D2. Network resilience audit on user-initiated calls** — done. New `lib/utils/retry_policy.dart` — top-level `withRetry<T>()` (chose top-level over mixin since call sites are async functions, not class methods). 3 attempts default, exponential 1s/2s/4s with ±25% symmetric jitter, max-delay cap 30s. Default `isRetryable`: `SocketException`, `TimeoutException`, `HttpException`, `http.ClientException`, `FirebaseException` codes `unavailable`/`deadline-exceeded`/`internal`. Does NOT retry `permission-denied`, `not-found`, validation, cancellations. Test injection points (`random`, `sleeper`) make tests deterministic. 11 tests, all green. **Wrapped 3 idempotent call sites:** image upload (`uploadImageFromBytes` in `image_upload_service.dart`), recipe save (`saveRecipeRaw` + `updateRecipe` in `personal_recipe_crud.dart`), share-extract (`_webScraper.performExtraction` in `extraction_manager.dart`). **Flagged non-idempotent (NOT wrapped):** `personalModule.createPersonalRecipe(...)` generates server-side doc IDs — needs client-generated UUID or server-side dedup-on-idempotency-key before retry-safe. UX surface: new `showErrorSnackbarWithRetry` helper in `snackbar_widgets.dart` + `utility_components.dart` using existing l10n key `commonRetry` ("Försök igen"); wired to `skriv_sjalv_recept_view.dart` save-failure path. 3 other views could migrate to retry variant — left as mechanical follow-up. (BUT-726)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test` (rules tests + repo tests + retry helper tests)
- [ ] `cd functions && npm test`
- [ ] Commit, push to main
- [ ] Update Linear: completed sprint tickets → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-426 (iOS half) / BUT-646 / BUT-714 — store/play submission deferred
- BUT-498 / BUT-697 — explicitly skipped this sprint, remain In Progress

---

## What this means in plain language

- **Comments and audit logs get safer.** Today any logged-in user can read every comment in the app, and users can read their own audit trail (which they shouldn't). This sprint locks both down.
- **Block-lists actually work everywhere.** Today, blocking someone stops them messaging you but not commenting on your recipes or sending you notifications. After this sprint, blocking blocks everything.
- **Account-export finishes routing through the secure layer.** Same pattern as last sprint's deletion work, applied to the GDPR-export path. No user-visible change — but the export-my-data path stops bypassing the safety net.
- **Recipe scanning gets sharper.** OCR currently skips image cleanup entirely. Adding contrast/deskew/grey-scale should noticeably improve "I scanned a cookbook page and it got 80% right" → closer to 95%.
- **Recipe scanning gets safer too.** A small backend hole let arbitrary URLs be forwarded to Google's OCR — now validated for size and content-type first.
- **Image upload, recipe save, and share-import stop failing on flaky wifi.** Adds 3-attempt retry with backoff, then a clear error if it really fails.
- **Risk: low.** A1-A3 are rules-only and proven via deny-tests before merge. B1 follows the playbook last sprint validated. B2 removes a fallback, so worth a manual smoke-test on token rotation. C1-C2 are server-side only. D1 is additive. Easy to revert any single task — git reset of one commit per task.

---

## Archived Sprint: Performance + a11y chunk-2 + repo-layer cleanup — 2026-04-27 (shipped `6521fff96`)

Theme: pre-launch hardening backlog is drained — pivot to visible performance wins + a11y chunk-2 close-out + one architectural debt while paperwork stays user-blocked. 4 agents, 9 tasks, isolated file trees.

**Sprint outcome:** 7 tasks completed, 1 partial (C2 / BUT-498), 3 verified-already-complete (B2/B3/C1 — work landed in prior commits). Net new code: a11y wraps on 7 widgets + 12+ heading-flag wrappers + ingredient-cache layer + 4 repo migrations on account-deletion path + cursor-pagination on recipe repo + GCS versioning script/runbook.

Tickets shipped: BUT-697 (chunk-2 closed; chunk-3 remaining), BUT-699, BUT-476, BUT-481 (verified done), BUT-469 (verified done), BUT-499 (verified done), BUT-498 (partial — 4 of 9 collections migrated; carry-over), BUT-484, BUT-419 (script + activation).

Continued blockers from prior sprint: BUT-426 (Android done in `308b87a76`, iOS deferred), BUT-450 (activated in `8ac8e654e`), BUT-714 (Apple Team ID), BUT-415 (privacy hosting), BUT-646 (Play Data Safety filing), BUT-419 (activated in `1a08d1acd`).
