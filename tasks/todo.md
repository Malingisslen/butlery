# Sprint Backlog

## Sprint: iter-102 — 8 code-only tickets across 8 disjoint areas (1 P2 security + 2 P3 + 5 P4) — 2026-05-29 (Fri)

Theme: **Backlog re-filled** — iter-101 drained In Progress and filed its ops-blocked remainders (BUT-1166 App Check client-half, BUT-1167 AI ops remainder) plus the code-only BUT-1168 (CPI long-tail) back into Backlog. This sprint deliberately AVOIDS the ops-blocked tickets (no Play Console / Apple Developer / deploy access this session, store-submission deferred per memory) and picks **8 in-session-shippable, code-only** tickets, each owning a DISJOINT file set so they parallelise cleanly across worktrees.

The headline is **BUT-1130** (P2, security) — the AlgoliaSearchRepository `withClient` seam that makes the search privacy invariants (cross-user leak, personal-vs-public index routing, error-contract asymmetry) unit-verifiable for the first time. The rest are recently re-verified (2026-05-28) DI-seam / cleanup / UX-recovery tickets clustered so no two agents touch the same file.

Phase 1.5 risk-gated expansion fires for **BUT-1130** (P2 + security) and **BUT-504** (3 distinct service modules — multi-module touch). Inline plans below. The other 6 are P3-idea / P4 tech-debt/test-gap with no Bug+area combo — gate skipped per the rule.

Linear: BUT-1130, BUT-935, BUT-504, BUT-1064, BUT-1077, BUT-1112, BUT-1065, BUT-1135 transitioned to Todo. No obsolete open tickets (In Progress / Todo / Triage all empty before this pass; iter-101 tickets already closed).

### Ship this sprint

#### Agent A — Algolia search DI seam + privacy-invariant tests (search) — `lib/repositories/algolia/algolia_search_repository.dart`, `test/unit/repositories/algolia/algolia_search_repository_test.dart`

- [ ] **A1. BUT-1130: add `withClient` ctor seam + assert privacy invariants** — add `AlgoliaSearchRepository.withClient({required SearchClient client, ...})` named ctor so a fake `SearchClient` can be injected. Then write tests that assert: (1) `searchRecipes` builds the `SearchForHits` request with the correct `ownerId` filter (cross-user leak guard), (2) `indexRecipe(isPersonal: true)` routes to `deleteObject` not `saveObject`, (3) searches hit `_recipesIndex` never `_usersIndex`, (4) searches return empty on failure while indexes rethrow. If `SearchClient` truly can't be faked even via the seam (final class), fall back to the thin `_AlgoliaClient` wrapper-interface alternative named in the ticket. (BUT-1130)

