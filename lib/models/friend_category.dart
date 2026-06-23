/// Friend category model for organizing friends into groups.
/// Supports inline member arrays and optional subcollection-based member storage for scalability.

// lib/models/friend_category.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

class FriendCategory {
  final String id;
  final String ownerId; // Who created this category
  final String name; // "Familj", "Jobbet", "Grannar", etc.
  final String? description; // Optional description
  final String? emoji; // Optional emoji for visual recognition
  final List<String> friendUserIds; // List of friend user IDs in this category
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder; // For custom ordering
  final bool isDefault; // Built-in categories like "Alla vänner"
  final bool isHousehold; // Household group for allergen aggregation

  FriendCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.emoji,
    this.friendUserIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isHousehold = false,
  }) : createdAt = createdAt ?? clock.now(),
       updatedAt = updatedAt ?? clock.now();

  /// Factory constructor with auto-generated ID
  factory FriendCategory.create({
    required String ownerId,
    required String name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
    int? sortOrder,
    bool isDefault = false,
    bool isHousehold = false,
  }) {
    return FriendCategory(
      id: const Uuid().v4(),
      ownerId: ownerId,
      name: name,
      description: description,
      emoji: emoji,
      friendUserIds: friendUserIds ?? [],
      sortOrder: sortOrder ?? 0,
      isDefault: isDefault,
      isHousehold: isHousehold,
    );
  }

  /// Create copy with updated values
  FriendCategory copyWith({
    String? ownerId,
    String? name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
    DateTime? updatedAt,
    int? sortOrder,
    bool? isDefault,
    bool? isHousehold,
  }) {
    return FriendCategory(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      friendUserIds: friendUserIds ?? List<String>.from(this.friendUserIds),
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isHousehold: isHousehold ?? this.isHousehold,
    );
  }

  /// Add friend to category
  FriendCategory addFriend(String friendUserId) {
    if (friendUserIds.contains(friendUserId)) return this;

    return copyWith(
      friendUserIds: [...friendUserIds, friendUserId],
      updatedAt: clock.now(),
    );
  }

  /// Remove friend from category
  FriendCategory removeFriend(String friendUserId) {
    if (!friendUserIds.contains(friendUserId)) return this;

    return copyWith(
      friendUserIds: friendUserIds.where((id) => id != friendUserId).toList(),
      updatedAt: clock.now(),
    );
  }

  /// Update category metadata
  FriendCategory updateMetadata({
    String? name,
    String? description,
    String? emoji,
    int? sortOrder,
  }) {
    return copyWith(
      name: name,
      description: description,
      emoji: emoji,
      sortOrder: sortOrder,
      updatedAt: clock.now(),
    );
  }

  int get friendCount => friendUserIds.length;
  bool get isEmpty => friendCount == 0;
  bool get isNotEmpty => friendCount > 0;

  /// Compatibility getter for operations that expect memberIds
  List<String> get memberIds => friendUserIds;

  /// All member IDs including the owner — for queries that need the full group
  List<String> get allMemberIds => [ownerId, ...friendUserIds];

  /// Added: Alias for ownerId for compatibility with permissions
  String get createdBy => ownerId;

  /// Check if friend is in this category
  bool containsFriend(String friendUserId) =>
      friendUserIds.contains(friendUserId);

  /// Get display name with emoji
  String get displayName {
    if (emoji != null && emoji!.isNotEmpty) {
      return '$emoji $name';
    }
    return name;
  }

  /// Get category summary for UI
  String get summary {
    if (isEmpty) {
      return AppLocale.current.friendSummaryNoFriends;
    } else if (friendCount == 1) {
      return AppLocale.current.friendSummaryOneFriend;
    } else {
      return AppLocale.current.friendSummaryCount(friendCount);
    }
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'friendUserIds': friendUserIds,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'updatedAt': AppTimestamp.fromDateTime(updatedAt).toFirestore(),
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'isHousehold': isHousehold,
    };
  }

  /// Create from repository data
  factory FriendCategory.fromMap(String id, Map<String, dynamic> data) {
    return FriendCategory(
      id: id,
      ownerId: SerializationUtils.safeString(data, 'ownerId'),
      name: SerializationUtils.safeString(data, 'name'),
      description: SerializationUtils.safeNullableString(data, 'description'),
      emoji: SerializationUtils.safeNullableString(data, 'emoji'),
      friendUserIds: SerializationUtils.safeStringList(data, 'friendUserIds'),
      createdAt: SerializationUtils.parseRequiredDateTimeValue(
        data['createdAt'],
      ),
      updatedAt: SerializationUtils.parseRequiredDateTimeValue(
        data['updatedAt'],
      ),
      sortOrder: SerializationUtils.safeInt(data, 'sortOrder'),
      isDefault: SerializationUtils.safeBool(data, 'isDefault'),
      isHousehold: SerializationUtils.safeBool(data, 'isHousehold'),
    );
  }

  /// JSON serialization for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'friendUserIds': friendUserIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'isHousehold': isHousehold,
    };
  }

  factory FriendCategory.fromJson(Map<String, dynamic> json) {
    return FriendCategory(
      id: SerializationUtils.safeString(json, 'id'),
      ownerId: SerializationUtils.safeString(json, 'ownerId'),
      name: SerializationUtils.safeString(json, 'name'),
      description: SerializationUtils.safeNullableString(json, 'description'),
      emoji: SerializationUtils.safeNullableString(json, 'emoji'),
      friendUserIds: SerializationUtils.safeStringList(json, 'friendUserIds'),
      createdAt:
          SerializationUtils.safeDateTime(json, 'createdAt') ?? clock.now(),
      updatedAt:
          SerializationUtils.safeDateTime(json, 'updatedAt') ?? clock.now(),
      sortOrder: SerializationUtils.safeInt(json, 'sortOrder'),
      isDefault: SerializationUtils.safeBool(json, 'isDefault'),
      isHousehold: SerializationUtils.safeBool(json, 'isHousehold'),
    );
  }

  @override
  String toString() {
    return 'FriendCategory(id: $id, name: $name, friends: $friendCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined category data for quick setup
class DefaultFriendCategories {
  static List<Map<String, dynamic>> get defaults => [
    {
      'name': AppLocale.current.friendCategoryDefaultFamily,
      'description': AppLocale.current.friendCategoryDefaultFamilyDesc,
      'emoji': '👨‍👩‍👧‍👦',
      'sortOrder': 0,
    },
    {
      'name': AppLocale.current.friendCategoryDefaultFriends,
      'description': AppLocale.current.friendCategoryDefaultFriendsDesc,
      'emoji': '👥',
      'sortOrder': 1,
    },
    {
      'name': AppLocale.current.friendCategoryDefaultNeighbors,
      'description': AppLocale.current.friendCategoryDefaultNeighborsDesc,
      'emoji': '🏠',
      'sortOrder': 2,
    },
    {
      'name': AppLocale.current.friendCategoryDefaultWork,
      'description': AppLocale.current.friendCategoryDefaultWorkDesc,
      'emoji': '💼',
      'sortOrder': 3,
    },
    {
      'name': AppLocale.current.friendCategoryDefaultFoodGroup,
      'description': AppLocale.current.friendCategoryDefaultFoodGroupDesc,
      'emoji': '👨‍🍳',
      'sortOrder': 4,
    },
  ];

  /// Create default categories for a user
  static List<FriendCategory> createDefaultsForUser(String ownerId) {
    return defaults.map((categoryData) {
      return FriendCategory.create(
        ownerId: ownerId,
        name: categoryData['name'] as String,
        description: categoryData['description'] as String?,
        emoji: categoryData['emoji'] as String?,
        sortOrder: categoryData['sortOrder'] as int,
      );
    }).toList();
  }
}

/// Category statistics for analytics
class CategoryStats {
  final String categoryId;
  final String categoryName;
  final int totalFriends;
  final int activeSharedLists;
  final DateTime lastUsed;

  CategoryStats({
    required this.categoryId,
    required this.categoryName,
    required this.totalFriends,
    required this.activeSharedLists,
    required this.lastUsed,
  });

  factory CategoryStats.fromCategory(FriendCategory category) {
    return CategoryStats(
      categoryId: category.id,
      categoryName: category.name,
      totalFriends: category.friendCount,
      activeSharedLists: 0, // Will be calculated by service
      lastUsed: category.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'totalFriends': totalFriends,
      'activeSharedLists': activeSharedLists,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }
}
