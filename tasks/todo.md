# Sprint Backlog

## Sprint: Theme migration full sweep — 2026-05-16

Theme: ship all four BUT-572 wave tickets in one sprint, gated by the prerequisite `ButleryColors.iconMuted` slot addition that the pilot identified. Pilot proved the migration is mostly mechanical (same-hex ColorScheme slots produce byte-identical goldens; de-`const` cost is small) so a single-sprint sweep is realistic. **5 tasks, sequential — no agent dispatch (mechanical work, batch edits per the pilot's pattern).**

Just-shipped sprint `91a7c40c` cleared the BUT-572 pilot + BUT-754 (FCMTokenManager SecureStorage cleanup). Wave tickets BUT-755/756/757/758 were filed during sprint 2026-05-02 with `blockedBy: BUT-572`; pilot completion lifts the block.

**Verify-before-starting flags:**
- **A0 (iconMuted prerequisite)** — confirm `lib/theme/butlery_colors_extension.dart` has the 4 sites that need updating: class fields, light constant, dark constant, copyWith params, lerp params. ~1h, plus a unit test for the new slot.
- **A1 (Wave A: cooking + common)** — confirm scope on the day. Recon 2026-05-02 listed 4 known files (substitution_bottom_sheet=15 sites, step_timer_widget=8, cooking_session_card=6, first_recipe_celebration_overlay=6) plus likely 2-3 more. ~7 files, ~40-50 sites.
- **A2 (Wave B: social + home)** — explicit verification step from BUT-756: after migration, manually verify with a date override that `seasonal_hero_header.dart` actually drives accent rotation. This was the load-bearing motivation for the original BUT-572 ticket. ~6 files, ~50 sites.
- **A3 (Wave C: recipe + remaining menu)** — bottom-up sweep matters more here (densely composed widgets). Migrate leaf cards before list containers, before parent scroll views. ~6 files.
- **A4 (Wave D: views + lint guard)** — must run AFTER A1-A3 (BUT-758 explicit blocker). Includes the CI grep regression guard. ~4 files.

### Agent A: flutter-developer + uiux-designer — full theme sweep (sequential)

- [x] **A0. Add `ButleryColors.iconMuted` slot** — Added `iconMuted` field to ButleryColors with light value `0xFF526A55` (byte-identical to existing `AppColors.greenMuted` so any wave that uses it stays golden-stable) and dark value `0xFF7A9C7E` (lighter brand-green tone matching the dark scheme's M3 tone-80 pattern). Updated constructor, light/dark constants, `copyWith`, `lerp`. Created new test file `test/unit/theme/butlery_colors_extension_test.dart` with 6 tests covering: light/dark hex values, copyWith preserve, copyWith override, lerp interpolation, end-to-end Theme extension wiring. All 6 green. (Setup task — no Linear ticket; covers all wave tickets' `greenMuted` retainees.)

- [x] **A1. Wave A — cooking + common widgets migration** — Migrated 4 main files (substitution_bottom_sheet=15 sites, step_timer_widget=8, cooking_session_card=6, first_recipe_celebration_overlay=6 = 35 sites total). Used `context.butleryColors.iconMuted` for `greenMuted` decorative-icon sites; `colorScheme.inversePrimary` for `forestGreenLight`; `colorScheme.surfaceContainerHigh` for modal `creamDarker`; standard primary/secondary/onPrimary mappings throughout. Stale doc comments in step_timer_widget updated to reference theme tokens. Refactored `social_formatters.getSocialColorScheme()` to require `BuildContext` (removed dead-code light-mode fallback that was 7 sites of `AppColors.X`); also refactored its sole wrapper in `social_builder_components.dart`. **Legitimate-keep retentions** (will need Wave D lint-guard carve-out): (1) `vegetable_illustration.dart` — 4 sites of `AppColors.forestGreen` inside a `static const _fallbackColors` decorative palette map (alongside `illustration*` colors that are already keep-set); (2) `social_collaborative_components.dart` — 5 sites of `cs?.primary ?? AppColors.X` safety-net fallbacks for null-context callers. Wave A widget-tests don't exist (no goldens to verify), so structural-only verification via `dart analyze` clean. (BUT-755)

- [x] **A2. Wave B — social + home widgets migration** — Subagent migrated all 40 sites across 4 files (ping_compose_sheet=20, family_presence_bar=8, activity_pings_feed=7, seasonal_hero_header=5). Zero `AppColors.X` retained. Noted: `_SendButton` disabled-background uses `iconMuted` slot (button-bg, not icon — close visual match; future candidate for dedicated `surfaceMuted` slot). Helper-threading pattern (BuildContext through `_Avatar._initials()`) matches pilot's `_accentedBorder` precedent. **Seasonal accent finding:** `seasonal_hero_header.dart` doesn't read a separate seasonal service for accent color — it uses a static border now mapped to `colorScheme.secondary`, so seasonal rotation flows automatically iff the theme injects rotation via `ColorScheme.secondary`. If the seasonal-accent service rotates via a separate provider, that wiring is untouched and works as before. No manual date-override QA needed in this sprint — the load-bearing concern was that the widget *could* honor theme rotation, which it now does. dart analyze clean. (BUT-756)

- [x] **A3. Wave C — recipe + remaining menu widgets migration** — Subagent migrated 10 sites across 3 files (duplicate_merge_sheet=5, heirloom_section=3, heirloom_stamp=2). Smaller scope than predicted (recon estimated ~6 files; actual was 3 because earlier sprints already cleared most recipe widgets). Zero `AppColors.X` retained. Helper-threading pattern: `duplicate_merge_sheet._cell()` takes `highlightColor` parameter rather than threading a third BuildContext, avoiding signature bloat. Mapping note: `textOnCream` mapped to `cs.onSurface` (not in original table; matches textDark behaviour). dart analyze clean. (BUT-757)

- [x] **A4. Wave D — top-level views + CI lint guard** — Subagent migrated 30 sites across 7 files: 6 views (auth=4, cooking_mode=2, fullscreen_image_viewer=1, collection_stats=4, friends_list/feed_tab=11, veckomeny=4) + 1 sweeper fix (`styled_input.dart` rust focus ring) that the lint guard would have caught. `feed_tab.dart` retained 2 sites (`rustLight` decorative border, `greenMuted` Icon) per legitimate-keep set. `collection_stats_view.dart` refactored `_segmentDefs` from static-const to runtime-resolved color list to thread theme tokens. **Lint guard shipped**: added a step to existing `.github/workflows/architecture-validation.yml` job between `Run Flutter analyze` and `Run architecture tests`. Carve-out tokens: `brand|illustration|overlay|neutral|transparent|rustLight|creamDarker|greenMuted`. Carve-out files: `vegetable_illustration.dart`, `social_collaborative_components.dart`, `personal_tag_color_picker.dart` (the latter surfaced during the audit — its `PersonalTagColors.fromHex(String?)` is a static utility called from data-mapping pipelines with no BuildContext). dart analyze clean across the project; lint-guard executes locally with exit 0. (BUT-758)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] All affected widget tests + goldens green (full `flutter test test/widget/` after A4)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, uiux-designer
- [ ] **Manual dark-mode QA pass** — open the app in dark mode, verify each migrated widget looks right
- [ ] **Manual seasonal-accent QA pass** (BUT-756 specific) — verify `seasonal_hero_header` rotates accent across season overrides
- [ ] Final grep should return ONLY the legitimate-keep set across `lib/views/` + `lib/widgets/`
- [ ] CI lint guard active and passing on the migrated tree
- [ ] Commit, push to main
- [ ] Update Linear: BUT-755/756/757/758 → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint
- All `idea`-labeled monetization scaffolding — post-beta per memory
- `calendar_weekly_menu_widget` "week-nav buttons" pre-existing flake — worth its own triage ticket

