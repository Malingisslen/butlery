import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/core/utils/serialization_utils.dart';

/// Physical location where a pantry item is stored.
///
/// Enum values are in English for code/storage; Swedish display strings
/// live in the l10n layer (see `AppLocalizations.pantryLocation*`).
enum PantryLocation {
  fridge,
  freezer,
  pantry,
  spiceRack;

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

  final double quantity;
  final String unit;
  final PantryLocation location;
  final DateTime? expiryDate;
  final DateTime addedAt;
  final String? note;

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
      quantity: SerializationUtils.safeDouble(data, 'quantity'),
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (ingredientId != null) 'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'location': location.name,
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      'addedAt': Timestamp.fromDate(addedAt),
      if (note != null) 'note': note,
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
    bool clearIngredientId = false,
    bool clearExpiryDate = false,
    bool clearNote = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      ingredientId:
          clearIngredientId ? null : (ingredientId ?? this.ingredientId),
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      location: location ?? this.location,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      addedAt: addedAt ?? this.addedAt,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  String get formattedQuantity => quantity == quantity.truncate()
      ? quantity.toInt().toString()
      : quantity.toString();

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
