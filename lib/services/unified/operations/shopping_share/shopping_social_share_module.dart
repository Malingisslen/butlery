// lib/services/unified/operations/shopping_share/shopping_social_share_module.dart

// ✅ PHASE 1A COMPLETED: All direct FirebaseFirestore.instance calls converted to use FirestoreRepository
// 🔄 PHASE 2 TODO: Further refactor to use specialized SocialSharingRepository for better domain separation
// Current state: All Firebase access goes through FirestoreRepository with proper authentication

import 'package:butlery/repositories/firestore_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/services/unified/operations/shopping_share/shared/shopping_share_utils.dart';

/// Shopping list social sharing module
/// 
/// This module handles ONLY social sharing operations:
/// - Share with friends and social groups
/// - Manage shared list access and permissions
/// - Handle collaboration invitations
/// - Track sharing history and statistics
/// - Import shared lists from other users
/// 
/// ❌ DOES NOT CONTAIN: Export, templates, external sharing, import from files
class ShoppingSocialShareModule {
  final dynamic _parent; // UnifiedShoppingService
  late final SocialSharingRepository _sharingRepository;
  late final FirestoreRepository _firestoreRepository;

  ShoppingSocialShareModule(this._parent) {
    _sharingRepository = sl<SocialSharingRepository>();
    _firestoreRepository = sl<FirestoreRepository>();
  }

  // ===== FRIEND SHARING =====

