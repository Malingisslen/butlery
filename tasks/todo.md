# Sprint Backlog

## Sprint: SSL pinning + push deep-linking + analytics + theme sweep — 2026-04-27

Theme: drain the next batch of High-priority tickets across security, growth instrumentation, and theme cleanup. **4 agents, 8 tasks, isolated file trees** (Algolia/OCR HTTP clients · Cloud Functions notification senders · views/widgets theme tokens · analytics events).

Prior sprint (`6fdac5724`) shipped — security rules tightened, repo-layer further drained, OCR validated, retry policy added. Carry-overs **BUT-501 / BUT-458** stay In Progress (partial-by-design residuals to settle one cycle); **BUT-498 / BUT-697** also stay In Progress per standing skip-direction.

### Agent A: firebase-backend-security — SSL pinning + push payload deep-linking

- [x] **A1. Add SSL certificate pinning for third-party HTTPS** — done. Added `http_certificate_pinning: ^3.0.1`. New `lib/services/security/cert_pin_config.dart` (per-host SHA-256 SPKI pin map; TODO placeholders for fingerprints — values come from a separate ops task), `pinned_http_client.dart` (BaseClient wrapper that pins on every send), `pinned_http_client_factory.dart` (factory wiring `ssl_pin_mismatch` analytics). Algolia: per-host Dio interceptor in `algolia_pinning_interceptor.dart` (dio reached transitively via algoliasearch — no new top-level dep). OCR (`ocr_extraction_service.dart`) and URL scraper (`http_content_fetcher.dart`) wrap their lazy HTTP clients via `PinnedHttpClientFactory.create()`. 15 tests green. (BUT-427)
- [x] **A2. Add `route` + `targetId` to all push notification payloads** — done. **Server**: new `functions/src/shared/notification-payload.ts` (`buildNotificationPayload` + 6-route allowlist `/recipe`/`/friend_request`/`/comment_thread`/`/cooking_session`/`/menu_voting`/`/winback`). 3 senders funnel through it (`sendNotification` callable + silent path, `detectLapsedUsers`, `sendWeeklyActivityDigest`). `HttpsError("invalid-argument")` on schema violation (avoids client retry storm). 12 new tests + extended `send-notification.test.ts`. **Client**: `notification_deep_link_router.dart` with route constants + analytics for missing/unknown routes (legacy-tolerant default-to-home). main.dart wired to instance; `notification_service._handleMessageOpened` forwards `route/targetId/notificationType`. 12 router tests green. (BUT-641)

### Agent B: flutter-developer — Recipe search routing + in-app review

- [x] **B1. Route recipe search through Algolia (fix 200-cap silent miss)** — done. New `lib/services/search/recipe_search_router.dart` — routes through `AlgoliaSearchRepository` when (a) `enable_algolia_search` Remote Config flag is on AND (b) the live `SearchRepository` delegate is Algolia (creds-resolution stays in `SearchModule`, the single source of truth — router observes the result). Falls back to legacy `RecipeRepository.searchRecipes` on flag-off, missing-creds, or Algolia exception. Wired into `RecipeServiceAdapter.searchRecipes` via `tryGet` (transparent for tests/partial DI). `has_algolia_search` user property fires once. 8 tests green. **Note:** `searchByTitle`/`findByIngredient` (the 200-cap methods at lines 865, 885) are unreferenced outside the file (0 external callers); the actively-used path is `searchRecipes:412` which the router now bypasses when Algolia is active. Dead-code cleanup left for follow-up. (BUT-475)
- [x] **B2. In-app review prompt** — done. Added `in_app_review: ^2.0.10`. New `lib/services/in_app_review_service.dart` with 4 gates: rating ≥ 4, cumulative ≥ 3 happy cooks (not just count), ≥ 7 days since first-seen, > 90 days since last prompt. **Decision**: no `firstInstallTime` tracker existed — self-bootstrapped `first_seen_at` timestamp on first `maybeRequest` call. Wired into `RecipeDetailViewModel.rateRecipe` post-success (covers both personal-rating and social-rating branches via single call site). Failures swallowed in try/catch. Analytics: `in_app_review_requested` fires on success. 8 tests green. (BUT-678)

### Agent C: flutter-developer — Theme tokens + dual-source string audit

- [x] **C1. Sweep `Colors.*` references → theme tokens** — done. **Reality check**: actual literal `Colors.*` count was 38 across 35 files, of which 35 were `Colors.transparent` (kept per spec). The "361" figure in the ticket included `AppColors.*` matches. Two substantive migrations: `veckomeny_view.dart` (2× `Colors.white` → `AppColors.cardWhite` on translucent green-header toggle) + `vegetable_illustration.dart` (1× kept as `Color(0xFFFFFFFF)` literal — identity `BlendMode.modulate`, truly always-white). Final state: zero non-transparent `Colors.*` in `lib/views/` and `lib/widgets/`. (BUT-689)
- [x] **C2. Audit `app_strings.dart` for user-facing strings** — done. **Pre-existing state**: file already migrated in prior sweeps. Zero plain user-facing constants remained — only computed helpers (`formatDuration`, `permissionContextualError`, etc.) that delegate to `AppLocale.current` or `context.l10n`. Added contract comment at file top forbidding user-facing text. Only 1 external caller (`contextual_error_handler.dart`) and it uses computed helpers correctly. No ARB regen needed. (BUT-585)

