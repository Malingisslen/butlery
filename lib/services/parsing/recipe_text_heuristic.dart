// lib/services/parsing/recipe_text_heuristic.dart

/// BUT-1037: cheap, deterministic "does this pasted text look like a recipe?"
/// gate used to avoid spending a paid LLM call on clearly-non-recipe content
/// (a news article, a chat snippet, gibberish).
///
/// Pure + side-effect-free — no LLM, no network. Signals are measurement units
/// and cooking verbs in Swedish and English. The unit list is deliberately
/// wider than BUT-1037's Swedish-only sketch: a typical English recipe uses
/// `cups`/`tbsp`/`oz` (not `kopp`), so those are included or the EN-recipe
/// acceptance case would fail.
class RecipeTextHeuristic {
  const RecipeTextHeuristic._();

  /// Measurement units (sv + en), matched whole-word, case-insensitive.
  /// Single/short tokens (`g`, `dl`, `st`, `l`) rely on `\b` so they only fire
  /// as standalone amounts ("500 g"), never inside other words ("good").
  static final RegExp _measure = RegExp(
    r'\b('
    // Swedish + metric
    'gram|hg|kg|dl|cl|ml|l|tsk|msk|krm|kopp|koppar|portion|portioner|'
    'stycken|st|nypa|klyfta|klyftor|paket|burk|'
    // English imperial / volume
    'cup|cups|tbsp|tbsps|tablespoon|tablespoons|tsp|tsps|teaspoon|teaspoons|'
    'oz|ounce|ounces|lb|lbs|pound|pounds|pinch|'
    // bare gram last so the alternation prefers longer tokens first
    'g'
    r')\b',
    caseSensitive: false,
  );

  /// Cooking verbs (sv + en), matched as word-prefixes so Swedish inflections
  /// (`blanda`/`blandar`/`blanda`) and English forms (`mix`/`mixing`) both hit.
  static final RegExp _verb = RegExp(
    r'\b('
    // Swedish
    'blanda|rör|vispa|koka|sjud|stek|fräs|baka|grädda|värm|tillsätt|häll|'
    'skär|riv|mixa|mosa|smält|kavla|krydda|servera|garnera|'
    // English
    'mix|stir|whisk|boil|simmer|fry|saute|bake|roast|grill|cook|heat|add|'
    'pour|chop|slice|grate|blend|knead|season|serve|melt|preheat'
    r')\w*',
    caseSensitive: false,
  );

  /// Returns true when [text] has enough recipe signal to be worth an LLM
  /// parse: at least one measurement AND one cooking verb, OR ≥3 total signal
  /// hits (covers an ingredient-only paste with several amounts but no verbs).
  static bool looksLikeRecipe(String text) {
    if (text.trim().length < 10) return false;
    final measures = _measure.allMatches(text).length;
    final verbs = _verb.allMatches(text).length;
    if (measures >= 1 && verbs >= 1) return true;
    return measures + verbs >= 3;
  }
}
