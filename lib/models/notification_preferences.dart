// lib/models/notification_preferences.dart

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// How often the activity digest may be sent. Wire value is [name], so
/// Firestore keeps the exact strings `'never'` and `'weekly'` it already holds.
///
/// A THIRD value, `'daily'`, was selectable in the settings dropdown between
/// `920256e9e` and `77ba0bd30` (2026-03-27, fourteen minutes) and was removed
/// without migrating whatever had been stored. `DropdownButton` requires its
/// value to match exactly one item, so a document holding `'daily'` — or any
/// other unrecognised string — would crash the notification settings screen in
/// debug and render a blank control in release. Whether any such document
/// exists is beside the point: the parse has to be TOTAL, and that is what
/// [fromWire] is for. (For the record, the window was short and the app is not
/// live — the same reasoning that closed a backfill unbuilt in
/// `.claude/rules/accepted-deviations.md` — so in practice this is test data.)
///
/// [fromWire] is nevertheless a permanent line, not a migration TODO: an
/// unrecognised value is never rewritten by a read (BUT-1782 forbids the read
/// path writing to FIRESTORE — it does refresh the local mirror), so a
/// Firestore document only changes when its owner next saves this screen.
enum DigestFrequency {
  never,
  weekly
  ;

  /// Total parse: every possible stored string maps to a value.
  ///
  /// The rule is `'never'` off, anything else weekly — deliberately the
  /// BACKEND'S OWN RULE, mirrored. `send-activity-digest.ts` asks
  /// `digestFrequency === "never"` and otherwise sends the weekly digest, so a
  /// client that disagreed for any value would re-create the class of defect
  /// this fixes. It also degrades in the safe direction: an unknown future
  /// value reads as "still subscribed", never as a silent unsubscribe.
  ///
  /// `'daily'` therefore becomes [weekly] rather than being shown as a retired
  /// option. BUT-1618 (`personal_tag_rule_dialog.dart`) does the opposite for a
  /// retired tag property, and rightly: there the system cannot name an
  /// equivalent, so only the user can decide. Here it can — both consumers
  /// treat `'daily'` and `'weekly'` identically, so a "Dagligen" option would
  /// promise a cadence that does not exist.
  ///
  /// Do NOT tighten the backend to `=== "weekly"` (BUT-1844). Every value it
  /// does not recognise would then stop meaning "send", which is a silent
  /// unsubscribe — the same failure as the bug above, pointing the other way.
  ///
  /// `null` is ABSENCE, not junk: it means no preference was ever stored, so it
  /// reads as [never]. Junk reads as [weekly] per the rule above.
  static DigestFrequency fromWire(String? wire) =>
      (wire == null || wire == never.name) ? never : weekly;
}

/// User notification preferences model
///
/// BUT-1783 removed `soundEnabled` and `vibrationEnabled`. Do not reintroduce
/// either without a consumer that can act on it: sound and vibration are owned
/// by the Android notification channel and by iOS system settings, so a stored
/// preference cannot take effect on its own, and the two switches spent their
/// whole life persisting a value nothing read.
///
/// The removal is forward-only and stays that way. Every document written
/// before it keeps both keys PERMANENTLY — the repository saves with
/// `SetOptions(merge: true)`, which never deletes a key it stops sending — so
/// the legacy keys are a fixture in the tests, not a cleanup candidate.
/// [fromMap] reads named keys only and ignores them. Verified 2026-08-13:
/// `match /user_notification_preferences/{userId}` in `firestore.rules` gates
/// this collection on ownership alone, with no `hasOnly` field allowlist, so
/// dropping the keys from [toFirestore] cannot be denied. Re-read that block
/// before ADDING a field anyway: an allowlist could be introduced later, and
/// the ADD direction is the one that fails closed and in silence (BUT-1482).
class NotificationPreferences {
  final bool enabled; // Master notification toggle
  final Map<NotificationCategory, bool> categorySettings;
  final Map<NotificationType, bool> typeSettings;
  final bool allowBatching; // Allow grouping similar notifications
  final DigestFrequency digestFrequency;
  final TimeOfDay? quietHoursStart; // Don't send during quiet hours
  final TimeOfDay? quietHoursEnd;
  final DateTime lastUpdated;

  const NotificationPreferences({
    required this.enabled,
    required this.categorySettings,
    required this.typeSettings,
    required this.allowBatching,
    required this.digestFrequency,
    this.quietHoursStart,
    this.quietHoursEnd,
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
      digestFrequency: DigestFrequency.never,
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: const TimeOfDay(hour: 8, minute: 0), // 8 AM
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
      // safeNullableString, not safeString with a default: the default belongs
      // to fromWire alone, or two layers own the same rule and can disagree.
      digestFrequency: DigestFrequency.fromWire(
        SerializationUtils.safeNullableString(data, 'digestFrequency'),
      ),
      quietHoursStart: _parseTimeOfDay(
        SerializationUtils.safeNullableMap(data, 'quietHoursStart'),
      ),
      quietHoursEnd: _parseTimeOfDay(
        SerializationUtils.safeNullableMap(data, 'quietHoursEnd'),
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
      'digestFrequency': digestFrequency.name,
      'quietHoursStart': _timeOfDayToMap(quietHoursStart),
      'quietHoursEnd': _timeOfDayToMap(quietHoursEnd),
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
