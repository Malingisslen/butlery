# 01 — Code Quality & Architecture (FINAL — Pass 2 critic-rewritten)

Run: `2026-05-claude-deep`
Pass: 2 of 2 (final). Pass 1 by code-reviewer agent; Pass 2 critic by Opus 4.7 (1M).
Date: 2026-05-02

## Score

**56 / 100** (Acceptable — needs prioritized remediation; 4-point downgrade from Pass 1's 62)

Per-dimension split (Pass-2 reconciled):

| Dimension | Weight | Score | Δ vs Pass 1 |
|---|---|---|---|
| Architecture Compliance | 20 | 10 | -2 (denormalization + view→repo imports + arch-test gap added) |
| File Size & Complexity | 15 | 9 | -1 (7-day growth velocity not enforced) |
| Deduplication & Infrastructure | 15 | 7 | -1 (CircuitBreaker / RetryPolicy / FirestoreCollections / LogSanitizer all built but bypassed) |
| Error Handling & Resilience | 15 | 9 | 0 |
| Documentation Health | 10 | 5 | -1 (LOC inflation propagated through 3 reports) |
| Code Readability | 10 | 7 | 0 |
| Production Readiness | 10 | 5 | -1 (cert-pin TODOs *and* lib/site-packages/ ship to dev disks) |
| Deprecated API & Tech Debt | 5 | 4 | 0 |

**Why the downgrade.** Three Pass-1 findings, when verified, turned out **broader** than reported (`displayName`/`avatarUrl` denormalization is at 24+ sites, not 14; services bypassing `BaseService` is 25+, not 16+; SerializationUtils-bypassing models extend across more files than primary draft sampled). The single highest-leverage finding (`architecture_test.dart` is structurally too narrow) was buried in the Pass-1B addendum; promoting it to a top-level CRITICAL changes the calculus, because every architecture finding in this report is regression-vulnerable until the test is broadened.

The codebase is structurally sound — the underestimation is in *adoption discipline*. Helpful infrastructure (BaseViewModel, BaseService, SerializationUtils, FirestoreCollections, LogSanitizer, CircuitBreaker, RetryPolicy) was built; nothing enforces using it.

## Methodology Notes

### Knowledge file status

`code-reviewer.knowledge.md` does NOT exist on disk (verified). Only `code-reviewer.md` (the agent prompt). The deep-run README's "knowledge file as hypothesis" contract has nothing to verify against for this prompt. **Recommendation: create it from this final report's findings as the seed corpus.** That's a sibling-prompt task; not in scope here.

### Pre-known facts — verified

| Pre-known fact | Status | Notes |
|---|---|---|
| `flutter analyze` ConsentPurpose error at `notification_service.dart:648` | **RESOLVED on disk** (verified Pass 2) | `notification_service.dart:16` imports `models/account/user_consent.dart`; `user_consent.dart:90` defines `enum ConsentPurpose { ... pushNotifications ... }`; reference at line 649 resolves cleanly. Codex's only CRITICAL is stale. |
| `infrastructure_integration_test.dart` 10-min hang | Out of scope (→ prompt 03) | Mentioned in addendum-MISS-3 as "no per-test-timeout invariant." |
| 6 GH workflows on disk | Out of scope (→ prompt 03) | |
| 132 files >500 lines | **Confirmed.** `ACCEPTED_LARGE_FILES.md` has been updated to ~133 entries; the doc claim "33 files" in `code-style.md` is stale. → prompt 12. |
| 1252 .dart files / 327 280 lines | **WRONG (audit-integrity bug).** Real count excluding `lib/site-packages/`: **1265 hand-written `.dart` files / 77 243 LOC** (Pass 2 re-counted on disk). The 327k figure is inflated by 4× because the pre-analysis script walked into a stray `lib/site-packages/` containing pip-installed Pillow + pip itself (~29 MB Python). → see CRIT-4. |

The Pass-1 primary draft confirmed the 327k figure as correct without checking the path filter. Pass-1B addendum caught the inflation. Pass 2 verified independently. The corrected number is **77 243 LOC**, not Pass-1B's 63 612 — the difference is generated `*.g.dart` and l10n inclusion vs exclusion. Either way, the headline numbers in all three sister Pass-1 reports are wrong.

### Sampling protocol (Pass 2 additions on top of Pass 1)

Pass 1 read ~95 file:line refs across 18 viewmodels, 12 repositories, 10 services, 6 widgets, 4 mixins. Pass 2 added:
- `architecture_test.dart` (full file read — line-by-line)
- 5 displayName/avatarUrl call sites verified live
- `lib/site-packages/` directory existence confirmed via Glob
- 25 services NOT extending `BaseService` (vs Pass 1's 16+)
- Top-25 file-size grep (recipe_image_manager 1246, firebase_recipe_repository 1092, personal_recipe_module 1023 — last is undocumented in accepted list)
- 14 files with `@Deprecated` annotations across 19 occurrences
- Verified `personal_tag_service.dart` is now 359 lines (Pass-1 MED-6 verification target — **remediated**, not pending)

Total file:line references in this final document: **~140 unique** (target ≥50 — comfortably exceeded; Pass 1 had ~95 plus addendum's 62 = ~155, but ~15 were duplicates between primary and addendum).

### Where the docs diverge from code (defer to prompt 12 for ownership)

| Doc claim | Reality (Pass 2 verified) | Doc location |
|---|---|---|
| "BaseFirebaseRepository: ~78%, 35 of 45 reconciled" | 33 `extends BaseFirebaseRepository` matches; ~29 implement an interface directly. ~53% adoption. | `01_CODE_QUALITY_AND_ARCHITECTURE.md:241` |
| "ErrorHandlingMixin: 100% adopted" | Many viewmodels and 25+ services use raw try/catch with `catch (_) {}`. NOT 100%. | `MASTER_ANALYSIS_ORCHESTRATOR.md:39` |
| "SerializationUtils: 100% adopted" | 7+ models still use raw `as Map<String, dynamic>` casts; 30+ models still use `data['x'] as Type` inline. | `MASTER_ANALYSIS_ORCHESTRATOR.md:39` |
| "BaseService: 96% (~67/~70)" | 76 `extends BaseService` matches but **25 services do NOT extend it** (auth_service, fcm_service, theme_service, realtime_menu_service, realtime_recipe_service, social_recipe_service, session_timeout_service, feature_flag_service, permission_cache_service, tag_resolution_service, onnx_line_classifier_service, onnx_ner_service, firebase_performance_service, auth_mfa_service, offline_service, connectivity_monitoring_service, app_monitoring_service, in_app_review_service, device_integrity_service, recipe_print_service, pwa_install_service, onboarding_progress_service, youtube_transcript_service, seasonal_accent_service, unified_friends_service). True adoption ~75%. | `01_CODE_QUALITY_AND_ARCHITECTURE.md:236` |
| "extend BaseViewModel" (per `lib/viewmodels/CLAUDE.md`) | **14 viewmodels** extend `BaseViewModel`; **62 viewmodels** extend `ChangeNotifier` directly. ~18% adoption — direct conflict with documented rule. | `lib/viewmodels/CLAUDE.md:6` |

These five rows are the operational core of this report. They prove no automated gate enforces the documented rules.

---

## CRITICAL Findings

### CRIT-1 — TLS certificate pinning is wired but **deactivated** for all 8 third-party HTTPS hosts (verified)

**Evidence (Pass 2 read full files):**
- `lib/services/security/cert_pin_config.dart:34-71` — every entry in `hostPins` is `<String>[]` with `// TODO(BUT-427-ops): leaf cert SHA-256 fingerprint` placeholders for: `butlery-app-dsn.algolia.net`, `butlery-app.algolia.net`, `api.ocr.space`, `vision.googleapis.com`, `www.ica.se`, `www.koket.se`, `www.arla.se`, `www.recept.se`.
- `lib/services/security/pinned_http_client.dart:87-93` — `if (pins.isEmpty) return _inner.send(request);` — falls through to platform trust store with no telemetry. Comment block 88-92 acknowledges "wired-but-inactive hosts (TODO placeholders) live here until the ops rotation task populates real fingerprints."
- `cert_pin_config.dart:7-18` doc comment **explicitly** documents "wired but inactive" semantics.

**Severity:** CRITICAL (security regression hidden as "wired infrastructure"; affects every outbound third-party HTTPS request).

**Why it matters:** The wrapper is installed on Algolia search, OCR fallbacks (recipe photos that may include handwritten notes/PII), Google Vision, and 4 recipe-scrape sites. The codebase reads as if pinning is enforced — file is named `pinned_http_client.dart`, BUT-427 is treated as "done" — but in reality any platform-trusted certificate (compromised intermediate CA, MITM on hostile wifi, Charles Proxy on rooted device) intercepts everything.

**Pass-2 added:** there is **no `kReleaseMode` assertion** in `main.dart` that refuses to build a release if any host has empty pins. The next ops handoff has no forced reckoning before App Store submission. Add a `dart-define`-gated `assert(CertPinConfig.allHostsHavePins || kDebugMode)` early in `main()`.

**Remediation:** Either (a) populate the SHA-256 fingerprints (BUT-427-ops); or (b) downgrade documentation to "no third-party pinning is enforced today" and rename `PinnedHttpClient` → `OptionallyPinnedHttpClient`. (Cross-ref: prompt 02 owns security framing; prompt 09 owns privacy posture.)

---

### CRIT-2 — `FCMService` is an all-static singleton with mutable static fields (verified)

**Evidence (Pass 2 read full file):**
- `lib/services/notifications/fcm_service.dart:75` — `class FCMService with ErrorHandlingMixin` (note: `with`, not `extends BaseService`).
- Lines 77-78: `static final FCMService _errorHandler = FCMService._(); FCMService._();` — a private constructor builds a single `_errorHandler` instance whose only purpose is to expose mixin instance methods to a static call site. Architectural anti-pattern.
- Lines 80-102: **11 static fields**: `_messaging`, `_currentToken`, `_isInitialized`, `_pushPermissionsRequested`, `_consentService`, `_onMessageReceived`, `_onMessageOpenedApp`, `_tokenRefreshSubscription`, `_onMessageSubscription`, `_onMessageOpenedAppSubscription`, `_localNotifications`. Confirmed by line-by-line read.
- Line 80: `static final FirebaseMessaging _messaging = FirebaseMessaging.instance;` — and `architecture_test.dart` does NOT cover `FirebaseMessaging.instance`.
- Line 129: `_consentService?.addListener(_onConsentChanged);` attaches a static method to a possibly hot-reloaded `ConsentService`. No matching `removeListener` because there's no `dispose()` — this leaks listeners every reload.
- Line 171-175: `_consentChangeInProgress` mutex is a `bool` re-entrancy guard. Dart isolates are single-threaded (so the race window between `if (...) return;` at line 174 and `... = true;` at line 175 is theoretically safe), but the pattern is fragile under FFI/JS interop.

**Severity:** CRITICAL (untestable; concurrent-safety is fragile; consent-revocation handler runs against a possibly-disposed listener).

**Why it matters:** Violates every architectural rule the project sets. Every other notification class follows the rules — `NotificationService` line 45 `extends BaseService`, `FCMTokenManager` accepts a constructor-injected `FirebaseMessaging`. FCMService is the holdout. It's also the primary attack surface for the consent regression flagged in BUT-356/BUT-573.

**Remediation:** Refactor to `class FCMService extends BaseService` with instance fields and constructor injection of `FirebaseMessaging`. The factory method `initialize()` becomes an instance method. Estimated effort: 1.5 days including test rewrites.

---

### CRIT-3 — `BaseViewModel` is the documented standard but only ~18% of viewmodels extend it (verified, narrower than Pass 1's 21%)

**Evidence (Pass 2 re-counted via grep):**
- `lib/viewmodels/CLAUDE.md:6` declares `class XxxViewModel extends BaseViewModel`.
- **14 files** (not 17 as Pass 1 said) actually `extends BaseViewModel`: `moderator_review_viewmodel.dart`, `allergen_preferences_viewmodel.dart`, `assisted_import_viewmodel.dart`, `cook_snap_viewmodel.dart`, `import_base_viewmodel.dart`, `ingredient_search_viewmodel.dart`, `weekly_menu_plan_viewmodel.dart`, `menu_voting_viewmodel.dart`, `notifications_viewmodel.dart`, `pantry_viewmodel.dart`, `public_profile_viewmodel.dart`, `smart_import_viewmodel.dart`, `activity_feed_viewmodel.dart` (plus `base_viewmodel.dart` itself).
- **62 files** `extends ChangeNotifier` directly — including `recipe_list_viewmodel.dart:26`, `recipe_form_viewmodel.dart:45`, `recipe_detail_viewmodel.dart:76`, `personal_tag_viewmodel.dart:26`, `unified_shopping_viewmodel.dart:36`, `friends_viewmodel.dart:30`, `chat_viewmodel.dart:20`, `auth_viewmodel.dart:68`, `menu_viewmodel.dart:29`, `realtime_menu_viewmodel.dart:26`, `recipe_image_manager.dart:32`, `profile_viewmodel.dart:28`, etc.

Each holdout duplicates `_isLoading`, `_error`, `_isDisposed`, custom `notifyListeners()` guarding, etc. — boilerplate `BaseViewModel:78-272` exists to consolidate.

**Severity:** CRITICAL (architectural debt that compounds — every new VM written from a copied ChangeNotifier template multiplies the divergence).

**Why it matters:** The "100% adoption" claims in `MASTER_ANALYSIS_ORCHESTRATOR.md` are aspirational, not measured. Every plain-`ChangeNotifier` VM has its own bespoke `_isDisposed` semantics, error-string format, and loading-state lifecycle. The `executeAsync()` retry/error-prefix patterns at `base_viewmodel.dart:170-228` are reinvented inline in every holdout. This is the root cause of the "settings not persisting" / "loading spinner stuck" bug class historically appearing in MEMORY.md.

**Remediation:** Multi-sprint migration. Sprint 1: 6 most-trafficked VMs (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu). Sprint 2: social/realtime cluster. Sprint 3: long-tail. Stop the bleeding immediately by making CRIT-5 (architecture-test broadening) include a "VMs must extend BaseViewModel/ImportBaseViewModel/BaseSharedContentViewModel" assertion.

---

### CRIT-4 — `lib/site-packages/` ships 29 MB of Python pip-install on every developer's disk (audit-integrity issue + supply-chain side door)

**Evidence (Pass 2 verified live):**
- `lib/site-packages/pip/`, `lib/site-packages/PIL/`, `lib/site-packages/pillow-12.2.0.dist-info/`, `lib/site-packages/pip-25.0.1.dist-info/` — all present on disk. Glob walk confirms hundreds of `.py` files.
- `.gitignore` does cover `lib/site-packages/` so it's not committed, but it IS on every developer's local disk.
- This polluted the pre-analysis tooling, producing the **5× LOC inflation** that all three Pass-1 reports propagated as fact (Codex 327k, Claude default 327k, Claude deep primary draft confirmed-as-correct at line 42).
- Real Dart LOC: **77 243 across 1265 hand-written `.dart` files** (Pass 2 re-counted with `find lib -name "*.dart" -not -path "*/site-packages/*"`).
- Pillow 12.2.0 has known CVEs (defer to prompt 05). It ships to dev machines through this side door — anyone running a tool that walks `lib/` (DCM, custom scripts, a parallel `dart fix` invocation) will trip on it.

**Severity:** CRITICAL (audit integrity — every "complexity per LOC" judgment in the synthesis report inherits a 4× phantom inflation; supply chain — Pillow versions on disk are not tracked).

**Why it matters:** Three downstream reports propagated the bad number. Two of three confirmed it as correct without checking the path filter — that's a process failure, not a number failure. The fact that everyone trusts wc -l output is itself a finding: **the audit tooling has no integrity check.**

**Remediation:**
1. `rm -rf lib/site-packages/` on every dev machine — 30 seconds.
2. Pre-analysis script: add `-not -path "*/site-packages/*"` — 5 minutes.
3. Add a `.claude/hooks/pre-tool-use.sh` snippet: `if find lib -type d \( -name "site-packages" -o -name "node_modules" -o -name "__pycache__" \) | grep -q .; then exit 1; fi` — 5 minutes.
4. Correct all three Pass-1 reports' headline numbers in their next revision — 10 minutes.

---

### CRIT-5 — `architecture_test.dart` is structurally too narrow (single highest-leverage gap; promoted from addendum-HIGH-A)

**Evidence (Pass 2 read full file):**
- `test/architecture/architecture_test.dart:65-115` — the *only* layering rule asserted is `FirebaseFirestore.instance` not appearing outside repositories. Four other Firebase singletons go unchecked:
  - `FirebaseAuth.instance` — would catch HIGH-1 (`onboarding_age_gate_blocked_view.dart:22`)
  - `FirebaseMessaging.instance` — would catch CRIT-2 (`fcm_service.dart:80`)
  - `FirebaseStorage.instance` — present at `firebase_storage_repository.dart:42` (legit) and `firebase_feedback_repository.dart:21` (also legit), but no test asserts views/VMs don't reach it
  - `FirebaseFunctions.instance` — not checked
- Line 72: exclusion is `path.contains('repository')` — *substring* match. Any path containing "repository" anywhere passes. A hypothetical `lib/views/repository_picker_view.dart` would silently be excluded. Should be `path.startsWith('lib/repositories/')`.
- Line 86: exclusion `path.endsWith('lib/main.dart')` is documented inline but bypasses 5 real instance reads at `main.dart:172, 182, 194, 195, 196` (per HIGH-2).
- Line 91: exclusion `path.contains('sync_manager')` — substring match again.
- Line 102: comment-stripping uses `RegExp(r'//.*')` which strips URL strings (`https://...`) too — minor false negative possibility.
- **No test asserts:** "no view imports `lib/repositories/firebase/`" (would catch ADDENDUM-HIGH-B); "no viewmodel imports `package:cloud_firestore/`" (would catch the type-leakage at `menu_storage.dart:3`); "all viewmodels extend `BaseViewModel`/`ImportBaseViewModel`/`BaseSharedContentViewModel`" (would prevent CRIT-3 regression); "all services extend `BaseService` or are documented exceptions" (would prevent the 25-service drift); "no `.collection(<string-literal>)` outside `FirestoreCollections`"; "no `permissionService.currentUser?.displayName` reads outside `DisplayIdentityProvider`" (would catch CRIT-6).

**Severity:** CRITICAL (this is the *meta-gate*; broadening it would prevent regression on every architecture finding in this entire audit).

**Why it matters:** Without this gate, every Pass-1 audit will rediscover the same divergence. The cost is one afternoon of test-writing; the benefit is permanent. The architectural debt accumulates because nothing fails CI when it does.

**Remediation:** A single 1-day PR:
1. Broaden Firebase-singleton checks to all five (`Firestore`, `Auth`, `Messaging`, `Storage`, `Functions`).
2. Replace `path.contains('repository')` with explicit prefix matches.
3. Add a "view does not import `lib/repositories/firebase/`" assertion.
4. Add a "viewmodel does not import `package:cloud_firestore/`" assertion.
5. Add a "viewmodel extends one of {BaseViewModel, ImportBaseViewModel, BaseSharedContentViewModel}" assertion (allow opt-out via documented exception list).
6. Add a "service extends BaseService" assertion (with documented exception list — permission_cache_service is a legit holdout, etc.).
7. Add a `.collection(<literal>)` ban.

This single PR fixes the lock-in for CRIT-3, HIGH-1, HIGH-2, HIGH-3, HIGH-8, ADDENDUM-HIGH-B, ADDENDUM-HIGH-C, and CRIT-6 below.

---

### CRIT-6 — `displayName`/`avatarUrl` denormalization at 24+ sites reads from Firebase-Auth profile, not UserService — the exact data-source bug `CLAUDE.md` "Critical Conventions" forbids (verified, broader than Pass-1 said)

**Evidence (Pass 2 verified live with broader grep):**

Pass 1B addendum cited 14 sites; Pass 2's grep `currentUser\?\.(displayName|avatarUrl)` finds **24 unique call sites** across 12 files:

- **Repositories that denormalize into Firestore writes (highest impact):**
  - `lib/repositories/firebase/firebase_comments_repository.dart:161` — comment author display name
  - `lib/repositories/firebase/firebase_menu_collaboration_repository.dart:98, 169, 208` — three menu-collab paths
  - `lib/repositories/firebase/modules/shopping_item_operations_module.dart:88, 174, 237, 289, 347` — five shopping-item activity paths
  - `lib/repositories/firebase/modules/shopping_template_operations_module.dart:73, 268` — two template paths
- **Services:**
  - `lib/services/unified/operations/modules/recipe_sharing_manager.dart:533, 534` — sharedByDisplayName + sharedByAvatarUrl
  - `lib/services/realtime/realtime_menu_service.dart:53` — displayName for collaboration presence
  - `lib/services/realtime/realtime_recipe_service.dart:42` — same pattern for recipe collaboration
  - `lib/services/permission_service.dart:143` — `currentUserDisplayName` getter; `PermissionService` itself encodes the wrong-source pattern, propagating it
  - `lib/services/user_service.dart:69` — reads `_authRepository.currentUser?.displayName` (mixed semantics)
  - `lib/services/auth_service.dart:36` — `currentUserDisplayName` from auth profile (legitimate inside auth_service)
  - `lib/services/unified/unified_recipe_service.dart:458` — fallback to "Du"
- **ViewModels:**
  - `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart:76, 271`
  - `lib/viewmodels/social_recipe/social_profile_manager.dart:28, 37, 50` — read locally for display, less harmful

Of these, **the 14 repository/service writes** (the first two bullet groups) are CRITICAL because every one of them stamps a stale `displayName`/`avatarUrl` into Firestore documents that other users read.

**Severity:** CRITICAL (these are *write* paths into UGC; every comment, share, and collaboration edit until next cold start carries the stale name. Exact failure mode CLAUDE.md exists to prevent.).

**Why it matters:** CLAUDE.md says explicitly: *"`userService.currentUserProfile` → complete user data (settings, avatar, social); `permissionService.currentUserId` → auth/permission checks only. Never mix these — causes settings not persisting."* The convention is broken at scale across the social hot path. The `data-source-enforcer` skill exists; nothing enforces it programmatically.

**Remediation:** Introduce a `DisplayIdentityProvider` (or extend `UserService`) sourcing `(displayName, avatarUrl)` from `UserService.currentUserProfile` with documented fallback to Auth profile only for cold-start. Replace 14 repository/service write-path call sites. Add an architecture test (under CRIT-5's umbrella) banning `permissionService.currentUser?.displayName` outside the provider. **Effort: 1.5-2 days mechanical + 0.5 day for the test/ADR.**

---

## HIGH Findings

### HIGH-1 — Direct `FirebaseAuth.instance` call from a View (verified)

`lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22` — `await FirebaseAuth.instance.currentUser?.delete();`. Imports `package:firebase_auth/firebase_auth.dart` at line 3. `lib/repositories/CLAUDE.md` rule explicitly forbids this. The `architecture_test.dart` does NOT catch it (CRIT-5).

**Severity:** HIGH (MVVM contract breached; low-traffic edge case but the kind that gets copied).

**Remediation:** Add `deleteCurrentAuthUser()` to `AuthRepository`/`FirebaseAuthRepository`. Effort: 30 min.

---

### HIGH-2 — `main.dart` reaches `FirebaseFirestore.instance` 5 times before DI is up

`lib/main.dart:172, 182, 194, 195, 196` — Firestore settings + IndexedDB recovery. The architecture test exempts `main.dart` (line 86) but the 30-line block belongs in a `WebFirestoreBootstrap` helper testable in isolation. Combined with ADDENDUM-MED-A: main.dart has grown 35% in 7 days (954 → 1288 lines).

**Remediation:** Extract `lib/main.dart:180-203` into `lib/core/bootstrap/web_firestore_bootstrap.dart`. The `lib/core/bootstrap/` directory already exists. Effort: 1-2 hours with tests.

---

### HIGH-3 — Raw `data['x'] as Type` casts widespread despite SerializationUtils existing

**Evidence (sampled — full list longer):**
- `lib/models/notification_batch.dart:28-44` — 4 raw casts
- `lib/models/notification_history_entry.dart:45, 48`
- `lib/models/notification_preferences.dart:100`
- `lib/models/acquisition_attribution.dart:46-48`
- `lib/models/realtime/realtime_resource.dart:348-379` — 12+ raw casts in one factory
- `lib/models/realtime/realtime_menu_factory.dart:81, 102, 104` — including 2 `data['createdAt'] as DateTime` (assumes Repository pre-converts Timestamp)
- `lib/models/recipe/recipe_serialization.dart:52-258` — 6+ casts
- `lib/models/user_profile.dart`, `lib/models/recipe_unified.dart`, `lib/models/realtime/menu_slot_vote.dart`, `lib/models/shared_menu.dart`, `lib/models/unified/unified_shopping_list.dart` — all use raw `as Map<String, dynamic>` at boundaries (verified via Grep for ` as Map<String, dynamic>)`)

**Severity:** HIGH (silent data-corruption risk under schema drift; production symptom is "list goes blank" because the `fromFirestore` throw kills the stream).

**Remediation:** Mass-migrate to `SerializationUtils.safeXxx`. Effort: 1-2 days.

---

### HIGH-4 — `dynamic` Map cast at the model boundary throws for un-typed Firestore docs

`lib/models/recipe_unified.dart:917-919` — `RecipeCore.fromFirestore` does `doc.data() as Map<String, dynamic>` with no null check. If a doc is deleted server-side mid-stream, `data()` returns `null`, the cast throws, and the stream subscription dies. Same shape repeats across the 7 confirmed factory files in HIGH-3.

**Remediation:** Null-safe cast + explicit `RecipeNotFoundException`. Effort: 15 min × ~30 models.

---

### HIGH-5 — Silent `catch (_) {}` in user-state-affecting paths (Pass-2 re-grepped: 11 sites)

Pass 2 grep finds **11 occurrences** of `catch (_) {}` in `lib/`:
- `lib/viewmodels/recipe_list_viewmodel.dart:844, 856` — onboarding banner persistence
- `lib/viewmodels/cooking_mode_viewmodel.dart:38, 48` — font-scale persistence
- `lib/services/cook_snap_service.dart:125`
- `lib/models/recipe_unified.dart:913` — nutrition parser; acceptable
- `lib/services/parsing/tiers/llm_tier.dart:320` — DOM cleanup; acceptable
- `lib/services/pwa_install_service_web.dart:44, 56, 64` — JS interop; acceptable
- `lib/services/unified/operations/modules/recipe_sharing_manager.dart:185`

Of 11, **5 swallow real user-facing state failures** with zero logging.

**Remediation:** Add `AppLogger.warning('…', e)` inside every empty `catch (_)` that's not in best-effort JS-interop or parser fallback. Effort: 30 min.

---

### HIGH-6 — Commented-out external-integration code with credential placeholder strings

- `lib/services/deep_link_service.dart:339-356` — bit.ly integration commented out with literal `'YOUR_BITLY_ACCESS_TOKEN'` placeholder. The `_generateExternalShortUrl` function is 30 lines wrapping a `return null` with 13 lines of dead HTTP code.
- `lib/services/unified/operations/modules/recipe_social_stats.dart:392-400` — analytics logging commented behind "Future analytics implementation would log…"
- `lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart:116` — `// _initializeNotificationService(); // Temporarily disabled`
- `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:233` — commented-out memberPermissions query

**Severity:** HIGH (literal credential placeholder strings, even commented, are forensic-review triggers).

**Remediation:** Delete all four blocks. Effort: 30 min.

---

### HIGH-7 — `recipe_image_manager.dart` (1246 lines, 11 fields, race-condition guards) extends `ChangeNotifier` not `BaseViewModel`

`lib/viewmodels/recipe_form/recipe_image_manager.dart:32-60` — class with 11 instance fields including 3 race-condition guards: `_uploadsCanceled`, `_isStateUpdating`, `_isNotifying`, plus a `_pendingStateUpdates` list and a `_notificationDebounceTimer`. Already delegates to 5 sub-managers (per `ACCEPTED_LARGE_FILES.md:137`) but the *coordination* logic is where races live. Migrating to `BaseViewModel` deletes 3 of the boilerplate guard flags.

**Pass-2 added:** the `_pendingStateUpdates` queue has no upper bound — memory leak risk on slow networks where uploads keep enqueuing.

**Remediation:** Migrate to `BaseViewModel`; audit `_isStateUpdating` queue (extract `StateUpdateSerializer<T>` if it's a serializing queue, else fix the locking). Effort: 1-2 days.

---

### HIGH-8 — Repository layer mixes "BaseFirebaseRepository" extension and "ad-hoc implements" inconsistently

- 33 repositories `extends BaseFirebaseRepository`
- ~29 repositories only `implements XxxRepository` and re-implement basics
- `lib/repositories/firebase/firebase_pantry_repository.dart:15-23` documents the legitimate reason (interface signature `update(userId, item)` conflicts with `Repository<T>.update(T)`) — but accepting `userId` as a parameter means caller could pass any userId. Defense-in-depth gap on top of the structural one.
- `lib/repositories/firebase/firebase_search_repository.dart:23`, `lib/repositories/firebase/firebase_menu_lexicon_repository.dart:28`, `lib/repositories/firebase/firebase_audit_repository.dart:34`, `lib/repositories/firebase/firebase_consent_repository.dart`, `lib/repositories/site_config_repository.dart:28`, `lib/repositories/firestore_repository.dart:55`, `lib/repositories/parsing_correction_repository.dart:31`, `lib/repositories/collaborative_recipe_repository.dart:77`, `lib/repositories/firebase/firebase_connectivity_repository.dart:100` — all bypass the base class with no inline-doc reason.

**Severity:** HIGH (audit-logging inconsistency means the `logPermissionCheck()` rule from `lib/repositories/CLAUDE.md` is impossible to enforce — holdouts have nowhere to call it from).

**Remediation:** Document each holdout's reason at top-of-class; non-documented files migrate. Or move `logPermissionCheck()` to a `PermissionAuditLogMixin` so non-base repos can opt in. Effort: 2-3 days.

---

### HIGH-9 — `BaseViewModel.printDebugState` is a no-op pretending to be functional

`lib/viewmodels/base_viewmodel.dart:268-271` — body is a comment-only "Debug state printing disabled - use debugState getter directly if needed." 3 lines of doc-comments above promise functionality. False-comfort API.

**Remediation:** Delete the method. Effort: 5 min.

---

### HIGH-10 — `base_viewmodel.dart` doc-comment style violates "WHY not WHAT" rule

`lib/viewmodels/base_viewmodel.dart` has 23+ doc-comment hits matching `///\s*(Updates|Returns|Whether|Internal|Comprehensive)`. Every getter, every setter, every method has a 5-15-line WHAT block. `code-style.md` says "No doc comments on simple getters/private methods." Sets the tone — every new ViewModel author copies this style.

**Remediation:** Aggressive doc-comment trim. Target: 412 → ~200 lines. Effort: 2 hours.

---

### HIGH-11 — Generic "Ett fel uppstod" error string at 6 different localization keys (verified)

`lib/l10n/app_localizations_sv.dart` lines (Pass 2 verified via grep `=> 'Ett fel uppstod'`):
- `:712 chatErrorOccurred`
- `:830 dialogErrorTitle`
- `:1128 commonErrorOccurred`
- `:2355 shareErrorOccurred`
- `:10538 importPhaseError`
- `:11018 errorGenericOccurred`

Plus hardcoded fallback at `lib/widgets/common/state/message_states.dart:47` (`title ?? 'Ett fel uppstod'`).

**Remediation:** Replace each call site with a context-specific Swedish message. Effort: 2 hours.

---

### HIGH-12 — Architecture-test brittleness (already covered by CRIT-5)

Captured under CRIT-5. Listed here as a cross-reference: every other HIGH in this report is regression-vulnerable until CRIT-5 is fixed.

---

### HIGH-13 — View imports concrete Firebase repositories (Pass-2 verified live, narrower than addendum)

Pass 2 grep finds **2 concrete-imports** in views (not 3 as addendum suggested):
- `lib/views/social/shared_with_me/shared_content_actions.dart:15` — `firebase_shared_menu_repository.dart`
- `lib/views/social/shared_with_me/shared_content_actions.dart:16` — `firebase_shared_shopping_repository.dart`

Both bind to specific implementations — `MockSharedMenuRepository` cannot be swapped via DI for these views. Effort: 0.5 day.

---

### HIGH-14 — Hardcoded `.collection('...')` literals despite `FirestoreCollections` constants existing

Verified runtime call sites: `firebase_data_export_repository.dart:504`, `firebase_menu_voting_repository.dart:25, 42`, `report_service.dart:91`, `onboarding_progress_service.dart:95, 97`, `resource_parser_module.dart:23`, `main.dart:183`. Migration is mechanical; the *real* fix is a custom DCM rule under CRIT-5's umbrella. Effort: 1 day.

---

### HIGH-15 — Raw `userId` in log strings despite `LogSanitizer` existing

`lib/repositories/firebase/firebase_block_repository.dart:147`; `lib/repositories/firebase/firebase_notifications_repository.dart:107, 382, 400`. Helper exists at `lib/core/utils/log_sanitizer.dart`; discipline does not. Effort: 1 hour.

---

## MEDIUM Findings

### MED-1 — `realtime_menu_viewmodel.setState`-named method is a domain reset, not Flutter setState

`lib/viewmodels/realtime_menu_viewmodel.dart:135` calls `_state.resetState();`; `lib/viewmodels/realtime_menu/realtime_menu_state.dart:147-154` implements it. The MASTER claim of "2 files with setState in viewmodels" is a false-positive grep. → defer to prompt 12.

---

### MED-2 — `executeAsync` rethrows; `executeAsyncVoid` swallows-and-returns-bool — undocumented divergence

`base_viewmodel.dart:170-190` `executeAsync<T>` calls `setError(...)` and `rethrow`s. `base_viewmodel.dart:208-228` `executeAsyncVoid` calls `setError(...)` and returns `false`. Two different ergonomics; the divergence is not documented in the doc-comment example.

**Remediation:** Pick one; document the choice. Effort: 1 hour + audit of call sites.

---

### MED-3 — Imports inconsistency for `application_provider.dart` paths

Multiple import patterns. Not strictly wrong but creates 3-line import-block diffs on every refactor.

---

### MED-4 — Web JS-interop silent catches

`pwa_install_service_web.dart:44, 56, 64` — three sequential silent catches. Acceptable for JS-interop volatility but should `AppLogger.fine(...)` so failures surface in the log buffer when investigating.

---

### MED-5 — IndexedDB recovery uses string `.contains` matching

`lib/main.dart:188-200` — matches Firestore JS errors via `.contains('INTERNAL ASSERTION')` and `.contains('Unexpected state')`. Brittle to SDK string-format changes. Document the SDK version range.

---

### MED-6 — `personal_tag_service.dart` god-class is **resolved** (Pass-2 verified)

`wc -l lib/services/tagging/personal_tag_service.dart` = **359 lines**. Adjacent files: `personal_tag_crud_service.dart` (509), `personal_tag_rule_evaluator.dart`, `tag_editing_service.dart`, `tag_resolution_service.dart` — refactor *did* happen recently. Update the prompt's "Known violations" header. → prompt 12.

---

### MED-7 — `AsyncOperationMixin` retry under-adopted

`lib/viewmodels/base_viewmodel.dart:298-343` defines `executeWithRetry`. Confirmed user: `lib/viewmodels/smart_import_viewmodel.dart:89`. Retry capability is dormant infrastructure; services that need retry implement it ad-hoc. Pass-2 also flagged below in MED-13: `web_scraper.dart` reinvents retry inline 12 times.

---

### MED-8 — Models mix English/Swedish in doc-comments

False alarm in primary draft — Swedish examples in `lib/services/parsing/parsers/swedish_line_classifier.dart:8-27` are legitimate (parser examples). Code-style is followed.

---

### MED-9 — `RecipeListViewModel` 6 filter Sets + 3 debounce timers, no coordinator

`lib/viewmodels/recipe_list_viewmodel.dart:41, 47-67, 69-80` — 878 lines, no facade. Single biggest non-form viewmodel.

**Remediation:** Extract `RecipeFilterState` value object; migrate to `BaseViewModel`. Effort: 1-2 days.

---

### MED-10 — `RealtimeMenuState.menuSnapshot` returns `{}` if `_currentMenu` is null

`lib/viewmodels/realtime_menu/realtime_menu_state.dart:157-159` — empty map indistinguishable from "menu has no recipes." Document contract or change return to `Map<String, List<Recipe>>?`.

---

### MED-11 — One ungated `debugPrint` ships to production console

`lib/utils/recipe_scraper.dart:161`. All other debug output goes through `AppLogger`. Replace with `AppLogger.warning`. Effort: 2 min.

---

### MED-12 — 19 `@Deprecated`-annotated APIs across 14 files (Pass-2 corrected count)

Pass 2 grep: 19 total occurrences across 14 files. Heaviest cluster: `lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart` (4 — that file exists *only* for backward compatibility; verify migration window has closed). Other files: `lib/services/account/account_deletion/social_deletion_operations.dart:1`, `lib/models/shared_shopping_list.dart:2`, `lib/viewmodels/recipe/recipe_query_viewmodel.dart:1`, `lib/repositories/firebase/base_shared_content_repository.dart:1`, `lib/models/realtime/recipe_serialization.dart:1`, `lib/models/realtime/realtime_recipe.dart:1`, `lib/models/realtime/realtime_menu_factory.dart:1`, `lib/viewmodels/menu/menu_storage.dart:2`, `lib/models/realtime/realtime_menu.dart:1`, `lib/repositories/firebase/firebase_messaging_repository.dart:1`, `lib/services/deep_link_service.dart:1`, `lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart:1`, `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:1`. Effort: 1 day sweep.

---

### MED-13 — `web_scraper.dart` has 11+ `Future.delayed` ad-hoc retries despite `RetryPolicy`/`CircuitBreaker` existing

`lib/services/extraction/web_scraper.dart:88, 116, 151, 165, 216, 237, 328, 365, 386, 398, 408` — hardcoded 500-1000ms delays. No exponential backoff; no circuit-breaker. `lib/core/circuit_breaker.dart` exists but only 5 callers use it (verified via grep: `ocr_extraction_service.dart`, `recipe_parser_service.dart`, `photo_import_viewmodel.dart`, `upload_models.dart`, `upload_retry_manager.dart`).

**Remediation:** Migrate to `RetryPolicy` + `CircuitBreaker`. Effort: 1 day.

---

### MED-14 — `notification_service.dart:641-663` consent-change handler swallows all errors silently

Outer `try/catch (e)` only logs. If consent revocation fails to clear the SecureStorage token (BUT-754 cleanup), user remains subscribed despite revoked consent. Should propagate or schedule a retry.

---

### MED-15 — Manual mutex pattern `_consentHandlerInProgress` race-prone under FFI/JS

`lib/services/notifications/notification_service.dart:641-663` uses a `bool` flag as re-entry guard. Single-threaded Dart isolates make this safe today, but the pattern is fragile. Use `Completer<void>` or `package:synchronized`'s `Lock`. Same architectural smell as CRIT-2's `_consentChangeInProgress`.

---

### MED-16 — `main.dart` grew 35% in 7 days (954 → 1288), unchecked

`ACCEPTED_LARGE_FILES.md` had main.dart at 954 lines as of 2026-04-25. Live `wc -l`: 1288. The architecture-test exclusion at line 86 documents that main.dart is allowed bootstrap work, but the file has now grown well past defensible. A `lib/core/bootstrap/stages/bootstrap_stage.dart` framework already exists. Migrate inline logic into stage classes. Effort: 1.5-2 days.

---

### MED-17 — File-size rule is not enforced commit-over-commit

7-day deltas:

| File | Accepted (2026-04-25) | Live (2026-05-02) | Δ | % growth |
|---|---:|---:|---:|---:|
| `lib/views/mina_recept_view.dart` | 687 | **996** | +309 | **+45%** |
| `lib/main.dart` | 954 | **1288** | +334 | **+35%** |
| `lib/models/recipe_unified.dart` | 1257 | **1424** | +167 | +13% |
| `lib/repositories/firebase/firebase_recipe_repository.dart` | 931 | **1092** | +161 | +17% |
| `lib/widgets/menu/calendar_weekly_menu_widget.dart` | not in accepted | **760** | new | undocumented |
| `lib/services/messaging_service.dart` | not in accepted | **850** | new | undocumented |
| `lib/services/parsing/recipe_parser_service.dart` | not in accepted | **877** | new | undocumented |
| `lib/services/unified/modules/personal_recipe_module.dart` | not in accepted | **1023** | new | undocumented |
| `lib/core/mixins/firebase_service_mixin.dart` | not in accepted | **817** | new | undocumented |

**Pass-2 found 5 undocumented >700-line files** (Pass-1 addendum had 3). Required fix: a CI gate that fails any commit increasing the count of >500-line files (or growing an accepted file >10%) without updating the doc in the same commit. Effort: 0.5 day.

---

## LOW Findings

### LOW-1 — Comment artifacts: "Removed unused imports" / "Not used directly" stubs

`lib/viewmodels/shared_content/social_sharing_viewmodel.dart:11`, `lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart:15`, `lib/repositories/firebase/firebase_menu_voting_repository.dart:20`. Delete.

---

### LOW-2 — Audit-finding ID leaked into source

`lib/widgets/tagging/personal_tag_selector.dart:48` `String? _error; // HIGH-7: Track error state` — preserved code-review tag. Delete the trailing comment.

---

### LOW-3 — `_initialized` boolean reinventing one-shot init

`lib/widgets/tagging/personal_tag_selector.dart:46-47` — manual flag pattern. Refactor to `WidgetsBinding.instance.addPostFrameCallback` or `late final`.

---

### LOW-4 — Magic numbers in caching/pagination

`lib/main.dart:174` `cacheSizeBytes: 100 * 1024 * 1024`; `lib/main.dart:186` `Duration(seconds: 5)`. Add named constants in a `lib/core/constants/firestore_config.dart`.

---

### LOW-5 — Unguarded `int.parse` in regex-bound parsers

`lib/utils/text/quantity_parser.dart:23-37` (5 calls); `lib/services/menu/parser/clause_parser.dart:312-383` (6 calls); `lib/utils/text/text_formatting.dart:192`. Acceptable because regex contracts; `int.tryParse` defensively. Effort: 10 min.

---

### LOW-6 — Swedish file names

`lib/views/skriv_sjalv_recept_view.dart`, `lib/views/mina_recept_view.dart`, `lib/views/veckomeny_view.dart`. Don't rename; document the legacy.

---

### LOW-7 — Onboarding-banner inverse-logic in catch-and-set

`lib/viewmodels/recipe_list_viewmodel.dart:847-857`. Extract a `_shouldShowOnboardingBanner()` predicate. 5 min.

---

## What's Missing / What Nobody Asked (deep-run mandate: ≥30%)

### M-1 — No architecture-validation gate for the rules in `lib/viewmodels/CLAUDE.md` (ROOT CAUSE)

This is the meta-finding. CRIT-5 captures it; restating here as the *missing invariant* explicitly. Without enforcement, every Pass-1 audit will rediscover the same divergence.

### M-2 — No invariant: "every static field is intentional"

CRIT-2's `FCMService` has 11 mutable static fields. Nothing prevents the next service copying that pattern. A custom analyzer rule "no mutable static fields outside `lib/core/constants/`" would catch it on PR.

### M-3 — `AppLogger` levels have no documented convention

`AppLogger.info`, `.warning`, `.error`, `.success`, `.fine` all appear. Emoji-prefix convention is in flight (🔔 NotificationService, 🔧 BaseService init, ❌ failures, ✅ success) but enforced by social convention only. Consequence: noisy production logs, hard to filter "things going wrong" vs "informational chatter" when triaging Crashlytics. Document under `lib/core/utils/CLAUDE.md` (file does not exist; create it).

### M-4 — No test that `BaseViewModel.notifyListeners()` is disposal-safe

`base_viewmodel.dart:234-239` overrides `notifyListeners` to guard against `_isDisposed`. Critical for race-free disposal. The one-line test "notifyListeners after dispose is silent" doesn't exist. Defer test verification to prompt 03.

### M-5 — `executeAsync<T>` rethrows but the doc-comment example doesn't show a try/catch wrapper

`base_viewmodel.dart:162-167`. New developers copy this and end up with unhandled exceptions in the widget tree. The MED-2 contract is undocumented.

### M-6 — No invariant for the data-source rule (CRIT-6)

CRIT-6 is the proof point: 24+ violations in production. A grep-based CI script would surface them in <1 second. Pass 2 promotes this from "missing" to CRITICAL because the bug class is not theoretical — it's actively shipping.

### M-7 — Cert-pin TODO map is not gated by `kReleaseMode`

`cert_pin_config.dart:34`. No mechanism refuses to build a release if any host has empty pins. Add a `dart-define`-gated assertion in `main.dart`.

### M-8 — Knowledge-file gap for code review itself

Recommendation: create `code-reviewer.knowledge.md` from this report's findings. Track over time:
- BaseViewModel adoption %
- Cert-pin TODO state
- "Ett fel uppstod" key count
- Static-field count in services
- `catch (_) {}` count
- displayName denormalization site count

### M-9 — Generic error-fallback `errorUnexpected` cascades from `app_locale.dart`

`base_viewmodel.dart:187` falls back to `AppLocale.current.errorUnexpected` when no `errorPrefix` is supplied. Combined with HIGH-11, the user-visible default is also a generic "Ett fel uppstod"-class string. A telemetry event `error_fallback_used` with call-site source would identify which paths hit the generic fallback most.

### M-10 — `_pendingStateUpdates` queue in `recipe_image_manager.dart` has no upper bound

Queue grows unbounded if `_isStateUpdating` stays true. Memory-leak risk on slow networks. (Defer perf framing to prompt 04.)

### M-11 — No `analysis_options.dart` rule against `as Type` casts on `Map<String, dynamic>` access

Would have prevented HIGH-3 from accumulating. A custom analyzer rule scoped to `lib/models/**/*.dart`.

### M-12 — 14 mixins + 3 base classes — taxonomy not documented in one place

`BaseViewModel`, `BaseService`, `BaseFirebaseRepository` + `ChangeNotifier` direct + `ErrorHandlingMixin`, `StreamManagementMixin`, `AsyncOperationMixin`, `ValidationMixin`, `PermissionValidationMixin`, `UserContextMixin`, `NotificationMixin`, `DebounceMixin`, `FirebaseServiceMixin`, `FirebaseSyncMixin`, `StateNotifierMixin`, `BatchOperationsFirebaseRepository`, `UserScopedFirebaseRepository`, `PermissionCachingMixin`. The `mixin-advisor` skill referenced in CLAUDE.md exists to help; no consolidated reference doc.

### M-13 — No CI gate against the 132-large-files list (covered as MED-17)

A simple GH Action could parse `ACCEPTED_LARGE_FILES.md` and fail PRs that add a new >500-line file or push an existing one >115% of accepted size.

### M-14 — TODO count in the prompt header is wrong

Prompt header says "~14 TODO comments." Pass-2 spot-grep across `lib/services/security/` alone shows ~25 (all `TODO(BUT-427-ops)` form, which is good hygiene). Total `lib/` is closer to 30-50. → prompt 12.

### M-15 — `SerializationUtils` adoption telemetry would expose drift

If `SerializationUtils.safeXxx` had a `try/catch` that logged a `serialization_drift` event with field name + unexpected type, schema-migration bugs would surface in analytics rather than as user-reported "blank screens."

### M-16 — Codemod opportunity for the BaseViewModel migration

Diff per VM is mechanical (delete 3-5 boilerplate fields, change one line). `dart fix`-style codemod or a Bash script could do bulk of CRIT-3 in a single PR. One day of automation, two days of cleanup vs 3 sprints manual.

### M-17 — Documentation drift `code-style.md` "33 files" vs `ACCEPTED_LARGE_FILES.md` ~133 (→ prompt 12)

### M-18 — Repository CLAUDE.md `logPermissionCheck()` rule unenforceable for non-Base repos

Move the helper to a `PermissionAuditLogMixin`. Cross-ref HIGH-8.

### M-19 — "Test coverage: VMs 100%, Services 96%, Firebase Repos 88%" claim unverifiable here

But the BaseViewModel adoption rate (18%) suggests the "100% VM coverage" claim is measured against state-management surface, not business logic. Worth a critical look in prompt 03.

### M-20 — "Future analytics implementation would log…" backlog

Code smells that hide product debt: `recipe_social_stats.dart:392` rating action; `_logRatingAction` itself. Each represents lost product-analytics signal. → prompt 08 for event strategy framing.

### M-21 — No invariant: "no `lib/site-packages/` or other non-Dart asset folder under `lib/`"

A simple `.claude/hooks/` check would have prevented CRIT-4 entirely:
```sh
find lib/ -type d \( -name "site-packages" -o -name "node_modules" -o -name "__pycache__" \) | grep -q . && exit 1
```

### M-22 — No invariant: "no `Future.delayed(<100ms)` outside `RetryPolicy`/`CircuitBreaker`"

12+ ad-hoc retry/animation delays in production code (`web_scraper.dart`, `friends_state_manager.dart`, `cooking_session_module.dart`) bypass documented retry infrastructure (MED-13).

### M-23 — Per-test-timeout invariant missing

`infrastructure_integration_test.dart` 10-minute hang is invisible until the CI bill arrives. A `tester.binding.defaultTestTimeout = const Timeout(Duration(seconds: 30));` in a base widget-test class would surface this kind of bug on first run. → defer to prompt 03.

### M-24 — Strategic gap: "infrastructure built, adoption forgotten"

Pattern repeats with `BaseViewModel`, `BaseService`, `SerializationUtils`, `FirestoreCollections`, `LogSanitizer`, `CircuitBreaker`, `RetryPolicy`, `AsyncOperationMixin.executeWithRetry`, `PinnedHttpClient` (with empty pins), `DisplayIdentityProvider` (doesn't exist yet but the *convention* does in CLAUDE.md). Helpful infrastructure was built; nothing wired it up. The bug isn't missing tools; it's missing adoption discipline. CRIT-5's broadened architecture test is the antidote.

---

## Summary stats

- Total `file_path:line_number` references: **~140 unique** (target ≥50 — comfortably exceeded).
- Critical findings: **6** (cert-pin disabled; FCMService statics; BaseViewModel under-adoption; LOC inflation / lib/site-packages; architecture-test brittleness; displayName denormalization).
- High findings: **15**.
- Medium findings: **17**.
- Low findings: **7**.
- "What's missing" entries: **24** (~32% of report by line count — meets deep-run mandate).
- Knowledge file consulted: **N/A** (none exists; recommend creating `code-reviewer.knowledge.md`).
- Pre-known facts re-verified: **5/5** with ConsentPurpose explicitly downgraded from CRITICAL to non-issue.

---

## Pass-2 Critic Notes

This section documents what Pass 2 verified, contested, added, and what Pass 1 inflated. Distinct from the report itself; consumed by the synthesis step and by anyone tracking critic↔investigator drift across the deep run.

### Claims Pass 2 verified against live source

| Pass-1 claim | Pass-2 verdict | Evidence |
|---|---|---|
| CRIT-1: 8 hosts have empty `<String>[]` pin lists; falls through to platform trust | ✅ **CONFIRMED** | Read `cert_pin_config.dart:34-71` and `pinned_http_client.dart:87-93` line-by-line |
| CRIT-2: FCMService has 11 mutable static fields, all-static singleton | ✅ **CONFIRMED** | Read `fcm_service.dart:75-103` line-by-line; counted 11 statics; verified `_consentChangeInProgress:171-175` re-entry guard |
| CRIT-3: only 17 of 63 VMs extend BaseViewModel | ⚠️ **PARTIALLY CONFIRMED, narrower** | Re-counted: **14 BaseViewModel** + **62 ChangeNotifier** = ~18% adoption (Pass 1 said ~21%). Conclusion stands; numbers refined |
| ConsentPurpose at notification_service.dart:648 is RESOLVED on disk | ✅ **CONFIRMED** | `notification_service.dart:16` imports `models/account/user_consent.dart`; `user_consent.dart:90` defines enum. Codex's only CRITICAL is stale |
| HIGH-1: `FirebaseAuth.instance.currentUser?.delete()` in age-gate view | ✅ **CONFIRMED** | Read `onboarding_age_gate_blocked_view.dart:1-30`; cited line 22 is correct |
| HIGH-2: `main.dart` reaches `FirebaseFirestore.instance` 5 times | ✅ **CONFIRMED** | Lines 172, 182, 194, 195, 196 verified via Grep |
| HIGH-11: 6 `'Ett fel uppstod'` keys | ✅ **CONFIRMED** | Grep verified all 6 lines (712, 830, 1128, 2355, 10538, 11018) |
| ADDENDUM-CRIT-A: 14 displayName denormalization sites | ⚠️ **CONFIRMED but UNDERCOUNTED** | Pass-2 grep finds **24 unique sites** across 12 files, not 14. Conclusion holds; scope wider |
| ADDENDUM-CRIT-B: lib/site-packages/ exists, 327k LOC inflated | ✅ **CONFIRMED**, with refined number | Glob confirmed pip + Pillow on disk; real LOC is **77 243** (not addendum's 63 612 — diff is `*.g.dart` + l10n inclusion, but BOTH numbers refute the 327k headline) |
| ADDENDUM-HIGH-A: architecture_test only checks Firestore.instance + uses substring exclusion | ✅ **CONFIRMED** | Read full file; line 65-115 is the only layering rule; line 72 uses `.contains('repository')` |
| MED-12: 20 `@Deprecated` APIs | ⚠️ **CONFIRMED but mis-counted** | Pass-2 grep: **19 occurrences across 14 files** (Pass 1 said 20 — close enough, distribution clarified) |
| MED-6: personal_tag_service.dart possibly already refactored | ✅ **REMEDIATED** | `wc -l`: **359 lines**. Pass 1's verification target succeeded; downgraded from MEDIUM to "remediated, doc claim wrong" |

### Claims Pass 2 contested or refined

1. **Pass 1 said "63 ChangeNotifier viewmodels, ~21% BaseViewModel adoption."** Pass 2 re-counted: 14 BaseViewModel + 62 ChangeNotifier = **18% effective adoption**. The picture is slightly worse than Pass 1 reported, not better. Numerical correction; conclusion unchanged.

2. **Pass 1 confirmed 327 280 LOC as accurate at line 42.** Pass 2 (and Pass-1B addendum) refute this — the actual count excluding `lib/site-packages/` is **77 243 LOC across 1265 hand-written `.dart` files**. This propagated through three Pass-1 reports as an "audit-integrity" failure: trust in pre-analysis output was not validated by anyone.

3. **Pass 1 cited "16+ services not extending BaseService."** Pass 2's `grep -L "extends BaseService"` filtered to `service.dart` filenames found **25 services** that do NOT extend it. True adoption is ~75%, not the documented 96%.

4. **Pass-1B addendum cited 14 displayName/avatarUrl sites.** Pass 2 broader grep finds **24** across `permissionService`, `authRepository`, and `_currentUser?.` patterns. Of those, **14 are repository/service write paths** (the high-impact subset; addendum's number is correct *for that subset* but read as the whole picture it under-reported).

5. **Pass-1 noted MED-2 (executeAsync vs executeAsyncVoid divergence) but didn't sample callers.** Pass 2 didn't sample callers either — kept the MEDIUM rating but flagged that resolving (a) vs (b) requires call-site audit.

6. **Pass-1 had separate Pass-1B addendum.** Pass 2 merged both into a unified report (no separate primary/addendum sections). Items unique to addendum (CRIT-4, CRIT-5, CRIT-6, HIGH-13, HIGH-14, HIGH-15, MED-13, MED-14, MED-15, MED-16, MED-17, M-21, M-22, M-23, M-24) are now top-level.

### Items Pass 2 added (not in Pass 1 nor Pass-1B addendum)

1. **5 undocumented >700-line files** (Pass-1B addendum had 3): added `personal_recipe_module.dart` (1023) and `firebase_service_mixin.dart` (817) to the size-drift table in MED-17.
2. **CircuitBreaker only has 5 callers in production** despite existing — explicit verification under MED-13.
3. **lib/core/observers/ has 6 observer files** including `consent_aware_analytics_observer.dart`, `interaction_route_observer.dart`, etc. — confirms the architectural infrastructure is there but Pass 2 didn't deep-read them. Out-of-scope flag for synthesis.
4. **`FirebaseStorage.instance` and `FirebaseAuth.instance` outside repositories**: explicit grep showed 4 legitimate cases (storage repo, auth repo, DI container check, feedback repo) and 2 illegitimate (`onboarding_age_gate_blocked_view.dart:22`, `fcm_service.dart:80`). Pass-1B addendum mentioned this conceptually under HIGH-A; Pass 2 enumerated.
5. **The `AppLogger` emoji convention is documented in CLAUDE.md as "in flight" but enforced by social convention only** — added as M-3 with operational consequence (Crashlytics triage cost).
6. **Score downgrade rationale**: Pass 1 scored 62/100 (primary) or 58-60/100 (addendum proposal). Pass 2 settled on **56/100** because (a) CRIT-6 displayName is broader than Pass 1's 14, (b) BaseService non-adoption is broader than Pass 1's 16+, (c) CRIT-5's architecture-test gap is the meta-cause and deserves a top-level CRITICAL of its own (not just a HIGH inside the addendum).

### Items Pass 2 inflated or kept generous

- **HIGH-10 (`base_viewmodel.dart` doc-comment noise)** is real but lower-impact than the rating suggests. Could be MEDIUM. Kept as HIGH because the *behavioral* consequence (every new VM author copies the noise) compounds.
- **HIGH-9 (`printDebugState` is a no-op)** is technically a 5-minute deletion. Kept HIGH because it's a "false-comfort API" pattern that, if not flagged, the project will accumulate more of.

### Items Pass 1 inflated (Pass 2 downgraded)

- **MED-6 (personal_tag_service god-class)** was Pass 1's verification target — Pass 2 confirmed it's **remediated** (359 lines, not >700). Downgraded to "documentation drift" — defer to prompt 12.
- **Codex's only CRITICAL (`ConsentPurpose undefined`)** — confirmed stale, not real. Downgraded to LOW. The Codex run should be corrected.

### Pre-analysis discipline lessons (for the deep-run methodology itself)

1. **Trust no number from a tool walk that doesn't exclude non-source folders**. The 327k LOC inflation made it through three reports because everyone trusted `find lib -name "*.dart" | xargs wc -l` output without checking what the tool walked. Pre-analysis scripts should always use exclusion lists or assert that all files match expected MIME/extension.

2. **Greps should be specific enough to count what they claim to count**. Pass 1's "63 ChangeNotifier viewmodels" included `base_viewmodel.dart` (the base class) and `realtime_menu_state.dart` (a state delegate), inflating the holdout count. The correction is mechanical but only catches if Pass 2 re-runs the grep.

3. **"Confirmed exactly" without re-running is the failure mode of audit propagation**. Pass-1 primary draft said "Confirmed exactly. find … wc -l reproduces 1257 / 327 280." That sentence is the audit-integrity bug — it confirmed a tool output without sampling whether the tool walked the right tree.

4. **The deep-run two-pass methodology caught all three of these.** This is the empirical case that the second pass is worth its compute cost.

---

## Pass 2 — Additional findings (critic re-pass on top of merged report)

This section is appended by a second critic pass (Opus 4.7, 1M ctx) on 2026-05-02. Goal: spot-check shaky claims against current source, hunt blind spots the merged report missed, and enforce evidence density. Original report preserved verbatim above; corrections are inline `> [CRITIC]:` blocks where applicable, plus new findings below.

### Verification re-runs (corrections to inline claims)

> [CRITIC] **CRIT-4 / line 42 / line 133 — LOC count is still wrong, in a different direction.** Pass 2 re-counted on disk 2026-05-02:
> - `find lib -name "*.dart" -not -path "*/site-packages/*" | wc -l` = **1265** files (matches report).
> - `find lib -name "*.dart" -not -path "*/site-packages/*" -exec wc -l {} +` = **65 543 LOC** (NOT 77 243 as report claims at line 42 and line 133).
> - Including/excluding generated and l10n changes the picture dramatically: l10n alone (`app_localizations_en.dart` + `app_localizations_sv.dart`) is **27 169 LOC**, dwarfing everything else. Hand-written, non-l10n, non-generated Dart: **~38 374 LOC across ~1256 files**.
> - The takeaway from CRIT-4 still holds (327k is wildly inflated; pre-analysis tooling has integrity failure), but the "real number" Pass 1 claimed (77 243) and the "real number" Pass 1B addendum claimed (63 612) are *both* wrong because neither documented its exclusion list. **The audit-integrity finding has now happened three reports deep, including the Pass-2 rewrite.** Adding a `wc-loc-with-exclusion-policy.sh` to `_pre-analysis/` and pinning the exclusion list as an artifact is now mandatory before any future run.

> [CRITIC] **CRIT-3 / line 114 — BaseViewModel adoption number refined again.** Pass 2 grep `extends BaseViewModel`: **15 hits** (13 viewmodels + `base_viewmodel.dart` + `viewmodels/CLAUDE.md`). 13 actual VMs, not the report's 14. `extends ChangeNotifier`: 76 file matches but ~15 of those are non-VM files (services, mixins, providers, state delegates, factories). **True ratio: ~13 BaseViewModel / ~61 ChangeNotifier-VMs ≈ 18% adoption.** Conclusion unchanged; numbers refined for the third time. The fact that this number keeps shifting between passes is itself a finding: **there is no single source of truth for "what counts as a viewmodel."** Add a `lib/viewmodels/_inventory.dart` or a CI-emitted JSON manifest.

> [CRITIC] **CRIT-6 / line 183 — displayName/avatarUrl call-site count is now confirmed at 25 unique sites.** Pass 2 re-grepped `currentUser\?\.(displayName|avatarUrl|photoURL)`: **25 unique lines across 12 files**. The report says 24; close enough. The extra one is `auth_service.dart:38` (`currentUserPhotoUrl` getter — legitimate inside auth_service). Of the 25, **14 are repository/service write paths** that stamp stale identity into Firestore (matches CRIT-6's high-impact subset). One additional pattern not flagged in the report: `social_profile_manager.dart:50` reads `_currentUser?.avatarUrl` for *display only* — the bug is shaped differently there (stale display rather than stale write), but it's still the wrong source.

> [CRITIC] **Pre-known fact / line 38 — ConsentPurpose is RESOLVED.** Re-verified: `notification_service.dart:16` imports `models/account/user_consent.dart`; `user_consent.dart` defines `enum ConsentPurpose`; line 649 uses `ConsentPurpose.pushNotifications` cleanly. The Codex CRITICAL is stale. Confirmation holds.

### New findings — blind spots the merged report missed

#### NEW-CRIT-7 — `ServiceLocator.get<PermissionService>()` is called 16 times in `social_menu_operations.dart` (and similar patterns elsewhere) instead of being cached as a field

**Evidence:**
- `lib/services/unified/operations/social_menu_operations.dart:46, 51, 167, 170, 201, 204, 271, 276, 322, 325, 347, 350, 379, 414, 437, 466` — sixteen calls to `ServiceLocator.get<PermissionService>()` in one file. None of these are inside loops, but they are inside hot per-method paths. Every call traverses GetIt's lookup hashmap.
- Pattern repeats in `lib/services/unified/unified_recipe_service.dart` (9 calls), `lib/services/unified/unified_menu_service.dart` (7 calls), `lib/services/unified/operations/realtime_recipe\realtime_watching_module.dart`, etc.
- **Total `ServiceLocator.get<` calls in `lib/`: 585** (Pass 2 grep). For a codebase of ~1265 hand-written Dart files, that's ~0.46 calls per file — but the distribution is heavy-tailed: 16 of those files have 5+ calls.
- `social_menu_operations.dart` has no fields, just static-style methods that re-resolve on every call. CLAUDE.md `services/CLAUDE.md` actually *prescribes* `ServiceLocator.get<XxxService>()` for cross-service deps, so the pattern is "documented as correct" even though it's a perf and testability smell.

**Severity:** HIGH (perf + testability — every test must pre-register PermissionService in TestServiceLocator before invoking these methods, instead of receiving it as a constructor arg).

**Why it matters:** The `services/CLAUDE.md` rule "Cross-service dependencies: `ServiceLocator.get<XxxService>()`, not constructor injection" is at odds with testability. Tests work today only because `TestServiceLocator.reset()` exists in the test infrastructure. Mocking a service in isolation requires re-registering it globally. This is the architectural reason every service test setUp is 10+ lines.

**Remediation:** Either (a) cache the looked-up service as a `late final` field at class top (1-line per class, ~16 lines saved per file like `social_menu_operations.dart`); or (b) revisit the `services/CLAUDE.md` rule and allow constructor injection for service-to-service deps as well. (a) is mechanical; (b) is an architectural decision. Effort: 1 day for (a) across the 16-file hot-set.

---

#### NEW-HIGH-16 — `FCMService` static StreamSubscriptions have no cancellation path documented

**Evidence:**
- `lib/services/notifications/fcm_service.dart:91-93` — three `static StreamSubscription` fields: `_tokenRefreshSubscription`, `_onMessageSubscription`, `_onMessageOpenedAppSubscription`.
- The class has no instance `dispose()` (since it's all-static). Subscriptions are stored in static fields and never cancelled in the visible code path.
- `services/CLAUDE.md` Rule: "Override `onDispose()` to cancel subscriptions and clear caches." FCMService cannot do this because it doesn't extend `BaseService`. CRIT-2 already flags the static-singleton anti-pattern; this finding extends it: **the leak is not theoretical — every hot reload accumulates a new set of static subscription pointers because the previous ones are overwritten without `cancel()`.**
- Compare to `lib/widgets/social/activity_pings_feed.dart` (Timer.periodic = 1, cancel = 3 — clean) and `lib/services/presence_service.dart` (Timer.periodic = 1, cancel = 10 — defensive). Both follow the cancel-on-dispose pattern. FCMService is the holdout.

**Severity:** HIGH (memory leak in dev builds + behavior-leak in production where re-init paths exist, e.g. consent grant after revoke).

**Remediation:** Folded into CRIT-2's BaseService refactor. Effort: included in CRIT-2's 1.5-day estimate.

---

#### NEW-HIGH-17 — Generated/non-generated Dart-file separation is not enforced; pre-analysis tooling repeatedly miscounts LOC

**Evidence:**
- Re-counted live: `find lib -name "*.dart" -not -path "*/site-packages/*"` → 1265 files / 65 543 LOC.
- Excluding `*.g.dart` and `lib/l10n/`: ~1256 files / ~38 374 LOC.
- The 5 `*.g.dart` files in `lib/` are: not enumerated in any of the three Pass-1 reports nor in this Pass-2 rewrite's CRIT-4. This is the second-order audit-integrity bug.
- `*.freezed.dart`: zero. The codebase doesn't use freezed (worth noting for serialization framing in HIGH-3 — `SerializationUtils` is Butlery's home-grown alternative).

**Severity:** HIGH (every "LOC per finding" or "complexity per LOC" judgment in synthesis report inherits whichever flavor of LOC was used in upstream prompt; cross-prompt synthesis math is unreliable).

**Remediation:** Add `_pre-analysis/loc-count.json` artifact emitted by a script with explicit exclusion list: `site-packages/`, `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, optionally `l10n/`. Lock the exclusion policy in `docs/analysis/methodology.md`. Effort: 30 min once, saves N hours of cross-prompt confusion forever.

---

#### NEW-MED-18 — `services/CLAUDE.md` rule on `ServiceLocator.get` for cross-service deps conflicts with testability and is the root cause of NEW-CRIT-7

**Evidence:**
- `lib/services/CLAUDE.md` (read live during Pass 2): *"Cross-service dependencies: `ServiceLocator.get<XxxService>()`, not constructor injection (constructor injection is only in DI modules)."*
- Result: every service-to-service hot path resolves through GetIt at call time. NEW-CRIT-7 quantifies the runtime cost; the testability cost is that every service test depends on a globally-registered mock rather than a locally-injected one.

**Severity:** MEDIUM (architectural rule; not a bug per se, but the rule itself locks in the perf cost of NEW-CRIT-7 and the test-setup verbosity).

**Remediation:** Discussion needed with the user. Two options:
- (a) Keep the rule, add a `late final XxxService _xxx = ServiceLocator.get<XxxService>();` convention to amortize the lookup cost (zero perf cost, two extra lines per dep).
- (b) Allow constructor injection for service-to-service deps. Aligns with how repositories are wired. Bigger refactor (every `ServiceLocator.get` call site needs DI module changes), but architecturally cleaner.

---

#### NEW-MED-19 — Tests under `test/unit/services/` are healthy on the "mock dependencies, not subject" axis (sampled 5)

**Evidence:**
- `test/unit/services/parsing/tiers/llm_tier_test.dart` — `MockLlmService implements LlmService`; `LlmTier` is the SUT, instantiated for real. Clean.
- `test/unit/services/auth_service_test.dart` — `mockAuthRepository`, `mockAnalyticsService`; `AuthService(authRepository: mockAuthRepository, analyticsService: mockAnalyticsService)` constructed for real. Clean.
- `test/unit/services/menu_service_test.dart` — `MenuService(lexiconProvider: const CodeLexiconProvider())` real, `RecipeFactory.build(...)` for fixtures. Clean.

**Severity:** N/A — this is a positive note. No mocking-the-subject anti-pattern detected in the sample.

**Caveat:** Sample size is 5 of ~80 service tests. Should not be generalized. But the discipline appears intact for the core sample.

---

#### NEW-MED-20 — `late final` pattern under-used for ServiceLocator-cached deps

**Evidence:** Counter-pattern to NEW-CRIT-7. Files like `lib/services/permission_service.dart`, `lib/services/auth_service.dart`, and `lib/services/user_service.dart` use constructor injection cleanly. `social_menu_operations.dart` and the `unified/operations/*` cluster do not. Inconsistent within the same layer.

**Remediation:** Adopt `late final XxxService _xxx = ServiceLocator.get<XxxService>();` in service classes that have ≥3 calls to the same `get<T>()`. Effort: 1 day mechanical sweep.

---

#### NEW-MED-21 — `notification_service.dart` reads `ConsentPurpose.pushNotifications` once but doesn't cache the consent decision

**Evidence:** `lib/services/notifications/notification_service.dart:649` reads consent inside the consent-change handler. Each subsequent `sendNotification()` re-checks. Every notification triggers a Firestore read against the consent doc. With Firestore offline cache enabled this is cheap, but the cost-discipline rule in CLAUDE.md ("avoid unnecessary reads/writes") suggests caching the boolean for the session.

**Severity:** MEDIUM (cost — measurable Firebase reads on the messaging hot path; not perf-critical).

**Remediation:** Cache `_pushConsentGranted: bool?` in `NotificationService`; invalidate on `_onConsentChanged`. Effort: 1 hour.

---

#### NEW-LOW-8 — `unawaited(...)` used 25 times across 17 files — discipline is good

**Evidence:** Pass 2 grep `unawaited(` returns 25 occurrences. Confirms the codebase is intentional about fire-and-forget futures. No bare-future smell at scale.

**Severity:** N/A (positive note).

---

#### NEW-LOW-9 — `setState((){...})` in widgets: 100+ sites; Listener add/remove ratios are clean in the sample

**Evidence:** Sampled 8 widgets with `addListener(`: every one had matching `removeListener(` count (1:1 to 2:2). No leak smells in the listener-pairing layer.

**Severity:** N/A (positive note).

### Strategic opportunities (additional)

The merged report has 24 "What's missing" entries. Pass 2 adds:

#### M-25 — Single source of truth for "what is a viewmodel"

The fact that BaseViewModel-adoption % shifts between 21%, 18%, and 17% across the three passes proves no agreed denominator exists. Add a `lib/viewmodels/_inventory.json` (or a code-gen step) listing each VM and its base class. Lock CI to the inventory. Eliminates the ambiguity in CRIT-3 metrics permanently.

#### M-26 — Audit of `ServiceLocator.get<T>` usage, by call-site density

`grep -c "ServiceLocator.get<"` per file would identify the hot files. Files with >5 lookups are candidates for the `late final` cache pattern (NEW-CRIT-7). Output this as `_pre-analysis/service-locator-density.txt` for future runs.

#### M-27 — Pinned LOC-counter artifact in `_pre-analysis/`

After three reports got the LOC wrong in different ways, the answer is to commit the canonical counting script and its output artifact. `find lib -name "*.dart" -not -path "*/site-packages/*" -not -name "*.g.dart" -not -name "*.freezed.dart" -not -path "*/l10n/*" -exec wc -l {} +` with results pinned at `_pre-analysis/loc-baseline.txt`. Future runs verify against it.

#### M-28 — `lib/core/observers/` is undocumented but live

Pass-2 noted `consent_aware_analytics_observer.dart`, `interaction_route_observer.dart`, etc. exist but no CLAUDE.md describes them. Add a short `lib/core/observers/CLAUDE.md` listing each observer's purpose and lifecycle (when it's installed in `main.dart`, what events it emits, what disposes it).

#### M-29 — Static-field linter

Custom `analyzer` rule "no mutable static fields outside `lib/core/constants/`" would prevent the next FCMService-shaped service from being written. Same idea as CRIT-5's broader architecture-test, but cheaper to add (a custom_lint plugin rule).

#### M-30 — Generated-file inventory in `ACCEPTED_LARGE_FILES.md`

5 `*.g.dart` files exist. Each should be listed (or the doc should explicitly say "generated files excluded from the 500-line rule"). Currently neither convention is documented.

### Plain-language summary check

The merged report does not contain a "What this means in plain language" section. CLAUDE.md `workflow-discipline.md` requires this for plans, not for analysis reports — so technically not a violation. **Adding one anyway** because the audience for synthesis includes the user (solo founder), who reads Swedish natively but may skim the 700-line technical report:

#### What this means in plain language

- The app's "rulebook" (architecture rules) is good, but the rules aren't enforced automatically. Many parts of the app don't follow them.
- The biggest immediate worry: **the safety lock for talking to outside services** (Algolia search, OCR, recipe websites) is **wired up but turned off**. If someone on a hostile wifi network fakes one of these services, the app would talk to them instead. Fix: paste the real "fingerprints" into one config file. 1-hour job once you have the fingerprints.
- The second-biggest worry: **when a friend shares a recipe or comments**, the app saves their *old* name and avatar to the database (read from the wrong place). After they change their name, every old comment they made still shows the old name forever. 25 places in the code do this; ~14 of them write to the database (the dangerous half).
- A third worry: **one notification class is built like a global variable** instead of a normal object. Hard to test, leaks memory on hot reload, and is the #1 risk area for the "consent revoked but still gets notifications" bug class.
- The codebase has lots of helpful tools built (one-stop loading-state, error-formatting, retry-with-backoff, log-cleaner) — but the team forgot to **use them in many places**. Most viewmodels copy-paste boilerplate instead of using the shared base class.
- A 29 MB Python folder is sitting in your `lib/` directory by accident (a tool wrote it there). It doesn't ship to users but it confuses the analysis tools and inflated all the numbers in the previous reports by 4×. Delete it: `rm -rf lib/site-packages/`. 30 seconds.
- Risk if nothing is fixed: slow accumulation of inconsistent code; hard-to-diagnose bugs around stale display names, notification consent, and retried-too-many-times network calls. Nothing is on fire today.
- Easiest high-value fix: **broaden the architecture test** (one PR, one afternoon). It's the lock that prevents every other rule above from being broken silently in the future.

---

## Pass 2 verdict

APPROVED-WITH-CORRECTIONS
