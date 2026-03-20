/// User profile with social networking and notification capabilities.
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// User profile with social features, privacy settings, and notifications.
class UserProfile with JsonSerializableMixin {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool isSearchable;
  final bool allowEmailSearch;
  final int publicRecipeCount;
  final int friendsCount;
  final DateTime joinedAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;
  final bool notificationsEnabled;
  final String? preferredLocale;
  final UserAllergenPreferences? allergenPreferences;
  final bool hasCompletedOnboarding;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.isSearchable = true,
    this.allowEmailSearch = false,
    this.publicRecipeCount = 0,
    this.friendsCount = 0,
    required this.joinedAt,
    required this.lastActiveAt,
    this.isOnline = false,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.notificationsEnabled = true,
    this.preferredLocale,
    this.allergenPreferences,
    this.hasCompletedOnboarding = false,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
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
    // Locale preference
    String? preferredLocale,
    // Allergen preferences
    UserAllergenPreferences? allergenPreferences,
    bool? hasCompletedOnboarding,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
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
      // Locale preference
      preferredLocale: preferredLocale ?? this.preferredLocale,
      // Allergen preferences
      allergenPreferences: allergenPreferences ?? this.allergenPreferences,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
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
      return AppLocale.current.userStatusOnline;
    } else if (difference.inMinutes < 1) {
      return AppLocale.current.userStatusJustActive;
    } else if (difference.inHours < 1) {
      return AppLocale.current.userStatusActiveMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return AppLocale.current.userStatusActiveHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return AppLocale.current.userStatusActiveDaysAgo(difference.inDays);
    } else {
      return AppLocale.current
          .userStatusActiveWeeksAgo((difference.inDays / 7).floor());
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
    final l = AppLocale.current;
    if (difference.inDays < 30) {
      return l.memberSinceDays(difference.inDays);
    } else if (difference.inDays < 365) {
      return l.memberSinceMonths((difference.inDays / 30).floor());
    } else {
      return l.memberSinceYears((difference.inDays / 365).floor());
    }
  }

  /// Convert to Firestore format (public fields only — written to public_profiles)
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'isSearchable': isSearchable,
      'allowEmailSearch': allowEmailSearch,
      'publicRecipeCount': publicRecipeCount,
      'friendsCount': friendsCount,
      'joinedAt': AppTimestamp.fromDateTime(joinedAt).toFirestore(),
      'lastActiveAt': AppTimestamp.fromDateTime(lastActiveAt).toFirestore(),
      'isOnline': isOnline,
    };
  }

  /// Sensitive fields stored in users/{uid}/settings/preferences subcollection
  Map<String, dynamic> toPrivateSettings() {
    return {
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null
          ? AppTimestamp.fromDateTime(fcmTokenUpdatedAt!).toFirestore()
          : null,
      'notificationsEnabled': notificationsEnabled,
      'preferredLocale': preferredLocale,
      'allergenPreferences': allergenPreferences?.toFirestore(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
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
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null
          ? serializeDateTime(fcmTokenUpdatedAt!)
          : null,
      'notificationsEnabled': notificationsEnabled,
      // Locale preference
      'preferredLocale': preferredLocale,
      // Allergen preferences
      'allergenPreferences': allergenPreferences?.toFirestore(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  /// Create from repository data (removes Firebase dependency from model)
  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      displayName: utils.SerializationUtils.safeString(data, 'displayName'),
      email: utils.SerializationUtils.safeString(data, 'email'),
      avatarUrl: utils.SerializationUtils.safeNullableString(data, 'avatarUrl'),
      isSearchable: utils.SerializationUtils.safeBool(data, 'isSearchable',
          defaultValue: true),
      allowEmailSearch:
          utils.SerializationUtils.safeBool(data, 'allowEmailSearch'),
      publicRecipeCount:
          utils.SerializationUtils.safeInt(data, 'publicRecipeCount'),
      friendsCount: utils.SerializationUtils.safeInt(data, 'friendsCount'),
      joinedAt: utils.SerializationUtils.safeDateTime(data, 'joinedAt').orNow(),
      lastActiveAt:
          utils.SerializationUtils.safeDateTime(data, 'lastActiveAt').orNow(),
      isOnline: utils.SerializationUtils.safeBool(data, 'isOnline'),
      // Notification fields
      fcmToken: utils.SerializationUtils.safeNullableString(data, 'fcmToken'),
      fcmTokenUpdatedAt:
          utils.SerializationUtils.safeDateTime(data, 'fcmTokenUpdatedAt'),
      notificationsEnabled: utils.SerializationUtils.safeBool(
          data, 'notificationsEnabled',
          defaultValue: true),
      // Locale preference
      preferredLocale:
          utils.SerializationUtils.safeNullableString(data, 'preferredLocale'),
      // Allergen preferences
      allergenPreferences: data['allergenPreferences'] != null
          ? UserAllergenPreferences.fromFirestore(
              data['allergenPreferences'] as Map<String, dynamic>)
          : null,
      hasCompletedOnboarding:
          utils.SerializationUtils.safeBool(data, 'hasCompletedOnboarding'),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      displayName: (json['displayName'] as String?).orEmpty(),
      email: (json['email'] as String?).orEmpty(),
      avatarUrl: json['avatarUrl'] as String?,
      isSearchable: (json['isSearchable'] as bool?).orTrue(),
      allowEmailSearch: (json['allowEmailSearch'] as bool?).orFalse(),
      publicRecipeCount: (json['publicRecipeCount'] as int?).orZero(),
      friendsCount: (json['friendsCount'] as int?).orZero(),
      joinedAt:
          utils.SerializationUtils.parseDateTimeValue(json['joinedAt']).orNow(),
      lastActiveAt:
          utils.SerializationUtils.parseDateTimeValue(json['lastActiveAt'])
              .orNow(),
      isOnline: (json['isOnline'] as bool?).orFalse(),
      // Notification fields
      fcmToken: json['fcmToken'] as String?,
      fcmTokenUpdatedAt: utils.SerializationUtils.parseDateTimeValue(
          json['fcmTokenUpdatedAt']),
      notificationsEnabled: (json['notificationsEnabled'] as bool?).orTrue(),
      // Locale preference
      preferredLocale: json['preferredLocale'] as String?,
      // Allergen preferences
      allergenPreferences: json['allergenPreferences'] != null
          ? UserAllergenPreferences.fromFirestore(
              json['allergenPreferences'] as Map<String, dynamic>)
          : null,
      hasCompletedOnboarding:
          (json['hasCompletedOnboarding'] as bool?).orFalse(),
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
