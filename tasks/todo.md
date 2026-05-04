# Sprint Backlog

## Sprint: backend hygiene + auth security micro-hardening — 2026-05-04 (I)

Theme: 4 implementations + 2 ticket-state updates. Backend test-injectability (BUT-446), bootstrap cleanup (BUT-506), GDPR re-consent UI (BUT-465), CI artifact upload (BUT-490). Plus closing BUT-716 (premise gone) and re-scoping BUT-520 (premise stale at scope-level).

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-446** plan-stale (refactor approach) — `lib/services/notifications/fcm_service.dart` is an *all-static* class (line 75: no public constructor, all methods static). Constructor injection isn't possible without restructuring. Adapt: expose `@visibleForTesting` static setter `setMessagingForTest(FirebaseMessaging?)` + accessor `_getMessaging()` that defaults to `FirebaseMessaging.instance` when no override is set. All `_messaging.foo()` call-sites become `_getMessaging().foo()`. Tests can override via the setter with a mock; `tearDown` clears it.
- **BUT-506** plan-stale (line numbers shifted) — real call sites are `lib/main.dart:174` (settings), `:184` (web health-check), `:196` (terminate), `:197` (clearPersistence), `:198` (re-set settings post-clearPersistence). Ticket cited 152/162/174-176. Extract bootstrap into `lib/core/bootstrap/firestore_bootstrap.dart` with `FirestoreBootstrap.configure({FirebaseFirestore? firestore})` accepting an injected instance.
- **BUT-465** fits — `lib/services/account/consent_service.dart:152` confirms `needsConsentRenewal()` checks `_currentConsentVersion = '1.1.0'` against stored version. `lib/viewmodels/account/consent_viewmodel.dart:80` already exposes `_needsRenewal` flag. Existing UI surface: `lib/views/account/consent_management_view.dart`. Need post-auth dispatcher in `_ButleryAppState` that surfaces a blocking dialog when true.
- **BUT-716 PREMISE GONE** — `android/app/src/main/AndroidManifest.xml:22-23` already has `android:allowBackup="false"` and `android:fullBackupContent="false"`. Likely closed by an earlier security sprint without crossing the ticket. → close as Done with link to manifest commit/lines.
- **BUT-490** fits — `.github/workflows/build-validation.yml:174-180` builds AAB; `:201-205` builds web. Neither uploads. Add `actions/upload-artifact@v4` steps after each. iOS already builds without codesign and isn't shippable, so no upload there yet (BUT-447 territory).
- **BUT-520 PREMISE STALE AT SCOPE** — ticket claims "3 standalone holdouts". Reality: ~30 top-level VMs in `lib/viewmodels/` extend `ChangeNotifier` directly; only 16 use `BaseViewModel`. The migration is incomplete, not a 3-VM holdout. This is a multi-sprint architectural sweep, not a sprint slot. → update ticket body to reflect true scope, leave in Backlog. Don't implement here.

### Agent A: Backend test-injectability + bootstrap

Specialists: `firebase-backend-security` (FCM/Firestore touch), `code-reviewer` + `testing-specialist` (any .dart change).

