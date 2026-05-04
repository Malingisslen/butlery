// lib/services/group_shared_content_service.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/permission_service.dart' as perm_service;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

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
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? clock.now(),
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

  // -- Public get methods --

  Future<List<SharedContentItem>> getSharedShoppingLists(
    FriendCategory group,
  ) async {
    return _getSharedContent(
        group, FirestoreCollections.sharedContent, 'shopping_list');
  }

  Future<List<SharedContentItem>> getSharedMenus(FriendCategory group) async {
    return _getSharedContent(group, FirestoreCollections.sharedContent, 'menu');
  }

  Future<List<SharedContentItem>> getSharedRecipes(
    FriendCategory group,
  ) async {
    return _getSharedContent(
        group, FirestoreCollections.sharedContent, 'recipe');
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

  // -- Public stream methods --

  Stream<List<SharedContentItem>> streamSharedShoppingLists(
    FriendCategory group,
  ) {
    return _streamSharedContent(
        group, FirestoreCollections.sharedContent, 'shopping_list');
  }

  Stream<List<SharedContentItem>> streamSharedMenus(FriendCategory group) {
    return _streamSharedContent(
        group, FirestoreCollections.sharedContent, 'menu');
  }

  Stream<List<SharedContentItem>> streamSharedRecipes(FriendCategory group) {
    return _streamSharedContent(
        group, FirestoreCollections.sharedContent, 'recipe');
  }

  // -- Private helpers --

  Future<List<SharedContentItem>> _getSharedContent(
    FriendCategory group,
    String collection,
    String contentType,
  ) async {
    try {
      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) return [];

      final allMemberIds = group.allMemberIds;

      AppLogger.debug(
          '🔍 [${contentType.toUpperCase()}] Querying for group: ${group.name}');
      AppLogger.debug('   All IDs for query: $allMemberIds');

      // arrayContainsAny supports up to 30 values — sufficient for current group sizes
      final snapshot = await _firestore
          .collection(collection)
          .where('contentType', isEqualTo: contentType)
          .where('sharedToUserIds', arrayContainsAny: allMemberIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .get();

      AppLogger.debug('   Found ${snapshot.docs.length} $contentType items');

      final items = snapshot.docs
          .map((doc) => SharedContentItem.fromFirestore(doc, contentType))
          .toList();

      if (items.isNotEmpty) {
        AppLogger.debug('   First item: ${items[0].title}');
      }

      return items;
    } catch (e) {
      AppLogger.warning('Failed to fetch shared $contentType for group: $e');
      return [];
    }
  }

  Stream<List<SharedContentItem>> _streamSharedContent(
    FriendCategory group,
    String collection,
    String contentType,
  ) {
    try {
      final userId = _permissionService.currentUserId;
      if (userId == null) return Stream.value([]);

      return _firestore
          .collection(collection)
          .where('contentType', isEqualTo: contentType)
          .where('sharedToUserIds', arrayContainsAny: group.allMemberIds)
          .orderBy('sharedAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => SharedContentItem.fromFirestore(doc, contentType))
              .toList());
    } catch (e) {
      AppLogger.warning('Failed to stream shared $contentType: $e');
      return Stream.value([]);
    }
  }
}
