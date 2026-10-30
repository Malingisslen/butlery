import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/quantity_parser.dart';

/// The amount an ingredient line states: a number, a range ("2-3 dl"), or
/// nothing at all ("salt"). Read from the line itself, so every import path
/// answers the same, whatever amount it stored.
class IngredientQuantity {
  const IngredientQuantity._(this.min, this.max, {this.approximate = false});

  static const IngredientQuantity unknown = IngredientQuantity._(null, null);

  /// The amount, or the low end of a range. Null when the line states none.
  final double? min;

  /// The high end of a range; equal to [min] for a single amount.
  final double? max;

  /// "ca 2 dl", "cirka", "ungefär".
  final bool approximate;

  bool get isUnknown => min == null;
  bool get isRange => min != null && max != null && max! > min!;

  /// What a shopping list buys: a range's highest value (Malin 2026-10-30).
  double? get forShopping => max ?? min;

  static final RegExp _startsWithWordRe = RegExp(r'^\p{L}', unicode: true);
  static final RegExp _rangeSplitRe = RegExp(r'\s*[-–]\s*');
  static final RegExp _qualifierRe = RegExp(
    r'^(?:ca|ev)\.?\s+',
    caseSensitive: false,
  );
  static final RegExp _digitRe = RegExp(r'[\d½¼¾⅓⅔⅛⅜⅝⅞]');
  static final RegExp _numberRe = RegExp(r'^\d+(?:[,.]\d+)?$');

  static IngredientQuantity read(String line) {
    final parsed = IngredientParser.parseIngredient(line);
    if (IngredientParser.statedQuantity(line, parsed.quantity) == null) {
      return unknown;
    }
    final low = parsed.quantity;
    final written = IngredientParser.writtenAmount(line);
    if (written == null) return IngredientQuantity._(low, low);
    final parts = written.split(_rangeSplitRe);
    final high = parts.length > 1 ? _readAmount(parts.last) : null;
    return IngredientQuantity._(
      low,
      high != null && high > low ? high : low,
      approximate: _startsWithWordRe.hasMatch(written),
    );
  }

  static double? _readAmount(String text) {
    final amount = text.replaceFirst(_qualifierRe, '').trim();
    final fraction = QuantityParser.parseAsciiFraction(amount);
    if (fraction != null) return fraction;
    if (_numberRe.hasMatch(amount) || QuantityParser.isFraction(amount)) {
      return QuantityParser.parse(amount);
    }
    return null;
  }

  /// One recipe line as a shopping list counts it. A stored amount inside the
  /// line's range (an import path may have stored its low end or its
  /// midpoint) counts as the top. A line stored without structure (older
  /// recipes) is parsed here rather than listed whole.
  static ({String name, String unit, double? amount}) shoppingLine(
    RecipeIngredient entry,
  ) {
    final quantity = read(entry.raw);
    if (entry.isStructured) {
      final stored = entry.amount?.toDouble();
      final amount = switch (stored) {
        _
            when quantity.isUnknown &&
                entry.unit.orEmpty().isEmpty &&
                !_digitRe.hasMatch(entry.raw) =>
          null,
        null => quantity.forShopping,
        final s
            when quantity.isRange && s >= quantity.min! && s <= quantity.max! =>
          quantity.max,
        final s => s,
      };
      return (
        name: entry.name.trim(),
        unit: amount == null ? '' : entry.unit.orEmpty().toLowerCase().trim(),
        amount: amount,
      );
    }
    final parsed = quantity.isUnknown
        ? null
        : IngredientParser.parseIngredient(entry.raw);
    if (parsed == null || parsed.name.trim().isEmpty) {
      return (name: entry.name.trim(), unit: '', amount: null);
    }
    return (
      name: parsed.name.trim(),
      unit: parsed.unit.toLowerCase().trim(),
      amount: quantity.forShopping,
    );
  }
}
