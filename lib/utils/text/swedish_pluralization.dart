// lib/utils/text/swedish_pluralization.dart

import 'text_formatting.dart';

/// SwedishPluralization - Swedish pluralization utilities
///
/// Handles pluralization of Swedish words and ingredients.
class SwedishPluralization {
  // Utökad lista över oregelbundna pluraler och invarianta former
  static const Map<String, String> irregularPlurals = {
    // Vätskemått (invarianta)
    'dl mjölk': 'dl mjölk',
    'l mjölk': 'l mjölk',
    'ml mjölk': 'ml mjölk',
    'cl mjölk': 'cl mjölk',
    'dl grädde': 'dl grädde',
    'l grädde': 'l grädde',
    'dl vatten': 'dl vatten',
    'l vatten': 'l vatten',
    'ml vatten': 'ml vatten',
    'dl buljong': 'dl buljong',
    'l buljong': 'l buljong',
    'dl vin': 'dl vin',
    'cl vin': 'cl vin',

    // Kryddor och pulver (oftast invarianta)
    'msk olja': 'msk olja',
    'tsk salt': 'tsk salt',
    'krm salt': 'krm salt',
    'tsk peppar': 'tsk peppar',
    'krm peppar': 'krm peppar',
    'msk smör': 'msk smör',
    'tsk socker': 'tsk socker',
    'msk socker': 'msk socker',
    'tsk vaniljsocker': 'tsk vaniljsocker',
    'krm kanel': 'krm kanel',
    'tsk kanel': 'tsk kanel',

    // Viktmått för pulver/torrvaror
    'g mjöl': 'g mjöl',
    'kg mjöl': 'kg mjöl',
    'g socker': 'g socker',
    'kg socker': 'kg socker',
    'g salt': 'g salt',
    'g ris': 'g ris',
    'kg ris': 'kg ris',

    // Specialfall för vissa ingredienser (invarianta i plural)
    'ägg': 'ägg',
    'fisk': 'fisk',
    'kött': 'kött',
    'mjöl': 'mjöl',
    'socker': 'socker',
    'ris': 'ris',
    'pasta': 'pasta',
    'bröd': 'bröd',
    'smör': 'smör',
    'grädde': 'grädde',
    'mjölk': 'mjölk',
    'vatten': 'vatten',

    // Vanliga oregelbundna pluraler
    'lök': 'lökar',
    'potatis': 'potatisar',
    'tomat': 'tomater',
    'morot': 'morötter',
    'gurka': 'gurkor',
    'paprika': 'paprikor',
    'citron': 'citroner',
    'lime': 'limefrukter',
    'vitlök': 'vitlökar',
    'champinjon': 'champinjoner',
    'svamp': 'svampar',
    'äpple': 'äpplen',
    'päron': 'päron',
    'banan': 'bananer',
    'apelsin': 'apelsiner',
    'kiwi': 'kiwis',
    'avokado': 'avokados',

    // Fler oregelbundna pluraler
    'lasagneplatt': 'lasagneplattor',
    'lasagneplattor': 'lasagneplattor', // Redan plural
    'krossa': 'krossade',
    'krossad': 'krossade',
    'krossade': 'krossade', // Redan plural
    'burk krossade tomater': 'burkar krossade tomater',
  };

  /// Normaliserar ett ingrediensnamn till sin grundform (singular)
  static String normalizeToSingular(String name) {
    final lower = name.toLowerCase().trim();

    // Kolla först om det är en känd oregelbunden plural (omvänd lookup)
    for (final entry in irregularPlurals.entries) {
      if (entry.value.toLowerCase() == lower) {
        return entry.key;
      }
    }

    // Ta bort vanliga pluralendelser
    if (lower.endsWith('ar') && lower.length > 3) {
      return name.substring(0, name.length - 2);
    }
    if (lower.endsWith('or') && lower.length > 3) {
      return name.substring(0, name.length - 2);
    }
    if (lower.endsWith('er') && lower.length > 3) {
      return name.substring(0, name.length - 2);
    }
    if (lower.endsWith('ingar') && lower.length > 6) {
      return '${name.substring(0, name.length - 5)}ing';
    }
    if (lower.endsWith('ningar') && lower.length > 7) {
      return '${name.substring(0, name.length - 6)}ning';
    }

    return name;
  }

  /// Pluraliserar ett ingrediensnamn
  static String pluralize(String singular, double count) {
    if (count == 1.0) {
      return singular;
    }

    final lower = singular.toLowerCase();

    // Kolla oregelbundna pluraler
    if (irregularPlurals.containsKey(lower)) {
      return irregularPlurals[lower]!;
    }

    // Hantera sammansatta namn (t.ex. "burk tomatsås")
    final parts = singular.split(' ');
    if (parts.length > 1) {
      final firstWord = parts[0];
      final rest = parts.sublist(1).join(' ');

      // Pluralisera bara första ordet om det inte är en måttenhet
      if (isMeasurementUnit(firstWord.toLowerCase())) {
        return singular; // Behåll oförändrat för måttenheter
      } else {
        final firstPlural = _pluralizeWord(firstWord);
        return '$firstPlural $rest';
      }
    }

    return _pluralizeWord(singular);
  }

