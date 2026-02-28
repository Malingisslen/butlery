# Phase 2: Legal & Compliance (~8 days)

GDPR consent wiring, privacy manifest, ToS, community guidelines, UGC moderation, data processor disclosures.

---

## P2-01 — Create Terms of Service [CRIT]

**Source**: R06:6.3 (implicit), R09:TS-009, R09:TS-012, R10:H5.2
**Files**: New ToS document (sv + en), new `ToSView`, auth_view.dart
**Fix**: Draft ToS (Swedish + English), create ToS view, wire navigation from auth screen, add acceptance checkbox to registration with timestamp in user profile. Note: legal review timeline not included in estimate.
**Effort**: 2-3d (content + implementation)

---

## P2-02 — Create community guidelines [CRIT]

**Source**: R06 (implicit), R09:TS-010, R09:TS-036
**Fix**: Create community guidelines covering harassment, spam, inappropriate content, copyright, impersonation. Swedish + English. Add to app settings, make accessible from social features.
**Effort**: 1-2d

---

## P2-03 — Wire report mechanism to Firestore [CRIT]

**Source**: R09:TS-001, R09:TS-003
**Files**: `lib/widgets/social/group_shopping_list_actions.dart:239`, `firestore.rules`
**Fix**: Create `reports` Firestore collection with security rules. Replace the fake `reportShoppingList()` with actual Firestore writes. Add Cloud Function for admin notification.
**Effort**: 1d

---

## P2-04 — Extend report UI to all content types [CRIT]

**Source**: R09:TS-002
**Files**: Comment views, recipe detail view, messaging view, profile view
**Fix**: Add report actions to comments, shared recipes, messages, and user profiles.
**Effort**: 2-3d

---

## P2-05 — Make auth footer ToS/Privacy links tappable [CRIT]

**Source**: R09:TS-011
**Files**: `lib/views/auth_view.dart:399-413`
**Fix**: Make "Villkor" and "Integritetspolicy" footer labels tappable with navigation to respective views. GDPR requires privacy policy accessible before account creation.
**Effort**: 2h

---

## P2-06 — Add age confirmation to registration [HIGH]

**Source**: R09:TS-033
**Files**: `lib/views/auth_view.dart`, `lib/viewmodels/auth_viewmodel.dart:209`
**Fix**: Add age confirmation checkbox or date of birth field. Block under-13. Privacy policy states 13+ but enforcement is text-only.
**Effort**: 1-2d

---

## P2-07 — Add `showLicensePage()` for OSS attribution [MED]

**Source**: R05:dim3
**Fix**: Add license page accessible from Settings. Required by BSD-3 and Apache-2.0 licenses (56 direct dependencies).
**Effort**: 1h

---

## P2-08 — Wire ConsentService to AnalyticsService [CRIT]

**Source**: R09:TS-014, R09:TS-015, R09:TS-018
**Files**: `lib/services/analytics/analytics_service.dart:55,68-78`, `lib/services/analytics/base_tracker.dart:19-32`, `lib/core/di/modules/core_module.dart:253-254`
**Fix**: Call `analyticsService.setConsentService(consentService)` in CoreModule. Currently `_consentService` is always null → always returns true → all analytics bypass consent. Also call `analyticsService.initialize()` instead of `.toString()` in CoreModule.
**Effort**: 4h

---

## P2-09 — Defer Crashlytics until consent [CRIT]

**Source**: R09:TS-016
**Files**: `lib/main.dart:113-114`
**Fix**: `setCrashlyticsCollectionEnabled(!kDebugMode)` runs before any consent check. Default to disabled, enable after consent is verified.
**Effort**: 1d

---

## P2-10 — Defer Firebase Performance until consent [HIGH]

**Source**: R09:TS-017
**Files**: `lib/main.dart:200`
**Fix**: `newTrace('app_startup')` runs before bootstrap and consent. Defer performance traces until after consent check.
**Effort**: 4h

---

## P2-11 — Update privacy policy with all data processors [CRIT]

**Source**: R09:TS-027
**Files**: `assets/legal/privacy_policy_sv.md:113-123`
**Fix**: Add Mistral AI and Algolia to Section 6.1 (currently only lists Google Firebase and Analytics).
**Effort**: 2h

---

## P2-12 — Add AI-specific consent purpose [CRIT]

**Source**: R07:C7.1
**Files**: `lib/services/account/consent_service.dart:89-112`
**Fix**: Add `aiProcessing` consent purpose (separate from generic `dataProcessing`). Gate LLM calls on it. GDPR Article 5(1)(b) requires purpose limitation.
**Effort**: 1d

---

## P2-13 — Load English privacy policy by locale [HIGH]

**Source**: R09:TS-013
**Files**: `lib/views/legal/privacy_policy_view.dart:45`
**Fix**: `_loadPrivacyPolicy()` hardcodes `privacy_policy_sv.md`. Load based on locale.
**Effort**: 2h

---

## P2-14 — Account deletion missing 7 collections [HIGH]

**Source**: R02:D-06
**Files**: `lib/services/account/account_deletion_service.dart:89-106`
**Fix**: Add deletion of `user_fcm_tokens`, `user_notification_preferences`, `user_notifications`, `consent` subcollection, top-level `messages`, `shared_menus`, `shared_shopping_lists` to complete GDPR Article 17. (More missing collections than originally identified.)
**Effort**: 6h

---

## P2-15 — Consent model field name mismatch [MED]

**Source**: R02:D-08
**Files**: `lib/models/user_consent.dart:44-53`, `firestore.rules:1288`
**Fix**: Model writes `grantedAt` but rule requires `timestamp` field. Align naming.
**Effort**: 1h

---

## P2-16 — Social deletion batch may exceed 500-doc limit [MED]

**Source**: R02:D-19
**Files**: `lib/services/account/social_deletion_operations.dart:11-78`
**Fix**: Add batch chunking to respect Firestore's 500-operation batch limit.
**Effort**: 2h

---

## P2-17 — Add content screening (profanity filter) [MED]

**Source**: R09:TS-008
**Files**: `lib/services/moderation/` (new), `functions/src/moderation/` (new)
**Fix**: Basic Swedish profanity word list filter for comments/messages. Baseline Trust & Safety requirement for UGC-enabled app.
**Effort**: 2-3d
