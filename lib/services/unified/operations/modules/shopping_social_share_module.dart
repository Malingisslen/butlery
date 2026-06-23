// lib/services/unified/operations/modules/shopping_social_share_module.dart

import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Module handling social shopping list sharing with friends and groups.
/// Provides complete social sharing functionality with Firebase integration.
class ShoppingSocialShareModule {
  final FirebaseFirestore _firestore;
  final PermissionService _permissionService;

  ShoppingSocialShareModule({
    required FirebaseFirestore firestore,
    required PermissionService permissionService,
  }) : _firestore = firestore,
       _permissionService = permissionService;

  /// Share shopping list with friends
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async {
    try {
      if (friendIds.isEmpty) {
        AppLogger.error('No friends selected for sharing');
        return false;
      }

      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User must be authenticated to share shopping list');
        return false;
      }

      final currentUser = _permissionService.currentUser;
      if (currentUser == null) return false;

      // Get shopping list data from user's personal lists
      final listDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(listId)
          .get();
      if (!listDoc.exists) {
        AppLogger.error('Shopping list not found: $listId');
        return false;
      }

      final listData = listDoc.data()!;
      // BUT-1109: localized fallback for missing/malformed list name. Reaches
      // recipients only via legacy/malformed data — normal share flow always
      // sets `name`. Replaces the literal '?' character.
      final listTitle = listData['name'] ?? AppLocale.current.unnamedSharedList;

      // Prepare shared list data for Firebase
      final sharedListData = {
        'contentType': 'shopping_list',
        'title': listTitle,
        'description': message?.trim(),
        'listData': listData,
        'sharedByUserId': currentUser.uid,
        'sharedByDisplayName': currentUser.displayName,
        'sharedByAvatarUrl': currentUser.avatarUrl,
        'sharedAt': FieldValue.serverTimestamp(),
        'sharedWithUserIds': friendIds,
        'isActive': true,
        'listType': 'shopping_list_shared',
      };

      // Create shared list document in Firestore
      final sharedListRef = _firestore
          .collection(FirestoreCollections.sharedContent)
          .doc();
      await sharedListRef.set(sharedListData);

      // Create individual share records for each friend
      final batch = _firestore.batch();

      for (final friendId in friendIds) {
        final shareRecordRef = _firestore
            .collection(FirestoreCollections.userSharedShoppingLists)
            .doc(friendId)
            .collection(FirestoreCollections.receivedLists)
            .doc(sharedListRef.id);

        batch.set(shareRecordRef, {
          'sharedListId': sharedListRef.id,
          'sharedByUserId': currentUser.uid,
          'sharedByDisplayName': currentUser.displayName,
          'listTitle': listTitle,
          'sharedAt': FieldValue.serverTimestamp(),
          'isViewed': false,
          'isImported': false,
        });
      }

      await batch.commit();

      AppLogger.success(
        '✅ Shopping list shared successfully with ${friendIds.length} friends',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to share shopping list with friends', e);
      return false;
    }
  }

  /// Share list with single friend
  Future<bool> shareListWithFriend(String listId, String friendId) async {
    return await shareWithFriends(listId: listId, friendIds: [friendId]);
  }

  /// Share list with multiple friends (alias for shareWithFriends)
  Future<bool> shareListWithMultipleFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async {
    return await shareWithFriends(
      listId: listId,
      friendIds: friendIds,
      message: message,
    );
  }