##### ★ Risky-ticket plan — BUT-1130 ──────────────────
Classification: **fits** — P2 + security fires the gate. The production code may already be correct; the gap is that the load-bearing privacy invariants ship UNVERIFIED. This adds a test seam + the tests, not a behavior change.
Files: `lib/repositories/algolia/algolia_search_repository.dart` (add named ctor only — keep the default ctor's internal `SearchClient` construction intact) + `test/unit/repositories/algolia/algolia_search_repository_test.dart` (replace the doc-comment gap-marker with real injected-client tests). Read-only ref: `lib/repositories/algolia/algolia_pinning_interceptor.dart`.
Blast radius: production callers use the default ctor unchanged; only tests use `withClient`. If the wrapper-interface fallback is needed, the field type changes from `SearchClient` to the interface — verify all internal call sites still compile. `algoliasearch ^1.46.2` declares `SearchClient` final, so confirm via Context7/pub whether a fake can `implements`/extend it before committing to the seam vs the wrapper approach.
Product-intent flags: none — pure verifiability hardening of an existing privacy contract.
Rollback: drop the `withClient` ctor + revert the test file to its gap-marker stub.
Proceeding automatically (no approval gate). firebase-backend-security NOT triggered (path is `lib/repositories/algolia/`, not `lib/repositories/firebase/` or `functions/src/`); code-reviewer + testing-specialist required.
─────────────────────────────────────────────────

#### Agent B — Menu "Rensa veckan" undo (menu) — `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`, `lib/services/menu/weekly_menu_plan_service.dart`, `lib/views/menu/weekly_menu_plan_view.dart`

- [ ] **B1. BUT-935: add 7s snackbar undo to clearWeek** — `weekly_menu_plan_viewmodel.dart:174-191` (`clearWeek`) clears with no recovery. Capture `current.entries` (and `_overflow`) BEFORE the clear; expose a restore primitive on `weekly_menu_plan_service.dart` (`setWeekEntries`/`restoreWeek` — check what already exists near `clearWeek` at :418) and on the VM (`undoClearWeek`); wire a 7s undo SnackBar from the menu plan view that calls it. Mirror the established undo pattern (BUT-907 children / cook-snap delete `a891ee724`). Add a VM test: capture→clear→undo round-trips the entries. (BUT-935)

#### Agent C — Layer-skipping cleanup: 3 service-layer Firestore callers (backend-services) — `lib/services/group_shared_content_service.dart`, `lib/services/cache/permission_cache_invalidator.dart`, `lib/services/notifications/modules/notification_analytics_manager.dart`

- [ ] **C1. BUT-504: route 3 remaining direct-Firestore service callers through repos (or document the exception)** — (a) `group_shared_content_service.dart` (2 refs) → `GroupSharedContentRepository`; (b) `permission_cache_invalidator.dart` (2 refs) → verify whether cache-infra is a legitimate `cloud_firestore` exception per the services pattern; if yes, document it in code + close that bullet, else route through a repo; (c) `notification_analytics_manager.dart` (1 ref) → route through `FirebaseAnalyticsRepository` or equivalent. Three small per-file changes. Update/extend the relevant service tests. (BUT-504)

##### ★ Risky-ticket plan — BUT-504 ──────────────────
Classification: **fits** — gate fires on the multi-module clause (3 distinct service files across group-content / cache / notifications). Re-verified 2026-05-28: scope shrank 7→3 files; the listed direct refs still hold.
Files: `lib/services/group_shared_content_service.dart`, `lib/services/cache/permission_cache_invalidator.dart`, `lib/services/notifications/modules/notification_analytics_manager.dart` + their tests. May need a repo method on `GroupSharedContentRepository` / `FirebaseAnalyticsRepository` — read those repos first.
Blast radius: each service swaps a direct `FirebaseFirestore.instance` call for a repo call. The cache-invalidator bullet may resolve to a documented exception (no code change beyond a comment) — decide per the CLAUDE.md services pattern. No Firestore schema change. Verify the repo methods exist or add them with PermissionValidationMixin intact.
Product-intent flags: none — architectural layer-discipline cleanup.
Rollback: revert per-file; the direct calls return.
Proceeding automatically (no approval gate). firebase-backend-security: these are `lib/services/` NOT `lib/services/{firebase|firestore|...}` — confirm against the hook's exact path pattern; if a touched service matches the firebase/firestore subpath, run the reviewer. code-reviewer + testing-specialist required regardless.
─────────────────────────────────────────────────

#### Agent D — RecipeParserService tiers: ctor seam (parsing) — `lib/services/parsing/recipe_parser_service.dart`, `test/unit/services/parsing/recipe_parser_service_test.dart`

- [ ] **D1. BUT-1064: add `tiers:` (or `tierFactory:`) ctor param** — `recipe_parser_service.dart` builds `_tiers` in the ctor with no injection seam (mirror the `cache:` seam shipped in iter-81 / BUT-1063). Add a `tiers:` param defaulting to the production factory. Then add ~5-10 orchestration tests: `_runTiers` quality-threshold short-circuit asserted directly (not via LLM callCount), `_trySelectiveIngredientEnhancement` CRF→LLM splice, `_pickUserMessage` priority ordering, `_emitTierAnalytics` per tier. (BUT-1064)

#### Agent E — UrlImportStrategy Tier 7 dead-code resolution (import) — `lib/services/import/url_import_strategy.dart`, `test/unit/services/import/url_import_strategy_test.dart`

- [ ] **E1. BUT-1077: resolve dead Tier-7 user-assistance path** — Tier 5 (`_tryHtmlTextParse` / `TextImportStrategy.import`) returns null only on empty input, so Tier 7 (`_createUserAssistedResult`) never fires for URL imports. **Step-0 product-intent decision required:** either (if Tier 7 SHOULD fire for URL imports) gate Tier 5 on a quality threshold (detected ingredient/instruction count) so prose-only pages fall through to assistance, OR (if not) explicitly document in code that user-assistance is for non-URL strategies only and remove/guard the unreachable branch. Pin the chosen contract with a test. Flag the product-intent choice in the commit, don't halt. (BUT-1077)

#### Agent F — Realtime errorStream wrapper forwarding (realtime) — `lib/services/realtime/realtime_recipe_service.dart`, `lib/services/unified/operations/realtime_recipe/realtime_watching_module.dart`, their tests

- [ ] **F1. BUT-1112: forward errorStream through realtime wrappers** — (1) add `Stream<SyncError> get errorStream => _syncService.errorStream;` on `realtime_recipe_service.dart`; (2) same on `realtime_watching_module.dart` with nullable-safe `_realtimeSyncService?.errorStream ?? const Stream.empty()`; (3) wrapper-level tests asserting dual-channel (main-stream + side-channel) errors survive the wrapper. Note: the ticket's "trigger" is a first production consumer — Step 0 should confirm whether to ship the plumbing now or keep docs-only. Given it's a tiny, low-risk getter forward that closes a known contract gap, ship it. (BUT-1112)

#### Agent G — UnifiedShoppingService test seam (shopping) — `lib/services/unified/unified_shopping_service.dart`, `test/unit/services/unified/unified_shopping_service_test.dart`

- [ ] **G1. BUT-1065: add `@visibleForTesting setError` + positive-assertion test** — `unified_shopping_service.dart` has no seam to set `_error` directly, so the "error present + cached data present → emit `ShoppingStateData` not `ShoppingStateError`" branch in `_emitState` is verified only by inverse. Add `@visibleForTesting void setError(String? err)` (or a `@visibleForTesting` setter for `_error`), then add a test: set cached lists AND an error → assert `currentState` is `ShoppingStateData` (cached-data-wins-over-error). (BUT-1065)

#### Agent H — SocialRecipeService reactive-error decision (social) — `lib/services/social_recipe_service.dart`, `test/unit/services/social_recipe_service_test.dart`

- [ ] **H1. BUT-1135: decide + implement reactive-error contract** — `SocialRecipeService` captures/sanitises `_error` (BUT-1087) but never calls `notifyListeners()` (doesn't extend ChangeNotifier). **Step-0 decision required:** ChangeNotifier vs StateNotifierMixin vs leave-as-is (pure read-after-await). Preferred low-risk route: add `ChangeNotifierMixin`/`notifyListeners()` so a reactive `ListenableBuilder` binding becomes possible, and audit consumers (`mina_recept_view.dart`, viewmodels) that currently read `service.hasError`/`service.error` synchronously post-await to confirm they still work. If the audit shows migration risk outweighs the (Low) benefit, document "intentional read-after-await contract" in code and close. Pin the chosen contract with a test. (BUT-1135)

### Acceptance

- [ ] `flutter analyze --fatal-infos` on all touched Dart files clean.
- [ ] Touched + new test files pass (A1 privacy-invariant tests, B1 undo round-trip, D1 orchestration tests, E1 tier contract, F1 dual-channel, G1 positive-assertion, H1 reactive contract).
- [ ] Tier-2 reviewers: code-reviewer (all Dart) + testing-specialist (all `lib/**` + test changes). firebase-backend-security ONLY if a BUT-504 touched service matches the `lib/services/{firebase|firestore|auth|user|gdpr}` hook path — Agent C must check.

### Post-Sprint Steps

- [ ] Run `dart analyze --fatal-infos`.
- [ ] Run relevant unit tests + the new seam tests.
- [ ] File follow-ups in Linear for any deferred sub-scope (e.g. BUT-1135 consumer migration if left-as-is, BUT-1077 product-intent if the threshold approach needs UX wiring).
- [ ] Commit (per-area or unified), push to main.
- [ ] Close BUT-1130, BUT-935, BUT-504, BUT-1064, BUT-1077, BUT-1112, BUT-1065, BUT-1135 in Linear (leave open + back to In Progress with a progress comment any that only partially ship).

---

## Sprint: iter-101 — backlog-drained: decompose the 4 remaining open tickets into code-only batches across 4 disjoint areas — 2026-05-29 (Fri)

Theme: **The Linear backlog is drained.** Backlog/Todo/Triage are all empty; only 4 tickets remain, all "In Progress" and all stale (no activity since early-mid May): BUT-804 (AI/LLM hardening bundle), BUT-760 (App Check), BUT-442 (BaseFirebaseRepository migration), BUT-885 (CPI migration). Two are partly ops-blocked (App Check needs Play Console / Apple Developer; the AI bundle's CF/Vertex/CI sub-parts need deploy access). So this sprint slices each ticket down to its **in-session-shippable code-only** part, clusters them into 4 DISJOINT areas, and files the ops remainders as follow-ups.

Step-0 obsolescence already found inside BUT-804 (do NOT re-do these — verified in code this pass):
- HIGH-AI2 (recipe.title privacy log) — DONE in `c61b810bc` (iter-45).
- HIGH-AI7 (Unicode fractions ⅙⅚⅐⅑⅒⅘) — DONE; `lib/utils/text/quantity_parser.dart:55-78` already carries all entries with a `BUT-804 HIGH-AI7` comment.
- HIGH-AI8 (prompt-changelog) — `functions/src/llm/PROMPT_CHANGELOG.md` already exists; only the CI gate (yaml) may be missing → ops follow-up, not this sprint.
The clean code-only remainder of BUT-804 is **HIGH-AI4 (adversarial golden fixtures)** — `test/golden/llm/adversarial/` does NOT exist yet.

Phase 1.5 risk-gated expansion fires for **B1 (BUT-760, security label)** and **C1 (BUT-804, security label)**. Inline plans below. A (CPI sweep, tech-debt/P4) and D (repo migration, backend/tech-debt/P3) skip the gate per the rule (mechanical sweeps within one dir, no Bug/area-Bug combo).

Linear: BUT-885, BUT-760, BUT-804, BUT-442 transitioned to Todo. No obsolete open tickets to close (iter-100 tickets already left the open set; HIGH-AI2/AI7/AI8 obsolescence is internal to BUT-804, which stays open for its ops remainder).

### Ship this sprint

#### Agent A — CPI→LoadingIndicator migration + arch-test guard (loading) — `lib/widgets/**` (disallowed-folder hits) + `test/architecture/architecture_test.dart`

> 41 raw `CircularProgressIndicator(` sites across 33 files in `lib/widgets/`, all OUTSIDE the allowed folders (`common/indicators/`, `common/state/`, `common/loading/`). The durable win is the arch-test guard — without it Phase-4 decays. Per the ≤3-files-per-agent discipline + 500-line caution, ship the GUARD this sprint plus a bounded first wave; the long tail of mechanical replacements continues in follow-up waves under the same ticket.

- [ ] **A1. BUT-885: add arch-test guard** — extend `test/architecture/architecture_test.dart` with a test that greps `lib/widgets/` for raw `CircularProgressIndicator(` and fails on any hit outside `common/indicators/`, `common/state/`, `common/loading/`. Mark the test `skip:`-free only after A2's first wave, or seed it with the current known-allowlist so it goes green immediately then tighten as the sweep lands. (BUT-885)
- [ ] **A2. BUT-885: migrate first bounded wave (≤3 files)** — replace raw `CircularProgressIndicator(...)` with the project `LoadingIndicator` wrapper in the 3 highest-traffic offenders: `lib/widgets/import/import_progress_widget.dart`, `lib/widgets/image/image_picker_widget.dart` (2 sites), `lib/widgets/common/scaffolds/loading_scaffold.dart`. Follow the established wrapper pattern from `2927ec7f0` (Phase-5 migration). (BUT-885)

#### Agent B — Server-side App Check enforcement (backend-functions) — `functions/src/**` callables + a CI grep/arch guard

> App Check has TWO halves. The CLIENT half (Play Integrity / App Attest registration, console enforcement roll-out) is ops-blocked — needs Play Console + Apple Developer access and a Monitor→Enforce window; that stays open + becomes a follow-up. The SERVER half (`enforceAppCheck: true` on each `onCall` callable) is code-only and ships now. Only 3 functions currently carry the flag.

- [ ] **B1. BUT-760 (server half): set `enforceAppCheck: true` on user-facing onCall callables** — audit every `onCall(` in `functions/src/` (12 files matched + the LLM wrapper-defined ones), add `{ enforceAppCheck: true }` to the user-facing recipe/import/feedback/account callables enumerated in the ticket's CRIT-SEC3 list. Skip admin-only / scheduled functions. Add a CI grep guard test (`functions/src/__tests__/app-check-enforcement.test.ts`) failing if a new user-facing `onCall` lands without the flag. (BUT-760)

##### ★ Risky-ticket plan — BUT-760 (server half) ──────────────────
Classification: **plan-stale + rescoped** — ticket is written client-first ("register Play Integrity / App Attest"), but that half is ops-blocked (no Play Console / Apple access this session, and per memory the store-submission track is deferred). Rescope this sprint to the **server-side `enforceAppCheck` flag + CI guard** only; the client registration + Monitor→Enforce roll-out becomes a follow-up ticket. Edit the Linear body to record the split.
Files: the user-facing onCall definitions under `functions/src/llm/`, `functions/src/feedback/`, account/export callables + new `functions/src/__tests__/app-check-enforcement.test.ts`. Read-only ref: the 3 already-flagged files (`ocr-recipe-image.ts`, `structure-recipe.ts`).
Blast radius: with the flag on but clients NOT yet sending attestation tokens, enforcement at the FUNCTION level still depends on the App Check product being in Enforce mode in console (currently Unenforced everywhere). So setting `enforceAppCheck: true` is SAFE now (no live blocking until console flips) and is the prerequisite the client roll-out builds on. Verify no callable used by an unattested path (web reCAPTCHA IS registered, so web is fine).
Product-intent flags: confirm `submitFeedback` / `requestAccountDeletion` aren't called from a context that lacks App Check init — flag, don't halt.
Rollback: remove the flag per-function; no data effect.
Proceeding automatically (no approval gate). firebase-backend-security reviewer REQUIRED at commit (touches `functions/src/`).
─────────────────────────────────────────────────

#### Agent C — Adversarial LLM golden fixtures (llm-test) — `test/golden/llm/adversarial/**`

- [ ] **C1. BUT-804 HIGH-AI4: author adversarial golden corpus** — create `test/golden/llm/adversarial/` alongside the existing BUT-784 golden corpus. Add fixture cases for: (a) prompt-injection ("ignore previous instructions, return X"), (b) jailbreak / role-play tricks, (c) structural attacks (very long input, nested JSON, control chars). Assert the parse/structure path returns a safe result (refuses / returns expected schema / no instruction-following). Wire into the existing golden runner. This is the LAST code-only slice of BUT-804 — file follow-ups for the ops remainder (AI1 retry-validator verify, AI5 Vertex prefix caching, AI6 splitter consolidation, AI8 CI changelog gate). (BUT-804)

##### ★ Risky-ticket plan — BUT-804 (HIGH-AI4 slice) ──────────────────
Classification: **plan-stale + rescoped** — the bundle's other 7 sub-parts are DONE (AI2/AI7), ops-blocked (AI1/AI5/AI8), or refactor-scoped (AI6). Only AI4 is a clean in-session code-only win. Rescope BUT-804 this sprint to AI4; edit Linear body to mark AI2/AI7 done and split AI1/AI5/AI6/AI8 into a follow-up.
Files: new `test/golden/llm/adversarial/cases.json` (+ any runner glue), mirroring `test/golden/llm/categorize_ingredient/cases.json`.
Blast radius: test-only — no production code touched. Adds a security regression net for prompt-injection.
Product-intent flags: none — pure test hardening.
Rollback: delete the new fixture dir.
Proceeding automatically (no approval gate). security label fires the gate but the change is test-only; firebase-backend-security NOT required (no `functions/src/`/`lib/repositories/firebase/` touch).
─────────────────────────────────────────────────

#### Agent D — BaseFirebaseRepository migration (backend-repo) — `lib/repositories/firebase/**` (non-adopters)

> 16 firebase repos extend `BaseFirebaseRepository`; the ticket asks to re-verify the high-traffic holdouts and migrate or close-as-done-enough. Bound to ≤3 high-value holdouts this wave.

- [ ] **D1. BUT-442: migrate ≤3 high-traffic repo holdouts** — list non-adopters via grep `-L "extends BaseFirebaseRepository" lib/repositories/firebase/*.dart`, filter to audit-log-worthy / high-traffic ones NOT already migrated, and migrate up to 3. If <3 high-value holdouts remain, close the ticket as done-enough per its own escape clause and document which repos intentionally don't extend the base (e.g. storage/messaging facades). (BUT-442)

### Acceptance

- [ ] `flutter analyze --fatal-infos` on all touched Dart files clean.
- [ ] `npm --prefix functions run build` (or tsc) clean for Agent B.
- [ ] Touched test files pass; new arch-test (A1) + app-check guard (B1) + adversarial corpus (C1) run green.
- [ ] Tier-2 reviewers: code-reviewer (all Dart) + testing-specialist (all `lib/**` + test changes) + firebase-backend-security (Agent B — `functions/src/`) + firebase-backend-security (Agent D — `lib/repositories/firebase/`).

### Post-Sprint Steps

- [ ] Run `dart analyze --fatal-infos`.
- [ ] Run relevant unit tests + the new arch/guard tests.
- [ ] File follow-ups in Linear: BUT-760 client-half (Play Integrity + App Attest + Monitor→Enforce roll-out), BUT-804 ops remainder (AI1 retry-validator verify, AI5 Vertex prefix caching, AI6 splitter consolidation, AI8 CI changelog gate), BUT-885 CPI long-tail (remaining ~30 widget files).
- [ ] Commit (per-area or unified), push to main.
- [ ] Linear: leave BUT-760/804/442/885 OPEN if only partially shipped (transition back to In Progress with a progress comment); close only if fully resolved (BUT-442 may close via its done-enough clause).

---

## Sprint: iter-100 — 8 tickets across 4 disjoint areas (1 P2 security Bug + 7 P4 cleanup) — 2026-05-28 (Thu)

Theme: Clean ticket-then-flip batch. One P2 High Bug closes the security gap that BUT-953's code-review flagged (heirloom upload format/contentType/compression — the natural follow-on to iter-98). The rest are P4 tech-debt/i18n/cleanup clustered so each agent owns a DISJOINT file set. iter-98+99 already committed in `631fceec4`, so the realtime/heirloom/categorizer/conflict-banner files are settled — but Agent A still re-touches `import_base_viewmodel.dart` for BUT-1161, so it must run alone on the import area.

Phase 1.5 risk-gated expansion fires for **BUT-1161** only (P2 + Bug + security + import + recipe). Inline plan below. The other 7 are P4 mechanical/tech-debt/i18n — gate skipped per the rule.

Linear: BUT-1161, BUT-1148, BUT-1078, BUT-1088, BUT-1126, BUT-1134, BUT-1105 transitioned to Todo. BUT-1095 NOT picked — obsolete (ctor seam already exists), close it this pass.

### Ship this sprint

#### Agent A — Import subsystem (import) — `lib/services/import/url_import_strategy.dart`, `lib/viewmodels/import_base_viewmodel.dart`, `lib/viewmodels/photo_import_viewmodel.dart`, `lib/viewmodels/smart_import_viewmodel.dart`

- [ ] **A1. BUT-1161: heirloom upload — detect real image format + compress** — fix BOTH upload sites. `lib/viewmodels/import_base_viewmodel.dart:153` builds `users/$userId/recipes/$recipeId/heirloom/$digest.jpg` with a hardcoded `.jpg` while uploading arbitrary capture bytes (HEIC/PNG/WebP). Same in `lib/viewmodels/photo_import_viewmodel.dart` (`uploadHeirloomImage`, ~343-374). Use `lib/core/utils/image_format_utils.dart` (already used by storage repo) to detect format from magic bytes and use matching extension OR re-encode to JPEG; compress >2 MB before upload (mirror existing image-compression pipeline). Add a test: PNG byte-array round-trips to `.png` (or correct re-encoded JPEG). (BUT-1161)
- [ ] **A2. BUT-1148: delete legacy string-match rate-limit fallback** — `lib/viewmodels/smart_import_viewmodel.dart:340-360` (the `errorLower.contains('rate limit'|'kvot'|'gräns')` block synthesising a `RateLimitDenied`). The structured `rateLimitDenied` branch shadows it for the only producer (ImportManager). Delete the block + the `'rate-limit denial includes the original error message'` legacy-path test in `test/unit/viewmodels/smart_import_viewmodel_test.dart` (~464-475). Structured rate-limit test must still pass. (BUT-1148)
- [ ] **A3. BUT-1078: add `dnsLookup` ctor seam to UrlImportStrategy** — `lib/services/import/url_import_strategy.dart:36-41` accepts `httpClient` + `webScraperFactory` but constructs `HttpContentFetcher` with the real `InternetAddress.lookup`. Add `Future<List<InternetAddress>> Function(String)? dnsLookup` ctor param, forward to `HttpContentFetcher` (default `InternetAddress.lookup`). Add a test injecting a fake returning `127.0.0.1` to drive the DNS-rebinding gate end-to-end through the strategy. (BUT-1078)

##### ★ Risky-ticket plan — BUT-1161 ──────────────────
Classification: **fits** — P2 + Bug + security + import + recipe fires the gate. Real upload-integrity bug: `.jpg` suffix on non-JPEG bytes can fail `storage.rules` contentType gate or get quarantined by the CF magic-byte verifier; >10 MB scans rejected by `isWithinSizeLimit(10)`.
Files: `lib/viewmodels/import_base_viewmodel.dart` (the `_attachHeirloomIfPending` path digest+upload block) + `lib/viewmodels/photo_import_viewmodel.dart` (`uploadHeirloomImage`) + `lib/core/utils/image_format_utils.dart` (read-only, reuse) + heirloom upload test.
Blast radius: both heirloom upload paths change the stored extension/contentType + add a compression step. No Firestore schema change (heirloom field already on Recipe). Storage path becomes format-correct so it stops tripping the rules/CF gate — strictly fixes a currently-broken path. Verify the chosen approach (detect-vs-reencode) is consistent across both sites so the storage layout matches.
Product-intent flags: if the heirloom viewer assumes JPEG-only display, prefer re-encode-to-JPEG over format-detect; check the consuming widget before choosing. Flag, do not halt.
Rollback: revert both VM edits; `.jpg` hardcode returns. Bridge/draft wiring (iter-98) is untouched.
Proceeding automatically (no approval gate). firebase-backend-security NOT required (no `lib/repositories/firebase/` or `functions/src/` touch); code-reviewer + testing-specialist required.
─────────────────────────────────────────────────

#### Agent B — Shared-content VMs + i18n (social) — `lib/viewmodels/shared_content/{base,shared_menu,shared_recipe,shared_shopping}_*.dart`, `lib/l10n/app_{sv,en}.arb`

> Both tickets here touch `shared_menu_viewmodel.dart`; BUT-1126 also touches base + recipe + shopping siblings. Single agent to keep the file set conflict-free.

- [ ] **B1. BUT-1088: i18n the `>2 categories` join in getMenuCategories** — `lib/viewmodels/shared_content/shared_menu_viewmodel.dart:321` hardcodes `' och ${count} till'` while the empty branch (line 315) correctly uses `AppLocale.current.labelNoCategories`. Add `"labelAndNMore": "och {count} till"` to `app_sv.arb` + `app_en.arb` (+ @meta), run `flutter gen-l10n`, switch the line to `AppLocale.current.labelAndNMore(extras)`. Update the test that pins the literal Swedish string. (BUT-1088)
- [ ] **B2. BUT-1126: fail-loud pagination contract on SharedContent VMs** — `base_shared_content_viewmodel.dart` advertises `loadContentWithPagination(limit, startAfter)` but `shared_recipe_viewmodel.dart` + `shared_shopping_viewmodel.dart` (+ menu) ignore both args and return the full list. Apply option (b): add `bool get supportsPagination => false;` on the base; override `=> true` only in VMs that actually paginate; assert/fail-loud in `loadMoreContent` when pagination is requested without support. Update sibling tests. (BUT-1126)

#### Agent C — SocialRecipeService init sanitizer (social-service) — `lib/services/social_recipe_service.dart`

- [ ] **C1. BUT-1134: route initialize() error through sanitizer** — `lib/services/social_recipe_service.dart:99` still writes `_error = 'Failed to initialize SocialRecipeService: $e';` (raw, sanitizer-bypassing) while every mutator uses `_captureAndLog`. Replace with `_captureAndLog('Failed to initialize SocialRecipeService', e)`. Update any init-error-path assertion in `social_recipe_service_test.dart` to the sanitised contract. (BUT-1134)

#### Agent D — Shopping coordinator no-op footgun (shopping) — `lib/services/unified/modules/social_shopping/social_shopping_coordinator.dart`

- [ ] **D1. BUT-1105: make saveShoppingList fail-loud instead of silent no-op** — `social_shopping_coordinator.dart:72-76` (`ShoppingListServiceAdapter.saveShoppingList`) logs + returns `shoppingList.id` without saving; `saveImportedContent` (line 187-188) delegates here and silently no-ops. Per ticket option: keep the documented "shopping uses direct collaboration" intent but throw `UnsupportedError` (with clear doc-comment) so callers fail immediately rather than believing a returned id means persisted. Add/adjust a test pinning the throw. (BUT-1105)

### Acceptance

- [ ] `flutter analyze --fatal-infos` on all touched files clean.
- [ ] `flutter gen-l10n` ran after B1 ARB additions.
- [ ] Touched test files pass.
- [ ] Tier-2 reviewers: code-reviewer (all Dart) + testing-specialist (all `lib/**`). No `lib/repositories/firebase/` / `functions/src/` touch → firebase-backend-security NOT triggered.

### Post-Sprint Steps

- [ ] Run `dart analyze --fatal-infos`.
- [ ] Run relevant unit tests.
- [ ] File any deferred follow-ups in Linear.
- [ ] Commit (unified), push to main.
- [ ] Close BUT-1161, BUT-1148, BUT-1078, BUT-1088, BUT-1126, BUT-1134, BUT-1105 in Linear.
- [ ] Close BUT-1095 as obsolete — `social_menu_coordinator.dart:96` already has the `sharedMenuRepository` ctor seam (shipped via the menu DI-seam work, BUT-1142/1153). Premise gone.

---

## Sprint: iter-99 — 7 backend/service bug + hardening tickets across 5 disjoint areas — 2026-05-28 (Thu)

Theme: Clean ticket-then-flip batch of backend/service-layer fixes, deliberately clustered to touch a DISJOINT set of files from the still-uncommitted iter-98 work (realtime/, heirloom/import, ingredient_categorizer, import_base_viewmodel, unified_shopping_item, conflict_banner, l10n ARBs). No ARB/l10n touches this sprint to avoid collision with iter-98's pending l10n keys.

Phase 1.5 risk-gated expansion fires for **BUT-1133** (security label) and **BUT-1106** (Bug+shopping). Inline plans below. The rest are P4 mechanical/tech-debt — gate skipped per the rule.

Linear: BUT-1099, BUT-1101, BUT-1152, BUT-1133, BUT-1106, BUT-1110, BUT-1120 transitioned to Todo.

### Ship this sprint

#### Agent A — PresenceService hardening (backend) — `lib/services/presence_service.dart`

- [x] **A1. BUT-1099: call `super.dispose()` in PresenceService.dispose** — `lib/services/presence_service.dart:163-188`. The override never calls `super.dispose()`, so `BaseService.onDispose()` is unreachable. Add `await super.dispose();` (BaseService.dispose is async) at the end of the override, after `_presenceRef = null`. (BUT-1099)
- [x] **A2. BUT-1101: null-guard `snapshot.data()` cast in `_cleanupStaleTypingIndicators`** — `lib/services/presence_service.dart:408`. Change `final data = snapshot.data() as Map<String, dynamic>;` to `final data = snapshot.data() as Map<String, dynamic>?; if (data == null) return;`. (Ticket cites old line 373; current site is line 408.) (BUT-1101)
- [x] **A3. Test** — extend `test/unit/services/presence_service_test.dart`: (a) dispose calls through to BaseService teardown (assert no post-dispose timer fires / onDispose hook reached); (b) cleanup tolerates an exists-but-null-data doc without throwing. (BUT-1099, BUT-1101)

#### Agent B — Shared-content repo permission + idempotency (backend/security) — two disjoint repo files

- [x] **B1. BUT-1133: gate `validateDeletePermission` on doc ownership** — `lib/repositories/firebase/firebase_notification_history_repository.dart:53-56`. Replace the unconditional `=> true` with a read-then-check: fetch the doc, return false if missing, else `doc.data()?['userId'] == _userId`. Call `logPermissionCheck()` for the audit trail (repo CLAUDE.md requirement). (BUT-1133)
- [x] **B2. BUT-1152: make `addMember` idempotent for existing members** — `lib/repositories/firebase/base_shared_content_repository.dart:308-354`. Read existing member doc (or `isMember`) BEFORE the `.set()`: if already a member, preserve original `addedAt` (merge rather than wholesale overwrite) and do NOT re-fire `incrementUnreadCounter`. Decision: option (a)+(b) combined — preserve audit fidelity AND suppress duplicate unread badge. (BUT-1152)
- [x] **B3. Tests** — `test/unit/repositories/firebase/firebase_notification_history_repository_test.dart`: assert delete denied for another user's doc / allowed for own. `test/unit/repositories/firebase/base_shared_content_repository_test.dart`: re-addMember preserves original `addedAt` and does not double-increment unread. (BUT-1133, BUT-1152)

##### ★ Risky-ticket plan — BUT-1133 ──────────────────
Classification: **fits** — security label fires the gate. Latent privacy hole: base-class `delete(id)` is currently ungated on this repo.
Files: `firebase_notification_history_repository.dart` (override the one method) + test.
Blast radius: any future caller of `repo.delete(notificationId)` is now per-user gated. No current UI caller (verified in ticket), so no behavior regression for existing flows. Adds one Firestore read per single-doc delete (rare path).
Product-intent flags: none — pure security tightening.
Rollback: revert the override back to `=> true`.
Proceeding automatically (no approval gate). firebase-backend-security reviewer required at commit (touches `lib/repositories/firebase/`).
─────────────────────────────────────────────────

#### Agent C — Shopping batch-add rollback (shopping) — `lib/services/unified/modules/shopping_item_management_module.dart`

- [x] **C1. BUT-1106: rollback partial Firestore writes on mid-loop failure** — `lib/services/unified/modules/shopping_item_management_module.dart:160-184`. The `updateItem` loop (line 161-163) can partially commit before `addItemsBatch` throws, diverging Firestore from local cache. Snapshot the pre-update item values; on any failure in the update loop or the batch add, re-apply the snapshot via `updateItem` to roll back the already-committed merges, then `return false`. Mirror the rollback shape already used in `toggleItemBought` (line 316-322). (BUT-1106)
- [x] **C2. Test** — `test/unit/services/unified/modules/shopping_item_management_module_test.dart`: stub repo so the 2nd `updateItem` throws after the 1st succeeds; assert the 1st item is rolled back to its original amount and the method returns false. (BUT-1106)

##### ★ Risky-ticket plan — BUT-1106 ──────────────────
Classification: **fits** — Bug+shopping fires the gate. Real medium-impact data-divergence bug.
Files: `shopping_item_management_module.dart` (rollback block in one method) + test.
Blast radius: `addItemsBatchToActiveList` is the batch path for recipe-import → shopping (called by `addItemsFromRecipe`). On the happy path behavior is unchanged; only the error path gains rollback. Adds compensating `updateItem` calls on failure (best-effort; if rollback itself throws, swallow + log — net no worse than today).
Product-intent flags: none — restoring consistency is the obvious intent.
Rollback: revert to the current `try { loop } catch { return false }`.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

#### Agent D — BaseSocialCoordinator dispose gate (social) — `lib/services/unified/modules/social_coordination/base_social_coordinator.dart`

- [x] **D1. BUT-1110: add `_disposed` gate to BaseSocialCoordinator** — `lib/services/unified/modules/social_coordination/base_social_coordinator.dart`. Add a `bool _disposed` field, set it in an `onDispose()` override (it's a BaseService subclass — verify the base hook name), and short-circuit `_notifyListeners()` / `_setError()` when disposed. The existing dispose-mid-await test PINS the current no-guard contract — flip it to assert no notify/setError fires after dispose. (BUT-1110)
- [x] **D2. Test flip** — `test/unit/services/unified/modules/social_coordination/base_social_coordinator_test.dart`: the dispose-mid-await test should now assert the post-dispose callback is suppressed. (BUT-1110)

#### Agent E — UploadQueueManager merge-safe updateStatus (upload) — `lib/services/upload/upload_queue_manager.dart`

- [x] **E1. BUT-1120: make `updateStatus` merge-safe** — `lib/services/upload/upload_queue_manager.dart:83-93`. The wholesale `_queue[filePath] = newStatus` clobbers the `file:` field if a caller builds the status from scratch. Preferred: change the contract so the existing entry's `file`/`url` round-trips — e.g. `_queue[filePath] = _queue[filePath]!.copyWith(state: newStatus.state, ...)` merging only the transition fields, OR add an assert that `newStatus.isDisplayable` (file or url present). Keep the single call site (`ImageUploadService`, which already passes `copyWith`) working unchanged. (BUT-1120)
- [x] **E2. Test** — `test/unit/services/upload/upload_queue_manager_test.dart`: call `updateStatus` with a from-scratch status missing `file`; assert the entry remains in `validUploads` (file preserved) OR the assert fires — pin whichever contract the fix chooses. (BUT-1120)

### Acceptance

- [ ] `flutter analyze --fatal-infos` on all touched files clean.
- [ ] Touched test files pass.
- [ ] Tier-2 reviewers: code-reviewer (all Dart) + testing-specialist (all `lib/**`) + firebase-backend-security (Agent B — touches `lib/repositories/firebase/`).

### Post-Sprint Steps

- [ ] Run `dart analyze --fatal-infos`.
- [ ] Run relevant unit tests.
- [ ] File any deferred follow-ups in Linear.
- [ ] Commit (unified), push to main.
- [ ] Close BUT-1099, BUT-1101, BUT-1152, BUT-1133, BUT-1106, BUT-1110, BUT-1120 in Linear.

> Note: BUT-1140 (RecipeFormAutoSaveManager.clearCurrentDraft "void despite async") was considered but is **obsolete** — already fixed by BUT-1138 (signature is already `Future<void> ... async` at `recipe_auto_save_manager.dart:412`, callers await it). Close it during this sprint's Linear pass.

---

## Sprint: iter-98 — 2 closures + 2 P2 High Bugs (rescoped) + 1 P3 categorizer — 2026-05-28 (Thu)

Theme: Re-verify in-progress tickets that recent commits actually closed (BUT-892, BUT-1086 → both shipped in 75c0845c9 but still In Progress). Then 2 P2 High Bugs (BUT-1031 collaborative-conflict event/banner, BUT-953 heirloom save wiring — rescoped against current architecture) + 1 P3 categorizer enhancement (BUT-1004 split fine-grained categories + oils → dry_goods).

Phase 1.5 risk-gated plan expansion fires for BUT-1031 (social+recipe+Bug) and BUT-953 (recipe+import+Bug). Inline plans below.

### Ship this sprint

#### Closure batch — already-shipped tickets still In Progress

- [x] **C1. Close BUT-892 in Linear** — Linear transitioned to Done, comment posted referencing commit 75c0845c9. (BUT-892)
- [x] **C2. Close BUT-1086 in Linear** — same. (BUT-1086)

#### Agent A — Realtime conflict visibility (BUT-1031)

- [x] **A1. Add `ConflictEvent` type** — extend `lib/services/realtime/realtime_types.dart` with `ConflictEvent` carrying `{collectionPath, docId, localValue, remoteValue, chosenStrategy, occurredAt}`. Strategy enum: `localWon`, `remoteWon`. (BUT-1031)
- [x] **A2. Emit on resolveConflict** — module gains `onConflict` + `collectionPath` ctor params. Emits from 4 normal-path branches. Catch-block emit removed per code-reviewer H1 (resolver crash is not "your edit was overwritten"). (BUT-1031)
- [x] **A3. Expose stream on RealtimeSyncService** — new `_conflictController` via `createBroadcastController` (auto-disposed via `StreamManagementMixin.disposeStreamResources()`), `conflictStream` getter, wired into `ConflictResolutionModule(onConflict: ...)`. (BUT-1031)
- [x] **A4. ConflictBanner widget** — `lib/widgets/realtime/conflict_banner.dart`, `StatefulWidget` subscribing to `conflictStream` via `ServiceLocator.tryGet` (graceful no-op when service not registered, e.g. tests). Square border, warning palette. l10n keys added: `conflictBannerMessage`, `conflictBannerDismiss`, `a11yConflictBannerDismiss` (sv+en). (BUT-1031)
- [x] **A5. Test** — `test/unit/services/realtime/conflict_resolution_module_test.dart` — 5 tests passing (localWon/remoteWon × editCount/timestamp + null-callback). (BUT-1031)

##### ★ Risky-ticket plan — BUT-1031 ──────────────────
Classification: **plan-stale + rescoped** — ticket says "wire the banner there [recipe edit/menu plan/shopping list] first." That's a 3-view UI touch on top of the infrastructure; **deferred to a follow-up Linear ticket** so this sprint can land the silent-loss fix.
Files: `realtime_types.dart` (add type), `conflict_resolution_module.dart` (emit), `realtime_sync_service.dart` (stream getter), `lib/widgets/realtime/conflict_banner.dart` (new widget), test + ARB updates.
Blast radius: ConflictResolutionModule ctor gains an optional callback. RealtimeSyncService gains a new broadcast stream — existing consumers unaffected.
Product-intent flags: banner copy may need stronger UX language ("Andra användarens ändring vann") once we have the diff view. Defer wording polish.
Rollback: revert all 4 files; `_conflictController` matches the existing `_errorController` pattern.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

#### Agent B — Heirloom save wiring (BUT-953, RESCOPED)

##### Step 0 finding: ticket premise drifted

The ticket says "Call uploadHeirloomImage from the recipe save flow." BUT `PhotoImportViewModel.uploadHeirloomImage` lives in a different VM than the save flow — saves happen in `TextImportViewModel.completeImport()` after `Navigator.pushNamed('/franSocialaMedier', ...)`. There is NO save action on PhotoImportView; the user always navigates to text-import. Re-scope: add a one-shot service-layer bridge so the heirloom draft survives navigation.

- [x] **B1. New `HeirloomDraft` model** — `lib/models/recipe/heirloom_draft.dart`. (BUT-953)
- [x] **B2. New `HeirloomBridge` service** — `lib/services/import/heirloom_bridge.dart`. Pure-state holder. (BUT-953)
- [x] **B3. DI registration** — `lib/core/di/modules/ui_module.dart` — registered as `lazySingleton<HeirloomBridge>`. (BUT-953)
- [x] **B4. PhotoImportView writes draft on navigation** — `_navigateToTextImport` + `_navigateToManualEntry` both call new `_stashHeirloomDraftIfActive` helper. (BUT-953)
- [x] **B5. Override `saveImportedRecipe` in ImportBaseViewModel** — `_attachHeirloomIfPending` called first inside `executeAsyncVoid`. Post-review fixes: re-check `isAuthenticated` (mirror BUT-1086), use `ServiceLocator.get` not `tryGet` (fail-loud), restore draft on failure (user can retry without re-filling). (BUT-953)
- [x] **B6. Unit test** — `test/unit/viewmodels/import_base_viewmodel_heirloom_test.dart` — 4 tests passing (OK / upload-null / no-userId / no-draft). Added per testing-specialist review. (BUT-953)

##### ★ Risky-ticket plan — BUT-953 ──────────────────
Classification: **plan-stale + rescoped** — ticket premise (call upload from photo VM save flow) doesn't fit current architecture. Rescoped to a service-bridge handoff.
Files: 1 new model + 1 new service + 1 DI line + photo view edit + import-base VM override + 1 test.
Blast radius: All import VMs consult HeirloomBridge in saveImportedRecipe — empty by default → text-only/url-only flows unaffected. Photo→text gets the wiring. No Firestore schema change (heirloom field already on Recipe). Upload reuses existing StorageRepository pattern.
Product-intent flags: "block success toast until upload resolves" — override does this implicitly by failing the save call.
Rollback: revert 6 files. Bridge is empty-by-default → existing non-heirloom flows unchanged.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

#### Agent C — IngredientCategorizer enhancement (BUT-1004)

- [x] **C1. Add new ShoppingCategory constants** — `meat`, `fish`, `fruit`, `veg` added; legacy `meatFish`/`fruitVeg` retained in `all` (back-compat). New buckets come first in store-walk order. (BUT-1004)
- [x] **C2. l10n keys for new categories** — added to sv + en; `flutter gen-l10n` ran. (BUT-1004)
- [x] **C3. Update displayName switch** — new cases added; legacy `meatFish`/`fruitVeg` still resolve. (BUT-1004)
- [x] **C4. Refine categorizer rules** — meat-only, fish-only, fruit-only, veg-only branches; oils → dryGoods rule placed before generic dry-goods to short-circuit `olja` substring. Word lists expanded (added torsk/sill/makrill/tonfisk, päron/druva/apelsin/jordgubb/hallon/blåbär, broccoli/blomkål/zucchini/spenat, rapsolja/solrosolja). (BUT-1004)
- [x] **C5. Flip golden corpus** — all 10/10 cases pass with new expectations. (BUT-1004)
- [x] **C6. UI sweep check** — `shopping_list_generator_test` (35/35) + `unified_shopping_item_test` + 3 others (73/73) all pass. Legacy switch cases unchanged. Follow-up BUT-1164 filed for eventual migration + cleanup. (BUT-1004)

### Acceptance

- [x] `flutter analyze --fatal-infos` on touched files clean.
- [x] Touched test files pass (9/9 new + regression checks green).
- [x] Tier-2 reviewers: code-reviewer (BUT-1031, BUT-953) + testing-specialist — all findings addressed inline or filed as follow-ups.

### Post-Sprint Steps

- [x] File follow-ups in Linear: BUT-1161 (heirloom upload contentType — High), BUT-1162 (banner surface wiring — Medium), BUT-1163 (diff view — Low), BUT-1164 (legacy category migration — Low).
- [ ] Commit (unified).
- [ ] Push.
- [ ] Close BUT-1031, BUT-953, BUT-1004 in Linear.

---

## Sprint: iter-97 — 2 P2 High Bug fixes (BUT-1086 + BUT-892) — 2026-05-28 (Thu)

Theme: Two P2 High Bugs via established patterns. BUT-1086 mirrors iter-82's BUT-1131 (silent secondary write → surface via setError). BUT-892 mirrors iter-82's BUT-894 (orphan cleanup extension in `_cleanupRecipeReferences`).

### Ship this sprint

- [x] **A1. BUT-1086: surface sign-out-during-import via _error** — `lib/services/social_recipe_service.dart:175-210` (importSharedRecipe). When `createRecipe` succeeds but `_permissionService.isAuthenticated == false` at the re-check (mid-import sign-out), set `_error = AppLocale.current.errorImportPartialReSignIn` and log warning. Function still returns true (recipe IS saved); UI prompts re-sign-in to clear inbox. Added `import 'package:butlery/core/l10n/app_locale.dart';`. (BUT-1086)
- [x] **A2. Flip BUT-1086 pinning test** — `test/unit/services/social_recipe_service_test.dart:696`. Test renamed to `BUT-1086: sign-out mid-import → returns true, no mark call, error surfaced`. New assertions: `ok=true`, `markedAsImported=empty`, `service.hasError=true`, `service.error!=null`. (BUT-1086)
- [x] **A3. BUT-892: cook_snaps cleanup in _cleanupRecipeReferences** — `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:143-160` (inserted between social_stats delete and shared_content drain). New paginated loop on `FirestoreCollections.cookSnaps` (constant already exists at `firestore_collections.dart:47`) `where('recipeId', isEqualTo: recipeId).limit(450)`. (BUT-892)
- [x] **A4. Add BUT-892 test** — `test/unit/services/unified/modules/service_adapters/recipe_service_adapter_test.dart:451-501`. Mirrors BUT-894 pattern: FakeFirebaseFirestore + mocked FirestoreRepository, seeds 1 cook_snap doc, calls `deleteRecipe`, asserts doc gone. Test name: `BUT-892: deleteRecipe drains orphan cook_snaps records`. (BUT-892)
- [x] **A5. l10n key + gen-l10n** — Added `errorImportPartialReSignIn` to both `lib/l10n/app_sv.arb` and `lib/l10n/app_en.arb` (with `@meta` descriptions). Ran `flutter gen-l10n`; key regenerated in `lib/l10n/app_localizations*.dart`. (BUT-1086)

### Acceptance

- [x] `flutter analyze --fatal-infos` on touched lib files clean (`No issues found!`).
- [x] Touched test files pass (61/61 in recipe_service_adapter_test + all in social_recipe_service_test).
- [ ] Tier-2 reviewers (run from orchestrating session before commit).

### Post-Sprint Steps

- [x] Commit (unified, from orchestrating session). — commit `75c0845c9`, pushed to main 2026-05-28.
- [ ] Close BUT-1086 + BUT-892 in Linear.

---

## Archived iter-92 (commit `5a65cd2cd` — BUT-1132) — 2026-05-27 (Wed)

Theme: Single P4 Low Bug — Firestore duplicate-share idempotency. Repository-layer fix: check for existing `shared_recipes` doc with same `(sharedByUserId, originalRecipeId)` before creating a new one. If found, reuse + addMember new recipients. Scope: repository-only change + test flip.

Phase 1.5 expansion fires (social+recipe+Bug). Risky-ticket plan documented inline.

### Ship this sprint

#### Agent — Idempotent createSharedRecipe

- [x] **A1. BUT-1132: check-then-write in `FirebaseSharedRecipeRepository.createSharedRecipe`** — `lib/repositories/firebase/firebase_shared_recipe_repository.dart:179-208`. Before calling `createSharedContent`, query `shared_recipes` for an existing doc with `where('sharedByUserId', isEqualTo: sharedRecipe.sharedByUserId).where('originalRecipeId', isEqualTo: sharedRecipe.originalRecipeId).limit(1).get()`. If exists, reuse the existing doc ID + `Future.wait(recipientIds.map((id) => addMember(existingId, id, addedBy: uid)))` and return the existing ID. Existing members are no-ops at the `.set()` level (addMember uses `.set()` at line 338, and arrayUnion is idempotent). Log `'♻️ Reusing existing shared recipe $existingId (idempotent)'`. (BUT-1132)
- [x] **A2. Add Firestore composite index for the dedup query** — `firestore.indexes.json`. New index: collection `shared_content` (actual runtime collection — `shared_recipes` was legacy/unused), fields `sharedByUserId ASC` + `originalRecipeId ASC`. (BUT-1132)
- [x] **A3. Flip pinning test** — `test/unit/repositories/firebase_shared_recipe_repository_test.dart` — added new `BUT-1132: idempotent share` group with two tests: (a) end-to-end double-create (skipped, matches existing FakeFirestore FieldValue skip pattern); (b) direct dedup-query probe (runs, asserts the `where().where()` chain finds the existing doc). (BUT-1132)
- [x] **A4. Flip pinning test (service layer)** — `test/unit/services/unified/modules/social_recipe/social_recipe_sharing_service_test.dart` — no existing test pins "second share creates second doc" at service layer (the `_FakeSharedRecipeRepo` returns `sharedRecipe.id` directly, so service-layer tests cannot observe doc-multiplication). No flip needed. (BUT-1132)

### Step 0 — premise verification (done)

- **BUT-1132** verified: `firebase_shared_recipe_repository.dart:179-208` — `createSharedRecipe` always calls `createSharedContent` which auto-generates a new doc ID. No existence check at the repository layer. `base_shared_content_repository.dart:308-353` `addMember` uses `.set()` (idempotent at doc level) + `arrayUnion` (idempotent at array level), but `incrementUnreadCounter` (line 346) fires unconditionally — secondary bug, file follow-up if scope warrants.

### ★ Risky-ticket plan — BUT-1132 ──────────────────
Classification: **fits** (social+recipe+Bug — Firestore behavior change, scope-managed via repository-layer-only edit)
Files: `lib/repositories/firebase/firebase_shared_recipe_repository.dart` (add 8-line check-then-write block before `createSharedContent`) + `firestore.indexes.json` (new composite index) + 1-2 test flips.
Blast radius: future `createSharedRecipe` calls with an existing `(owner, recipe)` pair return the existing doc ID instead of creating a new one. Recipients added via addMember (idempotent at member-doc level). UI consumers reading `shared_recipes` will now see one canonical doc per (sender, recipe) pair instead of one per share-event. The recipient's inbox load-path likely dedups by `(sharedRecipeId)` already; this change reinforces that. New composite index needed for the query (sharedByUserId + originalRecipeId).
Product-intent flags: Re-share might be intended to re-notify the recipient. Current implementation re-notifies via `incrementUnreadCounter` in `addMember`. After this fix, re-share still triggers addMember which still increments unread (since addMember always runs). So re-notification behavior is preserved — only the doc-multiplication is fixed.
Rollback: revert the check-then-write block + drop the new index. No data migration; existing duplicate docs in Firestore continue to exist (they're not retroactively merged) — but that's a separate cleanup if desired.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] Touched test files pass.
- [x] Tier-2 reviewers clean (firebase-backend-security required — touches `lib/repositories/firebase/`).

### Post-Sprint Steps

- [x] Commit + push.
- [x] Close BUT-1132 in Linear.
- [x] File follow-up if scope demands: addMember unread-counter idempotency (BUT-1132-followup).

---

## Archived iter-91 (commit `913bc35ff` — BUT-1150) — 2026-05-27 (Wed)

Theme: Tiny pure-doc commit. Closes BUT-1150 design-clarity question by documenting the shared read+write circuit-breaker as intentional.

Theme: Tiny pure-doc commit. Closes BUT-1150 design-clarity question by documenting the shared read+write circuit-breaker as intentional. Rationale: the breaker protects the underlying Drift channel, so any I/O success (read OR write) genuinely indicates channel health. The pathological scenario (schema migration breaks read deserialization but not writes) is vanishingly rare — flag for telemetry-driven escalation rather than preemptive refactor.

No Phase 1.5 expansion (P4 + pure `parsing`/`tech-debt`/`Improvement` labels).

### Ship this sprint

- [x] **A1. BUT-1150: document shared-breaker rationale** — 9-line doc comment on `_cacheCircuitBreaker` field at `recipe_parser_service.dart:151-155`. References BUT-1150 for the design discussion. (BUT-1150)

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched file.
- [x] No test changes needed (doc-only).

### Post-Sprint Steps

- [x] Orchestrating session commits + pushes.
- [x] Close BUT-1150 in Linear.

---

## Archived iter-90 (commit `f125ab9e1` — BUT-1141) — 2026-05-27 (Wed)

Theme: Single P3 Medium test-gap. 5 cache-behaviour tests using the `cache:` ctor seam shipped in iter-81 (BUT-1063). Test-only, no production change. Pure coverage gain.

Theme: Single P3 Medium test-gap. 5 cache-behaviour tests using the `cache:` ctor seam shipped in iter-81 (BUT-1063). Test-only, no production change. Pure coverage gain.

No Phase 1.5 expansion (P3 + `parsing`/`test-gap` labels, no Bug or area-trigger combo).

### Ship this sprint

#### Agent — Author FakeLocalRecipeCache + 5 behaviour tests

- [x] **A1. Author `FakeLocalRecipeCache` test helper** — place in `test/unit/services/parsing/_fake_local_recipe_cache.dart` (or inline at top of the test file if simpler). Must:
  - Extend or implement the same shape as `LocalRecipeCache` (subclass + override, or implements + manual stub). Methods: `init()`, `get({urlHash, contentHash, source})`, `set({urlHash, contentHash, source, recipe})`, plus the version-aware key generation if needed.
  - Record all `get` and `set` calls (counters + last-args) for assertions.
  - Support configurable behaviour:
    - `setStoredRecipe(ParsedRecipe?)` — what `get` returns
    - `throwOnGet = true` — `get` throws
    - `throwOnSet = true` — `set` throws
  - The fake can hold a single `ParsedRecipe?` and a single `parserVersion` (model the version-mismatch invalidation by mimicking the key check)
- [x] **A2. Test 1 — init() with injected cache skips OfflineService lookup** — register a stub `OfflineService` in `ServiceLocator` that throws on any access (or simply do NOT register it). Construct `RecipeParserService` with `cache: FakeLocalRecipeCache()`. Call `init()`. Assert no exception thrown + the injected fake's `initCallCount == 1`. (BUT-1141)
- [x] **A3. Test 2 — Cache HIT short-circuits tier pipeline** — seed fake with `setStoredRecipe(testParsedRecipe)`. Call `parseFromUrl(url: ..., htmlContent: ..., useCache: true)`. Assert `result.success`, `result.fromCache == true`, fake's `getCallCount == 1`, fake's `setCallCount == 0`. (BUT-1141)
- [x] **A4. Test 3 — Cache MISS writes parsed result to cache** — fake returns null on `get`. Call `parseFromUrl(...)`. Assert tier pipeline runs (result NOT from cache: `result.fromCache == false`), fake's `setCallCount == 1`, fake's `lastSetRecipe` equals the parsed result. (BUT-1141)
- [x] **A5. Test 4 — Parser-version mismatch causes cache miss + re-parse** — configure the fake so `get` returns null when the stored `parserVersion` differs from the service's current version (mimic `LocalRecipeCache`'s version-aware key generation). Construct service with `parserVersion: 'v2'`. Pre-populate fake with a stored recipe at `parserVersion: 'v1'`. Drive `parseFromUrl`. Assert tier pipeline ran (NOT from cache) AND fake's `setCallCount == 1` (new entry written with v2). (BUT-1141)
- [x] **A6. Test 5 — Circuit breaker opens after N consecutive cache read failures, bypasses subsequent reads** — fake throws `Exception('cache failure')` on `get`. Drive `parseFromUrl` 3 times (failureThreshold=3 per `recipe_parser_service.dart:152-155`). On the 4th call, assert fake's `getCallCount == 3` (NOT 4) — the circuit-breaker.isOpen guard at `_checkCache:714` short-circuited the call. (BUT-1141)

### Step 0 — premise verification (done)

- **BUT-1141** verified: `recipe_parser_service.dart:166-194` ctor accepts `LocalRecipeCache? cache` param (shipped in iter-81 commit `503a0556`). `init()` at line 197-208 conditionally creates production cache only when `_cacheField == null`. `_checkCache` at line 713-732 wraps `cache.get(...)` in `_cacheCircuitBreaker` (failureThreshold=3, resetTime=2min, lines 152-155). `_cacheResult` at line 736-... similarly wraps `cache.set(...)`. `LocalRecipeCache` API (`lib/services/parsing/cache/local_recipe_cache.dart`) — methods: `init()`, `get({urlHash, contentHash, source})`, `set({urlHash, contentHash, source, recipe})`, plus internal `generateCacheKey()` with parserVersion in the hash.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched test files.
- [x] All 5 new tests pass.
- [x] Existing `recipe_parser_service_test.dart` tests still pass.
- [x] Tier-2 reviewers clean (testing-specialist must approve — `lib/**/*.dart` is NOT touched, but test-quality review is still valuable for new test infrastructure).

### Post-Sprint Steps

- [x] Orchestrating session does commit + push.
- [x] Close BUT-1141 in Linear.

---

## Archived iter-89 (commit `e5d163fcd` — BUT-1143) — 2026-05-27 (Wed)

Theme: Single P4 Low pure-cleanup. Pivot from P4 Bug well (BUT-1132 needs deeper scope — Firestore deterministic doc ID or check-then-write w/ idempotent addMember).

Theme: Single P4 Low pure-cleanup. Pivot from P4 Bug well (BUT-1132 needs deeper scope — Firestore deterministic doc ID or check-then-write w/ idempotent addMember).

BUT-1143 was filed by iter-81 wrap-up as a follow-up after the BUT-1074 rename made `configureAuthStateStream` Fake-incompatible. The ticket suggested "1 sprint of telemetry watch" before deletion, but the testing-specialist's audit at file-time confirmed zero callers via grep — and the method is `@Deprecated` with a clear migration note. The watch was over-cautious; the static audit is sufficient.

No Phase 1.5 expansion (P4 + pure `tech-debt`/`test-gap` labels — explicitly skipped per the rule).

### Ship this sprint

#### Agent — Delete dead method (direct edit, no agent needed)

- [x] **A1. Delete `MockConfigurator.configureAuthStateStream`** — `test/test_support/mock_configurator.dart:120-136`. Remove the entire method + its 7-line docstring + `@Deprecated` annotation. Confirm via grep that no other file references it (verified: only the knowledge-file doc references it, that's fine to leave). (BUT-1143)
- [x] **A2. Verify** — `dart analyze --fatal-infos` clean. Full unit suite still green. (BUT-1143)

### Step 0 — premise verification (done)

- **BUT-1143** verified: `mock_configurator.dart:120-136` has the method as described. Grep across `test/` and `lib/` returns zero non-doc references. The method is already `@Deprecated` with a migration note to the local `_MockAuthRepository extends Mock` pattern.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] `flutter test test/unit/` still passes (no behavior change — method had no callers).
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does commit + push.
- [x] Close BUT-1143 in Linear.

---

## Archived iter-88 (commit `b12b40e3e` — BUT-1129) — 2026-05-27 (Wed)

Theme: Single P4 Low Bug. **Plan-stale rescope** — original ticket proposed `this.disposed` field reads, but `disposed`/`uploadsCanceled` are params, not fields. Re-scoped inline to callback-based fresh-read. Linear ticket body updated.

Theme: Single P4 Low Bug. **Plan-stale rescope** — original ticket proposed `this.disposed` field reads, but `disposed`/`uploadsCanceled` are params, not fields. Re-scoped inline to callback-based fresh-read. Linear ticket body updated.

Phase 1.5 doesn't fire (P4 + plain `Bug` label, no area-label combo). Plan-stale rescope handled in Step 0 + Linear ticket edit per the established pattern.

### Ship this sprint

#### Agent — Soft-cancel fresh-read in ImageUploadCoordinator

- [x] **A1. BUT-1129: replace value-passed bool with callback** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart`. Change `uploadPendingImagesInBackground` (line 60) and `_uploadSingleImageWithTracking` (line 145) params:
  - `required bool disposed` → `required bool Function() isDisposedNow`
  - `required bool uploadsCanceled` → `required bool Function() isUploadsCanceledNow`
  
  Update all 5 cancellation-check sites to call the closures:
  - `image_upload_coordinator.dart:68` outer guard
  - `image_upload_coordinator.dart:157` single pre-upload check
  - `image_upload_coordinator.dart:167` notifyListeners guard
  - `image_upload_coordinator.dart:173` single state-update check
  - `image_upload_coordinator.dart:182` single post-upload check
  - `image_upload_coordinator.dart:219` catch-block state-update guard
  
  Update internal call site at `image_upload_coordinator.dart:101-102` (the inner `_uploadSingleImageWithTracking` invocation) to forward the closures.
  
  Update caller in `lib/viewmodels/recipe_form/recipe_image_manager.dart:1214-1215`:
  - `disposed: _disposed` → `isDisposedNow: () => _disposed`
  - `uploadsCanceled: _uploadsCanceled` → `isUploadsCanceledNow: () => _uploadsCanceled`
  
  (BUT-1129)

- [x] **A2. Add BUT-1129 mid-flight soft-cancel test** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. Pin the now-correct behaviour: 
  - Stub a slow `StorageService.uploadRecipeImage` (e.g. delayed Future)
  - Start `uploadPendingImagesInBackground` with `isDisposedNow: () => disposedFlag` where `disposedFlag` is a local `bool` variable
  - Flip `disposedFlag = true` while uploads are in flight
  - Assert the returned list of URLs is empty (uploads short-circuited)
  
  This test would have failed with the old captured-by-value behaviour (mid-flight flip would have been invisible). (BUT-1129)

### Step 0 — premise verification (done)

- **BUT-1129 PLAN STALE**: `image_upload_coordinator.dart:60-67, 145-152` — `disposed`/`uploadsCanceled` are passed-in parameters, NOT fields on ImageUploadCoordinator. Ticket's `this.disposed` fix doesn't apply. Re-scoped to callback-based fresh-read; Linear ticket body updated to reflect new plan.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib files.
- [x] Touched test file passes (incl. new mid-flight soft-cancel test).
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1129 in Linear.

---

## Archived iter-87 (commit `7d37c88ba` — BUT-1093) — 2026-05-27 (Wed)

Theme: Single P4 Low Bug — mirror-existing-pattern fix. Phase 1.5 expansion fires (menu+social+Bug) — richer plan inline, no halt. The remaining easy P4 Bug well is empty; this is the last clean ticket-then-flip fit. The rest (BUT-1132/1129/897) need larger scope changes.

Theme: Single P4 Low Bug — mirror-existing-pattern fix. Phase 1.5 expansion fires (menu+social+Bug) — richer plan inline, no halt. The remaining easy P4 Bug well is empty; this is the last clean ticket-then-flip fit. The rest (BUT-1132/1129/897) need larger scope changes.

### Ship this sprint

#### Agent — SocialMenuCoordinator imported-menu attribution

- [x] **A1. BUT-1093: replace placeholder in `createImportedContent` forEach with real copyWith** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:160-183`. The forEach body currently returns the recipe verbatim with a `// Placeholder` comment. Mirror the pattern from `createStaticCopyForOwner` at lines 542-554: apply `recipe.copyWith(title: '${recipe.title} (Min kopia)', lastCookedAt: null)`. Keep the category names as-is (don't mirror the "$category (Min kopia)" category-suffix from createStaticCopyForOwner — that's a different pattern for static copies, not imports). (BUT-1093)
- [x] **A2. BUT-1093 test flip** — `test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart`. Find the test that pins the placeholder behavior (likely asserts the recipe title is unchanged after `createImportedContent`). Flip: assert the imported recipe's title ends with "(Min kopia)" AND `lastCookedAt == null`. (BUT-1093)

### Step 0 — premise verification (done)

- **BUT-1093** verified: `social_menu_coordinator.dart:160-183` — `createImportedContent` has `return recipe; // Placeholder - needs actual Recipe.copyWith implementation` on line 176. The mirror pattern at lines 542-554 (`createStaticCopyForOwner`) uses `recipe.copyWith(title: '${recipe.title} (Min kopia)', lastCookedAt: null)`.

### ★ Risky-ticket plan — BUT-1093 ──────────────────
Classification: **fits** (menu+social+Bug — mirror-existing-pattern fix, smallest possible blast radius)
Files: `lib/services/unified/modules/social_menu/social_menu_coordinator.dart` (1 forEach body, ~5 lines) + 1 test flip.
Blast radius: any user who imports a shared menu via the `createImportedContent` path (the new copy-on-write `joinSharedMenu` flow) will now see recipe titles suffixed with "(Min kopia)" and reset `lastCookedAt`. The legacy `importSharedMenu` path already did this via `SharedMenu.createImportMenu` — this fix brings the new path into alignment. UI-visible change: imported menus now show "(Min kopia)" on each recipe title.
Product-intent flags: NONE. The ticket explicitly states this is the intended behavior; the placeholder was a known TODO from the BaseSocialCoordinator template extraction.
Rollback: revert the forEach body to `return recipe;`. No schema, no data effect — only newly-imported menus get the new title shape.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib file.
- [x] Touched test file passes.
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1093 in Linear.

---

## Archived iter-86 (commit `38a961ec9` — BUT-1117 + BUT-1115 + BUT-1109 + BUT-1096) — 2026-05-27 (Wed)

Theme: Four P4 Low Bugs across 4 unrelated files. Single agent. All ticket-then-flip mechanical fits. BUT-1109 triggers Phase 1.5 expansion (shopping+Bug combo) but the fix is a tiny i18n change — richer plan documented inline, no halt.

Theme: Four P4 Low Bugs across 4 unrelated files. Single agent. All ticket-then-flip mechanical fits. BUT-1109 triggers Phase 1.5 expansion (shopping+Bug combo) but the fix is a tiny i18n change — richer plan documented inline, no halt.

### Ship this sprint

#### Agent — i18n + content-quality polish

- [x] **A1. BUT-1117: YouTube inputExample uses real video ID** — `lib/services/import/youtube/youtube_import_strategy.dart:35`. Change `'https://www.youtube.com/watch?v=VIDEO_ID'` to `'https://www.youtube.com/watch?v=dQw4w9WgXcQ'`. The 8-char placeholder fails the strategy's own 11-char video-ID regex. (BUT-1117)
- [x] **A2. BUT-1117 self-consistency test** — `test/unit/services/import/youtube/youtube_import_strategy_test.dart`. New test: `expect(strategy.canHandle(strategy.inputExample), isTrue, reason: 'BUT-1117: inputExample must satisfy canHandle')`. (BUT-1117)
- [x] **A3. BUT-1115: l10n the delete-confirmation itemTypes** — `lib/core/utils/common_dialog_actions.dart:46,60,74`. Replace literals: `'recept'` → `context.l10n.itemTypeRecipe`, `'grupp'` → `context.l10n.itemTypeGroup`, `'inköpslista'` → `context.l10n.itemTypeShoppingList`. Add 3 new keys to `app_sv.arb` + `app_en.arb` + @meta. (BUT-1115)
- [x] **A4. BUT-1115 test flip** — `test/unit/core/utils/common_dialog_actions_test.dart`. Find the existing test `'english locale → recipe delete title still leaks Swedish "recept"'` that asserts the BROKEN behaviour. Flip it: in English locale the title should contain "recipe" (NOT "recept"). (BUT-1115)
- [x] **A5. BUT-1109: l10n the shopping-list missing-name fallback** — `lib/services/unified/operations/modules/shopping_social_share_module.dart`. Four sites: lines 54, 272, 273, 310 (the ticket cites old line numbers — actual current lines from grep) — replace `?? '?'` with `?? AppLocale.current.shoppingListUnnamed` (or `?? AppLocale.current.unnamedSharedList` — pick the more semantically correct key name). Add the key to both ARBs + @meta. Swedish: "(Namnlös lista)". English: "(Unnamed list)". (BUT-1109)
- [x] **A6. BUT-1109 pinning test** — find or create a test for `shopping_social_share_module` (test path: `test/unit/services/unified/operations/modules/shopping_social_share_module_test.dart`). Seed a shopping list with no `name` field. Assert the resulting title contains the localised "Namnlös lista" / "Unnamed list" string (NOT a literal `?`). (BUT-1109)
- [x] **A7. BUT-1096: YouTube transcript no double-spaces after marker strip** — `lib/services/import/youtube/youtube_transcript_service.dart:417-428`. Reorder `_cleanTranscript` so the marker stripping runs FIRST, then the whitespace normalization. Current order: normalize→strip→trim (leaves double-spaces). New order: strip→normalize→trim. (BUT-1096)
- [x] **A8. BUT-1096 test flip** — `test/unit/services/import/youtube/youtube_transcript_service_test.dart`. Find the existing test that asserts `isNot(contains('   '))` (3 spaces). Tighten to `isNot(contains('  '))` (2 spaces). (BUT-1096)
- [x] **A9. Run `flutter gen-l10n`** after A3 + A5 ARB additions.

### Step 0 — premise verification (done)

- **BUT-1117** verified: `youtube_import_strategy.dart:35` literal `VIDEO_ID` (8 chars). The video-ID regex in `youtube_transcript_service.dart` requires exactly 11 chars.
- **BUT-1115** verified: `common_dialog_actions.dart:46,60,74` hardcode `'recept'`, `'grupp'`, `'inköpslista'`.
- **BUT-1109** verified: `shopping_social_share_module.dart` has 4 sites of `?? '?'` fallback at lines 54, 272, 273, 310 (line numbers shifted slightly from ticket — same shape).
- **BUT-1096** verified: `_cleanTranscript` at line 417-428 normalizes whitespace at line 420 BEFORE stripping markers at lines 422-425. Markers like `[musik] ` become `''` but the trailing space remains, producing double-spaces.

### ★ Risky-ticket plan — BUT-1109 ──────────────────
Classification: **fits** (shopping+Bug — i18n fallback string, smallest possible blast radius)
Files: `lib/services/unified/operations/modules/shopping_social_share_module.dart` (4 fallback sites — same `?? '?'` shape) + `lib/l10n/app_sv.arb` + `lib/l10n/app_en.arb` + 1 new test.
Blast radius: any path that creates a "shared list" card via this module without a `name` field now shows the localised fallback instead of `?`. UI is purely cosmetic — no consumer relies on the literal `?` character. Confirmed via grep: no `'?'` equality check exists anywhere in the consumer paths.
Product-intent flags: ticket says this is only reachable for "legacy/malformed data" — the normal share flow always sets `name`. Localizing keeps the fallback honest for the corner case.
Rollback: revert the 4 `?? '?'` lines + new ARB keys. No schema effect, no behavior change for healthy data.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib files.
- [x] Touched test files pass.
- [x] `flutter gen-l10n` succeeded after A3 + A5 ARB additions.
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1117 + BUT-1115 + BUT-1109 + BUT-1096 in Linear.

---

## Archived iter-85 (commit `91c22fca3` — BUT-1119 + BUT-1127 + BUT-1103 + BUT-1104) — 2026-05-27 (Wed)

Theme: Four P4 Low Bugs across the upload subsystem (3 sibling files). Single agent. Same `Bug` shape as iter-84, ticket-then-flip. No Phase 1.5 expansion (all P4 + plain `Bug` label, no area-label combo).

Theme: Four P4 Low Bugs across the upload subsystem (3 sibling files). Single agent. Same `Bug` shape as iter-84, ticket-then-flip. No Phase 1.5 expansion (all P4 + plain `Bug` label, no area-label combo).

### Ship this sprint

#### Agent — Upload subsystem fixes

- [x] **A1. BUT-1119: UploadQueueManager.getSummary['uploading'] honest count** — `lib/services/upload/upload_queue_manager.dart:212`. Change `final uploading = activeUploads.length;` to `final uploading = getByState(ImageUploadState.uploading).length;`. Keep `'active'` key set to `activeUploads.length` (alias for in-flight = uploading+retrying). Add new `'retrying'` key = `getByState(ImageUploadState.retrying).length`. So the summary now has honest semantics: `uploading` = strictly uploading, `retrying` = strictly retrying, `active` = both. (BUT-1119)
- [x] **A2. BUT-1119 pinning test** — `test/unit/services/upload/upload_queue_manager_test.dart`. New test: seed queue with 1 uploading + 1 retrying. Assert `summary['uploading'] == 1` (NOT 2), `summary['retrying'] == 1`, `summary['active'] == 2` (unchanged). (BUT-1119)
- [x] **A3. BUT-1127: ImageUploadCoordinator bulk buttons on single-item state** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart:326-327`. Change `failed > 1` → `failed >= 1` and `active > 1` → `active >= 1` for `canBulkRetry` / `canBulkCancel`. Option A from the ticket — UX consistency over single-vs-bulk distinction. (BUT-1127)
- [x] **A4. BUT-1127 pinning test flip** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. Existing tests pin both branches at `> 1`. Flip the assertions to `>= 1`: a queue with 1 failed should now have `canBulkRetry == true`; a queue with 1 active should have `canBulkCancel == true`. (BUT-1127)
- [x] **A5. BUT-1103: UploadQueueSummaryCalculator denominator** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart:158`. Change `return l.uploadStatusAllFailed(failed, total);` to `return l.uploadStatusAllFailed(failed, failed);`. This branch fires when `completed == 0` AND `failed > 0` — denominator should be the count of items that actually attempted, i.e. just `failed` (cancellations didn't attempt). (BUT-1103)
- [x] **A6. BUT-1103 pinning test flip** — `test/unit/viewmodels/recipe_form/image_management/upload_queue_summary_calculator_test.dart`. Existing test pins `uploadStatusAllFailed(3, 5)` (with cancellations inflating total). Flip to expect `uploadStatusAllFailed(3, 3)` and verify the resulting string no longer says "3 av 5" but rather "3 av 3" (or whichever Swedish form `uploadStatusAllFailed(3, 3)` produces). (BUT-1103)
- [x] **A7. BUT-1104: getSpeedDisplayText sub-1 KB/s precision** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart:190-200`. In the `< 1.0 MB/s` branch, change the KB formatting to use `toStringAsFixed(1)` when `kbPerSecond < 1.0` (sub-KB cases) so 500 B/s shows as "0.5 KB/s" not "0 KB/s". Keep `toStringAsFixed(0)` for `kbPerSecond >= 1.0` (whole-KB cases). (BUT-1104)
- [x] **A8. BUT-1104 pinning test** — same test file. New test: `getSpeedDisplayText(500)` returns "0.5 KB/s" (not "0 KB/s"). `getSpeedDisplayText(2048)` returns "2 KB/s" (whole KB unchanged). `getSpeedDisplayText(0)` returns '' (no-data unchanged). (BUT-1104)

### Step 0 — premise verification (done)

- **BUT-1119** verified: `upload_queue_manager.dart:166-170` `activeUploads` getter explicitly includes both `uploading` AND `retrying`. Line 212 `final uploading = activeUploads.length` — over-counts.
- **BUT-1127** verified: `image_upload_coordinator.dart:326-327` `canBulkRetry: failed > 1` and `canBulkCancel: active > 1`. Comment confirms intent ("multiple"); matches ticket.
- **BUT-1103** verified: `upload_queue_summary_calculator.dart:155-158` — `uploadStatusAllFailed(failed, total)` fires when `failed > 0 && completed > 0` is false. `total` includes cancelled items, inflating denominator.
- **BUT-1104** verified: `upload_queue_summary_calculator.dart:190-200` — `(500/1024).toStringAsFixed(0) == "0"`. The KB-branch always uses `toStringAsFixed(0)`.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib files.
- [x] Touched test files pass.
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1119 + BUT-1127 + BUT-1103 + BUT-1104 in Linear.

---

## Archived iter-84 (commit `0e85b8786` — BUT-1145 + BUT-1146 + BUT-1147) — 2026-05-27 (Wed)

Theme: Three P4 Low Bugs all in `lib/viewmodels/smart_import_viewmodel.dart`, dispatched to a single agent. Same file, no merge collision risk. All mechanical fits. P3 Bug well dried after iter-83 — graduating to P4 batches; the priority just reflects user-visible impact, the shape is identical. No Phase 1.5 expansion (`import` not in expansion-trigger label list).

Theme: Three P4 Low Bugs all in `lib/viewmodels/smart_import_viewmodel.dart`, dispatched to a single agent. Same file, no merge collision risk. All mechanical fits. P3 Bug well dried after iter-83 — graduating to P4 batches; the priority just reflects user-visible impact, the shape is identical. No Phase 1.5 expansion (`import` not in expansion-trigger label list).

### Ship this sprint

#### Agent — SmartImportViewModel hygiene

- [x] **A1. BUT-1145: reorder pattern matches in `_localizeImportError`** — `lib/viewmodels/smart_import_viewmodel.dart:466-502`. The "could not save" and "could not read" specifics must run BEFORE the generic `_isNetworkError(lower)` so that `"could not save: network unreachable"` gets labelled as a save failure, not a network error. Move lines 488-493 (the `'could not read'` + `'could not save'` blocks) ABOVE line 479 (`_isNetworkError(lower)`). (BUT-1145)
- [x] **A2. Add BUT-1145 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: stub `ImportManager.autoImport` to return `ImportManagerResult.failure('could not save: network unreachable')`. Drive `vm.startUrlImport(...)`. Assert the surfaced error string equals `AppLocale.current.importErrorCouldNotSaveRecipe` (NOT `importErrorCouldNotReachPage`). (BUT-1145)
- [x] **A3. BUT-1146: reset `_lastStepBeforeError` in `triggerManualImport`** — `lib/viewmodels/smart_import_viewmodel.dart:451-461`. Add `_lastStepBeforeError = 0;` before the `_setPhase(ImportPhase.needsHelp)` call. Reason: `needsHelp` is a user-initiated state with no "prior step that failed" — leaking the previous import's last-step into the progress strip is meaningless. (BUT-1146)
- [x] **A4. Add BUT-1146 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: drive a successful import to set `_lastStepBeforeError = 3` (via the `creating` phase), then call `vm.triggerManualImport()`, assert `vm.currentStep == 0` (or whatever the contract for `needsHelp` step should be — read the `currentStep` getter to confirm). (BUT-1146)
- [x] **A5. BUT-1147: short-circuit `_loadPendingImport` when user already typed** — `lib/viewmodels/smart_import_viewmodel.dart:534-550`. After the `isDisposed` check (line 537) and after reading the persisted URL (line 538), add `if (_input.isNotEmpty) return;` BEFORE setting `_hasPendingImport = true`. Effect: if the user typed before prefs resolved, neither the flag nor `notifyListeners()` fires. (BUT-1147)
- [x] **A6. Add BUT-1147 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: stub `SharedPreferences` to return a pending URL with a delay. Construct VM (fires `_loadPendingImport` in init). Before the delay completes, drive `vm.input = "https://user-typed.com"`. Wait for prefs to resolve. Assert `vm.hasPendingImport == false`. (BUT-1147)

### Step 0 — premise verification (done)

- **BUT-1145** verified: `smart_import_viewmodel.dart:479` runs `_isNetworkError(lower)` (matches "network" substring) BEFORE line 491 `'could not save'`. `"could not save: network unreachable"` correctly reproduces the bug.
- **BUT-1146** verified: `triggerManualImport()` at line 451 calls `_setPhase(ImportPhase.needsHelp)`. `_setPhase` at lines 508-510 only sets `_lastStepBeforeError` for `fetching/analyzing/creating` — `needsHelp` leaves whatever value was there.
- **BUT-1147** verified: `_loadPendingImport()` at lines 540-545: `_hasPendingImport = true` + `notifyListeners()` fire unconditionally; the `_input.isEmpty` guard only protects `_input` overwrite, not the banner flag.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib file.
- [x] Touched test file passes.
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1145 + BUT-1146 + BUT-1147 in Linear.

---

## Archived iter-83 (commit `ca66e0fce` — BUT-1144 + BUT-1070) — 2026-05-27 (Wed)

Theme: Two P3 import-area Bug tickets, single agent (small clean batch). Both are ticket-then-flip shape. No Phase 1.5 expansion — `import`/`parsing` aren't in the expansion-trigger label list. BUT-953 (heirloom wiring) considered but deferred — it's feature-completion work with product decisions, half-day scope, doesn't fit ticket-then-flip.

Theme: Two P3 import-area Bug tickets, single agent (small clean batch). Both are ticket-then-flip shape. No Phase 1.5 expansion — `import`/`parsing` aren't in the expansion-trigger label list. BUT-953 (heirloom wiring) considered but deferred — it's feature-completion work with product decisions, half-day scope, doesn't fit ticket-then-flip.

### Ship this sprint

#### Agent — Import surface fixes

- [x] **A1. ImportManagerResult: add `rateLimit(RateLimitDenied)` factory + `rateLimitDenied` field** — `lib/services/import/import_manager_result.dart`. New named ctor `ImportManagerResult.rateLimit(RateLimitDenied details)` with `isSuccess=false`, `errorMessage = details.message`, `strategy = 'rate_limited'`, and new field `RateLimitDenied? rateLimitDenied`. Existing `.success`/`.failure`/`.assistance` constructors initialise the field to `null`. (BUT-1144)
- [x] **A2. ImportManager: route rate-limit hit through the new factory** — `lib/services/import/import_manager.dart` around line 204 (and any other `strategy: 'rate_limited'` sites — grep for them). Replace `ImportManagerResult.failure('Importgräns nådd...', strategy: 'rate_limited')` with `ImportManagerResult.rateLimit(rateLimitDenied)` where `rateLimitDenied` is the structured `RateLimitDenied` returned by `rateLimiter.checkLimit(...)`. If checkLimit's current return shape doesn't surface `RateLimitDenied` to this caller, thread it through (read the rate-limiter API). (BUT-1144)
- [x] **A3. SmartImportViewModel: prefer structured rateLimitDenied over string-match synthesis** — `lib/viewmodels/smart_import_viewmodel.dart:330-350`. New shape: if `result.rateLimitDenied != null`, use it verbatim in `ImportRateLimited(...)`. Keep the existing string-match block as a fallback for back-compat — surrounding `if (result.rateLimitDenied != null) { use verbatim } else if (errorMessage contains rate-limit-words) { existing synth }`. (BUT-1144)
- [x] **A4. BUT-1144 pinning test flip** — `test/unit/viewmodels/smart_import_viewmodel_test.dart` (added in iter-81 batch-14 commit `d44509d3b`). Find the test that pins the current "always shows 1 hour retry" synth behaviour. Flip it: when ImportManager returns an `ImportManagerResult.rateLimit(...)` with `retryAfter: Duration(minutes: 5), limitType: perHour, suggestedAction: skipLlm`, the VM's resulting `ImportRateLimited` MUST carry those exact values (no synth override). (BUT-1144)
- [x] **A5. UrlImportStrategy._tryHtmlTextParse: detect non-Recipe JSON-LD + add strong warning** — `lib/services/import/url_import_strategy.dart:252-...`. Before invoking `TextImportStrategy.import`, parse JSON-LD scripts in the HTML. If any have `@type` set AND none of the values are `Recipe` (treating both string and list-of-string), prepend a strong warning to the resulting `ImportResult.warnings`: Swedish "Denna sida verkar vara en nyhetsartikel. Det extraherade innehållet kanske inte är ett riktigt recept." / English "This page appears to be a news article. The extracted content may not be a recipe." (option B from the ticket — keep extraction behaviour, escalate user signal). Add l10n keys `warningUrlImportNotARecipe` to both ARBs + @meta and use `AppLocale.current.warningUrlImportNotARecipe`. (BUT-1070)
- [x] **A6. BUT-1070 test flip** — `test/unit/services/import/url_import_strategy_test.dart:524`. Existing test "JSON-LD @type=Article does NOT trigger Tier 2" already asserts extraction_method is NOT schema.org. Extend it: now also assert `result.warnings` contains the new "news article" warning string (or its l10n key path). (BUT-1070)
- [x] **A7. Run `flutter gen-l10n`** after A5 ARB additions.

### Step 0 — premise verification (done)

- **BUT-1144** verified: `smart_import_viewmodel.dart:330-350` — VM string-matches `errorMessage` for 'rate limit'/'kvot'/'gräns', then synthesises new `RateLimitDenied(retryAfter: 1h, limitType: perDay, suggestedAction: useUserAssisted)`. `ImportManager.basicImport` at line ~204 returns `ImportManagerResult.failure('Importgräns nådd...', strategy: 'rate_limited')` after dropping the `RateLimitDenied` from `_rateLimiter`. The structured details ARE produced but never plumbed through.
- **BUT-1070** verified: `url_import_strategy.dart:252` `_tryHtmlTextParse` runs unconditionally if `bestHtml.length > 100`. No JSON-LD inspection happens at the tier-5 boundary. Existing pinning test at `url_import_strategy_test.dart:524` asserts current "extraction_method is NOT schema.org" behaviour but no warning-shape assertion. Picking option B from the ticket's 3 options — keep behavior, escalate warning copy.

### Acceptance

- [x] `flutter analyze --fatal-infos` clean on touched lib files.
- [x] Touched test files pass.
- [x] `flutter gen-l10n` succeeded after A5 ARB additions.
- [x] Orchestrating session runs full `dart analyze --fatal-infos`.
- [x] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1144 + BUT-1070 in Linear.

---

## Archived iter-82 (commit `3ea1a5253` — BUT-1138 + BUT-894 + BUT-1139 + BUT-1131) — 2026-05-27 (Wed)

Theme: Four P3 Bug tickets dispatched to 2 parallel agents. All small mechanical-fit shape (ticket-then-flip). Same proven pattern as iter-78/79/80. Phase 1.5 expansion fires on BUT-1131 and BUT-894 (Bug+social+recipe combo) — richer plan documented inline, no halt.

Theme: Four P3 Bug tickets dispatched to 2 parallel agents. All small mechanical-fit shape (ticket-then-flip). Same proven pattern as iter-78/79/80. Phase 1.5 expansion fires on BUT-1131 and BUT-894 (Bug+social+recipe combo) — richer plan documented inline, no halt.

### Ship this sprint

#### Agent A — Recipe lifecycle race + orphan hygiene

- [x] **A1. RecipeFormAutoSaveManager.clearCurrentDraft → async + await deleteDraft** — `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:387-392`. Method becomes `Future<void>` and `await`s `deleteDraft(_currentDraftId!)` before nulling. Update callers — grep all `clearCurrentDraft()` sites and either `await` or `unawaited(...)` per call-site intent. (BUT-1138)
- [x] **A2. Add race-pin test** — `test/unit/viewmodels/recipe_form/recipe_auto_save_manager_test.dart`. New test in clearCurrentDraft group: drive `await mgr.clearCurrentDraft(); await mgr.saveNow(form)`, assert the saved draft's metadata does NOT collide with the just-cleared draft's metadata. (BUT-1138)
- [x] **A3. Extend _cleanupRecipeReferences to delete shared_content (or shared_recipes) records** — `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:101-...`. Add a paginated batch delete of `FirestoreCollections.sharedContent` (verify exact constant name via grep) where `originalRecipeId == recipeId`. Mirror the existing pattern for comments/ratings/social_stats. Mind: if a `members` subcollection exists, follow the soft-cascade pattern already used elsewhere. (BUT-894)
- [x] **A4. Add BUT-894 orphan-cleanup test** — `test/unit/services/unified/modules/service_adapters/recipe_service_adapter_test.dart` (or its existing test file). Seed Firestore fake with a recipe + 1 shared_content record where `originalRecipeId == recipeId`. Call `deleteRecipe(recipeId)`. Assert: recipe doc gone AND shared_content record gone. (BUT-894)

#### Agent B — Diagnostic + silent-throw error surfacing

- [x] **B1. BackupService per-recipe error: read `core.title` with `title` fallback** — `lib/services/backup_service.dart:235`. One line: `recipeJson['core']?['title'] ?? recipeJson['title'] ?? AppLocale.current.backupUnknownRecipe`. The double fallback handles current nested + any future top-level shape. (BUT-1139)
- [x] **B2. Update test pin in backup_service_test.dart** — the test `'isolates per-recipe repository failures into errors list'` now asserts the error string contains the real recipe title (from `core.title`), not "Okänt recept". (BUT-1139)
- [x] **B3. SocialRecipeSharingService secondary-write: bump log severity warning→error + setError so UI can react** — `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:152-156`. Keep return `true` (primary write succeeded). Change `AppLogger.warning(...)` → `AppLogger.error(...)`. Add `_setError(AppLocale.current.errorSharedRecipeMayNotBeVisible)` (or similar — add l10n key to ARB + @meta; Swedish: "Receptet delades, men mottagaren kanske inte ser det. Försök igen om de inte hittar det."). (BUT-1131)
- [x] **B4. Add BUT-1131 error-surfaced test** — `test/unit/services/unified/modules/social_recipe/social_recipe_sharing_service_test.dart`. Test: primary write succeeds, secondary write throws → `shareRecipe` returns true (primary intent honoured) AND `service.error` is set to the new sanitized message. (BUT-1131)
- [x] **B5. Run `flutter gen-l10n` after B3** to regenerate AppLocalizations.

### Step 0 — premise verification (done)

- **BUT-1138** verified: `recipe_auto_save_manager.dart:387-392` — `deleteDraft(_currentDraftId!)` is unawaited as ticket describes. Method signature is `void clearCurrentDraft()`. Becomes `Future<void>`.
- **BUT-1139** verified: `backup_service.dart:235` — `recipeJson['title'] ?? AppLocale.current.backupUnknownRecipe`. Top-level read.
- **BUT-1131** verified: `social_recipe_sharing_service.dart:152-156` — warning log + comment "// Don't fail the whole operation if this secondary write fails" + no setError. Return path at line 162 returns `true`.
- **BUT-894** verified: `_cleanupRecipeReferences` at `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:101`. Currently cleans up comments + ratings + social_stats. Called from `deleteRecipe()` at line 76.

### ★ Risky-ticket plan — BUT-1131 ──────────────────
Classification: **fits** (Bug+social+recipe label triggers Phase 1.5 — surfacing a silent throw on a write path warrants the extra plan)
Files: `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart` (1 catch-block edit) + `lib/l10n/app_sv.arb` + `lib/l10n/app_en.arb` (new key `errorSharedRecipeMayNotBeVisible`) + test (1 new test) + regen.
Blast radius: catch block behavior changes from silent → setError(...) but return value stays `true`. UI callers that currently rely on `result == true` to mean "fully shared" will now see `service.error` non-null on the rare secondary-failure path. UI is free to read or ignore. No other callers (this is the unified service's public method; SocialMenuCoordinator's mirror was already fixed in iter-79 BUT-1094).
Product-intent flags: I'm choosing option A from the 4 options in the ticket (log+setError+keep returning true). Options B (retry), C (atomic rollback), D (partial-success type) are larger and folded into a follow-up if telemetry shows real frequency.
Rollback: revert the catch block; no schema, no API change. The new l10n key is additive.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### ★ Risky-ticket plan — BUT-894 ──────────────────
Classification: **fits** (Bug+social+recipe — orphan cleanup on delete path warrants the extra plan)
Files: `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart` (extend `_cleanupRecipeReferences` ~25-line addition mirroring the existing comments/ratings paginated-delete pattern) + test (1 new test).
Blast radius: every recipe delete now also runs a paginated query against the shared_content (or shared_recipes — agent confirms via grep) collection. For users who haven't shared the recipe, the query returns 0 docs and the batch is a no-op. For shared recipes, the recipient's inbox now correctly drops the dead reference. Pre-existing behaviour (graceful degrade on broken refs) means rollback is safe.
Product-intent flags: BUT-894 mentions "soft-delete epic" as a future option — that's NOT this ticket. This ticket is hard-delete cascade; soft-delete would supersede if/when it ships.
Rollback: revert the extension; orphan records remain (current behaviour). No schema effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [x] Each agent reports its touched test files pass.
- [x] `flutter gen-l10n` succeeded after BUT-1131 ARB addition.
- [x] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [x] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1138, BUT-1139, BUT-1131, BUT-894 in Linear.

---

## Archived iter-81 (commits `503a05567` + `991a8a653` — BUT-1063 + BUT-1062 + BUT-1074) — 2026-05-27 (Wed)

Theme: Three independent testability tickets dispatched to 3 parallel agents. All add testability seams (ctor params or rename to `Fake` shape).

Theme: Three independent testability tickets dispatched to 3 parallel agents. All add testability seams (ctor params or rename to `Fake` shape).

### Ship this sprint

#### Agent A — BUT-1063 RecipeParserService cache ctor seam
- [x] Add `cache:` ctor param to `RecipeParserService` accepting a `LocalRecipeCache` interface (or expose the existing DAO via `@visibleForTesting` ctor).
- [x] Unlocks ~5 cache-behaviour unit tests in `recipe_parser_service_test.dart`.

#### Agent B — BUT-1062 UnifiedMenuService DI seam
- [x] Add ctor params: `sharedMenuRepository`, `menuService`, `userService`, `realtimeMenuService` — each with default factory falling back to ServiceLocator/production. Mirrors the existing `firestoreRepository` pattern.
- [x] Unlocks ~5 currently-skipped tests in `unified_menu_service_test.dart`. No new tests required this sprint — the DI seam is the deliverable.

#### Agent C — BUT-1074 MockAuthRepository rename to FakeAuthRepository
- [x] Rename `MockAuthRepository` → `FakeAuthRepository` and switch from `extends Mock` to `extends Fake implements AuthRepository` in `test/infrastructure/mocks/production_mocks.dart`.
- [x] Audit all callers (grep `MockAuthRepository`); update any caller that was relying on `when()` (those tests were already broken — the `when()` was silently overridden by the concrete @override getters).

### Acceptance

- [x] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [x] Each agent reports its touched tests pass (or, for BUT-1062, that existing tests still pass — no new tests required).
- [x] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified commit + push. (commit `503a05567`)
- [x] Close BUT-1063, BUT-1062, BUT-1074 in Linear. (closed 2026-05-27)
- [x] File follow-ups: BUT-1141 (cache tests), BUT-1142 (collaborative-ops DI seam), BUT-1143 (delete dead configureAuthStateStream).

---

## Archived iter-80 (commit `4f6489ea4` — BUT-1087 + BUT-1114 + BUT-1125) — 2026-05-26 (Tue)

Theme: Three P3 tickets dispatched simultaneously to 3 general-purpose agents. Each cluster touches an independent file tree so there's no merge collision. Orchestrating session does the unified commit.

### Ship this sprint

#### Agent A — SocialRecipeService error-state refactor (BUT-1087)
- [x] **A1. Extract `_setErrorFromException(String message, Object e)` helper + call from every catch block in `social_recipe_service.dart`** (lines 130, 145, 185, 230, 283, 300 cited).
- [x] **A2. Clear `_error = null` at the entry of each public mutator** (or via `_resetError()` helper at method top).
- [x] **A3. Flip pinning tests in `social_recipe_service_test.dart`** — undismiss/markAsViewed/import false returns now ALSO populate `service.error`. Add test for "success after failure clears error".

#### Agent B — InstagramPipeline tier-2 source provenance (BUT-1114)
- [x] **B1. Add `instagramCaption` enum value to `SourceArtefactType`** in `lib/models/recipe/source_artefact.dart`.
- [x] **B2. In `instagram_pipeline.dart` tier-2 success path: copyWith sourceUrl=input + SourceArtefact(type: instagramCaption, payload: caption)**. Mirror the tiktok_pipeline shape.
- [x] **B3. Adjust instagram_pipeline_test.dart docstring** to reflect that BUT-1114 is fixed (production-level — full pin requires WebScraper injection seam, deferred).

#### Agent C — SocialShoppingCoordinator perf parallelize (BUT-1125)
- [x] **C1. `loadStatusForShoppingList`: collapse 3 sequential awaits via `Future.wait([hasViewed, hasEngaged, hasDismissed])`**.
- [x] **C2. `loadStatusForAllShoppingLists`: parallelise via `Future.wait(shoppingLists.map(...))`**.
- [x] **C3. Update / add test verifying the parallel-fetch contract** — assert all 3 stat reads are issued before any await on the next list item.

### Step 0 — premise verification

Delegated to each agent's first phase. Each agent must read current code state, classify fits/premise-gone/plan-stale, and report classification before implementing.

### Acceptance

- [x] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [x] Each agent reports its touched test files pass.
- [x] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [x] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified `git add` + commit + push.
- [x] Close BUT-1087, BUT-1114, BUT-1125 in Linear.

---

## Archived iter-79 (commit `0f339ad43` — BUT-1107 + BUT-1108 + BUT-1098 + BUT-1100 + BUT-1124) — 2026-05-26 (Tue)

Theme: Five small mechanical-fit P3 Bug tickets. Two batches with cross-cluster discipline (BUT-1108 = security label, triggers Phase 1.5 expansion). Deferred: BUT-1087 (service-wide refactor — bigger than ticket-then-flip shape), BUT-1106 (Firestore transaction redesign — needs careful blast-radius review).

### Ship this sprint

#### Agent A — Shopping social share-module hardening

- [x] **A1. ShoppingSocialShareModule.importSharedShoppingList: switch `.update()` → `.set(..., merge:true)`** — `lib/services/unified/operations/modules/shopping_social_share_module.dart:343-351`. (BUT-1107)
- [x] **A2. Flip "no received pointer" pinning test** — `test/unit/services/unified/operations/modules/shopping_social_share_module_test.dart:916-935`. Now asserts `out == sharedListId` (import succeeds, pointer created) instead of `isNull`. (BUT-1107)
- [x] **A3. ShoppingSocialShareModule.getShoppingListsSharedWithMe: add `sharedWithUserIds.contains(currentUserId)` check in inbox loop** — same file, around line 256-272 (before the `sharedLists.add({...})` block). Defense-in-depth — implicit access via received_lists pointer is no longer the only gate. (BUT-1108, security)
- [x] **A4. Add BUT-1108 defense-in-depth test** — same test file. New test in `getShoppingListsSharedWithMe` group: seed a shared doc WITHOUT current user in `sharedWithUserIds`, plus a received_lists pointer, and assert the entry is filtered out of the result. (BUT-1108)

#### Agent B — Presence + legacy social-coord error hygiene

- [x] **B1. PresenceService.dispose: split set(offline) + cancel into separate try-blocks** — `lib/services/presence_service.dart:171-178`. (BUT-1098)
- [x] **B2. PresenceService.resetForLogout: same split** — same file, lines 190-197. (BUT-1098)
- [x] **B3. Add BUT-1098 "cancel-after-set-throws" test** — `test/unit/services/presence_service_test.dart`. New test in dispose() group: when `ref.set(any())` throws, `disconnect.cancel()` MUST still be called. (BUT-1098)
- [x] **B4. PresenceService.didChangeAppLifecycleState: wrap fire-and-forget RTDB writes in `.catchError`** — `lib/services/presence_service.dart:332-353`. Use `unawaited(_presenceRef?.set(...).catchError((e) { AppLogger.warning(...); }))` for each set/onDisconnect call. (BUT-1100)
- [x] **B5. Add BUT-1100 "lifecycle-state errors are swallowed" test** — `test/unit/services/presence_service_test.dart`. Drive `didChangeAppLifecycleState(paused)` after stubbing `ref.set(any())` to throw — assert no unhandled async exception escapes. (BUT-1100)
- [x] **B6. SocialMenuCoordinator legacy `importSharedMenu`: add `setError(sanitizeErrorForUser(e))` to catch** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:354-357`. Mirrors the BUT-1094 fix pattern already shipped on the non-legacy paths. (BUT-1124)
- [x] **B7. Add BUT-1124 setError test for legacy path** — `test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart`. New test: legacy `importSharedMenu` repo throw → setError called with sanitised message, lastError populated. (BUT-1124)

### Step 0 — premise verification (done)

- **BUT-1107** verified: `shopping_social_share_module.dart:343-351` — `.update()` on missing received_lists doc throws `FirebaseException(not-found)`, swallowed at line 355-358. Pinning test at line 916-935 in test file.
- **BUT-1108** verified: `getShoppingListsSharedWithMe` lines 254-272 build result map WITHOUT `sharedWithUserIds` membership check. `importSharedShoppingList` already has this check at line 335-340 — adding the same shape to the inbox read.
- **BUT-1098** verified: `presence_service.dart:172-178` (dispose) and 190-197 (resetForLogout) both have `set` + `cancel` in same try block. Existing test at line 428 only asserts `dispose() completes` — doesn't pin the "cancel still runs after set throws" contract.
- **BUT-1100** verified: `presence_service.dart:332-353` — `didChangeAppLifecycleState` fires off 3 RTDB calls (`paused`-branch set, `resumed`-branch onDisconnect.set + set) with no await + no catch.
- **BUT-1124** verified: `social_menu_coordinator.dart:354-358` — legacy `importSharedMenu` catch logs but does NOT call `setError(sanitizeErrorForUser(e))`. Diverges from the BUT-1094 pattern shipped on the non-legacy paths (line 376 reference).

### ★ Risky-ticket plan — BUT-1108 ──────────────────
Classification: **fits** (security label on a defense-in-depth fix — mechanical but matters)
Files: `lib/services/unified/operations/modules/shopping_social_share_module.dart` (1 inserted check in loop) + test (1 new test).
Blast radius: `getShoppingListsSharedWithMe` becomes stricter. Any list where the user has a `received_lists` pointer but is NOT in the canonical `sharedWithUserIds` is now invisible. Practically this should never happen under correct Firestore rules — the implicit gate (rules + pointer creation) already prevents it. The new check is belt-and-suspenders for rule regressions. Verified: no test depends on the "stranger pointer succeeds" path (would be a security test failure if it did).
Rollback: revert the one-line `continue`; no schema or data effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] Each touched test file passes.

### Post-Sprint Steps

- [x] Run code-reviewer + testing-specialist agents per Tier-2 gate.
- [x] Commit + push.
- [x] Close BUT-1107, BUT-1108, BUT-1098, BUT-1100, BUT-1124 in Linear.

---

## Archived iter-78 (commit `1a07a77a7` — BUT-1092 + BUT-1113 + BUT-1116 + BUT-1091 + BUT-1118 + BUT-1128 + BUT-1102) — 2026-05-26 (Tue)

Theme: Seven P3 Bug tickets from intent-test sprint batches 5–10, all "ticket-then-flip" shape. Two coherent batches: Agent A (4 import-regex bugs) + Agent B (3 upload-status bugs). Same proven pattern as iter-76/77.

### Ship this sprint

#### Agent A — Imports: case-sensitivity + host-anchoring (regex hardening)

- [x] **A1. TikTokPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/tiktok_pipeline.dart:56-65`. (BUT-1092)
- [x] **A2. Flip tiktok pinning test** — `test/unit/services/import/pipelines/tiktok_pipeline_test.dart`. `isFalse` → `isTrue` on mixed-case host case. (BUT-1092)
- [x] **A3. InstagramPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/instagram_pipeline.dart:22-26`. (BUT-1113)
- [x] **A4. Flip instagram pinning test** — `test/unit/services/import/pipelines/instagram_pipeline_test.dart`. Mixed-case host PINNED→passes. (BUT-1113)
- [x] **A5. YouTubeTranscriptService: add `caseSensitive: false` to 6 video-ID patterns** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. (BUT-1116)
- [x] **A6. Flip youtube_import_strategy_test sibling-hunt assertion** — `test/unit/services/import/youtube/youtube_import_strategy_test.dart`. (BUT-1116)
- [x] **A7. YouTubeTranscriptService: anchor host regex (typosquat fix)** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. Add `^https?://(?:www\.|m\.)?` prefix to youtube.com patterns, `^https?://` to youtu.be. Keep bare-ID pattern unchanged. (BUT-1091)
- [x] **A8. Flip youtube_transcript_service_test CHARACTERIZATION** — `test/unit/services/import/youtube/youtube_transcript_service_test.dart`. `equals(_vid)` → `isNull` for typosquat cases. (BUT-1091)

#### Agent B — Upload status bugs

- [x] **B1. UploadQueueManager.addCompletedUpload: add containsKey guard** — `lib/services/upload/upload_queue_manager.dart:58-69`. Mirror `addUpload` warning+no-op shape. (BUT-1118)
- [x] **B2. Flip upload_queue_manager_test "asymmetry" pinning test** — `test/unit/services/upload/upload_queue_manager_test.dart:168-186`. Assert pre-existing entry is PRESERVED (state == uploading, progress == 0.4) and warning is logged. (BUT-1118)
- [x] **B3. ImageUploadCoordinator: replace errorGeneric with sanitizeErrorForUser(e)** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart:120-123`. Import `error_sanitizer.dart` if needed. (BUT-1128)
- [x] **B4. Add image_upload_coordinator fatal-batch test** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. New test in "fatal-batch" group: when storage throws a typed exception (e.g. FormatException with message), assert errorsSet contains a sanitised message (NOT "Ett fel uppstod"). (BUT-1128)
- [x] **B5. UploadQueueSummaryCalculator: thread cancelled through + add all-cancelled branch** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart`. Add `cancelled` param to `getEnhancedQueueStatusText` (positional, after total). Call site at line 123 passes `cancelled`. Branch before final `else`: `if (cancelled > 0 && active == 0 && pending == 0 && failed == 0 && completed == 0) return l.uploadStatusAllCancelled(cancelled);`. Add l10n key `uploadStatusAllCancelled` to `app_sv.arb` + `app_en.arb` + `@meta`. (BUT-1102)
- [x] **B6. Update upload_queue_summary_calculator_test all-cancelled pin** — `test/unit/viewmodels/recipe_form/image_management/upload_queue_summary_calculator_test.dart:445-450`. Assert text contains '2' and the Swedish/English "alla avbrutna" substring (or just non-empty + cancelled count). Update positional args to include `cancelled`. (BUT-1102)

### Step 0 — premise verification (done)

- **BUT-1092** verified: `tiktok_pipeline.dart:56-65` — 4 `RegExp` lack `caseSensitive: false`. `_isTikTokUrl` lowercases for substring check, then matches original-case `url` against case-sensitive regex.
- **BUT-1113** verified: `instagram_pipeline.dart:21-26` — same shape as BUT-1092, 4 patterns.
- **BUT-1116** verified: `youtube_transcript_service.dart:20-32` — 6 patterns, all case-sensitive.
- **BUT-1091** verified: `youtube_transcript_service.dart:22-30` — no host anchoring; `iyoutube.com/watch?v=...` would match.
- **BUT-1118** verified: `upload_queue_manager.dart:58-69` — unconditional `_queue[key] = ...`. Note ticket says `_uploads` but file uses `_queue` (cosmetic).
- **BUT-1128** verified: `image_upload_coordinator.dart:120-123` — `_setError(AppLocale.current.errorGeneric)`. `sanitizeErrorForUser` exists in `lib/core/utils/error_sanitizer.dart`.
- **BUT-1102** verified: `upload_queue_summary_calculator.dart:155-157` — final `else` returns `''`. Function signature does NOT take `cancelled` — needs threading.

### ★ Risky-ticket plan — BUT-1091 ──────────────────
Classification: **fits** (security label on a regex-validation gate — caution warranted but mechanical)
Files: `lib/services/import/youtube/youtube_transcript_service.dart` (5 regex prefix additions) + test (typosquat assertion flips).
Blast radius: `isYouTubeUrl` becomes stricter. Any legitimate URL caller (share-sheet, paste, channel-watch) MUST start with `http(s)://(www.|m.)?youtube.com` or `http(s)://youtu.be`. Verified: production callers all originate from URL-import flows where the source is already a full URL. The bare-ID pattern is preserved for direct ID entry.
Rollback: revert the prefix additions; no schema or data effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] Each touched test file passes.
- [x] `flutter gen-l10n` succeeded after BUT-1102 ARB additions.

### Post-Sprint Steps

- [x] Run code-reviewer + testing-specialist agents per Tier-2 gate.
- [x] Commit + push.
- [x] Close BUT-1092, BUT-1113, BUT-1116, BUT-1091, BUT-1118, BUT-1128, BUT-1102 in Linear.

---

## Archived iter-77 (commit `7b2d25b35` — BUT-1085 + BUT-1090) — 2026-05-25 (Mon)

Both P2 High social-bug fixes shipped via ticket-then-flip. Acceptance met. BUT-1086 stays open (deferred — needs product decision).
