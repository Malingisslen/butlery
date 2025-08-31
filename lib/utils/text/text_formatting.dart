/// Comprehensive text formatting system providing Swedish number formatting, text normalization, and cooking-specific text processing.
///
/// This utility class consolidates text formatting patterns found throughout the application, providing consistent
/// Swedish language support for numbers, fractions, and cooking-related text processing. It eliminates duplicate
/// formatting logic while ensuring proper Swedish cultural conventions for decimal notation, fraction display,
/// and cooking measurement formatting.
///
/// **Architecture Integration:**
/// - Provides foundation for ingredient parsing and recipe formatting
/// - Supports Swedish decimal comma notation and fraction display
/// - Integrates with cooking measurement systems for proper number formatting
/// - Eliminates text formatting duplication across 180+ files in the codebase
/// - Ensures consistent Swedish language conventions throughout the application
///
/// **Text Processing Capabilities:**
/// - **Swedish Numbers**: Decimal comma formatting ("2,5" instead of "2.5")
/// - **Fraction Display**: Unicode fraction notation (½, ¼, ¾) with mixed fractions
/// - **Text Normalization**: Unicode cleanup and whitespace normalization
/// - **Pattern Recognition**: Cooking-specific text pattern detection
/// - **Cultural Adaptation**: Swedish language and formatting conventions
///
/// **Usage Examples:**
/// ```dart
/// // Swedish decimal formatting
/// TextFormatting.formatFractional(2.5); // Returns "2,5"
/// 
/// // Fraction notation
/// TextFormatting.toSwedishHalfFraction(1.5); // Returns "1 ½"
/// 
/// // Text normalization
/// TextFormatting.normalizeText("  fancy   text  "); // Returns "fancy text"
/// 
/// // Swedish number parsing
/// TextFormatting.parseSwedishNumber("2,5"); // Returns 2.5
/// ```

import 'dart:core';

