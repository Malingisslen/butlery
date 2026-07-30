import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// Result of preprocessing with metadata
class PreprocessingResult {
  /// Cleaned text ready for parser
  final String cleaned;

  /// Flags for what was removed/modified
  final bool hadBullet;
  final bool hadApproximation;
  final bool hadRange;
  final bool hadOptionalMarker;
  final bool hadParentheses;
  final bool hadInstruction;

  /// Original input for debugging
  final String original;

  /// Extracted preparation hint from parenthetical content (e.g. "saften" from "(saften)")
  final String? preparationHint;

  /// Substitute ingredients extracted from parenthetical content
  /// (e.g. "kokosmjölk" from "(eller kokosmjölk)")
  final List<String> substitutes;

  /// Range boundaries when input contained a range (e.g. "3-5" → min: 3, max: 5)
  final double? rangeMin;
  final double? rangeMax;

  const PreprocessingResult({
    required this.cleaned,
    this.hadBullet = false,
    this.hadApproximation = false,
    this.hadRange = false,
    this.hadOptionalMarker = false,
    this.hadParentheses = false,
    this.hadInstruction = false,
    required this.original,
    this.preparationHint,
    this.substitutes = const [],
    this.rangeMin,
    this.rangeMax,
  });

  @override
  String toString() {
    final flags = <String>[];
    if (hadBullet) flags.add('bullet');
    if (hadApproximation) flags.add('approximation');
    if (hadRange) flags.add('range');
    if (hadOptionalMarker) flags.add('optional');
    if (hadParentheses) flags.add('parentheses');
    if (hadInstruction) flags.add('instruction');
    if (substitutes.isNotEmpty) flags.add('substitutes: $substitutes');

    return 'PreprocessingResult('
        'original: "$original", '
        'cleaned: "$cleaned"'
        '${flags.isNotEmpty ? ', flags: ${flags.join(", ")}' : ''}'
        ')';
  }
}

/// Preprocesses raw Swedish ingredient text before parsing.
/// Removes approximations ("ca"), normalizes ranges to max value ("2-3" → "3"),
/// removes optional markers ("ev"), instruction phrases ("till formen"), and parentheses.
class IngredientPreprocessor {
  IngredientPreprocessor._();

  static PreprocessingResult preprocess(String rawText) {
    final original = rawText;
    var text = rawText.trim().toLowerCase();

    if (text.isEmpty) {
      return PreprocessingResult(cleaned: '', original: original);
    }

    // Guard against unreasonably long input (real ingredient lines are 10-60 chars)
    if (text.length > 500) {
      text = text.substring(0, 500);
    }

    var hadBullet = false;
    var hadApproximation = false;
    var hadRange = false;
    var hadOptionalMarker = false;
    var hadParentheses = false;
    var hadInstruction = false;

    final result0 = _removeBullets(text);
    text = result0.text;
    hadBullet = result0.modified;

    final result1 = _removeApproximations(text);
    text = result1.text;
    hadApproximation = result1.modified;

    final result2 = _normalizeRanges(text);
    text = result2.text;
    hadRange = result2.modified;
    final rangeMin = result2.min;
    final rangeMax = result2.max;

    final result3 = _removeOptionalMarkers(text);
    text = result3.text;
    hadOptionalMarker = result3.modified;

    final result4 = _removeInstructionPhrases(text);
    text = result4.text;
    hadInstruction = result4.modified;

    final result5 = _removeParentheses(text);
    text = result5.text;
    hadParentheses = result5.modified;
    final preparationHint = result5.hint;
    final substitutes = result5.substitutes;

    text = _normalizeWhitespace(text);

    return PreprocessingResult(
      cleaned: text,
      hadBullet: hadBullet,
      hadApproximation: hadApproximation,
      hadRange: hadRange,
      hadOptionalMarker: hadOptionalMarker,
      hadParentheses: hadParentheses,
      hadInstruction: hadInstruction,
      original: original,
      preparationHint: preparationHint,
      substitutes: substitutes,
      rangeMin: rangeMin,
      rangeMax: rangeMax,
    );
  }

