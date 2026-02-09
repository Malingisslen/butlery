// ignore_for_file: avoid_print

/// Migration script to generate Firebase tag configs.
///
/// This script generates JSON files for Firebase based on the
/// hardcoded config data from the Dart config files.
///
/// Usage:
///   dart scripts/migrate_tag_configs.dart
///
/// Output:
///   scripts/output/tagConfigs/
///     allergens.json
///     dietary.json
///     cuisines.json
///     properties.json
///     display.json
library;

import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== Tag Config Migration Script ===\n');

  // Create output directory
  final outputDir = Directory('scripts/output/tagConfigs');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Migrate each config type
  await _migrateAllergens(outputDir);
  await _migrateDietary(outputDir);
  await _migrateCuisines(outputDir);
  await _migrateProperties(outputDir);
  await _migrateDisplay(outputDir);

  print('\n=== Migration Complete ===');
  print('Output files saved to: ${outputDir.path}');
  print('\nNext steps:');
  print('1. Review the generated JSON files');
  print('2. Upload to Firestore:');
  print('   firebase firestore:delete tagConfigs --recursive');
  print('   Use Admin SDK or Firebase Console to import');
  print('3. Run validation tests');
}

Future<void> _migrateAllergens(Directory outputDir) async {
  print('Migrating allergens...');

  // Allergen data from allergen_config.dart
  final allergens = [
    // EU Allergens (14)
    _allergen(
      key: 'gluten',
      triggerProperties: ['contains-gluten'],
      containsTagSv: 'innehåller-gluten',
      freeTagSv: 'glutenfri',
      containsTagEn: 'contains-gluten',
      freeTagEn: 'gluten-free',
      isEuAllergen: true,
      priority: 1,
    ),
    _allergen(
      key: 'mjölk',
      triggerProperties: ['dairy'],
      containsTagSv: 'innehåller-mjölk',
      freeTagSv: 'mjölkfri',
      containsTagEn: 'contains-milk',
      freeTagEn: 'dairy-free',
      isEuAllergen: true,
      uiGroup: 'dairy',
      descriptionSv: 'Mjölkprotein (kasein, vassle). Skiljer sig från laktos.',
      priority: 2,
    ),
    _allergen(
      key: 'ägg',
      triggerProperties: ['egg'],
      containsTagSv: 'innehåller-ägg',
      freeTagSv: 'äggfri',
      containsTagEn: 'contains-egg',
      freeTagEn: 'egg-free',
      isEuAllergen: true,
      priority: 3,
    ),
    _allergen(
      key: 'fisk',
      triggerProperties: ['fish'],
      containsTagSv: 'innehåller-fisk',
      freeTagSv: 'fiskfri',
      containsTagEn: 'contains-fish',
      freeTagEn: 'fish-free',
      isEuAllergen: true,
      uiGroup: 'seafood',
      priority: 4,
    ),
    _allergen(
      key: 'kräftdjur',
      triggerProperties: ['crustacean'],
      containsTagSv: 'innehåller-kräftdjur',
      freeTagSv: 'kräftdjursfri',
      containsTagEn: 'contains-crustaceans',
      freeTagEn: 'crustacean-free',
      isEuAllergen: true,
      uiGroup: 'seafood',
      priority: 5,
    ),
    _allergen(
      key: 'blötdjur',
      triggerProperties: ['mollusc'],
      containsTagSv: 'innehåller-blötdjur',
      freeTagSv: 'blötdjursfri',
      containsTagEn: 'contains-molluscs',
      freeTagEn: 'mollusc-free',
      isEuAllergen: true,
      uiGroup: 'seafood',
      priority: 6,
    ),
    _allergen(
      key: 'trädnötter',
      triggerProperties: ['tree-nut'],
      containsTagSv: 'innehåller-trädnötter',
      freeTagSv: 'trädnötsfri',
      containsTagEn: 'contains-tree-nuts',
      freeTagEn: 'tree-nut-free',
      isEuAllergen: true,
      uiGroup: 'nuts',
      priority: 7,
    ),
    _allergen(
      key: 'jordnötter',
      triggerProperties: ['peanut'],
      containsTagSv: 'innehåller-jordnötter',
      freeTagSv: 'jordnötsfri',
      containsTagEn: 'contains-peanuts',
      freeTagEn: 'peanut-free',
      isEuAllergen: true,
      uiGroup: 'nuts',
      priority: 8,
    ),
    _allergen(
      key: 'soja',
      triggerProperties: ['soy'],
      containsTagSv: 'innehåller-soja',
      freeTagSv: 'sojafri',
      containsTagEn: 'contains-soy',
      freeTagEn: 'soy-free',
      isEuAllergen: true,
      priority: 9,
    ),
    _allergen(
      key: 'sesam',
      triggerProperties: ['sesame'],
      containsTagSv: 'innehåller-sesam',
      freeTagSv: 'sesamfri',
      containsTagEn: 'contains-sesame',
      freeTagEn: 'sesame-free',
      isEuAllergen: true,
      priority: 10,
    ),
    _allergen(
      key: 'selleri',
      triggerProperties: ['celery'],
      containsTagSv: 'innehåller-selleri',
      freeTagSv: 'sellerifri',
      containsTagEn: 'contains-celery',
      freeTagEn: 'celery-free',
      isEuAllergen: true,
      priority: 11,
    ),
    _allergen(
      key: 'senap',
      triggerProperties: ['mustard'],
      containsTagSv: 'innehåller-senap',
      freeTagSv: 'senapfri',
      containsTagEn: 'contains-mustard',
      freeTagEn: 'mustard-free',
      isEuAllergen: true,
      priority: 12,
    ),
    _allergen(
      key: 'lupin',
      triggerProperties: ['lupin'],
      containsTagSv: 'innehåller-lupin',
      freeTagSv: 'lupinfri',
      containsTagEn: 'contains-lupin',
      freeTagEn: 'lupin-free',
      isEuAllergen: true,
      priority: 13,
    ),
    _allergen(
      key: 'sulfiter',
      triggerProperties: ['sulfites'],
      containsTagSv: 'innehåller-sulfiter',
      freeTagSv: 'sulfitfri',
      containsTagEn: 'contains-sulfites',
      freeTagEn: 'sulfite-free',
      isEuAllergen: true,
      priority: 14,
    ),
    // Additional allergens
    _allergen(
      key: 'laktos',
      triggerProperties: ['contains-lactose'],
      containsTagSv: 'innehåller-laktos',
      freeTagSv: 'laktosfri',
      containsTagEn: 'contains-lactose',
      freeTagEn: 'lactose-free',
      uiGroup: 'dairy',
      descriptionSv:
          'Mjölksocker. Mjölkfri ≠ laktosfri (laktosfria produkter innehåller mjölkprotein).',
      priority: 15,
    ),
    _allergen(
      key: 'alkohol',
      triggerProperties: ['contains-alcohol'],
      containsTagSv: 'innehåller-alkohol',
      freeTagSv: 'alkoholfri',
      containsTagEn: 'contains-alcohol',
      freeTagEn: 'alcohol-free',
      priority: 16,
    ),
    _allergen(
      key: 'kött',
      triggerProperties: ['meat'],
      containsTagSv: 'innehåller-kött',
      freeTagSv: 'köttfri',
      containsTagEn: 'contains-meat',
      freeTagEn: 'meat-free',
      uiGroup: 'meat',
      descriptionSv:
          'Allt kött (nöt, fläsk, kyckling, etc.). Se även vegetarisk.',
      priority: 17,
    ),
    _allergen(
      key: 'fläsk',
      triggerProperties: ['pork'],
      containsTagSv: 'innehåller-fläsk',
      freeTagSv: 'fläskfri',
      containsTagEn: 'contains-pork',
      freeTagEn: 'pork-free',
      uiGroup: 'meat',
      priority: 18,
    ),
    _allergen(
      key: 'nötkött',
      triggerProperties: ['beef'],
      containsTagSv: 'innehåller-nötkött',
      freeTagSv: 'nötkötsfri',
      containsTagEn: 'contains-beef',
      freeTagEn: 'beef-free',
      uiGroup: 'meat',
      priority: 19,
    ),
    // Combined allergens
    _allergen(
      key: 'skaldjur',
      triggerProperties: ['crustacean', 'mollusc'],
      containsTagSv: 'innehåller-skaldjur',
      freeTagSv: 'skaldjursfri',
      containsTagEn: 'contains-shellfish',
      freeTagEn: 'shellfish-free',
      uiGroup: 'seafood',
      priority: 20,
    ),
    _allergen(
      key: 'nötter',
      triggerProperties: ['tree-nut', 'peanut'],
      containsTagSv: 'innehåller-nötter',
      freeTagSv: 'nötfri',
      containsTagEn: 'contains-nuts',
      freeTagEn: 'nut-free',
      uiGroup: 'nuts',
      priority: 21,
    ),
  ];

  final document = {
    'schemaVersion': 1,
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'updatedBy': 'migration-script',
    'displayOrder': allergens.map((a) => a['key']).toList(),
    'entries': allergens,
  };

  await _writeJson(outputDir, 'allergens.json', document);
  print('  - ${allergens.length} allergens migrated');
}

