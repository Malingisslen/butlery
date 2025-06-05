// lib/utils/text_utils.dart

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

/// Ingrediensparser för att hantera svenska ingrediensformat
class IngredientParser {
  // Regex som hanterar svenska bråk och decimalformat
  static final RegExp quantityRegex = RegExp(
    r'^(\d+(?:[,\.]\d+)?|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾)([A-Za-zÅÄÖåäö]+)?\s*(.+)$',
  );

  // Utökad enhetslista
  static final Set<String> standaloneUnits = {
    'g',
    'kg',
    'hg',
    'dag',
    'dl',
    'l',
    'ml',
    'cl',
    'msk',
    'tsk',
    'krm',
    'burk',
    'pkt',
    'förpackning',
    'påse',
    'ask',
    'flaska',
    'st',
    'bit',
    'skiva',
    'skvätt',
    'nypa',
    'klyfta',
    'sked',
    'glas',
    'kopp',
    'mugg',
    'port',
    'portioner',
    'pers',
    'personer',
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
          return ParsedIngredient(
            quantity: quantity,
            unit: tokens[0].toLowerCase(),
            name: rest.substring(tokens[0].length).trim(),
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
      'g',
      'kg',
      'hg',
      'dag',
      'dl',
      'l',
      'ml',
      'cl',
      'msk',
      'tsk',
      'krm',
    };
    return units.contains(word);
  }

  static String _pluralizeWord(String word) {
    final lower = word.toLowerCase();

    // Reguljära regler
    if (lower.endsWith('ning')) {
      return '${word}ar';
    }
    if (lower.endsWith('ling')) {
      return '${word}ar';
    }
    if (lower.endsWith('a')) {
      return '${word.substring(0, word.length - 1)}or';
    }

    // Standard: lägg till 'ar'
    return '${word}ar';
  }

  /// Huvudfunktionen som kombinerar kvantitet och pluraliserad ingrediens
  static String formatIngredient(String ingredientKey, double totalQuantity) {
    final qtyStr = toSwedishHalfFraction(totalQuantity);

    if (totalQuantity == 1.0) {
      return '$qtyStr $ingredientKey';
    }

    // Dela upp i enhet och namn om det finns mellanslag
    final parts = ingredientKey.split(' ');
    if (parts.length > 1 && _isMeasurementUnit(parts[0])) {
      // T.ex. "dl mjölk" -> "2 dl mjölk" (invariant)
      return '$qtyStr $ingredientKey';
    } else {
      // Pluralisera hela nyckeln
      final pluralized = pluralize(ingredientKey, totalQuantity);
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

    // Formatera för visning
    final displayList = <String>[];
    final sortedKeys = groupedIngredients.keys.toList()..sort();

    for (final key in sortedKeys) {
      final totalQuantity = groupedIngredients[key]!;
      final formatted = SwedishPluralization.formatIngredient(
        key,
        totalQuantity,
      );
      displayList.add(formatted);
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
