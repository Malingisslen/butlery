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
  ovrigt
  ;

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

/// BUT-1611: the meal slots "who's home" applies to. Övrigt (snacks/baking)
/// has no presence concept, so presence — and the "Hela dagen" shortcut —
/// span lunch + middag only. Canonical: the service, viewmodel, and calendar
/// UI all reference this one list so the set can never drift between them.
const List<MealSlot> kPresenceSlots = [MealSlot.lunch, MealSlot.middag];

/// Day of the week. ISO order — Monday is index 0.
enum DayOfWeek {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun
  ;

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
      id: SerializationUtils.safeString(
        data,
        'id',
        defaultValue: const Uuid().v4(),
      ),
      day: DayOfWeek.fromName(SerializationUtils.safeString(data, 'day')),
      slot: MealSlot.fromName(SerializationUtils.safeString(data, 'slot')),
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      recipeTitle: SerializationUtils.safeString(data, 'recipeTitle'),
      recipeImageUrl: SerializationUtils.safeNullableString(
        data,
        'recipeImageUrl',
      ),
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

  /// BUT-1611: who's home per (weekday, meal-slot), as roster memberIds
  /// (accounts AND diner profiles — same key space as
  /// `HouseholdRosterMember.memberId`). Presence is per meal, not per day:
  /// a diner can be home for middag but away at lunch on the same day. A slot
  /// WITHOUT an entry has no explicit selection, which downstream consumers
  /// treat as "everyone" (default whole-household filtering). An explicitly
  /// emptied slot is stored as an empty list and must NOT be read as "no
  /// filtering". Additive: docs saved before this field parse to an empty map.
  final Map<DayOfWeek, Map<MealSlot, List<String>>> presenceBySlot;

  const WeeklyMenuPlan({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.presenceBySlot = const {},
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

  /// Explicit presence selection for [day]/[slot], or null when the slot has
  /// none (= "everyone", the default). Never returns an empty list as a
  /// selection distinct from null — an explicitly-emptied slot is stored and
  /// returned as an empty list, which consumers must NOT read as "no filtering".
  List<String>? presentMemberIdsFor(DayOfWeek day, MealSlot slot) =>
      presenceBySlot[day]?[slot];

  /// BUT-1611: whether [memberId] is present for BOTH real meal slots of [day]
  /// — a slot with no explicit selection counts as "everyone present" (the
  /// default). The single owner of the "present the whole day" rule so the
  /// week-overview never drifts from the per-slot cells.
  bool isPresentWholeDay(DayOfWeek day, String memberId) {
    for (final slot in kPresenceSlots) {
      final ids = presentMemberIdsFor(day, slot);
      if (ids != null && !ids.contains(memberId)) return false;
    }
    return true;
  }

  /// BUT-1613: the effective serving count for [day]/[slot] — the number of
  /// members present when the slot has an explicit, NON-EMPTY selection,
  /// otherwise [fallback] (the recipe's own authored serving count).
  ///
  /// Both `null` (no selection = everyone/default) and `[]` (explicitly "nobody
  /// home") fall back to [fallback]: the shopping list buys the full amount
  /// rather than under-buying when presence was left unset or deliberately
  /// emptied — decided 2026-07-23. The single owner of the "how many does this
  /// meal cook for" rule, shared by the shopping-list scaler and cooking mode.
  ///
  /// Övrigt has no presence concept (`presenceBySlot` is never populated for it,
  /// `kPresenceSlots` = lunch/middag only), so this returns [fallback] there —
  /// but callers scaling quantities must skip övrigt explicitly rather than
  /// relying on that, so the whole-household exemption reads at the call site.
  int servingsFor(DayOfWeek day, MealSlot slot, {required int fallback}) {
    final ids = presentMemberIdsFor(day, slot);
    if (ids == null || ids.isEmpty) return fallback;
    return ids.length;
  }

  WeeklyMenuPlan copyWith({
    List<WeeklyMenuPlanEntry>? entries,
    DateTime? updatedAt,
    int? schemaVersion,
    Map<DayOfWeek, Map<MealSlot, List<String>>>? presenceBySlot,
  }) {
    return WeeklyMenuPlan(
      id: id,
      userId: userId,
      weekStartDate: weekStartDate,
      entries: entries ?? this.entries,
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
      presenceBySlot: presenceBySlot ?? this.presenceBySlot,
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
      if (presenceBySlot.isNotEmpty)
        'presenceBySlot': presenceBySlot.map(
          (day, bySlot) => MapEntry(
            day.name,
            bySlot.map((slot, memberIds) => MapEntry(slot.name, memberIds)),
          ),
        ),
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
      presenceBySlot: _parsePresenceBySlot(data['presenceBySlot']),
    );
  }

  /// Tolerant parse of the per-(day, slot) presence map. Malformed keys/values
  /// are dropped rather than corrupting another slot's selection; an unknown
  /// day or slot name is skipped (not defaulted onto another key). An empty
  /// inner map for a day is not retained.
  static Map<DayOfWeek, Map<MealSlot, List<String>>> _parsePresenceBySlot(
    dynamic raw,
  ) {
    if (raw is! Map) return const {};
    final result = <DayOfWeek, Map<MealSlot, List<String>>>{};
    raw.forEach((dayKey, bySlot) {
      if (dayKey is! String || bySlot is! Map) return;
      final day = DayOfWeek.values.where((d) => d.name == dayKey).firstOrNull;
      if (day == null) return;
      final slots = <MealSlot, List<String>>{};
      bySlot.forEach((slotKey, value) {
        if (slotKey is! String || value is! List) return;
        final slot = MealSlot.values
            .where((s) => s.name == slotKey)
            .firstOrNull;
        if (slot == null) return;
        slots[slot] = value.whereType<String>().toList();
      });
      if (slots.isNotEmpty) result[day] = slots;
    });
    return result;
  }
}
