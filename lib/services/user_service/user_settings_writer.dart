import 'package:clock/clock.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';
import 'package:butlery/services/social/profile_searchability_service.dart';
import 'package:butlery/services/user_service/own_profile_port.dart';

/// The own profile's settings and one-time flags for [UserService]: each
/// writes one field, then patches the facade's profile and cache through
/// [OwnProfilePort].
class UserSettingsWriter {
  UserSettingsWriter({
    required OwnProfilePort port,
    required UserRepository repository,
    required ProfileSearchabilityService? Function() profileSearchability,
    required OwnAllergenShareMirror allergenShareMirror,
  }) : _port = port,
       _repository = repository,
       _profileSearchability = profileSearchability,
       _allergenShareMirror = allergenShareMirror;

  final OwnProfilePort _port;
  final UserRepository _repository;
  final ProfileSearchabilityService? Function() _profileSearchability;
  final OwnAllergenShareMirror _allergenShareMirror;
  String? _localeWritePending;

  /// See [UserService.setMinorSearchable].
  Future<bool?> setMinorSearchable(bool value) async {
    final stored = await callSetSearchable(value);
    if (stored == null) {
      _port.setError(AppLocale.current.errorCouldNotUpdateSearchability);
      return null;
    }

    final profile = _port.profile;
    if (profile != null) {
      final updated = profile.copyWith(isSearchable: stored);
      _port.profile = updated;
      _port.cacheProfile(updated.uid, updated);
    }
    _port.notifyListeners();
    return stored;
  }

  /// BUT-2221: persists the name-on-shared-dishes opt-in on its own write
  /// path.
  Future<bool> setShowNameOnSharedDishes(bool enabled) async {
    _port.clearError();
    final profile = _port.profile;
    if (profile == null) {
      _port.setError(AppLocale.current.errorCouldNotSaveDishCredit);
      return false;
    }
    try {
      await _repository.setShowNameOnSharedDishes(profile.uid, enabled);
    } catch (e) {
      AppLogger.error('setShowNameOnSharedDishes failed: $e');
      _port.setError(AppLocale.current.errorCouldNotSaveDishCredit);
      return false;
    }
    // Re-read after the await: a sign-out or a profile reload may have
    // replaced the profile captured above.
    final current = _port.profile;
    if (current != null && current.uid == profile.uid) {
      final updated = current.copyWith(
        showNameOnSharedDishes: enabled,
        showNameOnSharedDishesChangedAt: clock.now(),
      );
      _port.profile = updated;
      _port.cacheProfile(updated.uid, updated);
    }
    _port.notifyListeners();
    return true;
  }

  /// Invokes the searchability callable. Returns the stored value, or null on
  /// any failure (offline, rate-limited, App Check, service unregistered) —
  /// the distinction between "server said false" and "we never reached the
  /// server" is what lets callers avoid reporting a state they don't hold.
  Future<bool?> callSetSearchable(bool value) async {
    final service = _profileSearchability();
    if (service == null) {
      AppLogger.warning(
        'ProfileSearchabilityService unavailable — searchability left unchanged',
      );
      return null;
    }
    try {
      return await service.setSearchable(value);
    } catch (e) {
      AppLogger.error('setProfileSearchability failed: $e');
      return null;
    }
  }

  /// Stores the app language where the server reads it, so a push is written
  /// in the recipient's language. [onlyIfUnset] fills an account that has no
  /// language yet and never replaces one, for the sync that runs without the
  /// user having chosen anything. Failure is logged only.
  Future<void> updatePreferredLocale(
    String localeCode, {
    bool onlyIfUnset = false,
  }) async {
    final userId = _port.userId;
    final stored = _port.profile?.preferredLocale;
    if (userId == null || _port.profile == null) return;
    if (stored == localeCode || (onlyIfUnset && stored != null)) return;
    if (_localeWritePending == localeCode) return;

    _localeWritePending = localeCode;
    try {
      await _repository.updatePreferredLocale(userId, localeCode);
      // The profile may have been replaced or signed out while the write was
      // in flight; patch what is there now, never a copy taken before.
      final current = _port.profile;
      if (current != null && current.uid == userId) {
        _port.profile = current.copyWith(preferredLocale: localeCode);
        _port.cacheProfile(userId, _port.profile!);
      }
    } catch (e) {
      AppLogger.warning('Could not store the preferred locale: $e');
    } finally {
      _localeWritePending = null;
    }
  }

