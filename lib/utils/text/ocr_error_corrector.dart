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
  static const _confusions = <String, String>{
    'rn': 'm', // very common: "rnilk" -> "milk", "rnorot" -> "morot"
    'cl': 'd', // "cill" -> "dill"
    'vv': 'w', // rare in Swedish but occurs
    'li': 'h', // "liackad" -> "hackad"
    'ii': 'n', // "iiottar" -> "nottar"
    'nn': 'm', // "nnuskotnot" -> "muskotnot" (less common)
    // "4 di apelsinjuice" is the unit "dl". Gate-safe: only fires when the
    // candidate is a known unit — "di"->"dl" sticks, "dill"->"dlll" is rejected.
    'di': 'dl',
  };

  /// What a reader prints for a letter it could not make out: the dotless i,
  /// an l read as i, a v read as u, and a Swedish vowel missing its marks or
  /// carrying the wrong ones. A word is only changed when exactly one of these
  /// single swaps lands on a known ingredient, and never a short word, where
  /// one swap too easily reaches another real word.
  static const _lookAlikes = <String, List<String>>{
    '\u0131': ['i'],
    'i': ['l'],
    'u': ['v'],
    '\u00fc': ['\u00e4', '\u00f6'],
    'a': ['\u00e5', '\u00e4'],
    'o': ['\u00f6', '\u00e5'],
    '\u0103': ['\u00e5', '\u00e4'],
    '\u0105': ['\u00e4', '\u00e5'],
    '\u00e2': ['\u00e5', '\u00e4'],
    '\u00e4': ['\u00e5'],
  };
  static const _minLookAlikeLength = 5;

  /// Real words one look-alike swap away from an ingredient ("plättar",
  /// "långa"); the swap would turn a correct word into the wrong one.
  static const _realWords = {'platt', 'plattar', 'langa'};

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
    '|': ['l'], // a pipe for the l of "dl" on a phone screenshot
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
    // Printed "2½" survives OCR as "21/2": the whole number and the fraction
    // run together. Only the leading amount is read this way.
    final words = line
        .replaceFirst(_strayBeforeFraction, '')
        .replaceFirstMapped(_percentAsHalf, (m) => '${m[1]}½')
        .replaceFirst(_strayOne, '1')
        .replaceFirst(_doubledLitre, '1 l ')
        .replaceFirstMapped(_gluedMixedFraction, (m) => '${m[1]} ${m[2]}')
        .split(RegExp(r'\s+'));
    // A bare "i" ahead of a known ingredient is the digit 1 ("i morot"); ahead
    // of anything else it can be the preposition of a sub-heading ("I botten").
    if (words.length > 1 &&
        (words.first == 'i' || words.first == 'I') &&
        KnownIngredients.isKnown(words[1].toLowerCase())) {
      words[0] = '1';
    }
    final corrected = <String>[];

    for (var w = 0; w < words.length; w++) {
      final word = words[w];
      final isLast = w == words.length - 1;
      // A lone "d" after an amount is a "dl" whose l the reader lost; no
      // Swedish unit is spelled "d".
      if (word == 'd' &&
          corrected.isNotEmpty &&
          _numericPattern.hasMatch(corrected.last)) {
        corrected.add('dl');
        continue;
      }
      // "d/" and "al" are what a reader prints for the "dl" after an amount;
      // neither is a Swedish unit, and "al" is only a unit when a word follows.
      if ((word == 'd/' || word == 'al') &&
          corrected.isNotEmpty &&
          _numericPattern.hasMatch(corrected.last) &&
          (word == 'd/' || !isLast)) {
        corrected.add('dl');
        continue;
      }
      // The litre sign read as "i", "|" or "/" after an amount, ahead of the
      // liquid it measures ("½ | gräddfil", "1 ½ / vatten").
      if ((word == 'i' || word == '|' || word == '/') &&
          corrected.isNotEmpty &&
          _numericPattern.hasMatch(corrected.last) &&
          !isLast &&
          _litreAhead.hasMatch(words[w + 1])) {
        corrected.add('l');
        continue;
      }
      corrected.add(_correctWord(word));
    }

    return corrected.join(' ');
  }

  /// Correct OCR errors in multiple lines.
  static List<String> correctLines(List<String> lines) {
    return lines.map(correctLine).toList();
  }

  // The reader prints the half sign as "%" ("% dl", "1% dl") and sometimes
  // prefixes a stray letter ("v½ dl"). Both only count when a measuring unit
  // follows, so "1% mjölk" is left alone.
  static const _unitAhead =
      r'(?=\s+(?:dl|di|d/|d|msk|tsk|krm|l|liter|kg|g|st)(?:\s|$))';
  static final _percentAsHalf = RegExp(
    r'^(\d?)%½?' + _unitAhead,
    caseSensitive: false,
  );
  static final _strayBeforeFraction = RegExp(
    r'^[vV](?=[½¼¾]' + _unitAhead + r')',
    caseSensitive: false,
  );

  // A one read as the letter i or l ("i dl kakao"). Only ahead of a measuring
  // unit, where no Swedish word "i" or "l" can stand.
  static final _strayOne = RegExp(
    r'^[ilI|](?=\s+(?:dl|msk|tsk|krm|kg|g|st|liter)(?:\s|$))',
  );

  // "11 köttbuljong" is "1 l köttbuljong": the unit's l printed as a second 1.
  static final _doubledLitre = RegExp(
    r'^11\s+(?=(?:vatten|mjölk|grädde|[a-zåäö]*buljong|[a-zåäö]*fond|vin)(?:\s|$))',
  );
  static final _litreAhead = RegExp(
    r'^(?:vatten|mjölk|grädde|gräddfil|filmjölk|yoghurt|[a-zåäö]*buljong|[a-zåäö]*fond|vin|olja)(?:\s|$)',
    caseSensitive: false,
  );

  static final _gluedMixedFraction = RegExp(r'^(\d)([13]/[248])(?=\s)');

  static final _numericPattern = RegExp(
    r'^[\d,./\-\u00BD\u00BC\u00BE\u2153\u2154\u215B\u215C\u215D\u215E]+$',
  );

  static String _correctWord(String word) {
    if (word.isEmpty) return word;
    // A pipe on its own is a separator, never the l of a unit.
    if (word == '|') return word;

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

    final restored = _restoreLookAlike(lower);
    if (restored != null) return _preserveCase(word, restored);

    // Try removing common OCR artifacts (stray punctuation, digit prefixes)
    final cleaned = lower.replaceAll(RegExp(r'^[^a-z\u00E5\u00E4\u00F6]+'), '');
    if (cleaned != lower && cleaned.length >= 3 && _isKnown(cleaned)) {
      return cleaned;
    }

    return word;
  }

  static String? _restoreLookAlike(String lower) {
    if (lower.length < _minLookAlikeLength || _realWords.contains(lower)) {
      return null;
    }
    String? found;
    for (var i = 0; i < lower.length; i++) {
      final replacements = _lookAlikes[lower[i]];
      if (replacements == null) continue;
      for (final replacement in replacements) {
        final candidate =
            lower.substring(0, i) + replacement + lower.substring(i + 1);
        if (!_isKnown(candidate)) continue;
        if (found != null && found != candidate) return null;
        found = candidate;
      }
    }
    return found;
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
