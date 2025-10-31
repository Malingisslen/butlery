/// Result of preprocessing with metadata
class PreprocessingResult {
  /// Cleaned text ready for parser
  final String cleaned;

  /// Flags for what was removed/modified
  final bool hadApproximation;
  final bool hadRange;
  final bool hadOptionalMarker;
  final bool hadParentheses;
  final bool hadInstruction;

  /// Original input for debugging
  final String original;

  const PreprocessingResult({
    required this.cleaned,
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

/// MODUL1 Stage 1: Preprocess raw recipe text before parsing
///
/// Cleans raw recipe strings to make them parser-ready.
/// Runs BEFORE IngredientParser to handle real-world Swedish recipe edge cases.
///
/// # What Preprocessing Does
///
/// 1. **Removes approximations**: "ca 300 g" → "300 g"
/// 2. **Normalizes ranges to MAX**: "3 - 5 dl" → "5 dl" ⚠️
/// 3. **Removes optional markers**: "ev majsstärkelse" → "majsstärkelse"
/// 4. **Removes instructions**: "smör till formen" → "smör"
/// 5. **Removes parentheses**: "lime (saften)" → "lime"
/// 6. **Normalizes whitespace**: Multiple spaces, etc.
///
/// # Critical: Range Handling
///
/// **Takes MAXIMUM value from ranges** (user decision):
/// - "3 - 5 st" → "5 st"
/// - "2-3 dl" → "3 dl"
/// - "ca 3 - 5 g" → "5 g"
///
/// Rationale: Better to have too much than too little when shopping.
///
/// # Integration
///
/// ```dart
/// // Step 1: Preprocess
/// final preprocessed = IngredientPreprocessor.preprocess("ca 3 - 5 dl mjölk (kall)");
/// // → PreprocessingResult(cleaned: "5 dl mjölk", ...)
///
/// // Step 2: Parse
/// final parsed = IngredientParser.parseIngredient(preprocessed.cleaned);
/// // → ParsedIngredient(5.0, "dl", "mjölk")
///
/// // Step 3: Normalize
/// final normalized = IngredientNormalizer.normalize(parsed.name);
/// // → NormalizationResult(normalized: "mjölk", ...)
/// ```
///
/// # Real-World Examples (From Test Data)
///
/// ```dart
/// preprocess("ca 300 g nachochips")
/// // → "300 g nachochips"
///
/// preprocess("3 - 5 st hallon")
/// // → "5 st hallon" (MAX value!)
///
/// preprocess("ev majsstärkelse")
/// // → "majsstärkelse"
///
/// preprocess("lime (saften)")
/// // → "lime"
///
/// preprocess("smör till formen")
/// // → "smör"
///
/// preprocess("cirka 2-3 dl mjölk (kall)")
/// // → "3 dl mjölk" (removes "cirka", takes max from "2-3", removes parentheses)
/// ```
///
/// # Version
/// 1.0.0 - Initial implementation based on real test data
class IngredientPreprocessor {
  /// Private constructor to prevent instantiation
  IngredientPreprocessor._();

  /// Preprocess raw recipe text before parsing
  ///
  /// Returns a [PreprocessingResult] with cleaned text and metadata flags.
  static PreprocessingResult preprocess(String rawText) {
    final original = rawText;
    var text = rawText.trim().toLowerCase();

    if (text.isEmpty) {
      return PreprocessingResult(cleaned: '', original: original);
    }

    // Track what was modified
    var hadApproximation = false;
    var hadRange = false;
    var hadOptionalMarker = false;
    var hadParentheses = false;
    var hadInstruction = false;

    // Step 1: Remove approximation words
    final result1 = _removeApproximations(text);
    text = result1.text;
    hadApproximation = result1.modified;

    // Step 2: Normalize ranges to MAXIMUM value
    final result2 = _normalizeRanges(text);
    text = result2.text;
    hadRange = result2.modified;

    // Step 3: Remove optional markers
    final result3 = _removeOptionalMarkers(text);
    text = result3.text;
    hadOptionalMarker = result3.modified;

    // Step 4: Remove "till [noun]" instruction phrases
    final result4 = _removeInstructionPhrases(text);
    text = result4.text;
    hadInstruction = result4.modified;

    // Step 5: Remove all parenthetical content
    final result5 = _removeParentheses(text);
    text = result5.text;
    hadParentheses = result5.modified;

    // Step 6: Final whitespace cleanup
    text = _normalizeWhitespace(text);

    return PreprocessingResult(
      cleaned: text,
      hadApproximation: hadApproximation,
      hadRange: hadRange,
      hadOptionalMarker: hadOptionalMarker,
      hadParentheses: hadParentheses,
      hadInstruction: hadInstruction,
      original: original,
    );
  }

  /// Remove approximation words
  ///
  /// Examples:
  /// - "ca 300 g" → "300 g"
  /// - "cirka 2 dl" → "2 dl"
  /// - "drygt 1 kg" → "1 kg"
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

  /// Normalize ranges to MAXIMUM value
  ///
  /// **CRITICAL: Takes MAXIMUM value from ranges (user decision)**
  ///
  /// Examples:
  /// - "3 - 5 st" → "5 st" (max: 5)
  /// - "2-3 dl" → "3 dl" (max: 3)
  /// - "1 - 2 kg" → "2 kg" (max: 2)
  /// - "2 1/2 - 3 dl" → "3 dl" (max: 3)
  ///
  /// Patterns handled:
  /// - With spaces: "3 - 5"
  /// - Without spaces: "2-3"
  /// - With decimals: "2.5 - 3.5"
  /// - With fractions: "1 1/2 - 2"
  static ({String text, bool modified}) _normalizeRanges(String text) {
    var modified = false;
    var result = text;

    // Pattern 1: With spaces "3 - 5" or with fractions "2 1/2 - 3"
    // Match: number (possibly with fraction) - number
    final pattern1 = RegExp(
        r'(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)\s*-\s*(\d+(?:\s+\d+/\d+)?(?:[,\.]\d+)?)');

    if (pattern1.hasMatch(result)) {
      result = result.replaceAllMapped(pattern1, (match) {
        // Take the SECOND number (maximum)
        final maxValue = match.group(2)!;
        modified = true;
        return maxValue;
      });
    }

    // Pattern 2: Without spaces "2-3" (but not "-3" alone)
    // Must have number before hyphen
    final pattern2 = RegExp(r'(\d+)-(\d+)');

    if (pattern2.hasMatch(result)) {
      result = result.replaceAllMapped(pattern2, (match) {
        // Take the SECOND number (maximum)
        final maxValue = match.group(2)!;
        modified = true;
        return maxValue;
      });
    }

    return (text: result, modified: modified);
  }

  /// Remove optional markers
  ///
  /// Examples:
  /// - "ev majsstärkelse" → "majsstärkelse"
  /// - "eventuellt salt" → "salt"
  /// - "valfritt peppar" → "peppar"
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

  /// Remove "till [noun]" instruction phrases
  ///
  /// Examples:
  /// - "smör till formen" → "smör"
  /// - "ströbröd till formen" → "ströbröd"
  /// - "florsocker till garnering" → "florsocker"
  ///
  /// Pattern: Remove "till" and everything after it
  static ({String text, bool modified}) _removeInstructionPhrases(String text) {
    // Match "till" followed by anything
    final pattern = RegExp(r'\s+till\s+\w+.*', caseSensitive: false);

    if (text.contains(pattern)) {
      final result = text.replaceAll(pattern, '').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  /// Remove all parenthetical content
  ///
  /// Examples:
  /// - "lime (saften)" → "lime"
  /// - "majskorn (à 150 g)" → "majskorn"
  /// - "äpple (halva används i såsen)" → "äpple"
  ///
  /// Removes everything between ( and ), including the parentheses
  static ({String text, bool modified}) _removeParentheses(String text) {
    // Match anything in parentheses
    final pattern = RegExp(r'\s*\([^)]*\)\s*');

    if (text.contains(pattern)) {
      final result = text.replaceAll(pattern, ' ').trim();
      return (text: result, modified: true);
    }

    return (text: text, modified: false);
  }

  /// Normalize whitespace
  ///
  /// - Multiple spaces → single space
  /// - Leading/trailing spaces → removed
  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Batch preprocess multiple ingredients
  static List<PreprocessingResult> preprocessMany(List<String> ingredients) {
    return ingredients.map((i) => preprocess(i)).toList();
  }
}
