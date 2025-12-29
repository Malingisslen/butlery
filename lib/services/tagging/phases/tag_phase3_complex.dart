import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';

/// Phase 3: Complex derived tags requiring Phase 1 + 2 results.
///
/// Generates:
/// - Difficulty levels (easy, medium, advanced)
/// - Texture/flavor profiles (creamy, crispy, cheesy)
/// - Nutritional indicators (high-protein, high-fiber)
/// - Practical tags (kid-friendly, freezer-friendly, batch-cooking)
class TagPhase3Complex {
  // MED-4: Use centralized thresholds from TaggingThresholds instead of
  // duplicating values here. These aliases are kept for local readability.
  static int get _easyMaxIngredients => TaggingThresholds.easyMaxIngredients;
  static int get _easyMaxMinutes => TaggingThresholds.easyMaxMinutes;
  static int get _advancedMinIngredients =>
      TaggingThresholds.advancedMinIngredients;
  static int get _advancedMinMinutes => TaggingThresholds.advancedMinMinutes;

  /// Calculates Phase 3 tags.
  Phase3Result calculate(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    final tags = <String>{};

    // Difficulty level
    tags.add(_calculateDifficulty(p1, p2, recipe));

    // Texture and flavor profiles
    if (_isCreamy(p1, recipe)) tags.add('krämig');
    if (_isCrispy(p1, recipe)) tags.add('krispig');
    if (_isCheesy(p1, recipe)) tags.add('ostig');

    // Temperature
    if (_isColdDish(p1, p2, recipe)) tags.add('kall-rätt');
    if (_isHotDish(p1, p2)) tags.add('varm-rätt');

    // Nutritional indicators
    if (_isHighProtein(p1, recipe)) tags.add('proteinrik');
    if (_isHighFiber(p1)) tags.add('fiberrik');
    if (_isVeggieRich(p1)) tags.add('grönsaksrik');
    if (p1.hasProperty('plant-based')) tags.add('kryddrik');

    // Practical tags
    if (_isKidFriendly(p1, p2)) tags.add('barnvänlig');
    if (_isFreezerFriendly(p1, p2)) tags.add('frysbar');
    if (_isMealPrepFriendly(p1, p2, recipe)) tags.add('meal-prep');

    // Batch cooking
    final portions = recipe.core.portions ?? 4;
    if (portions >= 6 || recipe.core.title.toLowerCase().contains('storkok')) {
      tags.add('storkok');
    }

    return Phase3Result(tags: tags, phase1: p1, phase2: p2);
  }

  String _calculateDifficulty(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    final ingredientCount = recipe.core.ingredients.length;
    final time = recipe.core.timeMinutes ?? 30;
    final hasAdvancedTechniques = _hasAdvancedTechniques(recipe);

    // L2: Use named constants for difficulty thresholds
    if (ingredientCount <= _easyMaxIngredients &&
        time <= _easyMaxMinutes &&
        !hasAdvancedTechniques) {
      return 'enkel';
    }

    if (ingredientCount > _advancedMinIngredients ||
        time > _advancedMinMinutes ||
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
    return advancedKeywords.any((k) => instructions.contains(k));
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

  bool _isCheesy(Phase1Result p1, Recipe recipe) {
    // Check for significant cheese content
    final cheeseIngredients = p1.lookup.matched
        .where((i) =>
            i.group.contains('protein/dairy') &&
            (i.swedish.toLowerCase().contains('ost') ||
                i.swedish.toLowerCase().contains('parmesan') ||
                i.swedish.toLowerCase().contains('mozzarella') ||
                i.swedish.toLowerCase().contains('cheddar')))
        .toList();

    // Check if cheese is in top 5 ingredients (significant position)
    final top5Ingredients = recipe.core.ingredients.take(5).toList();
    final hasCheeseInTop5 = top5Ingredients.any((ing) {
      final lower = ing.toLowerCase();
      return lower.contains('ost') ||
          lower.contains('parmesan') ||
          lower.contains('mozzarella') ||
          lower.contains('cheddar');
    });

    // Cheesy if: cheese in title, OR multiple cheeses, OR single cheese in top 5
    return recipe.core.title.toLowerCase().contains('ost') ||
        cheeseIngredients.length > 1 ||
        (cheeseIngredients.isNotEmpty && hasCheeseInTop5);
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

  bool _isHighProtein(Phase1Result p1, Recipe recipe) {
    // Protein must be a significant portion of the recipe, not just present.
    // Require: 1+ protein ingredient AND it makes up >25% of matched ingredients.
    // Changed from 2+ to 1+ to properly tag dishes with a single main protein (e.g., steak).
    final proteinIngredients = p1.lookup.getIngredientsInGroup('protein');
    final totalMatched = p1.lookup.matched.length;

    if (proteinIngredients.isEmpty) return false;
    if (totalMatched == 0) return false;

    // MED-5: Use centralized threshold instead of hardcoded value
    final proteinRatio = proteinIngredients.length / totalMatched;
    return proteinRatio > TaggingThresholds.highProteinRatio;
  }

  bool _isHighFiber(Phase1Result p1) {
    // High fiber sources: legumes, whole grains, and nuts
    return p1.hasTag('baljväxter') ||
        p1.hasTag('fullkorn') ||
        p1.lookup.hasGroup('vegetable/legume') ||
        p1.lookup.hasGroup('nut');
  }

  bool _isVeggieRich(Phase1Result p1) {
    final veggieCount = p1.lookup.getIngredientsInGroup('vegetable').length;
    return veggieCount >= 3;
  }

  bool _isKidFriendly(Phase1Result p1, Phase2Result p2) {
    // Mild + recognizable protein + no bitter vegetables
    if (!p2.hasTag('mild')) return false;
    if (p1.getAllergenStatus('alkohol') != TriState.free) return false;

    final hasRecognizableProtein = p1.hasTag('kyckling') ||
        p1.hasTag('köttbullar') ||
        p1.hasTag('fläskkött') ||
        p1.hasTag('nötkött') ||
        p1.hasTag('fisk') ||
        p1.hasTag('ägg');

    return hasRecognizableProtein;
  }

  bool _isFreezerFriendly(Phase1Result p1, Phase2Result p2) {
    // No ingredients that don't freeze well
    if (p1.hasProperty('doesnt-freeze-well')) return false;

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
    if (p1.hasProperty('doesnt-freeze-well')) return false;

    final portions = recipe.core.portions ?? 4;
    // L6: Added pastabaserad - pasta dishes keep well for meal prep
    return portions >= 4 &&
        (p1.hasTag('gryta') ||
            p1.hasTag('soppa') ||
            p1.hasTag('köttbullar') ||
            p1.hasTag('gratäng') ||
            p1.hasTag('pastabaserad'));
  }
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
