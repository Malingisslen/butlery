import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_line.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';
import 'package:butlery/services/tagging/main_ingredients.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';

/// Phase 3: Complex derived tags requiring Phase 1 + 2 results.
///
/// Generates:
/// - Difficulty levels (easy, medium, advanced)
/// - Texture/flavor profiles (creamy, crispy, cheesy)
/// - Nutritional indicators (high-protein, high-fiber)
/// - Practical tags (kid-friendly, freezer-friendly, batch-cooking)
/// - Sustainability tags (klimatsmart, budgetvänlig) [Sprint 2]
class TagPhase3Complex {
  final int easyMaxIngredients;
  final int easyMaxMinutes;
  final int advancedMinIngredients;
  final int advancedMinMinutes;
  final int proteinGramsPerPortion;
  final int spiceRichCount;
  final int veggieRichCount;

  TagPhase3Complex({
    this.easyMaxIngredients = TaggingThresholds.easyMaxIngredients,
    this.easyMaxMinutes = TaggingThresholds.easyMaxMinutes,
    this.advancedMinIngredients = TaggingThresholds.advancedMinIngredients,
    this.advancedMinMinutes = TaggingThresholds.advancedMinMinutes,
    this.proteinGramsPerPortion = TaggingThresholds.proteinGramsPerPortion,
    this.spiceRichCount = TaggingThresholds.spiceRichCount,
    this.veggieRichCount = TaggingThresholds.veggieRichCount,
  });

  /// Calculates Phase 3 tags.
  Phase3Result calculate(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    final tags = <String>{};
    final mains = MainIngredients.of(p1.lookup.lines);

    final difficulty = _calculateDifficulty(p1, p2, recipe);
    if (difficulty != null) tags.add(difficulty);

    // Texture and flavor profiles
    if (_isCreamy(p1, recipe)) tags.add('krämig');
    if (_isCrispy(p1, recipe)) tags.add('krispig');
    if (_isCheesy(p1)) tags.add('ostig');

    // Temperature
    if (_isColdDish(p1, p2, recipe)) tags.add('kall-rätt');
    if (_isHotDish(p1, p2)) tags.add('varm-rätt');

    // Nutritional indicators
    if (_isHighProtein(p1, recipe)) tags.add('proteinrik');
    if (_hasHerbs(p1)) tags.add('örtig');
    if (_isHighFiber(p1)) tags.add('fiberrik');
    if (_isVeggieRich(p1)) tags.add('grönsaksrik');
    if (_isSpiceRich(p1)) tags.add('kryddrik');

    // Practical tags
    if (_isKidFriendly(p1, p2)) tags.add('barnvänlig');
    if (_isLittleWork(recipe)) tags.add('lite-jobb');
    if (_hasSeafoodMain(mains)) tags.add('fisk-och-skaldjur');
    if (_isFreezerFriendly(p1, p2)) tags.add('frysbar');
    if (_isMealPrepFriendly(p1, p2, recipe)) tags.add('meal-prep');

    // Batch cooking
    final portions = recipe.core.portions ?? 4;
    if (portions >= 6 || recipe.core.title.toLowerCase().contains('storkok')) {
      tags.add('storkok');
    }

    // Sprint 2: Sustainability tags
    if (_isKlimatsmart(mains)) tags.add('klimatsmart');
    if (_isBudgetvanlig(mains)) tags.add('budgetvänlig');

    return Phase3Result(tags: tags, phase1: p1, phase2: p2);
  }

  /// Null when the recipe states no time: a guessed time would make the
  /// difficulty a guess too (Malin 2026-10-30, kärnflöde steg 5 beslut 9).
  String? _calculateDifficulty(
    Phase1Result p1,
    Phase2Result p2,
    Recipe recipe,
  ) {
    final time = recipe.core.timeMinutes;
    if (time == null || time <= 0) return null;
    final ingredientCount = recipe.core.ingredients.length;
    final hasAdvancedTechniques = _hasAdvancedTechniques(recipe);

    // L2: Use named constants for difficulty thresholds
    if (ingredientCount <= easyMaxIngredients &&
        time <= easyMaxMinutes &&
        !hasAdvancedTechniques) {
      return 'enkel';
    }

    if (ingredientCount > advancedMinIngredients ||
        time > advancedMinMinutes ||
        hasAdvancedTechniques) {
      return 'avancerad';
    }

    return 'medel';
  }

