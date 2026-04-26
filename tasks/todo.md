# Sprint Backlog

## Sprint: A11y chunk-1 + observability + perf + paperwork — 2026-04-26 (Late evening)

Theme: anchor the next coherent pre-launch cluster — the one Urgent (BUT-697 a11y broad sweep, chunk-1 of N), one observability gap (BUT-449 web error tracking with PII scrubbing), two cheap perf wins (BUT-470 imageCache, BUT-429 PNG→WebP), kill-switch hardening (BUT-439 verify+document+test), one backend hygiene fix (BUT-477 presence TTL + GDPR cascade), two paperwork close-outs (BUT-720 COPPA, BUT-646 Data Safety filing). 4 agents, 7 tasks, isolated file trees.

Plan file: `C:\Users\malla\.claude\plans\i-want-you-to-curried-ladybug.md`

### Agent A: flutter-developer — a11y broad sweep chunk-1 (Urgent)

- [x] **A1. A11y Semantics sweep — image widgets + comment system + menu-content + recipe-card chunk** — done. 10 of 14 widget files modified (image/avatar, image_gallery, image_picker, components/edit_actions_panel, components/empty_image_state, components/upload_progress_widgets, recipe/comment_item, recipe/comment_item_widgets, recipe/recipe_card, menu/menu_content_widgets) plus 4 new `*_semantics_a11y_test.dart` files + `recipe_card_test.dart` updated. l10n keys added to `lib/l10n/app_sv.arb` + `app_en.arb` (regenerated `app_localizations*.dart`). 4 files from the original list (simple_image_widget, recipe_image_widget, components/image_grid_widgets, editable_image_widget) deferred to chunk-2 — they were either already covered by other-file Semantics wrappers or determined non-tappable. Tests pass, dart analyze clean. Chunk-2 file list to follow in BUT-697 Linear comment. WCAG 4.1.2. (BUT-697 — partial chunk-1, stays In Progress)

### Agent B: flutter-developer — perf bundle (cheap pre-launch wins)

- [x] **B1. Bump `PaintingBinding.imageCache.maximumSize` 100 → 300** — done. `lib/main.dart:142`. (BUT-470)
- [x] **B2. Convert PNG illustrations to WebP** — done. 12 illustrations converted (Pillow q=85, `cwebp` unavailable on Windows). **10.4 MB saved** (94% reduction; 11.0 MB → 663 KB). `arta/artskida{0..5}.PNG` animation frames intentionally left as PNG (q=85 artifacts compound across rapid frame cycling). pubspec.yaml unchanged (directory-level asset declaration). Dart references updated in `vegetable_illustration.dart` + `auth_view.dart`. `flutter analyze` clean. Manual visual smoke pending (`flutter run -d chrome` → broccoli/empty-state illustrations) — bash harness can't drive interactive browser. (BUT-429)

### Agent C: firebase-backend-security — observability + LLM kill-switch hardening

