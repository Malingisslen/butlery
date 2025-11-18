/// Comprehensive shared shopping list model providing consistent sharing experience across all content types.
/// This model implements unified sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedRecipe and SharedMenu for consistent user experience.
/// It provides complete shopping list sharing capabilities while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
/// **Single Responsibility Focus:**
/// This model exclusively handles shared shopping list management and tracking:
/// - **Shopping List Snapshots**: Complete list preservation with all items for independent sharing and preview
/// - **Status Tracking**: Unified read/unread, joined/not-joined, dismissed/visible status management
/// - **Attribution Preservation**: Proper shopping list attribution with source acknowledgment
/// - **Consistent User Interaction**: View/Join/Dismiss actions matching recipe and menu patterns
/// **What This Model Does NOT Handle:**
/// - Shopping list creation and editing operations (handled by shopping services)
/// - Collaborative list management (handled by collaborative shopping system)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Shopping list persistence and storage operations (handled by repositories and services)
/// **Shared Shopping List Features:**
/// - **Complete Shopping List Snapshots**: Full list preservation with all items and metadata for independent sharing
/// - **Unified Status Management**: Read/unread, joined/dismissed tracking consistent with other shared content
/// - **Attribution Preservation**: Proper source attribution maintained throughout sharing lifecycle
/// - **Preview Functionality**: Complete list preview before joining with item details
/// - **Consistent Actions**: View/Join/Dismiss pattern matching recipes and menus
/// **Usage Examples:**
/// ```dart
/// // Create new shared shopping list
/// final sharedShoppingList = SharedShoppingList.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckohandling - kanske något för er också?',
///   listName: 'Veckohandling v.45',
///   listDescription: 'Familjehandling för hela veckan',
///   listItems: groceryItems,
/// );
/// // Track user engagement
/// final viewedList = sharedShoppingList.markViewedBy(userId);
/// final joinedList = viewedList.markJoinedBy(userId);
/// // Handle user dismissal
/// final dismissedList = sharedShoppingList.markDismissedBy(userId);
/// final restoredList = dismissedList.undismissBy(userId);
/// // Check status and permissions
/// final canView = sharedShoppingList.canBeViewedBy(userId);
/// final isJoined = sharedShoppingList.isJoinedBy(userId);
/// final shouldShow = sharedShoppingList.shouldBeShownTo(userId);
/// // Get list summary for preview
/// final summary = sharedShoppingList.itemSummary; // '8 artiklar (mjölk, bröd, äpplen...)'
/// final timeAgo = sharedShoppingList.timeAgoText; // '2 dagar sedan'
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';