  /// Share with groups - resolves group members and shares with all
  /// Optimized: Uses batch whereIn queries instead of N+1 pattern (#040)
  Future<bool> shareWithGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) async {
    try {
      if (groupIds.isEmpty) return false;

      // Resolve all group members using batch fetch (max 30 per whereIn query)
      final allMemberIds = <String>{};

      // Batch fetch groups in chunks of 30 (Firestore whereIn limit)
      for (int i = 0; i < groupIds.length; i += 30) {
        final batchIds = groupIds.sublist(i, min(i + 30, groupIds.length));
        final groupDocs = await _firestore
            .collection(FirestoreCollections.userFriendCategories)
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in groupDocs.docs) {
          final memberIds = List<String>.from(
            doc.data()['friendUserIds'] ?? [],
          );
          allMemberIds.addAll(memberIds);
        }
      }

      if (allMemberIds.isEmpty) {
        AppLogger.error('No members found in specified groups');
        return false;
      }

      // Use existing shareWithFriends method
      return await shareWithFriends(
        listId: listId,
        friendIds: allMemberIds.toList(),
        message: message,
      );
    } catch (e) {
      AppLogger.error('Failed to share shopping list with groups', e);
      return false;
    }
  }

  /// Share list with single group
  Future<bool> shareListWithGroup(String listId, String groupId) async {
    return await shareWithGroups(listId: listId, groupIds: [groupId]);
  }

  /// Share list with multiple groups
  Future<bool> shareListWithMultipleGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) async {
    return await shareWithGroups(
      listId: listId,
      groupIds: groupIds,
      message: message,
    );
  }

  /// Send collaboration invite
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) async {
    return await shareWithFriends(
      listId: listId,
      friendIds: [recipientId],
      message: message,
    );
  }

  /// Get shopping lists shared with me
  /// Optimized: Uses batch whereIn queries instead of N+1 pattern (#040)
  Future<List<Map<String, dynamic>>> getShoppingListsSharedWithMe() async {
    try {
      if (!_permissionService.isAuthenticated) return [];

      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedLists)
          .orderBy('sharedAt', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      // Collect all sharedListIds for batch fetch
      final receivedListData = <String, Map<String, dynamic>>{};
      final sharedListIds = <String>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final sharedListId = data['sharedListId'] as String?;
        if (sharedListId != null) {
          sharedListIds.add(sharedListId);
          receivedListData[sharedListId] = data;
        }
      }

      if (sharedListIds.isEmpty) return [];

      // Batch fetch all shared list documents (max 10 per whereIn query)
      final allListDocs = <String, Map<String, dynamic>>{};

      for (int i = 0; i < sharedListIds.length; i += 10) {
        final batchIds = sharedListIds.sublist(
          i,
          min(i + 10, sharedListIds.length),
        );
        final listDocs = await _firestore
            .collection(FirestoreCollections.sharedContent)
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in listDocs.docs) {
          allListDocs[doc.id] = doc.data();
        }
      }

      // Build result list from cached batch data
      final sharedLists = <Map<String, dynamic>>[];

      for (final sharedListId in sharedListIds) {
        final listData = allListDocs[sharedListId];
        final receivedData = receivedListData[sharedListId];

        // BUT-1108: defense-in-depth — verify the current user is in the
        // canonical sharedWithUserIds. The implicit access via received_lists
        // pointer is no longer the only gate; if Firestore rules ever loosen
        // on pointer writes, this prevents cross-user inbox leakage.
        final sharedWithUserIds =
            (listData?['sharedWithUserIds'] as List?)?.cast<String>() ??
            const <String>[];
        if (!sharedWithUserIds.contains(currentUserId)) continue;

        if (listData != null &&
            receivedData != null &&
            listData['isActive'] == true) {
          sharedLists.add({
            'id': sharedListId,
            // BUT-1109: localized fallback for missing title — was literal '?'.
            'title': listData['title'] ?? AppLocale.current.unnamedSharedList,
            // BUT-1109: reuse the existing shoppingUnknownUser key (Swedish:
            // "Okänd användare") for a missing displayName — semantically a
            // person, not a list, so unnamedSharedList would be wrong here.
            'sharedByDisplayName':
                listData['sharedByDisplayName'] ??
                AppLocale.current.shoppingUnknownUser,
            'sharedByAvatarUrl': listData['sharedByAvatarUrl'],
            'sharedAt': receivedData['sharedAt'],
            'description': listData['description'],
            'isViewed': receivedData['isViewed'] ?? false,
            'isImported': receivedData['isImported'] ?? false,
          });
        }
      }

      return sharedLists;
    } catch (e) {
      AppLogger.error('Failed to get shopping lists shared with me', e);
      return [];
    }
  }

  /// Get shopping lists shared by me
  Future<List<Map<String, dynamic>>> getShoppingListsSharedByMe() async {
    try {
      if (!_permissionService.isAuthenticated) return [];

      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: 'shopping_list')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('sharedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          // BUT-1109: localized fallback for missing title — was literal '?'.
          'title': data['title'] ?? AppLocale.current.unnamedSharedList,
          'sharedAt': data['sharedAt'],
          'sharedWithCount': (data['sharedWithUserIds'] as List?)?.length ?? 0,
          'description': data['description'],
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get shopping lists shared by me', e);
      return [];
    }
  }

  /// Import shared shopping list
  Future<String?> importSharedShoppingList(String sharedListId) async {
    try {
      if (!_permissionService.isAuthenticated) return null;

      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return null;

      // Get shared list data
      final listDoc = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .doc(sharedListId)
          .get();

      if (!listDoc.exists) {
        AppLogger.error('Shared shopping list not found');
        return null;
      }

      final listData = listDoc.data()!;

      // Verify user has access to this list
      final sharedWithUserIds = List<String>.from(
        listData['sharedWithUserIds'] ?? [],
      );
      if (!sharedWithUserIds.contains(currentUserId)) {
        AppLogger.error('User does not have access to this shopping list');
        return null;
      }

      // Mark as imported in user's received lists.
      // BUT-1107: `set(..., merge:true)` creates the pointer if it's missing
      // (inbox cleanup race) instead of throwing not-found on `.update()` and
      // collapsing to a useless "import failed" message.
      await _firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedLists)
          .doc(sharedListId)
          .set({
            'isImported': true,
            'importedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      AppLogger.success('✅ Shopping list imported successfully');
      return sharedListId;
    } catch (e) {
      AppLogger.error('Failed to import shared shopping list', e);
      return null;
    }
  }

  /// Mark shared shopping list as viewed
  Future<bool> markSharedShoppingListAsViewed(String sharedListId) async {
    try {
      if (!_permissionService.isAuthenticated) return false;

      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return false;

      await _firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedLists)
          .doc(sharedListId)
          .update({
            'isViewed': true,
            'viewedAt': FieldValue.serverTimestamp(),
          });

      AppLogger.debug('Shopping list marked as viewed: $sharedListId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark shopping list as viewed', e);
      return false;
    }
  }

  /// Get shopping list sharing stats
  Future<Map<String, dynamic>> getShoppingListSharingStats(
    String listId,
  ) async {
    try {
      if (!_permissionService.isAuthenticated) return {};

      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return {};

      final querySnapshot = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: 'shopping_list')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      final totalSharedByMe = querySnapshot.docs.length;
      final totalFriendsSharedWith = querySnapshot.docs
          .expand(
            (doc) => List<String>.from(doc.data()['sharedWithUserIds'] ?? []),
          )
          .toSet()
          .length;

      return {
        'sharedWith': totalFriendsSharedWith,
        'totalShared': totalSharedByMe,
        'lastShared': querySnapshot.docs.isNotEmpty
            ? querySnapshot.docs.first.data()['sharedAt']
            : null,
      };
    } catch (e) {
      AppLogger.error('Failed to get shopping list sharing stats', e);
      return {};
    }
  }
}
