/// Comprehensive friend category data model providing friend organization and group management capabilities.
/// This model implements sophisticated friend categorization functionality following Single Responsibility Principle,
/// handling all aspects of friend organization including category metadata, member management, sorting,
/// and social grouping features. It provides comprehensive friend categorization capabilities while
/// maintaining clean separation from friend management and social interaction concerns.
/// **Single Responsibility Focus:**
/// This model exclusively handles friend category data and operations:
/// - **Category Metadata**: Complete category information including name, description, emoji, and ownership
/// - **Member Management**: Friend membership operations with add, remove, and containment checking
/// - **Organization Features**: Sorting, display customization, and hierarchical organization capabilities
/// - **Data Persistence**: Comprehensive serialization for Firestore and JSON with timestamp handling
/// **What This Model Does NOT Handle:**
/// - Friend relationship management (handled by friend models and operations)
/// - Social interaction and communication (handled by social features)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and user management (handled by permission services)
/// **Friend Category Features:**
/// - **Flexible Organization**: Custom categories with names, descriptions, emojis, and custom sorting
/// - **Member Management**: Complete member operations with duplicate prevention and membership tracking
/// - **Visual Customization**: Emoji support and display name formatting for enhanced user experience
/// - **Default Categories**: Predefined category templates for quick setup and standard organization
/// - **Comprehensive Metadata**: Creation tracking, update timestamps, and ownership information
/// **Usage Examples:**
/// ```dart
/// // Create custom friend category
/// final workCategory = FriendCategory.create(
///   ownerId: currentUserId,
///   name: 'Arbetskamrater',
///   description: 'Kollegor och arbetskamrater',
///   emoji: '💼',
///   sortOrder: 1,
/// );
/// // Add friends to category
/// final updatedCategory = workCategory
///     .addFriend(colleague1Id)
///     .addFriend(colleague2Id);
/// // Update category metadata
/// final renamedCategory = updatedCategory.updateMetadata(
///   name: 'Jobbet',
///   emoji: '🏢',
///   description: 'Alla från kontoret',
/// );
/// // Category utilities and display
/// final displayName = category.displayName; // '💼 Arbetskamrater'
/// final summary = category.summary; // '5 vänner'
/// final isEmpty = category.isEmpty;
/// ```

// lib/models/friend_category.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive friend category data model for organizing friends into groups with metadata and display customization.
/// Represents a friend category with all associated metadata including member management,
/// visual customization, and organizational features.
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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory constructor with auto-generated ID
  factory FriendCategory.create({
    required String ownerId,
    required String name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
    int? sortOrder,
    bool isDefault = false,
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
  }) {
    return FriendCategory(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      friendUserIds: friendUserIds ?? List<String>.from(this.friendUserIds),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Add friend to category
  FriendCategory addFriend(String friendUserId) {
    if (friendUserIds.contains(friendUserId)) return this;

    return copyWith(
      friendUserIds: [...friendUserIds, friendUserId],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove friend from category
  FriendCategory removeFriend(String friendUserId) {
    if (!friendUserIds.contains(friendUserId)) return this;

    return copyWith(
      friendUserIds: friendUserIds.where((id) => id != friendUserId).toList(),
      updatedAt: DateTime.now(),
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
      updatedAt: DateTime.now(),
    );
  }

  // Getters
  int get friendCount => friendUserIds.length;
  bool get isEmpty => friendUserIds.isEmpty;
  bool get isNotEmpty => friendUserIds.isNotEmpty;

  /// Compatibility getter for operations that expect memberIds
  List<String> get memberIds => friendUserIds;

  /// ✅ LAGT TILL: Alias för ownerId för kompatibilitet med permissions
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
      return 'Inga vänner';
    } else if (friendCount == 1) {
      return '1 vän';
    } else {
      return '$friendCount vänner';
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
    };
  }

  /// Create from repository data
  factory FriendCategory.fromMap(String id, Map<String, dynamic> data) {
    return FriendCategory(
      id: id,
      ownerId: data['ownerId'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      emoji: data['emoji'] as String?,
      friendUserIds: List<String>.from(data['friendUserIds'] ?? []),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      sortOrder: data['sortOrder'] as int? ?? 0,
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  /// JSON serialization för caching
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
    };
  }

  factory FriendCategory.fromJson(Map<String, dynamic> json) {
    return FriendCategory(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      friendUserIds: List<String>.from(json['friendUserIds'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
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

  /// Helper method for parsing timestamps from repository data
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map) {
        // Handle raw timestamp data from Firestore
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + nanoseconds ~/ 1000000);
        }
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle ISO string format
        return DateTime.parse(timestamp);
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}

/// Predefined category data för snabb setup
class DefaultFriendCategories {
  static const List<Map<String, dynamic>> defaults = [
    {
      'name': 'Familj',
      'description': 'Familjemedlemmar',
      'emoji': '👨‍👩‍👧‍👦',
      'sortOrder': 0,
    },
    {
      'name': 'Vänner',
      'description': 'Nära vänner',
      'emoji': '👥',
      'sortOrder': 1,
    },
    {
      'name': 'Grannar',
      'description': 'Grannar och lokalområdet',
      'emoji': '🏠',
      'sortOrder': 2,
    },
    {
      'name': 'Jobbet',
      'description': 'Kollegor och arbetskompisar',
      'emoji': '💼',
      'sortOrder': 3,
    },
    {
      'name': 'Matgrupp',
      'description': 'Personer som älskar att laga mat',
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

/// Category statistics för analytics
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
