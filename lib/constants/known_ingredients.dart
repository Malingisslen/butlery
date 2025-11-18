/// Registry of known Swedish ingredients organized by category
/// Used by ingredient normalizer to validate normalized ingredient names
/// and provide category information for tagging.
/// # Usage
/// ```dart
/// // Check if ingredient is known
/// if (KnownIngredients.isKnown('mjölk')) {
///   // Known ingredient
/// }
/// // Get category
/// final category = KnownIngredients.getCategory('mjölk');
/// // → 'dairy'
/// // Check if compound name
/// if (KnownIngredients.isCompoundName('vitpeppar')) {
///   // Don't split this compound name!
/// }
/// ```
class KnownIngredients {
  /// Private constructor to prevent instantiation
  KnownIngredients._();

  /// Dairy products
  static const dairy = {
    'mjölk',
    'grädde',
    'vispgrädde',
    'matlagningsgrädde',
    'creme fraiche',
    'créme fraiche',
    'yoghurt',
    'filmjölk',
    'kefir',
    'ost',
    'smör',
    'margarin',
    'kvarg',
    'kesella',
    'keso',
    'bredbar',
  };

  /// Meat and poultry
  static const meat = {
    'kött',
    'fläsk',
    'bacon',
    'skinka',
    'korv',
    'falukorv',
    'prinskorv',
    'salami',
    'kyckling',
    'kalkon',
    'höna',
    'fågel',
    'kötfärs',
    'nötkött',
    'nötfärs',
    'fläskfärs',
    'blandfärs',
    'köttfärs',
    'fläskkarré',
    'fläskfilé',
    'revbensspjäll',
    'entrecote',
    'oxfilé',
    'ryggbiff',
    'flankstek',
    'bog',
  };

  /// Fish and seafood
  static const seafood = {
    'fisk',
    'lax',
    'torsk',
    'sill',
    'strömming',
    'makrill',
    'abborre',
    'gädda',
    'tonfisk',
    'räka',
    'räkor',
    'krabba',
    'hummer',
    'musslor',
    'ostron',
    'blåmusslor',
  };

  /// Vegetables
  static const vegetables = {
    'potatis',
    'sötpotatis',
    'lök',
    'vitlök',
    'morot',
    'tomat',
    'gurka',
    'paprika',
    'chili',
    'broccoli',
    'blomkål',
    'vitkål',
    'rödkål',
    'kålrot',
    'palsternacka',
    'selleri',
    'purjolök',
    'squash',
    'zucchini',
    'aubergine',
    'pumpa',
    'champinjon',
    'svamp',
    'ärt',
    'ärtor',
    'böna',
    'bönor',
    'linser',
    'kikärtor',
    'sallad',
    'isbergssallad',
    'rucola',
    'spenat',
    'grönkål',
    'kålrabbi',
    'sockerärter',
    'haricots verts',
  };

  /// Fruits and berries
  static const fruits = {
    'äpple',
    'päron',
    'banan',
    'apelsin',
    'citron',
    'lime',
    'mango',
    'ananas',
    'melon',
    'vattenmelon',
    'persika',
    'nektarin',
    'plommon',
    'kiwi',
    'druva',
    'druvor',
    'hallon',
    'jordgubbe',
    'jordgubbar',
    'blåbär',
    'lingon',
    'tranbär',
    'björnbär',
    'vinbär',
    'svarta vinbär',
    'krusbär',
    'avokado',
  };

  /// Grains and flour
  static const grains = {
    'mjöl',
    'vetemjöl',
    'rågmjöl',
    'dinkel',
    'dinkelmjöl',
    'grahamsmjöl',
    'havre',
    'havregryn',
    'havreflingor',
    'ris',
    'risgryn',
    'basmatiris',
    'jasminris',
    'pasta',
    'makaroner',
    'spagetti',
    'tagliatelle',
    'penne',
    'farfalle',
    'bulgur',
    'couscous',
    'quinoa',
    'durra',
    'korngryn',
    'råghvete',
  };

