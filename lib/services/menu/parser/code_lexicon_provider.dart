/// Sprint-1 seed lexicon. Sprint 2 (BUT-360) will overlay Google-Sheet data
/// from Firestore on top of these defaults via `Lexicon.mergedWith`.
///
/// All canonical values (right-hand sides) must exist in the corresponding
/// tagging configuration:
///   - dietaryStems → DietaryConfig.allKeys
///   - allergenFreeStems / allergenNounStems → AllergenConfig.allKeys
///   - cuisineStems → CuisineConfig keys
///   - mealStems → MealSlot mapping (lunch / middag / ovrigt buckets)
///   - formatStems / themeStems / verbObjectMap → free-form recipe tag set
///
/// `code_lexicon_provider_test.dart` enforces these invariants.
library;

import 'package:butlery/services/menu/parser/lexicon_provider.dart';

class CodeLexiconProvider implements LexiconProvider {
  const CodeLexiconProvider();

  @override
  Future<Lexicon> load() async => const Lexicon(_entries);

  static const Map<LexiconCategory, Map<String, String>> _entries = {
    LexiconCategory.numbers: _numbers,
    LexiconCategory.vagueQuantity: _vagueQuantity,
    LexiconCategory.everydayPhrases: _everydayPhrases,
    LexiconCategory.mealStems: _mealStems,
    LexiconCategory.dietaryStems: _dietaryStems,
    LexiconCategory.allergenFreeStems: _allergenFreeStems,
    LexiconCategory.allergenNounStems: _allergenNounStems,
    LexiconCategory.negationWords: _negationWords,
    LexiconCategory.cuisineStems: _cuisineStems,
    LexiconCategory.formatStems: _formatStems,
    LexiconCategory.verbObjectMap: _verbObjectMap,
    LexiconCategory.themeStems: _themeStems,
    LexiconCategory.timeKeywords: _timeKeywords,
    LexiconCategory.dayNames: _dayNames,
    LexiconCategory.dayIdioms: _dayIdioms,
    LexiconCategory.subdivisionWords: _subdivisionWords,
    LexiconCategory.politePreamble: _politePreamble,
    LexiconCategory.skipFrukostMarkers: _skipFrukostMarkers,
  };

  // Numbers — value is the integer as a string so the map type stays uniform.
  static const Map<String, String> _numbers = {
    'en': '1',
    'ett': '1',
    'två': '2',
    'tva': '2',
    'tre': '3',
    'fyra': '4',
    'fem': '5',
    'sex': '6',
    'sju': '7',
    'åtta': '8',
    'atta': '8',
    'nio': '9',
    'tio': '10',
    'elva': '11',
    'tolv': '12',
    'tretton': '13',
    'fjorton': '14',
    'femton': '15',
    'sexton': '16',
    'sjutton': '17',
    'arton': '18',
    'nitton': '19',
    'tjugo': '20',
  };

  static const Map<String, String> _vagueQuantity = {
    'några': '3',
    'nagra': '3',
    'ett par': '2',
    'par': '2',
    'en handfull': '3',
    'handfull': '3',
    'lite': '2',
    'flera': '3',
    'många': '5',
    'manga': '5',
  };

  static const Map<String, String> _everydayPhrases = {
    'varje dag': '7',
    'hela veckan': '7',
    'alla dagar': '7',
    'varannan dag': '4',
    'några dagar': '3',
    'helgen': '2',
    'vardagar': '5',
  };

  // Meal stems → canonical mealType key.
  // Targets the existing recipe.mealType strings ('frukost','lunch','middag',
  // 'dessert','mellanmål','fika','ovrigt'). Slang and English aliases roll up
  // to whichever bucket the user most likely meant.
  static const Map<String, String> _mealStems = {
    'frukost': 'frukost',
    'frukostar': 'frukost',
    'breakfast': 'frukost',
    'morgonmål': 'frukost',
    'morgonmal': 'frukost',
    'gröt': 'frukost',
    'grot': 'frukost',
    'lunch': 'lunch',
    'luncher': 'lunch',
    'lunches': 'lunch',
    'middag': 'middag',
    'middagar': 'middag',
    'dinner': 'middag',
    'dinners': 'middag',
    'kvällsmat': 'middag',
    'kvallsmat': 'middag',
    'kvällsmål': 'middag',
    'kvallsmal': 'middag',
    'kväll': 'middag',
    'kvall': 'middag',
    'dessert': 'dessert',
    'desserter': 'dessert',
    'mellanmål': 'mellanmål',
    'mellanmal': 'mellanmål',
    'mellis': 'mellanmål',
    'snack': 'mellanmål',
    'snacks': 'mellanmål',
    'fika': 'fika',
    'fikabröd': 'fika',
    'fikabrod': 'fika',
    'brunch': 'frukost',
    'rätt': 'middag',
    'ratt': 'middag',
    'rätter': 'middag',
    'ratter': 'middag',
    'recept': 'middag',
    'måltid': 'middag',
    'maltid': 'middag',
  };

