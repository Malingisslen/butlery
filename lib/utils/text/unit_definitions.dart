/// Comprehensive measurement unit definitions for Swedish and American cooking systems.
/// Provides unit recognition for ingredient parsing.
class UnitDefinitions {
  UnitDefinitions._();

  /// Comprehensive measurement unit recognition supporting Swedish and American cooking systems.
  /// Organized by category for optimal recognition and conversion accuracy.
  ///
  /// **Swedish Measurements:**
  /// - Weight: g, kg, hg, dag, mg
  /// - Volume: dl, l, ml, cl
  /// - Cooking: msk (matsked), tsk (tesked), krm (kryddmått)
  /// - Packaging: burk, pkt, förpackning, påse, ask, flaska
  /// - Counting: st, bit, skiva, klyfta, port, etc.
  ///
  /// **American Measurements:**
  /// - Volume: cup, fl oz, tbsp, tsp, pint, quart, gallon
  /// - Weight: lb, oz, pound, ounce
  static const Set<String> standaloneUnits = {
    // Swedish units
    'g', 'kg', 'hg', 'dag', 'mg',
    'dl', 'l', 'ml', 'cl',
    'msk', 'tsk', 'krm',
    'burk', 'pkt', 'förpackning', 'förpackningar', 'förp', 'påse', 'påsar',
    'ask', 'flaska', 'flaskor',
    'st',
    'styck',
    'stycken',
    'bit',
    'bitar',
    'skiva',
    'skivor',
    'skvätt',
    'nypa',
    'klyfta', 'klyftor', 'sked',
    'glas', 'kopp', 'mugg', 'port', 'portioner', 'pers', 'personer',
    'knippe', 'knippen', 'kruka', 'krukor', 'bunt', 'buntar', 'bunch',
    'blad', 'kvist', 'kvistar', 'tube', 'tub',
    'kasse', 'låda', 'burkar', 'paket',
    // Informal Swedish measures
    'näve', 'nävar', 'gnutta', 'klick', 'droppe', 'droppar',
    // Length measures (for "3 cm ingefära")
    'cm', 'mm',

    // Swedish full-word unit forms
    'matsked', 'matskedar', 'tesked', 'teskedar', 'kryddmått',
    'gram', 'kilo', 'liter', 'deciliter', 'milliliter',

    // American units
    'cup', 'cups', 'oz', 'fl oz', 'floz', 'tbsp', 'tsp',
    'lb', 'lbs', 'pound', 'pounds', 'ounce', 'ounces',
    'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
    'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
  };

  /// Checks if a word is a known measurement unit (case-insensitive).
  static bool isKnownUnit(String word) {
    return standaloneUnits.contains(word.toLowerCase());
  }

  /// Spellings of one unit that are not its short form. A count noun the
  /// list shows in plural ("3 skivor") keeps its spelling here.
  static const Map<String, String> _shortForms = {
    'matsked': 'msk',
    'matskedar': 'msk',
    'tesked': 'tsk',
    'teskedar': 'tsk',
    'kryddmått': 'krm',
    'gram': 'g',
    'kilo': 'kg',
    'liter': 'l',
    'deciliter': 'dl',
    'milliliter': 'ml',
    'styck': 'st',
    'stycken': 'st',
    'förpackning': 'förp',
    'förpackningar': 'förp',
    'paket': 'pkt',
    'påsar': 'påse',
    'flaskor': 'flaska',
    'burkar': 'burk',
    'bitar': 'bit',
    'klyftor': 'klyfta',
    'tub': 'tube',
    'cups': 'cup',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'lbs': 'lb',
    'pound': 'lb',
    'pounds': 'lb',
    'ounce': 'oz',
    'ounces': 'oz',
    'floz': 'fl oz',
    'pints': 'pint',
    'quarts': 'quart',
    'gallons': 'gallon',
  };

  /// The one spelling a unit is stored, summed and shown under: "Matsked"
  /// and "msk" are the same unit. An unknown unit comes back lowercased.
  static String canonical(String unit) {
    final lower = unit.toLowerCase().trim();
    return _shortForms[lower] ?? lower;
  }

  /// Multiplier to the family's base unit, and that base unit, for units
  /// that convert (volume to ml, weight to g). Spoons use their standard ml
  /// equivalence.
  static const Map<String, (double, String)> _baseFactors = {
    'l': (1000.0, 'ml'),
    'dl': (100.0, 'ml'),
    'cl': (10.0, 'ml'),
    'ml': (1.0, 'ml'),
    'msk': (15.0, 'ml'),
    'tsk': (5.0, 'ml'),
    'krm': (1.0, 'ml'),
    'kg': (1000.0, 'g'),
    'hg': (100.0, 'g'),
    'g': (1.0, 'g'),
    'mg': (0.001, 'g'),
  };

  /// Null for a unit with no convertible family ("st", "klyfta", unknown).
  static (double, String)? baseFactor(String unit) =>
      _baseFactors[canonical(unit)];
}
