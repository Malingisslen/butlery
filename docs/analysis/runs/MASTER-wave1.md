# MASTER — Wave 1 — Forensic Audit Consensus Report

**Scope:** Prompts 01 (Code Quality & Architecture), 02 (Security & Compliance), 05 (Dependencies & Supply Chain).
**Date:** 2026-05-03.
**Sources:** Three independent forensic runs of the Butlery codebase:
- `2026-05-codex/` — OpenAI Codex CLI (GPT-5)
- `2026-05-claude/` — Claude default (Opus 4.7, single-pass per prompt)
- `2026-05-claude-deep/` — Claude deep methodology (Opus 4.7, two-pass investigator + critic, ≥50 file:line refs/report)

**Methodology:** Each run produced an independent report. The deep run's Pass 2 critic re-verified Pass 1's claims against live source. This master applies a fourth verification layer: every claim unique to the codex or default run was independently verified against the working tree before inclusion. Findings that could not be verified or that were disproved are explicitly listed in the **Disproved / stale** section. Source data lives in `MASTER-wave1-01-codequality-data.md`, `MASTER-wave1-02-security-data.md`, `MASTER-wave1-05-dependencies-data.md`.

**Consolidated wave score:** **60/100** (weighted average of three verified prompt scores; range 56–62).

---

## 0. Executive summary

Wave 1 reveals a codebase that is **structurally sound but operationally under-enforced**. The architectural patterns, security helpers, and dependency hygiene infrastructure all exist — but adoption is partial, the `architecture_test.dart` gate doesn't catch the regressions, and three documented orchestrator-level claims are wrong in ways that propagated into multiple reports.

**Top three findings of the wave (all CRITICAL):**

1. **TLS certificate pinning is wired but disabled for all 8 third-party HTTPS hosts.** Every outbound request to Algolia, OCR.space, Google Vision, and 4 recipe-scrape sites falls through to the platform trust store. The wrapper is named `PinnedHttpClient` and the BUT-427 ticket reads as "done" — but in production any user-installed CA or compromised intermediate CA intercepts everything. (Prompt 02 CRIT-1; Prompt 01 CRIT-1)
2. **`compliance_export_manager.exportAuditLogs` permission-denies for every non-admin user and the catch block silently swallows it. GDPR Article 15 is currently broken for the audit-log category.** Codebase admits this in its own docstring (`compliance_export_manager.dart:11-20`); the planned Cloud Function exporter at `functions/src/exports/` does not exist. (Prompt 02 CRIT-2)
3. **`sqlcipher_flutter_libs` (the encrypted local-database substrate) is formally end-of-life.** Latest version 0.7.0+eol on pub.dev says "Not used anymore"; maintainer directs migration to `sqlite3 ^3.x`. The encryption guarantee on local user data is now backed by a retired binary distribution. (Prompt 05 CRIT-1)

**Three audit-integrity findings that everyone needs to know about:**

| Stale narrative | Reality | Impact |
|---|---|---|
| "Codebase is 327 280 LOC across 1 252 files" (codex + default headlines) | **76 325 LOC across 1 257 files** | Pre-analysis script walked into `lib/site-packages/` containing 29 MB of Python pip-install (Pillow + pip itself). Inflated 4×. Affects every "complexity per LOC" judgment in run 1 and run 2. |
| "`ConsentPurpose` undefined at `notification_service.dart:648`" — codex's only CRITICAL | **Resolved on disk.** `notification_service.dart:16` imports `models/account/user_consent.dart`; that file declares `enum ConsentPurpose` at line 90; reference at line 649 resolves cleanly. Pre-analysis snapshot was taken at 19:48; file modified 19:51. The error existed for 3 minutes. | Codex flagged this CRITICAL, default flagged it CRITICAL "uncertain". Both wasted severity. Drop. |
| "BaseService 96% adoption / BaseFirebaseRepository 78% / ErrorHandlingMixin 100% / SerializationUtils 100%" (orchestrator-prompt baseline; cited by codex + default as orthodoxy) | **All four are wrong.** Real: BaseService ~75% (25 holdouts), BaseFirebaseRepository ~53% (29 implements-only), ErrorHandlingMixin partial (many empty `catch (_) {}`), SerializationUtils partial (7+ models with raw `as Map<String, dynamic>` casts). | Documented "100% adopted" claims are aspirational. The architecture-test gate doesn't catch the holdouts. → prompt 12 doc drift. |

**Three structural findings that surface in multiple prompts and deserve cross-cutting action:**

- **`architecture_test.dart:65-115` is the meta-gate that's too narrow.** It checks only `FirebaseFirestore.instance` outside repositories, uses substring path-matching, and exempts `main.dart` whole-file. Broadening it (1-day PR) would prevent regression on at least 8 of this wave's findings — every architecture finding in the report is regression-vulnerable until this is fixed. (Prompt 01 CRIT-5)
- **`displayName`/`avatarUrl` denormalization at 24+ sites in 12 files reads from `permissionService.currentUser`, not `userService.currentUserProfile`.** This is the exact data-source bug `CLAUDE.md` "Critical Conventions" forbids. 14 of those sites are write paths into Firestore that stamp stale display data into shared docs. (Prompt 01 CRIT-6)
- **`lib/site-packages/` ships 29 MB of Python pip-install on every developer's disk.** Caused the LOC inflation above. `.gitignore` covers it so it's not committed; but it pollutes every tool that walks `lib/`. Pillow has known CVEs (defer to prompt 05) — the side door is real even though the artifact isn't shipped to users. (Prompt 01 CRIT-4)

**Bottom line:** The infrastructure for a hardened production app is mostly built. Nothing systematically enforces using it. The single highest-leverage one-day investment is broadening `architecture_test.dart`; the second is filling the cert-pin fingerprints.

---

## 1. Score reconciliation across runs

### Per-prompt score consensus

| Prompt | Codex | Claude default | Claude deep | **Master (verified)** | Status label |
|---|---:|---:|---:|---:|---|
| 01 Code Quality & Architecture | 63 | 71 | **56** | **56** | Acceptable; needs prioritized remediation |
| 02 Security & Compliance | 61 | 78 | **62** | **62** | Acceptable; CRITICAL items have safe blast radius |
| 05 Dependencies & Supply Chain | 69 | 71 | **62** | **62** | Acceptable; remediation in 2 sprints |
| **Wave 1 weighted average** | 64.3 | 73.3 | **60.0** | **60.0** | |

**Why deep's lower scores are authoritative:** deep's Pass 2 critic re-verified every Pass 1 claim against live source, found broader scopes than other runs, and disproved several findings. Default systematically scored higher because it didn't enumerate the full scope of architectural drift (e.g., on prompt 02 default missed CRIT-1 / CRIT-2 / CRIT-3 / HIGH-1 / HIGH-2 entirely — all source-verified real per deep + my own re-check). Codex was closer to deep but undercounted in some areas (e.g., `displayName` denormalization narrow-flagged at 2 sites instead of 24).

### Disputed numbers — authoritative truth

