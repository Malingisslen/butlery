// lib/utils/text_utils.dart
// UPPDATERAD för Fas 16 med smart enhetskonvertering

import 'dart:core';

/// Tar bort "fancy" Unicode-bokstäver (t.ex. matematiska bold-bokstäver)
/// genom att mappa dem till vanliga latinska bokstäver. Därefter normaliseras
/// alla vita tecken till ett enda mellanslag.
String normalizeText(String input) {
  final withoutFancyStyle = input.replaceAllMapped(
    RegExp(r'[\u{1D400}-\u{1D7FF}]', unicode: true),
    (m) {
      final original = m[0]!;
      final code = original.codeUnitAt(0);
      final normalizedCode = code - 0x1D400 + 0x41;
      if (normalizedCode < 0 || normalizedCode > 0x10FFFF) {
        return '';
      }
      return String.fromCharCode(normalizedCode);
    },
  );

  return withoutFancyStyle.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Kollar om texten innehåller ett mönster som indikerar portion eller minuter.
bool isPortionOrTimeLine(String text) {
  final pattern = RegExp(
    r'^.*\b(\d+(\s*-\s*\d+)?)(\s*)(min|minuter|portioner|port|pers|personer|st|stycken)\b.*$',
    caseSensitive: false,
  );
  return pattern.hasMatch(text);
}

/// Formaterar ett `double`-värde med svenska decimalkomma och maximalt två decimaler.
String formatFractional(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  var s = value.toStringAsFixed(2);
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');

  // Konvertera punkt till komma för svenska decimaler
  s = s.replaceAll('.', ',');
  return s;
}

/// Parsa svenska nummer (hanterar både . och , som decimaltecken)
double parseSwedishNumber(String number) {
  // Ta bort mellanslag och ersätt komma med punkt
  final normalized = number.trim().replaceAll(',', '.');

  try {
    return double.parse(normalized);
  } catch (e) {
    // Om parsing misslyckas, returnera 1 som default
    return 1.0;
  }
}

/// Konverterar decimaler med halva delar till en "½"-notation med svensk formatering.
String toSwedishHalfFraction(double value) {
  final integerPart = value.truncate();
  final fracPart = value - integerPart;

  // Om fraktionen är ungefär 0.5
  if ((fracPart - 0.5).abs() < 0.001) {
    if (integerPart == 0) {
      return '½';
    }
    return '$integerPart ½';
  }

  // Om fraktionen är ungefär 0.25
  if ((fracPart - 0.25).abs() < 0.001) {
    if (integerPart == 0) {
      return '¼';
    }
    return '$integerPart ¼';
  }

  // Om fraktionen är ungefär 0.75
  if ((fracPart - 0.75).abs() < 0.001) {
    if (integerPart == 0) {
      return '¾';
    }
    return '$integerPart ¾';
  }

  return formatFractional(value);
}

/// NY KLASS för smart enhetskonvertering (Fas 16)
class SmartUnitConverter {
  /// Konverterar enheter till mer läsbara format när det är vettigt
  /// Exempel: 15 dl → 1,5 liter, 1200 g → 1,2 kg
  static ConvertedMeasurement convertToReadableUnit(
    double quantity,
    String unit,
  ) {
    final lowerUnit = unit.toLowerCase();

    switch (lowerUnit) {
      // AMERIKANSKA ENHETER → SVENSKA ENHETER

      // Volym: amerikanska → svenska
      case 'cup':
      case 'cups':
        return ConvertedMeasurement(quantity * 2.37, 'dl'); // 1 cup ≈ 2.37 dl

      case 'fl oz':
      case 'floz':
      case 'oz': // fluid ounce
        if (quantity >= 3.4) {
          // 3.4 fl oz ≈ 1 dl
          return ConvertedMeasurement(quantity / 3.4, 'dl');
        } else {
          return ConvertedMeasurement(
            quantity * 29.6,
            'ml',
          ); // 1 fl oz ≈ 29.6 ml
        }

      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        return ConvertedMeasurement(
          quantity * 0.89,
          'msk',
        ); // 1 tbsp ≈ 0.89 msk

      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return ConvertedMeasurement(quantity * 0.84, 'tsk'); // 1 tsp ≈ 0.84 tsk

      case 'pint':
      case 'pints':
        return ConvertedMeasurement(quantity * 4.73, 'dl'); // 1 pint ≈ 4.73 dl

      case 'quart':
      case 'quarts':
        return ConvertedMeasurement(quantity * 9.46, 'dl'); // 1 quart ≈ 9.46 dl

      case 'gallon':
      case 'gallons':
        return ConvertedMeasurement(quantity * 3.79, 'l'); // 1 gallon ≈ 3.79 l

      // Vikt: amerikanska → svenska
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return ConvertedMeasurement(quantity * 454, 'g'); // 1 lb ≈ 454 g

      case 'ounce':
      case 'ounces':
        return ConvertedMeasurement(quantity * 28.3, 'g'); // 1 oz ≈ 28.3 g

      // SVENSKA ENHETER (befintliga konverteringar)

      // Volym: ml → cl → dl → liter
      case 'ml':
        if (quantity >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'l');
        } else if (quantity >= 100) {
          return ConvertedMeasurement(quantity / 100, 'dl');
        } else if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'cl');
        }
        break;

      case 'cl':
        if (quantity >= 100) {
          return ConvertedMeasurement(quantity / 100, 'l');
        } else if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'dl');
        }
        break;

      case 'dl':
        if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'l');
        }
        break;

      // Vikt: g → kg
      case 'g':
        if (quantity >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'kg');
        }
        break;

      case 'mg':
        if (quantity >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'g');
        }
        break;

      // Teskedar/matskedar → dl (ungefärliga konverteringar)
      case 'krm':
        if (quantity >= 5) {
          // 5 krm ≈ 1 tsk
          return ConvertedMeasurement(quantity / 5, 'tsk');
        }
        break;

      case 'tsk':
        if (quantity >= 3) {
          // 3 tsk = 1 msk
          return ConvertedMeasurement(quantity / 3, 'msk');
        } else if (quantity >= 15) {
          // 15 tsk ≈ 1 dl (fallback för stora mängder)
          return ConvertedMeasurement(quantity / 15, 'dl');
        }
        break;

      case 'msk':
        if (quantity >= 5) {
          // 5 msk ≈ 1 dl
          return ConvertedMeasurement(quantity / 5, 'dl');
        }
        break;
    }

    // Ingen konvertering gjord
    return ConvertedMeasurement(quantity, unit);
  }

  /// Kontrollerar om en konvertering förbättrar läsbarheten
  static bool shouldConvert(double quantity, String unit) {
    final converted = convertToReadableUnit(quantity, unit);

    // Konvertera om enheten faktiskt ändrades
    if (converted.unit != unit) {
      // AMERIKANSKA → SVENSKA: konvertera ALLTID
      final americanUnits = {
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

      if (americanUnits.contains(unit.toLowerCase())) {
        return true; // Konvertera alltid amerikanska enheter till svenska
      }

      // SVENSKA ENHETER: befintliga regler
      // För volym: konvertera alltid om vi går från dl till liter
      if (unit.toLowerCase() == 'dl' && converted.unit == 'l') {
        return true;
      }

      // För vikt: konvertera alltid om vi går från g till kg
      if (unit.toLowerCase() == 'g' && converted.unit == 'kg') {
        return true;
      }

      // För små enheter: konvertera alltid uppåt
      if (unit.toLowerCase() == 'krm' && converted.unit == 'tsk') {
        return true;
      }

      if (unit.toLowerCase() == 'tsk' &&
          (converted.unit == 'msk' || converted.unit == 'dl')) {
        return true;
      }

      if (unit.toLowerCase() == 'msk' && converted.unit == 'dl') {
        return true;
      }

      // För andra konverteringar: kolla om det blir mer läsbart
      final originalDecimals = _countDecimals(quantity);
      final convertedDecimals = _countDecimals(converted.quantity);

      return convertedDecimals <= originalDecimals ||
          converted.quantity.round() == converted.quantity;
    }

    return false;
  }

  static int _countDecimals(double value) {
    final str = value.toString();
    if (str.contains('.')) {
      return str.split('.')[1].length;
    }
    return 0;
  }
}

