/// User profile with social networking and notification capabilities.

import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// Cooking skill level for user profile.
enum CookingSkillLevel {
  beginner,
  intermediate,
  advanced;

  /// Parse from string, returning null for unknown values.
  static CookingSkillLevel? tryParse(String? value) {
    if (value == null) return null;
    return CookingSkillLevel.values.cast<CookingSkillLevel?>().firstWhere(
          (e) => e!.name == value,
          orElse: () => null,
        );
  }
}

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

  /// BUT-912: when false the user opts out of online-status visibility — the
  /// presence write is forced offline so no one sees their dot or last-active.
  /// Defaults true (existing behaviour) for accounts created before this field.
  final bool showOnlineStatus;

  /// BUT-906: master toggle for broadcasting activity to friends' feeds. When
  /// false the user opts out and their cook/share/ping events are not emitted.
  /// Defaults true (existing behaviour) for accounts created before this field.
  final bool shareActivityToFeed;

  /// BUT-1220: per-event-type opt-outs that sit UNDER the master toggle. Keyed
  /// by [ActivityEventType.name]. A type that is absent from the map counts as
  /// ENABLED — so an empty/missing map means "all types on" and matches the
  /// behaviour of accounts created before this field. Only an explicit `false`
  /// suppresses that one event type; the master toggle still gates everything.
  final Map<String, bool> activityFeedEventTypes;

  /// BUT-1220: whether the one-time "your activity is now visible to friends"
  /// hint has already been shown. Flipped true after the first event is
  /// broadcast so the nudge fires exactly once. Defaults false.
  final bool hasSeenActivityFeedHint;

  /// BUT-1050: when true, checking off a bought shopping item auto-adds it to
  /// the pantry. Defaults false (opt-in) — existing accounts keep manual pantry
  /// management until they turn it on.
  final bool autoAddBoughtToPantry;

  /// BUT-1050: whether the one-time "add bought items to your pantry?" prompt
  /// has been shown on the first shopping-checkoff. Flipped true after it fires
  /// once so it never re-nags. Defaults false.
  final bool pantryAutoAddPrompted;
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;
  final bool notificationsEnabled;
  final String? preferredLocale;
  final UserAllergenPreferences? allergenPreferences;
  final bool hasCompletedOnboarding;
  final DateTime? onboardingSkippedAt;
  final CookingSkillLevel? cookingSkillLevel;
  final List<String>? cuisineAffinities;
  final String? bio;

  // Year-only birth year for the GDPR Art 8 age gate. Nullable so pre-gate
  // users keep working; rules + onboarding require it for new sign-ups. The
  // 15-year Swedish threshold is enforced at sign-up, not here — model only
  // enforces a hard floor of 13 so admins can backfill edge cases.
  final int? birthYear;

  // Moderation hide flag. Admin-only writeable (rules-enforced). When true,
  // the profile is excluded from search and rendered as a placeholder in
  // friend/group/comment surfaces. Existing data is preserved so a
  // moderator can reverse the decision; reversal sets `isHidden = false`
  // and clears `hiddenAt`.
  final bool isHidden;
  final DateTime? hiddenAt;

  /// BUT-648: Schema version for lazy migration on read.
  /// Default 1 — old docs without this field are treated as v1.
  final int schemaVersion;

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
    this.showOnlineStatus = true,
    this.shareActivityToFeed = true,
    this.activityFeedEventTypes = const {},
    this.hasSeenActivityFeedHint = false,
    this.autoAddBoughtToPantry = false,
    this.pantryAutoAddPrompted = false,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.notificationsEnabled = true,
    this.preferredLocale,
    this.allergenPreferences,
    this.hasCompletedOnboarding = false,
    this.onboardingSkippedAt,
    this.cookingSkillLevel,
    this.cuisineAffinities,
    this.bio,
    this.birthYear,
    this.isHidden = false,
    this.hiddenAt,
    this.schemaVersion = 1,
  }) {
    if (birthYear != null) {
      final currentYear = clock.now().year;
      if (birthYear! < 1900 || birthYear! > currentYear - 13) {
        throw ArgumentError(
          'birthYear must be between 1900 and ${currentYear - 13} (got $birthYear)',
        );
      }
    }
  }

  /// BUT-1220: whether a given event type is allowed to broadcast. Absent key
  /// = enabled (opt-out semantics). The master [shareActivityToFeed] toggle is
  /// checked separately by the caller and overrides this.
  bool isActivityEventTypeEnabled(String typeName) =>
      activityFeedEventTypes[typeName] ?? true;

  static const _sentinel = Object();

  UserProfile copyWith({
    String? displayName,
    String? email,
    Object? avatarUrl = _sentinel,
    bool? isSearchable,
    bool? allowEmailSearch,
    int? publicRecipeCount,
    int? friendsCount,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    bool? showOnlineStatus,
    bool? shareActivityToFeed,
    Map<String, bool>? activityFeedEventTypes,
    bool? hasSeenActivityFeedHint,
    bool? autoAddBoughtToPantry,
    bool? pantryAutoAddPrompted,
    Object? fcmToken = _sentinel,
    Object? fcmTokenUpdatedAt = _sentinel,
    bool? notificationsEnabled,
    Object? preferredLocale = _sentinel,
    Object? allergenPreferences = _sentinel,
    bool? hasCompletedOnboarding,
    Object? onboardingSkippedAt = _sentinel,
    Object? cookingSkillLevel = _sentinel,
    Object? cuisineAffinities = _sentinel,
    Object? bio = _sentinel,
    Object? birthYear = _sentinel,
    bool? isHidden,
    Object? hiddenAt = _sentinel,
    int? schemaVersion,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl == _sentinel ? this.avatarUrl : avatarUrl as String?,
      isSearchable: isSearchable ?? this.isSearchable,
      allowEmailSearch: allowEmailSearch ?? this.allowEmailSearch,
      publicRecipeCount: publicRecipeCount ?? this.publicRecipeCount,
      friendsCount: friendsCount ?? this.friendsCount,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      shareActivityToFeed: shareActivityToFeed ?? this.shareActivityToFeed,
      activityFeedEventTypes:
          activityFeedEventTypes ?? this.activityFeedEventTypes,
      hasSeenActivityFeedHint:
          hasSeenActivityFeedHint ?? this.hasSeenActivityFeedHint,
      autoAddBoughtToPantry:
          autoAddBoughtToPantry ?? this.autoAddBoughtToPantry,
      pantryAutoAddPrompted:
          pantryAutoAddPrompted ?? this.pantryAutoAddPrompted,
      fcmToken: fcmToken == _sentinel ? this.fcmToken : fcmToken as String?,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt == _sentinel
          ? this.fcmTokenUpdatedAt
          : fcmTokenUpdatedAt as DateTime?,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      preferredLocale: preferredLocale == _sentinel
          ? this.preferredLocale
          : preferredLocale as String?,
      allergenPreferences: allergenPreferences == _sentinel
          ? this.allergenPreferences
          : allergenPreferences as UserAllergenPreferences?,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingSkippedAt: onboardingSkippedAt == _sentinel
          ? this.onboardingSkippedAt
          : onboardingSkippedAt as DateTime?,
      cookingSkillLevel: cookingSkillLevel == _sentinel
          ? this.cookingSkillLevel
          : cookingSkillLevel as CookingSkillLevel?,
      cuisineAffinities: cuisineAffinities == _sentinel
          ? this.cuisineAffinities
          : cuisineAffinities as List<String>?,
      bio: bio == _sentinel ? this.bio : bio as String?,
      birthYear: birthYear == _sentinel ? this.birthYear : birthYear as int?,
      isHidden: isHidden ?? this.isHidden,
      hiddenAt: hiddenAt == _sentinel ? this.hiddenAt : hiddenAt as DateTime?,
      schemaVersion: schemaVersion ?? this.schemaVersion,
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
    // BUT-912: a user who opted out of online-status visibility must not leak a
    // "last active" signal either — return empty so no presence text renders.
    if (!showOnlineStatus) return '';

    final now = clock.now();
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

    final now = clock.now();
    final tokenAge = now.difference(fcmTokenUpdatedAt!);
    return tokenAge.inDays < 30; // FCM tokens should be refreshed regularly
  }

  /// Check if user can receive push notifications
  bool get canReceiveNotifications {
    return notificationsEnabled && fcmToken != null && fcmToken!.isNotEmpty;
  }

  /// Time since joined
  String get memberSinceText {
    final now = clock.now();
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
      'showOnlineStatus': showOnlineStatus,
      'shareActivityToFeed': shareActivityToFeed,
      'activityFeedEventTypes': activityFeedEventTypes,
      'cookingSkillLevel': cookingSkillLevel?.name,
      'cuisineAffinities': cuisineAffinities,
      'isHidden': isHidden,
      'hiddenAt': hiddenAt != null
          ? AppTimestamp.fromDateTime(hiddenAt!).toFirestore()
          : null,
      'schemaVersion': schemaVersion,
    };
  }

  /// Owner-editable subset of the public profile, for a `merge:true` write.
  ///
  /// BUT-1285: this is the merge-write acceptance surface — it deliberately
  /// EXCLUDES three server-owned fields that a stale in-memory profile would
  /// otherwise clobber on a full `set()`:
  /// - `friendsCount` — maintained by OTHER users' friend-creation transactions
  ///   (firestore.rules lets any authed user change only this field). A stale
  ///   value in a full overwrite silently reverts a concurrent friend's change.
  /// - `isHidden` / `hiddenAt` — moderator-only. A stale `isHidden:false` trips
  ///   the rules' diff() guard and rejects the ENTIRE save, so a hidden user
  ///   could never edit their display name, avatar, or searchability.
  ///
  /// Omitting these keys means `merge:true` leaves the server values untouched
  /// and they never appear in the update's affectedKeys().
  Map<String, dynamic> toFirestoreEditable() {
    final data = toFirestore();
    data.remove('friendsCount');
    data.remove('isHidden');
    data.remove('hiddenAt');
    return data;
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
      'onboardingSkippedAt': onboardingSkippedAt != null
          ? AppTimestamp.fromDateTime(onboardingSkippedAt!).toFirestore()
          : null,
      'bio': bio,
      'birthYear': birthYear,
      'hasSeenActivityFeedHint': hasSeenActivityFeedHint,
      'autoAddBoughtToPantry': autoAddBoughtToPantry,
      'pantryAutoAddPrompted': pantryAutoAddPrompted,
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
      'showOnlineStatus': showOnlineStatus,
      'shareActivityToFeed': shareActivityToFeed,
      'activityFeedEventTypes': activityFeedEventTypes,
      'hasSeenActivityFeedHint': hasSeenActivityFeedHint,
      'autoAddBoughtToPantry': autoAddBoughtToPantry,
      'pantryAutoAddPrompted': pantryAutoAddPrompted,
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
      'onboardingSkippedAt': onboardingSkippedAt != null
          ? serializeDateTime(onboardingSkippedAt!)
          : null,
      'cookingSkillLevel': cookingSkillLevel?.name,
      'cuisineAffinities': cuisineAffinities,
      'bio': bio,
      'birthYear': birthYear,
      'isHidden': isHidden,
      'hiddenAt': hiddenAt != null ? serializeDateTime(hiddenAt!) : null,
      'schemaVersion': schemaVersion,
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
      showOnlineStatus: utils.SerializationUtils.safeBool(
          data, 'showOnlineStatus',
          defaultValue: true),
      shareActivityToFeed: utils.SerializationUtils.safeBool(
          data, 'shareActivityToFeed',
          defaultValue: true),
      activityFeedEventTypes: _readActivityFeedEventTypes(data),
      hasSeenActivityFeedHint:
          utils.SerializationUtils.safeBool(data, 'hasSeenActivityFeedHint'),
      autoAddBoughtToPantry:
          utils.SerializationUtils.safeBool(data, 'autoAddBoughtToPantry'),
      pantryAutoAddPrompted:
          utils.SerializationUtils.safeBool(data, 'pantryAutoAddPrompted'),
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
      onboardingSkippedAt:
          utils.SerializationUtils.safeDateTime(data, 'onboardingSkippedAt'),
      cookingSkillLevel: CookingSkillLevel.tryParse(
          utils.SerializationUtils.safeNullableString(
              data, 'cookingSkillLevel')),
      cuisineAffinities: data.containsKey('cuisineAffinities')
          ? utils.SerializationUtils.safeStringList(data, 'cuisineAffinities')
          : null,
      bio: utils.SerializationUtils.safeNullableString(data, 'bio'),
      birthYear: _readBirthYear(data),
      isHidden: utils.SerializationUtils.safeBool(data, 'isHidden'),
      hiddenAt: utils.SerializationUtils.safeDateTime(data, 'hiddenAt'),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: utils.SerializationUtils.safeString(json, 'uid'),
      displayName: utils.SerializationUtils.safeString(json, 'displayName'),
      email: utils.SerializationUtils.safeString(json, 'email'),
      avatarUrl: utils.SerializationUtils.safeNullableString(json, 'avatarUrl'),
      isSearchable: utils.SerializationUtils.safeBool(json, 'isSearchable',
          defaultValue: true),
      allowEmailSearch:
          utils.SerializationUtils.safeBool(json, 'allowEmailSearch'),
      publicRecipeCount:
          utils.SerializationUtils.safeInt(json, 'publicRecipeCount'),
      friendsCount: utils.SerializationUtils.safeInt(json, 'friendsCount'),
      joinedAt:
          utils.SerializationUtils.parseDateTimeValue(json['joinedAt']).orNow(),
      lastActiveAt:
          utils.SerializationUtils.parseDateTimeValue(json['lastActiveAt'])
              .orNow(),
      isOnline: utils.SerializationUtils.safeBool(json, 'isOnline'),
      showOnlineStatus: utils.SerializationUtils.safeBool(
          json, 'showOnlineStatus',
          defaultValue: true),
      shareActivityToFeed: utils.SerializationUtils.safeBool(
          json, 'shareActivityToFeed',
          defaultValue: true),
      activityFeedEventTypes: _readActivityFeedEventTypes(json),
      hasSeenActivityFeedHint:
          utils.SerializationUtils.safeBool(json, 'hasSeenActivityFeedHint'),
      autoAddBoughtToPantry:
          utils.SerializationUtils.safeBool(json, 'autoAddBoughtToPantry'),
      pantryAutoAddPrompted:
          utils.SerializationUtils.safeBool(json, 'pantryAutoAddPrompted'),
      fcmToken: utils.SerializationUtils.safeNullableString(json, 'fcmToken'),
      fcmTokenUpdatedAt: utils.SerializationUtils.parseDateTimeValue(
          json['fcmTokenUpdatedAt']),
      notificationsEnabled: utils.SerializationUtils.safeBool(
          json, 'notificationsEnabled',
          defaultValue: true),
      preferredLocale:
          utils.SerializationUtils.safeNullableString(json, 'preferredLocale'),
      // Allergen preferences
      allergenPreferences: json['allergenPreferences'] != null
          ? UserAllergenPreferences.fromFirestore(
              json['allergenPreferences'] as Map<String, dynamic>)
          : null,
      hasCompletedOnboarding:
          utils.SerializationUtils.safeBool(json, 'hasCompletedOnboarding'),
      onboardingSkippedAt: utils.SerializationUtils.parseDateTimeValue(
          json['onboardingSkippedAt']),
      cookingSkillLevel: CookingSkillLevel.tryParse(
          utils.SerializationUtils.safeNullableString(
              json, 'cookingSkillLevel')),
      cuisineAffinities: json.containsKey('cuisineAffinities')
          ? utils.SerializationUtils.safeStringList(json, 'cuisineAffinities')
          : null,
      bio: utils.SerializationUtils.safeNullableString(json, 'bio'),
      birthYear: _readBirthYear(json),
      isHidden: utils.SerializationUtils.safeBool(json, 'isHidden'),
      hiddenAt: utils.SerializationUtils.parseDateTimeValue(json['hiddenAt']),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  /// BUT-1220: read the per-event-type toggle map defensively. Coerces the raw
  /// value to `Map<String, bool>`, dropping any non-bool entries so corrupt or
  /// legacy data never throws. A missing/empty map means "all types enabled".
  static Map<String, bool> _readActivityFeedEventTypes(
      Map<String, dynamic> data) {
    final raw = data['activityFeedEventTypes'];
    if (raw is! Map) return const {};
    final result = <String, bool>{};
    raw.forEach((key, value) {
      if (value is bool) result[key.toString()] = value;
    });
    return result;
  }

  /// Read birthYear defensively: drops invalid values (out of range, wrong type)
  /// so we never throw on deserialization of legacy / corrupt data — invariant
  /// is re-enforced by the constructor for valid values.
  static int? _readBirthYear(Map<String, dynamic> data) {
    final raw = data['birthYear'];
    if (raw == null) return null;
    final parsed = raw is int ? raw : int.tryParse(raw.toString());
    if (parsed == null) return null;
    final currentYear = clock.now().year;
    if (parsed < 1900 || parsed > currentYear - 13) return null;
    return parsed;
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
