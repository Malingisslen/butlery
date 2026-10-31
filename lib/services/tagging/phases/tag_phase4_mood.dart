import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/config/generated/occasion_vocabulary.g.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/title_keyword_rules.dart';

/// Phase 4: Mood and occasion tags requiring all previous phases.
///
/// The holiday, season and luxury WORDS come from `OccasionVocabulary`,
/// generated from `config/data/occasions.json`. The rules that combine them
/// stay here: how many matches a tag needs, the season threshold, the grill
/// and game bonuses, the Easter and midsummer combinations, and every time
/// and mood tag.
///
/// Generates:
/// - Time-based occasions (weeknight, weekend, quick-fix)
/// - Mood tags (comfort-food, warming, refreshing)
/// - Swedish holidays (christmas, midsummer, easter)
/// - Seasons (spring, summer, autumn, winter)
class TagPhase4Mood {
  /// MED-7: Configurable minimum seasonal ingredients required for season tag.
  /// Default is 2 (e.g., 2 summer ingredients = 'sommar' tag).
  final int seasonThreshold;

  /// Creates Phase 4 mood/occasion tag calculator.
  ///
  /// [seasonThreshold]: Minimum seasonal ingredients to trigger season tag.
  ///   Default: 2. Lower values are more permissive, higher values stricter.
  TagPhase4Mood({this.seasonThreshold = 2});

  /// Calculates Phase 4 tags.
  Phase4Result calculate(
    Phase1Result p1,
    Phase2Result p2,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};

    // Time-based occasions
    tags.addAll(_calculateTimeBasedTags(p1, p3, recipe));

    // Mood tags
    tags.addAll(_calculateMoodTags(p1, p2, p3, recipe));

    // Swedish holidays
    tags.addAll(_calculateSwedishHolidayTags(p1, recipe));

    // Seasons
    tags.addAll(_calculateSeasonTags(p1));

