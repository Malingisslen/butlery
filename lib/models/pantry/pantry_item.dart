import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';

/// Physical location where a pantry item is stored.
///
/// Enum values are in English for code/storage; Swedish display strings
/// live in the l10n layer (see `AppLocalizations.pantryLocation*`).
enum PantryLocation {
  fridge,
  freezer,
  pantry,
  spiceRack
  ;

  /// Infers a location from an [IngredientData.typicalStorage] value.
  ///
  /// Accepts: 'refrigerated', 'frozen', 'ambient'. Returns [pantry] as the
  /// sensible fallback for anything unknown (pantry is the most common
  /// storage for ambient goods users add manually).
  static PantryLocation fromTypicalStorage(String? typicalStorage) {
    switch (typicalStorage) {
      case 'refrigerated':
        return PantryLocation.fridge;
      case 'frozen':
        return PantryLocation.freezer;
      case 'ambient':
      default:
        return PantryLocation.pantry;
    }
  }
}

/// Classifies how urgent an item's expiry status is, for UI badges/sorting.
enum PantryExpiryStatus { fresh, expiringSoon, expired }

/// A single item the user tracks in their pantry ("skafferi").
///
/// Items may be linked to a taxonomy [ingredientId] for recipe matching,
/// or stand alone with just a free-text [ingredientName] (e.g. a brand
/// product that isn't in the ingredient database).
@immutable
class PantryItem {
  final String id;

  /// Taxonomy ingredient ID. Null when the item has no canonical match
  /// (e.g. user typed "Oatly iKaffe" — no entry in the ingredient DB).
  final String? ingredientId;

  /// Denormalized display name (Swedish by default). Always populated —
  /// either from the matched ingredient or from the user's raw input.
  final String ingredientName;

  /// The amount on hand, or null for "har hemma, vet inte hur mycket" — a
  /// value of its own that never overwrites a known amount
  /// (produktregler.md:148, § 2.2).
  final double? quantity;
  final String unit;
  final PantryLocation location;
  final DateTime? expiryDate;
  final DateTime addedAt;
  final String? note;

  /// BUT-1279: a "staple" the user always keeps on hand (salt, olja, peppar).
  /// Staples are excluded from the menu→shopping list so the generated list
  /// stays focused on what actually needs buying this week.
  final bool isStaple;

  /// When the row was last changed, written by the server on every update
  /// (produktregler.md:105: "radens tidsstämpel uppdateras"). Null for a row
  /// that has not been changed since it was added.
  final DateTime? updatedAt;

  /// Who made the last change. The pantry is owner-only
  /// (firestore.rules, `match /pantry/{pantryItemId}`), so this is the owner;
  /// it is stored so a change from another device can be told apart from
  /// none.
  final String? updatedBy;

  const PantryItem({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.addedAt,
    this.ingredientId,
    this.expiryDate,
    this.note,
    this.isStaple = false,
    this.updatedAt,
    this.updatedBy,
  });

