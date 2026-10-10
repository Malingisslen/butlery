import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/utils/text/unit_converter.dart';

/// Converts a recipe line's amount and unit to grams of a matched ingredient.
class NutritionAmount {
  NutritionAmount._();

  /// Plural and long spellings of the piece-type units the curated table
  /// uses, folded to the table's spelling.
  static const Map<String, String> _pieceUnits = {
    'st': 'st',
    'st.': 'st',
    'styck': 'st',
    'stycken': 'st',
    'klyfta': 'klyfta',
    'klyftor': 'klyfta',
    'burk': 'burk',
    'burkar': 'burk',
    'paket': 'paket',
    'pkt': 'paket',
    'förp': 'paket',
    'förpackning': 'paket',
    'förpackningar': 'paket',
    'påse': 'påse',
    'påsar': 'påse',
    'knippe': 'knippe',
    'knippen': 'knippe',
    'kruka': 'kruka',
    'krukor': 'kruka',
    'skiva': 'skiva',
    'skivor': 'skiva',
    'bit': 'bit',
    'bitar': 'bit',
    'näve': 'näve',
    'nävar': 'näve',
    'tärning': 'tärning',
    'tärningar': 'tärning',
  };

  /// Grams for [amount] [unit] of [match], or null when it cannot be weighed
  /// without guessing: an unknown unit, a volume of something with no
  /// density, or a piece of something with no piece weight. A missing unit
  /// means pieces ("2 ägg").
  static double? grams({
    required num amount,
    required String? unit,
    required IngredientMatch match,
  }) {
    final u = unit.orEmpty().toLowerCase().trim();
    if (u.isEmpty) return _pieces(amount, 'st', match);

    final measure = SmartUnitConverter.toCanonicalBase(amount.toDouble(), u);
    if (measure != null) {
      if (measure.baseUnit == 'g') return measure.quantity;
      final perDl = match.gramsPerDl;
      return perDl == null ? null : measure.quantity / 100 * perDl;
    }

    final direct = match.gramsPerUnit[u];
    if (direct != null) return amount * direct;
    final piece = _pieceUnits[u];
    return piece == null ? null : _pieces(amount, piece, match);
  }

  static double? _pieces(num amount, String unit, IngredientMatch match) {
    final each = match.gramsPerUnit[unit];
    return each == null ? null : amount * each;
  }
}
