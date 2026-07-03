/// User profile service with 30-min caching, social discovery, real-time auth sync, and privacy controls.

import 'package:clock/clock.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// User profile service with 30-min caching, social discovery, auth monitoring, and privacy controls.
/// ```dart
/// final svc = UserService(repository: ServiceLocator.get(), authRepository: ServiceLocator.get());
/// await svc.initialize(); // Monitor auth state
/// await svc.createOrUpdateProfile(displayName: 'John', isSearchable: true);
class UserService extends ChangeNotifier
    with ErrorHandlingMixin, FirebaseServiceMixin, StreamManagementMixin {
  final UserRepository _repository;
  final AuthRepository _authRepository;
  final FirestoreRepository _firestoreRepository;

  UserService({
    required UserRepository repository,
    required AuthRepository authRepository,
    FirestoreRepository? firestoreRepository,
  }) : _repository = repository,
       _authRepository = authRepository,
       _firestoreRepository =
           firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();

  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  /// BUT-1400: current Terms-of-Service version. Single source of truth for
  /// the per-user acceptance record — mirrors the `Version:` header in
  /// `assets/legal/terms_of_service_{en,sv}.md`. Bump both together when the
  /// ToS text changes so the stored `termsVersion` stays meaningful.
  static const String currentTermsVersion = '1.0';

  // Cache for performance (30 minutes)
  UserProfile? _currentUserProfile;
  final Map<String, UserProfile> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Constants
  static const int _cacheDurationMinutes = 30;
  static const int _maxCacheSize = 200;

  /// BUT-1322: "not passed" sentinel for nullable [createOrUpdateProfile]
  /// fields where an explicit null is a meaningful value (clear-to-default).
  static const Object _unset = Object();

  /// BUT-1322 (review): public alias of the sentinel so an editing surface can
  /// say "leave householdSize untouched" on a save where the user never edited
  /// it. Passing the current in-memory value instead would wipe the stored
  /// setting whenever the settings sub-doc read was degraded (fetchProfile
  /// swallows a failed sub-doc fetch into null).
  static const Object householdSizeUntouched = _unset;

  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Display name with Firebase Auth fallback for pre-profile-load state.
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
          _loadCurrentUserProfile();
        } else {
          _currentUserProfile = null;
          _profileCache.clear();
          _cacheTimestamps.clear();
          notifyListeners();
        }
      },
      name: 'auth_state_changes',
    );

    // Load current user if already authenticated
    if (_authRepository.currentUser != null) {
      await _loadCurrentUserProfile();
    }
  }

  /// Create or update user profile
  Future<UserProfile?> createOrUpdateProfile({
    required String displayName,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
    bool? showOnlineStatus,
    bool? shareActivityToFeed,
    Map<String, bool>? activityFeedEventTypes,
    // BUT-1322: sentinel default (not plain null) so callers that don't pass
    // the field (auto-creation, social handler) can't wipe a saved household
    // size, while an explicit null still clears it back to "recipe default".
    Object? householdSize = _unset,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _setError(AppLocale.current.errorNoUserLoggedIn);
      return null;
    }

    try {
      _setLoading(true);
      _clearError();

      // Prefer in-memory profile to avoid re-fetching, which can silently lose
      // hasCompletedOnboarding if the private settings sub-doc fetch fails (BUG-044).
      // Tradeoff: won't pick up changes made on other devices since last load.
      final existingProfile =
          _currentUserProfile ?? await _repository.fetchProfile(user.uid);

      UserProfile profile;
      if (existingProfile != null) {
        // Only pass cooking identity fields when caller provides them,
        // so other callers (auto-creation, social handler) don't wipe them.
        profile = existingProfile.copyWith(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isSearchable: isSearchable,
          allowEmailSearch: allowEmailSearch,
          lastActiveAt: clock.now(),
        );
        if (cookingSkillLevel != null) {
          profile = profile.copyWith(cookingSkillLevel: cookingSkillLevel);
        }
        if (cuisineAffinities != null) {
          profile = profile.copyWith(cuisineAffinities: cuisineAffinities);
        }
        if (bio != null) {
          profile = profile.copyWith(bio: bio);
        }
        if (showOnlineStatus != null) {
          // BUT-912: when the user turns visibility off, also clear isOnline so
          // the live dot disappears the moment they save (not just on the next
          // heartbeat). The presence gate then keeps them dark.
          profile = profile.copyWith(
            showOnlineStatus: showOnlineStatus,
            isOnline: showOnlineStatus ? profile.isOnline : false,
          );
        }
        if (shareActivityToFeed != null) {
          profile = profile.copyWith(shareActivityToFeed: shareActivityToFeed);
        }
        if (activityFeedEventTypes != null) {
          profile = profile.copyWith(
            activityFeedEventTypes: activityFeedEventTypes,
          );
        }
        if (!identical(householdSize, _unset)) {
          profile = profile.copyWith(householdSize: householdSize as int?);
        }
      } else {
        final now = clock.now();
        profile = UserProfile(
          uid: user.uid,
          displayName: displayName,
          email: user.email.orEmpty(),
          avatarUrl: avatarUrl,
          isSearchable: isSearchable ?? true,
          allowEmailSearch: allowEmailSearch ?? false,
          publicRecipeCount: 0,
          friendsCount: 0,
          joinedAt: now,
          lastActiveAt: now,
          isOnline: true,
          showOnlineStatus: showOnlineStatus ?? true,
          shareActivityToFeed: shareActivityToFeed ?? true,
          activityFeedEventTypes: activityFeedEventTypes ?? const {},
          cookingSkillLevel: cookingSkillLevel,
          cuisineAffinities: cuisineAffinities,
          bio: bio,
          householdSize: identical(householdSize, _unset)
              ? null
              : householdSize as int?,
        );
      }

      // BUT-1322 (review): only write the householdSize key when the caller
      // deliberately set/cleared it — see UserRepository.saveProfile.
      await _repository.saveProfile(
        profile,
        writeHouseholdSize: !identical(householdSize, _unset),
      );

      _currentUserProfile = profile;
      _cacheProfile(user.uid, profile);

      // Profile propagation handled by Cloud Function (on-profile-updated.ts)

      AppLogger.success('Profil sparad: ${profile.displayName.maskedName}');
      notifyListeners();
      return profile;
    } catch (e) {
      AppLogger.error('❌ Kunde inte spara profil: $e');
      _setError(extractUserMessage(e));
      return null;
    } finally {
      _setLoading(false);
    }
  }

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
  Future<UserProfile?> getUserProfile(String userId) async {
    // Check cache first
    if (_profileCache.containsKey(userId)) {
      final cached = _profileCache[userId]!;
      final cacheTime = _cacheTimestamps[userId]!;
      final isExpired =
          clock.now().difference(cacheTime).inMinutes > _cacheDurationMinutes;

      if (!isExpired) {
        return cached;
      }
    }

    // Fetch from repository
    final profile = await safeExecute(
      () async {
        final profile = await _getProfileFromRepository(userId);
        if (profile != null) {
          _cacheProfile(userId, profile);
        }
        return profile;
      },
      operationName: 'Get user profile',
    );

    return profile;
  }

  /// Get multiple profiles efficiently (batch)
  Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final results = <UserProfile>[];
    final uncachedIds = <String>[];

    // Check cache first
    for (final userId in userIds) {
      if (_profileCache.containsKey(userId)) {
        final cached = _profileCache[userId]!;
        final cacheTime = _cacheTimestamps[userId]!;
        final isExpired =
            clock.now().difference(cacheTime).inMinutes > _cacheDurationMinutes;

        if (!isExpired) {
          results.add(cached);
        } else {
          uncachedIds.add(userId);
        }
      } else {
        uncachedIds.add(userId);
      }
    }

    if (uncachedIds.isNotEmpty) {
      try {
        final fetched = await _repository.fetchProfiles(uncachedIds);
        for (final profile in fetched) {
          results.add(profile);
          _cacheProfile(profile.uid, profile);
        }
      } catch (e) {
        AppLogger.error('❌ Kunde inte hämta profilbatch: $e');
      }
    }

    return results;
  }

  /// Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) return;

    // BUT-912: respect the online-status privacy opt-out. When visibility is
    // off we write NO presence at all — not even lastActiveAt — so neither the
    // dot nor a "last active" time advances. isOnline was already cleared to
    // false when the user saved the toggle, so they stay fully dark.
    if (!_currentUserProfile!.showOnlineStatus) return;

    try {
      await _repository.updateOnlineStatus(userId, isOnline);

      _currentUserProfile = _currentUserProfile!.copyWith(
        isOnline: isOnline,
        lastActiveAt: clock.now(),
      );

      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera online-status: $e');
    }
  }

  /// Update profile statistics (friend count, recipe count)
  Future<void> updateProfileStats({
    int? friendsCount,
    int? publicRecipeCount,
  }) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) return;

    try {
      final updates = <String, dynamic>{};
      if (friendsCount != null) updates['friendsCount'] = friendsCount;
      if (publicRecipeCount != null) {
        updates['publicRecipeCount'] = publicRecipeCount;
      }

      if (updates.isNotEmpty) {
        await _repository.updateProfileStats(
          userId,
          friendsCount: friendsCount,
          publicRecipeCount: publicRecipeCount,
        );

        _currentUserProfile = _currentUserProfile!.copyWith(
          friendsCount: friendsCount,
          publicRecipeCount: publicRecipeCount,
        );

        _cacheProfile(userId, _currentUserProfile!);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera profilstatistik: $e');
    }
  }

  /// Check if display name is available
  Future<bool> isDisplayNameAvailable(String displayName) async {
    if (ValidationUtils.isNullOrWhitespace(displayName)) return false;

    try {
      return await _repository.isDisplayNameAvailable(displayName);
    } catch (e) {
      AppLogger.error('❌ Kunde inte kontrollera displayName: $e');
      return false;
    }
  }

  /// Private methods - UPPDATERAD med auto-create
  Future<void> _loadCurrentUserProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    try {
      // NYTT: Skapa base user document i 'users' collection för friends system
      await _ensureBaseUserDocument(user.uid);

      _currentUserProfile = await _repository.fetchProfile(user.uid);

      // NY: Om profil inte finns, skapa en automatiskt
      if (_currentUserProfile == null && user.email != null) {
        AppLogger.info(
          '👤 Ingen profil hittad - skapar automatiskt för ${user.email}',
        );

        final displayName =
            user.displayName ??
            user.email!.split('@')[0]; // Use email prefix as default

        _currentUserProfile = await createOrUpdateProfile(
          displayName: displayName,
          isSearchable: true,
          allowEmailSearch: false,
        );

        if (_currentUserProfile != null) {
          // BUT-1400: record ToS acceptance once, at the account-creation
          // moment (this branch only runs when no profile existed yet — i.e.
          // signup). Best-effort: an accountability-record write must never
          // block onboarding, so a failure is logged and swallowed.
          try {
            await _repository.recordTermsAcceptance(
              user.uid,
              currentTermsVersion,
            );
          } catch (e) {
            AppLogger.warning(
              '⚠️ Kunde inte registrera villkorsgodkännande: $e',
            );
          }
          AppLogger.success(
            '✅ Profil skapad automatiskt: ${_currentUserProfile!.displayName}',
          );
        } else {
          // BUG-13: the lazy auto-create returned null (e.g. permission-denied /
          // App Check / unavailable during createOrUpdateProfile). Surface a
          // user-visible error so AuthWrapper can show a retryable error state
          // instead of an indefinite spinner. createOrUpdateProfile already set
          // a specific _error; only fall back to the generic message if it didn't.
          AppLogger.error('❌ Kunde inte skapa profil automatiskt');
          if (!hasError) {
            _setError(AppLocale.current.errorCouldNotLoadProfile);
          }
        }
      }

      if (_currentUserProfile != null) {
        _cacheProfile(user.uid, _currentUserProfile!);
        AppLogger.info(
          '👤 Nuvarande profil laddad: ${_currentUserProfile!.displayName}',
        );
      } else {
        AppLogger.warning(
          '⚠️ Kunde inte ladda eller skapa profil för användare',
        );
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda nuvarande profil: $e');
      _setError(AppLocale.current.errorCouldNotLoadProfile);
      notifyListeners();
    }
  }

  /// BUG-13: Clear the load/create error and re-run the profile load.
  /// Wired to the "Försök igen" button in AuthWrapper's error state so a
  /// transient profile-load failure (permission-denied / App Check / unavailable)
  /// is recoverable without a full sign-out. No-op-safe when already loaded.
  Future<void> retryLoadProfile() async {
    _clearError();
    notifyListeners();
    await _loadCurrentUserProfile();
  }

  /// Ensures base user document exists in 'users' collection for friends system
  Future<void> _ensureBaseUserDocument(String userId) async {
    try {
      await _repository.ensureBaseUserDocument(userId);

      AppLogger.info(
        '✅ Base user document ensured for: ${userId.maskedUserId}',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Could not ensure base user document: $e');
      // Don't throw - this is not critical for user functionality
    }
  }

  Future<UserProfile?> _getProfileFromRepository(String userId) async {
    try {
      return await _repository.fetchProfile(userId);
    } catch (e) {
      AppLogger.error('❌ Kunde inte hämta profil ${userId.maskedUserId}: $e');
      return null;
    }
  }

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
    _currentUserProfile = null;
    _profileCache.clear();
    _cacheTimestamps.clear();
    _clearError();
  }

  void _clearError() {
    _error = null;
  }

  /// LRU cache insert: removes existing key (resets order), inserts at end, evicts oldest if over cap.
  void _cacheProfile(String userId, UserProfile profile) {
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
    _profileCache[userId] = profile;
    _cacheTimestamps[userId] = clock.now();
    if (_profileCache.length > _maxCacheSize) {
      final oldest = _profileCache.keys.first;
      _profileCache.remove(oldest);
      _cacheTimestamps.remove(oldest);
    }
  }

  /// Public error clearing
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Update user's FCM token for push notifications
  Future<void> updateFCMToken(String token) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
      AppLogger.warning('⚠️ Cannot update FCM token - no current user');
      return;
    }

    try {
      AppLogger.info('🔔 Updating FCM token for user: ${userId.maskedUserId}');

      await _repository.updateFCMToken(userId, token);

      _currentUserProfile = _currentUserProfile!.copyWith(
        fcmToken: token,
        fcmTokenUpdatedAt: clock.now(),
      );

      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();

      AppLogger.success('✅ FCM token updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update FCM token', e);
      _setError(AppLocale.current.errorCouldNotUpdateNotificationToken);
    }
  }

  /// Update user's notification preferences
  Future<void> updateNotificationSettings(bool enabled) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
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

      _currentUserProfile = _currentUserProfile!.copyWith(
        notificationsEnabled: enabled,
      );

      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();

      AppLogger.success('✅ Notification settings updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update notification settings', e);
      _setError(AppLocale.current.errorCouldNotUpdateNotificationSettings);
    }
  }

  /// Update user's allergen preferences.
  Future<bool> updateAllergenPreferences(
    UserAllergenPreferences preferences,
  ) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
      AppLogger.warning(
        '⚠️ Cannot update allergen preferences - no current user',
      );
      return false;
    }

    try {
      _setLoading(true);
      _clearError();
      AppLogger.info(
        '🍽️ Updating allergen preferences for user: ${userId.maskedUserId}',
      );

      await _repository.updateAllergenPreferences(userId, preferences);

      _currentUserProfile = _currentUserProfile!.copyWith(
        allergenPreferences: preferences,
      );

      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();

      AppLogger.success('✅ Allergen preferences updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update allergen preferences', e);
      _setError(AppLocale.current.errorCouldNotUpdateAllergenSettings);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Mark onboarding as completed for the current user.
  Future<void> markOnboardingComplete() async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) return;

    try {
      final updated = _currentUserProfile!.copyWith(
        hasCompletedOnboarding: true,
      );
      await _repository.saveProfile(
        updated,
        writeHouseholdSize:
            false, // onboarding never edits it (BUT-1322 review)
      );

      _currentUserProfile = updated;
      _cacheProfile(userId, updated);
      notifyListeners();

      AppLogger.success('Onboarding marked as complete');
    } catch (e) {
      AppLogger.error('Failed to mark onboarding complete', e);
      rethrow;
    }
  }

  /// BUT-1050: persist the "auto-add bought shopping items to pantry" preference
  /// (the Settings toggle). Optimistically updates the in-memory profile after
  /// the targeted single-field write succeeds.
  Future<void> setAutoAddToPantry(bool enabled) async {
    final userId = currentUserId;
    final profile = _currentUserProfile;
    if (userId == null || profile == null) {
      AppLogger.warning('⚠️ Cannot set auto-add-to-pantry - no current user');
      return;
    }

    try {
      await _repository.setAutoAddBoughtToPantry(userId, enabled);
      _currentUserProfile = profile.copyWith(autoAddBoughtToPantry: enabled);
      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to set auto-add-to-pantry', e);
      rethrow;
    }
  }

  /// BUT-1050: persist that the one-time first-checkoff prompt has been shown,
  /// so it never re-nags across sessions/devices. Idempotent and best-effort —
  /// a no-op when there's no profile or the flag is already set.
  Future<void> markPantryAutoAddPrompted() async {
    final userId = currentUserId;
    final profile = _currentUserProfile;
    if (userId == null || profile == null) return;
    if (profile.pantryAutoAddPrompted) return;

    try {
      await _repository.markPantryAutoAddPrompted(userId);
      _currentUserProfile = profile.copyWith(pantryAutoAddPrompted: true);
      _cacheProfile(userId, _currentUserProfile!);
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to mark pantry auto-add prompted', e);
    }
  }

  /// BUT-1220: persist that the one-time activity-feed hint has been shown, so
  /// it never fires again across sessions/devices. Idempotent and best-effort —
  /// a no-op when there's no profile or the flag is already set.
  Future<void> markActivityFeedHintSeen() async {
    final userId = currentUserId;
    final profile = _currentUserProfile;
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
      _currentUserProfile = updated;
      _cacheProfile(userId, updated);
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to persist activity-feed hint flag: $e');
    }
  }

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
  }) async {
    final userId = currentUserId;
    if (userId == null || _currentUserProfile == null) {
      throw StateError('No current user for onboarding completion');
    }

    final updated = _currentUserProfile!.copyWith(
      allergenPreferences:
          preferences ?? _currentUserProfile!.allergenPreferences,
      hasCompletedOnboarding: true,
      onboardingSkippedAt: onboardingSkippedAt,
    );
    await _repository.saveProfile(
      updated,
      writeHouseholdSize: false, // onboarding never edits it (BUT-1322 review)
    );

    _currentUserProfile = updated;
    _cacheProfile(userId, updated);
    notifyListeners();
  }

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      AppLogger.info('🔔 Clearing FCM token for user: ${userId.maskedUserId}');

      await _repository.clearFCMToken(userId);

      if (_currentUserProfile != null) {
        _currentUserProfile = _currentUserProfile!.copyWith(
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        );
        _cacheProfile(userId, _currentUserProfile!);
        notifyListeners();
      }

      AppLogger.success('✅ FCM token cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to clear FCM token', e);
    }
  }

  /// Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
    AppLogger.info('🗑️ Profil-cache rensad');
  }

  @override
  Future<void> dispose() async {
    await disposeStreamResources();
    clearCache();
    super.dispose();
  }
}