  /// Bread and baked goods
  static const bread = {
    'bröd',
    'mjukbröd',
    'hårdrost',
    'kavring',
    'knäckebröd',
    'baguette',
    'ciabatta',
    'pitabröd',
    'tortilla',
    'wraps',
    'ströbröd',
    'panko',
  };

  /// Condiments and sauces
  static const condiments = {
    'ketchup',
    'senap',
    'majonnäs',
    'mayo',
    'aioli',
    'soja',
    'sojasås',
    'fisksås',
    'ostronsås',
    'hoisinsås',
    'chilisås',
    'tabasco',
    'sriracha',
    'tomatsås',
    'tomatpuré',
    'tomatpasta',
    'passata',
    'krossade tomater',
    'tomatkross',
    'buljong',
    'fond',
    'kalvfond',
    'hönsfond',
    'grönsaksfond',
    'ättika',
    'vinäger',
    'balsamico',
    'rödvinsvinäger',
    'vitvinsvinäger',
    'äppelcidervinäger',
  };

  /// Spices and herbs
  static const spices = {
    'salt',
    'peppar',
    'vitpeppar',
    'svartpeppar',
    'cayennepeppar',
    'kryddpeppar',
    'paprikapulver',
    'chilipulver',
    'spiskummin',
    'kummin',
    'koriander',
    'kardemumma',
    'kanel',
    'nejlika',
    'ingefära',
    'muskotnöt',
    'lagerbladbard',
    'timjan',
    'rosmarin',
    'oregano',
    'basilika',
    'persilja',
    'dill',
    'gräslök',
    'mejram',
    'salvia',
    'dragon',
    'curry',
    'gurkmeja',
    'saffran',
    'vanilj',
    'vaniljsocker',
  };

  /// Oils and fats
  static const oils = {
    'olja',
    'olivolja',
    'rapsolja',
    'solrosolja',
    'sesamolja',
    'kokosolja',
    'smör',
    'margarin',
    'bredbart',
  };

  /// Sweeteners
  static const sweeteners = {
    'socker',
    'strösocker',
    'florsocker',
    'pärlsocker',
    'farinsocker',
    'muscovadosocker',
    'honung',
    'sirap',
    'ljus sirap',
    'mörk sirap',
    'lönnsirap',
    'agavesirap',
  };

  /// Nuts and seeds
  static const nutsAndSeeds = {
    'mandel',
    'hasselnöt',
    'valnöt',
    'cashewnöt',
    'pistagenöt',
    'pinjekärna',
    'jordnöt',
    'solroskärnor',
    'pumppärnor',
    'sesamfrön',
    'linfrön',
    'chiafrön',
  };

  /// Baking ingredients
  static const baking = {
    'bakpulver',
    'bikarbonat',
    'jäst',
    'torrjäst',
    'färsk jäst',
    'vaniljsocker',
    'vanilj',
    'kakao',
    'kakaopulver',
    'mörk choklad',
    'mjölkchoklad',
    'vit choklad',
    'choklad',
    'chokladknappar',
    'russin',
    'bakrosiner',
    'torkad frukt',
  };

  /// Canned and preserved
  static const canned = {
    'majskorn',
    'kidneybönor',
    'vita bönor',
    'svarta bönor',
    'kikärtor',
    'linser',
    'kokosmjölk',
    'crème fraiche',
  };

  /// Beverages (non-alcoholic)
  static const beverages = {
    'vatten',
    'mjölk',
    'juice',
    'läsk',
    'kaffe',
    'te',
  };

  /// Alcoholic beverages (for cooking)
  static const alcohol = {
    'vin',
    'rödvin',
    'vitt vin',
    'rosévin',
    'sherry',
    'portvin',
    'madeira',
    'cognac',
    'brandy',
    'rom',
    'öl',
    'pilsner',
    'porter',
  };

  /// Eggs and egg products
  static const eggs = {
    'ägg',
  };

