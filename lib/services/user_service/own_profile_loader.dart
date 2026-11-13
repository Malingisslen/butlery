import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/account/terms_acceptance.dart';
import 'package:butlery/services/guest/new_profile_defaults.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/user_service/own_profile_port.dart';
import 'package:butlery/services/user_service/user_settings_writer.dart';

/// The "not passed" sentinel [UserService] gives [OwnProfileLoader.createOrUpdateProfile].
const Object _unset = UserService.avatarUntouched;

/// Loads and creates the own profile for [UserService], through the facade's
/// state in [OwnProfilePort].
class OwnProfileLoader with ErrorHandlingMixin {
  OwnProfileLoader({
    required OwnProfilePort port,
    required UserRepository repository,
    required AuthRepository authRepository,
    required UserSettingsWriter settings,
  }) : _port = port,
       _repository = repository,
       _authRepository = authRepository,
       _settings = settings;

  final OwnProfilePort _port;
  final UserRepository _repository;
  final AuthRepository _authRepository;
  final UserSettingsWriter _settings;

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
    // BUT-1322: sentinel default (not plain null) so callers that don't pass
    // the field (auto-creation, social handler) can't wipe a saved household
    // size, while an explicit null still clears it back to "recipe default".
    Object? householdSize = _unset,
    // Only read when no profile exists yet (NewProfileDefaults).
    bool newProfileCompletedOnboarding = false,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _port.setError(AppLocale.current.errorNoUserLoggedIn);
      return null;
    }

    try {
      _port.setLoading(true);
      _port.clearError();

      // Prefer in-memory profile to avoid re-fetching, which can silently lose
      // hasCompletedOnboarding if the private settings sub-doc fetch fails (BUG-044).
      // Tradeoff: won't pick up changes made on other devices since last load.
      final inMemory = _port.profile;
      final existingProfile = inMemory?.uid == user.uid
          ? inMemory
          : await _repository.fetchProfile(user.uid);
      if (!_isStillSignedInAs(user.uid)) return null;

      UserProfile profile;
      if (existingProfile != null) {
        // Only pass cooking identity fields when caller provides them,
        // so other callers (auto-creation, social handler) don't wipe them.
        profile = existingProfile.copyWith(
          displayName: displayName,
          avatarUrl: identical(avatarUrl, _unset)
              ? existingProfile.avatarUrl
              : avatarUrl as String?,
          isSearchable: isSearchable,
          allowEmailSearch: allowEmailSearch,
          lastActiveAt: clock.now(),
        );
        if (!identical(cookingSkillLevel, _unset)) {
          profile = profile.copyWith(
            cookingSkillLevel: cookingSkillLevel as CookingSkillLevel?,
          );
        }
        if (!identical(cuisineAffinities, _unset)) {
          profile = profile.copyWith(
            cuisineAffinities: cuisineAffinities as List<String>?,
          );
        }
        if (!identical(bio, _unset)) {
          profile = profile.copyWith(bio: bio as String?);
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
          avatarUrl: identical(avatarUrl, _unset) ? null : avatarUrl as String?,
          isSearchable: isSearchable ?? true,
          allowEmailSearch: allowEmailSearch ?? false,
          publicRecipeCount: 0,
          friendsCount: 0,
          joinedAt: now,
          lastActiveAt: now,
          isOnline: true,
          // This service is writing the first settings doc right now, so the
          // settings ARE known: empty. Left false, the menu would treat the
          // whole first session as a failed read and filter by the
          // common-allergen floor (HouseholdService.ownMenuPreferences).
          settingsMerged: true,
          showOnlineStatus: showOnlineStatus ?? true,
          shareActivityToFeed: shareActivityToFeed ?? true,
          activityFeedEventTypes: activityFeedEventTypes ?? const {},
          cookingSkillLevel: identical(cookingSkillLevel, _unset)
              ? null
              : cookingSkillLevel as CookingSkillLevel?,
          cuisineAffinities: identical(cuisineAffinities, _unset)
              ? null
              : cuisineAffinities as List<String>?,
          bio: identical(bio, _unset) ? null : bio as String?,
          householdSize: identical(householdSize, _unset)
              ? null
              : householdSize as int?,
          hasCompletedOnboarding: newProfileCompletedOnboarding,
        );
      }

      // BUT-1637 (data-safety): decide whether the post-save re-assert may
      // restore this minor's discoverability BEFORE the save below clobbers it.
      // Read the AUTHORITATIVE server value — not the possibly-stale in-memory
      // `existingProfile` — so an opt-out made on another device can never be
      // silently re-granted by an unrelated profile edit, and an explicit
      // `isSearchable:false` on THIS save is honoured. Fail closed: a read the
      // server can't answer (offline) leaves the minor not searchable.
      var minorReassertSearchable = false;
      var minorSearchabilityReadFailed = false;
      if (profile.isMinor && isSearchable != false) {
        try {
          minorReassertSearchable = await _repository.fetchPersistedSearchable(
            user.uid,
          );
        } catch (e) {
          AppLogger.warning(
            'Could not read persisted minor searchability; leaving it off: $e',
          );
          minorReassertSearchable = false;
          minorSearchabilityReadFailed = true;
        }
      }

      if (!_isStillSignedInAs(user.uid)) return null;

      // BUT-1322 (review): only write the householdSize key when the caller
      // deliberately set/cleared it — see UserRepository.saveProfile.
      await _repository.saveProfile(
        profile,
        writeHouseholdSize: !identical(householdSize, _unset),
        writeAvatarUrl: !identical(avatarUrl, _unset),
      );

      // BUT-1629: [UserProfile.toFirestore] forces `isSearchable:false` for a
      // minor — deliberately, so no client write can make one discoverable.
      // The side effect is that EVERY full-document profile save silently
      // revokes an opted-in minor's discoverability, whatever the save was
      // actually about (bio, avatar, household size…). Compensate here, at the
      // same layer as the chokepoint, so all three call sites inherit it
      // instead of each having to remember.
      var savedProfile = profile;
      // The searchability callable acts on whoever is signed in NOW, so after
      // a switch it would re-assert the other account's discoverability.
      if (!_isStillSignedInAs(user.uid)) return savedProfile;
      if (profile.isMinor) {
        // Gated on [minorReassertSearchable] — the fresh, server-authoritative
        // pre-save value. This restores an EXISTING opt-in, never grants a new
        // one, and can never re-grant one the user disabled elsewhere.
        final actuallySearchable =
            minorReassertSearchable &&
            await _settings.callSetSearchable(true) == true;
        // Carry the server's real answer, never the requested one: a privacy
        // toggle that renders the opposite of reality is worse than the
        // revocation itself.
        savedProfile = profile.copyWith(isSearchable: actuallySearchable);
        // Surface the revocation whenever it was NOT the user's intent on this
        // save: either the re-assert callable failed, OR the pre-save server
        // read failed while the (stale) in-memory value said they were opted in
        // — otherwise an opted-in minor silently loses discoverability on an
        // unrelated bio/avatar edit and must rediscover the toggle. A minor who
        // was already not-searchable gets no spurious error (the stale-value
        // guard), and the profile still saves fail-closed either way.
        final staleOptedIn = existingProfile?.isSearchable == true;
        final revokedUnintentionally =
            (minorReassertSearchable && !actuallySearchable) ||
            (minorSearchabilityReadFailed && staleOptedIn);
        if (revokedUnintentionally && _isStillSignedInAs(user.uid)) {
          _port.setError(AppLocale.current.errorCouldNotUpdateSearchability);
        }
      }

      if (!_isStillSignedInAs(user.uid)) return savedProfile;
      _port.profile = savedProfile;
      _port.cacheProfile(user.uid, savedProfile);

      // Profile propagation handled by Cloud Function (on-profile-updated.ts)

      AppLogger.success('Profil sparad: ${profile.displayName.maskedName}');
      _port.notifyListeners();
      return savedProfile;
    } catch (e) {
      AppLogger.error('❌ Kunde inte spara profil: $e');
      if (_isStillSignedInAs(user.uid)) _port.setError(extractUserMessage(e));
      return null;
    } finally {
      _port.setLoading(false);
    }
  }

  Future<void>? _loadInFlight;
  String? _loadInFlightUid;

  /// At sign-in both `initialize` and the auth listener start a load. For the
  /// same account they share one, so the second cannot create the profile a
  /// second time. A retry or the load after accepting the terms calls
  /// [loadCurrentUserProfile] and always reads afresh.
  Future<void> loadCurrentUserProfileShared() {
    final uid = _authRepository.currentUser?.uid;
    final inFlight = _loadInFlight;
    if (inFlight != null && uid == _loadInFlightUid) return inFlight;
    final load = loadCurrentUserProfile();
    _loadInFlight = load;
    _loadInFlightUid = uid;
    return load.whenComplete(() {
      if (identical(_loadInFlight, load)) {
        _loadInFlight = null;
        _loadInFlightUid = null;
      }
    });
  }

  Future<void> loadCurrentUserProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    // Every await below can outlive a switch of account; what it brings back
    // then belongs to the account that left, so it is dropped rather than
    // installed in, cached for or written on behalf of the one now signed in.
    bool switched() => !_isStillSignedInAs(user.uid);

    try {
      // BUT-916 C1: checked BEFORE anything is written for the account.
      UserProfile? fetched;
      if (_signsInWithProviderOnly(user)) {
        fetched = await _repository.fetchProfile(user.uid);
        if (switched()) return;
        if (fetched == null && user.email == null) {
          _port.setError(AppLocale.current.providerTermsNoEmail);
          return;
        }
        // The profile decides, not a terms record: an earlier answer whose
        // profile was never made is asked again, so the profile is only made
        // from the name the user confirmed, never the provider's full name.
        if (fetched == null) {
          _port.setTermsPending(true);
          _port.notifyListeners();
          return;
        }
      }
      _port.setTermsPending(false);

      // NYTT: Skapa base user document i 'users' collection för friends system
      await _ensureBaseUserDocument(user.uid);
      if (switched()) return;

      // BUT-2264: the address is not on the public document; Auth holds it.
      final loaded = (fetched ?? await _repository.fetchProfile(user.uid))
          ?.copyWith(email: user.email.orEmpty());
      if (switched()) return;
      _port.profile = loaded;

      // NY: Om profil inte finns, skapa en automatiskt
      if (_port.profile == null && NewProfileDefaults.appliesTo(user)) {
        AppLogger.info(
          '👤 Ingen profil hittad - skapar automatiskt för ${user.uid.maskedUserId}',
        );
        final defaults = NewProfileDefaults.forUser(
          user,
          registrationName: _authRepository.registrationDisplayNameFor,
        );
        final created = await createOrUpdateProfile(
          displayName: defaults.displayName,
          isSearchable: defaults.isSearchable,
          allowEmailSearch: false,
          newProfileCompletedOnboarding: defaults.completedOnboarding,
        );
        if (switched()) return;
        _port.profile = created;

        if (_port.profile != null) {
          // This branch only runs when no profile existed yet, which is the
          // account-creation moment.
          await recordTermsAcceptance(_repository, user.uid);
          AppLogger.success(
            '✅ Profil skapad automatiskt: ${_port.profile!.displayName}',
          );
        } else {
          // BUG-13: the lazy auto-create returned null (e.g. permission-denied /
          // App Check / unavailable during createOrUpdateProfile). Surface a
          // user-visible error so AuthWrapper can show a retryable error state
          // instead of an indefinite spinner. createOrUpdateProfile already set
          // a specific _error; only fall back to the generic message if it didn't.
          AppLogger.error('❌ Kunde inte skapa profil automatiskt');
          if (!_port.hasError) {
            _port.setError(AppLocale.current.errorCouldNotLoadProfile);
          }
        }
      }

      if (switched()) return;
      if (_port.profile != null) {
        _port.cacheProfile(user.uid, _port.profile!);
        AppLogger.info(
          '👤 Nuvarande profil laddad: ${_port.profile!.displayName}',
        );
      } else if (user.email == null && !user.isAnonymous) {
        // C2: no address means no profile can be made; a retryable error,
        // never the endless busy screen. A guest (anonymous) has no address
        // by design and is not a failed Google/Apple sign-up (BUT-920).
        _port.setError(AppLocale.current.providerTermsNoEmail);
      } else {
        AppLogger.warning(
          '⚠️ Kunde inte ladda eller skapa profil för användare',
        );
      }

      _port.notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda nuvarande profil: $e');
      if (switched()) return;
      _port.setError(AppLocale.current.errorCouldNotLoadProfile);
      _port.notifyListeners();
    }
  }

  bool _isStillSignedInAs(String uid) =>
      _authRepository.currentUser?.uid == uid;

  static bool _signsInWithProviderOnly(User user) {
    final ids = user.providerData.map((info) => info.providerId);
    return ids.isNotEmpty && !ids.contains('password');
  }

  Future<bool> acceptProviderTerms({required String displayName}) async {
    final user = _authRepository.currentUser;
    if (user == null) return false;
    _port.clearError();
    try {
      await _repository.recordTermsAcceptance(
        user.uid,
        UserService.currentTermsVersion,
      );
    } catch (e) {
      AppLogger.warning('Terms acceptance not recorded: $e');
      if (_isStillSignedInAs(user.uid)) {
        _port.setError(AppLocale.current.providerTermsSaveFailed);
      }
      return false;
    }
    if (!_isStillSignedInAs(user.uid)) return false;
    _port.setTermsPending(false);
    final created = await createOrUpdateProfile(
      displayName: displayName,
      isSearchable: true,
      allowEmailSearch: false,
    );
    if (!_isStillSignedInAs(user.uid)) return false;
    if (created == null) {
      if (!_port.hasError) {
        _port.setError(AppLocale.current.providerTermsSaveFailed);
      }
      return false;
    }
    await loadCurrentUserProfile();
    return true;
  }

  Future<void> retryLoadProfile() async {
    _port.clearError();
    _port.notifyListeners();
    await loadCurrentUserProfile();
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
}
