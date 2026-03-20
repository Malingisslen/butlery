# Urgent Security Sweep (BUT-10, BUT-62, BUT-14, BUT-17, BUT-63)

## Context

5 urgent tickets flagged as production security/integrity risks. After investigation, **3 are already fixed** and can be closed. **2 need implementation work.**

## Tickets to Close (already fixed)

| Ticket | Finding |
|--------|---------|
| **BUT-10** | `auth_service.dart` already uses injected `AuthRepository`, no direct `FirebaseAuth.instance` |
| **BUT-17** | `firebase_deeplink_repository.dart:255` already uses `Random.secure()` (CSPRNG, 47.6 bits entropy) |
| **BUT-63** | No `example.com` stubs in any production share/invite path — only in doc comments and UI hint text |

## Ticket 1: BUT-62 — Adopt LogSanitizer across ~25 files (GDPR)

### Problem
`LogSanitizer` exists at `lib/core/utils/log_sanitizer.dart` with `.maskedUserId`, `.maskedEmail`, `.maskedName` extensions. But ~25 files still log raw user IDs, display names, and emails in `AppLogger` calls.

### Fix
Mechanical find-and-replace: change raw `$userId` / `${user.uid}` / `$displayName` interpolations in log calls to use existing sanitizer extensions.

### Files to modify (~25)
- `lib/main.dart` (line ~817)
- `lib/services/presence_service.dart` (line ~148)
- `lib/services/auth_service.dart` (line ~136)
- `lib/services/auth/auth_mfa_service.dart` (line ~155)
- `lib/services/messaging_service.dart` (line ~363)
- `lib/services/performance/intelligent_cache_manager.dart` (line ~449)
- `lib/services/unified/friends/friends_utility_operations.dart` (lines ~41, ~83)
- `lib/services/unified/friends/friends_state_manager.dart` (lines ~512, ~519)
- `lib/services/unified/operations/friends_management_operations.dart` (line ~461)
- `lib/services/unified/unified_friends_service.dart` (line ~395 — display name)
- `lib/services/notifications/modules/notification_preference_manager.dart` (9 locations)
- `lib/services/notifications/modules/fcm_token_manager.dart` (lines ~82, ~516)
- `lib/services/notifications/modules/notification_batch_manager.dart` (line ~465)
- `lib/services/notifications/modules/notification_offline_manager.dart` (line ~351)
- `lib/repositories/firebase/firebase_auth_repository.dart` (line ~22)
- `lib/repositories/firebase/firebase_recipe_presence_repository.dart` (lines ~71, ~100, ~128)
- `lib/repositories/firebase/firebase_consent_repository.dart` (line ~128)
- `lib/repositories/firebase/firebase_user_repository.dart` (line ~187)
- `lib/repositories/firebase/modules/shopping_repository_query_module.dart` (line ~34)
- `lib/repositories/firebase/modules/message_mutation_module.dart` (line ~292)
- `lib/repositories/algolia/algolia_search_repository.dart` (line ~198)
- `lib/core/cache/json_cache_helper.dart` (lines ~39, ~108, ~139)
- `lib/viewmodels/realtime/participant_tracker.dart` (lines ~129, ~138 — userId + displayName)

### Approach
- Each file already imports `AppLogger`; add `import 'package:butlery/core/utils/log_sanitizer.dart'` where missing
- Replace `$userId` with `${userId.maskedUserId}`, `${user.uid}` with `${user.uid.maskedUserId}`, `$displayName` with `${displayName.maskedName}`
- Reuses existing `LogSanitizer` extensions — no new code needed
- Process in batches of 5-8 files

## Ticket 2: BUT-14 — Add SSRF protection to client-side URL import

### Problem
Cloud Functions have SSRF protection via `functions/src/shared/url-safety.ts`. But the client-side recipe URL import (`HeadlessInAppWebView` in `web_scraper.dart`) has no private IP blocking.

### Fix
Add URL validation in `lib/viewmodels/url_import_viewmodel.dart` method `getUrlValidationErrors()` (lines ~209-235). Add the private-IP check as a static helper directly in the ViewModel (same pattern as the existing `_isValidUrl` helper there) — no new utility file needed.

### Implementation
1. Add a `_isPrivateOrReservedHost(String host)` static method to `UrlImportViewModel` that blocks:
   - `localhost`, `127.0.0.1`, `[::1]`, `0.0.0.0`
   - `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
   - `169.254.0.0/16` (link-local / cloud metadata)
   - `fc00::/7` (IPv6 private)
2. Call it from `getUrlValidationErrors()` and return an error string via localization
3. Add l10n entries to **both** `app_localizations_sv.dart` and `app_localizations_en.dart` (e.g., key `urlImportPrivateAddressError`)
4. Patch `functions/src/shared/url-safety.ts` minor gaps: add `0.0.0.0/8` and IPv6 private range blocks (~5 lines)

### Files to modify
- `lib/viewmodels/url_import_viewmodel.dart` — add private IP check (~30 lines)
- `lib/l10n/app_localizations_sv.dart` — add `urlImportPrivateAddressError` string
- `lib/l10n/app_localizations_en.dart` — add `urlImportPrivateAddressError` string
- `functions/src/shared/url-safety.ts` — patch IPv6 + 0.0.0.0/8 gaps (~5 lines)

## Execution order
1. Close BUT-10, BUT-17, BUT-63 in Linear
2. Implement BUT-14 (small, ~30 lines, quick win)
3. Implement BUT-62 (medium, mechanical but many files)
4. Run `dart analyze --fatal-infos`
5. Commit with message referencing all 5 ticket IDs

## Testing
- **BUT-14**: Add test cases in existing `url_import_viewmodel_test.dart` (or create if absent) verifying `getUrlValidationErrors()` rejects `http://192.168.1.1`, `http://169.254.169.254`, `http://localhost`, `http://10.0.0.1`, and accepts `https://www.ica.se/recept`
- **BUT-62**: No new tests — log content is not unit-tested; correctness verified by grep
- Static analysis: `dart analyze --fatal-infos` passes
- Grep verification: zero raw `$userId` / `${user.uid}` in `AppLogger` calls after BUT-62

## Checklist review
- **Design System**: N/A — no UI changes
- **Architecture**: Validation stays in ViewModel (system boundary). Log changes are in existing service/repo files. No layer violations.
- **Security**: This IS the security fix. SSRF blocked at input. PII masked in logs.
- **Localization**: New error string added to both sv and en l10n files
- **DI**: No new services or registrations
- **Testing**: Specific test cases listed for BUT-14
- **Edge cases**: DNS rebinding (hostname resolving to private IP) not addressed — requires async DNS resolution which is impractical on mobile client. Hostname-based blocking is sufficient for client-side context.
- **Code reuse**: Reuses existing `LogSanitizer` extensions. SSRF logic mirrors existing `url-safety.ts` pattern.
- **Scope**: Minimal — only what's needed. No new utility files.

## What this means in plain language
- 3 tickets turn out to already be fixed — we just close them
- We'll make log messages hide personal data (user IDs, names) so they can't leak in logs — important for GDPR
- We'll block the recipe URL importer from loading private network addresses (like your router's admin page)
- Nothing visible changes in the app's behavior for normal use
- Low risk — log masking is cosmetic to logs, URL blocking just adds a validation error for invalid URLs
