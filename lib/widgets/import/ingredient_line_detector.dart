/// Heuristic detection for ingredient lines in extracted text.
///
/// Uses Swedish measurement patterns and common ingredient formats
/// to identify likely ingredient lines for pre-selection in user-assisted import.
library;

/// Detects likely ingredient lines in extracted text.
class IngredientLineDetector {
  // Swedish measurements (case-insensitive)
  static const _swedishMeasurements = [
    'dl',
    'cl',
    'ml',
    'l',
    'liter',
    'msk',
    'tsk',
    'krm',
    'g',
    'gram',
    'kg',
    'kilo',
    'st',
    'stycken',
    'styck',
    'port',
    'portioner',
    'nypa',
    'nypor',
    'knippe',
    'klyfta',
    'klyftor',
    'skiva',
    'skivor',
    'burk',
    'burkar',
    'paket',
    'pkt',
    'ask',
    'askar',
    'tärning',
    'tärningar',
  ];

  // Common ingredient starters
  static const _ingredientStarters = [
    'ca ',
    'ca. ',
    'cirka ',
    'ungefär ',
    'ev ',
    'ev. ',
    'eventuellt ',
  ];

  // Fraction patterns (½, ¼, ¾, 1/2, 1/4)
  static final _fractionPattern = RegExp(
    r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗]+[/\d]*\s*',
    caseSensitive: false,
  );

  // Number at start of line (e.g., "2 dl", "500 g")
  static final _numberStartPattern = RegExp(
    r'^\d+[\s,.\d]*\s*',
    caseSensitive: false,
  );

  // Lines that are NOT ingredients (headers, instructions, etc.)
  static final _excludePatterns = [
    RegExp(r'^(steg|step)\s*\d', caseSensitive: false),
    RegExp(r'^instruktioner?:?$', caseSensitive: false),
    RegExp(r'^ingredienser?:?$', caseSensitive: false),
    RegExp(r'^tillagning:?$', caseSensitive: false),
    RegExp(r'^gör så här:?$', caseSensitive: false),
    RegExp(r'^\d+\.\s+[A-ZÅÄÖ]', caseSensitive: false), // Numbered instructions
    RegExp(r'^(för|till)\s+\d+\s+(port|pers)', caseSensitive: false),
  ];

  /// Analyze text and return indices of likely ingredient lines.
  ///
  /// [text] - Raw extracted text
  /// Returns list of 0-based line indices that are likely ingredients.
  static List<int> detectIngredientLines(String text) {
    final lines = text.split('\n');
    final ingredientIndices = <int>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (_isLikelyIngredient(line)) {
        ingredientIndices.add(i);
      }
    }

    return ingredientIndices;
  }

  /// Analyze lines and return indices of likely ingredient lines.
  ///
  /// [lines] - List of text lines
  /// Returns list of 0-based line indices that are likely ingredients.
  static List<int> detectFromLines(List<String> lines) {
    final ingredientIndices = <int>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (_isLikelyIngredient(line)) {
        ingredientIndices.add(i);
      }
    }

    return ingredientIndices;
  }

  /// Check if a single line is likely an ingredient.
  static bool _isLikelyIngredient(String line) {
    // Skip empty or very short lines
    if (line.length < 3) return false;

    // Skip very long lines (likely descriptions or instructions)
    if (line.length > 100) return false;

    // Check exclusion patterns first
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(line)) return false;
    }

    final lowerLine = line.toLowerCase();

    // Check for Swedish measurements
    for (final measurement in _swedishMeasurements) {
      // Match whole words only
      final measurementPattern = RegExp(
        r'\b' + RegExp.escape(measurement) + r'\b',
        caseSensitive: false,
      );
      if (measurementPattern.hasMatch(lowerLine)) {
        return true;
      }
    }

    // Check for fraction at start
    if (_fractionPattern.hasMatch(line)) {
      return true;
    }

    // Check for number at start followed by space (e.g., "2 ägg", "500 g mjöl")
    if (_numberStartPattern.hasMatch(line) && line.contains(' ')) {
      // Make sure it's not just a numbered instruction
      if (!RegExp(r'^\d+\.\s').hasMatch(line)) {
        return true;
      }
    }

    // Check for ingredient starters
    for (final starter in _ingredientStarters) {
      if (lowerLine.startsWith(starter)) {
        return true;
      }
    }

    return false;
  }

  /// Get confidence score for a line being an ingredient (0.0 - 1.0).
  static double getConfidence(String line) {
    if (line.trim().length < 3) return 0.0;
    if (line.trim().length > 100) return 0.0;

    double score = 0.0;
    final lowerLine = line.toLowerCase();

    // Check exclusion patterns
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(line)) return 0.0;
    }

    // Measurements are strong indicators
    for (final measurement in _swedishMeasurements) {
      final measurementPattern = RegExp(
        r'\b' + RegExp.escape(measurement) + r'\b',
        caseSensitive: false,
      );
      if (measurementPattern.hasMatch(lowerLine)) {
        score += 0.4;
        break;
      }
    }

    // Number at start
    if (_numberStartPattern.hasMatch(line)) {
      score += 0.3;
    }

    // Fraction at start
    if (_fractionPattern.hasMatch(line)) {
      score += 0.3;
    }

    // Short lines are more likely ingredients
    if (line.length < 50) {
      score += 0.1;
    }

    // Cap at 1.0
    return score.clamp(0.0, 1.0);
  }

  /// Detect instruction lines (lines that are NOT ingredients but have content).
  static List<int> detectInstructionLines(
    List<String> lines, {
    Set<int>? excludeIndices,
  }) {
    final instructionIndices = <int>[];

    for (int i = 0; i < lines.length; i++) {
      // Skip excluded indices (already selected as ingredients)
      if (excludeIndices?.contains(i) ?? false) continue;

      final line = lines[i].trim();

      // Skip empty or very short lines
      if (line.length < 10) continue;

      // Skip lines that look like ingredients
      if (_isLikelyIngredient(line)) continue;

      // Instruction indicators
      final isInstruction =
          line.length > 20 || // Longer lines are likely instructions
          RegExp(r'^\d+[\.\)]\s').hasMatch(line) || // Numbered step
          RegExp(r'^(steg|step)\s*\d', caseSensitive: false).hasMatch(line) ||
          _containsVerb(line);

      if (isInstruction) {
        instructionIndices.add(i);
      }
    }

    return instructionIndices;
  }

  /// Check if line contains cooking verbs (heuristic for instructions).
  static bool _containsVerb(String line) {
    final cookingVerbs = [
      'vispa',
      'rör',
      'blanda',
      'häll',
      'tillsätt',
      'lägg',
      'stek',
      'koka',
      'grädda',
      'baka',
      'fräs',
      'sjud',
      'hacka',
      'skär',
      'skala',
      'dela',
      'ansa',
      'servera',
      'garnera',
      'strö',
      'toppa',
      'låt',
      'ställ',
      'sätt',
      'ta',
      'använd',
      'värm',
      'kyl',
      'frys',
      'tina',
    ];

    final lowerLine = line.toLowerCase();
    for (final verb in cookingVerbs) {
      if (lowerLine.contains(verb)) {
        return true;
      }
    }
    return false;
  }
}