    return Phase4Result(
      tags: tags,
      phase1: p1,
      phase2: p2,
      phase3: p3,
    );
  }

  Set<String> _calculateTimeBasedTags(
    Phase1Result p1,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};
    final time = recipe.core.timeMinutes ?? 0;

    // Weeknight: under 45 min AND easy/medium
    if (p1.hasTag('under-45-min') &&
        (p3.hasTag('enkel') || p3.hasTag('medel'))) {
      tags.add('vardagsmiddag');
    }

    // Weekend: medium/advanced OR longer cooking
    if (p3.hasTag('medel') || p3.hasTag('avancerad') || time > 60) {
      tags.add('helgmat');
    }

    // Dinner party: advanced OR luxury ingredients
    if (p3.hasTag('avancerad') || _hasLuxuryIngredients(p1)) {
      tags.add('middagsbjudning');
    }

    // Quick fix: under 15 min AND easy
    if (p1.hasTag('under-15-min') && p3.hasTag('enkel')) {
      tags.add('snabblagat');
    }

    // Friday night
    if (p1.hasTag('taco') ||
        p1.hasTag('pizza') ||
        p1.hasTag('hamburgare') ||
        recipe.core.title.toLowerCase().contains('nachos')) {
      tags.add('fredagsmys');
    }

    // Sunday dinner
    if (time > 60 && (p1.hasTag('gryta') || p1.hasTag('ugnsbakad'))) {
      tags.add('söndagsmiddag');
    }

    return tags;
  }

  Set<String> _calculateMoodTags(
    Phase1Result p1,
    Phase2Result p2,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};

    // L8: Comfort food: creamy AND (pasta OR potato OR rice OR soup)
    // Added soppa for creamy soups which are classic comfort food
    if (p3.hasTag('krämig') &&
        (p1.hasTag('pastabaserad') ||
            p1.hasTag('potatisbaserad') ||
            p1.hasTag('risbaserad') ||
            p1.hasTag('soppa'))) {
      tags.add('comfort-food');
    }

    // Warming: soup OR stew OR hot + spiced
    if (p1.hasTag('soppa') || p1.hasTag('gryta')) {
      tags.add('värmande');
    }

    // Refreshing: salad OR cold + citrus
    if (p1.hasTag('sallad') ||
        (p3.hasTag('kall-rätt') && p1.lookup.hasGroup('fruit/citrus'))) {
      tags.add('fräsch');
    }

    // Luxurious: premium ingredients
    if (_hasLuxuryIngredients(p1)) {
      tags.add('lyxig');
    }

    return tags;
  }

  Set<String> _calculateSwedishHolidayTags(Phase1Result p1, Recipe recipe) {
    final tags = <String>{};
    final title = recipe.core.title.toLowerCase();
    bool titleHasAny(List<String> words) => words.any(title.contains);

    // The bare stem also sits inside words like "julienne", so only the stem
    // checks the false positives; a full title word does not.
    final hasTrueJul =
        title.contains(OccasionVocabulary.christmasTitleStem) &&
        !titleHasAny(OccasionVocabulary.christmasTitleStemFalsePositives);
    // A holiday comes from the title or from a pair of ingredients, never
    // from one ingredient alone (Malin 2026-10-30, beslut 6): lamb is not
    // Easter food by itself, nor lobster New Year's.
    final christmasPlate =
        _anyWordMatching(p1, OccasionVocabulary.christmasMainIngredients) &&
        _anyWordMatching(p1, OccasionVocabulary.christmasSideIngredients);
    if (hasTrueJul ||
        titleHasAny(OccasionVocabulary.christmasTitleWords) ||
        christmasPlate) {
      tags.add(OccasionVocabulary.christmasTag);
    }

    final saffronBake =
        _anyWordMatching(p1, OccasionVocabulary.luciaSaffronIngredients) &&
        // A bake word usually ends a compound ("saffransbullar"), so it
        // matches anywhere in the title.
        titleHasAny(OccasionVocabulary.luciaBakeTitleWords);
    if (titleHasAny(OccasionVocabulary.luciaTitleWords) || saffronBake) {
      tags.add(OccasionVocabulary.luciaTag);
    }

    final lamb = _anyWordMatching(p1, OccasionVocabulary.easterLambIngredients);
    final egg = _anyWordMatching(p1, OccasionVocabulary.easterEggIngredients);
    final herring = _anyWordMatching(
      p1,
      OccasionVocabulary.easterHerringIngredients,
    );
    if (titleHasAny(OccasionVocabulary.easterTitleWords) ||
        (lamb && (egg || herring)) ||
        (egg && herring)) {
      tags.add(OccasionVocabulary.easterTag);
    }

    // Herring with new potatoes, or strawberries with cream.
    final midsummerPlate =
        (_anyWordMatching(
              p1,
              OccasionVocabulary.midsummerHerringIngredients,
            ) &&
            _anyWordMatching(
              p1,
              OccasionVocabulary.midsummerNewPotatoIngredients,
            )) ||
        (_anyWordMatching(
              p1,
              OccasionVocabulary.midsummerStrawberryIngredients,
            ) &&
            _anyWordMatching(p1, OccasionVocabulary.midsummerCreamIngredients));
    if (titleHasAny(OccasionVocabulary.midsummerTitleWords) || midsummerPlate) {
      tags.add(OccasionVocabulary.midsummerTag);
    }

    if (titleHasAny(OccasionVocabulary.crayfishTitleWords) ||
        (_anyWordMatching(p1, OccasionVocabulary.crayfishIngredients) &&
            _anyWordMatching(p1, OccasionVocabulary.crayfishDillIngredients))) {
      tags.add(OccasionVocabulary.crayfishTag);
    }

    if (titleHasAny(OccasionVocabulary.newYearTitleWords) ||
        _countWordMatching(p1, OccasionVocabulary.newYearIngredients) >= 2) {
      tags.add(OccasionVocabulary.newYearTag);
    }

    return tags;
  }

  /// The season tags one `seasonAvailability` value counts towards. The
  /// ingredient data writes seasons in English (`summer`, `spring-summer`),
  /// older data and tests in Swedish, so both are read. `year-round` and
  /// `seasonal` name no season and count towards none.
  static Set<String> seasonTagsFor(String value) {
    final tags = <String>{};
    for (final part in value.toLowerCase().trim().split('-')) {
      final tag = switch (part) {
        'spring' || 'vår' => OccasionVocabulary.springTag,
        'summer' || 'sommar' => OccasionVocabulary.summerTag,
        'autumn' || 'fall' || 'höst' => OccasionVocabulary.autumnTag,
        'winter' || 'vinter' => OccasionVocabulary.winterTag,
        _ => null,
      };
      if (tag != null) tags.add(tag);
    }
    return tags;
  }

  /// Sprint 3: Hybrid season detection using seasonAvailability field + name inference.
  Set<String> _calculateSeasonTags(Phase1Result p1) {
    final tags = <String>{};

    // First, collect season data from seasonAvailability field
    final seasonCounts = <String, int>{
      OccasionVocabulary.springTag: 0,
      OccasionVocabulary.summerTag: 0,
      OccasionVocabulary.autumnTag: 0,
      OccasionVocabulary.winterTag: 0,
    };

    // Count ingredients with seasonAvailability data
    int ingredientsWithSeasonData = 0;
    for (final ingredient in p1.lookup.matched) {
      if (ingredient.seasonAvailability.isNotEmpty) {
        ingredientsWithSeasonData++;
        for (final season in ingredient.seasonAvailability) {
          for (final tag in seasonTagsFor(season)) {
            seasonCounts[tag] = seasonCounts[tag]! + 1;
          }
        }
      }
    }

    // If we have season data, use it; otherwise fall back to name-based inference
    if (ingredientsWithSeasonData >= seasonThreshold) {
      // Use field-based detection when enough data is available
      for (final entry in seasonCounts.entries) {
        if (entry.value >= seasonThreshold) {
          tags.add(entry.key);
        }
      }
    } else {
      // Grilling counts as one summer ingredient, game as one autumn one.
      final grillBonus = p1.hasTag('grillad') ? 1 : 0;
      final gameBonus = p1.hasTag('vilt') ? 1 : 0;
      if (_countMatching(p1, OccasionVocabulary.springIngredients) >=
          seasonThreshold) {
        tags.add(OccasionVocabulary.springTag);
      }
      if (_countMatching(p1, OccasionVocabulary.summerIngredients) +
              grillBonus >=
          seasonThreshold) {
        tags.add(OccasionVocabulary.summerTag);
      }
      if (_countMatching(p1, OccasionVocabulary.autumnIngredients) +
              gameBonus >=
          seasonThreshold) {
        tags.add(OccasionVocabulary.autumnTag);
      }
      if (_countMatching(p1, OccasionVocabulary.winterIngredients) >=
          seasonThreshold) {
        tags.add(OccasionVocabulary.winterTag);
      }
    }

    // Note: No 'året-runt' default tag - absence of season tags already
    // indicates year-round suitability. Adding it would be meaningless noise.

    return tags;
  }

  bool _hasLuxuryIngredients(Phase1Result p1) =>
      _anyMatching(p1, OccasionVocabulary.luxuryIngredients);

  /// How many matched ingredients contain one of [words]; an ingredient that
  /// contains several still counts once.
  int _countMatching(Phase1Result p1, List<String> words) => p1.lookup.matched
      .where((i) => words.any(i.swedish.toLowerCase().contains))
      .length;

  bool _anyMatching(Phase1Result p1, List<String> words) =>
      p1.lookup.matched.any((i) => words.any(i.swedish.toLowerCase().contains));

  /// Like [_countMatching], but a word must begin a word of the ingredient
  /// name, so "kål" does not find "blomkål".
  int _countWordMatching(Phase1Result p1, List<String> words) =>
      p1.lookup.matched.where((i) {
        final name = i.swedish.toLowerCase();
        return words.any((w) => TitleKeywordRules.titleHasWord(name, w));
      }).length;

  bool _anyWordMatching(Phase1Result p1, List<String> words) =>
      _countWordMatching(p1, words) > 0;
}

/// Result of Phase 4 calculation.
class Phase4Result {
  final Set<String> tags;
  final Phase1Result phase1;
  final Phase2Result phase2;
  final Phase3Result phase3;

  const Phase4Result({
    required this.tags,
    required this.phase1,
    required this.phase2,
    required this.phase3,
  });

  /// Gets all tags from all phases combined.
  Set<String> get allTags => {
    ...phase1.tags,
    ...phase2.tags,
    ...phase3.tags,
    ...tags,
  };
}
