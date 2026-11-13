/// User profile service with 30-min caching, social discovery, real-time auth sync, and privacy controls.

import 'dart:async';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/models/search/search_result.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/avatar_write_outcome.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service/profile_cache.dart';
import 'package:butlery/services/user_service/profile_lookups.dart';
import 'package:butlery/services/user_service/own_profile_port.dart';
import 'package:butlery/services/user_service/own_profile_loader.dart';
import 'package:butlery/services/user_service/profile_status_writer.dart';
import 'package:butlery/services/user_service/user_settings_writer.dart';
import 'package:butlery/services/social/profile_searchability_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';

class UserService extends ChangeNotifier
    with ErrorHandlingMixin, FirebaseServiceMixin, StreamManagementMixin {
  final UserRepository _repository;
  final AuthRepository _authRepository;
  final FirestoreRepository _firestoreRepository;

  final PermissionService Function() _permissionService;
  final ProfileSearchabilityService? Function() _profileSearchability;
  final OwnAllergenShareMirror _allergenShareMirror;

  UserService({
    required UserRepository repository,
    required AuthRepository authRepository,
    required FirestoreRepository firestoreRepository,
    required PermissionService Function() permissionService,
    required ProfileSearchabilityService? Function() profileSearchability,
    required OwnAllergenShareMirror allergenShareMirror,
  }) : _repository = repository,
       _authRepository = authRepository,
       _firestoreRepository = firestoreRepository,
       _permissionService = permissionService,
       _profileSearchability = profileSearchability,
       _allergenShareMirror = allergenShareMirror;

  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  /// BUT-1400: current Terms-of-Service version. Single source of truth for
  /// the per-user acceptance record — mirrors the `Version:` header in
  /// `assets/legal/terms_of_service_{en,sv}.md`. Bump both together when the
  /// ToS text changes so the stored `termsVersion` stays meaningful.
  static const String currentTermsVersion = '1.4';

  // Cache for performance (30 minutes)
  UserProfile? _currentUserProfile;
  final ProfileCache _cache = ProfileCache();
  late final ProfileLookups _lookups = ProfileLookups(
    repository: _repository,
    authRepository: _authRepository,
    cache: _cache,
  );
  late final OwnProfilePort _port = OwnProfilePort(
    userId: () => currentUserId,
    readProfile: () => _currentUserProfile,
    writeProfile: (profile) => _currentUserProfile = profile,
    cacheProfile: _cacheProfile,
    notifyListeners: notifyListeners,
    setError: _setError,
    clearError: _clearError,
    setLoading: _setLoading,
    hasError: () => hasError,
    setTermsPending: (pending) => _termsPending = pending,
  );
  late final OwnProfileLoader _loader = OwnProfileLoader(
    port: _port,
    repository: _repository,
    authRepository: _authRepository,
    settings: _settings,
  );
  late final UserSettingsWriter _settings = UserSettingsWriter(
    port: _port,
    repository: _repository,
    profileSearchability: _profileSearchability,
    allergenShareMirror: _allergenShareMirror,
  );
  late final ProfileStatusWriter _status = ProfileStatusWriter(
    port: _port,
    repository: _repository,
  );

  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  /// BUT-1322: "not passed" sentinel for nullable [createOrUpdateProfile]
  /// fields where an explicit null is a meaningful value (clear-to-default).
  static const Object _unset = Object();

  /// BUT-1322 (review): public alias of the sentinel so an editing surface can
  /// say "leave householdSize untouched" on a save where the user never edited
  /// it. Passing the current in-memory value instead would wipe the stored
  /// setting whenever the settings sub-doc read was degraded (fetchProfile
  /// swallows a failed sub-doc fetch into null).
  static const Object householdSizeUntouched = _unset;

  /// "Leave the profile picture as it is": the default of [createOrUpdateProfile]'s
  /// `avatarUrl`, so a save that is about something else neither clears the
  /// picture nor writes the copy this device holds back over a newer one.
  static const Object avatarUntouched = _unset;

  /// "Leave this field as it is" for `cookingSkillLevel`, `cuisineAffinities`
  /// and `bio`, where null (or an empty list) is the user clearing it
  /// (BUT-2509).
  static const Object profileFieldUntouched = _unset;

  bool _termsPending = false;

  /// BUT-916 C1: a Google/Apple account with no profile. Nothing is created
  /// for it until [acceptProviderTerms]; AuthWrapper shows the terms step
  /// instead. Read from Firestore on every load, so it holds across a
  /// restart.
  bool get termsPending => _termsPending;

  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _permissionService().currentUserId;

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
  String? get profileDisplayName {
    final profileName = _currentUserProfile?.displayName;
    return (profileName != null && profileName.isNotEmpty) ? profileName : null;
  }

  /// [profileDisplayName] for a writer whose field cannot be null: empty
  /// instead, never the Auth name (BUT-2009). Empty rather than a label so each
  /// reader shows "unknown" in its own language (BUT-2351).
  String get attributionDisplayName => profileDisplayName.orEmpty();

  /// The profile picture and NOTHING else — the Firebase Auth `photoURL` is the
  /// Google/Apple account picture, which the user never chose to show in the
  /// app (BUT-2009). Null when the profile has none, so a writer stores the
  /// field absent rather than an empty string a reader would take for a URL.
  String? get profileAvatarUrl {
    final url = _currentUserProfile?.avatarUrl;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  /// Display name with Firebase Auth fallback for pre-profile-load state.
  ///
  /// For DISPLAY only. Anything that persists the name as attribution must use
  /// [profileDisplayName] instead (BUT-1705).
  String? get currentDisplayName {
    final profileName = _currentUserProfile?.displayName;
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final authName = _authRepository.currentUser?.displayName;
    return (authName != null && authName.isNotEmpty) ? authName : null;
  }

  /// Get user's allergen preferences, returns defaults if not set.
  UserAllergenPreferences get allergenPreferences =>
      _currentUserProfile?.allergenPreferences ??
      UserAllergenPreferences.defaults;

  /// Initialize service och ladda current user profile
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    AppLogger.info('🔄 Initialiserar UserService...');

    // Listen to auth state changes with StreamManagementMixin
    listenToStream(
      _authRepository.authStateChanges(),
      (user) {
        if (user != null) {
          _loader.loadCurrentUserProfile();
        } else {
          _currentUserProfile = null;
          _termsPending = false;
          _cache.clear();
          notifyListeners();
        }
      },
      name: 'auth_state_changes',
    );

    // Load current user if already authenticated
    if (_authRepository.currentUser != null) {
      await _loader.loadCurrentUserProfile();
    }
  }

  /// Create or update user profile
  Future<UserProfile?> createOrUpdateProfile({
    required String displayName,
    Object? avatarUrl = _unset,
    bool? isSearchable,
    bool? allowEmailSearch,
    Object? cookingSkillLevel = _unset,
    Object? cuisineAffinities = _unset,
    Object? bio = _unset,
    bool? showOnlineStatus,
    bool? shareActivityToFeed,
    Map<String, bool>? activityFeedEventTypes,
    Object? householdSize = _unset,
    bool newProfileCompletedOnboarding = false,
  }) => _loader.createOrUpdateProfile(
    displayName: displayName,
    avatarUrl: avatarUrl,
    isSearchable: isSearchable,
    allowEmailSearch: allowEmailSearch,
    cookingSkillLevel: cookingSkillLevel,
    cuisineAffinities: cuisineAffinities,
    bio: bio,
    showOnlineStatus: showOnlineStatus,
    shareActivityToFeed: shareActivityToFeed,
    activityFeedEventTypes: activityFeedEventTypes,
    householdSize: householdSize,
    newProfileCompletedOnboarding: newProfileCompletedOnboarding,
  );

  /// BUT-1629: set a MINOR's search discoverability through the audited
  /// `setProfileSearchability` callable — the only path that works, since
  /// firestore.rules denies the client write and [UserProfile.toFirestore]
  /// zeroes the field. Keeps the cached profile in step with the server so a
  /// later save re-asserts the right value rather than a stale one.
  ///
  /// Returns the value the server stored, or null when the call failed (the
  /// caller should leave the toggle where it was and surface [error]).
  Future<bool?> setMinorSearchable(bool value) =>
      _settings.setMinorSearchable(value);

  /// See [UserSettingsWriter.setShowNameOnSharedDishes].
  Future<bool> setShowNameOnSharedDishes(bool enabled) =>
      _settings.setShowNameOnSharedDishes(enabled);

  /// Search users by display name or email - OPTIMERAD VERSION
  Future<List<UserProfile>> searchUsers(String query) async =>
      (await searchUsersResult(query)).hits;

  /// Like [searchUsers] but carries a `failed` flag (BUT-1442): true when the
  /// search backend errored on every attempt (an outage), vs. a legitimate
  /// zero-match search. Lets the friend-search UI show a degraded notice
  /// instead of a neutral "no users found" state.
  Future<SearchResult<UserProfile>> searchUsersResult(String query) async {
    if (ValidationUtils.isNullOrWhitespace(query)) {
      return const SearchResult(
        hits: [],
        totalHits: 0,
        page: 0,
        totalPages: 1,
        processingTimeMs: 0,
      );
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _repository.searchProfilesResult(query);

      for (final profile in result.hits) {
        _cacheProfile(profile.uid, profile);
      }

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Search users failed: $e', stackTrace);
      _setError(sanitizeErrorForUser(e));
      return const SearchResult.failure();
    } finally {
      _setLoading(false);
    }
  }

  /// Get user profile by ID (with caching)
  Future<UserProfile?> getUserProfile(String userId) =>
      _lookups.getUserProfile(userId);

  /// Get multiple profiles efficiently (batch); see
  /// [ProfileLookups.getUserProfiles] for what the result reports.
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) =>
      _lookups.getUserProfiles(userIds);

  /// Check if display name is available
  Future<bool> isDisplayNameAvailable(String displayName) =>
      _lookups.isDisplayNameAvailable(displayName);

  /// BUT-1663: a profile read that keeps "absent" and "failed" apart; see
  /// [ProfileLookups.lookupUserProfile].
  Future<ProfileLookup> lookupUserProfile(String userId) =>
      _lookups.lookupUserProfile(userId);

  /// Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) =>
      _status.updateOnlineStatus(isOnline);

  /// Update profile statistics (friend count)
  Future<void> updateProfileStats({int? friendsCount}) =>
      _status.updateProfileStats(friendsCount: friendsCount);

  /// BUT-916: the terms step's "Skapa konto". The acceptance is recorded
  /// first and awaited (not the best-effort record of an e-mail sign-up),
  /// then the profile is made with the name the user confirmed. False when
  /// either write failed; [error] then says so and nothing is half-made
  /// that would let the next load skip the step without a record.
  Future<bool> acceptProviderTerms({required String displayName}) =>
      _loader.acceptProviderTerms(displayName: displayName);

  /// BUG-13: Clear the load/create error and re-run the profile load.
  /// Wired to the "Försök igen" button in AuthWrapper's error state so a
  /// transient profile-load failure (permission-denied / App Check / unavailable)
  /// is recoverable without a full sign-out. No-op-safe when already loaded.
  Future<void> retryLoadProfile() => _loader.retryLoadProfile();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void resetForLogout() {
    _isInitialized = false;
    _termsPending = false;
    _currentUserProfile = null;
    _cache.clear();
    _clearError();
  }

  void _clearError() {
    _error = null;
  }

  void _cacheProfile(String userId, UserProfile profile) =>
      _cache.put(userId, profile);

  /// Public error clearing
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Update user's FCM token for push notifications
  Future<void> updateFCMToken(String token) => _status.updateFCMToken(token);

  /// See [UserSettingsWriter.updatePreferredLocale].
  Future<void> updatePreferredLocale(
    String localeCode, {
    bool onlyIfUnset = false,
  }) => _settings.updatePreferredLocale(localeCode, onlyIfUnset: onlyIfUnset);

  /// Update user's notification preferences
  Future<void> updateNotificationSettings(bool enabled) =>
      _settings.updateNotificationSettings(enabled);

  /// Update user's allergen preferences.
  Future<bool> updateAllergenPreferences(UserAllergenPreferences preferences) =>
      _settings.updateAllergenPreferences(preferences);

  /// See [ProfileStatusWriter.setQueuedAvatar].
  Future<AvatarWriteOutcome> setQueuedAvatar({
    required String? expected,
    required String url,
  }) => _status.setQueuedAvatar(expected: expected, url: url);

  /// Mark onboarding as completed for the current user.
  Future<void> markOnboardingComplete() => _status.markOnboardingComplete();

  /// See [UserSettingsWriter.setAutoAddToPantry].
  Future<void> setAutoAddToPantry(bool enabled) =>
      _settings.setAutoAddToPantry(enabled);

  /// See [UserSettingsWriter.setUseHouseholdAllergens].
  Future<void> setUseHouseholdAllergens(bool enabled) =>
      _settings.setUseHouseholdAllergens(enabled);

  /// See [UserSettingsWriter.setUseMealAllergenScope].
  Future<void> setUseMealAllergenScope(bool enabled) =>
      _settings.setUseMealAllergenScope(enabled);

  /// See [UserSettingsWriter.setShowNutritionStrip].
  Future<void> setShowNutritionStrip(bool enabled) =>
      _settings.setShowNutritionStrip(enabled);

  /// See [UserSettingsWriter.setNewRecipesShowOnProfile].
  Future<bool> setNewRecipesShowOnProfile(bool enabled) =>
      _settings.setNewRecipesShowOnProfile(enabled);

  /// See [UserSettingsWriter.markPantryAutoAddPrompted].
  Future<void> markPantryAutoAddPrompted() =>
      _settings.markPantryAutoAddPrompted();

  /// See [UserSettingsWriter.markActivityFeedHintSeen].
  Future<void> markActivityFeedHintSeen() =>
      _settings.markActivityFeedHintSeen();

  /// Complete onboarding with preferences in a single atomic write.
  /// [onboardingSkippedAt] records a skip.
  ///
  /// BUT-1386 (ADR-0002): `birthYear` is NO LONGER written here. The
  /// `verifySignupAge` Cloud Function is the sole authority for the age gate
  /// and the only writer of birthYear (firestore.rules deny client writes of
  /// it). The onboarding ViewModel calls that CF before this method.
  Future<void> completeOnboardingWithPreferences(
    UserAllergenPreferences? preferences, {
    DateTime? onboardingSkippedAt,
    bool isMinor = false,
  }) => _status.completeOnboardingWithPreferences(
    preferences,
    onboardingSkippedAt: onboardingSkippedAt,
    isMinor: isMinor,
  );

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken() => _status.clearFCMToken();

  /// Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _cache.clear();
    AppLogger.info('🗑️ Profil-cache rensad');
  }

  @override
  Future<void> dispose() async {
    await disposeStreamResources();
    clearCache();
    super.dispose();
  }
}