  /// Update user's notification preferences
  Future<void> updateNotificationSettings(bool enabled) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) {
      AppLogger.warning(
        '⚠️ Cannot update notification settings - no current user',
      );
      return;
    }

    try {
      AppLogger.info(
        '🔔 Updating notification settings for user: ${userId.maskedUserId}',
      );

      await _repository.updateNotificationSettings(userId, enabled);

      _port.profile = _port.profile!.copyWith(
        notificationsEnabled: enabled,
      );

      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();

      AppLogger.success('✅ Notification settings updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update notification settings', e);
      _port.setError(AppLocale.current.errorCouldNotUpdateNotificationSettings);
    }
  }

  /// Update user's allergen preferences.
  Future<bool> updateAllergenPreferences(
    UserAllergenPreferences preferences,
  ) async {
    final userId = _port.userId;
    if (userId == null || _port.profile == null) {
      AppLogger.warning(
        '⚠️ Cannot update allergen preferences - no current user',
      );
      return false;
    }

    try {
      _port.setLoading(true);
      _port.clearError();
      AppLogger.info(
        '🍽️ Updating allergen preferences for user: ${userId.maskedUserId}',
      );

      final sharedCopies = await _allergenShareMirror.sharesFor(
        userId,
        preferences,
      );
      await _repository.updateAllergenPreferences(
        userId,
        preferences,
        sharedCopies: sharedCopies,
      );

      _port.profile = _port.profile!.copyWith(
        allergenPreferences: preferences,
      );

      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();

      AppLogger.success('✅ Allergen preferences updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update allergen preferences', e);
      _port.setError(AppLocale.current.errorCouldNotUpdateAllergenSettings);
      return false;
    } finally {
      _port.setLoading(false);
    }
  }

  /// BUT-1050: persist the "auto-add bought shopping items to pantry" preference
  /// (the Settings toggle). Optimistically updates the in-memory profile after
  /// the targeted single-field write succeeds.
  Future<void> setAutoAddToPantry(bool enabled) async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) {
      AppLogger.warning('⚠️ Cannot set auto-add-to-pantry - no current user');
      return;
    }

    try {
      await _repository.setAutoAddBoughtToPantry(userId, enabled);
      _port.profile = profile.copyWith(autoAddBoughtToPantry: enabled);
      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to set auto-add-to-pantry', e);
      rethrow;
    }
  }

  /// BUT-1465: persist the household-allergen-filter opt-out. `enabled` = the
  /// weekly menu filters by the whole household's allergens; false = the owner's
  /// allergens only. Targeted single-field write, then updates the in-memory
  /// profile + cache and notifies so the menu generator + the toggle reflect it.
  Future<void> setUseHouseholdAllergens(bool enabled) async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) {
      AppLogger.warning(
        '⚠️ Cannot set use-household-allergens - no current user',
      );
      return;
    }

    try {
      await _repository.setUseHouseholdAllergens(userId, enabled);
      _port.profile = profile.copyWith(useHouseholdAllergens: enabled);
      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to set use-household-allergens', e);
      rethrow;
    }
  }

  /// BUT-2362: persist the per-meal allergen choice, then update the in-memory
  /// profile and notify, as [setUseHouseholdAllergens] does. Rethrows so the
  /// settings tile can say the change did not save.
  Future<void> setUseMealAllergenScope(bool enabled) async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) {
      AppLogger.warning('⚠️ Cannot set meal allergen scope - no current user');
      return;
    }

    try {
      await _repository.setUseMealAllergenScope(userId, enabled);
      _port.profile = profile.copyWith(useMealAllergenScope: enabled);
      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to set meal allergen scope', e);
      rethrow;
    }
  }

  /// BUT-643: persist the nutrition-strip choice, then update the in-memory
  /// profile and notify. Rethrows so the settings tile can say it did not save.
  Future<void> setShowNutritionStrip(bool enabled) async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) {
      AppLogger.warning('⚠️ Cannot set nutrition strip - no current user');
      return;
    }

    try {
      await _repository.setShowNutritionStrip(userId, enabled);
      _port.profile = profile.copyWith(showNutritionStrip: enabled);
      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to set nutrition strip', e);
      rethrow;
    }
  }

  /// Persist the new-recipes-are-public preference, then update the in-memory
  /// profile and notify. Returns false on failure so the caller can say so.
  Future<bool> setNewRecipesShowOnProfile(bool enabled) async {
    _port.clearError();
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) {
      AppLogger.warning('⚠️ Cannot set new recipes public - no current user');
      return false;
    }
    try {
      await _repository.setNewRecipesShowOnProfile(userId, enabled);
    } catch (e) {
      AppLogger.error('❌ Failed to set new recipes public', e);
      _port.setError(AppLocale.current.errorCouldNotSaveNewRecipesPublic);
      return false;
    }
    // Re-read after the await: a sign-out may have replaced the profile.
    final current = _port.profile;
    if (current != null && current.uid == userId) {
      _port.profile = current.copyWith(newRecipesShowOnProfile: enabled);
      _port.cacheProfile(userId, _port.profile!);
    }
    _port.notifyListeners();
    return true;
  }

  /// BUT-1050: persist that the one-time first-checkoff prompt has been shown,
  /// so it never re-nags across sessions/devices. Idempotent and best-effort —
  /// a no-op when there's no profile or the flag is already set.
  Future<void> markPantryAutoAddPrompted() async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) return;
    if (profile.pantryAutoAddPrompted) return;

    try {
      await _repository.markPantryAutoAddPrompted(userId);
      _port.profile = profile.copyWith(pantryAutoAddPrompted: true);
      _port.cacheProfile(userId, _port.profile!);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to mark pantry auto-add prompted', e);
    }
  }

  /// BUT-1220: persist that the one-time activity-feed hint has been shown, so
  /// it never fires again across sessions/devices. Idempotent and best-effort —
  /// a no-op when there's no profile or the flag is already set.
  Future<void> markActivityFeedHintSeen() async {
    final userId = _port.userId;
    final profile = _port.profile;
    if (userId == null || profile == null) return;
    if (profile.hasSeenActivityFeedHint) return;

    try {
      // BUT-1220: targeted single-field write, NOT saveProfile (a full-document
      // set). This fires automatically on the first activity broadcast, so a
      // full set built from a possibly-stale in-memory profile would clobber
      // fields owned by other writers (friendsCount, via friend-creation
      // transactions) or moderators (isHidden/hiddenAt). The flag itself only
      // changes locally.
      await _repository.markActivityFeedHintSeen(userId);

      final updated = profile.copyWith(hasSeenActivityFeedHint: true);
      _port.profile = updated;
      _port.cacheProfile(userId, updated);
      _port.notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to persist activity-feed hint flag: $e');
    }
  }
}