  /// Share shopping list with specific friends
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot share with friends: $errorMessage');
        return false;
      }
      
      if (friendIds.isEmpty) {
        AppLogger.error('No friends specified for sharing');
        return false;
      }

      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to share with friends');
        return false;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;
      
      // Create shared content using repository
      final sharedContent = SharedContent(
        id: '${listId}_${DateTime.now().millisecondsSinceEpoch}',
        contentType: 'shopping_list',
        contentId: listId,
        ownerId: currentUser.uid,
        sharedAt: DateTime.now(),
        sharedWithUserIds: friendIds,
        sharedWithGroupIds: [],
        permissions: SharingPermissions(
          canView: true,
          canEdit: false,
        ),
        metadata: {
          'listName': list!.name,
          'ownerDisplayName': currentUser.displayName,
          'ownerAvatarUrl': currentUser.avatarUrl,
          'message': message ?? '',
          'shareType': 'direct_friend',
          'listData': _createShareListData(list),
        },
      );
      
      await _sharingRepository.shareToUsers(friendIds, sharedContent);
      
      AppLogger.success('✅ List shared with ${friendIds.length} friends: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list with friends', e);
      return false;
    }
  }

  /// Share shopping list with single friend
  Future<bool> shareListWithFriend(String listId, String friendId) async {
    return await shareWithFriends(
      listId: listId,
      friendIds: [friendId],
    );
  }

  /// Share shopping list with multiple friends (alias for shareWithFriends)
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

  // ===== COLLABORATION MANAGEMENT =====

  /// Send shopping list collaboration invitation
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot send invite: $errorMessage');
        return false;
      }
      
      if (!list!.isCollaborative) {
        AppLogger.error('Cannot send invite: List is not collaborative');
        return false;
      }

      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to send collaboration invite');
        return false;
      }

      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;

      // Create collaboration invitation using repository
      final sharedContent = SharedContent(
        id: '${listId}_collab_${DateTime.now().millisecondsSinceEpoch}',
        contentType: 'shopping_list_collaboration',
        contentId: listId,
        ownerId: currentUser.uid,
        sharedAt: DateTime.now(),
        sharedWithUserIds: [recipientId],
        sharedWithGroupIds: [],
        permissions: SharingPermissions(
          canView: true,
          canEdit: true,
        ),
        metadata: {
          'listName': list.name,
          'ownerDisplayName': currentUser.displayName,
          'message': message ?? '',
          'status': 'pending',
          'type': 'shopping_list_collaboration',
        },
      );
      
      await _sharingRepository.shareToUsers([recipientId], sharedContent);
      
      AppLogger.success('✅ Collaboration invite sent for list: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send collaboration invite', e);
      return false;
    }
  }

  // ===== SHARED LISTS MANAGEMENT =====

  /// Get shopping lists shared with current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedWithMe() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      // Get shared content from repository  
      final sharedContent = await _sharingRepository
          .getSharedWithMe(currentUserId)
          .first;
      
      final sharedLists = <Map<String, dynamic>>[];
      
      for (final content in sharedContent.where((c) => c.contentType == 'shopping_list')) {
        final listData = content.metadata['listData'] as Map<String, dynamic>? ?? {};
        final statistics = listData['statistics'] as Map<String, dynamic>? ?? {};
        
        sharedLists.add({
          'id': content.id,
          'listName': content.metadata['listName'] ?? 'Namnlös lista',
          'ownerDisplayName': content.metadata['ownerDisplayName'] ?? 'Okänd användare',
          'ownerAvatarUrl': content.metadata['ownerAvatarUrl'],
          'sharedAt': content.sharedAt,
          'totalItems': statistics['totalItems'] ?? 0,
          'boughtItems': statistics['boughtItems'] ?? 0,
          'remainingItems': statistics['remainingItems'] ?? 0,
          'isViewed': content.viewedBy.containsKey(currentUserId),
          'isImported': content.acceptedBy.containsKey(currentUserId),
          'shareType': content.metadata['shareType'] ?? 'direct_friend',
          'message': content.metadata['message'],
        });
      }

      return sharedLists;
    } catch (e) {
      AppLogger.error('Failed to get shared shopping lists', e);
      return [];
    }
  }

  /// Get shopping lists shared by current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedByMe() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      // Use repository instead of direct Firebase access
      final sharedContent = await _sharingRepository.getMySharedContent(currentUserId).first;
      
      return sharedContent
          .where((content) => content.contentType == 'shopping_list')
          .map((content) {
        final metadata = content.metadata;
        final listData = metadata['listData'] as Map<String, dynamic>? ?? {};
        final statistics = listData['statistics'] as Map<String, dynamic>? ?? {};
        
        return {
          'id': content.id,
          'listName': metadata['listName'] ?? 'Namnlös lista',
          'sharedWithUserId': content.sharedWithUserIds.isNotEmpty ? content.sharedWithUserIds.first : null,
          'sharedAt': content.sharedAt,
          'totalItems': statistics['totalItems'] ?? 0,
          'boughtItems': statistics['boughtItems'] ?? 0,
          'remainingItems': statistics['remainingItems'] ?? 0,
          'shareType': metadata['shareType'] ?? 'direct_friend',
          'message': metadata['message'],
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get lists shared by me', e);
      return [];
    }
  }

  // ===== SHARED LIST IMPORT =====

  /// Import shared shopping list
  Future<String?> importSharedShoppingList(String sharedListId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return null;
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return null;

      // Get shared list data
      final listDoc = await _firestoreRepository.firestore
          .collection('sharedShoppingLists')
          .doc(sharedListId)
          .get();

      if (!listDoc.exists || listDoc.data()!['isActive'] != true) {
        AppLogger.error('Shared shopping list not found or inactive');
        return null;
      }

      final listData = listDoc.data()!;
      final listDataSnapshot = listData['listData'] as Map<String, dynamic>? ?? {};
      
      // Verify user has access to this list
      if (listData['sharedWithUserId'] != currentUserId) {
        AppLogger.error('User does not have access to this shopping list');
        return null;
      }

      // Create the shopping list items
      final itemsData = listDataSnapshot['items'] as List<dynamic>? ?? [];
      final items = itemsData.map((itemData) {
        return UnifiedShoppingItem(
          name: itemData['name'] ?? 'Okänd artikel',
          amount: (itemData['amount'] as num?)?.toDouble() ?? 1.0,
          unit: itemData['unit'] ?? '',
          category: itemData['category'] ?? 'Övrigt',
          note: itemData['note'],
          estimatedPrice: (itemData['estimatedPrice'] as num?)?.toDouble(),
          priority: itemData['priority'] ?? 3,
          bought: itemData['bought'] ?? false,
        );
      }).toList();

      // Create new shopping list with imported data
      final importedListName = '${listDataSnapshot['name'] ?? 'Importerad lista'} (från ${listData['ownerDisplayName'] ?? 'okänd'})';
      final listId = await _parent.createPersonalList(importedListName, items: items);

      if (listId != null) {
        // Mark as imported in user's received lists
        await _firestoreRepository.firestore
            .collection('userSharedShoppingLists')
            .doc(currentUserId)
            .collection('receivedLists')
            .doc(sharedListId)
            .update({
          'isImported': true,
          'importedAt': FieldValue.serverTimestamp(),
          'importedListId': listId,
        });

        AppLogger.success('✅ Shopping list imported successfully');
      }

      return listId;
    } catch (e) {
      AppLogger.error('Failed to import shared shopping list', e);
      return null;
    }
  }

  /// Mark shared shopping list as viewed
  Future<void> markSharedShoppingListAsViewed(String sharedListId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return;
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _firestoreRepository.firestore
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .doc(sharedListId)
          .update({
        'isViewed': true,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.debug('Shopping list marked as viewed: $sharedListId');
    } catch (e) {
      AppLogger.error('Failed to mark shopping list as viewed', e);
    }
  }

  // ===== SHARING STATISTICS =====

  /// Get shopping list sharing statistics
  Future<Map<String, dynamic>> getShoppingListSharingStats() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return {};
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return {};

      // Get lists shared by user
      final sharedByMeQuery = await _firestoreRepository.firestore
          .collection('sharedShoppingLists')
          .where('ownerId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get lists shared with user
      final sharedWithMeQuery = await _firestoreRepository.firestore
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .get();

      final totalSharedByMe = sharedByMeQuery.docs.length;
      final totalSharedWithMe = sharedWithMeQuery.docs.length;
      
      // Calculate imported lists
      final importedLists = sharedWithMeQuery.docs
          .where((doc) => doc.data()['isImported'] == true)
          .length;

      // Calculate this month's activity
      final thisMonth = DateTime.now();
      final monthStart = DateTime(thisMonth.year, thisMonth.month, 1);
      
      final thisMonthShared = sharedByMeQuery.docs
          .where((doc) {
            final sharedAt = doc.data()['sharedAt'] as Timestamp?;
            return sharedAt != null && sharedAt.toDate().isAfter(monthStart);
          })
          .length;

      return {
        'listsSharedByMe': totalSharedByMe,
        'listsSharedWithMe': totalSharedWithMe,
        'importedLists': importedLists,
        'totalSharingActivity': totalSharedByMe + totalSharedWithMe,
        'thisMonthShared': thisMonthShared,
        'importRate': totalSharedWithMe > 0 ? (importedLists / totalSharedWithMe * 100).round() : 0,
      };
    } catch (e) {
      AppLogger.error('Failed to get shopping list sharing stats', e);
      return {};
    }
  }

  /// Get most active sharing friends
  Future<List<Map<String, dynamic>>> getMostActiveSharingFriends({int limit = 10}) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      // Get all lists shared with current user
      final sharedWithMeQuery = await _firestoreRepository.firestore
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .get();

      // Count shares by user
      final sharingCounts = <String, Map<String, dynamic>>{};
      
      for (final doc in sharedWithMeQuery.docs) {
        final data = doc.data();
        final sharedByUserId = data['sharedByUserId'] as String?;
        final sharedByDisplayName = data['sharedByDisplayName'] as String?;
        
        if (sharedByUserId != null) {
          if (!sharingCounts.containsKey(sharedByUserId)) {
            sharingCounts[sharedByUserId] = {
              'userId': sharedByUserId,
              'displayName': sharedByDisplayName ?? 'Okänd användare',
              'shareCount': 0,
              'lastSharedAt': null,
            };
          }
          
          sharingCounts[sharedByUserId]!['shareCount'] = 
              (sharingCounts[sharedByUserId]!['shareCount'] as int) + 1;
          
          final sharedAt = data['sharedAt'] as Timestamp?;
          if (sharedAt != null) {
            final lastSharedAt = sharingCounts[sharedByUserId]!['lastSharedAt'] as Timestamp?;
            if (lastSharedAt == null || sharedAt.compareTo(lastSharedAt) > 0) {
              sharingCounts[sharedByUserId]!['lastSharedAt'] = sharedAt;
            }
          }
        }
      }

      // Sort by share count and return top friends
      final sortedFriends = sharingCounts.values.toList()
        ..sort((a, b) => (b['shareCount'] as int).compareTo(a['shareCount'] as int));

      return sortedFriends.take(limit).toList();
    } catch (e) {
      AppLogger.error('Failed to get most active sharing friends', e);
      return [];
    }
  }

  // ===== HELPER METHODS =====

  /// Get list by ID from parent service
  UnifiedShoppingList? _getListById(String listId) {
    return _parent.lists.where((list) => list.id == listId).firstOrNull;
  }

  /// Create share list data for social sharing
  Map<String, dynamic> _createShareListData(UnifiedShoppingList list) {
    return {
      'name': list.name,
      'description': list.description,
      'type': list.isCollaborative ? 'collaborative' : 'personal',
      'items': list.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'amount': item.amount,
        'unit': item.unit,
        'category': item.category,
        'note': item.note,
        'estimatedPrice': item.estimatedPrice,
        'priority': item.priority,
        'bought': item.bought,
        'purchasedAt': item.purchasedAt?.toIso8601String(),
        'addedBy': item.addedByUserId != null ? {
          'id': item.addedByUserId,
          'displayName': item.addedByDisplayName,
        } : null,
      }).toList(),
      'statistics': ShoppingShareUtils.getListStatistics(list),
    };
  }
}