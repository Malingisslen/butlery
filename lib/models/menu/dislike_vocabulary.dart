// lib/models/menu/dislike_vocabulary.dart

import 'package:butlery/models/recipe_unified.dart';

/// Which ingredient words each disliked-ingredient chip in the family form
/// stands for (BUT-1625). A dislike is a soft taste preference: this table
/// decides where the weekly menu places a dish, never whether a dish is
/// safe, and nothing here may be read as allergen data.
///
/// Words are matched against whole tokens of a recipe's ingredient lines,
/// lower-cased and split on anything that is not a letter, so "vitlök" is
/// one token and never matches "lök". [_DislikeTerms.prefixes] catch
/// inflections and compounds that start with the word ("tomatpuré",
/// "champinjoner").
class DislikeVocabulary {
  const DislikeVocabulary._();

  static const Map<String, _DislikeTerms> _terms = {
    'svamp': _DislikeTerms(
      prefixes: [
        'svamp',
        'champinjon',
        'kantarell',
        'karljohan',
        'shiitake',
        'portabello',
        'portobello',
        'murkl',
        'ostronskivling',
        'trattkantarell',
      ],
      exact: ['skogssvamp', 'skogssvampar'],
    ),
    'lök': _DislikeTerms(
      prefixes: ['lök'],
      exact: [
        'rödlök',
        'rödlökar',
        'gullök',
        'gullökar',
        'schalottenlök',
        'schalottenlökar',
        'silverlök',
        'syltlök',
        'purjolök',
        'purjolökar',
        'salladslök',
        'salladslökar',
      ],
    ),
    'vitlök': _DislikeTerms(prefixes: ['vitlök']),
    // Never a prefix: "olivolja" is not an olive.
    'oliver': _DislikeTerms(
      exact: ['oliv', 'oliven', 'oliver', 'oliverna', 'kalamataoliver'],
    ),
    'koriander': _DislikeTerms(prefixes: ['koriander']),
    'tomat': _DislikeTerms(
      prefixes: ['tomat'],
      exact: ['körsbärstomat', 'körsbärstomater', 'plommontomater'],
    ),
    // The vegetable. Paprikapulver and rökt paprika are a spice, and a
    // child who will not eat paprika strips does not taste them.
    'paprika': _DislikeTerms(
      exact: ['paprika', 'paprikor', 'paprikan', 'paprikorna'],
      unlessFollowedBy: ['pulver'],
      unlessPrecededBy: ['rökt', 'söt', 'stark'],
    ),
    'aubergine': _DislikeTerms(prefixes: ['aubergin']),
    'rödbetor': _DislikeTerms(prefixes: ['rödbet']),
    'blåmögelost': _DislikeTerms(
      prefixes: ['blåmögel', 'gorgonzola', 'roquefort', 'ädelost'],
    ),
    'lever': _DislikeTerms(prefixes: ['lever', 'kycklinglever']),
    'inlagd sill': _DislikeTerms(prefixes: ['sill', 'matjessill']),
    // Heat is the dislike, so the dried and bottled forms count too.
    'chili': _DislikeTerms(
      prefixes: ['chili', 'jalapeño', 'jalapeno', 'sriracha', 'sambal'],
    ),
    'russin': _DislikeTerms(prefixes: ['russin']),
  };

  /// Every chip key this table knows.
  static Iterable<String> get keys => _terms.keys;

  /// Whether any ingredient line of [recipe] contains an ingredient one of
  /// [dislikeKeys] stands for. An unknown key matches nothing.
  static bool recipeContainsAny(Recipe recipe, Set<String> dislikeKeys) {
    if (dislikeKeys.isEmpty) return false;
    final terms = [for (final key in dislikeKeys) ?_terms[key]];
    if (terms.isEmpty) return false;
    for (final line in recipe.ingredients) {
      final tokens = _tokens(line);
      for (final t in terms) {
        if (t.matches(tokens)) return true;
      }
    }
    return false;
  }

  static final RegExp _nonLetter = RegExp(r'[^a-zåäöéèüñ]+');

  static List<String> _tokens(String line) =>
      line.toLowerCase().split(_nonLetter).where((t) => t.isNotEmpty).toList();
}

class _DislikeTerms {
  const _DislikeTerms({
    this.prefixes = const [],
    this.exact = const [],
    this.unlessFollowedBy = const [],
    this.unlessPrecededBy = const [],
  });

  final List<String> prefixes;
  final List<String> exact;

  /// A match is void when the next token starts with one of these
  /// ("paprika pulver" written apart).
  final List<String> unlessFollowedBy;

  /// A match is void when the previous token is one of these.
  final List<String> unlessPrecededBy;

  bool matches(List<String> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final hit =
          exact.contains(token) || prefixes.any((p) => token.startsWith(p));
      if (!hit) continue;
      if (i + 1 < tokens.length &&
          unlessFollowedBy.any((s) => tokens[i + 1].startsWith(s))) {
        continue;
      }
      if (i > 0 && unlessPrecededBy.contains(tokens[i - 1])) continue;
      return true;
    }
    return false;
  }
}
