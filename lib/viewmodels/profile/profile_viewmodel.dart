// lib/viewmodels/profile/profile_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/account/retained_record.dart';

/// ViewModel for profile management and user account operations.
/// Handles:
/// - User profile display data
/// - Logout operation
/// - Account deletion coordination
/// - Profile updates
/// **Architecture**:
/// - Uses AsyncOperationMixin for loading states
/// - Uses StateNotifierMixin for safe notifications
/// - Constructor injection for testability
/// **Usage**:
/// ```dart
/// final viewModel = ServiceLocator.get<ProfileViewModel>();
/// await viewModel.logout();
/// ```
class ProfileViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final AuthService _authService;
  final UserService _userService;
  final AccountDeletionService _accountDeletionService;

  ProfileViewModel({
    required AuthService authService,
    required UserService userService,
    required AccountDeletionService accountDeletionService,
  }) : _authService = authService,
       _userService = userService,
       _accountDeletionService = accountDeletionService;

  String? get currentUserId => _authService.currentUserId;

  UserProfile? get currentUserProfile => _userService.currentUserProfile;

  String? get displayName =>
      currentUserProfile?.displayName ?? _authService.currentUserDisplayName;

  String? get email => _authService.currentUserEmail;

  String? get photoUrl =>
      currentUserProfile?.avatarUrl ?? _authService.currentUserPhotoUrl;

  bool get isAuthenticated => _authService.currentUserId != null;

  /// Sign out the current user
  Future<void> logout() async {
    await executeAsync(() async {
      try {
        await _authService.signOut();
        AppLogger.info('User logged out successfully');
      } catch (e) {
        AppLogger.error('Logout failed', e);
        rethrow;
      }
    });
  }

  /// Delete user account and all associated data
  /// This is a destructive operation that:
  /// - Deletes all user data from Firestore
  /// - Deletes Firebase Authentication account
  /// - Cannot be undone
  /// [reason] - Required reason for account deletion (for audit log)
  ///
  /// Returns an [AccountDeletionOutcome]: a deletion can succeed and still
  /// lawfully retain moderation evidence under GDPR Art. 17(3)(e), which a
  /// boolean cannot carry.
  Future<AccountDeletionOutcome> deleteAccount({required String reason}) async {
    bool success = false;
    var accountDeleted = false;
    var retained = const <RetainedRecord>[];

    await executeAsync(() async {
      try {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No user logged in');
        }

        AppLogger.info(
          'Starting account deletion for user: ${userId.maskedUserId}',
        );

        // Delete all user data and Firebase Auth account
        final result = await _accountDeletionService.deleteUserAccount(
          reason: reason,
          createAuditLog: true,
        );

        success = result['success'] as bool? ?? false;
        retained =
            result['retained'] as List<RetainedRecord>? ??
            const <RetainedRecord>[];
        // The Auth account specifically, which is NOT the same as the erasure
        // succeeding: the callable pushes `auth_deletion` into
        // `failedCollections` when `auth.deleteUser` throws, and every other
        // failed step leaves the account genuinely gone.
        // Fails OPEN on a missing key — an absent list reads as "the account
        // is gone". The real service always populates it, and the direction is
        // stated rather than left to be inferred because it is the one this
        // flag exists to prevent.
        final failed = result['failedCollections'] as List? ?? const [];
        accountDeleted = !failed.contains('auth_deletion');

        if (success) {
          AppLogger.info('Account deleted successfully');
        } else {
          final errors = result['errors'] as List?;
          AppLogger.error('Account deletion had errors: $errors');
        }
      } catch (e) {
        AppLogger.error('Account deletion failed', e);
        success = false;
        rethrow;
      }
    });

    return AccountDeletionOutcome(
      success: success,
      accountDeleted: accountDeleted,
      retained: retained,
    );
  }

  /// Update user profile
  /// Updates display name and other profile settings
  Future<void> updateProfile({
    required String displayName,
    bool? isSearchable,
    bool? allowEmailSearch,
  }) async {
    await executeAsync(() async {
      try {
        await _userService.createOrUpdateProfile(
          displayName: displayName,
          isSearchable: isSearchable,
          allowEmailSearch: allowEmailSearch,
        );
        AppLogger.info('Profile updated successfully');
      } catch (e) {
        AppLogger.error('Profile update failed', e);
        rethrow;
      }
    });
  }

  @override
  void dispose() {
    AppLogger.debug('ProfileViewModel disposed');
    super.dispose();
  }
}

/// What an account deletion did — and, when the law required it, what it kept.
///
/// BUT-2046 follow-up. This replaces a bare `bool`: a deletion can succeed and
/// still lawfully retain moderation evidence under GDPR Art. 17(3)(e), and the
/// person is owed a notice saying so (Art. 12(4)). A boolean cannot carry that,
/// and the screen has exactly one moment to show it.
class AccountDeletionOutcome {
  const AccountDeletionOutcome({
    required this.success,
    this.accountDeleted = false,
    this.retained = const <RetainedRecord>[],
  });

  /// Whether the erasure completed. A lawful hold does NOT make this false —
  /// retention under an Art. 17(3) exception is a compliant outcome.
  final bool success;

  /// Whether the Auth account itself is gone.
  ///
  /// Distinct from [success], which also requires every cascade step to have
  /// completed. The Art. 12(4) notice opens with "Ditt konto är raderat", so it
  /// must not be shown when `auth.deleteUser` failed and the account is still
  /// there — the retention is real but the sentence above it would not be.
  final bool accountDeleted;

  /// Records kept, empty on every ordinary deletion.
  final List<RetainedRecord> retained;

  /// Whether the person must be shown the Art. 12(4) notice.
  ///
  /// Data being KEPT is what triggers the duty, not the erasure completing —
  /// Malin's call, 2026-09-09 (BUT-2047). It does require the account to be
  /// gone, because the notice's own title says it is.
  bool get owesRetentionNotice => retained.isNotEmpty && accountDeleted;

  /// Whether anything was kept at all, regardless of what else happened.
  bool get hasRetainedRecords => retained.isNotEmpty;
}
