/// User Profile Factory for generating test user profiles
///
/// Provides factory methods for creating UserProfile instances
/// with configurable properties for testing.
library;

import 'package:butlery/models/user_profile.dart';

/// Factory for creating test UserProfile instances
class UserProfileFactory {
  /// Private constructor to prevent instantiation
  UserProfileFactory._();

  /// Build a UserProfile with configurable properties
  static UserProfile build({
    String? uid,
    String? email,
    String displayName = 'Test User',
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool notificationsEnabled = true,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
  }) {
    return UserProfile(
      uid: uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email ?? 'test@example.com',
      displayName: displayName,
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      joinedAt: joinedAt ?? DateTime.now(),
      lastActiveAt: lastActiveAt ?? DateTime.now(),
      isOnline: isOnline,
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled,
      cookingSkillLevel: cookingSkillLevel,
      cuisineAffinities: cuisineAffinities,
      bio: bio,
    );
  }

  /// Build a list of user profiles
  static List<UserProfile> buildList({
    int count = 3,
    String namePrefix = 'User',
  }) {
    return List.generate(
      count,
      (index) => build(
        uid: 'user_$index',
        displayName: '$namePrefix ${index + 1}',
        email: 'user$index@example.com',
      ),
    );
  }

  /// Build a searchable user profile
  static UserProfile buildSearchable({
    String? uid,
    String displayName = 'Searchable User',
  }) {
    return build(
      uid: uid,
      displayName: displayName,
      isSearchable: true,
      allowEmailSearch: true,
      email: 'searchable@example.com',
    );
  }

  /// Build an online user profile
  static UserProfile buildOnline({
    String? uid,
    String displayName = 'Online User',
  }) {
    return build(
      uid: uid,
      displayName: displayName,
      isOnline: true,
      lastActiveAt: DateTime.now(),
    );
  }

  /// Build a user with notification settings
  static UserProfile buildWithNotifications({
    String? uid,
    String displayName = 'Notifiable User',
    String? fcmToken,
    bool notificationsEnabled = true,
  }) {
    return build(
      uid: uid,
      displayName: displayName,
      fcmToken: fcmToken ?? 'fcm_token_123',
      fcmTokenUpdatedAt: DateTime.now(),
      notificationsEnabled: notificationsEnabled,
    );
  }

  /// Build a social user with friends and recipes
  static UserProfile buildSocial({
    String? uid,
    String displayName = 'Social User',
    int friendsCount = 10,
    int publicRecipeCount = 25,
  }) {
    return build(
      uid: uid,
      displayName: displayName,
      friendsCount: friendsCount,
      publicRecipeCount: publicRecipeCount,
      isSearchable: true,
    );
  }
}