  /// Remove bullet/list markers (• ● - * 1.) from start of line.
  static ({String text, bool modified}) _removeBullets(String text) {
    final bulletPattern = RegExp(
      r'^[\u2022\u25CF\u25CB\u25E6\u25BA\u25AA\u25B8\-\*]\s*|'
      r'^\d+[.)]\s*',
    );

    if (bulletPattern.hasMatch(text)) {
      final result = text.replaceFirst(bulletPattern, '').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  /// [word] escaped and bounded so it can only match as a whole token.
  ///
  /// BUT-1715: the right-hand side must be a LOOKAHEAD, never `\b`. A dotted
  /// abbreviation ends in '.', which is itself a non-word character, so
  /// `\bca\.\b` demanded a word character immediately after the period and
  /// never matched "ca. 2 dl". That silently killed the "dotted forms FIRST"
  /// ordering below — the bare "ca" alternative matched instead and left the
  /// period behind as ". 2 dl". [SwedishWordBoundary] supplies both sides, so
  /// å/ä/ö can't open a phantom boundary either.
  ///
  /// A word that ALREADY ends in punctuation gets no right-hand boundary at
  /// all, and that asymmetry is the point. The trailing '.' is itself the token
  /// terminator, so a lookahead there only asks a second question — "and is the
  /// next character also a non-letter?" — which "ca.3 dl mjölk" answers no. That
  /// is exactly the glued-digit form ASCII `\b` used to handle, so bounding
  /// both sides would have swapped one orphaned period for another rather than
  /// removing the class.
  static String _boundedWord(String word) {
    final escaped = RegExp.escape(word);
    return RegExp('[${SwedishWordBoundary.letters}]\$').hasMatch(word)
        ? SwedishWordBoundary.bounded(escaped)
        : '${SwedishWordBoundary.before}(?:$escaped)';
  }

  /// Remove approximation words (ca, cirka, drygt, knappt, ungefär).
  static ({String text, bool modified}) _removeApproximations(String text) {
    // Dotted forms FIRST to prevent orphaned periods (ca. before ca)
    final approximations = [
      'ca.',
      'cirka.',
      'ungefär.',
      'ca',
      'cirka',
      'drygt',
      'knappt',
      'ungefär',
    ];

    var modified = false;
    var result = text;

    for (final word in approximations) {
      // [_boundedWord] escapes the dotted forms for safe interpolation.
      final pattern = RegExp(_boundedWord(word), caseSensitive: false);
      if (result.contains(pattern)) {
        result = result.replaceAll(pattern, '').trim();
        modified = true;
      }
    }

    return (text: result, modified: modified);
  }

  /// Normalize ranges to maximum value ("3-5" → "5"), preserving min/max.
  static ({String text, bool modified, double? min, double? max})
  _normalizeRanges(String text) {
    var modified = false;
    var result = text;
    double? rangeMin;
    double? rangeMax;

    final pattern1 = RegExp(
      r'(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)\s*-\s*(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)',
    );

    if (pattern1.hasMatch(result)) {
      result = result.replaceAllMapped(pattern1, (match) {
        final minStr = match.group(1)!;
        final maxStr = match.group(2)!;
        rangeMin ??= double.tryParse(minStr.replaceAll(',', '.'));
        rangeMax ??= double.tryParse(maxStr.replaceAll(',', '.'));
        modified = true;
        return maxStr;
      });
    }

    final pattern2 = RegExp(r'(\d+)-(\d+)');

    if (!modified && pattern2.hasMatch(result)) {
      result = result.replaceAllMapped(pattern2, (match) {
        final minStr = match.group(1)!;
        final maxStr = match.group(2)!;
        rangeMin ??= double.tryParse(minStr);
        rangeMax ??= double.tryParse(maxStr);
        modified = true;
        return maxStr;
      });
    }

    return (text: result, modified: modified, min: rangeMin, max: rangeMax);
  }

  /// Remove optional markers (ev, eventuellt, valfritt).
  static ({String text, bool modified}) _removeOptionalMarkers(String text) {
    // Dotted forms first to prevent orphaned periods
    final optionals = [
      'ev.',
      'ev',
      'eventuellt',
      'valfritt',
      'valfri',
    ];

    var modified = false;
    var result = text;

    for (final word in optionals) {
      final pattern = RegExp(_boundedWord(word), caseSensitive: false);
      if (result.contains(pattern)) {
        result = result.replaceAll(pattern, '').trim();
        modified = true;
      }
    }

    return (text: result, modified: modified);
  }

  /// Remove "till [noun]" instruction phrases ("smör till formen" → "smör").
  static ({String text, bool modified}) _removeInstructionPhrases(String text) {
    // Non-greedy: stop at comma/semicolon to preserve subsequent ingredients
    final pattern = RegExp(r'\s+till\s+\w+[^,;]*', caseSensitive: false);

    if (text.contains(pattern)) {
      final result = text.replaceAll(pattern, '').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  // Swedish phrases that indicate a substitute ingredient inside parentheses
  static final _substitutionPatterns = [
    RegExp(r'^eller\s+(.+)$', caseSensitive: false),
    RegExp(r'^kan\s+bytas\s+(?:ut\s+)?mot\s+(.+)$', caseSensitive: false),
    RegExp(r'^alternativt\s+(.+)$', caseSensitive: false),
    RegExp(r'^(.+?)\s+(?:funkar|fungerar)\s+också$', caseSensitive: false),
    RegExp(r'^(.+?)\s+istället$', caseSensitive: false),
    RegExp(r'^ersätt\s+med\s+(.+)$', caseSensitive: false),
    RegExp(r'^kan\s+ersättas\s+med\s+(.+)$', caseSensitive: false),
    RegExp(r'^(?:t\.?\s*ex\.?|till\s+exempel)\s+(.+)$', caseSensitive: false),
  ];

  /// Remove all parenthetical content ("lime (saften)" → "lime").
  /// Extracts first non-substitution parenthetical as preparation hint,
  /// and detects Swedish substitution phrases as substitute ingredients.
  static ({String text, bool modified, String? hint, List<String> substitutes})
  _removeParentheses(String text) {
    final pattern = RegExp(r'\s*\(([^)]*)\)\s*');
    String? hint;
    final substitutes = <String>[];

    if (!pattern.hasMatch(text)) {
      return (text: text, modified: false, hint: null, substitutes: const []);
    }

    for (final match in pattern.allMatches(text)) {
      final content = match.group(1)?.trim();
      if (content == null || content.isEmpty) continue;

      bool isSubstitution = false;
      for (final subPattern in _substitutionPatterns) {
        final subMatch = subPattern.firstMatch(content);
        if (subMatch != null) {
          substitutes.add(subMatch.group(1)!.trim());
          isSubstitution = true;
          break;
        }
      }

      if (!isSubstitution) {
        hint ??= content;
      }
    }

    final result = text.replaceAll(pattern, ' ').trim();
    return (text: result, modified: true, hint: hint, substitutes: substitutes);
  }

  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<PreprocessingResult> preprocessMany(List<String> ingredients) {
    return ingredients.map((i) => preprocess(i)).toList();
  }
}