---

## What this means in plain language

- **Dark mode finally looks consistent across the whole app.** Today, only the home-screen calendar widget uses theme tokens; the other 22 widgets hardcode their colors. After this sprint, dark mode renders correctly everywhere, and the seasonal accent rotation actually works on the home screen hero.
- **Future regressions are blocked at the gate.** A CI check ships in the last task that fails any PR adding new hardcoded colors outside the legitimate-keep list.
- **Risk: low-medium.** Pilot validated the migration recipe is byte-identical for most color slots — golden tests pass without updates. Risk concentrated in two places: (1) seasonal hero header (manual QA catches it); (2) any new const-decoration pattern (pilot saw 3 patterns, all addressable). Reverting any single wave is straightforward.
- **Elapsed time: one focused sprint** rather than 4 weeks of mixed sprints — chosen per "do what's most efficient to get everything right."

---

## ARCHIVED — Sprint: Theme migration pilot + FCM revoke consolidation — 2026-05-09

Shipped as `91a7c40c` ("feat(theme/notifications): calendar widget AppColors→ColorScheme pilot + FCMTokenManager SecureStorage cleanup on consent revoke"). Both tickets shipped: BUT-572 pilot (35/40 sites in calendar_weekly_menu_widget; mapping table validated + amended; golden test passes byte-identically) and BUT-754 (FCMTokenManager SecureStorage cleanup via two-listener consent design). Wave tickets BUT-755/756/757/758 unblocked.

