// lib/widgets/common/input/portion_scaler_logic.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Contains the business logic for portion scaling and unit conversion
class PortionScalerLogic {
  static const Set<String> _americanUnits = {
    'cup',
    'cups',
    'oz',
    'fl oz',
    'floz',
    'tbsp',
    'tsp',
    'lb',
    'lbs',
    'pound',
    'pounds',
    'ounce',
    'ounces',
    'pint',
    'pints',
    'quart',
    'quarts',
    'gallon',
    'gallons',
    'tablespoon',
    'tablespoons',
    'teaspoon',
    'teaspoons',
  };

  /// Detects if any ingredient contains American units
  static bool detectAmericanUnits(List<String> ingredients) {
    for (final ingredient in ingredients) {
      final parsed = IngredientParser.parseIngredient(ingredient);

      if (_americanUnits.contains(parsed.unit.toLowerCase())) {
        return true;
      }

      // Fallback: simple string check
      final lowerIngredient = ingredient.toLowerCase();
      for (final unit in _americanUnits) {
        if (lowerIngredient.contains(' $unit ') ||
            lowerIngredient.startsWith('$unit ') ||
            lowerIngredient.endsWith(' $unit')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Scales ingredients from original portions to new portions
  static List<String> scaleIngredients(
    List<String> originalIngredients,
    int originalPortions,
    int newPortions,
    bool convertToSwedish,
  ) {
    if (originalPortions == 0 || newPortions == originalPortions) {
      // Even if portions are same, run conversion if convertToSwedish is true
      if (convertToSwedish) {
        final scaledList = <String>[];
        for (final ingredient in originalIngredients) {
          final converted = _scaleIndividualIngredient(
            ingredient,
            1.0,
            convertToSwedish,
          ); // Scale factor 1.0
          scaledList.add(converted);
        }
        return scaledList;
      }

      return List.from(originalIngredients);
    }

    final scaleFactor = newPortions.toDouble() / originalPortions.toDouble();
    final scaledList = <String>[];

    for (final ingredient in originalIngredients) {
      final scaled = _scaleIndividualIngredient(
        ingredient,
        scaleFactor,
        convertToSwedish,
      );
      scaledList.add(scaled);
    }

    return scaledList;
  }

  /// BUT-444: structured-first scaling. [entries] come from
  /// `Recipe.structuredIngredients` — one entry per ingredient line, with
  /// raw-only fallbacks for legacy/manually-edited recipes. Structured
  /// entries scale via the persisted `amount` (no string re-parse); range
  /// lines scale both endpoints; everything else keeps the v1 string path.
  static List<String> scaleEntries(
    List<RecipeIngredient> entries,
    int originalPortions,
    int newPortions,
    bool convertToSwedish,
  ) {
    // Mirror scaleIngredients' same-portions semantics: unchanged unless
    // unit conversion is requested (then run the pipeline at factor 1.0).
    final noScale = originalPortions == 0 || newPortions == originalPortions;
    if (noScale && !convertToSwedish) {
      return [for (final e in entries) e.raw];
    }
    final factor =
        noScale ? 1.0 : newPortions.toDouble() / originalPortions.toDouble();
    return [for (final e in entries) _scaleEntry(e, factor, convertToSwedish)];
  }

  static String _scaleEntry(
    RecipeIngredient entry,
    double factor,
    bool convertToSwedish,
  ) {
    if (entry.raw.trim().isEmpty) return entry.raw;

    // Ranges first: a structured entry for "1-2 vitlöksklyftor" carries
    // amount == null (a range has no single amount), so without this branch
    // it would fall to the string path where QuantityParser coerced the
    // range to 1.0 — the "scales silently wrong" bug this ticket fixes.
    final ranged = _scaleRange(entry.raw, factor);
    if (ranged != null) return ranged;

    if (entry.amount != null) {
      return _rebuildStructuredEntry(entry, factor, convertToSwedish);
    }
    return _scaleIndividualIngredient(entry.raw, factor, convertToSwedish);
  }

  /// Scales a structured entry numerically and rebuilds the display line.
  /// Same unit-conversion pipeline as the string path, but the quantity
  /// comes from the persisted amount instead of re-parsing the line.
  static String _rebuildStructuredEntry(
    RecipeIngredient entry,
    double factor,
    bool convertToSwedish,
  ) {
    final converted = _convertUnits(
      entry.amount!.toDouble() * factor,
      entry.unit.orEmpty(),
      convertToSwedish,
    );

    final note =
        (entry.note != null && entry.note!.isNotEmpty) ? ', ${entry.note}' : '';
    if (converted.unit.isNotEmpty) {
      final formatted =
          TextFormatting.toSwedishHalfFraction(converted.quantity);
      return '$formatted ${converted.unit} ${entry.name}$note';
    }
    return '${SwedishPluralization.formatIngredient(entry.name, converted.quantity)}$note';
  }

  /// Shared two-pass unit conversion: optional American→Swedish, then the
  /// readability promotion (e.g. 12 msk → 1,8 dl). Both scaling paths call
  /// this — unit/conversion fixes land in one place.
  static ({double quantity, String unit}) _convertUnits(
    double quantity,
    String unit,
    bool convertToSwedish,
  ) {
    var q = quantity;
    var u = unit;
    if (convertToSwedish &&
        u.isNotEmpty &&
        _americanUnits.contains(u.toLowerCase())) {
      final c = SmartUnitConverter.convertToReadableUnit(q, u);
      q = c.quantity;
      u = c.unit;
    }
    if (u.isNotEmpty && SmartUnitConverter.shouldConvert(q, u)) {
      final c = SmartUnitConverter.convertToReadableUnit(q, u);
      q = c.quantity;
      u = c.unit;
    }
    return (quantity: q, unit: u);
  }

  /// BUT-444: "2-3 dl" must scale both endpoints ("4-6 dl" at 2x) — the v1
  /// pipeline parsed the range as 1.0 and scaled from that. Matches a
  /// leading numeric range (ASCII or en/em dash, Swedish decimal comma).
  /// Unit conversion is deliberately skipped for ranges: the endpoints
  /// could convert to different units (e.g. 8-12 msk → 1,2 dl-1,8 dl),
  /// which reads worse than keeping the source unit.
  static final RegExp _leadingRange = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*[-–—]\s*(\d+(?:[.,]\d+)?)(\s.*|$)',
  );

  static String? _scaleRange(String line, double factor) {
    final match = _leadingRange.firstMatch(line);
    if (match == null) return null;
    double parseEndpoint(String s) => double.parse(s.replaceAll(',', '.'));
    final low = parseEndpoint(match.group(1)!) * factor;
    final high = parseEndpoint(match.group(2)!) * factor;
    final rest = match.group(3).orEmpty();
    return '${TextFormatting.toSwedishHalfFraction(low)}'
        '-${TextFormatting.toSwedishHalfFraction(high)}$rest';
  }

  /// Scales a single ingredient by the given scale factor
  static String _scaleIndividualIngredient(
    String ingredient,
    double scaleFactor,
    bool convertToSwedish,
  ) {
    if (ingredient.trim().isEmpty) return ingredient;

    // BUT-444: range-aware before the single-quantity parser (which coerces
    // "2-3" to 1.0). Keeps the string path correct for legacy callers too.
    final ranged = _scaleRange(ingredient, scaleFactor);
    if (ranged != null) return ranged;

    final parsed = IngredientParser.parseIngredient(ingredient);

    // If no quantity found, return unchanged
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == ingredient) {
      return ingredient;
    }

    // Scale the quantity
    final scaledQuantity = parsed.quantity * scaleFactor;

    final converted =
        _convertUnits(scaledQuantity, parsed.unit, convertToSwedish);

    // Format with Swedish fractions and units
    final formattedQuantity =
        TextFormatting.toSwedishHalfFraction(converted.quantity);

    // Build together again
    if (converted.unit.isNotEmpty) {
      return '$formattedQuantity ${converted.unit} ${parsed.name}';
    } else {
      // Use pluralization for ingredients without unit
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}
