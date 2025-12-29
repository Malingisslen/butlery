/// Configuration for cuisine detection in the tagging system.
///
/// Defines 17 world cuisines with their title keywords and ingredient patterns.
/// This is a hardcoded approach for reliability and testability - no CSV parsing.
library;

import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Single cuisine configuration.
class CuisineEntry {
  /// Cuisine key (e.g., 'svensk', 'italiensk').
  final String key;

  /// Swedish tag for this cuisine.
  final String tag;

  /// Title keywords that indicate this cuisine (case-insensitive).
  final Set<String> titleKeywords;

  /// Ingredient names that indicate this cuisine (case-insensitive).
  final Set<String> ingredientKeywords;

  /// Ingredient groups that indicate this cuisine.
  final Set<String> ingredientGroups;

  /// Minimum ingredient matches required (default: 2).
  final int minIngredientMatches;

  const CuisineEntry({
    required this.key,
    required this.tag,
    this.titleKeywords = const {},
    this.ingredientKeywords = const {},
    this.ingredientGroups = const {},
    this.minIngredientMatches = 2,
  });

  /// Check if recipe matches this cuisine.
  ///
  /// Returns true if:
  /// - Title contains any title keyword, OR
  /// - At least [minIngredientMatches] ingredient keywords match
  bool matches(Recipe recipe, IngredientLookupResult lookup) {
    final title = recipe.core.title.toLowerCase();

    // Check title keywords
    for (final keyword in titleKeywords) {
      if (title.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    // Count ingredient matches
    int ingredientMatches = 0;

    for (final ingredient in lookup.matched) {
      final name = ingredient.swedish.toLowerCase();
      final group = ingredient.group.toLowerCase();

      // Check ingredient name keywords
      for (final keyword in ingredientKeywords) {
        if (name.contains(keyword.toLowerCase())) {
          ingredientMatches++;
          break; // Count each ingredient only once
        }
      }

      // Check ingredient groups
      for (final groupPattern in ingredientGroups) {
        if (group.contains(groupPattern.toLowerCase())) {
          ingredientMatches++;
          break;
        }
      }
    }

    return ingredientMatches >= minIngredientMatches;
  }
}

/// Static configuration of all supported cuisines.
class CuisineConfig {
  CuisineConfig._();

  /// All cuisine entries.
  static const List<CuisineEntry> cuisines = [
    // Swedish/Nordic
    svensk,
    nordisk,

    // Mediterranean
    italiensk,
    grekisk,
    spansk,
    fransk,
    medelhavsmat,

    // Asian
    thailandsk,
    indisk,
    kinesisk,
    japansk,
    koreansk,
    vietnamesisk,
    asiatisk,

    // Americas
    mexikansk,
    amerikansk,

    // Middle Eastern
    mellanoostern,
  ];

  // ===== INDIVIDUAL CUISINE DEFINITIONS =====

  static const svensk = CuisineEntry(
    key: 'svensk',
    tag: 'svensk',
    titleKeywords: {
      'svensk',
      'husmanskost',
      'köttbullar',
      'janssons',
      'falukorv',
      'pannkakor',
      'kroppkakor',
      'pitepalt',
      'raggmunk',
    },
    ingredientKeywords: {
      'lingon',
      'dill',
      'gräddsås',
      'rårörda lingon',
      'falukorv',
      'isterband',
      'prinskorv',
    },
    minIngredientMatches: 2,
  );

  static const nordisk = CuisineEntry(
    key: 'nordisk',
    tag: 'nordisk',
    titleKeywords: {
      'nordisk',
      'scandinavian',
      'nordic',
      'gravad',
      'smørrebrød',
    },
    ingredientKeywords: {
      'gravad lax',
      'dill',
      'rågbröd',
      'lingon',
      'hjortron',
    },
    minIngredientMatches: 2,
  );

  static const italiensk = CuisineEntry(
    key: 'italiensk',
    tag: 'italiensk',
    titleKeywords: {
      'italiensk',
      'italian',
      'pasta',
      'pizza',
      'risotto',
      'lasagne',
      'carbonara',
      'bolognese',
      'pesto',
      'bruschetta',
      'tiramisu',
    },
    ingredientKeywords: {
      'parmesan',
      'mozzarella',
      'basilika',
      'oregano',
      'prosciutto',
      'pancetta',
      'mascarpone',
      'ricotta',
      'pecorino',
      'gorgonzola',
    },
    ingredientGroups: {'grain/pasta-bread'},
    minIngredientMatches: 2,
  );

  static const grekisk = CuisineEntry(
    key: 'grekisk',
    tag: 'grekisk',
    titleKeywords: {
      'grekisk',
      'greek',
      'moussaka',
      'tzatziki',
      'souvlaki',
      'gyros',
    },
    ingredientKeywords: {
      'feta',
      'fetaost',
      'oregano',
      'olivolja',
      'tzatziki',
      'pita',
    },
    minIngredientMatches: 2,
  );

  static const spansk = CuisineEntry(
    key: 'spansk',
    tag: 'spansk',
    titleKeywords: {
      'spansk',
      'spanish',
      'paella',
      'tapas',
      'gazpacho',
      'tortilla española',
    },
    ingredientKeywords: {
      'saffran',
      'chorizo',
      'paprika',
      'manchego',
      'serrano',
      'pimentón',
    },
    minIngredientMatches: 2,
  );

  static const fransk = CuisineEntry(
    key: 'fransk',
    tag: 'fransk',
    titleKeywords: {
      'fransk',
      'french',
      'coq au vin',
      'bouillabaisse',
      'ratatouille',
      'quiche',
      'crème brûlée',
      'croissant',
    },
    ingredientKeywords: {
      'dijonsenap',
      'estragon',
      'gruyère',
      'brie',
      'camembert',
      'crème fraîche',
      'dragon',
    },
    minIngredientMatches: 2,
  );

  static const medelhavsmat = CuisineEntry(
    key: 'medelhavsmat',
    tag: 'medelhavsmat',
    titleKeywords: {
      'medelhavs',
      'mediterranean',
    },
    ingredientKeywords: {
      'olivolja',
      'citron',
      'vitlök',
      'rosmarin',
      'timjan',
      'kapris',
      'kronärtskocka',
    },
    minIngredientMatches: 3, // Higher threshold for this broad category
  );

  static const thailandsk = CuisineEntry(
    key: 'thailändsk',
    tag: 'thailändsk',
    titleKeywords: {
      'thailändsk',
      'thai',
      'pad thai',
      'tom yum',
      'tom kha',
      'massaman',
      'panang',
    },
    ingredientKeywords: {
      'kokosmjölk',
      'fisksås',
      'limblad',
      'galanga',
      'citrongräs',
      'koriander',
      'chili',
      'jordnöt',
      'kaffirlime',
      'röd curry',
      'grön curry',
    },
    minIngredientMatches: 2,
  );

  static const indisk = CuisineEntry(
    key: 'indisk',
    tag: 'indisk',
    titleKeywords: {
      'indisk',
      'indian',
      'curry',
      'tikka',
      'masala',
      'tandoori',
      'korma',
      'vindaloo',
      'biryani',
      'naan',
      'samosa',
    },
    ingredientKeywords: {
      'garam masala',
      'gurkmeja',
      'kummin',
      'koriander',
      'kardemumma',
      'ghee',
      'yoghurt',
      'paneer',
      'naan',
      'chutney',
    },
    minIngredientMatches: 2,
  );

  static const kinesisk = CuisineEntry(
    key: 'kinesisk',
    tag: 'kinesisk',
    titleKeywords: {
      'kinesisk',
      'chinese',
      'dim sum',
      'wok',
      'stir fry',
      'kung pao',
      'sweet and sour',
    },
    ingredientKeywords: {
      'sojasås',
      'ingefära',
      'sesamolja',
      'hoisin',
      'ostronsås',
      'böngroddar',
      'szechuan',
      'femkrydda',
      'tofu',
    },
    minIngredientMatches: 2,
  );

  static const japansk = CuisineEntry(
    key: 'japansk',
    tag: 'japansk',
    titleKeywords: {
      'japansk',
      'japanese',
      'sushi',
      'sashimi',
      'ramen',
      'udon',
      'tempura',
      'teriyaki',
      'miso',
      'yakitori',
    },
    ingredientKeywords: {
      'miso',
      'wasabi',
      'nori',
      'dashi',
      'sake',
      'mirin',
      'sojasås',
      'shiitake',
      'wakame',
      'tobiko',
    },
    minIngredientMatches: 2,
  );

  static const koreansk = CuisineEntry(
    key: 'koreansk',
    tag: 'koreansk',
    titleKeywords: {
      'koreansk',
      'korean',
      'kimchi',
      'bibimbap',
      'bulgogi',
      'japchae',
    },
    ingredientKeywords: {
      'kimchi',
      'gochujang',
      'gochugaru',
      'sesamolja',
      'koreansk chili',
      'doenjang',
    },
    minIngredientMatches: 2,
  );

  static const vietnamesisk = CuisineEntry(
    key: 'vietnamesisk',
    tag: 'vietnamesisk',
    titleKeywords: {
      'vietnamesisk',
      'vietnamese',
      'pho',
      'bahn mi',
      'banh mi',
      'spring rolls',
    },
    ingredientKeywords: {
      'fisksås',
      'risnudlar',
      'mynta',
      'koriander',
      'citrongräs',
      'böngroddar',
      'sriracha',
      'hoisin',
    },
    minIngredientMatches: 2,
  );

  static const asiatisk = CuisineEntry(
    key: 'asiatisk',
    tag: 'asiatisk',
    titleKeywords: {
      'asiatisk',
      'asian',
      'wok',
    },
    ingredientKeywords: {
      'sojasås',
      'sesamolja',
      'ingefära',
      'risnudlar',
      'tofu',
      'böngroddar',
    },
    minIngredientMatches: 3, // Higher threshold for this broad category
  );

  static const mexikansk = CuisineEntry(
    key: 'mexikansk',
    tag: 'mexikansk',
    titleKeywords: {
      'mexikansk',
      'mexican',
      'taco',
      'burrito',
      'enchilada',
      'quesadilla',
      'fajita',
      'nachos',
      'guacamole',
    },
    ingredientKeywords: {
      'jalapeño',
      'chipotle',
      'koriander',
      'limejuice',
      'avokado',
      'tortilla',
      'svarta bönor',
      'majs',
      'cheddar',
    },
    minIngredientMatches: 2,
  );

  static const amerikansk = CuisineEntry(
    key: 'amerikansk',
    tag: 'amerikansk',
    titleKeywords: {
      'amerikansk',
      'american',
      'burger',
      'hamburgare',
      'bbq',
      'barbecue',
      'hot dog',
      'mac and cheese',
      'pancakes',
      'muffins',
    },
    ingredientKeywords: {
      'cheddar',
      'bacon',
      'bbq-sås',
      'ranch',
      'majssirap',
    },
    minIngredientMatches: 2,
  );

  static const mellanoostern = CuisineEntry(
    key: 'mellanöstern',
    tag: 'mellanöstern',
    titleKeywords: {
      'mellanöstern',
      'middle eastern',
      'libanesisk',
      'falafel',
      'hummus',
      'shawarma',
      'kebab',
      'tabbouleh',
      'fattoush',
    },
    ingredientKeywords: {
      'tahini',
      'hummus',
      'granatäpple',
      'sumak',
      'za\'atar',
      'zaatar',
      'bulgur',
      'kikärtor',
      'pitabröd',
    },
    minIngredientMatches: 2,
  );
}
