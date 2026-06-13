/// Weekly menu plan model — calendar view of `MenuGenerator` output.
library;

import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

/// Meal slot for weekly planning. Frukost is intentionally absent — breakfast
/// recipes go in [ovrigt] alongside desserts, baking, mellanmål, fika, snacks.
enum MealSlot {
  lunch,
  middag,
  ovrigt;

  /// Whether multiple recipes per day are allowed in this slot.
  /// Lunch and middag are single-recipe; övrigt is the catch-all bucket.
  bool get isMulti => this == MealSlot.ovrigt;

  /// Swedish display label (lowercase, matches the design system).
  String get displayLabel {
    switch (this) {
      case MealSlot.lunch:
        return 'lunch';
      case MealSlot.middag:
        return 'middag';
      case MealSlot.ovrigt:
        return 'övrigt';
    }
  }

  static MealSlot fromName(String name) =>
      SerializationUtils.safeEnumByName(MealSlot.values, name, MealSlot.middag);
}

/// Day of the week. ISO order — Monday is index 0.
enum DayOfWeek {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  /// Maps to `DateTime.weekday` (1=Mon..7=Sun).
  int get isoWeekday => index + 1;

  /// Swedish 3-letter label.
  String get displayLabel {
    switch (this) {
      case DayOfWeek.mon:
        return 'mån';
      case DayOfWeek.tue:
        return 'tis';
      case DayOfWeek.wed:
        return 'ons';
      case DayOfWeek.thu:
        return 'tor';
      case DayOfWeek.fri:
        return 'fre';
      case DayOfWeek.sat:
        return 'lör';
      case DayOfWeek.sun:
        return 'sön';
    }
  }

  static DayOfWeek fromDateTime(DateTime date) =>
      DayOfWeek.values[date.weekday - 1];

  static DayOfWeek fromName(String name) =>
      SerializationUtils.safeEnumByName(DayOfWeek.values, name, DayOfWeek.mon);
}

/// A single placement target inside one week: (day, slot). Lives next to the
/// enums it combines so service- and widget-layer consumers share one type
/// without a services-layer import (BUT-999).
typedef SlotTarget = ({DayOfWeek day, MealSlot slot});

/// A single placement of a recipe into a day + slot of the weekly plan.
///
/// Cached `recipeTitle` and `recipeImageUrl` keep the calendar renderable
/// offline and gracefully handle deleted recipes (entry stays as a tombstone
/// instead of crashing the view).
class WeeklyMenuPlanEntry {
  final String id;
  final DayOfWeek day;
  final MealSlot slot;
  final String recipeId;
  final String recipeTitle;
  final String? recipeImageUrl;

  const WeeklyMenuPlanEntry({
    required this.id,
    required this.day,
    required this.slot,
    required this.recipeId,
    required this.recipeTitle,
    this.recipeImageUrl,
  });

  factory WeeklyMenuPlanEntry.create({
    required DayOfWeek day,
    required MealSlot slot,
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
  }) {
    return WeeklyMenuPlanEntry(
      id: const Uuid().v4(),
      day: day,
      slot: slot,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day': day.name,
      'slot': slot.name,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      if (recipeImageUrl != null) 'recipeImageUrl': recipeImageUrl,
    };
  }

  factory WeeklyMenuPlanEntry.fromMap(Map<String, dynamic> data) {
    return WeeklyMenuPlanEntry(
      id: SerializationUtils.safeString(data, 'id',
          defaultValue: const Uuid().v4()),
      day: DayOfWeek.fromName(SerializationUtils.safeString(data, 'day')),
      slot: MealSlot.fromName(SerializationUtils.safeString(data, 'slot')),
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      recipeTitle: SerializationUtils.safeString(data, 'recipeTitle'),
      recipeImageUrl:
          SerializationUtils.safeNullableString(data, 'recipeImageUrl'),
    );
  }

  WeeklyMenuPlanEntry copyWith({
    DayOfWeek? day,
    MealSlot? slot,
  }) {
    return WeeklyMenuPlanEntry(
      id: id,
      day: day ?? this.day,
      slot: slot ?? this.slot,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeeklyMenuPlanEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A user's planned meals for one ISO week, persisted as a single Firestore
/// document keyed by `{userId}_{YYYY}-W{WW}`.
class WeeklyMenuPlan {
  final String id;
  final String userId;
  final DateTime weekStartDate;
  final List<WeeklyMenuPlanEntry> entries;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// BUT-648: Schema version for lazy migration on read.
  /// Default 1 — old docs without this field are treated as v1.
  final int schemaVersion;

  const WeeklyMenuPlan({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Creates an empty plan for the ISO week containing [date].
  factory WeeklyMenuPlan.empty({
    required String userId,
    required DateTime date,
  }) {
    final weekStart = IsoWeekUtils.weekStartOf(date);
    final now = clock.now();
    return WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor(userId, weekStart),
      userId: userId,
      weekStartDate: weekStart,
      entries: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// First entry at [day]/[slot], or null. Use for lunch/middag (single-recipe slots).
  WeeklyMenuPlanEntry? entryAt(DayOfWeek day, MealSlot slot) {
    for (final entry in entries) {
      if (entry.day == day && entry.slot == slot) return entry;
    }
    return null;
  }

  /// All entries at [day]/[slot], in insertion order. Use for övrigt (multi-recipe slot).
  List<WeeklyMenuPlanEntry> entriesAt(DayOfWeek day, MealSlot slot) {
    return entries.where((e) => e.day == day && e.slot == slot).toList();
  }

  /// Whether [day]/[slot] is occupied. For multi slots, "occupied" means
  /// at least one entry exists; the distribution algorithm handles multi
  /// vs single semantics separately.
  bool isOccupied(DayOfWeek day, MealSlot slot) {
    return entryAt(day, slot) != null;
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  WeeklyMenuPlan copyWith({
    List<WeeklyMenuPlanEntry>? entries,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return WeeklyMenuPlan(
      id: id,
      userId: userId,
      weekStartDate: weekStartDate,
      entries: entries ?? this.entries,
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'weekStartDate': AppTimestamp.fromDateTime(weekStartDate).toFirestore(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'updatedAt': AppTimestamp.fromDateTime(updatedAt).toFirestore(),
      'schemaVersion': schemaVersion,
    };
  }

  factory WeeklyMenuPlan.fromMap(String id, Map<String, dynamic> data) {
    final userId = SerializationUtils.safeString(data, 'userId');
    final weekStart = SerializationUtils.safeRequiredDateTime(
      data,
      'weekStartDate',
      defaultValue: clock.now(),
    );
    return WeeklyMenuPlan(
      id: id,
      userId: userId,
      weekStartDate: weekStart,
      entries: SerializationUtils.safeObjectList<WeeklyMenuPlanEntry>(
        data,
        'entries',
        WeeklyMenuPlanEntry.fromMap,
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      updatedAt: SerializationUtils.safeRequiredDateTime(data, 'updatedAt'),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }
}
