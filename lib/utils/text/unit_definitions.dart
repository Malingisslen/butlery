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
    'burk', 'pkt', 'förpackning', 'förp', 'påse', 'ask', 'flaska',
    'st', 'bit', 'skiva', 'skvätt', 'nypa', 'klyfta', 'sked',
    'glas', 'kopp', 'mugg', 'port', 'portioner', 'pers', 'personer',
    'knippe', 'bunch', 'blad', 'kvist', 'tube', 'tub',
    'kasse', 'låda', 'burkar', 'paket',

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
}
