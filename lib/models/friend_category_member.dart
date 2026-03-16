// lib/models/friend_category_member.dart

import 'package:butlery/core/utils/serialization_utils.dart';

/// Junction document for friend category membership.
/// Stored at: users/{ownerId}/friendCategories/{categoryId}/members/{friendId}
///
/// Enables scalable friend category membership beyond Firestore's 1MB document limit.
/// Uses two-way indexing for efficient queries in both directions.
class FriendCategoryMember {
  /// The friend's user ID (also used as document ID)
  final String friendId;

  /// The category this member belongs to
  final String categoryId;

  /// The owner of the category
  final String ownerId;

  /// When this membership was created
  final DateTime addedAt;

  /// Optional display name cached for list rendering
  final String? displayName;

  /// Optional avatar URL cached for list rendering
  final String? avatarUrl;

  const FriendCategoryMember({
    required this.friendId,
    required this.categoryId,
    required this.ownerId,
    required this.addedAt,
    this.displayName,
    this.avatarUrl,
  });

  /// Create a new membership
  factory FriendCategoryMember.create({
    required String friendId,
    required String categoryId,
    required String ownerId,
    String? displayName,
    String? avatarUrl,
  }) {
    return FriendCategoryMember(
      friendId: friendId,
      categoryId: categoryId,
      ownerId: ownerId,
      addedAt: DateTime.now(),
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  /// Create from Firestore document
  factory FriendCategoryMember.fromFirestore(
    String friendId,
    Map<String, dynamic> data,
  ) {
    return FriendCategoryMember(
      friendId: friendId,
      categoryId: SerializationUtils.safeString(data, 'categoryId'),
      ownerId: SerializationUtils.safeString(data, 'ownerId'),
      addedAt: SerializationUtils.safeRequiredDateTime(data, 'addedAt'),
      displayName: SerializationUtils.safeNullableString(data, 'displayName'),
      avatarUrl: SerializationUtils.safeNullableString(data, 'avatarUrl'),
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'ownerId': ownerId,
      'addedAt': addedAt,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'friendId': friendId,
      'categoryId': categoryId,
      'ownerId': ownerId,
      'addedAt': addedAt.toIso8601String(),
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  /// Create from JSON
  factory FriendCategoryMember.fromJson(Map<String, dynamic> json) {
    return FriendCategoryMember(
      friendId: json['friendId'] as String,
      categoryId: json['categoryId'] as String,
      ownerId: json['ownerId'] as String,
      addedAt: SerializationUtils.safeRequiredDateTime(json, 'addedAt'),
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  @override
  String toString() =>
      'FriendCategoryMember(friendId: $friendId, categoryId: $categoryId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendCategoryMember &&
        other.friendId == friendId &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode => Object.hash(friendId, categoryId);
}

/// Inverse index document for efficient "what categories is this friend in?" queries.
/// Stored at: users/{friendId}/categoryMemberships/{categoryId}
class CategoryMembership {
  /// The category ID (also used as document ID)
  final String categoryId;

  /// The owner of the category
  final String ownerId;

  /// The category name for display
  final String categoryName;

  /// Optional emoji for the category
  final String? categoryEmoji;

  /// When this membership was created
  final DateTime addedAt;

  const CategoryMembership({
    required this.categoryId,
    required this.ownerId,
    required this.categoryName,
    this.categoryEmoji,
    required this.addedAt,
  });

  /// Create from Firestore document
  factory CategoryMembership.fromFirestore(
    String categoryId,
    Map<String, dynamic> data,
  ) {
    return CategoryMembership(
      categoryId: categoryId,
      ownerId: SerializationUtils.safeString(data, 'ownerId'),
      categoryName: SerializationUtils.safeString(data, 'categoryName'),
      categoryEmoji:
          SerializationUtils.safeNullableString(data, 'categoryEmoji'),
      addedAt: SerializationUtils.safeRequiredDateTime(data, 'addedAt'),
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'categoryName': categoryName,
      'categoryEmoji': categoryEmoji,
      'addedAt': addedAt,
    };
  }

  @override
  String toString() =>
      'CategoryMembership(categoryId: $categoryId, owner: $ownerId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryMembership && other.categoryId == categoryId;
  }

  @override
  int get hashCode => categoryId.hashCode;
}
