import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/user_service/profile_cache.dart';

/// Reads other people's profiles (and the own one, by uid) for [UserService],
/// through the cache it shares with the service.
class ProfileLookups with ErrorHandlingMixin {
  ProfileLookups({
    required UserRepository repository,
    required AuthRepository authRepository,
    required ProfileCache cache,
  }) : _repository = repository,
       _authRepository = authRepository,
       _cache = cache;

  final UserRepository _repository;
  final AuthRepository _authRepository;
  final ProfileCache _cache;

  /// Get user profile by ID (with caching)
  Future<UserProfile?> getUserProfile(String userId) async {
    // Check cache first
    if (_cache.containsKey(userId) && !_cache.isExpired(userId)) {
      return _cache[userId]!;
    }

    // Fetch from repository
    final profile = await safeExecute(
      () async {
        final profile = await _getProfileFromRepository(userId);
        if (profile != null) {
          _cache.put(userId, profile);
        }
        return profile;
      },
      operationName: 'Get user profile',
    );

    return profile;
  }

  /// Get multiple profiles efficiently (batch). Reports which ids, if any,
  /// could not be resolved — and whether that is because they are confirmed
  /// absent or because the read itself failed — rather than silently
  /// returning a subset that looks complete (BUT-2027).
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) {
      return const ProfileBatchLookup(
        profiles: [],
        missingIds: {},
        unavailableIds: {},
      );
    }

    final results = <UserProfile>[];
    final uncachedIds = <String>[];

    // Check cache first
    for (final userId in userIds) {
      if (_cache.containsKey(userId)) {
        final cached = _cache[userId]!;
        if (!_cache.isExpired(userId)) {
          results.add(cached);
        } else {
          uncachedIds.add(userId);
        }
      } else {
        uncachedIds.add(userId);
      }
    }

    if (uncachedIds.isEmpty) {
      return ProfileBatchLookup(
        profiles: results,
        missingIds: const {},
        unavailableIds: const {},
      );
    }

    try {
      final fetched = await _repository.fetchProfiles(uncachedIds);
      for (final profile in fetched) {
        results.add(profile);
        _cache.put(profile.uid, profile);
      }
      // The call returned, so every id it was asked for and did not return
      // is a CONFIRMED absence, not a dropped read.
      final fetchedIds = fetched.map((p) => p.uid).toSet();
      final missing = uncachedIds
          .where((id) => !fetchedIds.contains(id))
          .toSet();
      return ProfileBatchLookup(
        profiles: results,
        missingIds: missing,
        unavailableIds: const {},
      );
    } catch (e) {
      AppLogger.error('❌ Kunde inte hämta profilbatch: $e');
      // The call threw, so nothing about these ids is known — they are
      // UNAVAILABLE, never folded into "missing" or dropped outright.
      return ProfileBatchLookup(
        profiles: results,
        missingIds: const {},
        unavailableIds: uncachedIds.toSet(),
      );
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

  /// BUT-1663: a profile read that keeps "absent" and "failed" apart.
  ///
  /// [getUserProfile] cannot answer this: `_getProfileFromRepository` catches
  /// and returns null, and `safeExecute` catches again, so a deleted account
  /// and a dropped connection are the same null by the time a caller sees it.
  /// The repository DOES distinguish them — `fetchProfile` returns null for a
  /// missing document and rethrows on a read error — so this goes to the
  /// repository directly rather than through either swallow.
  ///
  /// Reuses the same 30-minute cache as [getUserProfile]: the household
  /// allergen union calls this once per member per menu generation, and an
  /// uncached read would add a Firestore read per member per generation.
  Future<ProfileLookup> lookupUserProfile(String userId) async {
    // Only the signed-in user's own settings are ever readable, so only their
    // profile can be "settings-merged". For anyone else the flag is always
    // false and means nothing — the caller already knows their preferences are
    // unreachable and compensates.
    final isSelf = userId == _authRepository.currentUser?.uid;

    // A cached self-profile that was never settings-merged is NOT usable here.
    // `getUserProfiles` fills this same cache from `fetchProfiles`, which
    // batch-reads public_profiles only — so the roster screen can leave the
    // owner cached with no preferences and no failure recorded. Serving that
    // as `found` would read the user's own allergens as "declared none".
    final cached = _cache[userId];
    if (cached != null && !_cache.isExpired(userId)) {
      if (!isSelf || cached.settingsMerged) return ProfileLookup.found(cached);
    }

    try {
      final profile = await _repository.fetchProfile(userId);
      if (profile == null) {
        // A stale roster id genuinely points at nobody — but the SIGNED-IN
        // user is definitionally at the table. Their public profile doc going
        // absent is a broken state (a half-completed save leaves the settings
        // sub-doc behind), not a person who left, so it must fail safe rather
        // than drop them from the union as "nobody to protect".
        return isSelf
            ? const ProfileLookup.unavailable()
            : const ProfileLookup.missing();
      }

      if (isSelf && !profile.settingsMerged) {
        // Read succeeded, preferences did not. Do NOT cache it: a one-second
        // blip would otherwise pin the household to the cautious floor for the
        // full 30 minutes, and hand a preference-less profile to every other
        // cache consumer.
        return ProfileLookup.foundSettingsUnavailable(profile);
      }
      _cache.put(userId, profile);
      return ProfileLookup.found(profile);
    } catch (e) {
      AppLogger.error('Profile lookup failed for ${userId.maskedUserId}: $e');
      return const ProfileLookup.unavailable();
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
}