  // Dietary stems → DietaryConfig keys: vegetarisk, vegansk, pescetarian,
  // graviditetssäker, barnvänlig.
  static const Map<String, String> _dietaryStems = {
    'vegansk': 'vegansk',
    'veganskt': 'vegansk',
    'vegana': 'vegansk',
    'vegan': 'vegansk',
    'växtbaserat': 'vegansk',
    'vaxtbaserat': 'vegansk',
    'växtbaserad': 'vegansk',
    'vaxtbaserad': 'vegansk',
    'plantbaserat': 'vegansk',
    'plantbaserad': 'vegansk',
    'vegetarisk': 'vegetarisk',
    'vegetariskt': 'vegetarisk',
    'vegetariska': 'vegetarisk',
    'vego': 'vegetarisk',
    'lakto-ovo': 'vegetarisk',
    'laktoovo': 'vegetarisk',
    'pescetarisk': 'pescetarian',
    'pescetariskt': 'pescetarian',
    'pescetarian': 'pescetarian',
    'gravid': 'graviditetssäker',
    'graviditetssäker': 'graviditetssäker',
    'graviditetssaker': 'graviditetssäker',
    'barnvänlig': 'barnvänlig',
    'barnvanlig': 'barnvänlig',
    'barnvänligt': 'barnvänlig',
    'barnvanligt': 'barnvänlig',
  };

  // Allergen-free stems → AllergenConfig keys (the stem expresses the
  // FREE-from semantic; values match `AllergenEntry.key`).
  static const Map<String, String> _allergenFreeStems = {
    'glutenfri': 'gluten',
    'glutenfritt': 'gluten',
    'glutenfria': 'gluten',
    'mjölkfri': 'mjölk',
    'mjolkfri': 'mjölk',
    'mjölkfritt': 'mjölk',
    'mjolkfritt': 'mjölk',
    'mjölkfria': 'mjölk',
    'mjolkfria': 'mjölk',
    'laktosfri': 'laktos',
    'laktosfritt': 'laktos',
    'laktosfria': 'laktos',
    'äggfri': 'ägg',
    'aggfri': 'ägg',
    'äggfritt': 'ägg',
    'aggfritt': 'ägg',
    'fiskfri': 'fisk',
    'fiskfritt': 'fisk',
    'sojafri': 'soja',
    'sojafritt': 'soja',
    'sesamfri': 'sesam',
    'sesamfritt': 'sesam',
    'kräftdjursfri': 'kräftdjur',
    'kraftdjursfri': 'kräftdjur',
    'blötdjursfri': 'blötdjur',
    'blotdjursfri': 'blötdjur',
    'trädnötsfri': 'trädnötter',
    'tradnotsfri': 'trädnötter',
    'jordnötsfri': 'jordnötter',
    'jordnotsfri': 'jordnötter',
    'nötfri': 'nötter',
    'notfri': 'nötter',
    'sellerifri': 'selleri',
    'senapsfri': 'senap',
    'lupinfri': 'lupin',
    'sulfitfri': 'sulfiter',
    'köttfri': 'kött',
    'kottfri': 'kött',
    'fläskfri': 'fläsk',
    'flaskfri': 'fläsk',
    'nötkötsfri': 'nötkött',
    'notkotsfri': 'nötkött',
    'alkoholfri': 'alkohol',
    'skaldjursfri': 'skaldjur',
  };

  // Allergen noun stems — used after a negation word ("inget jordnötter") or
  // preposition ("utan gluten"). Values are AllergenConfig keys.
  static const Map<String, String> _allergenNounStems = {
    'gluten': 'gluten',
    'mjölk': 'mjölk',
    'mjolk': 'mjölk',
    'laktos': 'laktos',
    'ägg': 'ägg',
    'agg': 'ägg',
    'fisk': 'fisk',
    'soja': 'soja',
    'sesam': 'sesam',
    'nötter': 'nötter',
    'notter': 'nötter',
    'nöt': 'nötter',
    'not': 'nötter',
    'jordnötter': 'jordnötter',
    'jordnotter': 'jordnötter',
    'jordnöt': 'jordnötter',
    'jordnot': 'jordnötter',
    'trädnötter': 'trädnötter',
    'tradnotter': 'trädnötter',
    'kräftdjur': 'kräftdjur',
    'kraftdjur': 'kräftdjur',
    'blötdjur': 'blötdjur',
    'blotdjur': 'blötdjur',
    'skaldjur': 'skaldjur',
    'selleri': 'selleri',
    'senap': 'senap',
    'lupin': 'lupin',
    'sulfiter': 'sulfiter',
    'sulfit': 'sulfiter',
    'kött': 'kött',
    'kott': 'kött',
    'fläsk': 'fläsk',
    'flask': 'fläsk',
    'nötkött': 'nötkött',
    'notkott': 'nötkött',
    'alkohol': 'alkohol',
  };