- [x] **C1. Web error tracking — Crashlytics-for-web or Sentry** — done. **Pivoted from Crashlytics-for-web** because `firebase_crashlytics` 5.x has no web SDK (verified: pub cache only ships android/ios/macos folders). Built callable-based pipeline instead: `lib/services/monitoring/web_error_reporter.dart` installs `FlutterError.onError` + `PlatformDispatcher.onError` web-only, gates on `ConsentPurpose.analytics` (matches native flow), scrubs PII via `lib/services/llm/pii_scrubber.dart` on every text field, dispatches via new `logWebError` callable in `europe-west1`. Server-side `functions/src/events/log-web-error.ts` AppCheck-enforced + rate-limited (20 tokens/5min refill) + double-scrubs PII server-side + drops on >50% redaction. 11 client tests + 10 server tests, all green. (BUT-449)
- [x] **C2. Verify LLM kill-switch coverage + write runbook + e2e test** — done. **Decision (option a — layered):** kept `aiEnabled` as master + added `llmParserEnabled` as per-feature granular kill (regressed parser shouldn't take down OCR vision). `llmMaxDailyInvocationsPerUser` already exists via existing token bucket in `functions/src/middleware/rate_limiter.ts` — out of scope for this sprint, captured as follow-up note in runbook. Audit: every Vertex-calling function in `functions/src/llm/` correctly gates at entry (structure-recipe ✓, ocr-recipe-image ✓ master + per-feature inherited via OCR retry, ocr-retry ✓ delegates to gated function, gemini-client ✓ utility wrapper). New `docs/ops/llm-kill-switch-runbook.md` covers Console URL + gcloud + server-callable TS commands for both flips, fail-open trade-off explained explicitly, audit table, monitoring filters, decision log. e2e test `functions/src/__tests__/llm-kill-switch.test.ts` 6/6 green. (BUT-439)

### Agent D: firebase-backend-security — backend hygiene + paperwork close-out

- [x] **D1. Audit presence listeners for server-side TTL cleanup + GDPR cascade** — done. **Verified backends:** `recipePresence` + `shoppingPresence` are **Firestore** (subcollection `activeUsers`); `cooking_sessions` is **RTDB** with `onDisconnect().remove()` already self-clearing (no work needed). **Approach taken:** per-doc `expiresAt: Timestamp` field on every Firestore write (60s TTL window, 30s heartbeat refresh = 2x within window). `markUserInactive` sets `expiresAt = now` for immediate eviction. Client read paths filter `expiresAt < now` in-memory. **Server-side TTL** documented in new `docs/ops/presence-ttl-runbook.md` — one-time `gcloud firestore fields ttls update expiresAt --collection-group=activeUsers --enable-ttl` to activate. **GDPR cascade:** added `cleanupPresenceRows()` to `functions/src/cleanup/on-user-deleted.ts` — `collectionGroup('activeUsers').where('userId', '==', uid)` sweep + batch delete (covers both presence collections in one query). Was NOT in the cascade before. New collection-group index on `activeUsers.userId` added to `firestore.indexes.json`. **Tests:** `test/unit/repositories/firebase_presence_ttl_test.dart` (8 tests: expiresAt write, heartbeat refresh, immediate eviction on inactive, stale-row filter, legacy-row passthrough — both repositories) + `functions/src/__tests__/presence-cascade.test.ts` (11 tests: target-only purge, empty-result skip, 500-op batch chunking). All green. (BUT-477)
- [x] **D2. COPPA flag — confirm app is not directed at children under 13** — done. New "## COPPA target audience" section appended to `docs/ops/age-rating-runbook.md` with the 5-point evidence pack (13+ age gate at `OnboardingAgeGatePage` + Firestore-rules layer, no child-friendly UI motifs, adult-targeted marketing copy, no child-targeted features, adult-to-adult UGC scope). Pre-filled Play Console workflow ("Target audience and content" → 13+ age groups, "Does your app unintentionally appeal to children?" = No, do not opt into Designed for Families) + Apple App Store Connect workflow ("Made for Kids" = NO). Cross-referenced BUT-590 + BUT-624 already-completed age-rating prep. (BUT-720)
- [~] **D3. File Google Play Data Safety form using BUT-561 runbook** — **PREP COMPLETE; AWAITING USER FILING.** Agents cannot reach Play Console. Created `docs/store-submission/play-data-safety/README.md` (filing workflow + screenshot naming convention + Play Console URL + runbook cross-reference) + `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` (top-level tracker mapping every store-submission item to its runbook + filing destination + state). Appended "## 10. Filing status" section to `docs/ops/play-data-safety-runbook.md` — currently "Pending user action — form to be filed via Play Console using the answers below; screenshot to be saved at `docs/store-submission/play-data-safety/2026-04-26-submitted.png`". User flips this status to "Submitted YYYY-MM-DD" after filing. (BUT-646 — Linear stays In Progress until user files)

### Post-Sprint Steps

- [x] Close prior-sprint Linear: BUT-467 → Done (privacy policy v1.2.0 already references Vertex AI; nothing to change).
- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `flutter test` — 64 sprint tests green (a11y + presence + web error reporter)
- [x] `cd functions && npm test` — kill-switch (6) + log-web-error (10) + presence-cascade (11) + all pre-existing suites green
- [~] Visual: `flutter run -d chrome` after Agent B WebP conversion — bash harness can't drive interactive browser; manual pass needed before high-confidence merge (broccoli on auth_view, empty-recipe state)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-449, BUT-470, BUT-429, BUT-439, BUT-477, BUT-720 → Done; BUT-697 stays In Progress (chunk-1 of N, comment with chunk-2 file list); BUT-646 stays In Progress (awaiting user filing)

### Continued blockers (NOT in this sprint scope)

- **BUT-426** freeRASP teamId — blocked on Talsec dashboard creds.
- **BUT-450** GCP alerting — blocked on user gcloud + notification channel.
- **BUT-714** iOS Universal Links credential substitution — blocked on Apple Team ID + production keystore SHA-256.
- **BUT-415** privacy policy hosting + screenshot capture — defer to domain-setup spike + screenshot-capture session.

---

## What this means in plain language

- **The most pressing accessibility problem gets a real first chunk fixed.** Today users with screen readers hit unlabeled buttons across image galleries, comment threads, and menu cards. After this sprint, those become labeled. The remaining 48 widget files queue for follow-up sprints.
- **The web build stops being a black hole for crashes.** Today if anything breaks in the browser version, you don't find out — only iOS and Android report crashes. After this, Crashlytics catches web errors too, with PII scrubbed.
- **The app gets ~10MB smaller on Android.** Pure asset compression — no visible change, just smaller download.
- **Image grids stop stuttering on iPad and desktop.** One number bumped in startup code.
- **The AI emergency brake gets a runbook + a real test.** Today the kill switch exists but nobody has documented how to actually use it in an incident. After this, there's a one-page runbook + an automated test proving the brake works.
- **Two store-submission paperwork items get closed.** Pure form-filling using runbooks already written.
- **Background data junk stops accumulating, and presence records become deletable.** Auto-cleanup runs daily; account-deletion now reaches presence paths if it didn't already.
- **Risk: low to medium.** A1 is the largest task (14 files of careful refactor + tests). B2 (PNG→WebP) is mechanically risky if asset names get desynced — triple-gated verification is the catch. Everything else is small and bounded. Each task independently revertible.

---

## Archive: Mediums close-out + admin-delete parity — 2026-04-26 (PM)

Theme: clean up the 4 deferred Mediums from the morning's sprint (BUT-521 / BUT-511 / BUT-517 follow-ups) plus the BUT-728 admin-delete parity work surfaced as a side-finding from BUT-511. All 5 tasks are bounded, all reuse patterns established earlier today, no new UX surface beyond Cmd+Enter starting to actually save forms.

### Agent A: flutter-developer — keyboard layer mediums (BUT-521 follow-ups)

- [x] **A1. Cmd+Enter actually submits forms** — today `SubmitFormIntent` calls `Form.validate() + Form.save()` but no form in the codebase uses `Form.save()` (saves go through ViewModel methods triggered by explicit Save buttons). New widget `lib/core/keyboard/keyboard_submittable_form.dart` registers an `Actions<SubmitFormIntent>` override at the form root with a caller-supplied `onSubmit` callback. Migrate 3 high-traffic forms: `lib/views/edit_recipe_view.dart`, `lib/views/skriv_sjalv_recept_view.dart`, `lib/views/social/user_profile_edit_view.dart`. Update `app_actions.dart` docstring + `app_shortcuts.dart` `SubmitFormIntent` doc to reflect override pattern. Test: pump form wrapped in `KeyboardSubmittableForm`, send Cmd+Enter, assert `onSubmit` fired. (BUT-521 follow-up)
- [x] **A2. Cmd+K route dedupe** — register `RouteObserver<ModalRoute<dynamic>>` in `lib/main.dart` and pass to `MaterialApp.navigatorObservers`. New `lib/core/keyboard/route_tracker.dart` exposes `currentRouteName` getter. In `app_actions.dart:_pushSearch`, no-op when current route name is the search route. Test: pump app with shortcuts, push search route once, send Cmd+K again, assert navigator stack length unchanged. (BUT-521 follow-up)

### Agent B: flutter-developer — DialogFormFields hardening (BUT-517 follow-up)

- [x] **B1. DialogFormFields contentFilter no longer bypassable** — `lib/widgets/common/dialogs/dialog_form_fields.dart:66-78`: today `customValidator ?? combine([...])` silently drops the contentFilter gate when caller provides a customValidator. Fix: always compose `combine([if (customValidator != null) customValidator, ...defaults, FormValidators.contentFilter(labelText)])`. Test: provide a customValidator that returns `null` for input containing profanity; assert the field validator returns the rejection reason. (BUT-517 follow-up)

### Agent C: firebase-backend-security — admin-delete parity rules (BUT-728)

- [x] **C1. Admin-delete parity rules + cook_snaps full block + resolver gaps closed** — scope expanded after gap analysis: `_resolveContentRef` was missing `'profile'` and `'shopping_list'` cases (added — point at `public_profiles/{contentOwnerId}` and `unified_shared_shopping_lists/{contentId}` respectively). Admin-delete overrides added to existing `public_profiles` (line 459) and `unified_shared_shopping_lists` (line 1041) rule blocks. Net new `cook_snaps` rule block (lines 1166-1209) — owner CRUD + auth read + admin moderation, with userId-pin on update to block impersonation. The cook_snaps block also fixes a pre-existing P0: `firebase_cook_snap_repository.dart` writes directly to a default-denied collection; without this rule block client-side cook-snap creation was failing in production. (BUT-728 + side-effect fix)

### Agent D: firestore-rules-tester — rules test coverage (BUT-511 + BUT-728 follow-up)

Runs after Agent C lands the new rules.

- [x] **D1. Test coverage for friend_categories + admin-delete paths + cook_snaps CRUD** — new `functions/src/__tests__/moderation-rules.test.ts` (4 suites, 21 tests). Covers admin moderation + owner regression + non-admin deny for each of `friend_categories`, `public_profiles`, `unified_shared_shopping_lists`, plus full new-block coverage for `cook_snaps`. Local Java unavailable; CI workflow `.github/workflows/firestore-rules.yml` is the verification path (added file to its path filter + `test:rules:moderation` script). (BUT-511 + BUT-728 follow-ups)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos`
- [x] `flutter test` — new + existing
- [x] `cd functions && npm test` — firestore-rules suite
- [x] `/simplify` pass
- [x] Commit, push to main — `5898d6485`
- [x] Update Linear: BUT-728 → Done

---

## What this means in plain language

- **Cmd+Enter now actually saves** the recipe / profile / group you're editing. Today it pretends to.
- **Cmd+K stops opening duplicate search screens** — repeated Cmd+K is a no-op when search is already up.
- **The dialog-form helper can no longer accidentally lose its profanity filter** when a developer adds a custom validator.
- **The new moderation rule for groups gets a test** that proves it works.
- **Admins can now actually take down reported profiles, cook-snaps, and shopping lists** — today they can mark the report as resolved but the offending content stays up. Same Apple 1.2 / Play UGC concern that drove the Groups Report wiring earlier.
- **Risk: very low.** Five small targeted edits. M3+M5 are test + rules-only (zero production app code). M4 is one method. M1 is additive. M2 adds one observer + one if-check.

---

## Archive: A11y P2 close-out + social safety completion — 2026-04-26

Theme: pre-launch hardening backlog is drained; no Urgent items remain. The next coherent cluster is the High-priority accessibility ring (5 P2 items, EN 301 549 / WCAG 2.1 AA — required for EU app distribution) plus the two remaining social-safety P2 gaps Apple 1.2 / Play Console care about. No new features, no UX surface change beyond an existing Report tile reused from the BUT-417 sprint.

### Agent A: flutter-developer — A11y P2 cluster

- [x] **A1. textLight contrast on cream surfaces** — `lib/theme/app_colors.dart`: `textLight` is `#767676`, fails 4.5:1 against cream backgrounds. Audit cream-surface call sites; either darken `textLight` or substitute a cream-safe token. WCAG 1.4.3 Level AA. (BUT-514)
- [x] **A2. Semantics coverage on styled_input + custom form fields** — `lib/widgets/styled/styled_input.dart` + `lib/widgets/common/dialogs/dialog_form_fields.dart` (20 hintText/labelText sites): confirm each field renders a native `TextField` with `decoration.labelText` (auto-Semantics) OR wrap custom-drawn variants with explicit `Semantics(textField: true, label, hint, value)`. Widget test asserting `find.bySemanticsLabel`. WCAG 4.1.2. (BUT-539)
- [x] **A3. Custom focus indicator ring** — `lib/theme/`: Material 3 default focus ring is invisible on cream. Add `FocusTheme` (or per-widget `Focus(canRequestFocus, ..)` decoration) using rust accent for visibility. WCAG 2.4.7. (BUT-533)
- [x] **A4. Respect MediaQuery.disableAnimations** — sweep `AnimationController` / `AnimatedX` widgets; gate non-essential animations behind `MediaQuery.disableAnimationsOf(context)`. Vestibular accessibility. WCAG 2.3.3. (BUT-527)
- [x] **A5. Keyboard navigation layer (Shortcuts/Actions) for web/desktop** — `lib/main.dart` app shell wraps the navigator subtree in `Shortcuts` + `Actions` + `Focus(autofocus: true)`. New `lib/core/keyboard/{app_shortcuts,app_actions}.dart` declare 7 intents (CloseDialog/NavigateBack/OpenSearch/GoToRecipes/GoToMenu/GoToShopping/SubmitForm) bound to Esc / Backspace / Cmd-or-Ctrl+(K, 1, 2, 3, Enter). Tab switching bridged via top-level `mainTabSwitchRequest` ValueNotifier listened to in `_MainMenuLayoutState`. All 7 bindings end-to-end (no stubs). WCAG 2.1.1. (BUT-521)

### Agent B: firebase-backend-security — social safety completion

- [x] **B1. Wire ReportContentDialog to groups (name + description + members)** — `lib/views/social/group_detail/group_detail_app_bar.dart` (overflow menu) + `lib/views/social/group_detail/group_detail_actions.dart` (member action sheet): call `ReportContentDialog.show` with existing `ContentType.group` (or add one). Reuses BUT-417 dialog. (BUT-511)
- [x] **B2. Expand ContentFilterService coverage** — `lib/services/moderation/content_filter_service.dart` (current call sites: `chat_viewmodel.dart:92`, `social_comments_manager.dart:57`): add `BaseService`-level `ensureClean(text, field)` helper, wire into recipe create/edit, group create/edit, profile update, cook-snap caption input. Block submit at validator level. (BUT-517)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] Targeted unit + widget tests per agent
- [ ] Commit, push to main
- [ ] Update Linear: BUT-514, 539, 533, 527, 521, 511, 517 → Done