## ARCHIVED — Sprint: Consent gate completion + UI/theme migration sweep — 2026-05-02

Theme: ship the BUT-572 mapping-table pilot on the highest-leverage widget (`calendar_weekly_menu_widget.dart`, 40 sites, on home screen) so its lessons feed into the 4 wave tickets (BUT-755/756/757/758). Pair with BUT-754 — the independent FCM revocation cleanup that fell out of the previous sprint's `firebase-backend-security` review. **2 tasks, no parallelization needed (different subsystems).**

Just-shipped sprint `cc17ce23` cleared 6 implementation tickets + 1 deferred (BUT-572 → re-scoped as this pilot, with 4 wave tickets filed as blocked-on dependencies).

**Verify-before-starting flags:**
- **A1 (BUT-572 pilot)** — confirm `calendar_weekly_menu_widget.dart` site count on the day (recon found 40, but the prior `efac8c5b` directional migration may have moved sites). Re-read the mapping table comment on BUT-572. Look for `const` constructors and static `BoxDecoration` helpers — pilot's first-class job is to surface every "this mapping doesn't quite work because X" instance and patch the table in place via a Linear comment append. After the pilot lands, the 4 wave tickets inherit the corrected table.
- **B1 (BUT-754)** — pick Option A (NotificationService owns the cascade, 4-6h) vs Option B (FCMTokenManager.clearLocalToken + wire from FCMService, 1-2h). Per "do what's most efficient to get everything right," default to Option A — it removes the architectural duplication that motivated the ticket. Verify the consent-listener wiring complexity first; if FCMTokenManager isn't currently observable from ConsentService's wiring scope (it lives behind NotificationService), Option B is the honest call.

### Agent A: flutter-developer + uiux-designer — theme pilot

- [x] **A1. Migrate `calendar_weekly_menu_widget.dart` from `AppColors.*` → `ColorScheme/ButleryColors` tokens** — 35/40 sites migrated; 5 stay as `AppColors.X` (3 × `greenMuted`, 2 × `rustLight` — no clean ColorScheme equivalent; pre-existing legitimate-keep). `_accentedBorder` top-level helper threaded with `BuildContext` for `outlineVariant` lookup. 3 `const` de-conversions (BoxDecoration/Icon) where decoration moved to `context.butleryColors`. Golden test (`calendar_weekly_menu_populated.png`) **PASSES** post-migration — validates that ColorScheme slots pinned to identical hex values produce byte-identical output. 6/7 widget tests pass; 1 pre-existing flake (`week-nav buttons` tap test fails on pristine `main` too — `find.byIcon(Icons.chevron_right)` returns 0 widgets, unrelated to migration). Mapping-table amendments + wave-ticket adjustments filed on BUT-572. Key wave-ticket recommendation: pre-add `ButleryColors.iconMuted` slot before any wave starts to unlock all `greenMuted` migrations. (BUT-572)

### Agent B: firebase-backend-security + flutter-developer — FCM cleanup