  // Negation triggers — the value is just the canonical form (rarely used).
  // Multi-word entries are handled by the parser before token splitting.
  static const Map<String, String> _negationWords = {
    'inget': 'inget',
    'ingen': 'inget',
    'inga': 'inget',
    'utan': 'inget',
    'undvik': 'inget',
    'undviker': 'inget',
    'slipper': 'inget',
    'vill inte ha': 'inget',
    'klarar inte': 'inget',
    'tål inte': 'inget',
    'tal inte': 'inget',
    'fritt från': 'inget',
    'fritt fran': 'inget',
    'inte': 'inget',
  };

  // Cuisines — values match CuisineEntry.key (svensk, italiensk, etc.).
  static const Map<String, String> _cuisineStems = {
    'svensk': 'svensk',
    'svenskt': 'svensk',
    'svenska': 'svensk',
    'nordisk': 'nordisk',
    'nordiskt': 'nordisk',
    'skandinavisk': 'nordisk',
    'italiensk': 'italiensk',
    'italienskt': 'italiensk',
    'italian': 'italiensk',
    'grekisk': 'grekisk',
    'grekiskt': 'grekisk',
    'spansk': 'spansk',
    'spanskt': 'spansk',
    'fransk': 'fransk',
    'franskt': 'fransk',
    'medelhav': 'medelhavsmat',
    'medelhavsmat': 'medelhavsmat',
    'thailändsk': 'thailandsk',
    'thailandsk': 'thailandsk',
    'thai': 'thailandsk',
    'indisk': 'indisk',
    'indiskt': 'indisk',
    'kinesisk': 'kinesisk',
    'kinesiskt': 'kinesisk',
    'japansk': 'japansk',
    'japanskt': 'japansk',
    'koreansk': 'koreansk',
    'koreanskt': 'koreansk',
    'vietnamesisk': 'vietnamesisk',
    'vietnamesiskt': 'vietnamesisk',
    'asiatisk': 'asiatisk',
    'asiatiskt': 'asiatisk',
    'asien': 'asiatisk',
    'mexikansk': 'mexikansk',
    'mexikanskt': 'mexikansk',
    'mexican': 'mexikansk',
    'amerikansk': 'amerikansk',
    'amerikanskt': 'amerikansk',
    'american': 'amerikansk',
    'mellanöstern': 'mellanoostern',
    'mellanostern': 'mellanoostern',
    'etiopisk': 'etiopisk',
    'etiopiskt': 'etiopisk',
    'marockansk': 'marockansk',
    'marockanskt': 'marockansk',
    'brasiliansk': 'brasiliansk',
    'brasilianskt': 'brasiliansk',
    'peruansk': 'peruansk',
    'peruanskt': 'peruansk',
    'argentinsk': 'argentinsk',
    'argentinskt': 'argentinsk',
  };

  // Format/recipe-shape stems — values are free-form tag strings the recipe
  // pool may or may not carry. Missing tags trigger a warning chip but don't
  // crash the parse.
  static const Map<String, String> _formatStems = {
    'soppa': 'soppa',
    'soppor': 'soppa',
    'sallad': 'sallad',
    'sallader': 'sallad',
    'gryta': 'gryta',
    'grytor': 'gryta',
    'gratäng': 'gratäng',
    'gratang': 'gratäng',
    'paj': 'paj',
    'pajer': 'paj',
    'pasta': 'pasta',
    'pizza': 'pizza',
    'wok': 'wok',
    'wokrätt': 'wok',
    'wokratt': 'wok',
    'poke': 'poke-bowl',
    'bowl': 'poke-bowl',
    'biff': 'biff',
    'bröd': 'bröd',
    'brod': 'bröd',
    'bullar': 'bröd',
    'pytt': 'pytt',
    'pannkakor': 'pannkakor',
    'tacos': 'tacos',
    'taco': 'tacos',
    'risotto': 'risotto',
    'lasagne': 'lasagne',
    'kyckling': 'kyckling',
    'fisk-rätt': 'fisk',
  };

