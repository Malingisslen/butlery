// lib/services/unified/friends/friends_utility_operations.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Utility operations for friends service providing helper methods for:
/// - Blocked users synchronization
/// - User search and friend queries
/// - Recent collaborators detection
/// - Shopping collaborators tracking
class FriendsUtilityOperations {
  final FirebaseFirestore firestore;
  final String? Function() getCurrentUserId;
  final Set<String> Function() getBlockedUsers;
  final List<FriendRequest> Function() getIncomingRequests;
  final List<FriendRequest> Function() getOutgoingRequests;

  FriendsUtilityOperations({
    required this.firestore,
    required this.getCurrentUserId,
    required this.getBlockedUsers,
    required this.getIncomingRequests,
    required this.getOutgoingRequests,
  });

  /// Get all friend requests (incoming and outgoing combined)
  List<FriendRequest> get friendRequests {
    final all = <FriendRequest>[];
    all.addAll(getIncomingRequests());
    all.addAll(getOutgoingRequests());
    return all;
  }

  /// Get friends of a specific user
  Future<List<UserProfile>> getFriendsOfUser(String userId) async {
    try {
      AppLogger.debug('Getting friends of user: ${userId.maskedUserId}');

      // Get friend IDs from user document
      final userDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        AppLogger.warning('User not found: ${userId.maskedUserId}');
        return [];
      }

      final data = userDoc.data();
      final friendIds = List<String>.from(data?['friends'] ?? []);

      if (friendIds.isEmpty) {
        return [];
      }

      final friendProfiles = await _batchFetchUserProfiles(friendIds);

      AppLogger.success(
          'Found ${friendProfiles.length} friends for user ${userId.maskedUserId}');
      return friendProfiles;
    } catch (e) {
      AppLogger.error(
          'Failed to get friends of user ${userId.maskedUserId}', e);
      return [];
    }
  }

  /// Get recent collaborators
  Future<List<UserProfile>> getRecentCollaborators() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        AppLogger.warning(
            'Cannot get recent collaborators: No authenticated user');
        return [];
      }

      AppLogger.debug('Fetching recent collaborators for user: ${userId.maskedUserId}');

      // Get recent collaborators from recipes
      final recentRecipes = await firestore
          .collection(FirestoreCollections.recipes)
          .where('sharedWith', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();

      // Get recent collaborators from menus
      final recentMenus = await firestore
          .collection(FirestoreCollections.menus)
          .where('sharedWith', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();

      // Collect unique collaborator IDs
      final collaboratorIds = <String>{};

      // Add recipe collaborators
      for (final doc in recentRecipes.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final sharedWith = List<String>.from(data['sharedWith'] ?? []);

        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }
        for (final collaboratorId in sharedWith) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }

      // Add menu collaborators
      for (final doc in recentMenus.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final sharedWith = List<String>.from(data['sharedWith'] ?? []);

        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }
        for (final collaboratorId in sharedWith) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }

      if (collaboratorIds.isEmpty) {
        AppLogger.debug('No recent collaborators found');
        return [];
      }

      final collaborators =
          await _batchFetchUserProfiles(collaboratorIds.take(10).toList());

      AppLogger.success('Found ${collaborators.length} recent collaborators');
      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent collaborators', e);
      return [];
    }
  }

  /// Get recent shopping collaborators
  Future<List<UserProfile>> getRecentShoppingCollaborators() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        AppLogger.warning(
            'Cannot get recent shopping collaborators: No authenticated user');
        return [];
      }

      AppLogger.debug(
          'Fetching recent shopping collaborators for user: $userId');

      // Get recent shopping lists where user is a collaborator
      final recentShoppingLists = await firestore
          .collection(FirestoreCollections.userShoppingLists)
          .where('collaborators', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();

      // Collect unique collaborator IDs
      final collaboratorIds = <String>{};

      for (final doc in recentShoppingLists.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final collaborators = List<String>.from(data['collaborators'] ?? []);

        // Add owner if not the current user
        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }

        // Add all collaborators except current user
        for (final collaboratorId in collaborators) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }

      if (collaboratorIds.isEmpty) {
        AppLogger.debug('No recent shopping collaborators found');
        return [];
      }

      final collaborators =
          await _batchFetchUserProfiles(collaboratorIds.take(10).toList());

      AppLogger.success(
          'Found ${collaborators.length} recent shopping collaborators');
      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent shopping collaborators', e);
      return [];
    }
  }

  Future<List<UserProfile>> _batchFetchUserProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final profileMap = <String, UserProfile>{};

    for (var i = 0; i < userIds.length; i += 30) {
      final chunk = userIds.skip(i).take(30).toList();
      final querySnapshot = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        profileMap[doc.id] = UserProfile(
          uid: doc.id,
          displayName: data['displayName'] ?? 'Unknown User',
          email: data['email'] ?? '',
          avatarUrl: data['avatarUrl'],
          joinedAt: data['joinedAt'] != null
              ? (data['joinedAt'] as Timestamp).toDate()
              : DateTime.now(),
          lastActiveAt: data['lastActiveAt'] != null
              ? (data['lastActiveAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }
    }

    return userIds
        .where((id) => profileMap.containsKey(id))
        .map((id) => profileMap[id]!)
        .toList();
  }
}