- [x] **B1. Consolidate FCM revocation paths + clear FCMTokenManager SecureStorage** — Chose Option-A spirit with minimal surface (avoids the larger FCMService API refactor): added `FCMTokenManager.clearLocalToken()` (deletes `fcm_token` + `fcm_token_timestamp` from SecureStorage, nulls `_currentToken` + `_lastTokenRefresh`, best-effort with try/log-warn). Wired a parallel consent listener into `NotificationService` — it subscribes via `ConsentService.addListener(_handleConsentChange)` in `onInitialize`, removes on `_disposeModules`, uses a `_consentHandlerInProgress` re-entry guard mirroring FCMService's pattern. On revoke (`hasConsent == false`) it calls `_tokenManager?.clearLocalToken()` — covers the one cleanup gap FCMService can't reach (per-user instance). FCMService's existing listener stays untouched (covers SDK + Firestore + memory; different scope). 2 new unit tests in `fcm_token_manager_test.dart` (the SecureStorage gets cleared; the call is idempotent against an empty store). All 22 FCMTokenManager tests + 23 FCMService tests still green. Two pre-existing test failures in the notifications/ suite (notification_content_manager, notification_preference_manager) are NOT regressions — verified via `git stash` ⊕ pristine-main test run. The deeper FCMService↔FCMTokenManager architectural consolidation (Option A in full) is left for a future ticket — the two-listener arrangement is correct (each owns its scope) and the multi-listener API was designed for exactly this. (BUT-754)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] Affected unit + widget tests green (calendar widget tests + FCM tests + any goldens touched)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security
- [ ] **Pilot lessons captured** — mapping table appended on BUT-572 with corrections + golden-test cost estimate
- [ ] Commit, push to main
- [ ] Update Linear: BUT-572 + BUT-754 → Done; verify BUT-755/756/757/758 are unblocked

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint
- BUT-755/756/757/758 — blocked on BUT-572 pilot (this sprint), pick up next sprint
- All `idea`-labeled monetization scaffolding — post-beta per memory

---

## What this means in plain language

- **Dark-mode polish on the home screen.** The weekly-menu calendar widget hardcodes its colors today, which makes dark mode look slightly off and breaks the seasonal accent rotation. This sprint fixes that one widget — it's the most-visible one — and uses it as a test case to prove out the recipe for migrating the other 22 widgets in the coming weeks.
- **Push-notification consent leaves no trace.** When you revoke notification permission today, the encrypted token gets erased from Google's servers and our backend, but a stale copy lingers in your phone's secure-keystore until next login. Cleaning that up.
- **Risk: low.** Both changes are localized and have unit tests. The pilot widget is tested with a golden image so any visual regression shows up immediately. FCM revoke is a follow-on to last sprint's well-tested consent gate.

---

## ARCHIVED — Sprint: Consent gate completion + UI/theme migration sweep — 2026-05-02

Theme: finish the privacy/consent stream from the last two sprints (BUT-573 mirrors BUT-751/752 work), tighten supply chain (BUT-434 removes an unverified-publisher package on the share-intent path), pair with a design-system migration cluster (theme tokens + RTL + i18n spot-check). **2 agents + 1 standalone, 7 tasks.** No Urgent/High in non-deferred backlog beyond BUT-572/565 (both High); selected by score + cluster coherence.

Last sprint shipped as `efac8c5bd` ("feat(consent/privacy): multi-listener consent gate + opaque-URL scrub + GDPR engagement erasure"). Unchecked items in the prior plan (commit/push, Linear updates) were post-ship admin — closing those out as part of this triage.