  // Verb → required-tag (used in the second-pass sweep so "baka bröd" becomes
  // a constraint requiring the 'bröd' tag).
  static const Map<String, String> _verbObjectMap = {
    'baka': 'bröd',
    'grilla': 'grill',
    'grillar': 'grill',
    'grillat': 'grill',
    'wokar': 'wok',
    'steka': 'stekt',
  };

  // Theme tags — match against canonical recipe tag set; missing → warning.
  static const Map<String, String> _themeStems = {
    'vardagsmat': 'vardagsmiddag',
    'vardag': 'vardagsmiddag',
    'snabbmat': 'snabblagat',
    'snabb': 'snabblagat',
    'snabba': 'snabblagat',
    'snabblagat': 'snabblagat',
    'snabblagad': 'snabblagat',
    'festmat': 'helgmat',
    'fest': 'helgmat',
    'helgmat': 'helgmat',
    'helgmiddag': 'helgmat',
    'barnvänlig': 'barnvänlig',
    'barnvanlig': 'barnvänlig',
    'barnfamilj': 'barnvänlig',
    'billigt': 'budgetvänlig',
    'budget': 'budgetvänlig',
    'budgetvänligt': 'budgetvänlig',
    'budgetvanligt': 'budgetvänlig',
    'matlåda': 'meal-prep',
    'matlada': 'meal-prep',
    'matlådor': 'meal-prep',
    'matlador': 'meal-prep',
    'lunchlåda': 'meal-prep',
    'lunchlada': 'meal-prep',
  };

  // Time keywords — values are unused; presence triggers regex extraction.
  static const Map<String, String> _timeKeywords = {
    'min': 'min',
    'minut': 'min',
    'minuter': 'min',
    'timme': 'h',
    'timmar': 'h',
    'h': 'h',
  };

  // Day names → ISO weekday index as a string.
  static const Map<String, String> _dayNames = {
    'måndag': '1',
    'mandag': '1',
    'mån': '1',
    'man': '1',
    'tisdag': '2',
    'tis': '2',
    'onsdag': '3',
    'ons': '3',
    'torsdag': '4',
    'tor': '4',
    'fredag': '5',
    'fre': '5',
    'lördag': '6',
    'lordag': '6',
    'lör': '6',
    'lor': '6',
    'söndag': '7',
    'sondag': '7',
    'sön': '7',
    'son': '7',
    'monday': '1',
    'tuesday': '2',
    'wednesday': '3',
    'thursday': '4',
    'friday': '5',
    'saturday': '6',
    'sunday': '7',
  };

  // Day idioms → "weekday|tag|mealType" packed string. The parser splits
  // on '|' when it reads these. Cheaper than a custom value type and keeps
  // the lexicon shape uniform.
  static const Map<String, String> _dayIdioms = {
    'tacofredag': '5|tacos|middag',
    'fredagsmys': '5|fredagsmys|middag',
  };

  // Subdivision keywords — value side is unused; presence is the trigger.
  // Multi-word entries are matched before token splitting.
  static const Map<String, String> _subdivisionWords = {
    'varav': 'varav',
    'varav är': 'varav',
    'varav ar': 'varav',
    'där': 'varav',
    'dar': 'varav',
    'vilka': 'varav',
    'vilken': 'varav',
    'en av': 'varav',
    'två av': 'varav',
    'tre av': 'varav',
    'minst': 'soft',
    'helst': 'soft',
    'gärna': 'soft',
    'garna': 'soft',
    'den ena': 'pair_a',
    'den andra': 'pair_b',
  };

  // Polite preamble — stripped at head before parsing.
  static const Map<String, String> _politePreamble = {
    'hej': 'strip',
    'hello': 'strip',
    'hi': 'strip',
    'snälla': 'strip',
    'snalla': 'strip',
    'kan du': 'strip',
    'kan ni': 'strip',
    'vill du': 'strip',
    'vill ni': 'strip',
    'jag vill': 'strip',
    'vi vill': 'strip',
    'jag skulle vilja': 'strip',
    'planera': 'strip',
    'ge mig': 'strip',
    'ge oss': 'strip',
    'gör en': 'strip',
    'gor en': 'strip',
    'gör mig': 'strip',
    'gor mig': 'strip',
  };

  // Skip-frukost markers — substring presence in the prompt suppresses the
  // frukost slot entirely.
  static const Map<String, String> _skipFrukostMarkers = {
    'ingen frukost': 'skip',
    'hoppa över frukost': 'skip',
    'hoppa over frukost': 'skip',
    'skippa frukost': 'skip',
    '16:8': 'skip',
    'periodisk fasta': 'skip',
  };
}
