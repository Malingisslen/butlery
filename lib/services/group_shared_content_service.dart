// lib/services/group_shared_content_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/permission_service.dart' as perm_service;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';

/// Model for shared content items displayed in group views
class SharedContentItem {
  final String id;
  final String title;
  final String type; // 'recipe', 'menu', 'shopping_list'
  final String sharedByUserId;
  final String sharedByDisplayName;
  final String? sharedByAvatarUrl;
  final DateTime sharedAt;
  final Map<String, dynamic> data;

  SharedContentItem({
    required this.id,
    required this.title,
    required this.type,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    this.sharedByAvatarUrl,
    required this.sharedAt,
    required this.data,
  });

  factory SharedContentItem.fromFirestore(
    DocumentSnapshot doc,
    String type,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return SharedContentItem(
      id: doc.id,
      title: _extractTitle(data, type),
      type: type,
      sharedByUserId: data['sharedByUserId'] ?? '',
      sharedByDisplayName: data['sharedByDisplayName'] ?? '?',
      sharedByAvatarUrl: data['sharedByAvatarUrl'],
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: data,
    );
  }

  static String _extractTitle(Map<String, dynamic> data, String type) {
    switch (type) {
      case 'shopping_list':
        return data['title'] ??
            data['listTitle'] ??
            AppLocale.current.labelUntitledList;
      case 'menu':
        return data['title'] ??
            data['menuTitle'] ??
            AppLocale.current.labelUntitledMenu;
      case 'recipe':
        return data['title'] ??
            data['recipeTitle'] ??
            AppLocale.current.labelUntitledRecipe;
      default:
        return AppLocale.current.labelUnknownContent;
    }
  }
}

/// Service for querying and managing shared content within groups
class GroupSharedContentService extends BaseService {
  @override
  String get serviceName => 'GroupSharedContentService';
  final FirebaseFirestore _firestore;
  final perm_service.PermissionService _permissionService;

  GroupSharedContentService({
    required FirebaseFirestore firestore,
    required perm_service.PermissionService permissionService,
  })  : _firestore = firestore,
        _permissionService = permissionService;

