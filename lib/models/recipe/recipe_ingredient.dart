import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';

/// BUT-1216: structured ingredient persisted on the Recipe — the foundation
/// for portion scaling (BUT-444), menu→shopping aggregation (BUT-956), and
/// per-ingredient confidence (BUT-925).
///
/// Always additive to the free-text `Recipe.ingredients` strings, never a
/// replacement: [raw] preserves the original line verbatim, and consumers
/// fall back to raw-only entries when no structured data exists (legacy
/// recipes) or when it no longer matches the edited strings (see
/// `Recipe.structuredIngredients`).
class RecipeIngredient {
  /// Parsed quantity, when the line has a single numeric amount.
  /// Null for unparseable amounts (ranges like "1-2", "en nypa") — [raw]
  /// still carries the original text.
  final num? amount;

  /// Measurement unit as written (e.g. "dl", "msk", "g", "st").
  final String? unit;

  /// The ingredient name (core identifier, e.g. "vetemjöl").
  final String name;

  /// Preparation/size notes (e.g. "hackad", "stor", "rumstempererad").
  final String? note;

  /// The original ingredient line verbatim. Always present — the safety
  /// net that lets every consumer render something meaningful.
  final String raw;

  const RecipeIngredient({
    this.amount,
    this.unit,
    required this.name,
    this.note,
    required this.raw,
  });

  /// A line we have no structured data for — name falls back to the line
  /// itself. This is what legacy recipes degrade to.
  factory RecipeIngredient.rawOnly(String line) =>
      RecipeIngredient(name: line.trim(), raw: line);

  /// Converts the parser's [ParsedIngredient] (quantity as String) to the
  /// persisted form. Unparseable quantities (ranges, words) yield a null
  /// [amount]; size + preparation fold into [note].
  factory RecipeIngredient.fromParsed(ParsedIngredient parsed) {
    final noteParts = [
      if (parsed.size != null && parsed.size!.isNotEmpty) parsed.size!,
      if (parsed.preparation != null && parsed.preparation!.isNotEmpty)
        parsed.preparation!,
    ];
    return RecipeIngredient(
      amount: _parseAmount(parsed.quantity),
      unit: (parsed.unit?.isEmpty ?? true) ? null : parsed.unit,
      name: parsed.name,
      note: noteParts.isEmpty ? null : noteParts.join(', '),
      raw: parsed.originalLine,
    );
  }

  /// Swedish sources write decimals with a comma ("1,5 dl").
  static num? _parseAmount(String? quantity) {
    if (quantity == null || quantity.isEmpty) return null;
    return num.tryParse(quantity.replaceAll(',', '.'));
  }

  /// Whether this entry carries usable quantity data (scaling/aggregation
  /// candidates). Raw-only fallbacks return false.
  bool get isStructured => amount != null || (unit?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (unit != null) 'unit': unit,
        'name': name,
        if (note != null) 'note': note,
        'raw': raw,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final raw = SerializationUtils.safeString(json, 'raw');
    return RecipeIngredient(
      amount: json['amount'] is num ? json['amount'] as num : null,
      unit: SerializationUtils.safeNullableString(json, 'unit'),
      name: SerializationUtils.safeString(json, 'name', defaultValue: raw),
      note: SerializationUtils.safeNullableString(json, 'note'),
      raw: raw,
    );
  }

  /// Safe list parse for Firestore/JSON payloads: a malformed entry degrades
  /// to raw-only (or is dropped when not even a map) instead of throwing —
  /// a corrupt structured list must never break recipe deserialization.
  static List<RecipeIngredient>? listFromJson(dynamic value) {
    if (value is! List) return null;
    final parsed = <RecipeIngredient>[];
    for (final entry in value) {
      if (entry is Map<String, dynamic>) {
        parsed.add(RecipeIngredient.fromJson(entry));
      } else if (entry is Map) {
        parsed.add(RecipeIngredient.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return parsed.isEmpty ? null : parsed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredient &&
          amount == other.amount &&
          unit == other.unit &&
          name == other.name &&
          note == other.note &&
          raw == other.raw;

  @override
  int get hashCode => Object.hash(amount, unit, name, note, raw);

  @override
  String toString() => 'RecipeIngredient($raw)';
}