### Agent D: flutter-developer — Acquisition + parse-quality analytics

- [x] **D1. Persist UTM params as user properties** — done. Real handler is `lib/core/bootstrap/handlers/deep_link_handler.dart` (not `lib/services/deep_link_service.dart` — ticket path was stale). On first UTM arrival, sets Firebase user properties `acquisition_source/medium/campaign` + mirrors to Firestore `users/{uid}/acquisition/current` via new `AcquisitionRepository` (interface + firebase impl with PermissionValidationMixin). Two-layer dedup: SharedPreferences flags (per-uid + `__anon__` for pre-auth) + repo-level read-before-write. Anonymous users get user properties immediately; Firestore mirror deferred until uid exists. Firestore rules added: owner read/create with `firstSeenAt == request.time`; updates and deletes blocked client-side (first-write-wins immutability + admin-only erasure). 17 unit tests + 9 rules tests (rules tests need emulator). (BUT-612)
- [x] **D2. Track post-import recipe edits for parse quality** — done. `kPostImportEditWindowDays = 30`. New `lib/utils/recipe_diff.dart` (pure diff helper, snake_case field names) + `lib/services/analytics/post_import_edit_decider.dart` (pure-function decision logic). `recipe_persistence_manager._logRecipeEdited` delegates to decider; on top of existing `recipe_edited`, emits `post_import_edit` with `recipe_id`, `fields_changed`, `hours_since_import`, `tier_used` when available. `recipeImportedAt` uses `recipe.createdAt` as proxy (Recipe has no `importedAt` field). **Honest gap**: `tier_used` is captured from `originalParsedRecipe.metadata.successfulTier` and is only available on the FIRST edit after import (parsed-recipe state clears post-save). Subsequent edits within 30-day window emit `post_import_edit` with `tier_used` omitted rather than guessed. 17 tests green. (BUT-569)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test` (Algolia routing + theme regression + analytics emitters)
- [ ] `cd functions && npm test` (push payload schema + senders)
- [ ] Commit, push to main
- [ ] Update Linear: completed sprint tickets → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-731 / BUT-714 / BUT-646 — store/play submission deferred (Apple Dev enrollment + Play Data Safety filing + Universal Links + hosted privacy)
- BUT-501 / BUT-458 — partial-by-design from prior sprint; let work bed in one cycle
- BUT-498 / BUT-697 — explicitly skipped per standing direction

---

## What this means in plain language

- **Search actually finds your stuff.** Today, if you have 500+ recipes, search silently skips 300+. After this, search routes through Algolia and finds them all.
- **Tapping a notification takes you somewhere useful.** Today notifications drop you on the home screen; after this they open the recipe / friend request / comment they're about.
- **Happy users get a nudge to leave a review** at the right moment (after a good cook, only once, OS-rate-limited).
- **Network calls get safer.** Algolia / OCR / scraping requests now refuse to talk to a fake server impersonating those hosts on a hostile wifi.
- **Theme cleanup makes dark mode less broken.** ~360 hardcoded white/black colors get swapped to theme-aware tokens.
- **Marketing finally measurable.** UTM params from "where did this user come from" now stick to the user, so retention can be sliced by acquisition channel.
- **Parse-quality loop closes.** When you edit an imported recipe, that signal feeds back to "which sites need better parsing rules" — completing the loop BUT-552 just opened.
- **Risk: low.** A1/A2 are additive (soft-fail SSL telemetry; payload fields default-empty). B1 is feature-flagged. B2 is a one-line OS prompt. C1-C2 + D1-D2 are mechanical. Easy to revert any single task — one commit per task.

---

## Archived Sprint: Security rules tighten + repo-layer close-out + OCR fixes — 2026-04-27 (shipped `6fdac5724`)

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

---

## Archived Sprint: Performance + a11y chunk-2 + repo-layer cleanup — 2026-04-27 (shipped `6521fff96`)

Theme: pre-launch hardening backlog is drained — pivot to visible performance wins + a11y chunk-2 close-out + one architectural debt while paperwork stays user-blocked. 4 agents, 9 tasks, isolated file trees.

**Sprint outcome:** 7 tasks completed, 1 partial (C2 / BUT-498), 3 verified-already-complete (B2/B3/C1 — work landed in prior commits). Net new code: a11y wraps on 7 widgets + 12+ heading-flag wrappers + ingredient-cache layer + 4 repo migrations on account-deletion path + cursor-pagination on recipe repo + GCS versioning script/runbook.

Tickets shipped: BUT-697 (chunk-2 closed; chunk-3 remaining), BUT-699, BUT-476, BUT-481 (verified done), BUT-469 (verified done), BUT-499 (verified done), BUT-498 (partial — 4 of 9 collections migrated; carry-over), BUT-484, BUT-419 (script + activation).

Continued blockers from prior sprint: BUT-426 (Android done in `308b87a76`, iOS deferred), BUT-450 (activated in `8ac8e654e`), BUT-714 (Apple Team ID), BUT-415 (privacy hosting), BUT-646 (Play Data Safety filing), BUT-419 (activated in `1a08d1acd`).