class ConvertedMeasurement {
  final double quantity;
  final String unit;

  ConvertedMeasurement(this.quantity, this.unit);

  @override
  String toString() => '${toSwedishHalfFraction(quantity)} $unit';
}

/// Ingrediensparser för att hantera svenska ingrediensformat
/// UPPDATERAD för Fas 16 med smart enhetskonvertering
class IngredientParser {
  // Regex som hanterar svenska bråk och decimalformat
  static final RegExp quantityRegex = RegExp(
    r'^(\d+(?:[,\.]\d+)?|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾)([A-Za-zÅÄÖåäö]+)?\s*(.+)$',
  );

  // Utökad enhetslista med amerikanska enheter
  static final Set<String> standaloneUnits = {
    // Svenska enheter
    'g', 'kg', 'hg', 'dag', 'mg',
    'dl', 'l', 'ml', 'cl',
    'msk', 'tsk', 'krm',
    'burk', 'pkt', 'förpackning', 'påse', 'ask', 'flaska',
    'st', 'bit', 'skiva', 'skvätt', 'nypa', 'klyfta', 'sked',
    'glas', 'kopp', 'mugg', 'port', 'portioner', 'pers', 'personer',
    'knippe',
    'bunch',
    'blad',
    'kvist',
    'tube',
    'tub',
    'kasse',
    'låda',
    'burkar',
    'paket',

    // Amerikanska enheter
    'cup', 'cups', 'oz', 'fl oz', 'floz', 'tbsp', 'tsp',
    'lb', 'lbs', 'pound', 'pounds', 'ounce', 'ounces',
    'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
    'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
  };