Map<String, dynamic> _allergen({
  required String key,
  required List<String> triggerProperties,
  required String containsTagSv,
  String? freeTagSv,
  required String containsTagEn,
  String? freeTagEn,
  bool isEuAllergen = false,
  String? uiGroup,
  String? descriptionSv,
  required int priority,
}) {
  return {
    'key': key,
    'triggerProperties': triggerProperties,
    'tags': {
      'sv': {
        'contains': containsTagSv,
        if (freeTagSv != null) 'free': freeTagSv,
      },
      'en': {
        'contains': containsTagEn,
        if (freeTagEn != null) 'free': freeTagEn,
      },
    },
    'isEuAllergen': isEuAllergen,
    if (uiGroup != null) 'uiGroup': uiGroup,
    'description': {
      if (descriptionSv != null) 'sv': descriptionSv,
    },
    'enabled': true,
    'priority': priority,
  };
}

Future<void> _migrateDietary(Directory outputDir) async {
  print('Migrating dietary...');

  final dietary = [
    _dietary(
      key: 'vegetarisk',
      tagSv: 'vegetarisk',
      tagEn: 'vegetarian',
      excludedProperties: ['meat', 'seafood'],
      descriptionSv: 'Ingen ingrediens har kött eller fisk/skaldjur',
      priority: 1,
    ),
    _dietary(
      key: 'vegansk',
      tagSv: 'vegansk',
      tagEn: 'vegan',
      excludedProperties: ['animal-product'],
      descriptionSv: 'Ingen ingrediens har animaliska produkter',
      priority: 2,
    ),
    _dietary(
      key: 'pescetarian',
      tagSv: 'pescetarian',
      tagEn: 'pescetarian',
      excludedProperties: ['meat'],
      requiredProperties: ['fish', 'crustacean', 'mollusc'],
      descriptionSv: 'Ingen kött + minst en fisk/skaldjur',
      priority: 3,
    ),
    _dietary(
      key: 'graviditetssäker',
      tagSv: 'graviditetssäker',
      tagEn: 'pregnancy-safe',
      excludedProperties: ['high-mercury', 'contains-alcohol'],
      descriptionSv: 'Undvik stor rovfisk och alkohol',
      priority: 4,
    ),
    _dietary(
      key: 'barnvänlig',
      tagSv: 'barnvänlig',
      tagEn: 'kid-friendly',
      excludedProperties: ['is-spicy', 'contains-alcohol'],
      descriptionSv: 'Ej starkt, ej alkohol',
      priority: 5,
    ),
    _dietary(
      key: 'halalanpassad',
      tagSv: 'halalanpassad',
      tagEn: 'halal-friendly',
      excludedProperties: ['pork', 'contains-alcohol'],
      descriptionSv: 'Ej fläsk, ej alkohol',
      priority: 6,
    ),
    _dietary(
      key: 'kosheranpassad',
      tagSv: 'kosheranpassad',
      tagEn: 'kosher-friendly',
      excludedProperties: ['pork', 'crustacean', 'mollusc'],
      descriptionSv: 'Ej fläsk, ej skaldjur',
      priority: 7,
    ),
    _dietary(
      key: 'nötkötsfri',
      tagSv: 'nötkötsfri',
      tagEn: 'beef-free',
      excludedProperties: ['beef'],
      descriptionSv: 'Ej nötkött',
      priority: 8,
    ),
    _dietary(
      key: 'aip-vänlig',
      tagSv: 'aip-vänlig',
      tagEn: 'aip-friendly',
      excludedProperties: [
        'nightshade',
        'contains-gluten',
        'dairy',
        'egg',
        'soy',
        'peanut',
        'tree-nut',
        'contains-alcohol',
      ],
      descriptionSv:
          'Autoimmun protokoll - inga nattskuggväxter eller vanliga allergener',
      priority: 9,
    ),
  ];

  final document = {
    'schemaVersion': 1,
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'updatedBy': 'migration-script',
    'displayOrder': dietary.map((d) => d['key']).toList(),
    'entries': dietary,
  };

  await _writeJson(outputDir, 'dietary.json', document);
  print('  - ${dietary.length} dietary statuses migrated');
}

