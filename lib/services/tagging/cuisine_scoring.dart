import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';
import 'package:butlery/services/tagging/title_keyword_rules.dart';

/// One cuisine as the scoring sees it, from the repo config or from the
/// Firestore copy of it.
typedef CuisineCandidate = ({
  String tag,
  Iterable<String> titleKeywords,
  Iterable<String> ingredientKeywords,
  Iterable<String> ingredientGroups,
  int minIngredientMatches,
  CuisineMatchMode matchMode,
});

/// Picks a recipe's cuisines by points (Malin 2026-10-30, kärnflöde steg 5
/// beslut 4): the title counts most, a word that does not belong in the
/// cuisine rules it out, and a recipe gets at most two.
abstract final class CuisineScoring {
  static const maxCuisines = 2;
  static const titlePoints = 3;
  static const schemaPoints = 2;
  static const ingredientPoints = 1;

  /// Words that rule a cuisine out when they appear in an ingredient or the
  /// title, from the Drive sheet "Butlery TagRules v1.0", CuisineRules.
  static const negativeKeywords = <String, List<String>>{
    'svensk': ['sojasås', 'taco', 'wok'],
    'italiensk': ['sojasås', 'ingefära'],
    'mexikansk': ['sojasås', 'pasta'],
    'thailändsk': ['parmesan'],
    'indisk': ['sojasås', 'pasta'],
    'kinesisk': ['parmesan', 'fisksås'],
    'japansk': ['parmesan', 'fisksås'],
    'koreansk': ['parmesan', 'pasta'],
    'vietnamesisk': ['parmesan'],
    'grekisk': ['sojasås'],
    'medelhavsmat': ['sojasås', 'grädde'],
    'mellanöstern': ['sojasås'],
    'fransk': ['sojasås'],
    'spansk': ['sojasås'],
    'nordisk': ['sojasås', 'chili'],
    'asiatisk': ['parmesan', 'grädde'],
  };

  /// Cuisines that name a region rather than one kitchen; on equal points the
  /// specific one comes first.
  static const generalCuisines = {'asiatisk', 'medelhavsmat'};

  /// [candidates] in priority order: on equal points an earlier one wins.
  ///
  /// Below [TaggingThresholds.cuisineAndMoodCoverage] the ingredients give no
  /// points, so only the title or the recipe's own cuisine can name one:
  /// pasta and tomato beside two unknown lines are not Italian on their own
  /// (Malin 2026-10-30, kärnflöde steg 5 beslut 5). A negative word still
  /// rules a cuisine out.
  static Set<String> detect(
    Recipe recipe,
    IngredientLookupResult lookup,
    List<CuisineCandidate> candidates,
  ) {
    final ingredientsCount =
        lookup.coverage >= TaggingThresholds.cuisineAndMoodCoverage;
    final title = recipe.core.title.toLowerCase();
    final names = [for (final i in lookup.matched) i.swedish.toLowerCase()];
    final schema = recipe.cuisine?.toLowerCase();

    final scored = <(CuisineCandidate, int)>[];
    for (final cuisine in candidates) {
      final negatives = negativeKeywords[cuisine.tag] ?? const [];
      final ruledOut = negatives.any(
        (w) =>
            TitleKeywordRules.titleHasWord(title, w) ||
            names.any((n) => TitleKeywordRules.titleHasWord(n, w)),
      );
      if (ruledOut) continue;

      final titleHit = cuisine.titleKeywords.any(
        (kw) => title.contains(kw.toLowerCase()),
      );
      final schemaHit =
          schema != null &&
          schema.isNotEmpty &&
          cuisine.titleKeywords.any((kw) => schema.contains(kw.toLowerCase()));
      final ingredientHits = ingredientsCount
          ? _ingredientHits(cuisine, lookup)
          : 0;

      final ingredientMatch =
          ingredientsCount && ingredientHits >= cuisine.minIngredientMatches;
      final eligible =
          schemaHit ||
          switch (cuisine.matchMode) {
            CuisineMatchMode.titleOnly => titleHit,
            CuisineMatchMode.ingredientsOnly => ingredientMatch,
            CuisineMatchMode.titleAndIngredients => titleHit && ingredientMatch,
            CuisineMatchMode.titleOrIngredients => titleHit || ingredientMatch,
          };
      if (!eligible) continue;
      scored.add((
        cuisine,
        (titleHit ? titlePoints : 0) +
            (schemaHit ? schemaPoints : 0) +
            ingredientHits * ingredientPoints,
      ));
    }

    scored.sort((a, b) {
      final byPoints = b.$2.compareTo(a.$2);
      if (byPoints != 0) return byPoints;
      final aGeneral = generalCuisines.contains(a.$1.tag) ? 1 : 0;
      final bGeneral = generalCuisines.contains(b.$1.tag) ? 1 : 0;
      if (aGeneral != bGeneral) return aGeneral - bGeneral;
      return candidates.indexOf(a.$1).compareTo(candidates.indexOf(b.$1));
    });
    return {for (final (c, _) in scored.take(maxCuisines)) c.tag};
  }

  /// Matched ingredients that name or group-match the cuisine; one ingredient
  /// counts once even when both its name and its group match.
  static int _ingredientHits(
    CuisineCandidate cuisine,
    IngredientLookupResult lookup,
  ) => lookup.matched.where((i) {
    final name = i.swedish.toLowerCase();
    final group = i.group.toLowerCase();
    return cuisine.ingredientKeywords.any(
          (kw) => name.contains(kw.toLowerCase()),
        ) ||
        cuisine.ingredientGroups.any((g) => group.contains(g.toLowerCase()));
  }).length;
}
