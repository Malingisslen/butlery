import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// Repository interface for user profile data operations and management.
/// This interface extends the base Repository pattern to provide specialized
/// user profile operations including profile management, statistics tracking,
/// notification settings, and social features integration. It manages user
/// data persistence and synchronization across the Butlery social platform.
/// **Key User Operations:**
/// - **Profile Management**: CRUD operations for user profiles and settings
/// - **Statistics Tracking**: Friend counts, recipe metrics, and activity stats
/// - **Notification Management**: FCM token handling and notification preferences
/// - **Search and Discovery**: User search and profile discovery features
/// - **Social Integration**: Base user document management for social features
/// - **Online Status**: Real-time presence and availability tracking
/// **Social Platform Integration:**
/// This repository serves as the foundation for social features by managing
/// user profiles that integrate with friends, groups, and sharing systems.
/// It ensures consistent user data across all social interactions.
/// **Firebase Integration:**
/// Manages user profiles in Firestore with proper indexing for search and
/// discovery features. Also handles FCM token management for push notifications
/// and maintains user presence information for social features.
/// **Usage Examples:**
/// ```dart
/// final userRepo = ServiceLocator.get<UserRepository>();
/// // Create or update user profile
/// final profile = UserProfile(
///   id: currentUserId,
///   displayName: 'John Doe',
///   email: 'john@example.com',
/// );
/// await userRepo.saveProfile(profile);
/// // Search for users
/// final searchResults = await userRepo.searchProfiles('john');
/// for (final user in searchResults) {
///   displayUserCard(user);
/// }
/// // Update notification settings
/// await userRepo.updateNotificationSettings(userId, true);
/// await userRepo.updateFCMToken(userId, fcmToken);
/// ```
abstract class UserRepository extends Repository<UserProfile> {
  /// Persist the given profile (create or update).
  ///
  /// [writeHouseholdSize] (BUT-1322 review): when false, the `householdSize`
  /// key is OMITTED from the private-settings merge write so the stored value
  /// survives. An in-memory null is ambiguous — it can mean "cleared" or
  /// "settings sub-doc read failed/degraded" — and only the editing surface
  /// knows the user's intent. Callers that did not deliberately change the
  /// field must pass false, or an unrelated profile save after a degraded
  /// load would silently wipe the stored setting.
  Future<void> saveProfile(UserProfile profile, {bool writeHouseholdSize});

  /// Fetch a profile by id.
  Future<UserProfile?> fetchProfile(String userId);

  /// Authoritative SERVER read of a user's current `isSearchable` flag from
  /// public_profiles — deliberately NOT cache-first (see the implementation).
  ///
  /// BUT-1637: [UserService.createOrUpdateProfile] uses this to decide whether
  /// to restore a minor's opt-in after a full-document save clobbers
  /// `public_profiles.isSearchable` (the [UserProfile.toFirestore] chokepoint).
  /// A cache-first read could report a stale `true` after the user opted out on
  /// another device, which would let an unrelated save silently re-grant
  /// discoverability they turned off. Returns false for a missing doc; throws
  /// on an unreachable server (callers fail closed → treat as not searchable).
  Future<bool> fetchPersistedSearchable(String userId);

  /// Fetch multiple profiles by their ids.
  Future<List<UserProfile>> fetchProfiles(List<String> userIds);

  /// Update statistics for a profile.
  Future<void> updateProfileStats(
    String userId, {
    int? friendsCount,
    int? publicRecipeCount,
  });

  /// Update the online status for a user.
  Future<void> updateOnlineStatus(String userId, bool isOnline);

  /// Search for profiles matching a query.
  Future<List<UserProfile>> searchProfiles(String query);

  /// Like [searchProfiles] but carries a `failed` flag (BUT-1442): true when
  /// every query attempt errored (a backend outage) rather than legitimately
  /// matching zero profiles, so callers can show a degraded notice instead of
  /// a neutral "no results" state. A successful zero-match search has
  /// `failed == false`. [searchProfiles] delegates to this and returns `.hits`.
  Future<SearchResult<UserProfile>> searchProfilesResult(String query);

  /// Check if a display name is available
  Future<bool> isDisplayNameAvailable(String displayName);

  /// Update FCM token for push notifications
  Future<void> updateFCMToken(String userId, String token);

  /// Update notification settings
  Future<void> updateNotificationSettings(String userId, bool enabled);

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken(String userId);

  /// Ensure base user document exists in 'users' collection for friends system
  Future<void> ensureBaseUserDocument(String userId);

  /// Increment public recipe count when a recipe is created or shared publicly
  Future<void> incrementPublicRecipeCount(String userId);

  /// Decrement public recipe count when a recipe is deleted or made private
  Future<void> decrementPublicRecipeCount(String userId);

  /// Update allergen preferences for a user
  Future<void> updateAllergenPreferences(
    String userId,
    UserAllergenPreferences preferences,
  );

  /// BUT-1220: persist the one-time activity-feed hint flag with a targeted
  /// single-field `update()` — never a full-document set. A background/automatic
  /// profile mutation must not clobber fields owned by other writers
  /// (`friendsCount`, mutated by friend-creation transactions) or moderators
  /// (`isHidden`/`hiddenAt`), which a stale full-profile set would do.
  Future<void> markActivityFeedHintSeen(String userId);

  /// BUT-1050: persist the auto-add-bought-to-pantry preference with a targeted
  /// single-field set on the private settings sub-doc — never a full-document
  /// set (same clobber-safety reasoning as [markActivityFeedHintSeen]).
  Future<void> setAutoAddBoughtToPantry(String userId, bool enabled);

  /// BUT-1465: persist the household-allergen-filter opt-out with a targeted
  /// single-field set on the private settings sub-doc (same clobber-safety
  /// reasoning as [setAutoAddBoughtToPantry]). `enabled` = filter by the whole
  /// household's allergens; false = owner's allergens only.
  Future<void> setUseHouseholdAllergens(String userId, bool enabled);

  /// BUT-1050: persist that the one-time "add bought items to pantry?" prompt
  /// has been shown, with a targeted single-field set on the private settings
  /// sub-doc.
  Future<void> markPantryAutoAddPrompted(String userId);

  /// Delete the `public_profiles/{userId}` document. GDPR Art. 17.
  /// Caller must own the profile (enforced via `validateOwnership`).
  Future<bool> deletePublicProfile(String userId);

  /// Delete the `users/{userId}` root document. GDPR Art. 17.
  /// Note: this targets the `users` collection (not `public_profiles`,
  /// where `collectionName` points). Caller must own the document.
  Future<bool> deleteUserRootDoc(String userId);

  /// BUT-1400: persist a Terms-of-Service acceptance record (`termsAcceptedAt`
  /// + `termsVersion`) on `users/{userId}`. Written once at account creation
  /// so we can demonstrate when, and to which ToS version, a user agreed —
  /// the accountability record the UI-only checkbox never produced. Caller
  /// must own the document (`validateSelfOperation`).
  Future<void> recordTermsAcceptance(String userId, String termsVersion);
}
