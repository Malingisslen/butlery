import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
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

    // Easy: <= 6 ingredients, <= 30 min, simple techniques
    if (ingredientCount <= 6 && time <= 30 && !hasAdvancedTechniques) {
      return 'enkel';
    }

    // Advanced: > 12 ingredients, > 60 min, or advanced techniques
    if (ingredientCount > 12 || time > 60 || hasAdvancedTechniques) {
      return 'avancerad';
    }

    return 'medel';
  }

  bool _hasAdvancedTechniques(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    final advancedKeywords = [
      'sous vide',
      'tempera',
      'karamellisera',
      'flambera',
      'emulsion',
      'réducer',
      'confit',
      'creme anglaise',
      'meringue',
      'maräng',
      'soufflé',
      'rulla',
      'vira',
      'vik in',
    ];
    return advancedKeywords.any((k) => instructions.contains(k));
  }

  bool _isCreamy(Phase1Result p1, Recipe recipe) {
    // Has cream or coconut milk as significant ingredient
    final hasCreamy = p1.lookup.matched.any((i) {
      final name = i.swedish.toLowerCase();
      return name.contains('grädde') ||
          name.contains('creme') ||
          name.contains('créme') ||
          name.contains('kokosmjölk') ||
          name.contains('mascarpone');
    });

    // And is a sauce or pasta dish
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return hasCreamy &&
        (instructions.contains('sås') ||
            instructions.contains('rör') ||
            p1.hasTag('pastabaserad'));
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
    final cheeseIngredients = p1.lookup.matched.where((i) =>
        i.group.contains('protein/dairy') &&
        (i.swedish.toLowerCase().contains('ost') ||
            i.swedish.toLowerCase().contains('parmesan') ||
            i.swedish.toLowerCase().contains('mozzarella') ||
            i.swedish.toLowerCase().contains('cheddar')));

    // More than one cheese or cheese in title
    return cheeseIngredients.length > 1 ||
        recipe.core.title.toLowerCase().contains('ost');
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
    // Require: 2+ protein ingredients AND they make up >25% of matched ingredients.
    final proteinIngredients = p1.lookup.getIngredientsInGroup('protein');
    final totalMatched = p1.lookup.matched.length;

    if (proteinIngredients.length < 2) return false;
    if (totalMatched == 0) return false;

    // Protein must be >25% of ingredients to qualify as "high protein"
    final proteinRatio = proteinIngredients.length / totalMatched;
    return proteinRatio > 0.25;
  }

  bool _isHighFiber(Phase1Result p1) {
    return p1.hasTag('baljväxter') ||
        p1.hasTag('fullkorn') ||
        p1.lookup.hasGroup('vegetable/legume');
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

    // Has some substance
    return p1.hasTag('gryta') ||
        p1.hasTag('soppa') ||
        p1.hasTag('köttbullar') ||
        p1.hasTag('pastabaserad');
  }

  bool _isMealPrepFriendly(Phase1Result p1, Phase2Result p2, Recipe recipe) {
    // Keeps well, easy to reheat
    if (p1.hasTag('sallad')) return false;
    if (p1.hasProperty('doesnt-freeze-well')) return false;

    final portions = recipe.core.portions ?? 4;
    return portions >= 4 &&
        (p1.hasTag('gryta') ||
            p1.hasTag('soppa') ||
            p1.hasTag('köttbullar') ||
            p1.hasTag('gratäng'));
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
