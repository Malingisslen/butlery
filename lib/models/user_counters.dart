// lib/models/user_counters.dart

import 'package:butlery/core/utils/serialization_utils.dart';

/// Denormalized counters for user-facing metrics.
/// Stored in users/{userId}/counters/shared_content document.
/// Updated via Cloud Functions or repository increment operations.
///
/// This model addresses QUERY-CRITICAL-003 by providing pre-computed
/// counts instead of requiring collection scans for unread counts.
class UserCounters {
  /// User ID these counters belong to
  final String userId;

  /// Unread shared recipes (not viewed by user)
  final int unreadSharedRecipes;

  /// Unread shared menus (not viewed by user)
  final int unreadSharedMenus;

  /// Unread shared shopping lists (not viewed by user)
  final int unreadSharedShoppingLists;

  /// Total shared content received
  final int totalSharedContent;

  /// Unread conversation messages
  final int unreadMessages;

  /// Pending friend requests
  final int pendingFriendRequests;

  /// When counters were last updated
  final DateTime lastUpdated;

  const UserCounters({
    required this.userId,
    this.unreadSharedRecipes = 0,
    this.unreadSharedMenus = 0,
    this.unreadSharedShoppingLists = 0,
    this.totalSharedContent = 0,
    this.unreadMessages = 0,
    this.pendingFriendRequests = 0,
    required this.lastUpdated,
  });

  /// Create empty counters for a new user
  factory UserCounters.empty(String userId) {
    return UserCounters(
      userId: userId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from Firestore document
  factory UserCounters.fromFirestore(String userId, Map<String, dynamic> data) {
    return UserCounters(
      userId: userId,
      unreadSharedRecipes:
          SerializationUtils.safeInt(data, 'unreadSharedRecipes'),
      unreadSharedMenus: SerializationUtils.safeInt(data, 'unreadSharedMenus'),
      unreadSharedShoppingLists:
          SerializationUtils.safeInt(data, 'unreadSharedShoppingLists'),
      totalSharedContent:
          SerializationUtils.safeInt(data, 'totalSharedContent'),
      unreadMessages: SerializationUtils.safeInt(data, 'unreadMessages'),
      pendingFriendRequests:
          SerializationUtils.safeInt(data, 'pendingFriendRequests'),
      lastUpdated: SerializationUtils.safeDateTime(data, 'lastUpdated') ??
          DateTime.now(),
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'unreadSharedRecipes': unreadSharedRecipes,
      'unreadSharedMenus': unreadSharedMenus,
      'unreadSharedShoppingLists': unreadSharedShoppingLists,
      'totalSharedContent': totalSharedContent,
      'unreadMessages': unreadMessages,
      'pendingFriendRequests': pendingFriendRequests,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Get total unread shared content count
  int get totalUnreadSharedContent =>
      unreadSharedRecipes + unreadSharedMenus + unreadSharedShoppingLists;

  /// Get counter value by content type key
  int getCounterForType(String type) {
    switch (type) {
      case 'recipes':
      case 'shared_recipes':
        return unreadSharedRecipes;
      case 'menus':
      case 'shared_menus':
        return unreadSharedMenus;
      case 'shopping_lists':
      case 'shared_shopping_lists':
        return unreadSharedShoppingLists;
      case 'messages':
        return unreadMessages;
      case 'friend_requests':
        return pendingFriendRequests;
      default:
        return 0;
    }
  }

  /// Create copy with updated counter
  UserCounters incrementCounter(String type, {int by = 1}) {
    switch (type) {
      case 'recipes':
      case 'shared_recipes':
        return copyWith(unreadSharedRecipes: unreadSharedRecipes + by);
      case 'menus':
      case 'shared_menus':
        return copyWith(unreadSharedMenus: unreadSharedMenus + by);
      case 'shopping_lists':
      case 'shared_shopping_lists':
        return copyWith(
            unreadSharedShoppingLists: unreadSharedShoppingLists + by);
      case 'messages':
        return copyWith(unreadMessages: unreadMessages + by);
      case 'friend_requests':
        return copyWith(pendingFriendRequests: pendingFriendRequests + by);
      default:
        return this;
    }
  }

  /// Create copy with decremented counter (min 0)
  UserCounters decrementCounter(String type, {int by = 1}) {
    switch (type) {
      case 'recipes':
      case 'shared_recipes':
        return copyWith(
          unreadSharedRecipes:
              (unreadSharedRecipes - by).clamp(0, unreadSharedRecipes),
        );
      case 'menus':
      case 'shared_menus':
        return copyWith(
          unreadSharedMenus:
              (unreadSharedMenus - by).clamp(0, unreadSharedMenus),
        );
      case 'shopping_lists':
      case 'shared_shopping_lists':
        return copyWith(
          unreadSharedShoppingLists: (unreadSharedShoppingLists - by)
              .clamp(0, unreadSharedShoppingLists),
        );
      case 'messages':
        return copyWith(
          unreadMessages: (unreadMessages - by).clamp(0, unreadMessages),
        );
      case 'friend_requests':
        return copyWith(
          pendingFriendRequests:
              (pendingFriendRequests - by).clamp(0, pendingFriendRequests),
        );
      default:
        return this;
    }
  }

  UserCounters copyWith({
    int? unreadSharedRecipes,
    int? unreadSharedMenus,
    int? unreadSharedShoppingLists,
    int? totalSharedContent,
    int? unreadMessages,
    int? pendingFriendRequests,
    DateTime? lastUpdated,
  }) {
    return UserCounters(
      userId: userId,
      unreadSharedRecipes: unreadSharedRecipes ?? this.unreadSharedRecipes,
      unreadSharedMenus: unreadSharedMenus ?? this.unreadSharedMenus,
      unreadSharedShoppingLists:
          unreadSharedShoppingLists ?? this.unreadSharedShoppingLists,
      totalSharedContent: totalSharedContent ?? this.totalSharedContent,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      pendingFriendRequests:
          pendingFriendRequests ?? this.pendingFriendRequests,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserCounters(userId: $userId, unreadShared: $totalUnreadSharedContent, messages: $unreadMessages)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserCounters && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}

/// Firestore field increment operations for atomic counter updates.
/// Use with FieldValue.increment() for concurrent-safe updates.
class UserCounterIncrements {
  static const String unreadSharedRecipes = 'unreadSharedRecipes';
  static const String unreadSharedMenus = 'unreadSharedMenus';
  static const String unreadSharedShoppingLists = 'unreadSharedShoppingLists';
  static const String totalSharedContent = 'totalSharedContent';
  static const String unreadMessages = 'unreadMessages';
  static const String pendingFriendRequests = 'pendingFriendRequests';

  /// Get field name for content type
  static String fieldForType(String type) {
    switch (type) {
      case 'recipes':
      case 'shared_recipes':
        return unreadSharedRecipes;
      case 'menus':
      case 'shared_menus':
        return unreadSharedMenus;
      case 'shopping_lists':
      case 'shared_shopping_lists':
        return unreadSharedShoppingLists;
      case 'messages':
        return unreadMessages;
      case 'friend_requests':
        return pendingFriendRequests;
      default:
        throw ArgumentError('Unknown counter type: $type');
    }
  }
}