  bool _hasAdvancedTechniques(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    // L9: Expanded advanced techniques list with professional culinary terms
    final advancedKeywords = [
      // Temperature techniques
      'sous vide',
      'tempera',
      'bain-marie',
      // Flavor development
      'karamellisera',
      'flambera',
      'deglacera',
      'réducer',
      'reducera',
      // Classic French techniques
      'confit',
      'creme anglaise',
      'crème anglaise',
      'beurre blanc',
      'hollandaise',
      'béarnaise',
      'bearnaise',
      // Emulsions and foams
      'emulsion',
      'montera',
      // Pastry/baking
      'meringue',
      'maräng',
      'soufflé',
      'souffle',
      // Knife skills
      'julienne',
      'brunoise',
      'mirepoix',
      'chiffonade',
      // Wrapping/folding
      'rulla',
      'vira',
      'vik in',
    ];
    return advancedKeywords.any((k) {
      // Word boundary matching to avoid false positives
      // (e.g., "emulsionsmaskinen" should not match "emulsion")
      final pattern = RegExp(
        '(?:^|[\\s,\\.])${RegExp.escape(k)}(?=[\\s,\\.]|\$)',
      );
      return pattern.hasMatch(instructions);
    });
  }

  bool _isCreamy(Phase1Result p1, Recipe recipe) {
    // Creamy ingredients must be in top 5 positions to be considered significant.
    // This avoids tagging recipes with just a tablespoon of cream as "creamy".
    final ingredients = recipe.core.ingredients;
    final top5 = ingredients.take(5).map((i) => i.toLowerCase()).toList();

    // L10: Expanded cream types list with Swedish and plant-based alternatives
    final creamyKeywords = [
      // Traditional dairy
      'grädde',
      'vispgrädde',
      'matgrädde',
      'creme',
      'créme',
      'crème fraîche',
      'fraiche',
      'smetana',
      'mascarpone',
      'cream cheese',
      'philadelphiaost',
      // Coconut-based
      'kokosmjölk',
      'kokosgrädde',
      // Plant-based alternatives
      'havremjölk',
      'havregrädde',
      'cashewgrädde',
      'sojamjölk',
      'sojagrädde',
    ];
    final hasSignificantCreamy = top5.any(
      (ing) => creamyKeywords.any((k) => ing.contains(k)),
    );

    if (!hasSignificantCreamy) return false;

    // And is a sauce, pasta dish, or soup (creamy soups are common)
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('sås') ||
        instructions.contains('rör') ||
        p1.hasTag('pastabaserad') ||
        p1.hasTag('soppa');
  }

  bool _isCrispy(Phase1Result p1, Recipe recipe) {
    if (p1.hasTag('friterad')) return true;

    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('krispig') ||
        instructions.contains('frasig') ||
        instructions.contains('knaprig');
  }

  /// At least [TaggingThresholds.cheeseGrams] of weighed cheese (Malin
  /// 2026-10-30, kärnflöde steg 5 beslut 8).
  bool _isCheesy(Phase1Result p1) =>
      MainIngredients.gramsWhere(p1.lookup.lines, _isCheese) >=
      TaggingThresholds.cheeseGrams;

  static const _notCheese = [
    'mjölk',
    'milk',
    'grädde',
    'gräddpulver',
    'cream',
    'smör',
    'butter',
    'yoghurt',
    'yogurt',
    'kefir',
    'ayran',
    'lassi',
    'kasein',
    'casein',
    'vassle',
    'whey',
    'fil',
    'crème',
    'creme',
    'crema',
    'fraiche',
    'fraîche',
    'smetana',
    'viili',
    'skyr',
    'kvarg',
    'quark',
    'labneh',
    'dulce',
    'mesvadd',
    'kafferoom',
    'clabber',
    'colostrum',
    'curd',
  ];

  // The ingredient data has no cheese flag, so a dairy row is cheese unless
  // its name says it is milk, cream, butter or a soured milk.
  static bool _isCheese(IngredientData i) {
    if (!i.group.startsWith('protein/dairy')) return false;
    final swedish = i.swedish.toLowerCase().trim();
    final english = i.english.toLowerCase();
    // "smörgåsost" and "cream cheese" name a cheese despite a milk word.
    if (swedish.split(' ').last.endsWith('ost') || english.contains('cheese')) {
      return true;
    }
    return !_notCheese.any('$swedish $english'.contains);
  }

  bool _isColdDish(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    return p2.hasTag('rå') ||
        p1.hasTag('sallad') ||
        recipe.core.title.toLowerCase().contains('kall');
  }

  bool _isHotDish(Phase1Result p1, Phase2Result p2) {
    return p1.hasTag('ugnsbakad') ||
        p1.hasTag('stekt') ||
        p1.hasTag('kokt') ||
        p1.hasTag('grillad') ||
        p1.hasTag('gryta') ||
        p1.hasTag('soppa');
  }

  /// At least [proteinGramsPerPortion] of weighed protein-group ingredients
  /// per portion (Malin 2026-10-30, kärnflöde steg 5 beslut 8). Dairy counts
  /// (Malin 2026-10-31).
  bool _isHighProtein(Phase1Result p1, Recipe recipe) {
    final portions = recipe.core.portions;
    if (portions == null || portions <= 0) return false;
    final grams = MainIngredients.gramsWhere(
      p1.lookup.lines,
      (i) => i.group.startsWith('protein/'),
    );
    return grams >= proteinGramsPerPortion * portions;
  }

