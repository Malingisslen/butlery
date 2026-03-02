/// Registry of Swedish preparation states and descriptors to remove
/// during ingredient normalization.
/// **EXCLUDED:** Diet descriptors (glutenfri, sockerfri, laktosfri)
/// These are preserved as they're important for dietary restrictions.
/// # Usage
/// ```dart
/// // Check if word should be removed
/// if (PreparationWords.shouldRemove('hackad')) {
///   // Remove from ingredient name
/// }
/// // Get all removable words
/// final allWords = PreparationWords.all;
/// ```
class PreparationWords {
  /// Private constructor to prevent instantiation
  PreparationWords._();

  /// Preparation states - how ingredient has been processed
  static const preparationStates = {
    // Cutting/chopping
    'hackad',
    'hackade',
    'hackat',
    'finhackad',
    'finhackade',
    'finhackat',
    'grovhackad',
    'grovhackade',
    'grovhackat',

    // Slicing
    'skivad',
    'skivat',
    'skivade',
    'strimlad',
    'strimlat',
    'strimlade',

    // Grating/shredding
    'riven',
    'rivet',
    'rivna',
    'finriven',
    'finrivet',
    'finrivna',
    'grovriven',
    'grovrivet',
    'grovrivna',
    'nyriven',
    'nyrivet',
    'nyrivna',

    // Crushing/grinding/pressing
    'stött',
    'stötta',
    'malen',
    'malet',
    'malda',
    'nymalen',
    'nymalet',
    'nymalda',
    'pressad',
    'pressat',
    'pressade',
    'krossad',
    'krossat',
    'krossade',

    // Dicing
    'tärnad',
    'tärnat',
    'tärnade',

    // Cooking states
    'kokt',
    'kokta',
    'stekt',
    'stekta',
    'grillad',
    'grillat',
    'grillade',
    'rostad',
    'rostat',
    'rostade',
    'bakad',
    'bakat',
    'bakade',

    // Curing/preserving
    'rimmat',
    'rimmad',
    'rimmade',
    'rökt',
    'rökta',
    'rökte',
    'saltad',
    'saltat',
    'saltade',

    // Temperature/freshness
    'färsk',
    'färskt',
    'färska',
    'fryst',
    'frysta',
    'kall',
    'kallt',
    'kalla',
    'varm',
    'varmt',
    'varma',
    'ljummen',
    'ljummet',
    'ljumna',

    // Liquid preparation (draining/wringing)
    'urvattnad',
    'urvattnade',
    'urvattnat',
    'avrunnen',
    'avrunnet',
    'avrunna',

    // Heat/freeze
    'tinad',
    'tinat',
    'tinade',
    'blancherad',
    'blancherat',
    'blancherade',

    // Marinading/soaking
    'marinerad',
    'marinerat',
    'marinerade',

    // Halving/chopping up
    'halverad',
    'halverat',
    'halverade',
    'upphackad',
    'upphackat',
    'upphackade',

    // Peeling/drying/crumbling/sprinkling
    'skalad',
    'skalat',
    'skalade',
    'strödd',
    'strött',
    'strödda',
    'torkad',
    'torkat',
    'torkade',
    'smulad',
    'smulat',
    'smulade',

    // Straining/puréeing
    'passerad',
    'passerat',
    'passerade',

    // Sweetness/flavor modifiers
    'osötad',
    'osötat',
    'osötade',
    'sötad',
    'sötat',
    'sötade',

    // Raw/unprocessed
    'rå',
    'rått',
    'råa',

    // Wringing/squeezing
    'urkramad',
    'urkramat',
    'urkramade',

    // Pitting/deseeding
    'urkärnad',
    'urkärnat',
    'urkärnade',

    // Mashing/puréeing
    'mosad',
    'mosat',
    'mosade',

    // Freeze-drying
    'frystorkad',
    'frystorkat',
    'frystorkade',

    // Temperature state
    'rumstempererad',
    'rumstempererat',
    'rumstempererade',

    // Adverb modifiers for preparation (thin/thick)
    'tunt',
    'grovt',
  };

