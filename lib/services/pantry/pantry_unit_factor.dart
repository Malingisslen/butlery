import 'package:butlery/utils/text/unit_converter.dart';

/// How a pantry row's unit relates to a recipe line's unit. The cooked-recipe
/// take and the shopping list's pantry deduction both count stock this way,
/// so they cannot disagree on what a unit is worth.
class PantryUnitFactor {
  const PantryUnitFactor._();

  /// "3 ägg" carries no unit and the pantry's "12 st" does: both count pieces.
  static bool isCount(String unit) => unit.isEmpty || unit == 'st';

  /// How many of [to] one [from] holds, or null when the two do not convert.
  /// Both units are canonical ([UnitDefinitions.canonical]).
  static double? unitsOfToPerFrom(String from, String to) {
    if (from == to || (isCount(from) && isCount(to))) return 1;
    final source = SmartUnitConverter.toCanonicalBase(1, from);
    final target = SmartUnitConverter.toCanonicalBase(1, to);
    if (source == null ||
        target == null ||
        source.baseUnit != target.baseUnit) {
      return null;
    }
    return source.quantity / target.quantity;
  }
}
