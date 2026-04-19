import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// One month's seasonal-cooking context for BUT-409.
///
/// Loaded from `assets/seasonal/{year}.json` at startup via
/// `SeasonalHeroService`. A [SeasonalMonth] describes which ingredients are
/// in season, which vegetable illustration represents the month, and an
/// optional two-stop gradient for decorative surfaces. The gradient palette
/// is held as hex strings so the curation file can be edited without
/// touching Dart code; interpretation is delegated to the widget layer.
class SeasonalMonth {
  const SeasonalMonth({
    required this.monthIndex,
    required this.monthKey,
    required this.ingredients,
    required this.vegetableType,
    required this.gradient,
  });

  /// 1-based month number (1 = January).
  final int monthIndex;

  /// Stable lowercase month identifier used as an l10n key suffix —
  /// e.g. `january` maps to `seasonalHeroMonthJanuary`.
  final String monthKey;

  /// Canonical lowercase ingredient names to match against recipe ingredients.
  /// Matching is substring-based, case-insensitive (see SeasonalHeroService).
  final List<String> ingredients;

  /// Illustration shown in the seasonal header.
  final VegetableType vegetableType;

  /// Two hex colour stops for decorative surfaces. Stored as strings so the
  /// curation JSON can be edited without rebuilding the app.
  final List<String> gradient;

  /// Parse one month entry from the seasonal JSON asset.
  ///
  /// Throws [FormatException] if required fields are missing or malformed;
  /// the service catches and logs so the UI degrades to "no hero" rather than
  /// crashing.
  factory SeasonalMonth.fromJson(Map<String, dynamic> json) {
    final monthIndex = json['monthIndex'];
    final monthKey = json['monthKey'];
    final ingredientsRaw = json['ingredients'];
    final vegetableTypeName = json['vegetableType'];
    final gradientRaw = json['gradient'];

    if (monthIndex is! int || monthIndex < 1 || monthIndex > 12) {
      throw const FormatException('SeasonalMonth: monthIndex must be 1-12');
    }
    if (monthKey is! String || monthKey.isEmpty) {
      throw const FormatException('SeasonalMonth: monthKey missing');
    }
    if (ingredientsRaw is! List || ingredientsRaw.isEmpty) {
      throw const FormatException('SeasonalMonth: ingredients required');
    }
    if (vegetableTypeName is! String) {
      throw const FormatException('SeasonalMonth: vegetableType required');
    }
    if (gradientRaw is! List || gradientRaw.length != 2) {
      throw const FormatException('SeasonalMonth: gradient needs 2 hex stops');
    }

    return SeasonalMonth(
      monthIndex: monthIndex,
      monthKey: monthKey,
      ingredients:
          ingredientsRaw.map((e) => (e as String).toLowerCase()).toList(),
      vegetableType: _parseVegetableType(vegetableTypeName),
      gradient: gradientRaw.cast<String>(),
    );
  }

  static VegetableType _parseVegetableType(String name) {
    return VegetableType.values.firstWhere(
      (v) => v.name == name,
      orElse: () => VegetableType.broccoli,
    );
  }
}
