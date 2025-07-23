// lib/repositories/firebase/firebase_user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/user_profile.dart';
import '../interfaces/user_repository.dart';

/// Repository for user profile data stored in the `public_profiles` collection.
class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository();

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('public_profiles');

  @override
  Future<UserProfile> create(UserProfile profile) async {
    await _profilesRef.doc(profile.uid).set(profile.toFirestore());
    return profile;
  }

  @override
  Future<UserProfile?> read(String id) async {
    final doc = await _profilesRef.doc(id).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  @override
  Future<List<UserProfile>> readAll() async {
    final snapshot = await _profilesRef.get();
    return snapshot.docs.map(UserProfile.fromFirestore).toList();
  }

  @override
  Future<void> update(UserProfile profile) async {
    await _profilesRef.doc(profile.uid).update(profile.toFirestore());
  }

  @override
  Future<void> delete(String id) async {
    await _profilesRef.doc(id).delete();
  }

  /// Create or update the current user's profile.
  @override
  Future<void> saveProfile(UserProfile profile) async {
    final data = profile.toFirestore();
    data['displayNameLower'] = profile.displayName.toLowerCase();
    await _profilesRef.doc(profile.uid).set(data);
  }

  /// Fetch a profile by id. Returns `null` if it doesn't exist.
  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final doc = await _profilesRef.doc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  /// Fetch multiple profiles in batches (Firestore limit 10 per query).
  @override
  Future<List<UserProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    const batchSize = 10;
    final results = <UserProfile>[];

    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final query = await _profilesRef
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in query.docs) {
        results.add(UserProfile.fromFirestore(doc));
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
    if (publicRecipeCount != null) updates['publicRecipeCount'] = publicRecipeCount;

    if (updates.isNotEmpty) {
      await _profilesRef.doc(userId).update(updates);
    }
  }

  /// Update the online status for a user.
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _profilesRef.doc(userId).update({
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
    final currentUserId = _authRepository.currentUserId;

    try {
      final nameQuery = await _profilesRef
          .where('isSearchable', isEqualTo: true)
          .where('displayNameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('displayNameLower', isLessThan: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();

      for (final doc in nameQuery.docs) {
        if (doc.id == currentUserId) continue;
        final profile = UserProfile.fromFirestore(doc);
        if (!seen.contains(profile.uid)) {
          results.add(profile);
          seen.add(profile.uid);
        }
      }
    } catch (_) {
      // If indexed search fails, fall back to a slower name search
      final slowQuery = await _profilesRef
          .where('isSearchable', isEqualTo: true)
          .orderBy('displayName')
          .limit(100)
          .get();
      for (final doc in slowQuery.docs) {
        if (doc.id == currentUserId) continue;
        final profile = UserProfile.fromFirestore(doc);
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
      final emailQuery = await _profilesRef
          .where('allowEmailSearch', isEqualTo: true)
          .where('email', isEqualTo: normalizedQuery)
          .limit(5)
          .get();
      for (final doc in emailQuery.docs) {
        if (doc.id == currentUserId) continue;
        final profile = UserProfile.fromFirestore(doc);
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
    final query = await _profilesRef
        .where('displayName', isEqualTo: displayName.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return true;
    final currentId = _authRepository.currentUserId;
    return query.docs.first.id == currentId;
  }

  /// Update FCM token for push notifications
  @override
  Future<void> updateFCMToken(String userId, String token) async {
    await _profilesRef.doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update notification settings
  @override
  Future<void> updateNotificationSettings(String userId, bool enabled) async {
    await _profilesRef.doc(userId).update({
      'notificationsEnabled': enabled,
    });
  }

  /// Clear FCM token (e.g., on logout)
  @override
  Future<void> clearFCMToken(String userId) async {
    await _profilesRef.doc(userId).update({
      'fcmToken': null,
      'fcmTokenUpdatedAt': null,
    });
  }
}

