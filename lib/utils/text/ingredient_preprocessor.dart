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

  const PreprocessingResult({
    required this.cleaned,
    this.hadBullet = false,
    this.hadApproximation = false,
    this.hadRange = false,
    this.hadOptionalMarker = false,
    this.hadParentheses = false,
    this.hadInstruction = false,
    required this.original,
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

    final result3 = _removeOptionalMarkers(text);
    text = result3.text;
    hadOptionalMarker = result3.modified;

    final result4 = _removeInstructionPhrases(text);
    text = result4.text;
    hadInstruction = result4.modified;

    final result5 = _removeParentheses(text);
    text = result5.text;
    hadParentheses = result5.modified;

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
    final approximations = [
      'ca',
      'ca.',
      'cirka',
      'cirka.',
      'drygt',
      'knappt',
      'ungefär',
      'ungefär.',
    ];

    var modified = false;
    var result = text;

    for (final word in approximations) {
      // Match word boundary to avoid partial matches
      final pattern = RegExp('\\b$word\\b', caseSensitive: false);
      if (result.contains(pattern)) {
        result = result.replaceAll(pattern, '').trim();
        modified = true;
      }
    }

    return (text: result, modified: modified);
  }

  /// Normalize ranges to maximum value ("3-5" → "5").
  static ({String text, bool modified}) _normalizeRanges(String text) {
    var modified = false;
    var result = text;

    final pattern1 = RegExp(
        r'(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)\s*-\s*(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)');

    if (pattern1.hasMatch(result)) {
      result = result.replaceAllMapped(pattern1, (match) {
        final maxValue = match.group(2)!;
        modified = true;
        return maxValue;
      });
    }

    final pattern2 = RegExp(r'(\d+)-(\d+)');

    if (pattern2.hasMatch(result)) {
      result = result.replaceAllMapped(pattern2, (match) {
        final maxValue = match.group(2)!;
        modified = true;
        return maxValue;
      });
    }

    return (text: result, modified: modified);
  }

  /// Remove optional markers (ev, eventuellt, valfritt).
  static ({String text, bool modified}) _removeOptionalMarkers(String text) {
    final optionals = [
      'ev',
      'ev.',
      'eventuellt',
      'valfritt',
      'valfri',
    ];

    var modified = false;
    var result = text;

    for (final word in optionals) {
      final pattern = RegExp('\\b$word\\b', caseSensitive: false);
      if (result.contains(pattern)) {
        result = result.replaceAll(pattern, '').trim();
        modified = true;
      }
    }

    return (text: result, modified: modified);
  }

  /// Remove "till [noun]" instruction phrases ("smör till formen" → "smör").
  static ({String text, bool modified}) _removeInstructionPhrases(String text) {
    final pattern = RegExp(r'\s+till\s+\w+.*', caseSensitive: false);

    if (text.contains(pattern)) {
      final result = text.replaceAll(pattern, '').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  /// Remove all parenthetical content ("lime (saften)" → "lime").
  static ({String text, bool modified}) _removeParentheses(String text) {
    final pattern = RegExp(r'\s*\([^)]*\)\s*');

    if (text.contains(pattern)) {
      final result = text.replaceAll(pattern, ' ').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<PreprocessingResult> preprocessMany(List<String> ingredients) {
    return ingredients.map((i) => preprocess(i)).toList();
  }
}