- [ ] **A1. BUT-446 — FCMService test seam for FirebaseMessaging** —
  - `lib/services/notifications/fcm_service.dart`:
    - Replace `static final FirebaseMessaging _messaging = FirebaseMessaging.instance;` (line 80) with:
      ```dart
      static FirebaseMessaging? _messagingOverride;
      static FirebaseMessaging _getMessaging() =>
          _messagingOverride ?? FirebaseMessaging.instance;

      /// Test-only seam. Pass a mock FirebaseMessaging in tests; reset to
      /// null in tearDown to restore the real instance.
      @visibleForTesting
      static void setMessagingForTest(FirebaseMessaging? messaging) {
        _messagingOverride = messaging;
      }
      ```
    - Replace every `_messaging.` call-site (token operations, message handlers, permission requests) with `_getMessaging().`. Grep for `_messaging\.` first to find all sites.
    - Add `import 'package:flutter/foundation.dart' show visibleForTesting;` if not already present.
  - Tests: `test/unit/services/notifications/fcm_service_test.dart` — extend if exists, otherwise add a focused regression test that:
    - Creates a `MockFirebaseMessaging` (mocktail).
    - Calls `FCMService.setMessagingForTest(mock)`.
    - Stubs `getToken()` → `'test-token'`.
    - Asserts `FCMService.getToken()` returns `'test-token'` without hitting real Firebase.
    - In `tearDown`, calls `FCMService.setMessagingForTest(null)` to clear override.
  - **Out of scope**: refactoring FCMService away from the all-static pattern (much bigger change; not the ticket's intent). The test seam is the minimum-viable fix that unblocks DI-style testing. (BUT-446)

- [ ] **A2. BUT-506 — Extract FirestoreBootstrap helper** —
  - Create `lib/core/bootstrap/firestore_bootstrap.dart`:
    ```dart
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:flutter/foundation.dart';

    /// Centralizes the Firestore bootstrap sequence pulled out of main.dart.
    /// Pass an explicit instance for tests; production callers omit it and
    /// get FirebaseFirestore.instance.
    class FirestoreBootstrap {
      static Future<void> configure({FirebaseFirestore? firestore}) async {
        final db = firestore ?? FirebaseFirestore.instance;
        db.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: 100 * 1024 * 1024,
        );

        if (kIsWeb) {
          try {
            await db.collection('_health').doc('_').get()
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            // BUT-506 / BUT-? web IndexedDB recovery (preserve existing
            // try/catch + terminate/clearPersistence/re-set semantics).
            await db.terminate();
            await db.clearPersistence();
            db.settings = const Settings(
              persistenceEnabled: true,
              cacheSizeBytes: 100 * 1024 * 1024,
            );
          }
        }
      }
    }
    ```
  - `lib/main.dart`: replace lines 174-198 (the `FirebaseFirestore.instance.settings = ...` block + nested web health-check + recovery) with a single `await FirestoreBootstrap.configure();`. Preserve any surrounding try/catch + `AppLogger` calls — wrap the new helper call in the same outer try/catch the existing block has.
  - **Verification**: `flutter analyze` clean; manual smoke that app boots in debug.
  - Tests: `test/unit/core/bootstrap/firestore_bootstrap_test.dart` — minimal (verifies the helper compiles + accepts an injected mock; the bootstrap path itself is covered by integration tests).
  - **Out of scope**: line 1218 (`BUT-743: resolved via DI; no FirebaseFirestore.instance here.`) — already migrated, comment-only. (BUT-506)

### Agent B: Auth/security micro-hardening

Specialists: `firebase-backend-security` (consent flow), `flutter-developer` (UI dialog), `code-reviewer` + `testing-specialist`.

- [ ] **B1. BUT-465 — Re-consent renewal prompt at app start** —
  - Strategy: route-level dispatch from `_ButleryAppState` after Firebase + ConsentService bootstrap, before navigating to home. Dialog blocks user until they re-confirm or revoke optional consents.
  - **New file** `lib/widgets/consent/consent_renewal_dialog.dart`:
    - Stateful dialog showing the current consent purposes (analytics, marketing, socialFeatures, pushNotifications) as toggles, plus a link to the privacy policy.
    - Required consents (no toggle) shown as fixed text.
    - "Acceptera" button calls `consentService.saveConsent(updatedPurposes)`. The save re-stamps `consentVersion` to current (`'1.1.0'`) and audit-logs via `FirebaseConsentRepository.saveConsent` (already gated behind permission validation per BUT-424).
    - "Avbryt" → calls `consentService.revokeOptionalConsents()`, dismisses dialog. (User can still revisit via settings.)
    - All copy in Swedish to match app locale.
  - `lib/main.dart` `_ButleryAppState`:
    - Add new private method `_checkConsentRenewal()`. Awaits `ApplicationBootstrap.initialized`, fetches `ConsentService` from container, and if `await consentService.needsConsentRenewal()` is true AND user is authenticated, schedules `showDialog<void>(... ConsentRenewalDialog ...)` on next frame via `WidgetsBinding.instance.addPostFrameCallback`.
    - Wire from `initState` after `_initializeSessionTimeout` (which already awaits bootstrap). Failures non-fatal (network, etc.) — log + continue, don't block app start.
  - Tests:
    - `test/unit/services/account/consent_service_test.dart` (extend) — verify `needsConsentRenewal` returns true when stored version < current; false when equal.
    - `test/widget/consent/consent_renewal_dialog_test.dart` — pumps the dialog with a mock ConsentService; tap "Acceptera" → asserts `saveConsent` called with selected purposes; tap "Avbryt" → asserts `revokeOptionalConsents` called.
  - **Out of scope**: full GDPR audit-log wiring (BUT-424); first-grant flow (handled separately by onboarding). This ticket only handles the *renewal* path when an existing consent's version is stale. (BUT-465)

### Agent C: CI hygiene

No agent — direct edit of `.github/workflows/build-validation.yml`. CI workflow changes don't trigger Tier-2 specialist hooks.

- [ ] **C1. BUT-490 — Upload AAB + web bundle as CI artifacts** —
  - `.github/workflows/build-validation.yml`:
    - After "Build Android App Bundle" step (line 180, before "Verify AAB signed..."), add:
      ```yaml
      - name: Upload AAB artifact
        if: matrix.platform == 'android'
        uses: actions/upload-artifact@v4
        with:
          name: app-${{ github.sha }}-android.aab
          path: build/app/outputs/bundle/release/app-release.aab
          retention-days: 14
          if-no-files-found: error
      ```
    - After "Build for web" step (line 205), add:
      ```yaml
      - name: Upload web bundle artifact
        if: matrix.platform == 'web'
        uses: actions/upload-artifact@v4
        with:
          name: app-${{ github.sha }}-web
          path: build/web
          retention-days: 14
          if-no-files-found: error
      ```
    - iOS not uploaded — build is `--no-codesign` and isn't installable; deferred to BUT-447.
  - **Verification**: workflow YAML lints via existing CI; first PR with this change should produce two artifacts on the build-summary page.
  - No test (CI config). (BUT-490)

### Ticket-state updates (no code)

- [ ] **D1. BUT-716 — close as Done (premise gone)** — comment with `AndroidManifest.xml:22-23` evidence; transition to Done.
- [ ] **D2. BUT-520 — re-scope ticket body** — update Linear ticket description: "Audit & migrate ~30 standalone ViewModels from `extends ChangeNotifier` to `extends BaseViewModel`. Current state: only 16 of ~46 VMs use BaseViewModel; the rest still hold their own loading/error fields. Multi-sprint sweep — propose batches of 5-7 VMs per sprint, starting with high-traffic ones (recipe_form, recipe_detail, friends, menu, auth)." Leave in Backlog (priority Low remains).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Affected unit/widget tests: `fcm_service_test`, `firestore_bootstrap_test`, `consent_service_test`, `consent_renewal_dialog_test`
- [ ] Tier-2 specialist gates: `code-reviewer` (any .dart), `testing-specialist` (any lib/), `firebase-backend-security` (fcm_service.dart + main.dart Firestore touch + consent flow)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-446/506/465/490/716 → Done; BUT-520 body updated, stays in Backlog

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-488 — pubspec auto-bump CI workflow (3h, intricate; standalone)
- BUT-704 — i18n @key ARB descriptions (2-day sweep)
- BUT-520 — VM-migration sweep (re-scoped this sprint; runs as own multi-sprint effort)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Easier testing of push notifications**: the part of the app that handles push notifications (FCM) was wired in a way that blocked test isolation. After this sprint, tests can swap in a mock cleanly. No user-visible change.
- **Cleaner app startup**: the boot sequence that configures the local cache used to live inline in `main.dart`. Moving it to its own helper makes future changes (e.g., disabling cache for a specific platform) safer and more testable.
- **GDPR re-consent prompt**: today, when we update what users have consented to (e.g., adding new processing purposes), users never see a refresh prompt — they keep their old consent state silently. After this sprint, when the consent version rolls forward, the next time a user opens the app they'll get a dialog asking them to re-confirm. Users can also revoke optional consents from the same dialog.
- **Build artifacts available for manual QA**: every green CI run will now publish a downloadable Android `.aab` and a web bundle, retained for 14 days. Useful for testing a PR build without checking out and building locally.
- **Two ticket cleanups**:
  - One ticket (Android backup permission) was already done by an earlier sprint without being noticed — closing it now.
  - Another ticket (ViewModel migration) had its scope wrong — it claimed 3 holdouts when reality is ~30. Updating the description so the next sprint starts from accurate facts.
- **Risk**: low. Test-seam additions are pure additions; the bootstrap extraction is a code-move with identical behavior; the re-consent dialog only fires when needed and is dismissable; CI artifact uploads can't break a build (the upload is a separate step). Easy to revert per task.

---

## Archived prior sprint (completed in commit 44b6f4792)

GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H) — shipped BUT-466/464/463/462/461/613/471. See git log for full task breakdown.

## Archived sprint before (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627. See git log for full task breakdown.

## Archived sprint before (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.

## Archived sprint before (completed in commit 75873d1e1)

Pre-beta moderation + anti-spam + UGC compliance — 2026-05-04 (E) — shipped BUT-537/544/649/651/654/659. See git log for full task breakdown.
