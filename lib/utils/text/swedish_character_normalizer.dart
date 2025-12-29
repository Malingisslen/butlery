/// CRIT-5: Swedish Character Normalizer
///
/// This utility provides the canonical normalization of Swedish diacritics
/// (å, ä, ö) for use in ingredient lookups and cascade retagging.
///
/// **CRITICAL CONTRACT**:
/// This normalization MUST match the TypeScript implementation in:
/// `functions/src/ingredients/on-ingredient-soft-deleted.ts`
///
/// The mapping is:
/// - å → a
/// - ä → a
/// - ö → o
///
/// If this implementation changes, the TypeScript side MUST be updated
/// to match, otherwise cascade retagging will fail silently.
///
/// See: docs/tagging/normalization_contract.md
class SwedishCharacterNormalizer {
  /// Private constructor to prevent instantiation
  SwedishCharacterNormalizer._();

  /// Normalizes Swedish characters in a string.
  ///
  /// Converts:
  /// - å → a
  /// - ä → a
  /// - ö → o
  ///
  /// Also lowercases the input for consistent matching.
  ///
  /// Example:
  /// ```dart
  /// normalize("Köttfärs") // returns "kottfars"
  /// normalize("Räkor")    // returns "rakor"
  /// normalize("Ägg")      // returns "agg"
  /// ```
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('å', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o');
  }

  /// Normalizes a list of strings.
  static List<String> normalizeAll(List<String> inputs) {
    return inputs.map(normalize).toList();
  }

  /// Test vectors for consistency verification.
  ///
  /// These vectors MUST produce identical results in both Dart and TypeScript.
  /// Used by normalization_consistency_test.dart to verify contract compliance.
  static const Map<String, String> testVectors = {
    // Basic Swedish characters
    'Köttfärs': 'kottfars',
    'Räkor': 'rakor',
    'Ägg': 'agg',
    'Löksoppa': 'loksoppa',
    'Grädde': 'gradde',
    'Smör': 'smor',
    'Mjölk': 'mjolk',
    'Bröd': 'brod',
    'Ärtor': 'artor',
    'Rödlök': 'rodlok',

    // Mixed cases
    'KÖTTBULLAR': 'kottbullar',
    'ÄGG OCH BACON': 'agg och bacon',

    // Multiple occurrences
    'äppelkräm': 'appelkram',
    'grönsaksbulljong': 'gronsaksbulljong',
    'rödbetssoppa': 'rodbetssoppa',

    // Edge cases
    '': '',
    'a': 'a',
    'abc': 'abc',
    'åäö': 'aao',

    // Common ingredients
    'fläsk': 'flask',
    'lök': 'lok',
    'morot': 'morot', // No Swedish chars
    'potatis': 'potatis', // No Swedish chars
    'tomat': 'tomat', // No Swedish chars
    'vitlök': 'vitlok',
    'persilja': 'persilja', // No Swedish chars
    'dill': 'dill', // No Swedish chars
  };
}