---

## What this means in plain language

- **Five small accessibility fixes** the EU expects every app shipping in 2025+ to have. Right now if a user taps Tab on a keyboard, navigates with a screen reader, or has motion-sickness settings on, parts of Butlery feel broken. After this sprint, those parts work.
- **Two social-safety surfaces get the Report button you already have elsewhere.** Today you can report a comment but you can't report a group name or a recipe title. Apple/Google care about this for store review.
- **Risk: low.** Four of the five a11y tasks are theme-token edits (one color, one focus ring, one animation guard, one Semantics wrapper). The keyboard navigation task (A5) is bigger; if it grows, we split it out. Social-safety tasks reuse components that already shipped.
- **What you'll notice:** focus rings appear when navigating with keyboard, Settings → "Reduce motion" actually reduces motion, the cream-background text is slightly darker, and a "Report" tile appears on group menus.

---

## Archive: Final store-submission close-out — age rating + iOS PrivacyInfo + reviewer paths — 2026-04-26

Theme: Five sprints of pre-launch hardening have drained the security/privacy/observability backlog. The only cluster left between `main` and a real App Store / Play Console submission is **age rating + iOS PrivacyInfo completion + App Review demo path**. Pure paperwork + small file edits, no UX changes.

### Agent A: firebase-backend-security — submission paperwork