  static double parseQuantity(String qtyString) {
    final trimmed = qtyString.trim();

    // Hantera svenska bråk
    if (trimmed == '½') return 0.5;
    if (trimmed == '¼') return 0.25;
    if (trimmed == '¾') return 0.75;

    // Hantera "2 ½" format
    if (trimmed.contains('½')) {
      final parts = trimmed.split('½');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.5;
      }
    }

    // Hantera "2 ¼" format
    if (trimmed.contains('¼')) {
      final parts = trimmed.split('¼');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.25;
      }
    }

    // Hantera "2 ¾" format
    if (trimmed.contains('¾')) {
      final parts = trimmed.split('¾');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.75;
      }
    }

    // Standardparsing med komma -> punkt för Dart
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 1.0;
  }

  static ParsedIngredient parseIngredient(String rawIngredient) {
    final ingredient = rawIngredient.trim();

    if (ingredient.isEmpty) {
      return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
    }

    // FÖRBÄTTRAD: Försök hitta enheter direkt först
    final words = ingredient.toLowerCase().split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i++) {
      if (standaloneUnits.contains(words[i])) {
        // Hitta quantity före enheten
        final beforeUnit = words.take(i);
        final afterUnit = words.skip(i + 1);

        double quantity = 1.0;
        if (beforeUnit.isNotEmpty) {
          final qtyStr = beforeUnit.join(' ');
          quantity = parseQuantity(qtyStr);
        }

        final result = ParsedIngredient(
          quantity: quantity,
          unit: words[i],
          name: afterUnit.join(' '),
        );
        return result;
      }
    }

    // Fallback till original regex parsing
    final match = quantityRegex.firstMatch(ingredient);

    if (match != null) {
      final qtyString = match.group(1)!;
      final attachedUnit = match.group(2);
      final rest = match.group(3)!.trim();

      final quantity = parseQuantity(qtyString);

      if (attachedUnit != null && attachedUnit.isNotEmpty) {
        // Enhet fäst på siffran (t.ex. "400g")
        return ParsedIngredient(
          quantity: quantity,
          unit: attachedUnit.toLowerCase(),
          name: rest,
        );
      } else {
        // Kolla om enheten är fristående
        final tokens = rest.split(RegExp(r'\s+'));
        if (tokens.isNotEmpty &&
            standaloneUnits.contains(tokens[0].toLowerCase())) {
          final unitName = rest.substring(tokens[0].length).trim();
          return ParsedIngredient(
            quantity: quantity,
            unit: tokens[0].toLowerCase(),
            name: unitName,
          );
        } else {
          return ParsedIngredient(quantity: quantity, unit: '', name: rest);
        }
      }
    }

    // Ingen kvantitet hittad - kolla om det börjar med enhet
    final tokens = ingredient.split(RegExp(r'\s+'));
    if (tokens.isNotEmpty &&
        standaloneUnits.contains(tokens[0].toLowerCase())) {
      return ParsedIngredient(
        quantity: 1.0,
        unit: tokens[0].toLowerCase(),
        name: ingredient.substring(tokens[0].length).trim(),
      );
    }

    return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
  }

  /// NY METOD för Fas 16: Skala och formatera ingrediens med smart enhetskonvertering
  static String scaleAndFormatIngredient(
    String rawIngredient,
    double scaleFactor,
  ) {
    if (rawIngredient.trim().isEmpty || scaleFactor <= 0) {
      return rawIngredient;
    }

    final parsed = parseIngredient(rawIngredient);

    // Om ingen kvantitet hittades, returnera oförändrad
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == rawIngredient) {
      return rawIngredient;
    }

    // Skala kvantiteten
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Försök smart enhetskonvertering
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(scaledQuantity, parsed.unit)) {
      final converted = SmartUnitConverter.convertToReadableUnit(
        scaledQuantity,
        parsed.unit,
      );
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    // Formatera med svenska bråk och enheter
    final formattedQuantity = toSwedishHalfFraction(finalQuantity);

    // Bygg ihop igen
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Använd pluralisering för ingredienser utan enhet
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}

