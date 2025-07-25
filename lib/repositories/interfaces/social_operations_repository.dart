import 'repository.dart';
import '../../models/recipe_unified.dart';

/// Repository interface for social operations like sharing and collaboration
abstract class SocialOperationsRepository extends Repository<SocialOperation> {
  /// Share a recipe with specific friends
  Future<bool> shareRecipeWithFriends({
    required String recipeId,
    required List<String> friendUserIds,
    String? message,
    String? customTitle,
  });

  /// Share a recipe with friend groups/categories
  Future<bool> shareRecipeWithGroups({
    required String recipeId,
    required List<String> groupIds,
    String? message,
    String? customTitle,
  });

  /// Share a menu with friends
  Future<bool> shareMenuWithFriends({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    String? message,
    String? customTitle,
  });

  /// Share a menu with groups
  Future<bool> shareMenuWithGroups({
    required Map<String, List<Recipe>> menu,
    required List<String> groupIds,
    String? message,
    String? customTitle,
  });

  /// Get shared items for a user
  Future<List<SharedItem>> getSharedItems(String userId, {
    SharedItemType? type,
    int limit = 50,
  });

  /// Get items shared by a user
  Future<List<SharedItem>> getItemsSharedByUser(String userId, {
    SharedItemType? type,
    int limit = 50,
  });

  /// Accept a shared item
  Future<void> acceptSharedItem(String sharedItemId);

  /// Decline a shared item
  Future<void> declineSharedItem(String sharedItemId);

  /// Remove/unshare an item
  Future<void> removeSharedItem(String sharedItemId);

  /// Create a public share link
  Future<String> createPublicShareLink({
    required String itemId,
    required SharedItemType type,
    Duration? expiresIn,
  });

  /// Get public shared item by link ID
  Future<SharedItem?> getPublicSharedItem(String linkId);

  /// Track social engagement (views, imports, etc.)
  Future<void> trackSocialEngagement({
    required String itemId,
    required String userId,
    required SocialEngagementType type,
  });

  /// Get social engagement statistics
  Future<SocialEngagementStats> getSocialStats(String itemId);
}

/// Social operation record
class SocialOperation {
  final String id;
  final String operationType;
  final String itemId;
  final String fromUserId;
  final List<String> targetUserIds;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  SocialOperation({
    required this.id,
    required this.operationType,
    required this.itemId,
    required this.fromUserId,
    required this.targetUserIds,
    required this.metadata,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
    'operationType': operationType,
    'itemId': itemId,
    'fromUserId': fromUserId,
    'targetUserIds': targetUserIds,
    'metadata': metadata,
    'createdAt': createdAt,
  };
}

/// Shared item model
class SharedItem {
  final String id;
  final SharedItemType type;
  final String itemId;
  final String fromUserId;
  final String toUserId;
  final String? message;
  final String? customTitle;
  final SharedItemStatus status;
  final DateTime sharedAt;
  final DateTime? respondedAt;

  SharedItem({
    required this.id,
    required this.type,
    required this.itemId,
    required this.fromUserId,
    required this.toUserId,
    this.message,
    this.customTitle,
    required this.status,
    required this.sharedAt,
    this.respondedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'type': type.toString(),
    'itemId': itemId,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'message': message,
    'customTitle': customTitle,
    'status': status.toString(),
    'sharedAt': sharedAt,
    'respondedAt': respondedAt,
  };
}

/// Types of items that can be shared
enum SharedItemType {
  recipe,
  menu,
  shoppingList,
}

/// Status of a shared item
enum SharedItemStatus {
  pending,
  accepted,
  declined,
  expired,
}

/// Types of social engagement
enum SocialEngagementType {
  view,
  import,
  like,
  comment,
  share,
}

/// Social engagement statistics
class SocialEngagementStats {
  final String itemId;
  final int totalViews;
  final int totalImports;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final DateTime? lastEngagementAt;

  SocialEngagementStats({
    required this.itemId,
    required this.totalViews,
    required this.totalImports,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    this.lastEngagementAt,
  });

  /// Total engagement score
  int get totalEngagement => totalViews + totalImports + totalLikes + totalComments + totalShares;
}