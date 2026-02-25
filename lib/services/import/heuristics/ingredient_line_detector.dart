/// Heuristics for detecting ingredient lines in unstructured text.
class IngredientLineDetector {
  IngredientLineDetector._();

  /// Swedish measurement terms used for ingredient detection.
  static const measurements = [
    'dl',
    'cl',
    'ml',
    'l',
    'msk',
    'tsk',
    'krm',
    'g',
    'gram',
    'kg',
    'st',
    'styck',
    'port',
  ];

  /// Returns true if the line looks like an ingredient line.
  static bool looksLikeIngredient(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.length < 3 || trimmed.length > 100) {
      return false;
    }

    final lower = trimmed.toLowerCase();
    for (final m in measurements) {
      if (RegExp(r'\b' + m + r'\b').hasMatch(lower)) {
        return true;
      }
    }

    // Starts with number or Unicode fraction
    if (RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗]').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Finds indices of lines that look like ingredients.
  static List<int> findIngredientLines(List<String> lines) {
    final indices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      if (looksLikeIngredient(lines[i])) {
        indices.add(i);
      }
    }
    return indices;
  }
}