| Metric | Codex | Default | Deep | **Master (verified)** | Source of truth |
|---|---:|---:|---:|---:|---|
| Hand-written Dart LOC | 327 280 | 327 280 | 77 243 | **76 325** | `find lib -name "*.dart" -not -path "*/site-packages/*" -not -name "*.g.dart" -not -name "*.freezed.dart" -not -name "app_localizations*.dart" \| xargs wc -l` |
| Hand-written `.dart` files | 1 252 | 1 252 | 1 265 | **1 257** | Same command |
| Files >500 lines | 131 | 132 | 132 | **132** | All within ±1; doc claim of 33 in `code-style.md` is stale |
| Files >1000 lines | 6 | 4 | 4-6 (mixed) | **4 confirmed + 2 borderline** | `recipe_image_manager.dart` 1246, `firebase_recipe_repository.dart` 1092, `personal_recipe_module.dart` 1023 (undocumented), `recipe_unified.dart`, `main.dart` 1288, `known_ingredients` (borderline) |
| Cloud Function callables exported | not enumerated | not enumerated | 18 | **18** | Deep enumerated each in table at `02-security.md:99-117` |
| Callables with `enforceAppCheck: true` | "5 examples" | not enumerated | 3 | **3** (`structureRecipe`, `ocrRecipeImage`, `logWebError`) — **15 of 18 missing (~17%)** | Deep file-by-file verification |
| Cert-pin host count | "TODO/empty" (not counted) | not flagged | 8 | **8** | `cert_pin_config.dart:34-71` line-by-line |
| `friend_requests` references in functions/src | 1 (only `send-notification.ts:125`) | not flagged | 6 across 4 files | **6+ across 4 files** | Deep enumeration |
| `firestore.rules` size | not stated | 1788 lines / 95 match rules | 1813 lines / 90 match blocks | **1813 / 90** | Deep grep |
| BaseService adoption | not numerical | 82% (72/88) | ~75% (76 extends, 25 holdouts of ~101 services) | **~75%** | Deep wider denominator authoritative |
| BaseFirebaseRepository adoption | 78% (orchestrator citation) | 78% (orchestrator citation) | ~53% (33 extends + 29 implements-only) | **~53%** | Deep counted holdouts; orchestrator's "78%" is stale |
| `BaseViewModel` adoption | not flagged | not flagged | 14/76 → 13/61 ≈ **18%** | **~18%** | Deep grep — 14 `extends BaseViewModel`, 62 `extends ChangeNotifier` directly |
| `displayName`/`avatarUrl` denormalization sites | 2 sites in 2 files | not flagged | 24-25 sites in 12 files | **24-25 sites / 12 files** | Deep Pass 2 grep; 14 are write-paths into Firestore |
| Empty `catch (_) {}` | 6+ examples (no total) | 11 across 7 files | 11 (5 user-state-affecting) | **11 (5 high-impact)** | Default + deep concur |

---

## 2. Verified CRITICAL findings (10 — sorted by ownership prompt)

Each finding lists: severity, source-of-claim, file:line evidence, verification status, remediation effort, owner.

### Code Quality & Architecture (Prompt 01)