  /// Two or more fresh herbs (Malin 2026-10-30, kärnflöde steg 5 beslut 9).
  bool _hasHerbs(Phase1Result p1) =>
      p1.lookup
          .getIngredientsInGroup('spice/herb-fresh')
          .map((i) => i.id)
          .toSet()
          .length >=
      TaggingThresholds.herbRichCount;

  /// Under 15 minutes of work, read only from a stated preparation time
  /// (Malin 2026-10-30, kärnflöde steg 5 beslut 9).
  bool _isLittleWork(Recipe recipe) {
    final prep = recipe.core.prepTimeMinutes;
    return prep != null &&
        prep > 0 &&
        prep < TaggingThresholds.littleWorkMaxMinutes;
  }

  bool _hasSeafoodMain(List<IngredientLine> mains) => mains.any(
    (l) => l.ingredients.any((i) => i.group.startsWith('protein/seafood')),
  );

  bool _isHighFiber(Phase1Result p1) {
    // High fiber sources: legumes, whole grains, and nuts
    return p1.hasTag('baljväxter') ||
        p1.hasTag('fullkorn') ||
        p1.lookup.hasGroup('vegetable/legume') ||
        p1.lookup.hasGroup('nut');
  }

  bool _isVeggieRich(Phase1Result p1) {
    final veggieCount = p1.lookup.getIngredientsInGroup('vegetable').length;
    return veggieCount >= veggieRichCount;
  }

  bool _isSpiceRich(Phase1Result p1) {
    final spiceCount = p1.lookup.getIngredientsInGroup('spice').length;
    return spiceCount >= spiceRichCount;
  }

  /// Neither strong nor alcoholic (Malin 2026-10-30, kärnflöde steg 5
  /// beslut 3); the alcohol check needs every ingredient known.
  bool _isKidFriendly(Phase1Result p1, Phase2Result p2) =>
      !p2.hasTag('stark') &&
      !p1.hasProperty('is-spicy') &&
      p1.getAllergenStatus('alkohol') == TriState.free;

  /// Both freezer and meal-prep promise that NO ingredient fails to keep, so
  /// they need enough of the ingredients known (Malin 2026-10-30, kärnflöde
  /// steg 5 beslut 5).
  bool _keepsWell(Phase1Result p1) =>
      p1.lookup.coverage >= TaggingThresholds.cuisineAndMoodCoverage &&
      !p1.hasProperty('doesnt-freeze-well');

  bool _isFreezerFriendly(Phase1Result p1, Phase2Result p2) {
    if (!_keepsWell(p1)) return false;

    // Not a salad
    if (p1.hasTag('sallad')) return false;

    // Has some substance (L5: added gratäng)
    return p1.hasTag('gryta') ||
        p1.hasTag('soppa') ||
        p1.hasTag('köttbullar') ||
        p1.hasTag('pastabaserad') ||
        p1.hasTag('gratäng');
  }

  bool _isMealPrepFriendly(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    // Keeps well, easy to reheat
    if (p1.hasTag('sallad')) return false;
    if (!_keepsWell(p1)) return false;

    final portions = recipe.core.portions ?? 4;
    // L6: Added pastabaserad - pasta dishes keep well for meal prep
    return portions >= 4 &&
        (p1.hasTag('gryta') ||
            p1.hasTag('soppa') ||
            p1.hasTag('köttbullar') ||
            p1.hasTag('gratäng') ||
            p1.hasTag('pastabaserad'));
  }

  /// Every main ingredient is known and low or medium in carbon (Malin
  /// 2026-10-30, kärnflöde steg 5 beslut 8).
  bool _isKlimatsmart(List<IngredientLine> mains) =>
      _allMainsKnown(mains) &&
      mains.every(
        (l) => l.ingredients.every(
          (i) => const {
            'low',
            'medium',
          }.contains(i.carbonFootprintCategory),
        ),
      );

  /// Every main ingredient is known and none is premium or high in price
  /// (Malin 2026-10-30, kärnflöde steg 5 beslut 8).
  bool _isBudgetvanlig(List<IngredientLine> mains) =>
      _allMainsKnown(mains) &&
      mains.every(
        (l) => l.ingredients.every(
          (i) =>
              i.priceCategory != null &&
              !const {'premium', 'high'}.contains(i.priceCategory),
        ),
      );

  bool _allMainsKnown(List<IngredientLine> mains) =>
      mains.isNotEmpty && mains.every((l) => l.known);
}

/// Result of Phase 3 calculation.
class Phase3Result {
  final Set<String> tags;
  final Phase1Result phase1;
  final Phase2Result phase2;

  const Phase3Result({
    required this.tags,
    required this.phase1,
    required this.phase2,
  });

  /// Checks if a specific tag exists in any phase.
  bool hasTag(String tag) =>
      tags.contains(tag) || phase2.hasTag(tag) || phase1.hasTag(tag);

  /// Gets all tags from all phases.
  Set<String> get allTags => {...phase1.tags, ...phase2.tags, ...tags};
}
