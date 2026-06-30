// lib/repositories/firebase/firebase_user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/modules/user_root_deletion_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Firebase Firestore implementation for user profile management and social discovery.
/// This repository implements the [UserRepository] interface using Firebase Firestore,
/// managing user profiles in the `public_profiles` collection with comprehensive search,
/// statistics tracking, and notification management. It provides the foundation for
/// social features while maintaining privacy and security controls.
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] to eliminate 45 lines of duplicate CRUD code while
/// providing specialized user profile operations. Uses the `public_profiles` collection
/// for searchable user data and integrates with authentication for security validation.
/// **Security and Privacy:**
/// - **Self-Operation Validation**: Users can only modify their own profiles and settings
/// - **Permission Logging**: Comprehensive audit trail for all profile operations
/// - **Field Validation**: Ensures data integrity for required profile fields
/// - **Privacy Controls**: Supports searchable profiles and email search opt-in
/// - **FCM Security**: Validates token updates to prevent unauthorized access
/// **Search and Discovery:**
/// - **Name Search**: Efficient searchable display name indexing with `displayNameLower`
/// - **Email Search**: Optional email-based discovery with user consent
/// - **Fallback Search**: Graceful degradation when indexed search fails
/// - **Search Privacy**: Users can control searchability through `isSearchable` flag
/// - **Result Ranking**: Prioritizes exact matches and alphabetical ordering
/// **Profile Statistics:**
/// Tracks and maintains user statistics including friend counts, recipe counts,
/// and activity metrics for profile display and social features integration.
/// **Notification Integration:**
/// - **FCM Token Management**: Secure FCM token storage and updates for push notifications
/// - **Notification Settings**: User-controlled notification preferences
/// - **Token Cleanup**: Proper token cleanup on logout for security
/// - **Timestamp Tracking**: FCM token update timestamps for debugging
/// **Usage Examples:**
/// ```dart
/// final userRepo = FirebaseUserRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Create/update profile with validation
/// final profile = UserProfile(
///   uid: currentUserId,
///   displayName: 'John Doe',
///   isSearchable: true,
/// );
/// await userRepo.saveProfile(profile);
/// // Search for users
/// final results = await userRepo.searchProfiles('john');
/// // Update notifications
/// await userRepo.updateFCMToken(userId, fcmToken);
/// await userRepo.updateNotificationSettings(userId, true);
/// ```
class FirebaseUserRepository extends BaseFirebaseRepository<UserProfile>
    with UserRootDeletionMixin
    implements UserRepository {
  FirebaseUserRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : super(
         authRepository: authRepository ?? FirebaseAuthRepository(),
       );
  @override
  String get collectionName => FirestoreCollections.publicProfiles;

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String userId) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userSettings)
          .doc('preferences');

  @override
  Future<bool> validateCreatePermission(
    String userId,
    UserProfile entity,
  ) async {
    // Users can only create their own profile
    // This prevents users from creating fake profiles for other users
    return userId == entity.uid;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    UserProfile? entity,
  ) async {
    // Anyone authenticated can read public profiles (for social features)
    // This enables friend search, recipe sharing, and social discovery
    // Privacy is controlled via the isSearchable flag within the profile
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    UserProfile entity,
  ) async {
    // Users can only update their own profile
    // This prevents unauthorized profile modifications
    return userId == entity.uid && userId == resourceId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Users can only delete their own profile
    // This supports GDPR Article 17 (Right to Erasure)
    return userId == resourceId;
  }

  /// Create or update the current user's profile.
  @override
  Future<void> saveProfile(UserProfile profile) async {
    // Validate user is updating their own profile
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: profile.uid,
      operation: 'update profile',
    );

    // Validate required fields (uid is not in toFirestore, it's the document ID)
    validateRequiredFields(
      data: profile.toFirestore(),
      requiredFields: ['displayName', 'email'],
      resourceType: 'user_profile',
    );

    // BUT-1285: write only owner-editable public fields with merge, so we never
    // clobber friendsCount (mutated by friend-creation transactions) or
    // moderator-owned isHidden/hiddenAt. A full set() with a stale in-memory
    // profile would silently revert a concurrent friend's count, and a stale
    // isHidden:false would trip the rules' diff() guard and reject every edit a
    // moderation-hidden user tries to make. Acceptance (BUT-1285): the write
    // uses toFirestoreEditable(), which excludes friendsCount/isHidden/hiddenAt
    // (see the regression guard in firebase_user_repository_test.dart).
    final data = profile.toFirestoreEditable();
    data['displayNameLower'] = profile.displayName.toLowerCase();
    await Future.wait([
      collection.doc(profile.uid).set(data, SetOptions(merge: true)),
      _settingsDoc(
        profile.uid,
      ).set(profile.toPrivateSettings(), SetOptions(merge: true)),
    ]);

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update',
      granted: true,
    );
  }

  /// Fetch a profile by id. Returns `null` if it doesn't exist.
  ///
  /// Uses cache-first strategy since profile display is non-critical
  /// and profiles rarely change mid-session.
  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final profile = await readCacheFirst(userId);
    if (profile == null) return null;
    final currentUserId = authRepository.currentUser?.uid;
    if (currentUserId != null && currentUserId == userId) {
      try {
        final settingsDoc = await _settingsDoc(userId).get();
        if (settingsDoc.exists && settingsDoc.data() != null) {
          final s = settingsDoc.data()!;
          return profile.copyWith(
            fcmToken: s['fcmToken'] as String?,
            fcmTokenUpdatedAt: SerializationUtils.parseDateTimeValue(
              s['fcmTokenUpdatedAt'],
            ),
            notificationsEnabled: s['notificationsEnabled'] as bool? ?? true,
            preferredLocale: s['preferredLocale'] as String?,
            allergenPreferences: s['allergenPreferences'] != null
                ? UserAllergenPreferences.fromFirestore(
                    s['allergenPreferences'] as Map<String, dynamic>,
                  )
                : null,
            hasCompletedOnboarding:
                s['hasCompletedOnboarding'] as bool? ?? false,
            // BUT-1220: the one-time activity-feed hint flag is persisted in
            // the private settings sub-doc (toPrivateSettings), not the public
            // profile doc, so it must be merged back here. Without this it
            // always read as the default false and the hint re-fired forever.
            hasSeenActivityFeedHint:
                s['hasSeenActivityFeedHint'] as bool? ?? false,
          );
        }
      } catch (e) {
        AppLogger.warning(
          'Failed to load private settings for ${userId.maskedUserId}: $e',
        );
      }
    }
    return profile;
  }

  /// Fetch multiple profiles in batches (Firestore `whereIn` cap).
  @override
  Future<List<UserProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final results = <UserProfile>[];

    for (final batch in userIds.chunked(kFirestoreWhereInLimit)) {
      final query = await collection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in query.docs) {
        results.add(fromFirestore(doc));
      }
    }

    return results;
  }

  /// Update profile statistics such as friend count or recipe count.
  @override
  Future<void> updateProfileStats(
    String userId, {
    int? friendsCount,
    int? publicRecipeCount,
  }) async {
    // Validate user is updating their own stats
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update profile stats',
    );

    final updates = <String, dynamic>{};
    if (friendsCount != null) updates['friendsCount'] = friendsCount;
    if (publicRecipeCount != null) {
      updates['publicRecipeCount'] = publicRecipeCount;
    }

    if (updates.isNotEmpty) {
      await collection.doc(userId).update(updates);

      logPermissionCheck(
        userId: currentUser,
        resource: 'user_profile',
        operation: 'update_stats',
        granted: true,
        details: 'Updated: ${updates.keys.join(', ')}',
      );
    }
  }

  /// Update the online status for a user.
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    // Validate user is updating their own status
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update online status',
    );

    await collection.doc(userId).update({
      'isOnline': isOnline,
      'lastActiveAt': timestampProvider.serverTimestamp(),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update_online_status',
      granted: true,
    );
  }

  @override
  Future<List<UserProfile>> searchProfiles(String query) async =>
      (await searchProfilesResult(query)).hits;

  /// Search for users by display name or email. BUT-1442: carries `failed`,
  /// set true only when EVERY query attempt errored (a backend outage) — not
  /// when the queries ran and matched zero profiles — so callers can show a
  /// degraded notice instead of a neutral "no results" state.
  @override
  Future<SearchResult<UserProfile>> searchProfilesResult(String query) async {
    const int limit = 20;
    if (query.trim().isEmpty) {
      return const SearchResult(
        hits: [],
        totalHits: 0,
        page: 0,
        totalPages: 1,
        processingTimeMs: 0,
      );
    }
    final normalizedQuery = query.trim().toLowerCase();
    final results = <UserProfile>[];
    final seen = <String>{};
    final uid = currentUserId;

    // failed == true iff no query level completes (all three throw). Set true
    // the moment any `.get()` returns, even with zero docs (a legitimate empty).
    var searchSucceeded = false;

    // Try optimized indexed search first
    bool usedFallback = false;
    try {
      AppLogger.debug(
        'searchProfiles: Attempting indexed search for query: $normalizedQuery',
      );

      // Server-side isHidden filter avoids paying read cost on suspended
      // profiles AND keeps the result count honest \u2014 a client-side drop
      // would silently shrink the returned set below `limit`. The fallback
      // paths below still client-filter as defence in depth (e.g., legacy
      // profiles missing the field).
      final nameQuery = await collection
          .where('isSearchable', isEqualTo: true)
          .where('isHidden', isEqualTo: false)
          .where('displayNameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('displayNameLower', isLessThan: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();
      searchSucceeded = true;

      for (final doc in nameQuery.docs) {
        if (doc.id == uid) continue;
        final profile = fromFirestore(doc);
        if (!seen.contains(profile.uid)) {
          results.add(profile);
          seen.add(profile.uid);
        }
      }

      AppLogger.info(
        'searchProfiles: Indexed search successful: found ${results.length} results',
      );
    } catch (e) {
      // If indexed search fails (likely missing composite index), use fallback
      usedFallback = true;
      AppLogger.warning(
        'searchProfiles: Indexed search failed, using fallback: $e',
      );

      try {
        final slowQuery = await collection
            .where('isSearchable', isEqualTo: true)
            .limit(100)
            .get();
        searchSucceeded = true;

        for (final doc in slowQuery.docs) {
          if (doc.id == uid) continue;
          final profile = fromFirestore(doc);
          if (profile.isHidden) continue;
          if (profile.displayName.toLowerCase().contains(normalizedQuery) &&
              !seen.contains(profile.uid)) {
            results.add(profile);
            seen.add(profile.uid);
            if (results.length >= limit) break;
          }
        }

        AppLogger.info(
          'searchProfiles: Fallback search successful: found ${results.length} results',
        );
      } catch (fallbackError) {
        AppLogger.error(
          'searchProfiles: Fallback search also failed: $fallbackError',
        );

        // If both indexed and fallback fail, try most basic query
        try {
          final basicQuery = await collection.limit(50).get();
          searchSucceeded = true;

          for (final doc in basicQuery.docs) {
            if (doc.id == uid) continue;
            try {
              final profile = fromFirestore(doc);
              // Check if profile is searchable and matches query
              if (profile.isSearchable &&
                  !profile.isHidden &&
                  profile.displayName.toLowerCase().contains(normalizedQuery) &&
                  !seen.contains(profile.uid)) {
                results.add(profile);
                seen.add(profile.uid);
                if (results.length >= limit) break;
              }
            } catch (docError) {
              // Skip malformed documents
              AppLogger.warning(
                'searchProfiles: Skipping malformed document ${doc.id}: $docError',
              );
            }
          }

          AppLogger.info(
            'searchProfiles: Basic search completed: found ${results.length} results',
          );
        } catch (basicError) {
          AppLogger.error(
            'searchProfiles: All search methods failed: $basicError',
          );
        }
      }
    }

    // Optional email search (only if not too many results already)
    if (normalizedQuery.contains('@') && results.length < 5) {
      try {
        final emailQuery = await collection
            .where('allowEmailSearch', isEqualTo: true)
            .where('email', isEqualTo: normalizedQuery)
            .limit(5)
            .get();
        for (final doc in emailQuery.docs) {
          if (doc.id == uid) continue;
          try {
            final profile = fromFirestore(doc);
            if (!seen.contains(profile.uid)) {
              results.add(profile);
              seen.add(profile.uid);
            }
          } catch (docError) {
            AppLogger.warning(
              'searchProfiles: Skipping malformed email search document ${doc.id}: $docError',
            );
          }
        }
      } catch (emailError) {
        AppLogger.warning('searchProfiles: Email search failed: $emailError');
      }
    }

    // Sort results with exact matches first
    results.sort((a, b) {
      final aExact = a.displayName.toLowerCase() == normalizedQuery;
      final bExact = b.displayName.toLowerCase() == normalizedQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    AppLogger.info(
      'searchProfiles: Search completed: ${results.length} total results, '
      'used fallback: $usedFallback, failed: ${!searchSucceeded}',
    );

    return SearchResult(
      hits: results,
      totalHits: results.length,
      page: 0,
      totalPages: 1,
      processingTimeMs: 0,
      failed: !searchSucceeded,
    );
  }

  /// Check if a display name is available (case sensitive).
  @override
  Future<bool> isDisplayNameAvailable(String displayName) async {
    final query = await collection
        .where('displayName', isEqualTo: displayName.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return true;
    final currentId = currentUserId;
    return query.docs.first.id == currentId;
  }

  /// Update FCM token for push notifications
  @override
  Future<void> updateFCMToken(String userId, String token) async {
    // Validate user is updating their own FCM token
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update FCM token',
    );

    await _settingsDoc(userId).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': timestampProvider.serverTimestamp(),
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update_fcm_token',
      granted: true,
    );
  }

  /// Update notification settings
  @override
  Future<void> updateNotificationSettings(String userId, bool enabled) async {
    // Validate user is updating their own settings
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update notification settings',
    );

    await _settingsDoc(userId).set({
      'notificationsEnabled': enabled,
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update_notification_settings',
      granted: true,
    );
  }

  /// Clear FCM token (e.g., on logout)
  @override
  Future<void> clearFCMToken(String userId) async {
    // Validate user is clearing their own FCM token
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'clear FCM token',
    );

    await _settingsDoc(userId).set({
      'fcmToken': null,
      'fcmTokenUpdatedAt': null,
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'clear_fcm_token',
      granted: true,
    );
  }

  /// Ensure base user document exists in 'users' collection for friends system
  @override
  Future<void> ensureBaseUserDocument(String userId) async {
    final usersCollection = firestore.collection(FirestoreCollections.users);
    await usersCollection.doc(userId).set({
      'uid': userId,
      'createdAt': timestampProvider.serverTimestamp(),
      'lastActiveAt': timestampProvider.serverTimestamp(),
      'initialized': true,
    }, SetOptions(merge: true));
  }

  /// Increment public recipe count when a recipe is created or shared publicly
  @override
  Future<void> incrementPublicRecipeCount(String userId) async {
    // Validate user is updating their own recipe count
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'increment public recipe count',
    );

    await collection.doc(userId).update({
      'publicRecipeCount': FieldValue.increment(1),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'increment_public_recipe_count',
      granted: true,
    );
  }

  /// Decrement public recipe count when a recipe is deleted or made private
  @override
  Future<void> decrementPublicRecipeCount(String userId) async {
    // Validate user is updating their own recipe count
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'decrement public recipe count',
    );

    await collection.doc(userId).update({
      'publicRecipeCount': FieldValue.increment(-1),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'decrement_public_recipe_count',
      granted: true,
    );
  }

  // Profile propagation is handled by Cloud Function (on-profile-updated.ts)

  /// Update allergen preferences for a user
  @override
  Future<void> updateAllergenPreferences(
    String userId,
    UserAllergenPreferences preferences,
  ) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update allergen preferences',
    );

    await _settingsDoc(userId).set({
      'allergenPreferences': preferences.toFirestore(),
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update_allergen_preferences',
      granted: true,
    );
  }

  @override
  Future<void> markActivityFeedHintSeen(String userId) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark activity-feed hint seen',
    );

    // BUT-1220: the hint flag lives in the private settings sub-doc
    // (toPrivateSettings), which is where fetchProfile reads it back from. A
    // merge:true single-field set touches only this field — it never overwrites
    // the public profile doc, so it can't clobber friendsCount (mutated by
    // friend-creation transactions) or moderator-owned isHidden/hiddenAt.
    await _settingsDoc(userId).set({
      'hasSeenActivityFeedHint': true,
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'mark_activity_feed_hint_seen',
      granted: true,
    );
  }

  @override
  Future<void> setAutoAddBoughtToPantry(String userId, bool enabled) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'set auto-add-bought-to-pantry',
    );

    // BUT-1050: the preference lives in the private settings sub-doc
    // (toPrivateSettings). A merge:true single-field set touches only this field
    // and never overwrites the public profile doc, so it can't clobber
    // friendsCount (friend-creation transactions) or isHidden/hiddenAt.
    await _settingsDoc(userId).set({
      'autoAddBoughtToPantry': enabled,
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'set_auto_add_bought_to_pantry',
      granted: true,
    );
  }

  @override
  Future<void> markPantryAutoAddPrompted(String userId) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark pantry auto-add prompted',
    );

    await _settingsDoc(userId).set({
      'pantryAutoAddPrompted': true,
    }, SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'mark_pantry_auto_add_prompted',
      granted: true,
    );
  }

  @override
  Future<bool> deletePublicProfile(String userId) async {
    // GDPR cascade: caller must own this profile.
    final currentUser = requireCurrentUserId();
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: userId,
      resourceType: collectionName,
    );
    // `collection` points at `public_profiles` (per `collectionName` above).
    await collection.doc(userId).delete();
    AppLogger.info('Deleted public_profiles/${userId.maskedUserId}');
    // GDPR Article 17 erasure must leave an audit entry on the SUCCESS path —
    // validateOwnership only logs on deny. Mirror the granted:true logging that
    // every other mutating method here does, and forward auditRepository so the
    // entry PERSISTS to the Art.30 trail (BUT-1286), not just the console.
    //
    // BUT-1287 (behavioral note): passing auditRepository here is what flips
    // this success-path log from console-only to Firestore-persisted. Without
    // the argument logPermissionCheck() still emits to AppLogger but writes
    // nothing durable — so a public-profile erasure would leave no Art.30
    // record an auditor could retrieve. The presence of `auditRepository:` is
    // the load-bearing difference; do not drop it when refactoring.
    logPermissionCheck(
      userId: currentUser,
      resource: 'public_profile/$userId',
      operation: 'delete',
      granted: true,
      auditRepository: auditRepository,
    );
    return true;
  }

  // deleteUserRootDoc is provided by UserRootDeletionMixin — it deletes the
  // root `users/{userId}` doc, which lives outside this repository's
  // `public_profiles` collection (BUT-734).
}