class ParsedIngredient {
  final double quantity;
  final String unit;
  final String name;

  ParsedIngredient({
    required this.quantity,
    required this.unit,
    required this.name,
  });

  String get key => unit.isEmpty ? name : '$unit $name';
}

/// Förbättrad pluralhantering för svenska
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
      if (_isMeasurementUnit(firstWord.toLowerCase())) {
        return singular; // Behåll oförändrat för måttenheter
      } else {
        final firstPlural = _pluralizeWord(firstWord);
        return '$firstPlural $rest';
      }
    }

    return _pluralizeWord(singular);
  }

  static bool _isMeasurementUnit(String word) {
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
    final qtyStr = toSwedishHalfFraction(totalQuantity);

    // Om kvantitet är 1, visa singular
    if (totalQuantity == 1.0) {
      return '$qtyStr $ingredientKey';
    }

    // Dela upp i enhet och namn
    final parts = ingredientKey.split(' ');
    if (parts.length > 1 && _isMeasurementUnit(parts[0])) {
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

/// Förenklad och mer robust inköpslistelogik
class ShoppingListGenerator {
  static List<String> generateShoppingList(Map<String, List<dynamic>> menu) {
    if (menu.isEmpty) return [];

    // Samla alla ingredienser
    final List<String> allIngredients = [];
    for (final recipesInSection in menu.values) {
      for (final recipe in recipesInSection) {
        // Anta att recipe har en ingredients property som är List<String>
        if (recipe is Map && recipe.containsKey('ingredients')) {
          final ingredients = recipe['ingredients'] as List?;
          if (ingredients != null) {
            allIngredients.addAll(ingredients.map((e) => e.toString()));
          }
        } else if (recipe.toString().contains('ingredients')) {
          // Fallback för Recipe objekt
          try {
            final recipeObj = recipe as dynamic;
            final ingredients = recipeObj.ingredients as List<String>?;
            if (ingredients != null) {
              allIngredients.addAll(ingredients);
            }
          } catch (e) {
            // Ignorera fel och fortsätt
          }
        }
      }
    }

    // Gruppera ingredienser
    final Map<String, double> groupedIngredients = {};

    for (final rawIngredient in allIngredients) {
      if (rawIngredient.trim().isEmpty) continue;

      final parsed = IngredientParser.parseIngredient(rawIngredient);

      // Skapa en nyckel baserat på enhet + normaliserat namn
      final normalizedName = SwedishPluralization.normalizeToSingular(
        parsed.name,
      );
      final key =
          parsed.unit.isEmpty
              ? normalizedName
              : '${parsed.unit} $normalizedName';

      // Summera kvantiteter
      groupedIngredients[key] =
          (groupedIngredients[key] ?? 0.0) + parsed.quantity;
    }

    // Formatera för visning med smart enhetskonvertering
    final displayList = <String>[];
    final sortedKeys = groupedIngredients.keys.toList()..sort();

    for (final key in sortedKeys) {
      final totalQuantity = groupedIngredients[key]!;

      // Använd smart enhetskonvertering för inköpslistor
      final parts = key.split(' ');
      if (parts.length > 1 &&
          SwedishPluralization._isMeasurementUnit(parts[0])) {
        final unit = parts[0];
        final name = parts.sublist(1).join(' ');

        if (SmartUnitConverter.shouldConvert(totalQuantity, unit)) {
          final converted = SmartUnitConverter.convertToReadableUnit(
            totalQuantity,
            unit,
          );
          final formatted = SwedishPluralization.formatIngredient(
            '${converted.unit} $name',
            converted.quantity,
          );
          displayList.add(formatted);
        } else {
          final formatted = SwedishPluralization.formatIngredient(
            key,
            totalQuantity,
          );
          displayList.add(formatted);
        }
      } else {
        final formatted = SwedishPluralization.formatIngredient(
          key,
          totalQuantity,
        );
        displayList.add(formatted);
      }
    }

    return displayList;
  }
}

// Gamla funktioner för bakåtkompatibilitet
const Map<String, String> irregularPlurals =
    SwedishPluralization.irregularPlurals;

String pluralizeSwedish(String singular, double count) {
  return SwedishPluralization.formatIngredient(singular, count);
}