/// Shared shopping list model using unified base infrastructure for consistent shared content patterns.
/// This model extends BaseSharedContentModel and uses SharedContentStatusMixin for status management,
/// eliminating duplicate code while maintaining shopping list-specific features and direct collaboration.
/// Unlike recipes/menus, shopping lists use direct collaboration (not copy-on-write) and "joined" terminology.
class SharedShoppingList
    extends BaseSharedContentModel<List<UnifiedShoppingItem>>
    with SharedContentStatusMixin {
  // ===== SHOPPING LIST-SPECIFIC FIELDS =====

  /// Name of the shared shopping list for identification and display.
  final String listName;

  /// Optional description providing additional context for the shopping list.
  final String? listDescription;

  /// Number of items in the shopping list.
  /// **Issue #015**: Cached from items subcollection for UI performance.
  /// Items now stored in Firestore subcollection: shared_shopping_lists/{id}/items/{itemId}
  /// This count is maintained via atomic FieldValue.increment/decrement operations.
  final int itemCount;

  // ===== ATTRIBUTION =====

  /// User identifier of the original shopping list owner.
  final String originalOwnerId;

  /// Cached display name of the original owner for UI performance.
  final String originalOwnerDisplayName;

  /// Creates a new shared shopping list with all required metadata.
  /// **Issue #014**: sharedToUserIds removed from model. Repository layer handles adding
  /// members to Firestore subcollection after creation.
  /// **Issue #015**: listItems array removed. Items stored in Firestore subcollection.
  /// itemCount parameter required for caching item count from subcollection.
  SharedShoppingList({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    DateTime? sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.dismissalCount = 0,
    required this.listName,
    this.listDescription,
    required this.itemCount,
    required this.originalOwnerId,
    required this.originalOwnerDisplayName,
  }) : super(sharedAt: sharedAt ?? DateTime.now());

  // ===== BASE CLASS IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'shopping_list';

  @override
  List<UnifiedShoppingItem> get contentSnapshot => [];

  @override
  String getContentTitle() => listName;

  @override
  String getContentDescription() => listDescription ?? '$itemCount artiklar';

  @override
  BaseSharedContentModel<List<UnifiedShoppingItem>> copyWithStatus({
    int? viewCount,
    int? engagementCount,
    int? dismissalCount,
  }) {
    return copyWith(
      viewCount: viewCount,
      joinedCount: engagementCount,
      dismissalCount: dismissalCount,
    );
  }

  // ===== SHOPPING LIST-SPECIFIC PROPERTIES =====

  /// Join count getter for backward compatibility (maps to engagement count).
  int get joinCount => engagementCount;

  // ===== FACTORY CONSTRUCTORS =====

  /// Factory constructor for creating new shared shopping lists with auto-generated ID and intelligent defaults.
  /// **Issue #014**: sharedToUserIds still accepted for repository layer but NOT passed to constructor.
  /// Repository handles adding members to Firestore subcollection after creation.
  /// **Issue #015**: listItems parameter DEPRECATED. Items stored in subcollection.
  /// Pass either itemCount OR listItems (will calculate count from list for migration compatibility).
  factory SharedShoppingList.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String>
        sharedToUserIds, // Still accept but don't pass to constructor
    required String shareMessage,
    required String listName,
    String? listDescription,
    List<UnifiedShoppingItem>? listItems, // DEPRECATED - for migration compatibility only
    int? itemCount,
  }) {
    return SharedShoppingList(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      shareMessage: shareMessage,
      listName: listName,
      listDescription: listDescription,
      itemCount: itemCount ?? listItems?.length ?? 0,
      originalOwnerId: sharedByUserId,
      originalOwnerDisplayName: sharedByDisplayName,
    );
  }

  /// Creates a shared shopping list instance from Firestore repository data with robust error handling.
  /// **Issue #014**: Arrays removed. Uses parseCommonFieldsFromFirestore() for base fields.
  /// **Issue #015**: listItems array removed. Now reads itemCount from document.
  /// For migration compatibility, falls back to calculating from listItems array if itemCount missing.
  factory SharedShoppingList.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final commonFields =
        BaseSharedContentModel.parseCommonFieldsFromFirestore(data);

    // Migration compatibility: read itemCount or calculate from deprecated listItems array
    final itemCount = data['itemCount'] as int? ??
        (data['listItems'] as List<dynamic>?)?.length ??
        0;

    return SharedShoppingList(
      id: doc.id,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount:
          data['joinedCount'] as int? ?? commonFields['engagementCount'] as int,
      dismissalCount: commonFields['dismissalCount'] as int,
      listName: (data['listName'] as String?).orEmpty(),
      listDescription: data['listDescription'],
      itemCount: itemCount,
      originalOwnerId: data['originalOwnerId'] ?? data['sharedByUserId'] ?? '',
      originalOwnerDisplayName: data['originalOwnerDisplayName'] ??
          data['sharedByDisplayName'] ??
          'Unknown User',
    );
  }

  /// Creates a shared shopping list instance from map data for compatibility.
  /// **Issue #014**: Arrays removed. Uses parseCommonFieldsFromFirestore() for base fields.
  /// **Issue #015**: listItems array removed. Now reads itemCount from map.
  /// For migration compatibility, falls back to calculating from listItems array if itemCount missing.
  factory SharedShoppingList.fromMap(String id, Map<String, dynamic> data) {
    final commonFields =
        BaseSharedContentModel.parseCommonFieldsFromFirestore(data);

    // Migration compatibility: read itemCount or calculate from deprecated listItems array
    final itemCount = SerializationUtils.safeInt(data, 'itemCount',
        defaultValue: SerializationUtils.safeObjectList(
          data,
          'listItems',
          (itemData) => UnifiedShoppingItem.fromFirestore(itemData),
        ).length);

    return SharedShoppingList(
      id: id,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: SerializationUtils.safeInt(data, 'joinedCount',
          defaultValue: commonFields['engagementCount'] as int),
      dismissalCount: commonFields['dismissalCount'] as int,
      listName: SerializationUtils.safeString(data, 'listName'),
      listDescription:
          SerializationUtils.safeNullableString(data, 'listDescription'),
      itemCount: itemCount,
      originalOwnerId: SerializationUtils.safeString(data, 'originalOwnerId',
          defaultValue: SerializationUtils.safeString(data, 'sharedByUserId')),
      originalOwnerDisplayName: SerializationUtils.safeString(
          data, 'originalOwnerDisplayName',
          defaultValue: SerializationUtils.safeString(
              data, 'sharedByDisplayName',
              defaultValue: 'Unknown User')),
    );
  }

  // ===== SERIALIZATION =====

  /// Converts the shared shopping list to Firestore-compatible format for persistence.
  /// **Issue #014**: Arrays removed. Uses getCommonFirestoreFields() for base serialization.
  /// **Issue #015**: listItems array removed. Now writes itemCount field.
  /// Items stored in separate subcollection: shared_shopping_lists/{id}/items/{itemId}
  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(),
      'listName': listName,
      'listDescription': listDescription,
      'itemCount': itemCount,
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount':
          joinCount, // Map engagement count to joined count for shopping lists
    };
  }

  /// Converts the shared shopping list to JSON format for caching and client-side storage.
  /// **Issue #014**: Arrays removed. Uses getCommonJsonFields() for base serialization.
  /// **Issue #015**: listItems array removed. Now writes itemCount field.
  Map<String, dynamic> toJson() {
    return {
      ...getCommonJsonFields(),
      'listName': listName,
      'listDescription': listDescription,
      'itemCount': itemCount,
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount':
          joinCount, // Map engagement count to joined count for shopping lists
    };
  }

  /// Creates a shared shopping list instance from JSON data for caching and deserialization.
  /// **Issue #014**: Arrays removed. Uses parseCommonFieldsFromJson() for base fields.
  /// **Issue #015**: listItems array removed. Now reads itemCount from JSON.
  /// For migration compatibility, falls back to calculating from listItems array if itemCount missing.
  factory SharedShoppingList.fromJson(Map<String, dynamic> json) {
    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);

    // Migration compatibility: read itemCount or calculate from deprecated listItems array
    final itemCount = json['itemCount'] as int? ??
        (json['listItems'] as List<dynamic>?)?.length ??
        0;

    return SharedShoppingList(
      id: commonFields['id'] as String,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount:
          json['joinedCount'] as int? ?? commonFields['engagementCount'] as int,
      dismissalCount: commonFields['dismissalCount'] as int,
      listName: json['listName'] as String,
      listDescription: json['listDescription'] as String?,
      itemCount: itemCount,
      originalOwnerId: json['originalOwnerId'] as String,
      originalOwnerDisplayName: json['originalOwnerDisplayName'] as String,
    );
  }

  // ===== TYPE-SAFE WRAPPER METHODS (REMOVED - ISSUE #014) =====
  //
  // Note: Status-checking methods (markViewedBy, markEngagedBy, markDismissedBy, undismissBy)
  // removed from base class. Status tracking now handled by repository layer using Firestore
  // subcollections.
  //
  // Use repository methods instead:
  //   - repository.addView(listId, userId)
  //   - repository.addEngagement(listId, userId, action: 'join')
  //   - repository.addDismissal(listId, userId)
  //   - repository.removeDismissal(listId, userId)

  // ===== SHOPPING LIST-SPECIFIC STATUS MANAGEMENT (REMOVED - ISSUE #014) =====
  //
  // Note: Status-checking methods removed as arrays no longer exist in model.
  // Use repository methods for status checks:
  //   - repository.isMember(listId, userId) - Check if user is a member
  //   - repository.hasViewed(listId, userId) - Check if user has viewed
  //   - repository.hasEngaged(listId, userId) - Check if user has joined
  //   - repository.hasDismissed(listId, userId) - Check if user has dismissed
  //
  // Methods removed:
  //   - isJoinedBy(userId) - Use repository.hasEngaged(listId, userId)
  //   - canBeViewedBy(userId) - Use repository.isMember(listId, userId)
  //   - shouldBeShownTo(userId) - Use repository.shouldShow(listId, userId)
  //   - markJoinedBy(userId) - Use repository.addEngagement(listId, userId)
  //   - unjoinBy(userId) - Use repository.removeEngagement(listId, userId)

  // ===== DISPLAY PROPERTIES =====

  /// Get shopping list item summary for preview.
  /// **Issue #015**: Items stored in subcollection, so we only have itemCount.
  /// Cannot display individual item names without loading subcollection.
  /// Use itemCountText instead or load items separately if needed.
  @Deprecated('Use itemCountText instead. Items stored in subcollection (Issue #015).')
  String get itemSummary {
    return itemCountText;
  }

  /// Get formatted item count
  String get itemCountText {
    return itemCount == 1 ? '1 artikel' : '$itemCount artiklar';
  }

  /// Get time ago text in Swedish
  @override
  String get timeAgoText {
    timeago.setLocaleMessages('sv', timeago.SvMessages());
    return timeago.format(sharedAt, locale: 'sv');
  }

  /// Get sharing context text
  String get sharingContextText => 'Delad av $sharedByDisplayName';

  /// Get attribution text for joined lists
  String get attributionText =>
      'Ursprungligen delad av $originalOwnerDisplayName';

  // ===== UTILITY METHODS =====

  /// Creates a copy of this shared shopping list with updated values.
  /// **Issue #014**: Array parameters removed. Only counts can be updated.
  /// **Issue #015**: listItems parameter removed. Use itemCount instead.
  SharedShoppingList copyWith({
    String? id,
    String? sharedByUserId,
    String? sharedByDisplayName,
    String? shareMessage,
    DateTime? sharedAt,
    int? viewCount,
    int? engagementCount,
    int? joinedCount,
    int? dismissalCount,
    String? listName,
    String? listDescription,
    int? itemCount,
    String? originalOwnerId,
    String? originalOwnerDisplayName,
  }) {
    return SharedShoppingList(
      id: id ?? this.id,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      sharedByDisplayName: sharedByDisplayName ?? this.sharedByDisplayName,
      shareMessage: shareMessage ?? this.shareMessage,
      sharedAt: sharedAt ?? this.sharedAt,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: joinedCount ?? engagementCount ?? this.engagementCount,
      dismissalCount: dismissalCount ?? this.dismissalCount,
      listName: listName ?? this.listName,
      listDescription: listDescription ?? this.listDescription,
      itemCount: itemCount ?? this.itemCount,
      originalOwnerId: originalOwnerId ?? this.originalOwnerId,
      originalOwnerDisplayName:
          originalOwnerDisplayName ?? this.originalOwnerDisplayName,
    );
  }

  @override
  String toString() =>
      'SharedShoppingList(id: $id, listName: $listName, sharedBy: $sharedByDisplayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedShoppingList &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
