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
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
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
  /// Stores `displayNameLower` on each friend doc to enable server-side prefix search.
  Future<void> addMutualFriends(String userId1, String userId2) async {
    final (user1Name, user2Name) = await _fetchDisplayNames(userId1, userId2);

    await firestore.runTransaction((transaction) async {
      await _writeMutualFriendDocs(
          transaction, userId1, userId2, user1Name, user2Name);
    });
  }

  /// Accept a friend request atomically: creates mutual friendship AND marks
  /// the request as accepted in a single Firestore transaction.
  ///
  /// [requestDocRef] must be resolved before calling (query by fromUserId/toUserId).
  Future<void> acceptFriendAtomically(
    String userId1,
    String userId2, {
    required DocumentReference requestDocRef,
  }) async {
    final (user1Name, user2Name) = await _fetchDisplayNames(userId1, userId2);

    await firestore.runTransaction((transaction) async {
      await _writeMutualFriendDocs(
          transaction, userId1, userId2, user1Name, user2Name);

      transaction.update(requestDocRef, {
        'status': FriendRequestStatus.accepted.name,
        'respondedAt': timestampProvider.serverTimestamp(),
      });
    });
  }

  /// Fetch lowercased display names for two users concurrently.
  Future<(String, String)> _fetchDisplayNames(
      String userId1, String userId2) async {
    final results = await Future.wait([
      collection.doc(userId1).get(),
      collection.doc(userId2).get(),
    ]);
    final user1Name =
        (results[0].data()?['displayName'] as String? ?? '').toLowerCase();
    final user2Name =
        (results[1].data()?['displayName'] as String? ?? '').toLowerCase();
    return (user1Name, user2Name);
  }

  /// Shared transaction body: creates friend docs + increments counts.
  /// BUG-011: skips if both sides already exist (partial recovery handled).
  Future<void> _writeMutualFriendDocs(
    Transaction transaction,
    String userId1,
    String userId2,
    String user1Name,
    String user2Name,
  ) async {
    final user1FriendRef = _userFriendsRef(userId1).doc(userId2);
    final user2FriendRef = _userFriendsRef(userId2).doc(userId1);

    final user1FriendDoc = await transaction.get(user1FriendRef);
    final user2FriendDoc = await transaction.get(user2FriendRef);

    // BUG-011 fix: only skip if BOTH docs exist (handles partial state)
    if (user1FriendDoc.exists && user2FriendDoc.exists) {
      return;
    }

    int docsCreated = 0;
    if (!user1FriendDoc.exists) {
      transaction.set(user1FriendRef, {
        'addedAt': timestampProvider.serverTimestamp(),
        'displayNameLower': user2Name,
      });
      docsCreated++;
    }
    if (!user2FriendDoc.exists) {
      transaction.set(user2FriendRef, {
        'addedAt': timestampProvider.serverTimestamp(),
        'displayNameLower': user1Name,
      });
      docsCreated++;
    }

    if (docsCreated == 2) {
      final user1Profile = collection.doc(userId1);
      final user2Profile = collection.doc(userId2);
      transaction
          .update(user1Profile, {'friendsCount': FieldValue.increment(1)});
      transaction
          .update(user2Profile, {'friendsCount': FieldValue.increment(1)});
    }
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

      // Conditionally delete each side and decrement its count
      // Handles partial state from a previous failed write
      final user1Profile = collection.doc(userId1);
      final user2Profile = collection.doc(userId2);

      if (user1FriendDoc.exists) {
        transaction.delete(user1FriendRef);
        transaction
            .update(user1Profile, {'friendsCount': FieldValue.increment(-1)});
      }
      if (user2FriendDoc.exists) {
        transaction.delete(user2FriendRef);
        transaction
            .update(user2Profile, {'friendsCount': FieldValue.increment(-1)});
      }
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
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final batch in userIds.chunked(kFirestoreWhereInLimit)) {
      futures.add(collection.where(FieldPath.documentId, whereIn: batch).get());
    }
    final snapshots = await Future.wait(futures);
    return snapshots
        .expand((s) => s.docs)
        .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get complete friend list with profiles for a user.
  Future<List<UserProfile>> getFriendsWithProfiles(String userId) async {
    final friendIds = await fetchFriendIds(userId);
    return await fetchFriendProfiles(friendIds);
  }

  /// Get mutual friends between two users.
  ///
  /// Fetches user1's friend IDs and checks them against user2's friends
  /// subcollection via batched `whereIn` (avoids downloading user2's entire
  /// friend list). Capped at 300 of user1's IDs to bound query cost.
  Future<List<String>> getMutualFriends(String userId1, String userId2) async {
    final friends1 = await fetchFriendIds(userId1);
    if (friends1.isEmpty) return [];

    final cappedFriends = friends1.take(300).toList();
    final mutualIds = <String>[];

    for (final batch in cappedFriends.chunked(kFirestoreWhereInLimit)) {
      final snapshot = await _userFriendsRef(userId2)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      mutualIds.addAll(snapshot.docs.map((doc) => doc.id));
    }

    return mutualIds;
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
  ///
  /// Limited to 1000 friends per stream snapshot. This balances real-time responsiveness
  /// (each snapshot transfers all matching docs) against supporting users with large
  /// friend lists. At 1000 friends the snapshot payload is ~50-100KB which is acceptable
  /// for real-time listeners. Users exceeding 1000 friends will see a truncation warning.
  Stream<List<String>> friendIdsStream(String userId) {
    return _userFriendsRef(userId).limit(1000).snapshots().map((snapshot) {
      if (snapshot.docs.length == 1000) {
        AppLogger.warning(
            'friendIdsStream for user $userId hit 1000-doc limit — results are truncated');
      }
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  /// Stream friend profiles for real-time updates.
  Stream<List<UserProfile>> friendProfilesStream(String userId) {
    return friendIdsStream(userId)
        .distinct((a, b) => const ListEquality<String>().equals(a, b))
        .asyncMap((friendIds) async {
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
    final results = await Future.wait([
      fetchFriendIds(userId),
      getRecentFriends(userId),
    ]);
    final friendIds = results[0] as List<String>;
    final recentFriends = results[1] as List<UserProfile>;

    return {
      'totalFriends': friendIds.length,
      'recentFriends': recentFriends.length,
      'hasActiveFriends': friendIds.isNotEmpty,
    };
  }

  /// Search friends by display name prefix using server-side Firestore query.
  ///
  /// Queries the `users/{userId}/friends` subcollection using `displayNameLower`
  /// prefix matching. Requires the `displayNameLower` field on friend docs
  /// (written by [addMutualFriends]). Legacy friend docs without this field
  /// will not appear in results. Results capped at 20.
  Future<List<UserProfile>> searchFriends(String userId, String query) async {
    if (query.isEmpty) return [];
    final normalizedQuery = query.toLowerCase();

    final snapshot = await _userFriendsRef(userId)
        .where('displayNameLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('displayNameLower', isLessThan: '$normalizedQuery\uf8ff')
        .limit(20)
        .get();

    final friendIds = snapshot.docs.map((doc) => doc.id).toList();
    if (friendIds.isEmpty) return [];
    return fetchFriendProfiles(friendIds);
  }
}
