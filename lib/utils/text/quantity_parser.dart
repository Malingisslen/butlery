import 'package:butlery/core/utils/logger.dart';

/// Utility for parsing quantities including Swedish fractions and ASCII fractions.
class QuantityParser {
  QuantityParser._();

  /// Parses ASCII fractions like "1/2", "3/4", "1 1/2" to decimal numbers.
  /// Returns null if input is not a valid ASCII fraction.
  ///
  /// **Supported Formats:**
  /// - Simple fractions: "1/2" → 0.5, "3/4" → 0.75
  /// - Mixed fractions: "1 1/2" → 1.5, "2 1/4" → 2.25
  ///
  /// Guards against division by zero and invalid formats.
  static double? parseAsciiFraction(String text) {
    final trimmed = text.trim();

    // Handle mixed fractions: "1 1/2" → 1.5
    final mixedPattern = RegExp(r'^(\d+)\s+(\d+)/(\d+)$');
    final mixedMatch = mixedPattern.firstMatch(trimmed);

    if (mixedMatch != null) {
      final whole = int.parse(mixedMatch.group(1)!);
      final numerator = int.parse(mixedMatch.group(2)!);
      final denominator = int.parse(mixedMatch.group(3)!);

      if (denominator == 0) return null;
      return whole + (numerator / denominator);
    }

    // Handle simple fractions: "1/2" → 0.5
    final simplePattern = RegExp(r'^(\d+)/(\d+)$');
    final simpleMatch = simplePattern.firstMatch(trimmed);

    if (simpleMatch != null) {
      final numerator = int.parse(simpleMatch.group(1)!);
      final denominator = int.parse(simpleMatch.group(2)!);

      if (denominator == 0) return null;
      return numerator / denominator;
    }

    return null;
  }

  /// Parses Swedish quantity strings with Unicode fraction and decimal support.
  ///
  /// **Supported Formats:**
  /// - Unicode fractions: "½" → 0.5, "¼" → 0.25, "¾" → 0.75
  /// - Mixed fractions: "2 ½" → 2.5, "1 ¼" → 1.25
  /// - Decimal numbers: "2,5" → 2.5, "3.14" → 3.14
  /// - Whole numbers: "400" → 400.0
  ///
  /// Unicode fraction map covering all common fraction characters.
  static const _unicodeFractions = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1 / 3,
    '⅔': 2 / 3,
    '⅛': 0.125,
    '⅜': 0.375,
    '⅝': 0.625,
    '⅞': 0.875,
    '⅕': 0.2,
    '⅖': 0.4,
    '⅗': 0.6,
  };

  /// Returns true if the string looks like a fraction (Unicode or ASCII).
  static bool isFraction(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Check Unicode fractions
    for (final key in _unicodeFractions.keys) {
      if (trimmed.contains(key)) return true;
    }

    // Check ASCII fractions like "1/2", "3/4", "1 1/2"
    return RegExp(r'^\d+\s*\/\s*\d+$').hasMatch(trimmed) ||
        RegExp(r'^\d+\s+\d+\s*\/\s*\d+$').hasMatch(trimmed);
  }

  /// Returns 1.0 for invalid input.
  static double parse(String qtyString) {
    final trimmed = qtyString.trim();

    // Handle standalone Unicode fractions and "N fraction" mixed formats
    for (final entry in _unicodeFractions.entries) {
      if (trimmed == entry.key) return entry.value;
      if (trimmed.contains(entry.key)) {
        final parts = trimmed.split(entry.key);
        if (parts.length == 2) {
          final whole =
              double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
          return whole + entry.value;
        }
      }
    }

    // Standard parsing with comma → period for Swedish decimal format
    final normalized = trimmed.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);

    if (parsed == null) {
      // Only warn when input contains digits (likely a real parsing issue);
      // non-digit input is expected when text flows through the parser
      if (RegExp(r'\d').hasMatch(qtyString)) {
        AppLogger.warning(
          'Could not parse quantity "$qtyString", defaulting to 1.0',
          'QuantityParser',
        );
      } else {
        AppLogger.debug(
          'Non-numeric input "$qtyString", defaulting to 1.0',
          'QuantityParser',
        );
      }
      return 1.0;
    }

    return parsed;
  }
}
