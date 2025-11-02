/// Comprehensive shared shopping list model providing consistent sharing experience across all content types.
///
/// This model implements unified sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedRecipe and SharedMenu for consistent user experience.
/// It provides complete shopping list sharing capabilities while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles shared shopping list management and tracking:
/// - **Shopping List Snapshots**: Complete list preservation with all items for independent sharing and preview
/// - **Status Tracking**: Unified read/unread, joined/not-joined, dismissed/visible status management  
/// - **Attribution Preservation**: Proper shopping list attribution with source acknowledgment
/// - **Consistent User Interaction**: View/Join/Dismiss actions matching recipe and menu patterns
///
/// **What This Model Does NOT Handle:**
/// - Shopping list creation and editing operations (handled by shopping services)
/// - Collaborative list management (handled by collaborative shopping system)  
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Shopping list persistence and storage operations (handled by repositories and services)
///
/// **Shared Shopping List Features:**
/// - **Complete Shopping List Snapshots**: Full list preservation with all items and metadata for independent sharing
/// - **Unified Status Management**: Read/unread, joined/dismissed tracking consistent with other shared content
/// - **Attribution Preservation**: Proper source attribution maintained throughout sharing lifecycle
/// - **Preview Functionality**: Complete list preview before joining with item details
/// - **Consistent Actions**: View/Join/Dismiss pattern matching recipes and menus
///
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
/// 
/// // Track user engagement  
/// final viewedList = sharedShoppingList.markViewedBy(userId);
/// final joinedList = viewedList.markJoinedBy(userId);
/// 
/// // Handle user dismissal
/// final dismissedList = sharedShoppingList.markDismissedBy(userId);
/// final restoredList = dismissedList.undismissBy(userId);
/// 
/// // Check status and permissions
/// final canView = sharedShoppingList.canBeViewedBy(userId);
/// final isJoined = sharedShoppingList.isJoinedBy(userId);
/// final shouldShow = sharedShoppingList.shouldBeShownTo(userId);
/// 
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
///
/// This model extends BaseSharedContentModel and uses SharedContentStatusMixin for status management,
/// eliminating duplicate code while maintaining shopping list-specific features and direct collaboration.
/// Unlike recipes/menus, shopping lists use direct collaboration (not copy-on-write) and "joined" terminology.
class SharedShoppingList extends BaseSharedContentModel<List<UnifiedShoppingItem>>
    with SharedContentStatusMixin {
  
  // ===== SHOPPING LIST-SPECIFIC FIELDS =====
  
  /// Name of the shared shopping list for identification and display.
  final String listName;
  
  /// Optional description providing additional context for the shopping list.
  final String? listDescription;
  
  /// Complete snapshot of the shopping list items at the time of sharing.
  final List<UnifiedShoppingItem> listItems;

  // ===== ATTRIBUTION =====
  
  /// User identifier of the original shopping list owner.
  final String originalOwnerId;
  
  /// Cached display name of the original owner for UI performance.
  final String originalOwnerDisplayName;

  /// Creates a new shared shopping list with all required metadata.
  SharedShoppingList({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    required super.sharedToUserIds,
    DateTime? sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.viewedByUserIds = const [],
    super.engagedByUserIds = const [],
    super.dismissedByUserIds = const [],
    required this.listName,
    this.listDescription,
    required this.listItems,
    required this.originalOwnerId,
    required this.originalOwnerDisplayName,
  }) : super(sharedAt: sharedAt ?? DateTime.now());

  // ===== BASE CLASS IMPLEMENTATIONS =====
  
  @override
  String get contentTypeName => 'shopping_list';
  
  @override
  List<UnifiedShoppingItem> get contentSnapshot => listItems;
  
  @override
  String getContentTitle() => listName;
  
  @override
  String getContentDescription() => listDescription ?? itemSummary;
  
  @override
  BaseSharedContentModel<List<UnifiedShoppingItem>> copyWithStatus({
    int? viewCount,
    int? engagementCount,
    List<String>? viewedByUserIds,
    List<String>? engagedByUserIds,
    List<String>? dismissedByUserIds,
  }) {
    return copyWith(
      viewCount: viewCount,
      joinedCount: engagementCount,
      viewedByUserIds: viewedByUserIds,
      joinedByUserIds: engagedByUserIds,
      dismissedByUserIds: dismissedByUserIds,
    );
  }

  // ===== SHOPPING LIST-SPECIFIC PROPERTIES =====
  
  /// Join count getter for backward compatibility (maps to engagement count).
  int get joinCount => engagementCount;
  
  /// Joined by user IDs getter for backward compatibility (maps to engaged user IDs).
  List<String> get joinedByUserIds => engagedByUserIds;

  // ===== FACTORY CONSTRUCTORS =====

  /// Factory constructor for creating new shared shopping lists with auto-generated ID and intelligent defaults.
  factory SharedShoppingList.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    required String shareMessage,
    required String listName,
    String? listDescription,
    required List<UnifiedShoppingItem> listItems,
  }) {
    return SharedShoppingList(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      listName: listName,
      listDescription: listDescription,
      listItems: listItems,
      originalOwnerId: sharedByUserId,
      originalOwnerDisplayName: sharedByDisplayName,
    );
  }

  /// Creates a shared shopping list instance from Firestore repository data with robust error handling.
  factory SharedShoppingList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return SharedShoppingList(
      id: doc.id,
      sharedByUserId: (data['sharedByUserId'] as String?).orEmpty(),
      sharedByDisplayName: (data['sharedByDisplayName'] as String?).orDefault('Unknown User'),
      sharedToUserIds: List<String>.from((data['sharedToUserIds'] as List?).orEmpty()),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate().orNow(),
      shareMessage: (data['shareMessage'] as String?).orEmpty(),
      viewCount: (data['viewCount'] as int?).orZero(),
      engagementCount: (data['joinedCount'] as int?).orZero(),
      viewedByUserIds: List<String>.from((data['viewedByUserIds'] as List?).orEmpty()),
      engagedByUserIds: List<String>.from((data['joinedByUserIds'] as List?).orEmpty()),
      dismissedByUserIds: List<String>.from((data['dismissedByUserIds'] as List?).orEmpty()),
      listName: (data['listName'] as String?).orEmpty(),
      listDescription: data['listDescription'],
      listItems: (data['listItems'] as List<dynamic>?)
          ?.map((item) => UnifiedShoppingItem.fromFirestore(Map<String, dynamic>.from(item)))
          .toList() ?? [],
      originalOwnerId: data['originalOwnerId'] ?? data['sharedByUserId'] ?? '',
      originalOwnerDisplayName: data['originalOwnerDisplayName'] ?? data['sharedByDisplayName'] ?? 'Unknown User',
    );
  }
  
  /// Creates a shared shopping list instance from map data for compatibility.
  factory SharedShoppingList.fromMap(String id, Map<String, dynamic> data) {
    return SharedShoppingList(
      id: id,
      sharedByUserId: SerializationUtils.safeString(data, 'sharedByUserId'),
      sharedByDisplayName: SerializationUtils.safeString(data, 'sharedByDisplayName', defaultValue: 'Unknown User'),
      sharedToUserIds: SerializationUtils.safeStringList(data, 'sharedToUserIds'),
      sharedAt: SerializationUtils.safeDateTime(data, 'sharedAt').orNow(),
      shareMessage: SerializationUtils.safeString(data, 'shareMessage'),
      viewCount: SerializationUtils.safeInt(data, 'viewCount'),
      engagementCount: SerializationUtils.safeInt(data, 'joinedCount'),
      viewedByUserIds: SerializationUtils.safeStringList(data, 'viewedByUserIds'),
      engagedByUserIds: SerializationUtils.safeStringList(data, 'joinedByUserIds'),
      dismissedByUserIds: SerializationUtils.safeStringList(data, 'dismissedByUserIds'),
      listName: SerializationUtils.safeString(data, 'listName'),
      listDescription: SerializationUtils.safeNullableString(data, 'listDescription'),
      listItems: SerializationUtils.safeObjectList(
        data,
        'listItems',
        (itemData) => UnifiedShoppingItem.fromFirestore(itemData),
      ),
      originalOwnerId: SerializationUtils.safeString(data, 'originalOwnerId',
          defaultValue: SerializationUtils.safeString(data, 'sharedByUserId')),
      originalOwnerDisplayName: SerializationUtils.safeString(data, 'originalOwnerDisplayName',
          defaultValue: SerializationUtils.safeString(data, 'sharedByDisplayName', defaultValue: 'Unknown User')),
    );
  }

  // ===== SERIALIZATION =====

  /// Converts the shared shopping list to Firestore-compatible format for persistence.
  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(),
      'listName': listName,
      'listDescription': listDescription,
      'listItems': listItems.map((item) => item.toFirestore()).toList(),
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount': joinCount, // Map engagement to joined for shopping lists
      'joinedByUserIds': joinedByUserIds, // Map engaged to joined for shopping lists
    };
  }
  
  /// Converts the shared shopping list to JSON format for caching and client-side storage.
  Map<String, dynamic> toJson() {
    return {
      ...getCommonJsonFields(),
      'listName': listName,
      'listDescription': listDescription,
      'listItems': listItems.map((item) => item.toJson()).toList(),
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount': joinCount, // Map engagement to joined for shopping lists
      'joinedByUserIds': joinedByUserIds, // Map engaged to joined for shopping lists
    };
  }
  
  /// Creates a shared shopping list instance from JSON data for caching and deserialization.
  factory SharedShoppingList.fromJson(Map<String, dynamic> json) {
    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);
    
    return SharedShoppingList(
      id: commonFields['id'] as String,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedToUserIds: commonFields['sharedToUserIds'] as List<String>,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: json['joinedCount'] as int? ?? commonFields['engagementCount'] as int,
      viewedByUserIds: commonFields['viewedByUserIds'] as List<String>,
      engagedByUserIds: List<String>.from(json['joinedByUserIds'] ?? commonFields['engagedByUserIds'] ?? []),
      dismissedByUserIds: commonFields['dismissedByUserIds'] as List<String>,
      listName: json['listName'] as String,
      listDescription: json['listDescription'] as String?,
      listItems: (json['listItems'] as List<dynamic>?)
          ?.map((item) => UnifiedShoppingItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      originalOwnerId: json['originalOwnerId'] as String,
      originalOwnerDisplayName: json['originalOwnerDisplayName'] as String,
    );
  }

  // ===== TYPE-SAFE WRAPPER METHODS =====
  
  /// Type-safe wrapper methods that return SharedShoppingList instead of BaseSharedContentModel with List generic type
  /// These methods delegate to mixin implementations but provide concrete return types.
  
  @override
  SharedShoppingList markViewedBy(String userId) {
    final updated = super.markViewedBy(userId);
    if (updated == this) return this;
    return copyWith(
      viewCount: updated.viewCount,
      viewedByUserIds: updated.viewedByUserIds,
    );
  }
  
  @override
  SharedShoppingList markEngagedBy(String userId) {
    final updated = super.markEngagedBy(userId);
    if (updated == this) return this;
    return copyWith(
      joinedCount: updated.engagementCount,
      joinedByUserIds: updated.engagedByUserIds,
    );
  }
  
  @override
  SharedShoppingList markDismissedBy(String userId) {
    final updated = super.markDismissedBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }
  
  @override
  SharedShoppingList undismissBy(String userId) {
    final updated = super.undismissBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }

  // ===== SHOPPING LIST-SPECIFIC STATUS MANAGEMENT =====

  /// Check if shopping list has been joined by user (maps to engaged status).
  @override
  bool isJoinedBy(String userId) => isEngagedBy(userId);

  /// Check if shopping list can be viewed by user.
  @override
  bool canBeViewedBy(String userId) {
    return sharedToUserIds.contains(userId) || sharedByUserId == userId;
  }

  /// Check if shopping list should be shown to user.
  @override
  bool shouldBeShownTo(String userId) {
    return canBeViewedBy(userId) && !isDismissedBy(userId);
  }

  /// Mark shopping list as joined by user (maps to engaged status) - delegates to type-safe wrapper.
  @override
  SharedShoppingList markJoinedBy(String userId) => markEngagedBy(userId);

  /// Remove join status for user (maps to un-engaged status).
  SharedShoppingList unjoinBy(String userId) {
    if (!isJoinedBy(userId)) return this;
    
    final updatedEngagedByUserIds = engagedByUserIds.where((id) => id != userId).toList();
    return copyWith(
      engagementCount: updatedEngagedByUserIds.length,
      engagedByUserIds: updatedEngagedByUserIds,
    );
  }

  /// Remove dismissal for user (restore visibility) - delegates to mixin implementation.

  // ===== DISPLAY PROPERTIES =====

  /// Get shopping list item summary for preview
  String get itemSummary {
    if (listItems.isEmpty) return 'Tom lista';
    
    if (listItems.length <= 3) {
      return listItems.map((item) => item.name).join(', ');
    } else {
      final firstThree = listItems.take(3).map((item) => item.name).join(', ');
      final remaining = listItems.length - 3;
      return '$firstThree... (+$remaining till)';
    }
  }

  /// Get formatted item count
  String get itemCountText {
    final count = listItems.length;
    return count == 1 ? '1 artikel' : '$count artiklar';
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
  String get attributionText => 'Ursprungligen delad av $originalOwnerDisplayName';

  // ===== UTILITY METHODS =====

  /// Creates a copy of this shared shopping list with updated values.
  SharedShoppingList copyWith({
    String? id,
    String? sharedByUserId,
    String? sharedByDisplayName,
    List<String>? sharedToUserIds,
    String? shareMessage,
    DateTime? sharedAt,
    int? viewCount,
    int? engagementCount,
    int? joinedCount,
    List<String>? viewedByUserIds,
    List<String>? engagedByUserIds,
    List<String>? joinedByUserIds,
    List<String>? dismissedByUserIds,
    String? listName,
    String? listDescription,
    List<UnifiedShoppingItem>? listItems,
    String? originalOwnerId,
    String? originalOwnerDisplayName,
  }) {
    return SharedShoppingList(
      id: id ?? this.id,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      sharedByDisplayName: sharedByDisplayName ?? this.sharedByDisplayName,
      sharedToUserIds: sharedToUserIds ?? this.sharedToUserIds,
      shareMessage: shareMessage ?? this.shareMessage,
      sharedAt: sharedAt ?? this.sharedAt,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: joinedCount ?? engagementCount ?? this.engagementCount,
      viewedByUserIds: viewedByUserIds ?? this.viewedByUserIds,
      engagedByUserIds: joinedByUserIds ?? engagedByUserIds ?? this.engagedByUserIds,
      dismissedByUserIds: dismissedByUserIds ?? this.dismissedByUserIds,
      listName: listName ?? this.listName,
      listDescription: listDescription ?? this.listDescription,
      listItems: listItems ?? this.listItems,
      originalOwnerId: originalOwnerId ?? this.originalOwnerId,
      originalOwnerDisplayName: originalOwnerDisplayName ?? this.originalOwnerDisplayName,
    );
  }

  @override
  String toString() => 'SharedShoppingList(id: $id, listName: $listName, sharedBy: $sharedByDisplayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedShoppingList &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}