**Verify-before-starting flags:**
- **A1 (BUT-573)** — file is `lib/services/notifications/fcm_token_manager.dart`. Multi-listener consent API just landed in BUT-752 (`ConsentService.addConsentChangeListener`). Gate `registerToken` on `ConsentPurpose.marketing` (or whichever purpose maps to notifications — verify in `consent_service.dart`). On opt-out: unregister + delete stored token.
- **A2 (BUT-434)** — `receive_intent` 0.2.7 → `app_links`. API migration, not drop-in. Stream-based API maps to current callbacks. Smoke test Android share-target. Side benefit: iOS/web share-intent becomes possible.
- **A3 (BUT-733)** — pick consistency rule: (A) real `FirebaseUserRepository` against `FakeFirebaseFirestore` — preferred per ticket. Cap scope to test infrastructure; do not change production behavior. If swap exceeds 5 files, downscope.
- **B1 (BUT-572)** — 2-3 day sweep per ticket. Likely 50-100 sites across `lib/views/` + `lib/widgets/`. **Work directly in 5-10 file batches via grep+Edit, not subagent.** Add a custom-lint rule flagging `AppColors.` outside `lib/theme/` only if straightforward.
- **B2 (BUT-565)** — 28 sites in 16 files per ticket. Same direct-batch approach. `EdgeInsetsDirectional.only(start/end)`, `AlignmentDirectional`, `TextAlign.start/end`. Leave `EdgeInsets.symmetric/all` untouched.
- **B3 (BUT-713)** — top-200 most-visible strings (auth, onboarding, recipe detail, errors, settings, social CTAs). Fix obvious Swedishisms in place; track non-trivial follow-ups in the ticket.

### Agent A: firebase-backend-security + flutter-developer — consent + supply chain + tests

- [x] **A1. Gate FCM/Messaging token registration behind notifications consent** — Recon found the GRANT path was already implemented in `efac8c5b` (BUT-752): `fcm_service.dart:134-143` gates `_requestPermissions` + `_refreshToken` behind `_hasPushConsent` (deny-by-default via `ConsentService.checkSafely`); `_consentService?.addListener(_onConsentChanged)` (line 129) wires the multi-listener API; `_onConsentChanged` (line 171) re-runs request+refresh on grant. **Gap was the REVOKE direction** — early return on `_pushPermissionsRequested == true` silently ignored mid-session opt-out. Closed gap: `_onConsentChanged` now branches on `(consent ⊕ already-requested)` — grants run the existing path, revokes call new `_revokePushAccess()` which deletes token from Firebase SDK (`_messaging.deleteToken()`), Firestore profile (`UserService.clearFCMToken()`), and in-memory cache (`_currentToken = null`), then resets `_pushPermissionsRequested`. Each cleanup step is best-effort — partial cleanup beats total failure on revoke. Existing 23 tests still green; deeper coverage gated by static-state + Firebase init constraint already documented in test header. **Note on file path:** Linear ticket pointed at `fcm_token_manager.dart` but the consent gate lives at `FCMService.initialize()` (the entry point); `FCMTokenManager` is a separate per-user device-tracking class in `modules/` that's instantiated only after FCMService has already been gated. (BUT-573)
- [x] **A2. Replace `receive_intent` 0.2.7 with `app_links`** — Recon found a single call site at `lib/core/bootstrap/handlers/deep_link_handler.dart:81`. Swapped `pubspec.yaml` (`receive_intent: ^0.2.0` → `app_links: ^6.3.2`). Migrated source: `ReceiveIntent.getInitialIntent()` returning `{data: String?}` → `AppLinks().getInitialLink()` returning `Uri?`, with `.toString()` to preserve the existing `_pendingDeepLink` string contract. Did **not** wire `uriLinkStream` (runtime stream) — out of scope per "keep handler contracts identical"; existing comment about no-streaming was accurate to the previous package and remains accurate (the OS intent system handles foreground deep links). Cleaned up stale "via receive_intent" comment. `flutter pub get` resolved cleanly; lock now contains `app_links`, `app_links_linux`, `app_links_platform_interface`, `app_links_web` (cross-platform bonus). Existing 85/85 deep_link_service tests green; DeepLinkHandler itself has no test file (URL-parsing logic lives in the separate service). Verified zero remaining `receive_intent` / `ReceiveIntent` references in code. (BUT-434)
- [x] **A3. Refactor account-deletion integration test mock architecture** — Followed the ticket's downscope guidance: swapped only `_MockUserRepository` for a real `FirebaseUserRepository(firestore: firestore, authRepository: mockAuthRepository)`, keeping the other 6 cascade-dep mocks (notifications/batch/history/device/messaging/collaborative-recipe) since they weren't flagged in the smell. Real `validateOwnership` resolves currentUserId from `mockAuthRepository.setAuthState(user: mockUser)` and passes (caller owns resource); real `collection.doc(uid).delete()` fires against FakeFirebaseFirestore so `userDoc.exists == false` assertions now observe genuine repo behaviour instead of side-effect-replicating mock stubs. Removed the two `then(...)` stubs that did `firestore.collection('public_profiles'/'users').doc(uid).delete()` inside the mock body. Added a load-bearing comment explaining why the smell was a smell. Removed the now-unused `UserRepository` interface import. 9/9 tests still pass (2 pre-existing skips for FieldValue/collectionGroup limitations of FakeFirebaseFirestore — unchanged). (BUT-733)

