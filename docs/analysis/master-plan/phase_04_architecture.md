# Phase 4: Architecture Fixes (~4 days)

Repository boundary violations, SerializationUtils adoption, Firebase collection constants, file decomposition.

---

## P4-01 — Create `FirestoreCollections` constants class [HIGH]

**Source**: R01:H6.1, R01:M3.2
**Files**: 385 hard-coded collection name strings across 79 files
**Fix**: Create centralized `FirestoreCollections` constants class, batch replace. Worst: `conversation_participant_module.dart` (33), `collaborative_recipe_repository.dart` (28).
**Effort**: 2d

---

## P4-02 — Migrate 4 remaining models to SerializationUtils [HIGH]

**Source**: R01:H3.1
**Files**: `audit_log.dart:67-73`, `friend_category.dart:238-249`, `conversation_participant.dart:89-100`, `conversation_membership.dart:92-100`
**Fix**: Replace raw `as String` / `as int` casting with `SerializationUtils.safe*` methods. Runtime TypeError risk on null Firestore data. ~~notification_batch.dart~~ already uses SerializationUtils. ~~realtime_menu_factory.dart~~ has no raw casting. ~~shared_content.dart~~ uses `.orEmpty()` (acceptable).
**Effort**: 2h

---

## P4-03 — Views import concrete/interface repositories directly [CRIT]

**Source**: R01:C1.1, R01:M1.1
**Files**: `lib/views/personal_tags_view.dart:19-20`, `lib/views/allergen_preferences_view.dart:6`
**Fix**: Route through appropriate services; remove direct repository access from views. Both concrete Firebase imports and repository interface imports violate MVVM layering.
**Effort**: 2h

---

## P4-04 — FeedbackService bypasses repository layer [CRIT]

**Source**: R01:C1.2
**Files**: `lib/services/feedback/feedback_service.dart:58,76`
**Fix**: Create FeedbackRepository, inject into FeedbackService. Currently uses `FirebaseFirestore.instance` and `FirebaseStorage.instance` directly.
**Effort**: 4h

---

## P4-05 — MessagingService bypasses repository for polls [CRIT]

**Source**: R01:C1.3
**Files**: `lib/services/messaging_service.dart:555,613`
**Fix**: Add poll operations to MessagingRepository. Service has `_messagingRepository` but bypasses it.
**Effort**: 3h

---

## P4-06 — 5 ViewModels import cloud_firestore (Timestamp leakage) [HIGH]

**Source**: R01:H1.1
**Files**: `base_shared_content_viewmodel.dart:30`, `shared_menu_viewmodel.dart:32`, `shared_shopping_viewmodel.dart:33`, `shared_recipe_viewmodel.dart:32`, `menu_social_manager.dart:3`
**Fix**: Convert Timestamp → DateTime at model/service boundary.
**Effort**: 3h

---

## P4-07 — ProfileViewModel imports firebase_auth [HIGH]

**Source**: R01:H1.2
**Files**: `lib/viewmodels/profile/profile_viewmodel.dart:8`
**Fix**: Use domain-level user type or expose through AuthService.
**Effort**: 2h

---

## P4-08 — Views import firebase_auth for MFA types [HIGH]

**Source**: R01:H1.3
**Files**: `lib/views/auth/mfa_challenge_dialog.dart:2`, `lib/views/settings/mfa_settings_view.dart:2`
**Fix**: Create MFA abstractions in auth service layer.
**Effort**: 4h

---

## P4-09 — Remove direct Firebase static references in DI [HIGH]

**Source**: R01:H1.4, R01:M1.4
**Files**: `lib/services/unified/modules/firebase_sync_manager.dart:212`, `lib/core/di/modules/social_module.dart:124`
**Fix**: Remove `FirebaseFirestore.instance` fallback in sync manager; inject `FirebaseAuth` through existing auth repository in social module. Both are 30-min fixes in same cleanup pass.
**Effort**: 1h

---

## P4-10 — notification_repository.dart misplaced in services/ [MED]

**Source**: R01:H1.6
**Files**: `lib/services/notifications/notification_repository.dart`
**Fix**: Move to `lib/repositories/`.
**Effort**: 30 min

---

## ~~P4-11~~ — ~~5 ViewModels import repository implementations~~ [FIXED]

**Status**: Verified fixed — all 5 ViewModels now import interfaces or specialized repositories correctly. No action needed.

---

## P4-12 — Direct service instantiation in ViewModels [MED]

**Source**: R01:M1.3
**Files**: `user_profile_viewmodel.dart:44`, `recipe_image_manager.dart:80`, `xfile_upload_handler.dart:31`
**Fix**: Remove `ImageUploadService()` fallback, require DI injection.
**Effort**: 1h

---

## P4-13 — Inconsistent null-coalescing patterns [MED]

**Source**: R01:H3.2
**Files**: 14 model files
**Fix**: Replace 33 `?? ''` with `.orEmpty()` in model files for consistency.
**Effort**: 1h

---

## P4-14 — 3 ViewModels manually manage _isLoading [MED]

**Source**: R01:M3.3
**Files**: `chat_viewmodel.dart:27`, `group_detail_viewmodel.dart:61`, `personal_tag_viewmodel.dart:32`
**Fix**: Migrate to StateNotifierMixin + AsyncOperationMixin.
**Effort**: 3h

---

## P4-15 — 9 plain service classes without BaseService/ErrorHandlingMixin [MED]

**Source**: R01:M3.1
**Files**: `YouTubeTranscriptService`, `FCMService`, `FieldEncryptionService` + 6 others
**Fix**: Add ErrorHandlingMixin to the 3 substantive services (others are thin wrappers).
**Effort**: 2h
