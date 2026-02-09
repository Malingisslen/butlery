/// Canonical compound suffix configuration for Swedish ingredient parsing.
///
/// Used by IngredientLookupService for compound word splitting.
/// ASCII-normalized (å→a, ä→a, ö→o) to match lookup normalization.
class CompoundSuffixes {
  CompoundSuffixes._();

  /// Primary suffixes for splitting compound words.
  /// Used for space-insertion matching (e.g., "kycklingbrost" → "kyckling brost").
  static const List<String> primarySuffixes = [
    'brost',
    'file',
    'kott',
    'flask',
    'skinka',
    'korv',
    'fars',
    'mjolk',
    'gradde',
    'ost',
    'smor',
    'olja',
    'sas',
    'soppa',
    'brod',
    'pasta',
    'ris',
    'potatis',
    'lok',
    'vitlok',
  ];

  /// Extended endings for base extraction from compound words.
  /// Used for variation generation (e.g., "vitlöksklyftor" → "vitlök").
  static const List<String> extendedEndings = [
    // Primary meat/protein suffixes
    'sas',
    'file',
    'kott',
    'flask',
    'skinka',
    'korv',
    'brost',
    'lar',
    'ben',
    'bog',
    'rygg',
    'fars',
    'lever',
    'njure',
    'kotlett',
    'kotletter',
    'stek',
    // Dairy and fats
    'mjolk',
    'gradde',
    'smor',
    'ost',
    'olja',
    'fett',
    // Prepared foods and sauces
    'soppa',
    'bullar',
    'brod',
    'kakor',
    'pasta',
    'pure',
    'passata',
    'buljong',
    'fond',
    // Vegetables
    'lok',
    'kal',
    'rot',
    'blad',
    'stjalk',
    'stjalkar',
    // Preparation/cuts
    'klyftor',
    'klyft',
    'skivor',
    'skiva',
    'bitar',
    'bit',
    'tarningar',
    // Other common
    'ris',
    'mjol',
  ];
}