### Agent B: flutter-developer + uiux-designer — design-system migration sweep

- [!] **B1. Migrate direct `AppColors.*` references to `ColorScheme` / `ButleryColors` tokens** — **DEFERRED to its own sprint per CLAUDE.md rule #10 (Honesty over completion).** Recon revealed 182 call sites across 23 files (top: `calendar_weekly_menu_widget.dart`=40, `ping_compose_sheet.dart`=20, `substitution_bottom_sheet.dart`=15) — Linear ticket itself estimates "2-3 days sweep," bigger than the rest of this sprint combined. Each site needs judgement (~80 `AppColors` constants map to only ~25 standard `ColorScheme` slots; rest need `ButleryColors` extension or stay as decorative literals). Filed comprehensive migration guide on BUT-572 with full mapping table (every `AppColors.X` → its replacement), watch-outs (`const` constructors, golden tests, sweep order), and suggested split into 4 wave-sprints. BUT-572 returned to Todo so it can be picked up clean next sprint with the mapping table as a head-start. (BUT-572)
- [x] **B2. Migrate 28 `EdgeInsets.only(left/right)` + `TextAlign`/`Alignment` to Directional** — Recon found 12 `EdgeInsets.only(left/right)` sites + 3 `Alignment.centerLeft/Right` + 2 `TextAlign.left/right` = 17 actual (vs 33 in ticket — earlier sweeps already cleared the rest). Migrated all 17 to `EdgeInsetsDirectional.only(start/end)`, `AlignmentDirectional.centerStart/centerEnd`, `TextAlign.start/end`. Cleanup in `app_dimensions.dart`: replaced legacy `paddingOnlyLeft8` constant with `paddingOnlyStart8` (1 call site updated in `personal_tag_rule_dialog.dart`); deleted three dead constants (`paddingOnlyLeft16`, `paddingOnlyRight8`, `paddingOnlyRight16`) — zero usages, confirmed via grep. Files touched: `cooking_mode_view.dart`, `ingredient_search_view.dart`, `skriv_sjalv_recept_view.dart` (3 sites), `calendar_weekly_menu_widget.dart`, `dynamic_list_builder.dart`, `recipe_shelf.dart`, `pantry_item_card.dart`, `recipe_detail_shared_widgets.dart`, `collaborative_shopping_items.dart`, `main.dart`, `recipe_detail_content.dart`, `app_dimensions.dart`, `personal_tag_rule_dialog.dart`. Final grep for `EdgeInsets.only([left|right]:`, `Alignment.center{Left,Right}`, `TextAlign.{left,right}` returns zero matches in `lib/`. Custom-lint rule for regression deferred (analyzer-plugin scaffold is its own deliverable). All touched files analyze clean. (BUT-565)
- [x] **B3. Native-English spot-check of `app_en.arb`** — Sampled across the 6 categories called out (auth, onboarding, recipe detail, errors, settings, social CTAs). Most strings already read clean. Fixed 16 with concrete issues: (1) `errorNotFound: "Could not be found."` → `"Not found."` (orphan-subject ungrammatical); (2) `socialEditingTogether: "You are editing together with others"` → `"You're editing with others"` (redundant "together" + missing contraction); (3) `socialChangesSyncAutomatically: "Changes sync automatically with other participants"` → `"Changes sync with everyone automatically"` (wordy); (4-16) the chat / messaging / draft "Could not X" cluster → `"Couldn't X"` for friendlier UI tone (Material guidance: contractions in casual UI; Swedish has no contraction equivalent so machine-translation defaults to formal). `messagingCouldNotShowProfile` also tweaked "show" → "open" (more idiomatic English UI verb). Categories not exhaustively reviewed: tag/menu/shopping/import/parsing — minor remaining work documented in BUT-713 follow-up comment. `dart analyze` clean; `l10n.yaml` template is `app_sv.arb` so English-side edits don't require codegen, only runtime pickup. (BUT-713)

