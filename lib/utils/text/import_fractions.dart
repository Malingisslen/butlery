import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/utils/text/quantity_parser.dart';
import 'package:butlery/utils/text/text_formatting.dart';

/// Writes an imported line's leading amount the way the recipe page shows it
/// ("1,5 dl" → "1 ½ dl"), so the editor and the page agree. Only imports go
/// through here: text the user typed is never rewritten.
class ImportFractions {
  ImportFractions._();

  // Mixed and simple ASCII fractions come first: alternation takes the first
  // branch that matches, and a bare "1" would leave "1/2" behind.
  static final RegExp _leadingAmount = RegExp(
    r'^(\s*)(\d+\s+\d+/\d+|\d+/\d+|\d+(?:[.,]\d+)?)(?![\d/½¼¾⅓⅔])',
  );

  static final RegExp _glyph = RegExp('[½¼¾⅓⅔]');

  // "1.500 g" is fifteen hundred grams, not one and a half.
  static final RegExp _thousands = RegExp(r'^\d+\.\d{3}$');

  static String line(String text) {
    final match = _leadingAmount.firstMatch(text);
    if (match == null) return text;
    final number = match.group(2)!;
    final rest = text.substring(match.end);
    // A range is shown as written on the recipe page, so it stays as read.
    if (RegExp(r'^\s*[-–—]').hasMatch(rest)) return text;
    if (_thousands.hasMatch(number)) return text;
    final value =
        QuantityParser.parseAsciiFraction(number) ??
        double.tryParse(number.replaceAll(',', '.'));
    if (value == null || value == value.roundToDouble()) return text;
    final shown = TextFormatting.toSwedishHalfFraction(value);
    if (!_glyph.hasMatch(shown)) return text;
    final gap = rest.isEmpty || rest.startsWith(RegExp(r'\s')) ? '' : ' ';
    return '${match.group(1)}$shown$gap$rest';
  }

  /// Rewrites [recipe]'s lines and the `raw` of each structured entry alike,
  /// so `entry.raw == ingredients[i]` still holds and the save keeps the
  /// import's richer entries instead of re-deriving them.
  static Recipe recipe(Recipe recipe) {
    final lines = [for (final l in recipe.ingredients) line(l)];
    final structured = recipe.core.structuredIngredients;
    final entries = structured == null
        ? null
        : [for (final entry in structured) withRaw(entry, line(entry.raw))];
    final unchanged =
        _same(lines, recipe.ingredients) &&
        (structured == null || _same(entries!, structured));
    if (unchanged) return recipe;
    return recipe.copyWith(
      ingredients: lines,
      structuredIngredients: entries,
    );
  }

  static bool _same(List<Object> a, List<Object> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
    }
    return true;
  }

  static RecipeIngredient withRaw(RecipeIngredient entry, String raw) =>
      raw == entry.raw
      ? entry
      : RecipeIngredient(
          amount: entry.amount,
          unit: entry.unit,
          name: entry.name,
          note: entry.note,
          raw: raw,
          section: entry.section,
          ingredientId: entry.ingredientId,
        );
}
