// lib/models/user_profile.dart

import '../core/mixins/json_serializable_mixin.dart';
import '../core/types/app_timestamp.dart';


class UserProfile with JsonSerializableMixin {
  final String uid;
  final String displayName;
  final String email;
  final String? bio;
  final String? avatarUrl;
  final bool isSearchable;
  final bool allowEmailSearch;
  final int publicRecipeCount;
  final int friendsCount;
  final DateTime joinedAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  
  // Notification system fields
  final String? fcmToken;           // Firebase Cloud Messaging token
  final DateTime? fcmTokenUpdatedAt; // When token was last updated
  final bool notificationsEnabled;  // Master notification toggle

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio,
    this.avatarUrl,
    this.isSearchable = true,
    this.allowEmailSearch = false,
    this.publicRecipeCount = 0,
    this.friendsCount = 0,
    required this.joinedAt,
    required this.lastActiveAt,
    this.isOnline = false,
    // Notification fields
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.notificationsEnabled = true, // Default to enabled
  });

  /// Create copy with updated values
  UserProfile copyWith({
    String? displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    int? publicRecipeCount,
    int? friendsCount,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    // Notification fields
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool? notificationsEnabled,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSearchable: isSearchable ?? this.isSearchable,
      allowEmailSearch: allowEmailSearch ?? this.allowEmailSearch,
      publicRecipeCount: publicRecipeCount ?? this.publicRecipeCount,
      friendsCount: friendsCount ?? this.friendsCount,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      // Notification fields
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  /// Check if profile matches search term
  bool matchesSearchTerm(String query) {
    final normalizedQuery = query.toLowerCase();
    return displayName.toLowerCase().contains(normalizedQuery) ||
        (allowEmailSearch && email.toLowerCase().contains(normalizedQuery));
  }

  /// Get initials for avatar fallback
  String get initials {
    if (displayName.isEmpty) return '?';

    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Time since last active
  String get lastActiveText {
    final now = DateTime.now();
    final difference = now.difference(lastActiveAt);

    if (isOnline) {
      return 'Online';
    } else if (difference.inMinutes < 1) {
      return 'Aktiv nyss';
    } else if (difference.inHours < 1) {
      return 'Aktiv för ${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return 'Aktiv för ${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return 'Aktiv för ${difference.inDays} dagar sedan';
    } else {
      return 'Aktiv för ${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Check if FCM token is valid (not older than 30 days)
  bool get hasFreshFCMToken {
    if (fcmToken == null || fcmTokenUpdatedAt == null) return false;
    
    final now = DateTime.now();
    final tokenAge = now.difference(fcmTokenUpdatedAt!);
    return tokenAge.inDays < 30; // FCM tokens should be refreshed regularly
  }

  /// Check if user can receive push notifications
  bool get canReceiveNotifications {
    return notificationsEnabled && fcmToken != null && fcmToken!.isNotEmpty;
  }

  /// Time since joined
  String get memberSinceText {
    final now = DateTime.now();
    final difference = now.difference(joinedAt);

    if (difference.inDays < 30) {
      return 'Medlem i ${difference.inDays} dagar';
    } else if (difference.inDays < 365) {
      return 'Medlem i ${(difference.inDays / 30).floor()} månader';
    } else {
      return 'Medlem i ${(difference.inDays / 365).floor()} år';
    }
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'isSearchable': isSearchable,
      'allowEmailSearch': allowEmailSearch,
      'publicRecipeCount': publicRecipeCount,
      'friendsCount': friendsCount,
      'joinedAt': AppTimestamp.fromDateTime(joinedAt).toFirestore(),
      'lastActiveAt': AppTimestamp.fromDateTime(lastActiveAt).toFirestore(),
      'isOnline': isOnline,
      // Notification fields
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null ? AppTimestamp.fromDateTime(fcmTokenUpdatedAt!).toFirestore() : null,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'isSearchable': isSearchable,
      'allowEmailSearch': allowEmailSearch,
      'publicRecipeCount': publicRecipeCount,
      'friendsCount': friendsCount,
      'joinedAt': serializeDateTime(joinedAt),
      'lastActiveAt': serializeDateTime(lastActiveAt),
      'isOnline': isOnline,
      // Notification fields
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null ? serializeDateTime(fcmTokenUpdatedAt!) : null,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  /// Create from repository data (removes Firebase dependency from model)
  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      bio: data['bio'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      isSearchable: data['isSearchable'] as bool? ?? true,
      allowEmailSearch: data['allowEmailSearch'] as bool? ?? false,
      publicRecipeCount: data['publicRecipeCount'] as int? ?? 0,
      friendsCount: data['friendsCount'] as int? ?? 0,
      joinedAt: data['joinedAt'] is DateTime 
          ? data['joinedAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(data['joinedAt'] as int),
      lastActiveAt: data['lastActiveAt'] is DateTime 
          ? data['lastActiveAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(data['lastActiveAt'] as int),
      isOnline: data['isOnline'] as bool? ?? false,
      // Notification fields
      fcmToken: data['fcmToken'] as String?,
      fcmTokenUpdatedAt: data['fcmTokenUpdatedAt'] != null
          ? (data['fcmTokenUpdatedAt'] is DateTime 
              ? data['fcmTokenUpdatedAt'] as DateTime
              : DateTime.fromMillisecondsSinceEpoch(data['fcmTokenUpdatedAt'] as int))
          : null,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
    );
  }


  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isSearchable: json['isSearchable'] as bool? ?? true,
      allowEmailSearch: json['allowEmailSearch'] as bool? ?? false,
      publicRecipeCount: json['publicRecipeCount'] as int? ?? 0,
      friendsCount: json['friendsCount'] as int? ?? 0,
      joinedAt: UserProfile._deserializeDateTime(json['joinedAt']) ?? DateTime.now(),
      lastActiveAt: UserProfile._deserializeDateTime(json['lastActiveAt']) ?? DateTime.now(),
      isOnline: json['isOnline'] as bool? ?? false,
      // Notification fields
      fcmToken: json['fcmToken'] as String?,
      fcmTokenUpdatedAt: UserProfile._deserializeDateTime(json['fcmTokenUpdatedAt']),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  static DateTime? _deserializeDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  String toString() {
    return 'UserProfile(uid: $uid, displayName: $displayName, friends: $friendsCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
