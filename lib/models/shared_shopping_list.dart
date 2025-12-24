import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';

/// Shared shopping list model using direct collaboration (not copy-on-write).
class SharedShoppingList
    extends BaseSharedContentModel<List<UnifiedShoppingItem>>
    with SharedContentStatusMixin {
  final String listName;
  final String? listDescription;

  /// Cached count from items subcollection for UI performance.
  final int itemCount;

  final String originalOwnerId;
  final String originalOwnerDisplayName;

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

  /// Maps to engagement count for shopping list terminology.
  int get joinCount => engagementCount;

  /// Creates a new shared shopping list with auto-generated ID.
  factory SharedShoppingList.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    required String shareMessage,
    required String listName,
    String? listDescription,
    @Deprecated('Items stored in subcollection')
    List<UnifiedShoppingItem>? listItems,
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

  factory SharedShoppingList.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final commonFields =
        BaseSharedContentModel.parseCommonFieldsFromFirestore(data);

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

  factory SharedShoppingList.fromMap(String id, Map<String, dynamic> data) {
    final commonFields =
        BaseSharedContentModel.parseCommonFieldsFromFirestore(data);

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

  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(),
      'listName': listName,
      'listDescription': listDescription,
      'itemCount': itemCount,
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount': joinCount,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...getCommonJsonFields(),
      'listName': listName,
      'listDescription': listDescription,
      'itemCount': itemCount,
      'originalOwnerId': originalOwnerId,
      'originalOwnerDisplayName': originalOwnerDisplayName,
      'joinedCount': joinCount,
    };
  }

  factory SharedShoppingList.fromJson(Map<String, dynamic> json) {
    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);

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

  @Deprecated('Use itemCountText instead')
  String get itemSummary {
    return itemCountText;
  }

  String get itemCountText {
    return itemCount == 1 ? '1 artikel' : '$itemCount artiklar';
  }

  @override
  String get timeAgoText {
    timeago.setLocaleMessages('sv', timeago.SvMessages());
    return timeago.format(sharedAt, locale: 'sv');
  }

  String get sharingContextText => 'Delad av $sharedByDisplayName';

  String get attributionText =>
      'Ursprungligen delad av $originalOwnerDisplayName';

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
