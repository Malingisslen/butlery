# Sprint Backlog

## Sprint: Consent gate completion + UI/theme migration sweep — 2026-05-02

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
