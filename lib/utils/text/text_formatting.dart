// lib/utils/text/text_formatting.dart

import 'dart:core';

/// TextFormatting - Basic text formatting utilities
///
/// Provides text normalization, formatting, and basic parsing functions.
class TextFormatting {
  /// Tar bort "fancy" Unicode-bokstäver (t.ex. matematiska bold-bokstäver)
  /// genom att mappa dem till vanliga latinska bokstäver. Därefter normaliseras
  /// alla vita tecken till ett enda mellanslag.
  static String normalizeText(String input) {
    final withoutFancyStyle = input.replaceAllMapped(
      RegExp(r'[\u{1D400}-\u{1D7FF}]', unicode: true),
      (m) {
        final original = m[0]!;
        final code = original.codeUnitAt(0);
        final normalizedCode = code - 0x1D400 + 0x41;
        if (normalizedCode < 0 || normalizedCode > 0x10FFFF) {
          return '';
        }
        return String.fromCharCode(normalizedCode);
      },
    );

    return withoutFancyStyle.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Kollar om texten innehåller ett mönster som indikerar portion eller minuter.
  static bool isPortionOrTimeLine(String text) {
    final pattern = RegExp(
      r'^.*\b(\d+(\s*-\s*\d+)?)(\s*)(min|minuter|portioner|port|pers|personer|st|stycken)\b.*$',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  /// Formaterar ett `double`-värde med svenska decimalkomma och maximalt två decimaler.
  static String formatFractional(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    var s = value.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');

    // Konvertera punkt till komma för svenska decimaler
    s = s.replaceAll('.', ',');
    return s;
  }

  /// Parsa svenska nummer (hanterar både . och , som decimaltecken)
  static double parseSwedishNumber(String number) {
    // Ta bort mellanslag och ersätt komma med punkt
    final normalized = number.trim().replaceAll(',', '.');

    try {
      return double.parse(normalized);
    } catch (e) {
      // Om parsing misslyckas, returnera 1 som default
      return 1.0;
    }
  }

  /// Konverterar decimaler med halva delar till en "½"-notation med svensk formatering.
  static String toSwedishHalfFraction(double value) {
    final integerPart = value.truncate();
    final fracPart = value - integerPart;

    // Om fraktionen är ungefär 0.5
    if ((fracPart - 0.5).abs() < 0.001) {
      if (integerPart == 0) {
        return '½';
      }
      return '$integerPart ½';
    }

    // Om fraktionen är ungefär 0.25
    if ((fracPart - 0.25).abs() < 0.001) {
      if (integerPart == 0) {
        return '¼';
      }
      return '$integerPart ¼';
    }

    // Om fraktionen är ungefär 0.75
    if ((fracPart - 0.75).abs() < 0.001) {
      if (integerPart == 0) {
        return '¾';
      }
      return '$integerPart ¾';
    }

    return formatFractional(value);
  }
}

// Export legacy functions for backward compatibility
String normalizeText(String input) => TextFormatting.normalizeText(input);
bool isPortionOrTimeLine(String text) => TextFormatting.isPortionOrTimeLine(text);
String formatFractional(double value) => TextFormatting.formatFractional(value);
double parseSwedishNumber(String number) => TextFormatting.parseSwedishNumber(number);
String toSwedishHalfFraction(double value) => TextFormatting.toSwedishHalfFraction(value);