Map<String, dynamic> _dietary({
  required String key,
  required String tagSv,
  required String tagEn,
  required List<String> excludedProperties,
  List<String>? requiredProperties,
  bool requiresFullCoverage = true,
  required String descriptionSv,
  required int priority,
}) {
  return {
    'key': key,
    'tags': {'sv': tagSv, 'en': tagEn},
    'excludedProperties': excludedProperties,
    if (requiredProperties != null) 'requiredProperties': requiredProperties,
    'requiresFullCoverage': requiresFullCoverage,
    'description': {'sv': descriptionSv},
    'enabled': true,
    'priority': priority,
  };
}

Future<void> _migrateCuisines(Directory outputDir) async {
  print('Migrating cuisines...');

  final cuisines = [
    _cuisine(
      key: 'svensk',
      tagSv: 'svensk',
      tagEn: 'swedish',
      titleKeywords: [
        'svensk',
        'husmanskost',
        'köttbullar',
        'janssons',
        'falukorv',
        'pannkakor',
        'kroppkakor',
        'pitepalt',
        'raggmunk',
      ],
      ingredientKeywords: [
        'lingon',
        'dill',
        'gräddsås',
        'rårörda lingon',
        'falukorv',
        'isterband',
        'prinskorv',
      ],
      priority: 1,
    ),
    _cuisine(
      key: 'nordisk',
      tagSv: 'nordisk',
      tagEn: 'nordic',
      titleKeywords: [
        'nordisk',
        'scandinavian',
        'nordic',
        'gravad',
        'smørrebrød',
      ],
      ingredientKeywords: [
        'gravad lax',
        'dill',
        'rågbröd',
        'lingon',
        'hjortron',
      ],
      priority: 2,
    ),
    _cuisine(
      key: 'italiensk',
      tagSv: 'italiensk',
      tagEn: 'italian',
      titleKeywords: [
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
      ],
      ingredientKeywords: [
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
      ],
      ingredientGroups: ['grain/pasta-bread'],
      priority: 3,
    ),
    _cuisine(
      key: 'grekisk',
      tagSv: 'grekisk',
      tagEn: 'greek',
      titleKeywords: [
        'grekisk',
        'greek',
        'moussaka',
        'tzatziki',
        'souvlaki',
        'gyros',
      ],
      ingredientKeywords: [
        'feta',
        'fetaost',
        'oregano',
        'olivolja',
        'tzatziki',
        'pita',
      ],
      priority: 4,
    ),
    _cuisine(
      key: 'spansk',
      tagSv: 'spansk',
      tagEn: 'spanish',
      titleKeywords: [
        'spansk',
        'spanish',
        'paella',
        'tapas',
        'gazpacho',
        'tortilla española',
      ],
      ingredientKeywords: [
        'saffran',
        'chorizo',
        'paprika',
        'manchego',
        'serrano',
        'pimentón',
      ],
      priority: 5,
    ),
    _cuisine(
      key: 'fransk',
      tagSv: 'fransk',
      tagEn: 'french',
      titleKeywords: [
        'fransk',
        'french',
        'coq au vin',
        'bouillabaisse',
        'ratatouille',
        'quiche',
        'crème brûlée',
        'croissant',
      ],
      ingredientKeywords: [
        'dijonsenap',
        'estragon',
        'gruyère',
        'brie',
        'camembert',
        'crème fraîche',
        'dragon',
      ],
      priority: 6,
    ),
    _cuisine(
      key: 'medelhavsmat',
      tagSv: 'medelhavsmat',
      tagEn: 'mediterranean',
      titleKeywords: ['medelhavs', 'mediterranean'],
      ingredientKeywords: [
        'olivolja',
        'citron',
        'vitlök',
        'rosmarin',
        'timjan',
        'kapris',
        'kronärtskocka',
      ],
      minIngredientMatches: 3,
      priority: 7,
    ),
    _cuisine(
      key: 'thailändsk',
      tagSv: 'thailändsk',
      tagEn: 'thai',
      titleKeywords: [
        'thailändsk',
        'thai',
        'pad thai',
        'tom yum',
        'tom kha',
        'massaman',
        'panang',
      ],
      ingredientKeywords: [
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
      ],
      priority: 8,
    ),
    _cuisine(
      key: 'indisk',
      tagSv: 'indisk',
      tagEn: 'indian',
      titleKeywords: [
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
      ],
      ingredientKeywords: [
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
      ],
      priority: 9,
    ),
    _cuisine(
      key: 'kinesisk',
      tagSv: 'kinesisk',
      tagEn: 'chinese',
      titleKeywords: [
        'kinesisk',
        'chinese',
        'dim sum',
        'wok',
        'stir fry',
        'kung pao',
        'sweet and sour',
      ],
      ingredientKeywords: [
        'sojasås',
        'ingefära',
        'sesamolja',
        'hoisin',
        'ostronsås',
        'böngroddar',
        'szechuan',
        'femkrydda',
        'tofu',
      ],
      priority: 10,
    ),
    _cuisine(
      key: 'japansk',
      tagSv: 'japansk',
      tagEn: 'japanese',
      titleKeywords: [
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
      ],
      ingredientKeywords: [
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
      ],
      priority: 11,
    ),
    _cuisine(
      key: 'koreansk',
      tagSv: 'koreansk',
      tagEn: 'korean',
      titleKeywords: [
        'koreansk',
        'korean',
        'kimchi',
        'bibimbap',
        'bulgogi',
        'japchae',
      ],
      ingredientKeywords: [
        'kimchi',
        'gochujang',
        'gochugaru',
        'sesamolja',
        'koreansk chili',
        'doenjang',
      ],
      priority: 12,
    ),
    _cuisine(
      key: 'vietnamesisk',
      tagSv: 'vietnamesisk',
      tagEn: 'vietnamese',
      titleKeywords: [
        'vietnamesisk',
        'vietnamese',
        'pho',
        'bahn mi',
        'banh mi',
        'spring rolls',
      ],
      ingredientKeywords: [
        'fisksås',
        'risnudlar',
        'mynta',
        'koriander',
        'citrongräs',
        'böngroddar',
        'sriracha',
        'hoisin',
      ],
      priority: 13,
    ),
    _cuisine(
      key: 'asiatisk',
      tagSv: 'asiatisk',
      tagEn: 'asian',
      titleKeywords: ['asiatisk', 'asian', 'wok'],
      ingredientKeywords: [
        'sojasås',
        'sesamolja',
        'ingefära',
        'risnudlar',
        'tofu',
        'böngroddar',
      ],
      minIngredientMatches: 3,
      priority: 14,
    ),
    _cuisine(
      key: 'mexikansk',
      tagSv: 'mexikansk',
      tagEn: 'mexican',
      titleKeywords: [
        'mexikansk',
        'mexican',
        'taco',
        'burrito',
        'enchilada',
        'quesadilla',
        'fajita',
        'nachos',
        'guacamole',
      ],
      ingredientKeywords: [
        'jalapeño',
        'chipotle',
        'koriander',
        'limejuice',
        'avokado',
        'tortilla',
        'svarta bönor',
        'majs',
        'cheddar',
      ],
      priority: 15,
    ),
    _cuisine(
      key: 'amerikansk',
      tagSv: 'amerikansk',
      tagEn: 'american',
      titleKeywords: [
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
      ],
      ingredientKeywords: [
        'cheddar',
        'bacon',
        'bbq-sås',
        'ranch',
        'majssirap',
      ],
      priority: 16,
    ),
    _cuisine(
      key: 'mellanöstern',
      tagSv: 'mellanöstern',
      tagEn: 'middle-eastern',
      titleKeywords: [
        'mellanöstern',
        'middle eastern',
        'libanesisk',
        'falafel',
        'hummus',
        'shawarma',
        'kebab',
        'tabbouleh',
        'fattoush',
      ],
      ingredientKeywords: [
        'tahini',
        'hummus',
        'granatäpple',
        'sumak',
        "za'atar",
        'zaatar',
        'bulgur',
        'kikärtor',
        'pitabröd',
      ],
      priority: 17,
    ),
    _cuisine(
      key: 'etiopisk',
      tagSv: 'etiopisk',
      tagEn: 'ethiopian',
      titleKeywords: [
        'etiopisk',
        'ethiopian',
        'injera',
        'doro wat',
        'kitfo',
      ],
      ingredientKeywords: [
        'berbere',
        'injera',
        'niter kibbeh',
        'teff',
        'mitmita',
        'korarima',
      ],
      priority: 18,
    ),
    _cuisine(
      key: 'marockansk',
      tagSv: 'marockansk',
      tagEn: 'moroccan',
      titleKeywords: [
        'marockansk',
        'moroccan',
        'tagine',
        'couscous',
        'pastilla',
        'harira',
      ],
      ingredientKeywords: [
        'ras el hanout',
        'couscous',
        'bevarad citron',
        'harissa',
        'arganölja',
        'koriander',
        'spiskummin',
        'kanel',
        'dadlar',
      ],
      priority: 19,
    ),
    _cuisine(
      key: 'brasiliansk',
      tagSv: 'brasiliansk',
      tagEn: 'brazilian',
      titleKeywords: [
        'brasiliansk',
        'brazilian',
        'feijoada',
        'picanha',
        'coxinha',
        'pão de queijo',
        'açaí',
      ],
      ingredientKeywords: [
        'farofa',
        'svarta bönor',
        'palmhjärta',
        'cassava',
        'maniok',
        'guarana',
        'dendéolja',
      ],
      priority: 20,
    ),
    _cuisine(
      key: 'peruansk',
      tagSv: 'peruansk',
      tagEn: 'peruvian',
      titleKeywords: [
        'peruansk',
        'peruvian',
        'ceviche',
        'lomo saltado',
        'aji de gallina',
        'causa',
      ],
      ingredientKeywords: [
        'ají amarillo',
        'quinoa',
        'huacatay',
        'rocoto',
        'limo chili',
        'purple majskorn',
      ],
      priority: 21,
    ),
    _cuisine(
      key: 'argentinsk',
      tagSv: 'argentinsk',
      tagEn: 'argentinian',
      titleKeywords: [
        'argentinsk',
        'argentinian',
        'asado',
        'empanada',
        'choripan',
        'milanesa',
      ],
      ingredientKeywords: [
        'chimichurri',
        'dulce de leche',
        'provolone',
        'chorizo argentino',
        'oregano',
        'persilja',
        'vitlök',
      ],
      priority: 22,
    ),
  ];

  final document = {
    'schemaVersion': 1,
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'updatedBy': 'migration-script',
    'displayOrder': cuisines.map((c) => c['key']).toList(),
    'entries': cuisines,
  };

  await _writeJson(outputDir, 'cuisines.json', document);
  print('  - ${cuisines.length} cuisines migrated');
}

