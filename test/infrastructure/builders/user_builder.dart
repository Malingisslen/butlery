/// Test data builder for UserProfile objects
/// 
/// Provides fluent API for creating test user instances with Swedish defaults.
library;

// ignore_for_file: prefer_final_fields

import 'package:butlery/models/user_profile.dart';

class UserBuilder {
  String _uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
  String _displayName = 'Test User';
  String _email = 'test@example.com';
  String? _bio;
  String? _avatarUrl;
  bool _isSearchable = true;
  bool _allowEmailSearch = false;
  int _friendsCount = 0;
  int _publicRecipesCount = 0;
  String? _fcmToken;
  DateTime? _fcmTokenUpdatedAt;
  bool _notificationsEnabled = true;
  DateTime _joinedAt = DateTime.now();
  DateTime _lastActiveAt = DateTime.now();
  Map<String, dynamic> _metadata = {};
  
  UserBuilder();
  
  /// Set user ID
  UserBuilder withId(String uid) {
    _uid = uid;
    return this;
  }
  
  /// Set display name
  UserBuilder withName(String name) {
    _displayName = name;
    return this;
  }
  
  /// Set email
  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }
  
  /// Set bio
  UserBuilder withBio(String bio) {
    _bio = bio;
    return this;
  }
  
  /// Set avatar URL
  UserBuilder withAvatarUrl(String avatarUrl) {
    _avatarUrl = avatarUrl;
    return this;
  }
  
  /// Set searchable status
  UserBuilder isSearchable(bool searchable) {
    _isSearchable = searchable;
    return this;
  }
  
  /// Set friend count
  UserBuilder withFriendCount(int count) {
    _friendsCount = count;
    return this;
  }
  
  /// Set public recipes count
  UserBuilder withPublicRecipesCount(int count) {
    _publicRecipesCount = count;
    return this;
  }
  
  /// Configure as Swedish user
  UserBuilder asSwedishUser() {
    _displayName = 'Sven Svensson';
    _email = 'sven@example.se';
    _bio = 'Matentusiast från Stockholm som älskar att laga mat';
    _metadata = {
      'country': 'Sweden',
      'language': 'sv',
      'timezone': 'Europe/Stockholm',
    };
    return this;
  }
  
  /// Configure as premium user
  UserBuilder asPremiumUser() {
    _metadata['isPremium'] = true;
    _metadata['premiumSince'] = DateTime.now().toIso8601String();
    _notificationsEnabled = true;
    return this;
  }
  
  /// Configure as chef user
  UserBuilder asChef() {
    _displayName = 'Chef Anders';
    _bio = 'Professionell kock med 15 års erfarenhet inom svensk och internationell mat';
    _publicRecipesCount = 50;
    _metadata['isVerifiedChef'] = true;
    return this;
  }
  
  /// Build the UserProfile instance
  UserProfile build() {
    return UserProfile(
      uid: _uid,
      displayName: _displayName,
      email: _email,
      bio: _bio,
      avatarUrl: _avatarUrl,
      isSearchable: _isSearchable,
      allowEmailSearch: _allowEmailSearch,
      friendsCount: _friendsCount,
      publicRecipeCount: _publicRecipesCount,
      fcmToken: _fcmToken,
      fcmTokenUpdatedAt: _fcmTokenUpdatedAt,
      notificationsEnabled: _notificationsEnabled,
      joinedAt: _joinedAt,
      lastActiveAt: _lastActiveAt,
    );
  }
}