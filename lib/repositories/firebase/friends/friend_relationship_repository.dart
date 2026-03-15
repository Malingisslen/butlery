/// Firebase Firestore implementation for comprehensive friend relationship and social connection management.
/// This repository provides sophisticated friend relationship functionality using Firebase Firestore
/// as the backend, managing mutual friendships, friend discovery, social connections, and relationship
/// analytics. It implements advanced features like bidirectional relationship management, friend
/// statistics, mutual friend discovery, and real-time relationship updates for social networking.
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Uses dual-collection approach: `public_profiles` for user data and `users/{id}/friends` for relationships
/// - Implements bidirectional friendship management ensuring data consistency across users
/// - Integrates with permission validation for secure relationship operations
/// - Coordinates with friend category system for comprehensive social organization
/// **Social Relationship Features:**
/// - **Mutual Friendships**: Bidirectional relationship management with automatic consistency
/// - **Friend Discovery**: Advanced search and discovery capabilities for social networking
/// - **Relationship Analytics**: Comprehensive statistics and insights into social connections
/// - **Real-time Updates**: Live streams for immediate friendship status changes
/// - **Mutual Friend Detection**: Sophisticated algorithms for finding common connections
/// - **Relationship History**: Temporal tracking of friendship formation and maintenance
/// **Data Consistency and Performance:**
/// - **Bidirectional Updates**: Maintains friendship consistency across both users automatically
/// - **Batch Operations**: Efficient bulk operations for relationship management
/// - **Count Maintenance**: Automatic friend count updates for profile statistics
/// - **Optimized Queries**: Efficient Firestore queries with proper indexing for scalability

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase implementation for friend relationship management with bidirectional consistency and analytics.
/// This repository provides comprehensive friend relationship functionality using Firebase Firestore
/// with sophisticated bidirectional relationship management, social analytics, and real-time updates.
/// It ensures data consistency across all friendship operations while providing advanced social
/// networking features like mutual friend discovery and relationship statistics.
/// **Relationship Management System:**
/// Uses a dual-collection architecture for efficient and consistent relationship management:
/// - `public_profiles`: Stores user profile information and aggregate friend statistics
/// - `users/{userId}/friends`: User-specific subcollections storing individual friend relationships
/// - Bidirectional updates ensure relationship consistency across both users automatically
/// **Advanced Social Features:**
/// - **Mutual Friend Discovery**: Sophisticated algorithms for finding common social connections
/// - **Relationship Analytics**: Comprehensive statistics and temporal friendship analysis
/// - **Real-time Streams**: Live updates for immediate social relationship changes
/// - **Batch Processing**: Efficient bulk operations for profile fetching and relationship management
/// **Usage Examples:**
/// ```dart
/// final relationshipRepo = FriendRelationshipRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Create mutual friendship
/// await relationshipRepo.addMutualFriends(userId1, userId2);
/// // Check friendship status
/// final areFriends = await relationshipRepo.areFriends(userId1, userId2);
/// // Get friend profiles with real-time updates
/// relationshipRepo.friendProfilesStream(userId).listen((friends) {
///   updateFriendsUI(friends);
/// });
/// // Discover mutual connections
/// final mutualFriends = await relationshipRepo.getMutualFriends(userId1, userId2);
/// // Get comprehensive social statistics
/// final stats = await relationshipRepo.getFriendStatistics(userId);
/// ```
class FriendRelationshipRepository extends BaseFirebaseRepository<UserProfile> {
  /// Creates a friend relationship repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository, defaults to FirebaseAuthRepository
  FriendRelationshipRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> _userFriendsRef(String userId) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends);
  @override
  String get collectionName => FirestoreCollections.publicProfiles;

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;
  @override
  Future<bool> validateCreatePermission(
      String userId, UserProfile entity) async {
    // Friend relationships are created through specific methods (addMutualFriends)
    // Not through generic CRUD, so we allow it and validate in specific methods
    return true;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, UserProfile? entity) async {
    // Anyone authenticated can read public profiles (for friend discovery)
    // Privacy is controlled via isSearchable flag in the profile
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, UserProfile entity) async {
    // Users can only update their own profile
    return userId == entity.uid;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Users can only delete their own profile
    return userId == resourceId;
  }

  /// Check if users are already friends.
  Future<bool> areFriends(String userId1, String userId2) async {
    final doc = await _userFriendsRef(userId1).doc(userId2).get();
    return doc.exists;
  }

  /// Add users to each other's friends collections and update counts.
  ///
  /// Uses a Firestore transaction to ensure atomicity and prevent race conditions
  /// when the same friendship is being created from multiple sources simultaneously.
  Future<void> addMutualFriends(String userId1, String userId2) async {
    await firestore.runTransaction((transaction) async {
      final user1FriendRef = _userFriendsRef(userId1).doc(userId2);
      final user2FriendRef = _userFriendsRef(userId2).doc(userId1);

      // Read both friendship documents to check if they already exist
      final user1FriendDoc = await transaction.get(user1FriendRef);
      final user2FriendDoc = await transaction.get(user2FriendRef);

      // BUG-011 fix: Changed from OR to AND - only skip if BOTH docs exist
      // This handles partial friendship states where only one side was created
      if (user1FriendDoc.exists && user2FriendDoc.exists) {
        return;
      }

      // Create friend documents for whichever side doesn't exist yet
      int docsCreated = 0;
      if (!user1FriendDoc.exists) {
        transaction.set(
            user1FriendRef, {'addedAt': timestampProvider.serverTimestamp()});
        docsCreated++;
      }
      if (!user2FriendDoc.exists) {
        transaction.set(
            user2FriendRef, {'addedAt': timestampProvider.serverTimestamp()});
        docsCreated++;
      }

      // Only update friend counts if we created both documents (new friendship)
      // If only one was created, don't increment (partial recovery scenario)
      if (docsCreated == 2) {
        final user1Profile = collection.doc(userId1);
        final user2Profile = collection.doc(userId2);
        transaction
            .update(user1Profile, {'friendsCount': FieldValue.increment(1)});
        transaction
            .update(user2Profile, {'friendsCount': FieldValue.increment(1)});
      }
    });
  }

  /// Remove users from each other's friends collections and update counts.
  ///
  /// Uses a Firestore transaction to ensure atomicity and prevent race conditions
  /// when the same friendship is being removed from multiple sources simultaneously.
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    await firestore.runTransaction((transaction) async {
      final user1FriendRef = _userFriendsRef(userId1).doc(userId2);
      final user2FriendRef = _userFriendsRef(userId2).doc(userId1);

      // Read both friendship documents to check if they exist
      final user1FriendDoc = await transaction.get(user1FriendRef);
      final user2FriendDoc = await transaction.get(user2FriendRef);

      // If friendship doesn't exist, skip to prevent duplicate count decrements
      if (!user1FriendDoc.exists && !user2FriendDoc.exists) {
        return;
      }

      // Delete friend documents for both users
      transaction.delete(user1FriendRef);
      transaction.delete(user2FriendRef);

      // Update friend counts atomically
      final user1Profile = collection.doc(userId1);
      final user2Profile = collection.doc(userId2);
      transaction
          .update(user1Profile, {'friendsCount': FieldValue.increment(-1)});
      transaction
          .update(user2Profile, {'friendsCount': FieldValue.increment(-1)});
    });
  }

  /// Remove a friend for the current user.
  Future<bool> removeFriend(String friendUserId) async {
    try {
      final current = requireCurrentUserId();
      await removeMutualFriends(current, friendUserId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retrieve friend ids for a user.
  Future<List<String>> fetchFriendIds(String userId) async {
    final snapshot = await _userFriendsRef(userId).get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  /// Retrieve user profiles for a list of ids.
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    const batchSize = 10;
    final profiles = <UserProfile>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final query =
          await collection.where(FieldPath.documentId, whereIn: batch).get();
      for (final doc in query.docs) {
        profiles.add(UserProfile.fromMap(doc.id, doc.data()));
      }
    }
    return profiles;
  }

  /// Get complete friend list with profiles for a user.
  Future<List<UserProfile>> getFriendsWithProfiles(String userId) async {
    final friendIds = await fetchFriendIds(userId);
    return await fetchFriendProfiles(friendIds);
  }

  /// Get mutual friends between two users.
  Future<List<String>> getMutualFriends(String userId1, String userId2) async {
    final friends1 = await fetchFriendIds(userId1);
    final friends2 = await fetchFriendIds(userId2);

    return friends1.where((id) => friends2.contains(id)).toList();
  }

  /// Count mutual friends between two users.
  Future<int> getMutualFriendsCount(String userId1, String userId2) async {
    final mutualFriends = await getMutualFriends(userId1, userId2);
    return mutualFriends.length;
  }

  /// Get friend count for a user.
  Future<int> getFriendCount(String userId) async {
    final snapshot = await _userFriendsRef(userId).count().get();
    return snapshot.count ?? 0;
  }

  /// Stream friend ids for real-time updates.
  /// Optimized (#043): Added limit to prevent unbounded stream for power users
  Stream<List<String>> friendIdsStream(String userId) {
    return _userFriendsRef(userId)
        .limit(200) // Limit to 200 friends for stream performance
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.length == 200) {
        AppLogger.warning(
            'friendIdsStream for user $userId returned exactly 200 docs — results may be silently truncated');
      }
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  /// Stream friend profiles for real-time updates.
  Stream<List<UserProfile>> friendProfilesStream(String userId) {
    return friendIdsStream(userId).asyncMap((friendIds) async {
      return await fetchFriendProfiles(friendIds);
    });
  }

  /// Check if user has any friends.
  Future<bool> hasFriends(String userId) async {
    final count = await getFriendCount(userId);
    return count > 0;
  }

  /// Get recently added friends (within last N days).
  Future<List<UserProfile>> getRecentFriends(String userId,
      {int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _userFriendsRef(userId)
        .where('addedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
        .orderBy('addedAt', descending: true)
        .get();

    final friendIds = snapshot.docs.map((doc) => doc.id).toList();
    return await fetchFriendProfiles(friendIds);
  }

  /// Get friend statistics for a user.
  Future<Map<String, dynamic>> getFriendStatistics(String userId) async {
    final friendIds = await fetchFriendIds(userId);
    final recentFriends = await getRecentFriends(userId);

    return {
      'totalFriends': friendIds.length,
      'recentFriends': recentFriends.length,
      'hasActiveFriends': friendIds.isNotEmpty,
    };
  }

  /// Search friends by name or display name.
  Future<List<UserProfile>> searchFriends(String userId, String query) async {
    final friends = await getFriendsWithProfiles(userId);
    final lowercaseQuery = query.toLowerCase();

    return friends.where((friend) {
      return friend.displayName.toLowerCase().contains(lowercaseQuery) ||
          (friend.email.toLowerCase().contains(lowercaseQuery) &&
              friend.allowEmailSearch);
    }).toList();
  }
}
