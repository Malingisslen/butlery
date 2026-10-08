import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// The content of one shopping row at a moment in time, kept so the row can be
/// restored for 30 days (BUT-2140).
///
/// Holds only what the user typed: id, name, amount, unit, category, note, and
/// when the snapshot was taken. It deliberately has no `*UserId` or
/// `*DisplayName` field. On a shared list the snapshot sits inside a document
/// the GDPR export and the erasure cascade only scrub at the top level of each
/// row, so a name or uid placed here would be exported unredacted and survive
/// an account deletion.
class ShoppingRowSnapshot {
  const ShoppingRowSnapshot({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
    required this.at,
    this.note,
  });

  /// [at] is kept to the millisecond. `arrayRemove` matches a stored entry
  /// by exact value, and a web client reads timestamps at millisecond
  /// precision, so an entry written with microseconds could never be taken
  /// out of the history from there.
  factory ShoppingRowSnapshot.fromItem(UnifiedShoppingItem item, DateTime at) =>
      ShoppingRowSnapshot(
        id: item.id,
        name: item.name,
        amount: item.amount,
        unit: item.unit,
        category: item.category,
        note: item.note,
        at: DateTime.fromMillisecondsSinceEpoch(
          at.millisecondsSinceEpoch,
          isUtc: at.isUtc,
        ),
      );

  /// Strict on `id`, `name` and `at`: a snapshot without them cannot be shown
  /// or restored, and list-level parsing skips a row that throws.
  factory ShoppingRowSnapshot.fromMap(Map<String, dynamic> map) =>
      ShoppingRowSnapshot(
        id: SerializationUtils.requiredString(map, 'id'),
        name: SerializationUtils.requiredString(map, 'name'),
        amount: SerializationUtils.safeDouble(map, 'amount'),
        unit: SerializationUtils.safeString(map, 'unit'),
        category: SerializationUtils.safeString(
          map,
          'category',
          defaultValue: ShoppingCategory.other,
        ),
        note: SerializationUtils.safeNullableString(map, 'note'),
        at: SerializationUtils.requiredDateTime(map, 'at'),
      );

  final String id;
  final String name;
  final double amount;
  final String unit;
  final String category;
  final String? note;
  final DateTime at;

  /// A snapshot stays restorable for exactly 30 days; a clock slightly behind
  /// the writer's must not hide a fresh one, so a future [at] counts as kept.
  static const Duration retention = Duration(days: 30);

  bool restorableAt(DateTime now) => now.difference(at) <= retention;

  /// Rebuilds the row. Attribution is not stored, so the caller stamps who
  /// restored it.
  UnifiedShoppingItem toItem() => UnifiedShoppingItem(
    id: id,
    name: name,
    amount: amount,
    unit: unit,
    category: category,
    note: note,
  );

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'amount': amount,
    'unit': unit,
    'category': category,
    'note': note,
    'at': Timestamp.fromDate(at),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'unit': unit,
    'category': category,
    'note': note,
    'at': at.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingRowSnapshot &&
          id == other.id &&
          name == other.name &&
          amount == other.amount &&
          unit == other.unit &&
          category == other.category &&
          note == other.note &&
          at.isAtSameMomentAs(other.at);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    amount,
    unit,
    category,
    note,
    at.microsecondsSinceEpoch,
  );
}
