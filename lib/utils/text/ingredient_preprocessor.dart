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
      // Use RegExp.escape for safe interpolation of dotted forms
      final escaped = RegExp.escape(word);
      final pattern = RegExp('\\b$escaped\\b', caseSensitive: false);
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
        r'(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)\s*-\s*(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)');

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
      final escaped = RegExp.escape(word);
      final pattern = RegExp('\\b$escaped\\b', caseSensitive: false);
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

  /// Remove all parenthetical content ("lime (saften)" → "lime").
  /// Extracts first parenthetical as a preparation hint.
  static ({String text, bool modified, String? hint}) _removeParentheses(
      String text) {
    final pattern = RegExp(r'\s*\(([^)]*)\)\s*');
    String? hint;

    final firstMatch = pattern.firstMatch(text);
    if (firstMatch != null) {
      hint = firstMatch.group(1)?.trim();
      if (hint != null && hint.isEmpty) hint = null;
      final result = text.replaceAll(pattern, ' ').trim();
      return (text: result, modified: true, hint: hint);
    }

    return (text: text, modified: false, hint: null);
  }

  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<PreprocessingResult> preprocessMany(List<String> ingredients) {
    return ingredients.map((i) => preprocess(i)).toList();
  }
}
