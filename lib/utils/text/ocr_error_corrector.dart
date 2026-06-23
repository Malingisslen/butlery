import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// Corrects common OCR errors in Swedish ingredient text.
///
/// Uses a confusion matrix of character substitutions that are common
/// in OCR output (e.g., "rn"->"m", "l"->"1", "o"->"0") and applies
/// corrections only when the corrected word matches a known ingredient
/// or unit within edit distance <= 2.
class OcrErrorCorrector {
  OcrErrorCorrector._();

  /// Common OCR character confusions: {wrong -> correct}.
  /// Ordered by frequency in typical Tesseract/Google Vision output.
  static const _confusions = <String, String>{
    'rn': 'm', // very common: "rnilk" -> "milk", "rnorot" -> "morot"
    'cl': 'd', // "cill" -> "dill"
    'vv': 'w', // rare in Swedish but occurs
    'li': 'h', // "liackad" -> "hackad"
    'ii': 'n', // "iiottar" -> "nottar"
    'nn': 'm', // "nnuskotnot" -> "muskotnot" (less common)
    // OCR.space engine 2 systematically reads the unit "dl" as "di" on
    // cookbook print ("4 di apelsinjuice"). Gate-safe: only fires when the
    // candidate is a known unit — "di"->"dl" sticks, "dill"->"dlll" is rejected.
    'di': 'dl',
  };

  /// Single-character confusions.
  static const _charConfusions = <String, List<String>>{
    '0': ['o', 'ö'], // zero -> lowercase o
    'O': ['0'], // uppercase O -> zero
    'l': ['1', 'i'], // lowercase L -> one/i
    '1': ['l', 'i'], // one -> lowercase L/i
    'I': ['l', '1'], // uppercase I -> lowercase L/one
    '5': ['s', 'S'], // five -> s
    'S': ['5'], // S -> five
    '8': ['B'], // eight -> B
    'B': ['8'], // B -> eight
    '\u00e9': ['e'], // é -> e
    '\u00e8': ['e'], // è -> e
    '\u00ea': ['e'], // ê -> e
    '\u00e1': ['a'], // á -> a
    '\u00e0': ['a'], // à -> a
    '\u00fc': ['u'], // ü -> u
  };

  /// Correct OCR errors in ingredient text.
  ///
  /// Processes each word, attempting corrections only when:
  /// 1. The word is not already a known ingredient/unit
  /// 2. A correction candidate is found within edit distance <= 2
  /// 3. The candidate IS a known ingredient or unit
  static String correctLine(String line) {
    final words = line.split(RegExp(r'\s+'));
    final corrected = <String>[];

    for (final word in words) {
      corrected.add(_correctWord(word));
    }

    return corrected.join(' ');
  }

  /// Correct OCR errors in multiple lines.
  static List<String> correctLines(List<String> lines) {
    return lines.map(correctLine).toList();
  }

  static final _numericPattern = RegExp(
    r'^[\d,./\-\u00BD\u00BC\u00BE\u2153\u2154\u215B\u215C\u215D\u215E]+$',
  );

  static String _correctWord(String word) {
    if (word.isEmpty) return word;

    // Skip numeric tokens (quantities, fractions) -- not ingredient names
    if (_numericPattern.hasMatch(word)) return word;

    final lower = word.toLowerCase();

    // Already known -- no correction needed
    if (_isKnown(lower)) return word;

    // Try multi-character substitutions first (higher confidence)
    for (final entry in _confusions.entries) {
      if (!lower.contains(entry.key)) continue;

      final candidate = lower.replaceFirst(entry.key, entry.value);
      if (_isKnown(candidate)) {
        return _preserveCase(word, candidate);
      }
    }

    // Try single-character substitutions
    for (var i = 0; i < lower.length; i++) {
      final replacements = _charConfusions[word[i]];
      if (replacements == null) continue;

      for (final replacement in replacements) {
        final candidate =
            lower.substring(0, i) + replacement + lower.substring(i + 1);
        if (_isKnown(candidate)) {
          return _preserveCase(word, candidate);
        }
      }
    }

    // Try removing common OCR artifacts (stray punctuation, digit prefixes)
    final cleaned = lower.replaceAll(RegExp(r'^[^a-z\u00E5\u00E4\u00F6]+'), '');
    if (cleaned != lower && cleaned.length >= 3 && _isKnown(cleaned)) {
      return cleaned;
    }

    return word;
  }

  /// Check if word is a known ingredient or unit.
  static bool _isKnown(String lower) {
    return KnownIngredients.isKnown(lower) ||
        UnitDefinitions.isKnownUnit(lower);
  }

  /// Preserve original casing pattern when returning corrected word.
  static String _preserveCase(String original, String corrected) {
    if (original == original.toLowerCase()) return corrected;
    if (original == original.toUpperCase()) return corrected.toUpperCase();
    // Title case
    if (original[0] == original[0].toUpperCase()) {
      return corrected[0].toUpperCase() + corrected.substring(1);
    }
    return corrected;
  }
}