  /// Size descriptors
  static const sizeDescriptors = {
    'stor',
    'stort',
    'stora',
    'liten',
    'litet',
    'små',
    'mellanstort',
    'mellanstor',
    'mellanstora',
    'extra stor',
    'extra stort',
    'mini',
  };

  /// Type descriptors (contextual)
  static const typeDescriptors = {
    // Potato types
    'mjölig',
    'mjöliga',
    'fast',
    'fasta',
    // 'mandel' removed — it's a real ingredient (almond), not a preparation descriptor

    // General quality
    'bra',
    'god',
    'goda',
    'gott',
    'fin',
    'fint',
    'fina',

    // NOTE: NOT including diet descriptors!
    // "glutenfri", "sockerfri", "laktosfri" are PRESERVED
  };

  /// Color descriptors (only remove when not part of compound name)
  /// **WARNING:** Do not remove from compound ingredient names like:
  /// - "vitpeppar" (white pepper)
  /// - "svartpeppar" (black pepper)
  /// - "rödlök" (red onion)
  /// These should be checked against compound name list first.
  static const colorDescriptors = {
    'gul',
    'gula',
    'gult',
    'röd',
    'röda',
    'rött',
    'vit',
    'vita',
    'vitt',
    'grön',
    'gröna',
    'grönt',
    'svart',
    'svarta',
    'brun',
    'bruna',
    'brunt',
    'orange',
    'orangea',
    'rosa',
    'ljus',
    'ljusa',
    'ljust',
    'mörk',
    'mörka',
    'mörkt',
  };

  /// Alternative conjunctions
  static const alternativeConjunctions = {
    'eller',
    'alternativt',
  };

  /// Swedish cooking verbs (imperative form) — shared vocabulary for
  /// instruction detection across classifiers and detectors.
  static const cookingVerbs = {
    // Preparation
    'skär', 'hacka', 'skala', 'riv', 'mosa', 'blanda', 'vispa', 'rör',
    'mixa', 'knåda', 'forma', 'kavla', 'fyll', 'garnera',
    // Cooking
    'koka', 'stek', 'fräs', 'grilla', 'grädda', 'baka', 'ugnssteka',
    'bryn', 'sjud', 'puttra', 'reducera', 'smält', 'värm',
    // Timing/Process
    'låt', 'vila', 'ställ', 'sätt', 'ta', 'häll', 'tillsätt', 'strö',
    'servera', 'toppa', 'lägg', 'placera', 'vänd', 'rosta',
    // Common starts
    'börja', 'förvärm', 'förbered',
  };

  /// Combined set of all removable words
  static final Set<String> all = {
    ...preparationStates,
    ...sizeDescriptors,
    ...typeDescriptors,
    ...colorDescriptors,
    ...alternativeConjunctions,
  };

  /// Check if word should be removed during normalization
  /// Returns true if the word is a preparation state, size descriptor,
  /// type descriptor, color descriptor, or alternative conjunction.
  /// **Note:** This does not check for compound names. Always check
  /// compound names BEFORE using this method.
  /// Examples:
  /// ```dart
  /// PreparationWords.shouldRemove('hackad')  // → true
  /// PreparationWords.shouldRemove('stor')    // → true
  /// PreparationWords.shouldRemove('mjölk')   // → false
  /// ```
  static bool shouldRemove(String word) {
    return all.contains(word.toLowerCase());
  }

  /// Check if word is a preparation state specifically
  static bool isPreparationState(String word) {
    return preparationStates.contains(word.toLowerCase());
  }

  /// Check if word is a size descriptor specifically
  static bool isSizeDescriptor(String word) {
    return sizeDescriptors.contains(word.toLowerCase());
  }

  /// Check if word is a type descriptor specifically
  static bool isTypeDescriptor(String word) {
    return typeDescriptors.contains(word.toLowerCase());
  }

  /// Check if word is a color descriptor specifically
  static bool isColorDescriptor(String word) {
    return colorDescriptors.contains(word.toLowerCase());
  }

  /// Check if word is an alternative conjunction specifically
  static bool isAlternativeConjunction(String word) {
    return alternativeConjunctions.contains(word.toLowerCase());
  }
}
