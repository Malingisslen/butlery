import 'package:clock/clock.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/avatar_write_outcome.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/user_service/own_profile_port.dart';

/// Writes to the own profile that are not settings for [UserService]: online
/// status, friend count, push token, a queued picture and onboarding.
class ProfileStatusWriter {
  ProfileStatusWriter({
    required OwnProfilePort port,
    required UserRepository repository,
  }) : _port = port,
       _repository = repository;

  final OwnProfilePort _port;
  final UserRepository _repository;

  /// Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) return;

    // BUT-912: respect the online-status privacy opt-out. When visibility is
    // off we write NO presence at all — not even lastActiveAt — so neither the
    // dot nor a "last active" time advances. isOnline was already cleared to
    // false when the user saved the toggle, so they stay fully dark.
    if (!_port.profile!.showOnlineStatus) return;

    try {
      await _repository.updateOnlineStatus(userId, isOnline);

      _port.profile = _port.profile!.copyWith(
        isOnline: isOnline,
        lastActiveAt: clock.now(),
      );

      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera online-status: $e');
    }
  }

  /// Update profile statistics (friend count)
  Future<void> updateProfileStats({int? friendsCount}) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) return;

    try {
      final updates = <String, dynamic>{};
      if (friendsCount != null) updates['friendsCount'] = friendsCount;

      if (updates.isNotEmpty) {
        await _repository.updateProfileStats(
          userId,
          friendsCount: friendsCount,
        );

        _port.profile = _port.profile!.copyWith(
          friendsCount: friendsCount,
        );

        _port.cacheProfile(userId, _port.profile!);
        _port.notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera profilstatistik: $e');
    }
  }

  /// Update user's FCM token for push notifications
  Future<void> updateFCMToken(String token) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) {
      AppLogger.warning('⚠️ Cannot update FCM token - no current user');
      return;
    }

    try {
      AppLogger.info('🔔 Updating FCM token for user: ${userId.maskedUserId}');

      await _repository.updateFCMToken(userId, token);

      _port.profile = _port.profile!.copyWith(
        fcmToken: token,
        fcmTokenUpdatedAt: clock.now(),
      );

      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();

      AppLogger.success('✅ FCM token updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update FCM token', e);
      _port.setError(AppLocale.current.errorCouldNotUpdateNotificationToken);
    }
  }

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken() async {
    final userId = _port.userId;
    if (userId == null) return;

    try {
      AppLogger.info('🔔 Clearing FCM token for user: ${userId.maskedUserId}');

      await _repository.clearFCMToken(userId);

      if (_port.profile != null) {
        _port.profile = _port.profile!.copyWith(
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        );
        _port.cacheProfile(userId, _port.profile!);
        _port.notifyListeners();
      }

      AppLogger.success('✅ FCM token cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to clear FCM token', e);
    }
  }

  /// BUT-2294: puts a profile picture that waited on the device onto the
  /// profile, unless the profile holds a different picture than [expected]
  /// (see [UserRepository.setAvatarIfUnchanged]). Brings the in-memory profile
  /// and its cache along when the picture is now the profile's.
  Future<AvatarWriteOutcome> setQueuedAvatar({
    required String? expected,
    required String url,
  }) async {
    final userId = _port.userId;
    if (userId == null) throw StateError('No current user for avatar');
    final outcome = await _repository.setAvatarIfUnchanged(
      userId,
      expected: expected,
      url: url,
    );
    final held = _port.profile;
    // The account may have changed while the transaction ran.
    if (held != null &&
        held.uid == userId &&
        (outcome == AvatarWriteOutcome.set ||
            outcome == AvatarWriteOutcome.alreadySet)) {
      final updated = held.copyWith(avatarUrl: url);
      _port.profile = updated;
      _port.cacheProfile(userId, updated);
      _port.notifyListeners();
    }
    return outcome;
  }

  /// Mark onboarding as completed for the current user.
  Future<void> markOnboardingComplete() async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) return;

    try {
      final updated = _port.profile!.copyWith(
        hasCompletedOnboarding: true,
      );
      await _repository.saveProfile(
        updated,
        writeHouseholdSize:
            false, // onboarding never edits it (BUT-1322 review)
        writeAvatarUrl: false,
      );

      _port.profile = updated;
      _port.cacheProfile(userId, updated);
      _port.notifyListeners();

      AppLogger.success('Onboarding marked as complete');
    } catch (e) {
      AppLogger.error('Failed to mark onboarding complete', e);
      rethrow;
    }
  }

  /// See [UserService.completeOnboardingWithPreferences].
  Future<void> completeOnboardingWithPreferences(
    UserAllergenPreferences? preferences, {
    DateTime? onboardingSkippedAt,
    // BUT-1454: when the verifySignupAge CF flagged this account as a compliant
    // 15–17-year-old, stamp `isMinor` so the profile's public_profiles write
    // serializes `isSearchable:false` (default-private search-suppression). ORed
    // with the existing value so it never DOWNGRADES a server-set minor flag
    // that a resumed session already merged in; the client never writes isMinor
    // itself (CF-authoritative) — it only drives the derived isSearchable.
    bool isMinor = false,
  }) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) {
      throw StateError('No current user for onboarding completion');
    }

    final updated = _port.profile!.copyWith(
      allergenPreferences: preferences ?? _port.profile!.allergenPreferences,
      hasCompletedOnboarding: true,
      onboardingSkippedAt: onboardingSkippedAt,
      isMinor: isMinor || _port.profile!.isMinor,
    );
    await _repository.saveProfile(
      updated,
      writeHouseholdSize: false, // onboarding never edits it (BUT-1322 review)
      writeAvatarUrl: false,
    );

    _port.profile = updated;
    _port.cacheProfile(userId, updated);
    _port.notifyListeners();
  }
}
