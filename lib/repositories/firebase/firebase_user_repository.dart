// lib/repositories/firebase/firebase_user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Firebase Firestore implementation for user profile management and social discovery.
///
/// This repository implements the [UserRepository] interface using Firebase Firestore,
/// managing user profiles in the `public_profiles` collection with comprehensive search,
/// statistics tracking, and notification management. It provides the foundation for
/// social features while maintaining privacy and security controls.
///
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] to eliminate 45 lines of duplicate CRUD code while
/// providing specialized user profile operations. Uses the `public_profiles` collection
/// for searchable user data and integrates with authentication for security validation.
///
/// **Security and Privacy:**
/// - **Self-Operation Validation**: Users can only modify their own profiles and settings
/// - **Permission Logging**: Comprehensive audit trail for all profile operations
/// - **Field Validation**: Ensures data integrity for required profile fields
/// - **Privacy Controls**: Supports searchable profiles and email search opt-in
/// - **FCM Security**: Validates token updates to prevent unauthorized access
///
/// **Search and Discovery:**
/// - **Name Search**: Efficient searchable display name indexing with `displayNameLower`
/// - **Email Search**: Optional email-based discovery with user consent
/// - **Fallback Search**: Graceful degradation when indexed search fails
/// - **Search Privacy**: Users can control searchability through `isSearchable` flag
/// - **Result Ranking**: Prioritizes exact matches and alphabetical ordering
///
/// **Profile Statistics:**
/// Tracks and maintains user statistics including friend counts, recipe counts,
/// and activity metrics for profile display and social features integration.
///
/// **Notification Integration:**
/// - **FCM Token Management**: Secure FCM token storage and updates for push notifications
/// - **Notification Settings**: User-controlled notification preferences
/// - **Token Cleanup**: Proper token cleanup on logout for security
/// - **Timestamp Tracking**: FCM token update timestamps for debugging
///
/// **Usage Examples:**
/// ```dart
/// final userRepo = FirebaseUserRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Create/update profile with validation
/// final profile = UserProfile(
///   uid: currentUserId,
///   displayName: 'John Doe',
///   isSearchable: true,
/// );
/// await userRepo.saveProfile(profile);
/// 
/// // Search for users
/// final results = await userRepo.searchProfiles('john');
/// 
/// // Update notifications
/// await userRepo.updateFCMToken(userId, fcmToken);
/// await userRepo.updateNotificationSettings(userId, true);
/// ```
class FirebaseUserRepository extends BaseFirebaseRepository<UserProfile>
    implements UserRepository {
  FirebaseUserRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'public_profiles';

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;

  // ===== SPECIALIZED USER PROFILE OPERATIONS =====

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
    
    final data = profile.toFirestore();
    data['displayNameLower'] = profile.displayName.toLowerCase();
    await collection.doc(profile.uid).set(data);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update',
      granted: true,
    );
  }

  /// Fetch a profile by id. Returns `null` if it doesn't exist.
  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    // Use the base class read method for consistency
    return await read(userId);
  }

  /// Fetch multiple profiles in batches (Firestore limit 10 per query).
  @override
  Future<List<UserProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    const batchSize = 10;
    final results = <UserProfile>[];

    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final query =
          await collection.where(FieldPath.documentId, whereIn: batch).get();
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
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'user_profile',
      operation: 'update_online_status',
      granted: true,
    );
  }

  /// Search for users by display name or email.
  @override
  Future<List<UserProfile>> searchProfiles(String query) async {
    const int limit = 20;
    if (query.trim().isEmpty) return [];
    final normalizedQuery = query.trim().toLowerCase();
    final results = <UserProfile>[];
    final seen = <String>{};
    final uid = currentUserId;

    try {
      final nameQuery = await collection
          .where('isSearchable', isEqualTo: true)
          .where('displayNameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('displayNameLower', isLessThan: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();

      for (final doc in nameQuery.docs) {
        if (doc.id == uid) continue;
        final profile = fromFirestore(doc);
        if (!seen.contains(profile.uid)) {
          results.add(profile);
          seen.add(profile.uid);
        }
      }
    } catch (_) {
      // If indexed search fails, fall back to a slower name search
      final slowQuery = await collection
          .where('isSearchable', isEqualTo: true)
          .orderBy('displayName')
          .limit(100)
          .get();
      for (final doc in slowQuery.docs) {
        if (doc.id == uid) continue;
        final profile = fromFirestore(doc);
        if (profile.displayName.toLowerCase().contains(normalizedQuery) &&
            !seen.contains(profile.uid)) {
          results.add(profile);
          seen.add(profile.uid);
          if (results.length >= limit) break;
        }
      }
    }

    // Optional email search
    if (normalizedQuery.contains('@') && results.length < 5) {
      final emailQuery = await collection
          .where('allowEmailSearch', isEqualTo: true)
          .where('email', isEqualTo: normalizedQuery)
          .limit(5)
          .get();
      for (final doc in emailQuery.docs) {
        if (doc.id == uid) continue;
        final profile = fromFirestore(doc);
        if (!seen.contains(profile.uid)) {
          results.add(profile);
          seen.add(profile.uid);
        }
      }
    }

    results.sort((a, b) {
      final aExact = a.displayName.toLowerCase() == normalizedQuery;
      final bExact = b.displayName.toLowerCase() == normalizedQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.displayName.compareTo(b.displayName);
    });
    return results;
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
    
    await collection.doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
    
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
    
    await collection.doc(userId).update({
      'notificationsEnabled': enabled,
    });
    
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
    
    await collection.doc(userId).update({
      'fcmToken': null,
      'fcmTokenUpdatedAt': null,
    });
    
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
    final usersCollection = firestore.collection('users');
    await usersCollection.doc(userId).set({
      'uid': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'initialized': true,
    }, SetOptions(merge: true));
  }
}