  /// Get all shopping lists shared with a group
  /// Returns lists where all group members are in sharedWithUserIds
  Future<List<SharedContentItem>> getSharedShoppingLists(
    FriendCategory group,
  ) async {
    try {
      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      // Include owner in query - friendUserIds might not include the owner
      final allMemberIds = [group.ownerId, ...group.friendUserIds];

      AppLogger.debug('🔍 [SHOPPING_LISTS] Querying for group: ${group.name}');
      AppLogger.debug('   Group owner: ${group.ownerId}');
      AppLogger.debug('   Group members: ${group.friendUserIds}');
      AppLogger.debug('   All IDs for query: $allMemberIds');

      // Query shopping lists shared with at least one group member
      final snapshot = await _firestore
          .collection('sharedShoppingLists')
          .where('sharedWithUserIds', arrayContainsAny: allMemberIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .get();

      AppLogger.debug('   Found ${snapshot.docs.length} shopping lists');

      final items = snapshot.docs
          .map((doc) => SharedContentItem.fromFirestore(doc, 'shopping_list'))
          .toList();

      if (items.isNotEmpty) {
        AppLogger.debug('   First item: ${items[0].title}');
      }

      return items;
    } catch (e) {
      AppLogger.error('Failed to fetch shared shopping lists for group', e);
      return [];
    }
  }

  /// Get all menus shared with a group
  Future<List<SharedContentItem>> getSharedMenus(FriendCategory group) async {
    try {
      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      // Include owner in query - friendUserIds might not include the owner
      final allMemberIds = [group.ownerId, ...group.friendUserIds];

      AppLogger.debug('🔍 [MENUS] Querying for group: ${group.name}');
      AppLogger.debug('   Group owner: ${group.ownerId}');
      AppLogger.debug('   Group members: ${group.friendUserIds}');
      AppLogger.debug('   All IDs for query: $allMemberIds');

      // Query menus shared with at least one group member
      final snapshot = await _firestore
          .collection('shared_menus')
          .where('sharedToUserIds', arrayContainsAny: allMemberIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .get();

      AppLogger.debug('   Found ${snapshot.docs.length} menus');

      final items = snapshot.docs
          .map((doc) => SharedContentItem.fromFirestore(doc, 'menu'))
          .toList();

      if (items.isNotEmpty) {
        AppLogger.debug('   First item: ${items[0].title}');
      }

      return items;
    } catch (e) {
      AppLogger.error('Failed to fetch shared menus for group', e);
      return [];
    }
  }

  /// Get all recipes shared with a group
  /// Note: This depends on the actual recipe sharing implementation
  Future<List<SharedContentItem>> getSharedRecipes(
    FriendCategory group,
  ) async {
    try {
      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      // Include owner in query - friendUserIds might not include the owner
      final allMemberIds = [group.ownerId, ...group.friendUserIds];

      AppLogger.debug('🔍 [RECIPES] Querying for group: ${group.name}');
      AppLogger.debug('   Group owner: ${group.ownerId}');
      AppLogger.debug('   Group members: ${group.friendUserIds}');
      AppLogger.debug('   All IDs for query: $allMemberIds');

      // Try querying shared_recipes collection if it exists
      // This may need adjustment based on actual recipe sharing structure
      final snapshot = await _firestore
          .collection('shared_recipes')
          .where('sharedWithUserIds', arrayContainsAny: allMemberIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .get();

      AppLogger.debug('   Found ${snapshot.docs.length} recipes');

      final items = snapshot.docs
          .map((doc) => SharedContentItem.fromFirestore(doc, 'recipe'))
          .toList();

      if (items.isNotEmpty) {
        AppLogger.debug('   First item: ${items[0].title}');
      }

      return items;
    } catch (e) {
      AppLogger.warning('Failed to fetch shared recipes for group: $e');
      // Recipe sharing might use a different structure
      return [];
    }
  }

  /// Get all shared content for a group (combined)
  Future<Map<String, List<SharedContentItem>>> getAllSharedContent(
    FriendCategory group,
  ) async {
    final results = await Future.wait([
      getSharedRecipes(group),
      getSharedMenus(group),
      getSharedShoppingLists(group),
    ]);

    return {
      'recipes': results[0],
      'menus': results[1],
      'shopping_lists': results[2],
    };
  }

  /// Stream of shopping lists shared with group (real-time updates)
  Stream<List<SharedContentItem>> streamSharedShoppingLists(
    FriendCategory group,
  ) {
    try {
      return _firestore
          .collection('sharedShoppingLists')
          .where('sharedWithUserIds', arrayContainsAny: group.friendUserIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) =>
                  SharedContentItem.fromFirestore(doc, 'shopping_list'))
              .toList());
    } catch (e) {
      AppLogger.error('Failed to stream shared shopping lists', e);
      return Stream.value([]);
    }
  }

  /// Stream of menus shared with group (real-time updates)
  Stream<List<SharedContentItem>> streamSharedMenus(FriendCategory group) {
    try {
      return _firestore
          .collection('shared_menus')
          .where('sharedToUserIds', arrayContainsAny: group.friendUserIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => SharedContentItem.fromFirestore(doc, 'menu'))
              .toList());
    } catch (e) {
      AppLogger.error('Failed to stream shared menus', e);
      return Stream.value([]);
    }
  }

  /// Stream of recipes shared with group (real-time updates)
  Stream<List<SharedContentItem>> streamSharedRecipes(FriendCategory group) {
    try {
      return _firestore
          .collection('shared_recipes')
          .where('sharedWithUserIds', arrayContainsAny: group.friendUserIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => SharedContentItem.fromFirestore(doc, 'recipe'))
              .toList());
    } catch (e) {
      // Recipe sharing might use a different structure
      AppLogger.warning('Failed to stream shared recipes: $e');
      return Stream.value([]);
    }
  }
}
