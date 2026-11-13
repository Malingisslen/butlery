// BUT-1507: each caller of UserService sees only the part it uses. The service
// implements all four; DI hands out the same instance under each, so there is
// still exactly one profile in memory (registerUserServiceRoles).

import 'package:flutter/foundation.dart';
import 'package:butlery/models/avatar_write_outcome.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/search/search_result.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';

/// The signed-in user's own profile, read-only. Listen for changes.
abstract interface class OwnProfileReader implements Listenable {
  UserProfile? get currentUserProfile;

  /// Get user's allergen preferences, returns defaults if not set.
  UserAllergenPreferences get allergenPreferences;

  /// BUT-1705: the profile name and NOTHING else — no Firebase Auth fallback.
  ///
  /// Use this wherever the name is about to be PERSISTED as attribution on a
  /// document other people read (shared shopping lists, collaborative items).
  /// The Auth handle is the legal name attached to the user's Google/Apple
  /// account, not a display name they chose to expose, and it is also invisible
  /// to the two systems that maintain such copies: `on-profile-updated.ts`
  /// propagates the PROFILE name, and account deletion scrubs what that CF
  /// wrote — so an Auth-sourced stamp is both unconsented and un-erasable.
  ///
  /// Null before the profile loads. Callers stamp empty rather than blocking;
  /// a name is a label, an unlabelled edit is better than a wrong one.
  String? get profileDisplayName;

  /// [profileDisplayName] for a writer whose field cannot be null: empty
  /// instead, never the Auth name (BUT-2009). Empty rather than a label so each
  /// reader shows "unknown" in its own language (BUT-2351).
  String get attributionDisplayName;

  /// The profile picture and NOTHING else — the Firebase Auth `photoURL` is the
  /// Google/Apple account picture, which the user never chose to show in the
  /// app (BUT-2009). Null when the profile has none, so a writer stores the
  /// field absent rather than an empty string a reader would take for a URL.
  String? get profileAvatarUrl;

  /// Display name with Firebase Auth fallback for pre-profile-load state.
  ///
  /// For DISPLAY only. Anything that persists the name as attribution must use
  /// [profileDisplayName] instead (BUT-1705).
  String? get currentDisplayName;
  String? get currentUserId;

  /// BUT-916 C1: a Google/Apple account with no profile. Nothing is created
  /// for it until `acceptProviderTerms`; AuthWrapper shows the terms step
  /// instead. Read from Firestore on every load, so it holds across a
  /// restart.
  bool get termsPending;
  bool get isLoading;
  String? get error;
  bool get hasError;
}

/// Other users' profiles.
abstract interface class ProfileDirectory {
  /// Get user profile by ID (with caching)
  Future<UserProfile?> getUserProfile(String userId);

  /// Get multiple profiles efficiently (batch); see
  /// `ProfileLookups.getUserProfiles` for what the result reports.
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds);

  /// BUT-1663: a profile read that keeps "absent" and "failed" apart; see
  /// `ProfileLookups.lookupUserProfile`.
  Future<ProfileLookup> lookupUserProfile(String userId);

  /// Search users by display name or email - OPTIMERAD VERSION
  Future<List<UserProfile>> searchUsers(String query);

  /// Like [searchUsers] but carries a `failed` flag (BUT-1442): true when the
  /// search backend errored on every attempt (an outage), vs. a legitimate
  /// zero-match search. Lets the friend-search UI show a degraded notice
  /// instead of a neutral "no users found" state.
  Future<SearchResult<UserProfile>> searchUsersResult(String query);

  /// Check if display name is available
  Future<bool> isDisplayNameAvailable(String displayName);
}

/// Changes to the signed-in user's own profile and settings.
abstract interface class OwnProfileEditor {
  /// Create or update user profile
  Future<UserProfile?> createOrUpdateProfile({
    required String displayName,
    Object? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    Object? cookingSkillLevel,
    Object? cuisineAffinities,
    Object? bio,
    bool? showOnlineStatus,
    bool? shareActivityToFeed,
    Map<String, bool>? activityFeedEventTypes,
    Object? householdSize,
    bool newProfileCompletedOnboarding,
  });

  Future<bool?> setMinorSearchable(bool value);

  /// See `UserSettingsWriter.setShowNameOnSharedDishes`.
  Future<bool> setShowNameOnSharedDishes(bool enabled);

  /// Update user's online status
  Future<void> updateOnlineStatus(bool isOnline);

  /// Update profile statistics (friend count)
  Future<void> updateProfileStats({int? friendsCount});

  /// Update user's FCM token for push notifications
  Future<void> updateFCMToken(String token);

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken();

  /// See `UserSettingsWriter.updatePreferredLocale`.
  Future<void> updatePreferredLocale(String localeCode, {bool onlyIfUnset});

  /// Update user's notification preferences
  Future<void> updateNotificationSettings(bool enabled);

  /// Update user's allergen preferences.
  Future<bool> updateAllergenPreferences(UserAllergenPreferences preferences);

  /// See `ProfileStatusWriter.setQueuedAvatar`.
  Future<AvatarWriteOutcome> setQueuedAvatar({
    required String? expected,
    required String url,
  });

  /// Mark onboarding as completed for the current user.
  Future<void> markOnboardingComplete();

  /// See `UserSettingsWriter.setAutoAddToPantry`.
  Future<void> setAutoAddToPantry(bool enabled);

  /// See `UserSettingsWriter.setUseHouseholdAllergens`.
  Future<void> setUseHouseholdAllergens(bool enabled);

  /// See `UserSettingsWriter.setUseMealAllergenScope`.
  Future<void> setUseMealAllergenScope(bool enabled);

  /// See `UserSettingsWriter.setShowNutritionStrip`.
  Future<void> setShowNutritionStrip(bool enabled);

  /// See `UserSettingsWriter.setNewRecipesShowOnProfile`.
  Future<bool> setNewRecipesShowOnProfile(bool enabled);

  /// See `UserSettingsWriter.markPantryAutoAddPrompted`.
  Future<void> markPantryAutoAddPrompted();

  /// See `UserSettingsWriter.markActivityFeedHintSeen`.
  Future<void> markActivityFeedHintSeen();

  Future<void> completeOnboardingWithPreferences(
    UserAllergenPreferences? preferences, {
    DateTime? onboardingSkippedAt,
    bool isMinor,
  });
}

/// Starting, retrying and ending the signed-in user's profile session.
abstract interface class ProfileSession {
  /// Initialize service och ladda current user profile
  Future<void> initialize();

  /// BUG-13: Clear the load/create error and re-run the profile load.
  /// Wired to the "Försök igen" button in AuthWrapper's error state so a
  /// transient profile-load failure (permission-denied / App Check / unavailable)
  /// is recoverable without a full sign-out. No-op-safe when already loaded.
  Future<void> retryLoadProfile();
  Future<bool> acceptProviderTerms({required String displayName});

  /// Public error clearing
  void clearError();

  /// Clear cache (useful for testing or manual refresh)
  void clearCache();
  void resetForLogout();
}
