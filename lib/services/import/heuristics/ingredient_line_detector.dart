import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// Heuristics for detecting ingredient lines in unstructured text.
///
/// Reached from `url_import_strategy.dart` — the URL-import path. The
/// same-named class at `lib/widgets/import/ingredient_line_detector.dart` is a
/// separate copy with its own vocabulary and is the one the ASSISTED-import
/// path (photo/OCR/text) calls. Fix behaviour in both; see that file's header.
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

  /// One whole-word pattern per unit, compiled once — [looksLikeIngredient]
  /// runs per line of every imported page, and the old inline `RegExp(...)`
  /// rebuilt all thirteen on every call.
  ///
  /// The boundary is [SwedishWordBoundary], not `\b`: Dart's ASCII `\b` treats
  /// å/ä/ö as non-word characters, so it reported a phantom boundary beside
  /// them and the one-letter units matched *inside* ordinary Swedish words —
  /// "kål", "mjöl" and "öl" all satisfied `\bl\b`, "höst" satisfied `\bst\b`.
  /// Every section heading built from such a word was pre-ticked as an
  /// ingredient line during URL import (BUT-1691). The assisted-import path
  /// runs the widgets copy of this class, fixed the same way.
  static final _measurementPatterns = measurements
      .map((m) => SwedishWordBoundary.boundedRegExp(RegExp.escape(m)))
      .toList(growable: false);

  static final _leadingQuantityPattern = RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗]');

  /// Returns true if the line looks like an ingredient line.
  static bool looksLikeIngredient(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.length < 3 || trimmed.length > 100) {
      return false;
    }

    final lower = trimmed.toLowerCase();
    for (final pattern in _measurementPatterns) {
      if (pattern.hasMatch(lower)) {
        return true;
      }
    }

    // Starts with number or Unicode fraction
    if (_leadingQuantityPattern.hasMatch(trimmed)) {
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