  static bool isMeasurementUnit(String word) {
    const units = {
      // Svenska enheter
      'g', 'kg', 'hg', 'dag', 'mg',
      'dl', 'l', 'ml', 'cl',
      'msk', 'tsk', 'krm',

      // Amerikanska enheter
      'cup', 'cups', 'oz', 'fl oz', 'floz', 'tbsp', 'tsp',
      'lb', 'lbs', 'pound', 'pounds', 'ounce', 'ounces',
      'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
      'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
    };
    return units.contains(word);
  }

  static String _pluralizeWord(String word) {
    final lower = word.toLowerCase();

    // Specialfall för specifika ord
    final specialCases = {
      'lasagneplatt': 'lasagneplattor',
      'krossade tomat': 'krossade tomater',
      'krossad tomat': 'krossade tomater',
      'lök': 'lökar',
      'potatis': 'potatisar',
      'tomat': 'tomater',
      'morot': 'morötter',
      'gurka': 'gurkor',
      'paprika': 'paprikor',
      'citron': 'citroner',
      'vitlök': 'vitlökar',
      'champinjon': 'champinjoner',
      'svamp': 'svampar',
      'äpple': 'äpplen',
      'banan': 'bananer',
      'apelsin': 'apelsiner',
      'avokado': 'avokados',
      'burk': 'burkar',
      'påse': 'påsar',
      'förpackning': 'förpackningar',
      'flaska': 'flaskor',
      'ask': 'askar',
      'kött': 'kött', // Invariant
      'fisk': 'fisk', // Invariant
      'mjöl': 'mjöl', // Invariant
      'socker': 'socker', // Invariant
      'ris': 'ris', // Invariant
      'pasta': 'pasta', // Invariant
      'bröd': 'bröd', // Invariant
      'smör': 'smör', // Invariant
      'grädde': 'grädde', // Invariant
      'mjölk': 'mjölk', // Invariant
      'vatten': 'vatten', // Invariant
    };

    if (specialCases.containsKey(lower)) {
      // Behåll ursprunglig case-struktur
      final special = specialCases[lower]!;
      if (word[0].toUpperCase() == word[0] && word.toLowerCase() == word) {
        // Första bokstaven stor, resten små
        return special[0].toUpperCase() + special.substring(1);
      }
      return special;
    }

    // Reguljära regler för pluralisering
    if (lower.endsWith('ing')) {
      return '${word}ar';
    }
    if (lower.endsWith('ling')) {
      return '${word}ar';
    }
    if (lower.endsWith('ning')) {
      return '${word}ar';
    }
    if (lower.endsWith('a')) {
      return '${word.substring(0, word.length - 1)}or';
    }
    if (lower.endsWith('e')) {
      return '${word}r';
    }
    if (lower.endsWith('el')) {
      return '${word.substring(0, word.length - 2)}lar';
    }
    if (lower.endsWith('er')) {
      return '${word.substring(0, word.length - 2)}rar';
    }
    if (lower.endsWith('en')) {
      return '${word.substring(0, word.length - 2)}nar';
    }

    // Standard: lägg till 'ar'
    return '${word}ar';
  }

  /// Huvudfunktionen som kombinerar kvantitet och pluraliserad ingrediens
  static String formatIngredient(String ingredientKey, double totalQuantity) {
    final qtyStr = TextFormatting.toSwedishHalfFraction(totalQuantity);

    // Om kvantitet är 1, visa singular
    if (totalQuantity == 1.0) {
      return '$qtyStr $ingredientKey';
    }

    // Dela upp i enhet och namn
    final parts = ingredientKey.split(' ');
    if (parts.length > 1 && isMeasurementUnit(parts[0])) {
      // T.ex. "dl mjölk" -> "2 dl mjölk" (invariant för måttenheter)
      return '$qtyStr $ingredientKey';
    } else {
      // För fristående ingredienser, pluralisera smart
      String pluralized;
      if (ingredientKey.toLowerCase().contains('platt')) {
        pluralized = ingredientKey.replaceAll(
          RegExp(r'platt$', caseSensitive: false),
          'plattor',
        );
      } else {
        pluralized = pluralize(ingredientKey, totalQuantity);
      }
      return '$qtyStr $pluralized';
    }
  }
}

// Export legacy functions for backward compatibility
const Map<String, String> irregularPlurals = SwedishPluralization.irregularPlurals;
String pluralizeSwedish(String singular, double count) {
  return SwedishPluralization.formatIngredient(singular, count);
}