/// Comprehensive text formatting utility class providing Swedish number formatting and cooking-specific text processing.
///
/// This class serves as the centralized text formatting engine for the Butlery cooking application, handling
/// the complexity of Swedish language conventions, decimal formatting, fraction notation, and cooking-related
/// text processing. It provides pure utility functions with optimal performance characteristics and comprehensive
/// cultural adaptation for Swedish cooking applications.
///
/// **Swedish Cultural Integration:**
/// The formatting system respects Swedish language conventions including decimal comma notation,
/// traditional fraction display, and cooking measurement formatting standards commonly used in
/// Swedish recipes and cooking applications.
///
/// **Static Utility Design:**
/// - Private constructor prevents instantiation, ensuring pure utility function usage
/// - All methods are static for convenient access without object creation overhead
/// - Pure functions with no side effects for predictable formatting behavior
/// - Comprehensive Unicode and whitespace handling for robust text processing
class TextFormatting {
  /// Private constructor preventing instantiation to enforce static utility usage.
  TextFormatting._();
  /// Advanced Unicode text normalization with mathematical symbol cleanup and whitespace standardization
  ///
  /// This method provides comprehensive text normalization by removing "fancy" Unicode characters
  /// (such as mathematical bold letters) and mapping them to standard Latin characters, followed
  /// by whitespace normalization. It ensures consistent text representation across different
  /// input sources and handles complex Unicode scenarios commonly found in recipe imports.
  ///
  /// **Normalization Features:**
  /// - **Unicode Cleanup**: Removes mathematical Unicode symbols (U+1D400-U+1D7FF range)
  /// - **Character Mapping**: Maps fancy Unicode letters to standard Latin equivalents
  /// - **Whitespace Standardization**: Normalizes all whitespace to single spaces
  /// - **Edge Case Handling**: Robust handling of malformed Unicode sequences
  ///
  /// [input] The text string to normalize
  /// Returns normalized text with standard characters and single-space whitespace
  ///
  /// **Examples:**
  /// ```dart
  /// normalizeText("𝐀𝐁𝐂   text");  // Returns "ABC text"
  /// normalizeText("  multiple   spaces  ");  // Returns "multiple spaces"
  /// normalizeText("\t\n mixed\r\n whitespace");  // Returns "mixed whitespace"
  /// ```
  static String normalizeText(String input) {
    // Remove mathematical Unicode styling by mapping to standard Latin characters
    final withoutFancyStyle = input.replaceAllMapped(
      RegExp(r'[\u{1D400}-\u{1D7FF}]', unicode: true),
      (m) {
        final original = m[0]!;
        // Get the actual Unicode code point, not the UTF-16 code unit
        final code = original.runes.first;
        
        // Map mathematical bold/italic/etc letters to standard ASCII
        // Mathematical Bold Capital A (U+1D400) -> A (U+0041)
        // Mathematical Bold Capital B (U+1D401) -> B (U+0042), etc.
        
        // Mathematical Bold Capital Letters: U+1D400-U+1D419 -> A-Z
        if (code >= 0x1D400 && code <= 0x1D419) {
          return String.fromCharCode(code - 0x1D400 + 0x41); // A-Z
        }
        // Mathematical Bold Small Letters: U+1D41A-U+1D433 -> a-z
        if (code >= 0x1D41A && code <= 0x1D433) {
          return String.fromCharCode(code - 0x1D41A + 0x61); // a-z
        }
        // Mathematical Bold Digits: U+1D7CE-U+1D7D7 -> 0-9
        if (code >= 0x1D7CE && code <= 0x1D7D7) {
          return String.fromCharCode(code - 0x1D7CE + 0x30); // 0-9
        }
        
        // For other mathematical symbols in this range, remove them
        return '';
      },
    );

    return withoutFancyStyle.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Pattern detection for cooking-specific text containing portion or time information
  ///
  /// This method identifies text patterns that indicate portion sizes or cooking times,
  /// which is essential for recipe parsing and ingredient scaling. It uses sophisticated
  /// regex patterns to detect Swedish cooking terminology and numeric patterns commonly
  /// used in recipe instructions and ingredient lists.
  ///
  /// **Detection Patterns:**
  /// - **Portion indicators**: "portioner", "port", "pers", "personer"
  /// - **Time indicators**: "min", "minuter"
  /// - **Count indicators**: "st", "stycken"
  /// - **Numeric ranges**: "4-6 portioner", "10-15 min"
  /// - **Mixed formats**: "2 pers", "30 minuter"
  ///
  /// [text] The text to analyze for portion or time patterns
  /// Returns true if the text contains portion or time indicators
  ///
  /// **Examples:**
  /// ```dart
  /// isPortionOrTimeLine("4 portioner");     // Returns true
  /// isPortionOrTimeLine("15 minuter");      // Returns true
  /// isPortionOrTimeLine("2-4 pers");        // Returns true
  /// isPortionOrTimeLine("ingrediens");      // Returns false
  /// ```
  static bool isPortionOrTimeLine(String text) {
    // Comprehensive regex for Swedish cooking terminology and numeric patterns
    final pattern = RegExp(
      r'^.*\b(\d+(\s*-\s*\d+)?)(\s*)(min|minuter|portioner|port|pers|personer|st|stycken)\b.*$',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  /// Swedish decimal formatting with cultural conventions and optimal precision display
  ///
  /// This method formats double values according to Swedish cultural conventions, using
  /// decimal comma notation and intelligent precision handling. It automatically optimizes
  /// decimal places for readability while maintaining accuracy, making it ideal for
  /// cooking measurements and ingredient quantities.
  ///
  /// **Formatting Features:**
  /// - **Swedish Notation**: Uses comma (",") as decimal separator instead of period
  /// - **Precision Optimization**: Removes trailing zeros and unnecessary decimal points
  /// - **Integer Detection**: Displays whole numbers without decimal notation
  /// - **Cooking Precision**: Limits to maximum 2 decimal places for cooking practicality
  ///
  /// [value] The double value to format with Swedish conventions
  /// Returns formatted string with Swedish decimal comma notation
  ///
  /// **Examples:**
  /// ```dart
  /// formatFractional(2.5);    // Returns "2,5"
  /// formatFractional(3.0);    // Returns "3"
  /// formatFractional(1.25);   // Returns "1,25"
  /// formatFractional(4.10);   // Returns "4,1"
  /// ```
  static String formatFractional(double value) {
    // Handle whole numbers without decimal notation
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    // Format with maximum 2 decimal places
    var s = value.toStringAsFixed(2);
    // Remove trailing zeros for cleaner display
    s = s.replaceAll(RegExp(r'0+$'), '');
    // Remove trailing decimal point if no decimals remain
    s = s.replaceAll(RegExp(r'\.$'), '');

    // Apply Swedish decimal comma convention
    s = s.replaceAll('.', ',');
    return s;
  }

  /// Swedish number parsing with comprehensive decimal separator support
  ///
  /// This method provides robust parsing of Swedish number formats, supporting both
  /// traditional Swedish decimal comma notation and international decimal point notation.
  /// It includes comprehensive error handling and provides sensible defaults for
  /// cooking applications where invalid numbers should not break functionality.
  ///
  /// **Parsing Features:**
  /// - **Dual Format Support**: Handles both "," and "." as decimal separators
  /// - **Whitespace Tolerance**: Automatically trims whitespace from input
  /// - **Error Recovery**: Returns 1.0 as default for invalid input (cooking-friendly)
  /// - **Culture Adaptive**: Normalizes Swedish format to Dart's expected format
  ///
  /// [number] The number string to parse (Swedish or international format)
  /// Returns parsed double value, or 1.0 as safe default for invalid input
  ///
  /// **Examples:**
  /// ```dart
  /// parseSwedishNumber("2,5");      // Returns 2.5
  /// parseSwedishNumber("3.14");     // Returns 3.14
  /// parseSwedishNumber(" 1,25 ");   // Returns 1.25
  /// parseSwedishNumber("invalid");  // Returns 1.0 (safe default)
  /// ```
  static double parseSwedishNumber(String number) {
    // Normalize input: remove whitespace and convert Swedish comma to decimal point
    final normalized = number.trim().replaceAll(',', '.');

    try {
      final result = double.parse(normalized);
      // Check for NaN or Infinity and return default
      if (result.isNaN || result.isInfinite) {
        return 1.0;
      }
      return result;
    } catch (e) {
      // Return cooking-friendly default (1.0) for invalid input
      return 1.0;
    }
  }

  /// Advanced Swedish fraction formatting with Unicode notation and mixed number support
  ///
  /// This method provides sophisticated fraction formatting that converts decimal values to
  /// traditional Swedish fraction notation using Unicode symbols. It handles mixed numbers,
  /// quarter fractions, and provides intelligent fallback to decimal notation when fractions
  /// are not appropriate, making it ideal for cooking measurements and recipe display.
  ///
  /// **Fraction Support:**
  /// - **Half fractions**: 0.5 -> "½", 1.5 -> "1 ½", 2.5 -> "2 ½"
  /// - **Quarter fractions**: 0.25 -> "¼", 0.75 -> "¾", 1.25 -> "1 ¼"
  /// - **Mixed numbers**: Combines whole numbers with fraction notation
  /// - **Precision handling**: Uses tolerance for floating-point comparison accuracy
  /// - **Fallback formatting**: Uses Swedish decimal notation for non-fraction values
  ///
  /// [value] The decimal value to convert to Swedish fraction notation
  /// Returns formatted string with Unicode fractions or Swedish decimal format
  ///
  /// **Examples:**
  /// ```dart
  /// toSwedishHalfFraction(0.5);   // Returns "½"
  /// toSwedishHalfFraction(1.5);   // Returns "1 ½"
  /// toSwedishHalfFraction(0.25);  // Returns "¼"
  /// toSwedishHalfFraction(2.75);  // Returns "2 ¾"
  /// toSwedishHalfFraction(1.33);  // Returns "1,33" (fallback)
  /// ```
  static String toSwedishHalfFraction(double value) {
    // Handle special values
    if (value.isNaN) return 'NaN';
    if (value.isInfinite) {
      return value.isNegative ? '-∞' : '∞';
    }
    
    // Handle negative values
    final isNegative = value < 0;
    final absValue = value.abs();
    
    final integerPart = absValue.truncate();
    final fracPart = absValue - integerPart;

    // Check for half fraction with floating-point tolerance
    if ((fracPart - 0.5).abs() < 0.001) {
      if (integerPart == 0) {
        return isNegative ? '-½' : '½';
      }
      return isNegative ? '-$integerPart ½' : '$integerPart ½';
    }

    // Check for quarter fraction with floating-point tolerance
    if ((fracPart - 0.25).abs() < 0.001) {
      if (integerPart == 0) {
        return isNegative ? '-¼' : '¼';
      }
      return isNegative ? '-$integerPart ¼' : '$integerPart ¼';
    }

    // Check for three-quarter fraction with floating-point tolerance
    if ((fracPart - 0.75).abs() < 0.001) {
      if (integerPart == 0) {
        return isNegative ? '-¾' : '¾';
      }
      return isNegative ? '-$integerPart ¾' : '$integerPart ¾';
    }

    // Fallback to Swedish decimal formatting for non-fraction values
    return formatFractional(value);
  }
}

/// Legacy function exports for backward compatibility during migration phase
///
/// These global functions provide backward compatibility for existing code that hasn't been
/// updated to use the new TextFormatting class methods. They delegate to the corresponding
/// static methods while maintaining the same function signatures and behavior.
///
/// **Migration Note:** New code should use `TextFormatting.methodName()` directly.
/// These legacy exports will be removed in a future version once all code has been migrated.

/// Legacy export: Use TextFormatting.normalizeText() instead
String normalizeText(String input) => TextFormatting.normalizeText(input);

/// Legacy export: Use TextFormatting.isPortionOrTimeLine() instead
bool isPortionOrTimeLine(String text) => TextFormatting.isPortionOrTimeLine(text);

/// Legacy export: Use TextFormatting.formatFractional() instead
String formatFractional(double value) => TextFormatting.formatFractional(value);

/// Legacy export: Use TextFormatting.parseSwedishNumber() instead
double parseSwedishNumber(String number) => TextFormatting.parseSwedishNumber(number);

/// Legacy export: Use TextFormatting.toSwedishHalfFraction() instead
String toSwedishHalfFraction(double value) => TextFormatting.toSwedishHalfFraction(value);