- [x] **A1. App Store / Play Console age rating answers** — new `docs/ops/age-rating-runbook.md`: enumerate UGC + messaging + photo features, decide 12+/Teen vs 17+/Mature, pre-fill answer set per console field. Cross-reference `docs/ops/play-data-safety-runbook.md` so the two don't contradict. Hard submission block. (BUT-624)
- [x] **A2. IARC + Apple age-rating questionnaire prep** — append to `docs/ops/age-rating-runbook.md`: copy-paste-ready answers per IARC question (violence, sexual content, simulated gambling, UGC, location sharing, digital purchases, drug references) + Apple equivalents. (BUT-590)
- [x] **A3. Reviewer demo account + reviewer notes** — new `docs/ops/app-review-demo.md`: seeded demo user (email + password), pre-populated household with 2 friends, sample shared menu, sample comments, sample report. Reviewers can't sign up + verify within review SLA — Apple/Google will reject if social features look untestable. (BUT-416)

### Agent B: firebase-backend-security — iOS PrivacyInfo close-out

- [x] **B1. PrivacyInfo: required-reason API entries** — `ios/Runner/PrivacyInfo.xcprivacy`: add FileTimestamp (C617.1, already partial), DiskSpace (E174.1), SystemBootTime (35F9.1). Cross-check current declared entries to avoid duplicates. (BUT-587)
- [x] **B2. Third-party pod PrivacyInfo manifest audit** — new `docs/ops/ios-third-party-privacy-manifests.md`: enumerate Firebase pods, image_picker, shared_preferences, freerasp, others; verify each ships its own `PrivacyInfo.xcprivacy`; flag any missing for upstream issue. App-level manifest doesn't cover transitive dependencies. (BUT-596)
- [x] **B3. PrivacyInfo: NSPrivacyCollectedDataTypeUserID** — `ios/Runner/PrivacyInfo.xcprivacy`: add Firebase UID as collected + linked data type with purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`. App Store rejects without this declared. (BUT-603)

### Agent C: flutter-developer — pre-login reachability + Android + asset audit

- [x] **C1. Pre-login privacy policy + ToS reachability** — `lib/views/auth/auth_view.dart`: verify both legal links render AND navigate before user is authenticated; add widget test asserting tap navigates without auth state. Apple 5.1.1 + GDPR Art 13 require both reachable pre-signup. (BUT-563)
- [x] **C2. Verify compileSdk / targetSdk 35** — `android/app/build.gradle`: confirm `compileSdk 35` + `targetSdk 35` (Play 2026 mandate); update if not. Run `flutter build apk --debug` to confirm clean build. (BUT-541)
- [x] **C3. iOS app icon size audit** — `ios/Runner/Assets.xcassets/AppIcon.appiconset/`: enumerate required sizes (20/29/40/60/76/83.5/1024 pt at 1x/2x/3x), flag any missing. Apple submission rejects on missing 1024×1024 marketing icon. Output: PASS or list of gaps. (BUT-583)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `flutter test` — green (4/4 auth_view_legal_links_test passing)
- [~] `flutter build apk --debug` — skipped (compileSdk=36/targetSdk=36 already verified above 35; no gradle changes)
- [x] Commit, push to main — `cafe75107`
- [x] Update Linear: BUT-624, BUT-590, BUT-416, BUT-587, BUT-596, BUT-603, BUT-563, BUT-541, BUT-583 → Done

### Continued blockers from prior sprints (NOT in this sprint scope)

- **BUT-426** freeRASP teamId — blocked on real Talsec teamId from freeRASP dashboard + cert hash via `keytool -list -v -keystore android/app/upload-keystore.jks -alias upload`.
- **BUT-450** GCP alerting — blocked on user installing gcloud, running `gcloud auth login`, creating email notification channel per `docs/ops/gcp-alerting-runbook.md`, exporting `GCP_NOTIFICATION_CHANNEL_ID`, running script.
- **BUT-635** iOS deployment target 17.0 — left as-is per user direction (commits `b320e0773` + `3c07522ed` already shipped the fix; Linear state cleanup deferred).

---

## What this means in plain language

- **The app gets one step closer to actually being submittable.** After this sprint, every form question App Store and Play Console will ask you has a pre-written answer — copy, paste, click submit.
- **The reviewer who tests your app for Apple/Google can actually try the social features.** Right now they'd hit a sign-up wall and never see friends/menus/comments. After this, there's a demo account + cheat-sheet they follow.
- **Apple's privacy nitpicks get closed.** Three small files in the iOS bundle declare exactly which iPhone APIs you use and why. Three of those declarations are missing today; this adds them.
- **The "you must use Android 35" deadline gets verified.** Google's January 2026 deadline says all new apps target Android 15 (API 35). One file check + maybe a one-line change.
- **Your icon files stop being a submission risk.** If even one icon size is missing, Apple rejects. This sprint either confirms all 14 sizes exist or lists the gaps.
- **Pre-login legal links get a regression test.** Today they work — but no test guarantees they keep working. After this, a CI test breaks if they ever stop being reachable.
- **Risk: Very low.** No code logic changes. Most tasks are documentation files or one-line plist edits. Each task is independently revertible. Worst case: a markdown file says the wrong thing and you fix the typo.

---

## Archive: Pre-launch growth visibility — activation analytics + parse-quality loop + Play Store paperwork — 2026-04-25

Theme: launch is imminent. Make day-1 user behavior measurable (5 activation milestones + sharing instrumentation), close the parse-quality feedback loop so LLM cost doesn't scale linearly with usage, knock out the Google Play Data Safety paperwork (hard submission block), and harden two parsing-pipeline robustness gaps. Plus two carry-over close-outs from the 04-25 hardening sprint side-findings. Additive only, no user-visible UX changes.

### Agent A: flutter-developer — activation analytics (events + user properties)

- [x] **A1. Wire `logRecipeShared` call sites + `first_share` milestone** — `lib/widgets/social/friend_recipe_sharing_dialog.dart`, `lib/widgets/social/group_recipe_sharing_dialog.dart`, `lib/services/social/share_service.dart`: emit `recipe_shared` with `method: 'friend' | 'group' | 'system_share_sheet' | 'link_copy'`, hashed recipe_id (per BUT-421 rules), recipient_count bucket. On first successful share per user, emit `first_share` / `sharing_activated` with `{minutes_since_signup, share_method}` and set user property `sharing_activated=true` (dedupe via user-profile flag). (BUT-532, BUT-584)
- [x] **A2. `first_meal_plan` + `social_activated` milestones + `first_recipe_source` user prop** — `lib/viewmodels/menu_viewmodel.dart`: on first `menu_saved` (when `menuPlanCount == 0` pre-save), emit `first_meal_plan` with `{minutes_since_signup, recipe_count_in_plan}` and set `menu_activated=true`. Friend/comment/group activation: emit `first_friend` on `friend_request_accepted` (friendCount==0), `first_comment` on `comment_created` (commentCount==0), `first_group` on `group_created`/`group_joined` (groupCount==0); set user props `has_friend`/`has_commented`/`has_group`. In `lib/services/recipe/recipe_persistence_manager.dart:_logRecipeCreated` when `recipeCount==1`, set user property `first_recipe_source = 'import' | 'manual' | 'seed'` (dedupe). Dedupe pattern follows `user_activated` logic at `recipe_persistence_manager.dart:398`. (BUT-576, BUT-593, BUT-618)

### Agent B: flutter-developer + functions/TS — parse-quality + AI-cost telemetry

- [x] **B1. Instrument import per-tier (site_config/regex/llm) for AI cost optimization** — `lib/services/parsing/tiers/`: emit `import_tier_succeeded` / `import_tier_failed` to Firebase Analytics with `{tier, duration_ms, platform (hostname bucketed), session_id}`. Keep the existing Cloud Function `parse_event_logger.dart → logParseEvent` (different use case) but mirror tier outcome to Analytics. Answers "what % of imports required LLM fallback?" — the single most AI-cost-sensitive question. (BUT-552)
- [x] **B2. Close quality feedback loop — upload `RecipeDiffCalculator` corrections** — `lib/services/parsing/feedback/recipe_diff_calculator.dart` (currently 4 local-only call sites via `recipe_persistence_manager.dart`): pipe diffs through new `logParseCorrection` (or extend `ParseEventLogger`) with schema `{correctedField, fromValue, toValue, sourceTier, promptVersion, domain}`. Persist to aggregatable Firestore collection `parsing_corrections`. Apply `pii-scrubber.ts` server-side before write. (BUT-595)

### Agent C: firebase-backend-security — Play Store paperwork + prior-sprint close-outs

- [x] **C1. Prepare Google Play Data Safety form runbook** — new `docs/ops/play-data-safety-runbook.md`. Enumerate every data type collected: Firebase Auth (email, uid), Firestore (profile, recipes, shopping, groups, comments, ratings, pantry, presence, pings), Analytics (events, user properties), Crashlytics, Performance, FCM tokens, Algolia indexed content, Vertex AI (recipe text). For each: purpose, sharing (none / processor), encryption in transit, deletion request flow. Cross-check against `ios/Runner/PrivacyInfo.xcprivacy` so iOS and Android declarations match. Output: copy-paste-ready answers per Play Console field. (BUT-561) — HARD SUBMISSION BLOCK
- [x] **C2. Gitignore Android signing artefacts** — `.gitignore`: add `android/key.properties` and `android/app/*.jks`. (Side-finding from 04-25 sprint. Git log shows never committed yet, but the gap exists — one accidental `git add .` leaks the keystore password.)
- [x] **C3. Migrate remaining notification call sites to `preference-aware-push` helper** — done. `send-activity-digest.ts` now routes through `sendPushToUserRespectingPreferences` (master + quiet-hours gates on top of the existing `digestFrequency` check). `send-notification.ts` callable refactored: `dispatchNotification()` extracted with test seams, non-silent pushes go through the helper, silent pushes (background sync) intentionally bypass the gate. Tests added: 4 scenarios for activity-digest, 7 for the callable (sent / master-disabled / quiet-hours / opted-out / no-token / silent-bypass / unknown-category fallback). Constraint honored: `preference-aware-push.ts` unchanged. No third bypass path found — `Grep sendEachForMulticast` returned only the two target files plus the helper itself. (Side-finding from 04-25 sprint — same bug as BUT-438, just different push paths.)

### Agent D: firebase-backend-security — parsing pipeline robustness

- [x] **D1. Per-phase budget on tagging pipeline** — `lib/services/tagging/tagging_service.dart`: replace single 30s `_tagGenerationTimeout` wrapper with per-phase budgets (P1:2s, P2:5s, P3:10s, P4:5s, P5:8s) and accumulated partial results. On phase timeout, emit structured log with `{phase_index, elapsed_ms}` and continue to next phase using Phase-N-1 result instead of falling back to `generatePhase1Only`. Targeted test: simulate Phase-2 hang, assert Phases 3-5 still run with stale Phase-1 result. (BUT-553)
- [x] **D2. OCR rawText auto re-extraction** — done. `functions/src/llm/structure-recipe.ts` extracts a server-callable `runStructureRecipe()` core (callable wrapper unchanged). New `functions/src/llm/ocr-retry.ts` orchestrator with budget guard (`MIN_REMAINING_BUDGET_MS = 65_000` against the 120s parent timeout). `functions/src/llm/ocr-recipe-image.ts` refactored: callable delegates to `runOcrRecipeImage()` core with test seams; on image-parse failure with non-empty rawText we invoke `runStructureRecipe(rawText)` in-process and return the structured result with `retryCount: 1` + `retryOutcome: 'success'`. Response gains `retryCount: number` and `retryOutcome: 'success'|'failure'|'skipped_budget'|'skipped_no_text'|null` (existing fields preserved). Structured `console.info` log emits `{retryCount, retryOutcome, elapsed_ms_total, raw_text_length}` for observability. New `functions/src/__tests__/ocr-retry.test.ts` — 10/10 passing: 6 orchestrator-direct + 4 end-to-end (mandatory rawText recovery, happy path no-retry, structureRecipe throws, budget exceeded). `cd functions && npm test` green (44 total). (BUT-559)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `cd functions && npm test` — green
- [x] Targeted unit tests per agent — green
- [x] Commit, push to main — `f4c698b6d`
- [x] Update Linear: BUT-532, BUT-584, BUT-576, BUT-593, BUT-618, BUT-552, BUT-595, BUT-561, BUT-553, BUT-559 → Done

### Continued blockers from prior sprint (NOT in this sprint scope)

- **BUT-426 freeRASP teamId + cert hashes** — partial done (placeholder constants extracted with release-mode warning). Blocked on real Talsec teamId from freeRASP dashboard + SHA-256 cert hash via `keytool -list -v -keystore android/app/upload-keystore.jks -alias upload`.
- **BUT-450 GCP alerting** — partial done (script hardened to fail-loud, runbook written). Blocked on user installing gcloud, running `gcloud auth login`, creating email notification channel per `docs/ops/gcp-alerting-runbook.md`, exporting `GCP_NOTIFICATION_CHANNEL_ID`, running script.

---

## Archive: Pre-launch hardening — security defects + Firestore cost-perf + push-prefs bug — 2026-04-25

Theme: drain the highest-leverage P2 Bug/security cluster before submission. One big rock (BUT-448 Firestore rules CI gate) plus six surgical 2-hour fixes. Additive only, no user-visible features.

### Agent A: firebase-backend-security — security defects (analysis report 02, D1/D3)

- [x] **A1. SQLCipher key out of PRAGMA string** — done; `lib/core/storage/drift/app_database.dart`: replaced interpolated `PRAGMA key = '$encryptionKey'` with parameterized prepared statement (`db.prepare('PRAGMA key = ?')` + bound execute + dispose). Key never enters SQL text. (BUT-428)
- [!] **A2. Wire freeRASP with real teamId + cert hashes** — PARTIAL/BLOCKED on user creds. Done: extracted `_kPlaceholderTeamId` + `_kPlaceholderAndroidCertHash` constants with `TODO(BUT-426)`, added release-mode `AppLogger.error` warning if placeholder is still in use. **Blocked on:** real Talsec teamId from freeRASP dashboard + real SHA-256 cert hash via `keytool -list -v -keystore android/app/upload-keystore.jks -alias upload`. (BUT-426)

### Agent B: firebase-backend-security — server testing + observability

- [x] **B1. Firestore rules unit tests + CI gate** — done (CI-verified). New `functions/src/__tests__/firestore-rules.test.ts` — 15 tests covering `recipes`, `users`, `users/.../settings/preferences`, `users/.../pantry`. New `.github/workflows/firestore-rules.yml`. Local Java not on PATH; CI is the verification path. Follow-up collections tracked separately. (BUT-448)
- [!] **B2. Activate GCP alerting** — PARTIAL/BLOCKED on user gcloud + GCP creds. Done: hardened `setup-gcp-alerts.sh:15` to require `GCP_NOTIFICATION_CHANNEL_ID:?`; new `docs/ops/gcp-alerting-runbook.md`. (BUT-450)

### Agent C: flutter-developer — Firestore cost/perf (analysis report 04)

- [x] **C1. Audit `.limit(10000)` callers** — done. Method = `BaseFirebaseRepository.readAll()`. Two real call-sites; structurally bounded subclasses. (BUT-474)
- [x] **C2. Denormalize rating stream** — done; `firebase_ratings_repository.dart`: aggregate path swapped from `.limit(500).snapshots()` (~501 reads/update) to single-doc stream on `recipe_social_stats/{recipeId}` (1 read/update). (BUT-430)

### Agent D: firebase-backend-security — push prefs bug

- [x] **D1. Win-back push respects prefs + quiet hours** — done. New `functions/src/shared/preference-aware-push.ts`. `detect-lapsed-users.ts` routed through helper. 12/12 scenario tests pass. (BUT-438)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `cd functions && npm test` — 28/28 parity + 12/12 lapsed-users green
- [x] Targeted unit tests per agent — green
- [x] Commit, push to main — `1a29311f6`, `fe7c168fe`, `8d4a365c7`
- [x] Update Linear: BUT-428, BUT-448, BUT-474, BUT-430, BUT-438 → Done; BUT-426, BUT-450 stay In Progress

### Side findings (rolled into next sprint as C2 + C3)

- [→] **`android/key.properties` is NOT gitignored** — rolled to next sprint C2.
- [→] **Other notification call sites still bypass prefs/quiet-hours** — rolled to next sprint C3.

---

## Archive: Sprint Launch Readiness v3 — store blockers + PII + dep safety — 2026-04-24

Theme: close out the Urgent cluster (BUT-411 + BUT-447) and drain the highest-leverage P2 security/store blockers. Additive only, no user-visible features except the age gate.

### Agent A: flutter-developer — iOS store-submission blockers

- [x] **A1. Flip `ITSAppUsesNonExemptEncryption=false` in Info.plist** — done; `ios/Runner/Info.plist` flipped to `<false/>`. (BUT-411)
- [x] **A2. Add iOS build job to CI** — done; `build-validation.yml` matrix extended with iOS (macos-latest), stub `ios/exportOptions.plist` created. Unsigned build for PR gate. Signing follow-up when BUT-485 lands. (BUT-447)

### Agent B: firebase-backend-security — PII scrubbing hardening

- [x] **B1. Tighten PII-scrubber regexes** — done; `functions/src/llm/pii-scrubber.ts` rewritten. Personnummer requires hyphen/+ + word-boundaries; phone requires country-code prefix + unit-suffix negative-lookahead. 10/10 TS tests pass. (BUT-423)
- [x] **B2. Scrub PII client-side before LLM callable** — done; new `lib/services/llm/pii_scrubber.dart` (Dart port), wired into `llm_service.dart:_executeLlmCall` pre-`callable.call`. 14/14 Dart tests pass. Sync note in both files. (BUT-422)

### Agent C: firebase-backend-security — dependency + supply-chain safety

- [x] **C1. Commit `.github/dependabot.yml`** — done; pub + npm (/functions) + github-actions, weekly, grouped, ignores pub majors per BUT-562. (BUT-432)
- [x] **C2. Add `flutter pub audit` + `npm audit` CI gate** — done; `.github/workflows/dep-audit.yml` with OSV scanner (pub) + `npm audit --audit-level=high`. Weekly cron + PR triggers. Allowlist doc at `.github/dep-audit-allowlist.md`. (BUT-433)

### Agent D: firebase-backend-security — age gate (GDPR Art 8)

- [x] **D1. Age gate at sign-up** — done; `birthYear` field on `UserProfile` (stored in private `settings/preferences`, not public profile); Firestore rules enforce `[1900, 2013]` + required on preferences-create; new `OnboardingAgeGatePage` + `OnboardingAgeGateBlockedView`; 16 new tests (7 model + 3 widget + 6 rules). Bounded `2013` flagged for Jan rollover. (BUT-413)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — expect 0 issues
- [x] Targeted tests per agent (pii_scrubber_test false-positive fixtures; age-gate widget + Firestore rules tests)
- [x] Commit, push to main — `c9f72c336`
- [x] Update Linear: BUT-411, BUT-447, BUT-423, BUT-422, BUT-432, BUT-433, BUT-413 → Done
- [x] Follow-ups landed post-sprint: BUT-485 (`086113880`, `c9e2e6e9e`) + BUT-418 (`ea7372bd4`) + iOS CI chain BUT-632/634/635

---

## Archive: Sprint a11y completion + permission helper — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\plan-elegant-wilkes.md`

Theme: close out the /simplify-skipped follow-ups from sprint `ec5b8a43a`. Pure cleanup: finish BUT-505/BUT-508 migrations, extract OS-permission helper for future permission types.

### Agent A: flutter-developer — AppIconButton Semantics parity + 48dp migration

- [x] **A1. Add explicit `Semantics` wrapper to `AppIconButton`** — `lib/widgets/common/buttons/action_buttons.dart:473-481`.
- [x] **A2. Migrate raw `IconButton + Semantics + manual constraints` sites to `AppIconButton`** — `shopping_item_tiles.dart`, `shopping_list_header.dart`, `duplicate_merge_sheet.dart`, `feedback_fab.dart`.
- [x] **A3. Migrate custom `InkWell + SizedBox(minTouchTarget)` sites to `TappableWrapper`** — `cooking_mode_view.dart`.
- [x] **A4. Tests** — `app_icon_button_test.dart` + targeted 48dp-survival widget tests.

### Agent B: firebase-backend-security — extract OS-permission helper

- [x] **B1. Create `lib/core/utils/os_permission_helper.dart`** — static `requestWithRationale(...)`, inject `PermissionGateway`.
- [x] **B2. Refactor `NotificationPermissionService`** — delegate to helper, 243 → ~80 lines.
- [x] **B3. Do NOT migrate `ImagePickerService`** — different flow, out of scope.
- [x] **B4. Tests** — `os_permission_helper_test.dart` with 6 branches.

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] Relevant tests green
- [~] Manual TalkBack + Android 13+ notification flow — user-skipped; covered by unit/widget tests
- [ ] `/simplify` pass, commit, push
- [x] Linear: no ticket closures (pure cleanup on already-Done tickets)

---

## Archive: Sprint Store Submission Readiness — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\recursive-baking-petal.md`

Theme: launch-readiness High-priority store-submission blockers (Apple 1.2 UGC, GDPR Ch V, iOS privacy manifest, deep-link verification).

### Agent A: firebase-backend-security — UGC moderation (Apple 1.2 + Google Play)

- [x] **A1. Reports state machine + moderator admin rule + Cloud Function trigger** — `isAdmin()` helper + `admins/{uid}` write-lock + forward-only `reports.status` state machine. `ReportStatus` enum + safe-serialization. `ReportService` with admin stream + content-delete per type. Moderator review view/viewmodel. (BUT-417, BUT-548)
- [x] **A2. Appeal process ToS + Settings link** — ToS section 6.1 both locales. Settings hub mailto tile. (BUT-556)
- [x] **A3. Moderator runbook** — `docs/ops/moderation-runbook.md`. (BUT-417/BUT-548 close-out)

### Agent B: firebase-backend-security — EU data residency (GDPR Ch V)

- [x] **B1. Verify Firebase region + document** — `docs/ops/data-residency.md`. Cloud Functions + Vertex AI confirmed `europe-west1`. Firestore + Storage still need Firebase Console check by account holder. (BUT-607)
- [x] **B2. Migrate Gemini → Vertex AI europe-west1** — `@google/generative-ai` → `@google-cloud/vertexai`, ADC auth, GEMINI_API_KEY secret removed. Privacy policy v1.2.0 both locales reflects Vertex EU. (BUT-614)

### Agent C: flutter-developer — iOS submission + deep links

- [x] **C1. PrivacyInfo.xcprivacy audit** — declared File Timestamp (C617.1) + existing UserDefaults (CA92.1). `docs/ops/ios-privacy-manifest-audit.md`. (BUT-568)
- [x] **C2. Host `.well-known/assetlinks.json` + AASA on butlery.app** — `web/.well-known/` with placeholders. Also unblocks BUT-434. (BUT-575)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos`
- [~] Firestore rules unit tests — spec compiles, execution requires emulator
- [~] Manual verification — requires user: Firebase Console region, Xcode Archive, `curl -I https://butlery.app/.well-known/*`
- [x] Commit, push to main — `8cb29da13` + `49ef82341`
- [x] Linear: BUT-417, BUT-548, BUT-556, BUT-607, BUT-614, BUT-568, BUT-575 → Done
- [ ] Paperwork tracked separately: BUT-561 Data Safety form, BUT-624 age rating

---

## Archive: Sprint Launch readiness — GDPR + a11y + infra — 2026-04-21

Theme: burn down the Urgent launch-readiness cluster (GDPR Art 7, Firestore RPO, Android 13+ notifications, WCAG) + High-priority companions.

### Agent A: firebase-backend-security — consent-gated analytics

- [x] **A1. Gate `setAnalyticsCollectionEnabled` behind consent** — (BUT-412)
- [x] **A2. Consent-gate `FirebaseAnalyticsObserver`** — (BUT-570)
- [x] **A3. Strip PII from Analytics event params** — (BUT-421)

### Agent B: firebase-backend-security — infra + signing verifies

- [!] **B1. Enable Firestore PITR + weekly GCS export** — runbook in `docs/ops/backups.md`; blocked on user gcloud install. (BUT-418)
- [x] **B2. Verify `upload-keystore.jks` is gitignored** — CLEAN. (BUT-487)
- [!] **B3. Verify CI release signing** — TWO DEFECTS FOUND: keystore path mismatch + CI doesn't materialize `key.properties`. Requires user secret-admin. (BUT-485)

### Agent C: flutter-developer — Android 13+ notifications

- [x] **C1. Declare `POST_NOTIFICATIONS` permission** — (BUT-414)

### Agent D: flutter-developer — WCAG a11y

- [x] **D1. Semantics labels on icon-only buttons** — (BUT-508)
- [x] **D2. Enforce 48x48dp minimum touch targets** — (BUT-505)

### Cleanup

- [x] **Z1. Delete analysis report files** — 11 files
- [x] **Z2. Cancel BUT-543** — intentional empty-grid

---

## Archive: Sprint Family presence + pings + cooking step depth — 2026-04-20

Theme: surface the existing presence infra (RTDB `presence/{userId}`) into UI, add lightweight ping primitive (BUT-407), finish BUT-408's "steg N av M".

- [x] Agent A (flutter-developer): `FamilyPresenceBar` widget + header integration (BUT-407)
- [x] Agent B (firebase-backend-security): `Ping` model + `PingService` with rate-limit + GDPR cascade (BUT-407)
- [x] Agent C (flutter-developer): `ActivityPingsFeed` + `PingComposeSheet` (BUT-407)
- [x] Agent D (flutter-developer): `CookingSession.currentStep/totalSteps` + " · steg N av M" (BUT-408 follow-up)

---

## Archive: Sprint Cooking depth + presence + heirloom — 2026-04-19

Theme: three independent slices advancing *Smart Cooking Mode first*.

- [x] Agent A (flutter-developer): BUT-406 long-press timer — `DurationParser`, `StepTimerService`, `StepTimerWidget`
- [x] Agent B (flutter-developer): BUT-408 "Erik lagar just nu" presence — `CookingSession` model + RTDB repo + rules + `CookingSessionModule` + `CookingSessionCard`
- [x] Agent C (flutter-developer): BUT-410 heirloom OCR — `HeirloomMetadata` model + content-addressed Storage + `HeirloomStamp`

---

## Archive: Previous Sprints

- Cooking depth + Chrome MCP hooks (2026-04-18): BUT-202, BUT-215, BUT-403, BUT-347
- UX polish + menu model upgrade (2026-04-18): BUT-402, BUT-399, BUT-400, BUT-404, BUT-405, BUT-398, BUT-401
- Shared Menu Decisions (2026-04-18): BUT-340, BUT-238, BUT-361
- Test Infra Phase 12 — Cross-platform + Patrol MVP (2026-04-17): BUT-396, BUT-395
- Test Infra Close-Out (BUT-387 Phase 11, 2026-04-17): BUT-394, BUT-389, BUT-393
- Test Hardening Close-Out (BUT-387 final phase, 2026-04-17): BUT-390, BUT-391, BUT-392, BUT-388, BUT-385, BUT-374
- Ingredient Search (2026-04-14): BUT-205
- Stability & Permissions (2026-04-14): BUT-379, BUT-381, BUT-383, BUT-373, BUT-380, BUT-372, BUT-382
- Menu System Deepening (2026-04-13): BUT-360, BUT-370
- Veckomeny Constraint Parser (2026-04-11): BUT-359
- Calendar Weekly Menu Phase 1 (2026-04-11): BUT-211
- Skafferiet / Pantry (2026-04-10): BUT-349, BUT-205
- Social Activity Feed Phase 1 (2026-04-10): BUT-339
- Consent Hardening (2026-04-10): BUT-356, BUT-357
- Insights & Engagement (2026-04-10): BUT-338, BUT-350, BUT-223, BUT-354, BUT-214
- Social Polish & Tech Debt (2026-04-09): BUT-342, BUT-343, BUT-305, BUT-304, BUT-346, BUT-302
- Feature & Polish (2026-04-09): BUT-348, BUT-355, BUT-352, BUT-353
- Social & Stability Blitz (2026-04-08): BUT-345, BUT-341, BUT-314, BUT-323, BUT-337, BUT-324, BUT-300, BUT-301
- Tech Debt Consolidation (2026-04-08): BUT-303, BUT-306, BUT-299
- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