  /// Compound ingredient names that should NOT be split
  /// These are ingredient names where a color/descriptor is part of the
  /// actual ingredient name and should be kept together.
  /// Examples:
  /// - "vitpeppar" (white pepper) - NOT "peppar"
  /// - "svartpeppar" (black pepper) - NOT "peppar"
  /// - "rödlök" (red onion) - NOT "lök"
  static const compoundNames = {
    // Peppers
    'vitpeppar',
    'svartpeppar',
    'cayennepeppar',
    'kryddpeppar',

    // Onions
    'rödlök',
    'gullök',
    'salladslök',
    'purjolök',

    // Cabbage
    'vitkål',
    'rödkål',
    'grönkål',
    'blomkål',

    // Beans
    'kidneybönor',
    'vita bönor',
    'svarta bönor',
    'gröna bönor',

    // Vinegar/wine
    'rödvinsvinäger',
    'vitvinsvinäger',
    'rödvin',
    'vitt vin',

    // Berries
    'svarta vinbär',
    'röda vinbär',

    // Other
    'vit choklad',
    'mörk choklad',
    'ljus sirap',
    'mörk sirap',
    'sötpotatis',
  };

  /// All known ingredients combined
  static final Set<String> all = {
    ...dairy,
    ...meat,
    ...seafood,
    ...vegetables,
    ...fruits,
    ...grains,
    ...bread,
    ...condiments,
    ...spices,
    ...oils,
    ...sweeteners,
    ...nutsAndSeeds,
    ...baking,
    ...canned,
    ...beverages,
    ...alcohol,
    ...eggs,
    ...compoundNames,
  };

  /// Check if ingredient is known
  static bool isKnown(String ingredient) {
    return all.contains(ingredient.toLowerCase());
  }

  /// Check if ingredient is a compound name that should not be split
  static bool isCompoundName(String ingredient) {
    return compoundNames.contains(ingredient.toLowerCase());
  }

  /// Get category for ingredient
  /// Returns category name or null if not found.
  static String? getCategory(String ingredient) {
    final lower = ingredient.toLowerCase();

    if (dairy.contains(lower)) return 'dairy';
    if (meat.contains(lower)) return 'meat';
    if (seafood.contains(lower)) return 'seafood';
    if (vegetables.contains(lower)) return 'vegetables';
    if (fruits.contains(lower)) return 'fruits';
    if (grains.contains(lower)) return 'grains';
    if (bread.contains(lower)) return 'bread';
    if (condiments.contains(lower)) return 'condiments';
    if (spices.contains(lower)) return 'spices';
    if (oils.contains(lower)) return 'oils';
    if (sweeteners.contains(lower)) return 'sweeteners';
    if (nutsAndSeeds.contains(lower)) return 'nuts_seeds';
    if (baking.contains(lower)) return 'baking';
    if (canned.contains(lower)) return 'canned';
    if (beverages.contains(lower)) return 'beverages';
    if (alcohol.contains(lower)) return 'alcohol';
    if (eggs.contains(lower)) return 'eggs';

    return null;
  }

  /// Get all ingredients in a category
  static Set<String>? getIngredientsInCategory(String category) {
    switch (category.toLowerCase()) {
      case 'dairy':
        return dairy;
      case 'meat':
        return meat;
      case 'seafood':
        return seafood;
      case 'vegetables':
        return vegetables;
      case 'fruits':
        return fruits;
      case 'grains':
        return grains;
      case 'bread':
        return bread;
      case 'condiments':
        return condiments;
      case 'spices':
        return spices;
      case 'oils':
        return oils;
      case 'sweeteners':
        return sweeteners;
      case 'nuts_seeds':
        return nutsAndSeeds;
      case 'baking':
        return baking;
      case 'canned':
        return canned;
      case 'beverages':
        return beverages;
      case 'alcohol':
        return alcohol;
      case 'eggs':
        return eggs;
      default:
        return null;
    }
  }

  /// Get all categories
  static List<String> getAllCategories() {
    return [
      'dairy',
      'meat',
      'seafood',
      'vegetables',
      'fruits',
      'grains',
      'bread',
      'condiments',
      'spices',
      'oils',
      'sweeteners',
      'nuts_seeds',
      'baking',
      'canned',
      'beverages',
      'alcohol',
      'eggs',
    ];
  }
}
