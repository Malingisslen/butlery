// lib/services/unified/friends/friends_utility_operations.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Utility operations for friends service providing helper methods for:
/// - Blocked users synchronization
/// - User search and friend queries
/// - Recent collaborators detection
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
        'Found ${friendProfiles.length} friends for user ${userId.maskedUserId}',
      );
      return friendProfiles;
    } catch (e) {
      AppLogger.error(
        'Failed to get friends of user ${userId.maskedUserId}',
        e,
      );
      return [];
    }
  }

  /// Get recent collaborators
  Future<List<UserProfile>> getRecentCollaborators() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        AppLogger.warning(
          'Cannot get recent collaborators: No authenticated user',
        );
        return [];
      }

      AppLogger.debug(
        'Fetching recent collaborators for user: ${userId.maskedUserId}',
      );

      // Find shared content where user is a member (via collectionGroup)
      final memberDocs = await firestore
          .collectionGroup(FirestoreCollections.members)
          .where('userId', isEqualTo: userId)
          .limit(40)
          .get();

      // Collect unique collaborator IDs from parent doc owners
      final collaboratorIds = <String>{};

      for (final doc in memberDocs.docs) {
        final addedBy = doc.data()['addedBy'] as String?;
        if (addedBy != null && addedBy != userId) {
          collaboratorIds.add(addedBy);
        }
      }

      if (collaboratorIds.isEmpty) {
        AppLogger.debug('No recent collaborators found');
        return [];
      }

      final collaborators = await _batchFetchUserProfiles(
        collaboratorIds.take(10).toList(),
      );

      AppLogger.success('Found ${collaborators.length} recent collaborators');
      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent collaborators', e);
      return [];
    }
  }

  // BUT-1724: `getRecentShoppingCollaborators()` used to live here. It queried
  // a ROOT `shopping_lists` collection for `collaborators array-contains <uid>`
  // — a collection `firestore.rules` grants no match for, so every call hit the
  // catch-all deny, logged a permission error and returned an empty list. It
  // was also unreachable: nothing outside its own facade and unit test ever
  // called it. Deleted rather than re-pointed at
  // `unified_shared_shopping_lists`, because a live version would need a
  // composite index and a product decision about where such a list is shown;
  // the collaborator surface the UI actually uses is
  // [getRecentCollaborators], which reads the `members` collection group.

  Future<List<UserProfile>> _batchFetchUserProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return [];

    final profileMap = <String, UserProfile>{};

    for (final chunk in userIds.chunked(kFirestoreWhereInLimit)) {
      final querySnapshot = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        profileMap[doc.id] = UserProfile(
          uid: doc.id,
          displayName:
              data['displayName'] ?? AppLocale.current.displayUnknownUser,
          email: data['email'] ?? '',
          avatarUrl: data['avatarUrl'],
          joinedAt:
              SerializationUtils.parseDateTimeValue(data['joinedAt']) ??
              clock.now(),
          lastActiveAt:
              SerializationUtils.parseDateTimeValue(data['lastActiveAt']) ??
              clock.now(),
        );
      }
    }

    return userIds
        .where((id) => profileMap.containsKey(id))
        .map((id) => profileMap[id]!)
        .toList();
  }
}