Map<String, dynamic> _cuisine({
  required String key,
  required String tagSv,
  required String tagEn,
  List<String> titleKeywords = const [],
  List<String> ingredientKeywords = const [],
  List<String> ingredientGroups = const [],
  int minIngredientMatches = 2,
  required int priority,
}) {
  return {
    'key': key,
    'tags': {'sv': tagSv, 'en': tagEn},
    'titleKeywords': titleKeywords,
    'ingredientKeywords': ingredientKeywords,
    'ingredientGroups': ingredientGroups,
    'minIngredientMatches': minIngredientMatches,
    'matchMode': 'title_or_ingredients',
    'titleMatchWeight': 1.0,
    'ingredientMatchWeight': 1.0,
    'enabled': true,
    'priority': priority,
  };
}

Future<void> _migrateProperties(Directory outputDir) async {
  print('Migrating properties...');

  final validProperties = [
    // Allergens (EU mandatory 14)
    'dairy',
    'egg',
    'fish',
    'crustacean',
    'mollusc',
    'peanut',
    'tree-nut',
    'wheat',
    'contains-gluten',
    'soy',
    'sesame',
    'celery',
    'mustard',
    'lupin',
    'sulfites',
    // Lactose (separate from dairy protein)
    'contains-lactose',
    // Meat types
    'meat',
    'pork',
    'beef',
    'poultry',
    'lamb',
    'game',
    // Seafood
    'seafood',
    'high-mercury',
    // Other animal products
    'animal-product',
    // Diet-related
    'contains-alcohol',
    'is-spicy',
    'plant-based',
    // Special diet properties
    'nightshade',
    // Practical
    'doesnt-freeze-well',
    'raw-safe',
  ];

  final document = {
    'schemaVersion': 1,
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'updatedBy': 'migration-script',
    'validProperties': validProperties..sort(),
  };

  await _writeJson(outputDir, 'properties.json', document);
  print('  - ${validProperties.length} properties migrated');
}

Future<void> _migrateDisplay(Directory outputDir) async {
  print('Migrating display config...');

  final document = {
    'schemaVersion': 1,
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'updatedBy': 'migration-script',
    'categoryOrder': [
      'allergens',
      'dietary',
      'proteins',
      'cuisines',
      'time',
      'cooking-method',
    ],
    'uiGroupNames': {
      'sv': {
        'dairy': 'Mjölk & Laktos',
        'nuts': 'Nötter',
        'seafood': 'Fisk & Skaldjur',
        'meat': 'Kött',
      },
      'en': {
        'dairy': 'Dairy & Lactose',
        'nuts': 'Nuts',
        'seafood': 'Fish & Shellfish',
        'meat': 'Meat',
      },
    },
  };

  await _writeJson(outputDir, 'display.json', document);
  print('  - Display config migrated');
}

Future<void> _writeJson(
  Directory outputDir,
  String filename,
  Map<String, dynamic> document,
) async {
  final file = File('${outputDir.path}/$filename');
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(document));
}
