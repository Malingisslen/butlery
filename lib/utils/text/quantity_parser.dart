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
  /// Returns 1.0 for invalid input.
  static double parse(String qtyString) {
    final trimmed = qtyString.trim();

    // Handle Unicode fractions
    if (trimmed == '½') return 0.5;
    if (trimmed == '¼') return 0.25;
    if (trimmed == '¾') return 0.75;

    // Handle "2 ½" format
    if (trimmed.contains('½')) {
      final parts = trimmed.split('½');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.5;
      }
    }

    // Handle "2 ¼" format
    if (trimmed.contains('¼')) {
      final parts = trimmed.split('¼');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.25;
      }
    }

    // Handle "2 ¾" format
    if (trimmed.contains('¾')) {
      final parts = trimmed.split('¾');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.75;
      }
    }

    // Standard parsing with comma → period for Swedish decimal format
    final normalized = trimmed.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);

    // CRIT-6: Log warning when falling back to 1.0 to help identify parsing issues
    if (parsed == null) {
      AppLogger.warning(
        'CRIT-6: Could not parse quantity "$qtyString", defaulting to 1.0',
        'QuantityParser',
      );
      return 1.0;
    }

    return parsed;
  }
}