  factory PantryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PantryItem.fromMap(data, doc.id);
  }

  factory PantryItem.fromMap(Map<String, dynamic> data, String id) {
    return PantryItem(
      id: id,
      ingredientId: SerializationUtils.safeNullableString(data, 'ingredientId'),
      ingredientName: SerializationUtils.safeString(data, 'ingredientName'),
      quantity: SerializationUtils.safeNullableDouble(data, 'quantity'),
      unit: SerializationUtils.safeString(data, 'unit'),
      location: SerializationUtils.safeEnumByName(
        PantryLocation.values,
        SerializationUtils.safeString(
          data,
          'location',
          defaultValue: PantryLocation.pantry.name,
        ),
        PantryLocation.pantry,
      ),
      expiryDate: SerializationUtils.safeDateTime(data, 'expiryDate'),
      addedAt: SerializationUtils.safeRequiredDateTime(data, 'addedAt'),
      note: SerializationUtils.safeNullableString(data, 'note'),
      isStaple: SerializationUtils.safeBool(data, 'isStaple'),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
      updatedBy: SerializationUtils.safeNullableString(data, 'updatedBy'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (ingredientId != null) 'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      // Written even when null: "har hemma" without an amount is a value.
      'quantity': quantity,
      'unit': unit,
      'location': location.name,
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      'addedAt': Timestamp.fromDate(addedAt),
      if (note != null) 'note': note,
      if (isStaple) 'isStaple': true,
    };
  }

  /// The fields a user edits, as a Firestore update of only what changed
  /// since [before] (produktregler.md:105, :142: "per fält, senaste ändring
  /// vinner"). Two devices that change different fields of the same row no
  /// longer overwrite each other.
  ///
  /// A null [quantity] never replaces a known amount (produktregler.md:148):
  /// when [before] has one, the quantity is left out. A cleared optional
  /// field is deleted. [updatedAt] and [updatedBy] are the repository's to
  /// write, so they are never part of the result.
  Map<String, Object> changesFrom(PantryItem before) {
    return {
      if (ingredientId != before.ingredientId)
        'ingredientId': ingredientId ?? FieldValue.delete(),
      if (ingredientName != before.ingredientName)
        'ingredientName': ingredientName,
      if (quantity != before.quantity &&
          !(quantity == null && before.quantity != null))
        'quantity': ?quantity,
      if (unit != before.unit) 'unit': unit,
      if (location != before.location) 'location': location.name,
      if (expiryDate != before.expiryDate)
        'expiryDate': expiryDate == null
            ? FieldValue.delete()
            : Timestamp.fromDate(expiryDate!),
      if (note != before.note) 'note': note ?? FieldValue.delete(),
      if (isStaple != before.isStaple) 'isStaple': isStaple,
    };
  }

  /// Every field a user edits, for an update where the previous state is not
  /// known. The same rules as [changesFrom]: a null quantity is left out, so
  /// it cannot wipe an amount another device wrote.
  Map<String, Object> editableFields() {
    return {
      'ingredientId': ingredientId ?? FieldValue.delete(),
      'ingredientName': ingredientName,
      'quantity': ?quantity,
      'unit': unit,
      'location': location.name,
      'expiryDate': expiryDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(expiryDate!),
      'note': note ?? FieldValue.delete(),
      'isStaple': isStaple,
    };
  }

  PantryItem copyWith({
    String? id,
    String? ingredientId,
    String? ingredientName,
    double? quantity,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    DateTime? addedAt,
    String? note,
    bool? isStaple,
    DateTime? updatedAt,
    String? updatedBy,
    bool clearIngredientId = false,
    bool clearQuantity = false,
    bool clearExpiryDate = false,
    bool clearNote = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      ingredientId: clearIngredientId
          ? null
          : (ingredientId ?? this.ingredientId),
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: unit ?? this.unit,
      location: location ?? this.location,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      addedAt: addedAt ?? this.addedAt,
      note: clearNote ? null : (note ?? this.note),
      isStaple: isStaple ?? this.isStaple,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// BUT-1910: this used to `toString()` the fraction, so a shopping item read
  /// "1,5" and a pantry item "1.5" — one screen apart, for the same kind of
  /// number. It is also what seeds the edit sheet's amount field, and that
  /// field parses both separators.
  ///
  /// Empty when the amount is unknown ("har hemma", [quantity] null).
  String get formattedQuantity {
    final q = quantity;
    return q == null ? '' : formatSwedishDecimal(q);
  }

  bool get isExpired {
    final exp = expiryDate;
    if (exp == null) return false;
    return clock.now().isAfter(exp);
  }

  /// Whole days until expiry. Negative when already expired, null when
  /// no expiry is tracked. Computed at day granularity (ignores time of
  /// day) to match how users think about shelf life.
  int? get daysUntilExpiry {
    final exp = expiryDate;
    if (exp == null) return null;
    final now = clock.now();
    final nowDay = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(exp.year, exp.month, exp.day);
    return expDay.difference(nowDay).inDays;
  }

  /// Three-state classification: fresh if >3 days or no date, expiringSoon
  /// within 3 days, expired if past. The 3-day threshold matches the
  /// service default for `getExpiringSoon`.
  PantryExpiryStatus get expiryStatus {
    final days = daysUntilExpiry;
    if (days == null) return PantryExpiryStatus.fresh;
    if (days < 0) return PantryExpiryStatus.expired;
    if (days <= 3) return PantryExpiryStatus.expiringSoon;
    return PantryExpiryStatus.fresh;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PantryItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PantryItem($id: $ingredientName $quantity $unit @ ${location.name})';
}
