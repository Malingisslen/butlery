/// The on-disk shape of a week's per-(day, slot) member lists, shared by
/// presence and away (BUT-1611, BUT-2362).
library;

import 'package:butlery/models/menu/weekly_menu_plan.dart';

Map<String, dynamic> serializeSlotMemberMap(
  Map<DayOfWeek, Map<MealSlot, List<String>>> bySlot,
) => bySlot.map(
  (day, slots) => MapEntry(
    day.name,
    slots.map((slot, memberIds) => MapEntry(slot.name, memberIds)),
  ),
);

/// Tolerant parse of a per-(day, slot) member map (presence or away).
/// Malformed keys/values are dropped rather than corrupting another slot's
/// selection; an unknown day or slot name is skipped (not defaulted onto
/// another key). An empty inner map for a day is not retained.
Map<DayOfWeek, Map<MealSlot, List<String>>> parseSlotMemberMap(dynamic raw) {
  if (raw is! Map) return const {};
  final result = <DayOfWeek, Map<MealSlot, List<String>>>{};
  raw.forEach((dayKey, bySlot) {
    if (dayKey is! String || bySlot is! Map) return;
    final day = DayOfWeek.values.where((d) => d.name == dayKey).firstOrNull;
    if (day == null) return;
    final slots = <MealSlot, List<String>>{};
    bySlot.forEach((slotKey, value) {
      if (slotKey is! String || value is! List) return;
      final slot = MealSlot.values.where((s) => s.name == slotKey).firstOrNull;
      if (slot == null) return;
      slots[slot] = value.whereType<String>().toList();
    });
    if (slots.isNotEmpty) result[day] = slots;
  });
  return result;
}
