// lib/models/notification_preferences.dart

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// User notification preferences model
class NotificationPreferences {
  final bool enabled; // Master notification toggle
  final Map<NotificationCategory, bool> categorySettings;
  final Map<NotificationType, bool> typeSettings;
  final bool allowBatching; // Allow grouping similar notifications
  final String digestFrequency; // 'daily', 'weekly', 'never'
  final TimeOfDay? quietHoursStart; // Don't send during quiet hours
  final TimeOfDay? quietHoursEnd;
  final bool soundEnabled; // Notification sounds
  final bool vibrationEnabled; // Notification vibration
  final DateTime lastUpdated;

  const NotificationPreferences({
    required this.enabled,
    required this.categorySettings,
    required this.typeSettings,
    required this.allowBatching,
    required this.digestFrequency,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.lastUpdated,
  });

  /// Create default preferences for new users
  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      enabled: true,
      categorySettings: {
        NotificationCategory.friends: true, // Friend requests are important
        NotificationCategory.recipes: true, // Recipe sharing is core feature
        NotificationCategory.collaboration: true, // Real-time collaboration
        NotificationCategory.shopping: false, // Shopping updates can be noisy
        NotificationCategory.messaging: true, // DM notifications are important
        NotificationCategory.social: false, // Activity feeds are optional
        NotificationCategory.system: true, // System notifications needed
      },
      typeSettings: {
        NotificationType.immediate: true, // Critical notifications
        NotificationType.batchable: true, // Allow grouping
        NotificationType.silent: true, // Background sync
        NotificationType.digest: false, // Daily summaries off by default
        NotificationType.optional: false, // Optional features off
      },
      allowBatching: true,
      digestFrequency: 'never',
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: const TimeOfDay(hour: 8, minute: 0), // 8 AM
      soundEnabled: true,
      vibrationEnabled: true,
      lastUpdated: clock.now(),
    );
  }

  /// Check if user should receive notification for category and type
  bool isEnabled(NotificationCategory category, NotificationType type) {
    if (!enabled) return false;

    final categoryEnabled = (categorySettings[category]).orFalse();
    final typeEnabled = (typeSettings[type]).orFalse();

    return categoryEnabled && typeEnabled;
  }

  /// Create from repository data (removes Firebase dependency)
  factory NotificationPreferences.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationPreferences(
      enabled: SerializationUtils.safeBool(data, 'enabled', defaultValue: true),
      categorySettings: _parseEnumMap(
        SerializationUtils.safeMap(data, 'categorySettings'),
        NotificationCategory.values,
      ),
      typeSettings: _parseEnumMap(
        SerializationUtils.safeMap(data, 'typeSettings'),
        NotificationType.values,
      ),
      allowBatching: SerializationUtils.safeBool(
        data,
        'allowBatching',
        defaultValue: true,
      ),
      digestFrequency: SerializationUtils.safeString(
        data,
        'digestFrequency',
        defaultValue: 'never',
      ),
      quietHoursStart: _parseTimeOfDay(
        SerializationUtils.safeNullableMap(data, 'quietHoursStart'),
      ),
      quietHoursEnd: _parseTimeOfDay(
        SerializationUtils.safeNullableMap(data, 'quietHoursEnd'),
      ),
      soundEnabled: SerializationUtils.safeBool(
        data,
        'soundEnabled',
        defaultValue: true,
      ),
      vibrationEnabled: SerializationUtils.safeBool(
        data,
        'vibrationEnabled',
        defaultValue: true,
      ),
      lastUpdated: data['lastUpdated'] is DateTime
          ? data['lastUpdated'] as DateTime
          : (data['lastUpdated'] != null
                ? AppTimestamp.fromFirestore(data['lastUpdated']).dateTime
                : clock.now()),
    );
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    return NotificationPreferences.fromMap(
      doc.id,
      ((doc.data() as Map<String, dynamic>?).orEmpty()),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'enabled': enabled,
      'categorySettings': _enumMapToStrings(categorySettings),
      'typeSettings': _enumMapToStrings(typeSettings),
      'allowBatching': allowBatching,
      'digestFrequency': digestFrequency,
      'quietHoursStart': _timeOfDayToMap(quietHoursStart),
      'quietHoursEnd': _timeOfDayToMap(quietHoursEnd),
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to JSON string for local storage
  ///
  /// Deliberately reuses the [toFirestore] field names so the offline copy is
  /// readable by [fromMap] and cannot drift from the remote shape. Only
  /// `lastUpdated` needs adapting: [toFirestore] writes a server-side sentinel
  /// that has no local value, so the object's own timestamp is written as a
  /// UTC ISO-8601 string instead.
  String toJson() {
    final data = Map<String, dynamic>.from(toFirestore());
    data['lastUpdated'] = lastUpdated.toUtc().toIso8601String();
    return jsonEncode(data);
  }

  /// Parse a cached copy, returning `null` when the payload is unusable.
  ///
  /// BUT-1799. [NotificationPreferences.fromJson] answers an unusable shape
  /// with [defaults], which a CACHE caller cannot tell apart from "the user
  /// really is on defaults" — so it caches the defaults, and the next toggle
  /// persists them to Firestore, silently resetting the user's real settings.
  /// The old `toJson()` stub wrote the literal `'{}'`, so that exact payload is
  /// sitting in every existing user's SharedPreferences right now.
  ///
  /// [fromJson]'s own contract is deliberate and pinned by its tests; this is
  /// the nullable door for callers that must tell the two cases apart.
  static NotificationPreferences? tryFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      if (!SerializationUtils.hasRequiredFields(data, const [
            'categorySettings',
            'typeSettings',
          ]) ||
          data['categorySettings'] is! Map ||
          data['typeSettings'] is! Map) {
        return null;
      }
      return NotificationPreferences.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// Create from JSON string.
  ///
  /// Throws [FormatException] on a string that is not a JSON object. A legacy
  /// `'{}'` written by the pre-BUT-1782 stub carries no settings at all, so it
  /// maps to [defaults] rather than to an all-categories-off object. That
  /// contract is deliberate and pinned by this class's tests — a caller that
  /// must tell "unusable payload" from "the user really is on defaults" wants
  /// [tryFromJson] instead.
  ///
  /// The shape check is on the VALUES, not merely on key presence: the two
  /// settings maps are parsed with `safeBool`, which reads a missing key as
  /// `false`, so `{"categorySettings": "corrupt"}` would clear key presence and
  /// then silently produce an object with every notification switched off —
  /// indistinguishable from a deliberate opt-out, and about to be written back
  /// as one.
  factory NotificationPreferences.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw FormatException('Expected a JSON object', json);
    }

    final data = Map<String, dynamic>.from(decoded);
    if (!SerializationUtils.hasRequiredFields(data, const [
          'categorySettings',
          'typeSettings',
        ]) ||
        data['categorySettings'] is! Map ||
        data['typeSettings'] is! Map) {
      return NotificationPreferences.defaults();
    }

    // fromMap accepts a DateTime or a Firestore Timestamp; the local copy
    // carries ISO-8601, so parse it here rather than widening fromMap.
    data['lastUpdated'] = DateTime.tryParse(
      SerializationUtils.safeString(data, 'lastUpdated'),
    );

    return NotificationPreferences.fromMap('local', data);
  }

  /// Helper: Parse enum map from Firestore
  static Map<T, bool> _parseEnumMap<T extends Enum>(
    Map<String, dynamic> data,
    List<T> enumValues,
  ) {
    final result = <T, bool>{};
    for (final enumValue in enumValues) {
      result[enumValue] = SerializationUtils.safeBool(
        data,
        enumValue.toString(),
      );
    }
    return result;
  }

  /// Helper: Convert enum map to strings for Firestore
  static Map<String, bool> _enumMapToStrings<T extends Enum>(
    Map<T, bool> enumMap,
  ) {
    return enumMap.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Helper: Parse TimeOfDay from Firestore
  static TimeOfDay? _parseTimeOfDay(Map<String, dynamic>? data) {
    if (data == null) return null;
    return TimeOfDay(
      hour: SerializationUtils.safeInt(data, 'hour'),
      minute: SerializationUtils.safeInt(data, 'minute'),
    );
  }

  /// Helper: Convert TimeOfDay to map for Firestore
  static Map<String, int>? _timeOfDayToMap(TimeOfDay? time) {
    if (time == null) return null;
    return {'hour': time.hour, 'minute': time.minute};
  }
}
