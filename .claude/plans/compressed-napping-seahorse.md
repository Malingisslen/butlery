# Stability Quick Wins (BUT-55, BUT-27, BUT-35)

## Context

3 stability tickets to prevent crashes. After investigation, **2 are already fixed**. Only BUT-55 needs work, and its actual issue is forced Timestamp casts, not DateTime.parse().

## Tickets to Close (already fixed)

| Ticket | Finding |
|--------|---------|
| **BUT-27** | Both `auth_service.dart` and `feature_flag_service.dart` have stored `StreamSubscription?` fields, proper `.listen()` assignment, and `?.cancel()` in `dispose()` |
| **BUT-35** | `StateNotifierMixin` already has `_isDisposed` guard on all 5 state methods (`setLoading`, `setError`, `clearError`, `clearState`, `setSuccess`). Flag set before `super.dispose()`. 21 ViewModels + 2 services benefit automatically. |

## Ticket: BUT-55 — Fix unsafe Timestamp/DateTime casts from Firestore data

### Problem
18 locations use forced `(data['x'] as Timestamp).toDate()` on Firestore data. If the field is null, missing, or stored as a different type, this throws `TypeError` and crashes.

A safe utility **already exists**: `SerializationUtils.parseDateTimeValue(dynamic value)` in `lib/core/utils/serialization_utils.dart` — handles `DateTime`, `String` (tryParse), `int` (epoch), Firestore `Timestamp`, and raw map. Returns `null` on failure.

### Category A — HIGH RISK (crash if field missing, no null guard)

| # | File | Line | Field |
|---|------|------|-------|
| 1 | `lib/repositories/firebase/dtos/message_dto.dart` | 93 | `sentAt` |
| 2 | `lib/repositories/firebase/dtos/conversation_dto.dart` | 89 | `createdAt` |
| 3 | `lib/repositories/firebase/dtos/conversation_dto.dart` | 90 | `updatedAt` |
| 4 | `lib/repositories/firebase/dtos/conversation_dto.dart` | 86 | `lastReadTimestamps` map values |
| 5 | `lib/services/tagging/ingredient_suggestion_service.dart` | 229 | `createdAt` |
| 6 | `lib/models/notification_batch.dart` | 40 | `createdAt` via `AppTimestamp.fromFirestore()` |
| 7 | `lib/models/notification_batch.dart` | 43 | `scheduledFor` via `AppTimestamp.fromFirestore()` |
| 8 | `lib/models/realtime/realtime_menu_data.dart` | 154 | `createdForDate` via `AppTimestamp.fromFirestore()` |

### Category B — MEDIUM RISK (null-guarded but forced type cast)

| # | File | Line | Field |
|---|------|------|-------|
| 9 | `lib/repositories/firebase/firebase_user_repository.dart` | 175 | `fcmTokenUpdatedAt` |
| 10 | `lib/models/shared_content.dart` | 216 | `expiresAt` |
| 11 | `lib/models/parsing/site_config.dart` | 200 | `lastUpdated` |
| 12 | `lib/services/tagging/ingredient_suggestion_service.dart` | 231 | `reviewedAt` |
| 13 | `lib/services/unified/friends/friends_utility_operations.dart` | 232 | `joinedAt` |
| 14 | `lib/services/unified/friends/friends_utility_operations.dart` | 235 | `lastActiveAt` |
| 15 | `lib/services/presence_service.dart` | 455 | map iteration values |
| 16 | `lib/repositories/firebase/dtos/message_dto.dart` | 95 | `deliveredAt` |
| 17 | `lib/repositories/firebase/dtos/message_dto.dart` | 98 | `readAt` |
| 18 | `lib/repositories/firebase/dtos/message_dto.dart` | 104 | `editedAt` |

### Fix approach

Replace all forced casts with the safe pattern. Two options depending on whether the field is required or optional:

**Required field (must have a value):**
```dart
// Before:
createdAt: (data['createdAt'] as Timestamp).toDate(),
// After:
createdAt: SerializationUtils.parseDateTimeValue(data['createdAt']) ?? DateTime.now(),
```

**Optional field (nullable):**
```dart
// Before:
if (data['expiresAt'] != null) expiresAt = (data['expiresAt'] as Timestamp).toDate();
// After:
expiresAt: SerializationUtils.parseDateTimeValue(data['expiresAt']),
```

**For AppTimestamp.fromFirestore() calls** — add null guard before calling:
```dart
// Before:
createdAt: AppTimestamp.fromFirestore(data['createdAt']).dateTime,
// After:
createdAt: data['createdAt'] != null
    ? AppTimestamp.fromFirestore(data['createdAt']).dateTime
    : DateTime.now(),
```

### Files to modify (10 unique files)
1. `lib/repositories/firebase/dtos/message_dto.dart` — 5 locations
2. `lib/repositories/firebase/dtos/conversation_dto.dart` — 3 locations
3. `lib/services/tagging/ingredient_suggestion_service.dart` — 2 locations
4. `lib/models/notification_batch.dart` — 2 locations
5. `lib/models/realtime/realtime_menu_data.dart` — 1 location
6. `lib/repositories/firebase/firebase_user_repository.dart` — 1 location
7. `lib/models/shared_content.dart` — 1 location
8. `lib/models/parsing/site_config.dart` — 1 location
9. `lib/services/unified/friends/friends_utility_operations.dart` — 2 locations
10. `lib/services/presence_service.dart` — 1 location

### Key utility to reuse
- `SerializationUtils.parseDateTimeValue()` at `lib/core/utils/serialization_utils.dart:85-112`
- Import: `import 'package:butlery/core/utils/serialization_utils.dart';`

## Execution order
1. Close BUT-27 and BUT-35 in Linear
2. Fix Category A locations first (highest crash risk)
3. Fix Category B locations
4. Run `dart analyze --fatal-infos`
5. Run relevant tests
6. Commit

## Verification
- `dart analyze --fatal-infos` passes
- Grep for `as Timestamp).toDate()` in modified files — should be zero
- Existing tests pass: `flutter test test/unit/`

## What this means in plain language
- 2 tickets turn out to already be fixed — we just close them
- We'll make the app handle missing or unexpected date fields from the database gracefully instead of crashing
- If a date field is missing, the app will use a safe fallback instead of showing a white screen of death
- Nothing visible changes for normal use — this only prevents crashes on corrupted/incomplete data
- Low risk — we're using an existing utility that's already proven across the codebase
