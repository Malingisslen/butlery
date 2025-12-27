import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Phase 2: Simple derived tags that depend on Phase 1 results.
///
/// Generates:
/// - Dish category tags (pasta-dish, rice-dish)
/// - Spicy/mild indicators
/// - Dietary combinations (pescetarian, halal-friendly)
/// - Practical tags (few-ingredients)
class TagPhase2Derived {
  /// Calculates Phase 2 tags.
  Phase2Result calculate(Phase1Result phase1, Recipe recipe) {
    final tags = <String>{};

    // Dish type derived from base
    if (phase1.hasTag('pastabaserad')) tags.add('pasta-dish');
    if (phase1.hasTag('risbaserad')) tags.add('rice-dish');
    if (phase1.hasTag('nudelbaserad')) tags.add('noodle-dish');
    if (phase1.hasTag('potatisbaserad')) tags.add('potato-dish');
    if (phase1.hasTag('brödbaserad')) tags.add('bread-dish');

    // Spicy/mild
    if (phase1.hasProperty('is-spicy')) {
      tags.add('stark');
    } else if (phase1.lookup.hasFullCoverage) {
      tags.add('mild');
    }

    // Pescetarian (fish/shellfish but no meat)
    if (phase1.getDietaryStatus('vegetarisk') != TriState.free &&
        (phase1.hasTag('fisk') || phase1.hasTag('skaldjur')) &&
        !phase1.hasProperty('meat')) {
      tags.add('pescetarian');
    }

    // Halal-friendly
    if (phase1.getAllergenStatus('fläsk') == TriState.free &&
        phase1.getAllergenStatus('alkohol') == TriState.free) {
      tags.add('halalanpassad');
    }

    // Kosher-friendly
    if (phase1.getAllergenStatus('fläsk') == TriState.free &&
        phase1.getAllergenStatus('skaldjur') == TriState.free) {
      tags.add('kosheranpassad');
    }

    // Few ingredients
    final ingredientCount = recipe.core.ingredients.length;
    if (ingredientCount <= 6) {
      tags.add('få-ingredienser');
    }

    // Raw (no cooking)
    final title = recipe.core.title.toLowerCase();
    if (_isRawDish(phase1, title)) {
      tags.add('rå');
    }

    // One-pot
    if (phase1.hasTag('gryta') && _isOnePot(recipe)) {
      tags.add('one-pot');
    }

    // Sheet-pan
    if (_isSheetPan(recipe)) {
      tags.add('plåtmat');
    }

    // No-bake
    if (!phase1.hasTag('ugnsbakad') &&
        !phase1.hasTag('stekt') &&
        !phase1.hasTag('kokt') &&
        !phase1.hasTag('grillad') &&
        _isNoBake(recipe)) {
      tags.add('no-bake');
    }

    // Slow-cooked
    final time = recipe.core.timeMinutes ?? 0;
    if (time > 120 &&
        (phase1.hasTag('slow-cooker') || phase1.hasTag('gryta'))) {
      tags.add('långkokt');
    }

    // Overnight
    if (_isOvernight(recipe)) {
      tags.add('över-natten');
    }

    // Dessert
    if (phase1.hasTag('kaka') ||
        title.contains('dessert') ||
        title.contains('efterrätt')) {
      tags.add('dessert');
    }

    // Breakfast
    if (phase1.hasTag('pannkaka') ||
        phase1.hasTag('våffla') ||
        title.contains('frukost')) {
      tags.add('frukost');
    }

    // Fika
    if (phase1.hasTag('kaka') ||
        title.contains('bulle') ||
        title.contains('fika')) {
      tags.add('fika');
    }

    // Drink
    if (phase1.hasTag('smoothie') || title.contains('drink')) {
      tags.add('dryck');
    }

    return Phase2Result(tags: tags, phase1: phase1);
  }

  bool _isRawDish(Phase1Result phase1, String title) {
    // No cooking methods and has raw indicators
    final noCooking = !phase1.hasTag('ugnsbakad') &&
        !phase1.hasTag('stekt') &&
        !phase1.hasTag('kokt') &&
        !phase1.hasTag('grillad') &&
        !phase1.hasTag('friterad');

    final rawIndicators = [
      'sashimi',
      'tartare',
      'tartar',
      'carpaccio',
      'ceviche'
    ];
    return noCooking && rawIndicators.any((r) => title.contains(r));
  }

  bool _isOnePot(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('en gryta') ||
        instructions.contains('samma kastrull') ||
        instructions.contains('one pot');
  }

  bool _isSheetPan(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('plåt') || instructions.contains('sheet pan');
  }

  bool _isNoBake(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('no bake') ||
        instructions.contains('utan ugn') ||
        instructions.contains('ingen tillagning');
  }

  bool _isOvernight(Recipe recipe) {
    final instructions = recipe.core.instructions.join(' ').toLowerCase();
    return instructions.contains('över natten') ||
        instructions.contains('overnight') ||
        instructions.contains('i kylen över natten');
  }
}

/// Result of Phase 2 calculation.
class Phase2Result {
  final Set<String> tags;
  final Phase1Result phase1;

  const Phase2Result({
    required this.tags,
    required this.phase1,
  });

  /// Checks if a specific tag was generated in Phase 1 or 2.
  bool hasTag(String tag) => tags.contains(tag) || phase1.hasTag(tag);

  /// Gets all tags from Phase 1 and 2 combined.
  Set<String> get allTags => {...phase1.tags, ...tags};
}