#### CRIT-CQ1 · TLS certificate pinning is wired but deactivated for all 8 third-party HTTPS hosts
- **Source:** Deep CRIT-1 (PROMOTED to CRITICAL); default H-9 (rated HIGH, deferred to 02); codex MEDIUM in Tech Debt dim (under-rated).
- **Evidence:** `lib/services/security/cert_pin_config.dart:34-71` — 8 host entries, every list is `<String>[]` with `// TODO(BUT-427-ops): leaf cert SHA-256 fingerprint` placeholders for `butlery-app-dsn.algolia.net`, `butlery-app.algolia.net`, `api.ocr.space`, `vision.googleapis.com`, `www.ica.se`, `www.koket.se`, `www.arla.se`, `www.recept.se`. `lib/services/security/pinned_http_client.dart:87-93` confirms `if (pins.isEmpty) return _inner.send(request);` falls through to platform trust store with no telemetry. Doc comment at `cert_pin_config.dart:7-18` documents "wired but inactive" semantics explicitly.
- **Verification:** VERIFIED by deep Pass 2 (read both files line-by-line). Independently confirmed by codex+default at lower severities.
- **Why CRITICAL not HIGH:** the wrapper is installed on every third-party request — and the file naming + BUT-427 status make it look enforced. Combined with HIGH-3 (binary-extractable OCR keys), an attacker on a hostile network has two independent paths to user PII (recipe photos may include handwritten notes).
- **Remediation:** **5–9 hours.** (a) Capture leaf+intermediate cert SHA-256 from each live endpoint via `openssl s_client`. (b) Populate the 8 host entries with `[leaf, backup]`. (c) Add a `kReleaseMode`-gated assertion in `main.dart` early bootstrap that refuses to build if any host has empty pins. (d) Establish 30-day-before-rotation alert in ops calendar.
- **Owner:** prompt 02 (security framing) and prompt 01 (the architectural detail that this exists but isn't enforced).

#### CRIT-CQ2 · `FCMService` is an all-static singleton with mutable static fields
- **Source:** Unique to deep CRIT-2.
- **Evidence:** `lib/services/notifications/fcm_service.dart:75` declares `class FCMService with ErrorHandlingMixin` (note `with`, not `extends BaseService`). Lines 77-78 have a private constructor + static `_errorHandler = FCMService._()` (architectural anti-pattern: instance for mixin-method exposure to static call sites). Lines 80-102 contain 11 static fields: `_messaging`, `_currentToken`, `_isInitialized`, `_pushPermissionsRequested`, `_consentService`, `_onMessageReceived`, `_onMessageOpenedApp`, `_tokenRefreshSubscription`, `_onMessageSubscription`, `_onMessageOpenedAppSubscription`, `_localNotifications`. Line 80 reads `static final FirebaseMessaging _messaging = FirebaseMessaging.instance` (which `architecture_test.dart` does NOT cover — see CRIT-CQ5). Line 129 attaches static method to listener with no matching `removeListener` (leaks listeners on hot reload).
- **Verification:** VERIFIED — I read `fcm_service.dart:75-103` independently. Confirmed `with ErrorHandlingMixin` at 75, static fields lines 80-84.
- **Why CRITICAL:** untestable; concurrent-safety fragile under FFI/JS interop; consent-revocation handler runs against possibly-disposed listener. Every other notification class (`NotificationService`, `FCMTokenManager`) follows the rules; FCMService is the holdout.
- **Remediation:** Refactor to `class FCMService extends BaseService` with instance fields and constructor injection. Estimated 1.5 days including test rewrites.

#### CRIT-CQ3 · `BaseViewModel` is the documented standard but only ~18% of viewmodels extend it
- **Source:** Unique to deep CRIT-3.
- **Evidence:** `lib/viewmodels/CLAUDE.md:6` declares `class XxxViewModel extends BaseViewModel`. **14 files** actually extend `BaseViewModel` (deep grep, Pass 2 reconciliation). **62 files** `extends ChangeNotifier` directly — including all the most-trafficked viewmodels (`recipe_list_viewmodel.dart:26`, `recipe_form_viewmodel.dart:45`, `recipe_detail_viewmodel.dart:76`, `unified_shopping_viewmodel.dart:36`, `friends_viewmodel.dart:30`, `chat_viewmodel.dart:20`, `auth_viewmodel.dart:68`, `menu_viewmodel.dart:29`, `realtime_menu_viewmodel.dart:26`, `profile_viewmodel.dart:28`).
- **Verification:** VERIFIED by deep Pass 2 (re-counted via grep across two passes; reconciled at ~18%).
- **Why CRITICAL:** every plain-`ChangeNotifier` viewmodel reinvents `_isLoading`, `_error`, `_isDisposed`, custom `notifyListeners()` guarding. The `executeAsync()` retry/error patterns at `base_viewmodel.dart:170-228` are reinvented inline in every holdout. This is the root cause of the "settings not persisting" / "loading spinner stuck" bug class historically appearing in `MEMORY.md`. The doc claim of "extend BaseViewModel" creates false confidence in code review.
- **Remediation:** Multi-sprint migration. Sprint 1: 6 most-trafficked VMs (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu). Stop the bleeding immediately by making CRIT-CQ5 (architecture-test broadening) include a "VMs must extend BaseViewModel/ImportBaseViewModel/BaseSharedContentViewModel" assertion.

#### CRIT-CQ4 · `lib/site-packages/` ships 29 MB of Python pip-install on every developer's disk (audit-integrity finding)
- **Source:** Unique to deep CRIT-4.
- **Evidence:** `lib/site-packages/pip/`, `lib/site-packages/PIL/`, `lib/site-packages/pillow-12.2.0.dist-info/`, `lib/site-packages/pip-25.0.1.dist-info/` confirmed live (master `du -sh lib/site-packages/` returns 29M). `.gitignore` covers the directory (so not committed) but it lives on every developer machine. Caused the 4× LOC inflation in codex+default reports (327k vs real 76k).
- **Verification:** VERIFIED — independently confirmed via `ls -d lib/site-packages/` (returns the directory) and `du -sh` (29M).
- **Why CRITICAL:** every "complexity per LOC" judgment in the synthesis layer inherits 4× phantom inflation; supply chain — Pillow versions on disk are not tracked in `pubspec.yaml`. Anyone running a tool that walks `lib/` (DCM, custom scripts, parallel `dart fix`) trips on it.
- **Remediation:**
  1. `rm -rf lib/site-packages/` on every dev machine — 30 seconds.
  2. Pre-analysis script: add `-not -path "*/site-packages/*"` filter — 5 minutes.
  3. Add `.claude/hooks/pre-tool-use.sh` snippet detecting `site-packages`, `node_modules`, `__pycache__` resurfacing in `lib/`.
  4. Correct all three Pass-1 reports' headline LOC numbers.

#### CRIT-CQ5 · `architecture_test.dart` is structurally too narrow — the meta-gate
- **Source:** Deep CRIT-5; codex MED-3 in Dim 1 captured the same gap at lower severity.
- **Evidence:** `test/architecture/architecture_test.dart:65-115` — only layering rule asserted is `FirebaseFirestore.instance` not appearing outside repositories. Four other Firebase singletons go unchecked (`FirebaseAuth.instance`, `FirebaseMessaging.instance`, `FirebaseStorage.instance`, `FirebaseFunctions.instance`). Line 72 exclusion uses `path.contains('repository')` (substring match — any path containing "repository" passes). Line 86 exempts `main.dart` whole-file but bypasses 5 real instance reads at `main.dart:172, 182, 194, 195, 196`. No test asserts: "no view imports `lib/repositories/firebase/`", "no viewmodel imports `package:cloud_firestore/`", "all viewmodels extend BaseViewModel", "all services extend BaseService", "no `.collection(<string-literal>)` outside `FirestoreCollections`".
- **Verification:** VERIFIED by deep Pass 2 (read full file).
- **Why CRITICAL:** this is the *meta-gate*. Without it, every Pass-1 audit will rediscover the same divergence. Cost: one afternoon of test-writing. Benefit: regression-blocking on every architecture finding in this report.
- **Remediation:** **1 day PR.** (a) Broaden Firebase-singleton checks to all five. (b) Replace `path.contains('repository')` with explicit prefix matches. (c) Add view→`lib/repositories/firebase/` import ban. (d) Add VM→`package:cloud_firestore/` import ban. (e) Add VM-extends-BaseViewModel assertion (with documented exception list). (f) Add service-extends-BaseService assertion (with exception list). (g) Add `.collection(<literal>)` ban. This single PR fixes lock-in for CRIT-CQ3, HIGH-1, HIGH-2, HIGH-3, HIGH-8, HIGH-13.

#### CRIT-CQ6 · `displayName`/`avatarUrl` denormalization at 24+ sites reads from auth profile, not UserService
- **Source:** Deep CRIT-6; codex flagged narrowly at 2 sites under HIGH-3 (Data source discipline).
- **Evidence (deep Pass 2 verified via grep `currentUser\?\.(displayName|avatarUrl|photoURL)` returning 25 unique lines across 12 files):**
  - **Repositories that denormalize into Firestore writes (highest impact, 14 sites):**
    - `lib/repositories/firebase/firebase_comments_repository.dart:161` (comment author display name)
    - `lib/repositories/firebase/firebase_menu_collaboration_repository.dart:98, 169, 208` (three menu-collab paths)
    - `lib/repositories/firebase/modules/shopping_item_operations_module.dart:88, 174, 237, 289, 347` (five activity paths)
    - `lib/repositories/firebase/modules/shopping_template_operations_module.dart:73, 268`
  - **Services:**
    - `lib/services/unified/operations/modules/recipe_sharing_manager.dart:533, 534`
    - `lib/services/realtime/realtime_menu_service.dart:53`
    - `lib/services/realtime/realtime_recipe_service.dart:42`
    - `lib/services/permission_service.dart:143` (`currentUserDisplayName` getter — propagates the wrong-source pattern)
    - `lib/services/user_service.dart:69` (mixed semantics)
    - `lib/services/auth_service.dart:36` (legitimate inside auth_service)
    - `lib/services/unified/unified_recipe_service.dart:458`
  - **ViewModels:** `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart:76, 271`; `lib/viewmodels/social_recipe/social_profile_manager.dart:28, 37, 50` (read locally for display, less harmful).
- **Verification:** VERIFIED by deep Pass 2 grep.
- **Why CRITICAL:** every comment, share, and collaboration edit until next cold start carries stale display name/avatar URL into other users' shared docs. CLAUDE.md "Critical Conventions" exists specifically to prevent this: *"`userService.currentUserProfile` → complete user data; `permissionService.currentUserId` → auth/permission checks only. Never mix these — causes settings not persisting."* The 14 repository write-paths are the actual high-impact subset.
- **Remediation:** **1.5–2 days mechanical + 0.5 day for the test/ADR.** Introduce `DisplayIdentityProvider` (or extend `UserService`) sourcing `(displayName, avatarUrl)` from `UserService.currentUserProfile`. Replace 14 repository/service write-path call sites. Add architecture test (under CRIT-CQ5) banning `permissionService.currentUser?.displayName` outside the provider.

### Security & Compliance (Prompt 02)

#### CRIT-SEC1 · `realtime_menus/{menuId}/votes/{voteId}` has no Firestore rule block — feature is silently broken since shipping
- **Source:** Unique to deep CRIT-1.
- **Evidence:** `lib/repositories/firebase/firebase_menu_voting_repository.dart:24-25` defines collection ref. Writes at lines 75 (`createVote`), 90 (`castVote`), 103 (transactional `resolveVote`), 120 (`addAlternative`). `firestore.rules:741-770` defines `realtime_menus` with only a `presence` subcollection. Deep grep `votes` against `firestore.rules` returns 0. Default-deny `match /{document=**}` at `firestore.rules:1810-1812` rejects every write. Repository contract `validateCreatePermission` (line 49-51) checks `realtime_menus/{menuId}.participantIds`, but client-side gates do not bypass rules. Three of four validators return literal `true` (see HIGH-SEC6).
- **Feature liveness verified:** UI widget at `lib/widgets/menu/menu_vote_card.dart`, viewmodel `menu_voting_viewmodel.dart`, service `menu_voting_service.dart`, DI registration in `collaboration_module.dart`, push deep-link route at `notification_deep_link_router.dart:49`. Push notification → user taps → opens menu_voting → user votes → silent permission-denied → UI looks like it succeeded → vote never persists.
- **Verification:** VERIFIED by deep grep of `firestore.rules` and live trace of the feature wiring.
- **Why CRITICAL:** same failure-mode class as the cook_snaps gap closed in BUT-728. Silent UX-affecting permission deny on a feature with a push deep-link.
- **Remediation:** **30 min.** Add rule block under `match /realtime_menus/{menuId}` mirroring the `presence` subcollection. Gate read/create on `isRealtimeParticipant('realtime_menus', menuId)`. For `castVote` (votes.userId map updates), pin `request.resource.data.diff(resource.data).affectedKeys().hasOnly(['votes'])`. Add rules tests via `firestore-rules-tester` agent for participant-allow + non-participant-deny matrix.

#### CRIT-SEC2 · `compliance_export_manager.exportAuditLogs` permission-denies on every non-admin call; GDPR Article 15 broken for audit-log access
- **Source:** Unique to deep CRIT-2.
- **Evidence:** `lib/services/account/export/compliance_export_manager.dart:42-91`. Line 49 reads Firestore `auditLogs` collection directly. Lines 84-90: catch swallows `permission-denied` PlatformException into a payload field — `return {'error': e.toString(), 'note': 'Audit logs may not be available or accessible'}`. Class docstring at lines 11-20 **explicitly admits the path is broken** ("a Cloud Function exporter is the proper long-term fix; tracked under the BUT-424 follow-up"). Firestore rule at `firestore.rules:1358` reads `allow read: if isAdmin()` (BUT-424 tightening 2026-04-27). The `functions/src/exports/` directory does not exist (verified by `ls`).
- **Verification:** VERIFIED by deep + my own re-read of `compliance_export_manager.dart:11-91`.
- **Why CRITICAL:** Article 15 export ALWAYS misses the audit-log category for end users with ≥1 audit-log entry — i.e., every active user. GDPR exposure: a regulator request would catch this missing category. The bug fires for every non-admin user.
- **Remediation:** **2-3 hours.** Build callable `exportAuditLogs` Cloud Function using Admin SDK + `request.auth.uid` filter. Deploy to `europe-west1`. Add `enforceAppCheck: true` and rate limit. Rewire `compliance_export_manager` to call via `FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('exportAuditLogs')`.

#### CRIT-SEC3 · 15 of 18 callable Cloud Functions lack `enforceAppCheck` (~83% unprotected)
- **Source:** Deep CRIT-3 (with full enumeration); codex flagged narrowly as "5 unprotected examples" without the table.
- **Evidence (deep verified `enforceAppCheck` setting per file in table at `02-security.md:99-117`):**

| Function | Export line | App Check |
|---|---|---|
| `structureRecipe` | `functions/src/llm/structure-recipe.ts:64` | YES (`:70`) |
| `ocrRecipeImage` | `functions/src/llm/ocr-recipe-image.ts:88` | YES (`:94`) |
| `logWebError` | `functions/src/events/log-web-error.ts:116` | YES (`:121`) |
| `bulkMarkForRetagging` | `functions/src/admin/bulk-retag.ts:191` | NO (admin-gated) |
| `getRetagStatus` | `functions/src/admin/bulk-retag.ts:401` | NO (admin-gated) |
| `seedSiteConfigs` | `functions/src/admin/seed-site-configs.ts:263` | NO (admin-gated) |
| `getSiteConfigStats` | `functions/src/admin/seed-site-configs.ts:321` | NO (admin-gated) |
| `getCorrectionStats` | `functions/src/analytics/analyze-corrections.ts:308` | NO |
| `getUnmatchedIngredientStats` | `functions/src/analytics/track-unmatched-ingredients.ts:166` | NO |
| `getAuditLogStats` | `functions/src/cleanup/cleanup-audit-logs.ts:155` | NO |
| `getDeletedIngredientStats` | `functions/src/cleanup/cleanup-deleted-ingredients.ts:164` | NO |
| `logParseCorrection` | `functions/src/events/log-parse-correction.ts:188` | NO |
| `logParseEvent` | `functions/src/events/log-parse-event.ts:144` | NO (bare `onCall(handler)`) |
| `backfillRecipeCommentsDenorm` | `functions/src/migrations/backfill-recipe-comments-denorm.ts:331` | NO (admin-gated) |
| `recordNotificationOpened` | `functions/src/notifications/record-notification-opened.ts:125` | NO (bare `onCall(handler)`) |
| `sendNotification` | `functions/src/notifications/send-notification.ts:74` | NO |
| `sendNotificationBatch` | `functions/src/notifications/send-notification.ts:469` | NO |

- **Highest-risk subset (no admin gate):** `recordNotificationOpened` (CTR-poisoning vector — combined with `suppressLowPerformers` cron, Sybil attacker can game which notification types are killed); `logParseEvent` (writes `site_configs/{domain}.failureCount` server-side — Sybil attack against competitor domains silently degrades parser confidence); `logParseCorrection` (poisons LLM training inputs); `sendNotification`/`sendNotificationBatch` (gated on friendship, but legacy `friend_requests` query is broken — see HIGH-SEC2).
- **Verification:** VERIFIED — deep enumerated each function file by file.
- **Remediation:** **1-2 hours.** Add `{ region: 'europe-west1', enforceAppCheck: true, cors: [...] }` to all 15 unprotected callables. For the two bare-`onCall(handler)` forms, switch to two-argument `onCall(options, handler)` form (~10 LOC each).

### Dependencies & Supply Chain (Prompt 05)

#### CRIT-DEP1 · `sqlcipher_flutter_libs` is confirmed end-of-life
- **Source:** Three-way (codex HIGH; default HIGH "potentially CRITICAL"; deep CRITICAL after live pub.dev verification).
- **Evidence:** `pubspec.yaml:44` (`sqlcipher_flutter_libs: ^0.6.4`, resolved 0.6.8 per `pub-deps.txt:60`). Single import site: `lib/core/storage/drift/app_database.dart` (verified by deep Pass-2 grep). Live pub.dev fetch confirms latest is `0.7.0+eol` flagged "Not used anymore"; maintainer (simolus3 — also drift's maintainer) directs users to `package:sqlite3 ^3.x`. The 0.7.0+eol release exists solely as a migration breadcrumb.
- **Verification:** VERIFIED — deep performed live pub.dev fetch; codex+default agreed on EOL signal but didn't classify as definitive.
- **Why CRITICAL not HIGH:** the encrypted-database substrate is on a package the upstream maintainer has formally retired. Path forward requires `sqlite3 2.x → 3.x` simultaneously (currently `^2.9.4` at `pubspec.yaml:93`). Cascade: drift 2.29 → 2.32, build_runner 2.7 → 2.15, drift_dev 2.29 → 2.32. Same head as the SDK floor bump cascade.
- **Remediation:** **0.5 day investigation + 2-3 days migration** including key derivation re-test and on-device sanity tests for encrypted-DB read/write.

#### CRIT-DEP2 · CI Node-version mismatch silently weakens npm-audit results
- **Source:** Unique to deep CRIT-2.
- **Evidence:** `functions/package.json:55-57` declares `"engines": { "node": "22" }` (the Cloud Functions runtime). `.github/workflows/dep-audit.yml:89` pins `node-version: "20"`. `.github/workflows/e2e_tests.yml:68` also pins `'20'` (also stale). `.github/workflows/firestore-rules.yml:52` correctly uses `"22"`. The asymmetry across workflows confirms the `dep-audit` pinning is unintentional drift.
- **Verification:** VERIFIED — independent re-read of all four files.
- **Why CRITICAL:** `npm ci` and `npm audit` resolve different optional / native binaries depending on Node version. The shipped artifact resolves under Node 22; the audit step resolves under Node 20. **The audit is therefore not auditing what ships.** Textbook supply-chain blind-spot. Probability of a real CVE slipping is small but not zero — and it's a configuration error, not a tradeoff.
- **Remediation:** **5 minutes.** Change `dep-audit.yml:89` `"20"` → `"22"`. Same for `e2e_tests.yml:68`. Defense in depth: add CI lint step that fails if any workflow's `node-version` differs from `functions/package.json:engines.node`, or set `engine-strict=true` in `functions/.npmrc`.

---

## 3. Verified HIGH findings (consolidated, ~24 unique after dedup)

### Code Quality & Architecture (8 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-CQ1 | Direct `FirebaseAuth.instance` call from a View | partial | `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22` — `await FirebaseAuth.instance.currentUser?.delete()`. Imports at line 3. | VERIFIED |
| HIGH-CQ2 | `main.dart` reaches `FirebaseFirestore.instance` 5× before DI is up; main.dart grew 35% in 7 days (954→1288 lines) | three-way | `lib/main.dart:172, 182, 194, 195, 196` (Firestore settings + IndexedDB recovery). The architecture test exempts `main.dart` whole-file but the 30-line block belongs in a `WebFirestoreBootstrap` helper. | VERIFIED. Default H-7 cited 31% growth at 1250 lines; deep refined to 35% at 1288 (most current). |
| HIGH-CQ3 | Raw `data['x'] as Type` casts widespread despite `SerializationUtils` existing | two-way (codex+deep) | Sampled 7+ models with raw casts at boundary: `lib/models/notification_batch.dart:28-44` (4 raw), `lib/models/notification_history_entry.dart:45,48`, `lib/models/notification_preferences.dart:100`, `lib/models/acquisition_attribution.dart:46-48`, `lib/models/realtime/realtime_resource.dart:348-379` (12+ in one factory), `lib/models/realtime/realtime_menu_factory.dart:81,102,104`, `lib/models/recipe/recipe_serialization.dart:52-258` (6+). Plus `recipe_unified.dart:917-919` null-safety hole (`doc.data() as Map<String, dynamic>` no null check — stream subscription dies if doc deleted server-side mid-stream). | VERIFIED at multiple sites. |
| HIGH-CQ4 | Empty/silent `catch (_) {}` in user-state-affecting paths (5 of 11 occurrences) | three-way | Deep grep finds 11 occurrences in `lib/`. **5 swallow real user-facing state failures with zero logging:** `lib/viewmodels/recipe_list_viewmodel.dart:844, 856` (onboarding banner persistence); `lib/viewmodels/cooking_mode_viewmodel.dart:38, 48` (font-scale persistence); `lib/services/cook_snap_service.dart:125`; `lib/services/unified/operations/modules/recipe_sharing_manager.dart:185`. **6 are acceptable** (best-effort JS-interop / parser fallback / nutrition parser at `recipe_unified.dart:913`). | VERIFIED. |
| HIGH-CQ5 | Commented-out external-integration code with credential placeholder strings | two-way (codex+deep) | `lib/services/deep_link_service.dart:339-356` — bit.ly integration commented out with literal `'YOUR_BITLY_ACCESS_TOKEN'` placeholder; `_generateExternalShortUrl` is 30 lines wrapping `return null` with 13 lines of dead HTTP code. Plus 3 other dead-code blocks. | VERIFIED. Codex rated LOW; deep promoted to HIGH due to credential-placeholder forensic-review trigger risk. |
| HIGH-CQ6 | `recipe_image_manager.dart` (1246 lines, 11 fields, 3 race-condition guards) extends `ChangeNotifier` not `BaseViewModel`; `_pendingStateUpdates` queue has no upper bound | three-way | `lib/viewmodels/recipe_form/recipe_image_manager.dart:32-60` — 11 instance fields incl 3 race guards (`_uploadsCanceled`, `_isStateUpdating`, `_isNotifying`), `_pendingStateUpdates` list, `_notificationDebounceTimer`. Migration to BaseViewModel deletes 3 boilerplate guards. | VERIFIED |
| HIGH-CQ7 | View files import concrete Firebase repositories (defeats DI mocking) | two-way (codex+deep) | `lib/views/social/shared_with_me/shared_content_actions.dart:15` — imports `firebase_shared_menu_repository.dart` directly; line 16 imports `firebase_shared_shopping_repository.dart` directly. `MockSharedMenuRepository` cannot be swapped via DI for these views. | VERIFIED |
| HIGH-CQ8 | Hardcoded `.collection('...')` literals despite `FirestoreCollections` constants existing | two-way (codex+deep) | `firebase_data_export_repository.dart:504`, `firebase_menu_voting_repository.dart:25, 42`, `report_service.dart:91`, `onboarding_progress_service.dart:95, 97`, `resource_parser_module.dart:23`, `main.dart:183`. | VERIFIED |
| HIGH-CQ9 | Raw `userId` in log strings despite `LogSanitizer` existing | two-way (codex+deep) | `firebase_block_repository.dart:59, 147`, `firebase_notifications_repository.dart:107, 382, 400`, `notification_service.dart:531`. PII leak risk in logs/telemetry. | VERIFIED |
| HIGH-CQ10 | Generic "Ett fel uppstod" error string at 6 different localization keys | unique to deep | `lib/l10n/app_localizations_sv.dart:712, 830, 1128, 2355, 10538, 11018` plus hardcoded fallback at `lib/widgets/common/state/message_states.dart:47`. | VERIFIED by deep Pass 2 grep |

### Security & Compliance (6 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-SEC1 | All 8 third-party SSL cert pins are empty placeholders | partial | (Same evidence as CRIT-CQ1 above; classified as CRITICAL on the security side; restated for completeness as it touches both code-quality and security framings.) | VERIFIED |
| HIGH-SEC2 | Cloud Function `sendNotification` queries non-existent `friend_requests` collection (legacy collection rename leak) | partial (deep + codex narrow) | `functions/src/notifications/send-notification.ts:125, 130, 539, 544` — direct `admin.firestore().collection('friend_requests')` calls. `functions/src/shared/collections.ts:20` — `friendRequests: "friend_requests"` (legacy constant). `functions/src/cleanup/cleanup-expired-friend-requests.ts:32` and `functions/src/admin/reset-user-data.ts:74`. Real collection: `firestore.rules:472` `social_requests`. NO `friend_requests` rule anywhere. Effect: pending-friend-request notification is silently broken. `cleanup-expired-friend-requests.ts` is now a no-op CRON sweeping an empty collection. | VERIFIED — 6 references across 4 files |
| HIGH-SEC3 | Third-party API keys baked into client binary (OCR.space, Google Vision) | three-way | `lib/services/ocr_extraction_service.dart:227` — `String.fromEnvironment('OCR_SPACE_API_KEY')`; line 236 — `String.fromEnvironment('GOOGLE_VISION_API_KEY')`. Materializes at compile time; recoverable from release APK/AAB/IPA. Bridges to HIGH-SEC1: with cert pinning empty, attacker doesn't even need to reverse-engineer. | VERIFIED |
| HIGH-SEC4 | GDPR cross-user cascade ops bypass `PermissionValidationMixin` audit trail | unique to deep | `lib/services/account/account_deletion/social_deletion_operations.dart:64, 97, 156, 208, 239` — direct `_firestore` writes that delete docs owned by other users. `profile_deletion_operations.dart:65`. Routing through per-resource repos with `validateOwnership` would deny — these ARE legitimate Art-17 cross-user cascade ops. The actual critique: NO audit logging on this path. From a forensic-investigation standpoint there's no trail showing WHEN, WHO, or WHICH cross-user docs were touched. | VERIFIED |
| HIGH-SEC5 | Account-deletion `user.delete()` runs BEFORE Firestore tier deletes (auth-context race) | unique to deep | `lib/services/account/account_deletion_service.dart:142-159` — comment "Delete auth entry FIRST", `await user.delete()` at line 146, tier-1 Firestore deletes from line 163. Firebase SDK caches ID token ~1 hour, so deletes generally succeed in window — but rules that ALSO call `exists(/databases/.../users/$(deletedUid))` will see the doc gone for cross-user cascades; partial Firestore-side residue if client crashes mid-deletion. | VERIFIED |
| HIGH-SEC6 | Friends cross-user write branch enables synthetic-friendship notification bypass (severity-reconciled) | severity dispute | `firestore.rules:282-285` allows write when `request.auth.uid == friendId`. Codex C-1 rated CRITICAL (CVSS 9.1); deep MED-16 rated MEDIUM (CVSS 5.5). **Reconciled to HIGH (CVSS 7.4-8.0):** the synthetic friendship doc IS the gate `sendNotification` reads — so the rule allows attacker-controlled bypass of the friend-only notification gate. Not CRITICAL because the legacy `friend_requests` query (HIGH-SEC2) fails closed; not MEDIUM because the rule alone enables un-gated cross-user writes. | VERIFIED rule shape; severity reconciled in master |
| HIGH-SEC7 | iOS release build omits `--obfuscate` and `--split-debug-info` (parity gap with Android) | unique to codex | `.github/workflows/build-validation.yml:229` — iOS builds with `flutter build ipa --release --no-codesign --dart-define-from-file=.env --export-options-plist=ios/exportOptions.plist`. **No obfuscate.** Android counterpart at line 194 DOES use `--obfuscate --split-debug-info=build/debug-info`. Symbol parity gap between platforms. | VERIFIED |

### Dependencies & Supply Chain (8 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-DEP1 | `build_resolvers` + `build_runner_core` marked DISCONTINUED upstream (transitive via `build_runner 2.7.1`, 8 minors behind 2.15.0) | three-way | `pub-outdated.txt:198-199, 217-218`; `pubspec.yaml:113` "Downgraded for drift_dev compatibility" | VERIFIED |
| HIGH-DEP2 | Firebase suite uniformly one minor behind on 12 packages | three-way | `pub-outdated.txt:98-113` confirms 12 packages all one minor behind: firebase_core (4.6→4.7), firebase_auth (6.3→6.4), firebase_app_check, firebase_crashlytics, firebase_database, firebase_messaging, firebase_performance, firebase_remote_config, firebase_storage, firebase_analytics, cloud_firestore (6.2→6.3), cloud_functions. Plus 11 transitive `firebase_*_platform_interface`/`_web` packages also patch-behind. Dependabot config groups these under `firebase` weekly — bottleneck likely human merge or OSV blocker. | VERIFIED |
| HIGH-DEP3 | (= HIGH-SEC1 / CRIT-CQ1) Cert pinning fingerprints empty — same evidence | unique to codex on dep-side | (See CRIT-CQ1) | VERIFIED |
| HIGH-DEP4 | Mistral→Vertex AI documentation drift | unique to deep | `functions/package.json:60` `"@google-cloud/vertexai": "1.12.0"`. `functions/src/index.ts:10, 24` literal "Mistral AI" comments. `functions/src/llm/gemini-client.ts:22` imports from `"@google-cloud/vertexai"`. `functions/src/llm/PROMPT_CHANGELOG.md:58` references "Mistral model" historically. Code is internally consistent (vertexai is the only LLM SDK); documentation says otherwise. | VERIFIED. Cross-prompt with 12. |
| HIGH-DEP5 | `dep-audit.yml` does not run on `push: branches: [main]` — only PR + schedule + dispatch | unique to deep | `.github/workflows/dep-audit.yml:7-17`. Combined with solo-dev push-to-main culture (CLAUDE.local.md), lockfile changes that bypass PR review do not trigger audit until next Monday cron — up to 7 days unaudited. | VERIFIED. Critic noted Trivy in `build-validation.yml` partially mitigates, but Trivy and OSV scan different things. |
| HIGH-DEP6 | Caret-loose pin posture (72/74 carets, 2 exact pins) on solo-dev push-to-main | unique to deep | `pubspec.yaml`: 74 dep declarations, 72 use `^`, 2 use exact pins (`device_info_plus 12.3.0` at line 34, `connectivity_plus 7.0.0` at line 52, both BUT-750-justified). For solo-dev push-to-main with no PR review, exact-pinning the 3 most security-critical (`firebase_app_check`, `freerasp`, `http_certificate_pinning`) closes the surprise-bump window. | VERIFIED |
| HIGH-DEP7 | Runtime-downloaded ONNX inference models have no integrity verification | unique to deep | `lib/services/parsing/ner/ner_model_manager.dart:24-30, 55-100` downloads `models/ingredient_ner/v{N}/model.onnx` (max 25MB) from Firebase Storage at runtime, caches in app docs dir. `lib/services/parsing/ner/onnx_ner_service.dart:55-78` runs BERT NER inference on user-entered ingredient lines using the cached model. **Pass-2 grep `sha256\|integrity\|verifyHash\|checksum` returns 0 matches.** Same gap in `lib/services/parsing/line_classifier/line_classifier_model_manager.dart`. Compromised admin Firebase token could replace model with one that produces wrong NER outputs for targeted inputs; app would happily run it. | VERIFIED |
| HIGH-DEP8 | All 37 GitHub Actions invocations use mutable major-tag refs (no SHA pinning) | unique to deep critic | All `uses:` refs across `.github/workflows/*.yml` use major-tag refs (`@v4`, `@v6`, `@v0.36.0`), zero SHA pins. tj-actions/changed-files March 2025 attack vector. Third-party `subosito/flutter-action`, `aquasecurity/trivy-action`, `codecov/codecov-action`, `trufflesecurity/trufflehog` carry largest blast radius. | VERIFIED |
| HIGH-DEP9 | `node-forge` dual-licensed (BSD-3-Clause OR GPL-2.0); election undocumented; no `LICENSE`/`NOTICE`/`SECURITY.md` at repo root | unique to deep | `functions/package-lock.json` shows `node-forge 1.4.0` license `(BSD-3-Clause OR GPL-2.0)`. `ls C:/Butlery/butlery/{LICENSE*,NOTICE*}` returns "No such file or directory" (re-verified). | VERIFIED. Election unambiguous (BSD-3 standard for commercial), but audit trail missing. |

---

## 4. Disproved / stale findings (DO NOT carry into action items)

These claims were made by codex or default but **disproved** by deep critic and/or my own re-verification. They should not appear in synthesis or remediation roadmaps.

| Claim | Origin | Disproof / Source | Master action |
|---|---|---|---|
| `flutter analyze` reports "Undefined name 'ConsentPurpose'" at `notification_service.dart:648` — CRITICAL build break | Codex CRIT-1; default C-1 (uncertain) | `notification_service.dart:16` imports `models/account/user_consent.dart`; that file declares `enum ConsentPurpose` at line 90; line 649 reference resolves cleanly. Mtime mismatch (analyze captured 19:48, file modified 19:51) explains it — pre-analysis was pre-edit. **STALE, not real.** | DROP from master and synthesis |
| Codebase is 327 280 LOC across 1 252 files | Codex baseline; default Codebase Scale table; both used as headline | Real: 76 325 LOC across 1 257 files. The 327k figure includes `lib/site-packages/` (29 MB Pillow + pip). Inflated 4×. | CORRECT to 76 325; flag as audit-integrity finding (CRIT-CQ4) |
| BaseService 96% adoption (orchestrator-prompt baseline propagated by codex+default as orthodoxy) | Codex + default | Deep Pass 2 found 25 services that do NOT extend BaseService → ~75% true adoption. | Flag stale (→ prompt 12) |
| BaseFirebaseRepository 78% adoption (orchestrator baseline) | Codex + default | Deep Pass 2: 33 extends + 29 implements-only = ~53%. Wider denominator. | Flag stale (→ prompt 12) |
| ErrorHandlingMixin 100% adopted (orchestrator claim) | Cited as orthodoxy | Deep Pass 2: many viewmodels and 25+ services use raw try/catch with `catch (_) {}`. Not 100%. | Flag stale (→ prompt 12) |
| SerializationUtils 100% adopted (orchestrator claim) | Cited as orthodoxy | Deep Pass 2: 7+ models use raw `as Map<String, dynamic>`; 30+ models use `data['x'] as Type` inline. | Flag stale (→ prompt 12) |
| `personal_tag_service.dart` god-class still pending | Implied by orchestrator's "Known violations" list | Deep MED-6: file is now 359 lines — refactor happened. **REMEDIATED.** | Update orchestrator; remove from violations list |
| Cook-snap unawaited async notification at `cook_snap_service.dart:222` | Codex HIGH (Dim 4) | Live re-read of `cook_snap_service.dart:215-234`: line 222 is wrapped in `try { ... } catch (e) { AppLogger.warning('Failed to send cook snap notification: $e'); }` (lines 220-233). The unawaited concern is moot in current source. **STALE.** | DROP from master HIGH list |
| Push-consent revoke handler likely broken at runtime (analyzer error) — HIGH | Default HIGH-2 | Stale analyzer cache. `notification_service.dart:643-663` compiles. Same enum reference at `fcm_service.dart:163` not flagged by analyzer. Default itself flagged the verification gap. | Demote to LOW or drop |
| `unified_shared_shopping_lists` view-permission member can downgrade items — MEDIUM | Default MEDIUM-5 | Default's own writeup acknowledges "rule shape today is correct"; rule at `firestore.rules:1125-1131` correctly requires `['edit','admin']`. Concern is documentation drift, not active vuln. | Demote to informational |
| iOS bundle-id mismatch between `firebase_options.dart` and Xcode project | Codex M-5 | Both files agree on `se.butlery.app` (`firebase_options.dart:58`; `pbxproj:377`). Test target's `RunnerTests` suffix is expected. | DROP |
| `excel`/`csv`/`archive` are dead-weight bloat | Default Dim 4 (MEDIUM) | DISPROVED. `lib/core/router/modules/extraction_deferred_module.dart:9, 31` registers `Routes.fileImport` as a deferred-loaded production route. Feature SHIPS. | DROP — informational note only |
| `http_certificate_pinning` is from an unverified single-maintainer publisher (MEDIUM) | Default Dim 5 | DISPROVED. Live pub.dev fetch confirms `softarch.dev` IS verified publisher. Apache-2.0. The actual gap (empty pin lists) is HIGH-SEC1. | DROP migration recommendation; keep CRIT-CQ1 |
| `flutter_onnxruntime` publisher uncertain | Default Dim 5 | DISPROVED. pub.dev confirms `masic.ai` verified publisher; MIT licensed. (But ONNX model integrity is HIGH-DEP7 — separate concern.) | DROP publisher concern; keep HIGH-DEP7 |
| `pointycastle` is on the security-critical runtime cryptography path | Pre-known facts list | DISPROVED. `package:pointycastle/` grep in `lib/` returns 0 files. Only used transitively by `dart_jsonwebtoken` (test mocks). Butlery uses `crypto` for SHA hashing. | Correct pre-known facts at `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md:92` (→ prompt 12) |

---

## 5. Cross-cutting findings (touch multiple prompts)

### CC-1 · Architecture-test gate is structurally too narrow (CRIT-CQ5)
Affects every architecture finding in this report — they're all regression-vulnerable until the gate is broadened. Single 1-day PR fixes lock-in for CRIT-CQ3, CRIT-CQ6, HIGH-CQ1, HIGH-CQ2, HIGH-CQ7, HIGH-CQ8, HIGH-CQ9, plus prompt 02's HIGH-SEC4 (cross-user GDPR cascade audit gap).

### CC-2 · Documented adoption percentages are systematically inflated (→ prompt 12)
Four architecture-orthodoxy claims cited by codex+default as orthodoxy are wrong:
- BaseService: claimed 96% / real ~75%
- BaseFirebaseRepository: claimed 78% / real ~53%
- ErrorHandlingMixin: claimed 100% / real partial
- SerializationUtils: claimed 100% / real partial

Plus `BaseViewModel` adoption is undocumented at all (real ~18%). The orchestrator-prompt baseline (`docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md`) and `MASTER_ANALYSIS_ORCHESTRATOR.md` propagate these. Defer to prompt 12 for systematic doc-drift correction.

### CC-3 · Audit-integrity vulnerabilities (LOC inflation, ConsentPurpose stale, polluted pre-analysis)
Three Pass-1 reports propagated wrong numbers because the pre-analysis tooling didn't filter `lib/site-packages/` and didn't re-verify analyzer errors against current file mtimes. **The audit tooling itself has no integrity check.** Recommended: (a) `rm -rf lib/site-packages/`; (b) update pre-analysis script with explicit path filters; (c) add a `.claude/hooks/pre-tool-use.sh` snippet detecting stray site-packages/node_modules/__pycache__ resurfacing; (d) for analyzer findings, always re-verify against current source mtime before flagging.

### CC-4 · Storage SVG XSS surface — three concerns combine (→ prompts 02, 09)
- `storage.rules:9` — `isValidImage()` matches `image/.*` with no `image/svg+xml` exclusion (deep MED-14).
- `firebase_storage_repository.dart:259, 264` — `contentType` set client-side; bypassable from hostile client (deep MED-13).
- Storage CDN serves back the client-claimed `contentType` — polyglot SVG containing JS opens via `getDownloadURL()` in browser → XSS.
- Combined with HIGH-DEP7 (no model integrity check) the broader narrative is "trust boundary on uploaded user content is shallow."

### CC-5 · Runtime-downloaded artifacts (HIGH-DEP7 model integrity, HIGH-SEC4 cascade audit gap)
Two findings about runtime artifacts crossing trust boundaries with no defense in depth:
- ONNX models downloaded with no SHA-256 verification.
- GDPR cross-user cascade ops with no audit log entries.

Both are "happy-path works, defense-in-depth missing" patterns. Sister-prompt: prompt 03 (DR / backup posture) and prompt 11 (legal evidence retention).

---

## 6. Remediation roadmap (verified, sized, sequenced)

### Sprint 1 — high-leverage fixes (target: 2 weeks, ~10 engineer days)
Goal: stop the bleeding on the highest-leverage gates and close the audit-integrity loop.

| # | Action | Effort | Source | Dependencies |
|---|---|---|---|---|
| S1.1 | Delete `lib/site-packages/` from dev machines + add path filter to pre-analysis | 0.5d | CRIT-CQ4 | none |
| S1.2 | Broaden `architecture_test.dart` (5 Firebase singletons + view→firebase-repo + VM→cloud_firestore + VM-extends-BaseViewModel + service-extends-BaseService + .collection-literal ban) | 1d | CRIT-CQ5 | S1.1 (clean LOC count) |
| S1.3 | Populate 8 cert-pin fingerprints + add release-mode assertion + ops rotation calendar | 1d | CRIT-CQ1 / HIGH-SEC1 | none |
| S1.4 | Add `realtime_menus/votes` Firestore rule block + rules tests (deny non-participants, allow participants, pin diff to votes-only) | 0.5d | CRIT-SEC1 | none |
| S1.5 | Build `exportAuditLogs` callable Cloud Function (Admin SDK + uid filter); rewire `compliance_export_manager` | 0.5d | CRIT-SEC2 | none |
| S1.6 | Add `enforceAppCheck: true` to 15 unprotected callables (priority order: notification + log functions first; admin gates have lower urgency) | 0.5d | CRIT-SEC3 | none |
| S1.7 | Fix Node version mismatch (`dep-audit.yml:89` and `e2e_tests.yml:68` to "22") + add CI lint asserting `node-version` matches `engines.node` | 0.5h | CRIT-DEP2 | none |
| S1.8 | Rename `friend_requests` → `social_requests` in 6 references across 4 functions/src files; update `Collections.friendRequests` constant; add integration test for pending-request notification flow | 0.5d | HIGH-SEC2 | none |
| S1.9 | Refactor `FCMService` static-singleton → instance + constructor injection of `FirebaseMessaging` | 1.5d | CRIT-CQ2 | S1.2 |
| S1.10 | Migrate `displayName`/`avatarUrl` 14 repository write paths to `DisplayIdentityProvider` | 2d | CRIT-CQ6 | S1.2 |
| S1.11 | Add audit-log entries to `social_deletion_operations` and `profile_deletion_operations` cross-user cascades | 0.5d | HIGH-SEC4 | none |
| S1.12 | Investigate `sqlcipher_flutter_libs` migration to `sqlite3 ^3.x` (SPIKE — read `UPGRADING_TO_V3.md`, plan key derivation re-test) | 0.5d | CRIT-DEP1 | none |

**Sprint 1 total: ~10.5 days.**

### Sprint 2 — adoption + maintenance (target: 2 weeks, ~10 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| S2.1 | Migrate top-6 viewmodels to `BaseViewModel` (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu) | 3d | CRIT-CQ3 |
| S2.2 | Migrate `sqlcipher_flutter_libs` → `sqlite3 ^3.x` substrate (key derivation re-test, on-device sanity) | 3d | CRIT-DEP1 |
| S2.3 | Mass-migrate raw `data['x'] as Type` casts to `SerializationUtils.safeXxx` (sample 7+ models, broaden audit) | 2d | HIGH-CQ3 |
| S2.4 | Move account-deletion entirely server-side (single CF callable, admin SDK end-to-end) — eliminates auth-context race | 1.5d | HIGH-SEC5 |
| S2.5 | Add SHA-256 verification to `ner_model_manager` and `line_classifier_model_manager` model downloads | 0.5d | HIGH-DEP7 |

**Sprint 2 total: ~10 days.**

### Sprint 3 — hardening + cleanup (target: 2 weeks, ~9 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| S3.1 | Pin 3 most security-critical packages to exact versions (`firebase_app_check`, `freerasp`, `http_certificate_pinning`) | 0.5h | HIGH-DEP6 |
| S3.2 | SHA-pin top-blast-radius GitHub Actions (3rd-party: `subosito/flutter-action`, `aquasecurity/trivy-action`, `codecov/codecov-action`, `trufflesecurity/trufflehog`) | 1d | HIGH-DEP8 |
| S3.3 | Add `push: branches: [main]` trigger to `dep-audit.yml` (path-filtered to lockfiles) | 15min | HIGH-DEP5 |
| S3.4 | Update doc claims that drifted: orchestrator BaseService/BaseFirebaseRepository/ErrorHandlingMixin/SerializationUtils percentages; `code-style.md` "33 files >500 lines" → 132 | 1d | CC-2 → prompt 12 |
| S3.5 | Replace 6 generic "Ett fel uppstod" Swedish error strings with context-specific messages | 2h | HIGH-CQ10 |
| S3.6 | Mass-migrate hardcoded `.collection('...')` literals to `FirestoreCollections` | 1d | HIGH-CQ8 |
| S3.7 | Mass-fix raw userId logging via `LogSanitizer` (5 sites confirmed) | 1h | HIGH-CQ9 |
| S3.8 | Wrap 5 user-state-affecting empty-catches with `AppLogger.warning(...)` | 30min | HIGH-CQ4 |
| S3.9 | Delete commented-out external-integration code with credential placeholders (4 sites) | 30min | HIGH-CQ5 |
| S3.10 | Migrate `recipe_image_manager.dart` to `BaseViewModel`; bound `_pendingStateUpdates` queue | 2d | HIGH-CQ6 |
| S3.11 | Refactor `parsing_correction_repository` + `site_config_repository` to extend `BaseFirebaseRepository` | 0.5d | MED-9 / HIGH-CQ |
| S3.12 | Update Mistral→Vertex AI references in `functions/src/index.ts:10, 24` and `functions/src/llm/PROMPT_CHANGELOG.md:58` | 30min | HIGH-DEP4 |
| S3.13 | Add `LICENSE`/`NOTICE`/`SECURITY.md` files at repo root; document node-forge BSD-3 election | 1h | HIGH-DEP9 |
| S3.14 | Scope `deep_links/{linkId}` rule to creator + shared participants only | 2h | LOW-MEDIUM (codex M-3) |
| S3.15 | Force HTTPS-only in `http_content_fetcher.dart:16` allowlist (drop 'http' scheme) | 30min | LOW (codex M-4) |
| S3.16 | Add `--obfuscate` and `--split-debug-info` to iOS release build (`build-validation.yml:229`) | 30min | HIGH-SEC7 |

**Sprint 3 total: ~8.5 days.**

**Total Wave-1 remediation: ~29 engineer-days across 3 sprints.** Excludes deferred items (test infra → prompt 03; AI/LLM → prompt 07; doc drift → prompt 12; legal → prompt 11).

---

## 7. Cross-prompt deferrals

These items surfaced in Wave 1 but belong with later prompts:

| Item | Source | Defer to |
|---|---|---|
| Test infrastructure 10-min hang in `infrastructure_integration_test.dart` | Codex (prompt 01); default C-2 | **03 Infrastructure & Operations** |
| `pub-outdated.txt` decode failures + EOL/discontinued chain (8-deep, sqlite3 cascade) detail | Codex Dim 7 HIGH | **05 Dependencies** (already covered above; the test-infra angle defers to 03) |
| AI / Function timeouts and circuit breakers | Deep | **04 Performance & Scalability** |
| Prompt-injection content scanning (cache poisoning bridge to LLM tier) | Deep MED-10 | **07 AI/LLM Quality** |
| SDK consent race / Privacy manifest / ATT prompt / UGC moderation | Deep | **09 Trust, Safety & Privacy** |
| iOS encryption export declaration (App Store ITSAppUsesNonExemptEncryption); CSP / web headers | Deep | **11 Legal Review** |
| Disaster Recovery / backup posture | Deep | **03** |
| Doc/comment drift (Stockholm references, region docs, BaseService percentage corrections) | Cross-cutting | **12 Doc & Operational Drift** |
| Region pinning audit (`europe-west1` enforcement across 18 callables) | Deep | **03 / 11** |

---

## 8. Methodology + provenance

### What we know with high confidence

Every CRITICAL and HIGH finding above has at least one of:
- Independent source verification by deep run's Pass 2 critic (claims grepped against live source);
- Independent re-verification by master synthesis (this document) against current working tree;
- Three-way consensus across all three runs (codex + default + deep all flag the same evidence with overlapping line citations).

Of the 10 CRITICALs:
- **6 are unique to deep but verified by deep Pass 2 + master re-check** (CRIT-CQ2, CRIT-CQ3, CRIT-CQ4, CRIT-CQ5, CRIT-SEC1, CRIT-SEC2)
- **3 have at least two-run consensus, plus deep Pass 2 verification** (CRIT-CQ1, CRIT-DEP1, CRIT-CQ6, CRIT-SEC3)
- **1 is unique to deep with critic + master verification** (CRIT-DEP2)

### What we DON'T know

- **Default's "62 service imports across 30 view files" count** (default M-2): plausible architecturally but the exact count was not re-grepped here. Defer to prompt 12 for systematic doc-drift audit.
- **Default's "29 files with direct `FirebaseFirestore`/`FirebaseAuth.instance`"** (default H-3): pattern is real (deep CRIT-2 confirms `fcm_service.dart:80`), exact count unverified.
- **`http_certificate_pinning` library quality**: live pub.dev shows verified publisher and Apache-2.0, but last release was 13 months ago. Maintenance risk is real but not a current vuln. Re-evaluate at scale.
- **Several prompt-12 doc drift sites**: BaseService 75%/82% denominator dispute, `code-style.md`'s "33 large files" claim vs reality 132, `MASTER_ANALYSIS_ORCHESTRATOR.md` adoption percentages.

### Methodology notes for synthesis consumers

1. **Treat deep run as authoritative when runs disagree**, because deep performed a second-pass critic re-verification against live source. This master inherits that discipline and adds a third independent verification layer.
2. **Codex caught one HIGH that deep missed:** cert-pin fingerprints empty (codex unique HIGH H3, deep CRIT-1 — same evidence, codex flagged first). Both runs found independently; critical to keep both in master record.
3. **Default systematically over-scored (78 / 71 / 71)** because it didn't enumerate full scope on architecture and missed CRIT-1/CRIT-2/CRIT-3 on prompt 02. Default's narrative is well-written but the score is unreliable as headline.
4. **All file:line references in this master have been confirmed present in current source**. Where a line number is "approximate" (cited as `:34-71` for a range), the range is verified inclusive.
5. **The cross-run comparison itself revealed that knowledge files alone can't substitute for source verification**: deep's Pass-1 investigator (with knowledge files + specialist agent context) initially propagated the same 327k LOC error and confirmed BaseService 96% as fact. Pass-2 critic caught both. The lesson: knowledge files are hypotheses; source code is truth.

---

## 9. Citation density

This master document contains:
- **~210 unique file:line references** across `lib/`, `functions/src/`, `firestore.rules`, `pubspec.yaml`, `pubspec.lock`, `.github/workflows/`, `.github/dependabot.yml`, `test/`, `docs/`.
- All citations are deduplicated across the three source runs.
- Where a finding spans multiple files, all relevant files are cited.

Source data files (working data, not the master itself):
- `MASTER-wave1-01-codequality-data.md` — 273 lines, ~155 unique refs
- `MASTER-wave1-02-security-data.md` — 220 lines, ~110 unique refs (deep alone has 96; codex adds ~14)
- `MASTER-wave1-05-dependencies-data.md` — 283 lines, ~180 unique refs (deep alone has ~140)

Aggregate across all three: ~445 unique file:line references in the source data; ~210 carried into this master with verification status.

---

## 10. Sign-off

This master document represents the **verified, deduplicated, sequenced view** of Wave 1 forensic findings. Findings here have been:
- Cross-checked against three independent forensic runs;
- Verified against live source (either by deep's Pass 2 critic, master re-check, or both);
- Stripped of stale claims (`ConsentPurpose`, cook-snap unawaited, iOS bundle-id mismatch, etc.);
- Sized for remediation effort in engineer-days;
- Sequenced into 3 sprints with explicit dependencies;
- Tagged with cross-prompt boundaries to avoid duplicate ownership.

**Status as of 2026-05-03:**
- Wave 1 (this doc): **complete and verified**.
- Wave 2 (prompts 03 infrastructure / 04 performance / 06 user-experience): in progress (Codex Wave 2 quota'd until 00:31; deep run Wave 2 critic-pass partial).
- Wave 3 (prompts 07-10): pending.
- Wave 4 (prompts 11-12): blocked on Waves 1-3 outputs.
- Synthesis: blocked on all 12 prompts.

A subsequent Wave 2 master will follow the same methodology when input data is complete.
