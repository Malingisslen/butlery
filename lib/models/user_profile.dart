// lib/models/user_profile.dart

import 'package:cloud_firestore/cloud_firestore.dart';


class UserProfile {
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
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isOnline': isOnline,
    };
  }

  /// Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      bio: data['bio'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      isSearchable: data['isSearchable'] as bool? ?? true,
      allowEmailSearch: data['allowEmailSearch'] as bool? ?? false,
      publicRecipeCount: data['publicRecipeCount'] as int? ?? 0,
      friendsCount: data['friendsCount'] as int? ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt:
          (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }

  /// JSON serialization för caching
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
      'joinedAt': joinedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isOnline': isOnline,
    };
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
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
    );
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
