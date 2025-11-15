// lib/viewmodels/profile/profile_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// ViewModel for profile management and user account operations.
///
/// Handles:
/// - User profile display data
/// - Logout operation
/// - Account deletion coordination
/// - Profile updates
///
/// **Architecture**:
/// - Uses AsyncOperationMixin for loading states
/// - Uses StateNotifierMixin for safe notifications
/// - Constructor injection for testability
///
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
  })  : _authService = authService,
        _userService = userService,
        _accountDeletionService = accountDeletionService;

  // ===== GETTERS =====

  /// Current authenticated user from Firebase Auth
  User? get currentUser => _authService.currentUser;

  /// Current user ID
  String? get currentUserId => _authService.currentUserId;

  /// Current user profile with full user data
  UserProfile? get currentUserProfile => _userService.currentUserProfile;

  /// User display name
  String? get displayName => currentUserProfile?.displayName ?? currentUser?.displayName;

  /// User email
  String? get email => currentUser?.email;

  /// User photo URL
  String? get photoUrl => currentUserProfile?.avatarUrl ?? currentUser?.photoURL;

  /// Whether user is authenticated
  bool get isAuthenticated => currentUser != null;

  // ===== OPERATIONS =====

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
  ///
  /// This is a destructive operation that:
  /// - Deletes all user data from Firestore
  /// - Deletes Firebase Authentication account
  /// - Cannot be undone
  ///
  /// [reason] - Required reason for account deletion (for audit log)
  ///
  /// Returns true if successful, false otherwise
  Future<bool> deleteAccount({required String reason}) async {
    bool success = false;

    await executeAsync(() async {
      try {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No user logged in');
        }

        AppLogger.info('Starting account deletion for user: $userId');

        // Delete all user data and Firebase Auth account
        final result = await _accountDeletionService.deleteUserAccount(
          reason: reason,
          createAuditLog: true,
        );

        success = result['success'] as bool? ?? false;

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

    return success;
  }

  /// Update user profile
  ///
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