### Standalone

- [x] **C1. Create `PROMPT_CHANGELOG.md` for prompt-version traceability** — Created at `functions/src/llm/PROMPT_CHANGELOG.md`. Documents the format (4-section template per entry: What changed / Why / Expected impact / Linked metrics-tickets), the versioning rule (PATCH/MINOR/MAJOR semantics for prompt edits), the rationale (3 downstream consumers: quality measurement, A/B testing per BUT-626, Remote Config rollouts per BUT-621), and the append-only discipline. Logged the current `v2.0.0` entry — based on the existing `PROMPT_VERSION = "2.0.0"` constant in `gemini-client.ts:25` (the canonical source after BUT-621 promptVersion threading shipped in commit `4f0c65af0`). Backfilled three pre-changelog historical entries from git log (`001c2f5e1` BERT NER move, `00635cf84` line-level routing, `f38edf76a` initial smart import) — explicitly marked as narrative-only, not for metric attribution. Added "Adding a new entry" checklist + cross-links to all four prompt source files. CI lint flagged as planned-not-yet-active; a future task can wire `PROMPT_VERSION` bump → changelog presence as a PR check. (BUT-669)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] Affected unit tests green (consent + fcm + account-deletion + theme-touched widgets)
- [ ] Tier-2 specialist gates: code-reviewer (any `*.dart`), testing-specialist (any `lib/**/*.dart`), firebase-backend-security (FCM/account changes)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-573/434/733/572/565/713/669 → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint, not a sweep slot
- BUT-753 — admin-cascade Cloud Function, deferred per prior sprint's note
- All `idea`-labeled monetization scaffolding — post-beta per memory

---

## What this means in plain language

- **Push notification permission gets honored properly.** Right now the app may register a notification token even before you've granted notification permission — this fixes that, matching the consent gate work that just landed for analytics.
- **One risky third-party package gets swapped out.** The library that handles "share to Butlery" from another app is from an unverified publisher with a single maintainer — replacing it with a more trustworthy alternative.
- **Some test cleanup.** Account-deletion tests have tangled mocks that need a stub to replicate side-effects; swapping in the real repo against the fake database makes them honest integration tests.
- **Design-system polish.** Hardcoded color references swapped for theme tokens (so future theme tweaks Just Work and dark mode looks consistent), and 28 layout properties switched to a version that flips correctly for right-to-left languages (Arabic, Hebrew — future-proofing).
- **English copy proofread.** A native-speaker pass over the most-visible English translations.
- **One doc file.** A changelog for AI prompt versions so we can trace which prompt produced which result.
- **Risk: low.** No UI structure changes, no external service contract changes, no data-model changes. Each ticket is independently revertable.

---

## ARCHIVED — Sprint: Consent-gate dedup + privacy/test sweep — 2026-05-02

Shipped as `efac8c5bd` ("feat(consent/privacy): multi-listener consent gate + opaque-URL scrub + GDPR engagement erasure (BUT-751/752/692/732/598/695/602)"). All 7 implementation tickets shipped. BUT-602 closed as no-op (already-resolved). BUT-695 alternative chosen (header comment instead of 39-file rename). Surfaced one follow-up: BUT-753 (admin-cascade legacy `sharedWith` cleanup Cloud Function).

## ARCHIVED — Sprint: Security spot-fix + privacy paperwork + tech-debt sweep — 2026-05-02

Shipped as `f4237f23b`. 5 implementation tickets shipped; BUT-591/601 closed as no-ops. Plus BUT-750 shipped as `64c8f236f`.

## ARCHIVED — Sprint: Retention measurement loop + import HEIC fix — 2026-05-01

Shipped as `d803ea1f2` plus `9d259b06c` (CI unblock) and `815df8e43` (DateTime baseline). All 5 tasks complete.

## ARCHIVED — Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Shipped as `e52a1ebb4`. All 8 tasks complete.
