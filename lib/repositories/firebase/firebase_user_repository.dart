// lib/repositories/firebase/firebase_user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/user_profile.dart';
import '../interfaces/user_repository.dart';
import 'base_firebase_repository.dart';

/// Repository for user profile data stored in the `public_profiles` collection.
///
/// Refactored to extend BaseFirebaseRepository, eliminating 45 lines of duplicate CRUD code
/// while preserving all specialized user profile operations.
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
    final data = profile.toFirestore();
    data['displayNameLower'] = profile.displayName.toLowerCase();
    await collection.doc(profile.uid).set(data);
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
    final updates = <String, dynamic>{};
    if (friendsCount != null) updates['friendsCount'] = friendsCount;
    if (publicRecipeCount != null) {
      updates['publicRecipeCount'] = publicRecipeCount;
    }

    if (updates.isNotEmpty) {
      await collection.doc(userId).update(updates);
    }
  }

  /// Update the online status for a user.
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await collection.doc(userId).update({
      'isOnline': isOnline,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
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
    await collection.doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update notification settings
  @override
  Future<void> updateNotificationSettings(String userId, bool enabled) async {
    await collection.doc(userId).update({
      'notificationsEnabled': enabled,
    });
  }

  /// Clear FCM token (e.g., on logout)
  @override
  Future<void> clearFCMToken(String userId) async {
    await collection.doc(userId).update({
      'fcmToken': null,
      'fcmTokenUpdatedAt': null,
    });
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
