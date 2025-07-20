// lib/utils/text_utils.dart
// UPPDATERAD för Fas 16 med smart enhetskonvertering

import 'dart:core';

// Import focused components
import 'text/text_formatting.dart';
import 'text/swedish_pluralization.dart';

// Export all classes and functions for backward compatibility
export 'text/text_formatting.dart';
export 'text/unit_converter.dart';
export 'text/ingredient_parser.dart';
export 'text/swedish_pluralization.dart';
export 'text/shopping_list_generator.dart';

// Legacy function exports for backward compatibility
String normalizeText(String input) => TextFormatting.normalizeText(input);
bool isPortionOrTimeLine(String text) => TextFormatting.isPortionOrTimeLine(text);
String formatFractional(double value) => TextFormatting.formatFractional(value);
double parseSwedishNumber(String number) => TextFormatting.parseSwedishNumber(number);
String toSwedishHalfFraction(double value) => TextFormatting.toSwedishHalfFraction(value);

// Legacy constants and functions
const Map<String, String> irregularPlurals = SwedishPluralization.irregularPlurals;
String pluralizeSwedish(String singular, double count) {
  return SwedishPluralization.formatIngredient(singular, count);
}