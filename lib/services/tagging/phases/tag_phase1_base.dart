import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';

/// Phase 1: Base tags calculated directly from ingredient properties and recipe metadata.
///
/// Generates:
/// - Time tags (under-15-min, under-30-min, etc.)
/// - Allergen status (tri-valued logic)
/// - Dietary status (vegetarian, vegan, etc.)
/// - Protein tags (kyckling, nötkött, fisk, etc.)
/// - Base/carb tags (pastabaserad, risbaserad, etc.)
/// - Cooking method tags (ugnsbakad, stekt, etc.)
/// - Dish type tags (soppa, sallad, gryta, etc.)
class TagPhase1Base {
  /// Calculates Phase 1 tags.
  Phase1Result calculate(IngredientLookupResult lookup, Recipe recipe) {
    final tags = <String>{};
    final allergenStatus = <String, TriState>{};
    final dietaryStatus = <String, TriState>{};

    // Time tags from metadata
    tags.addAll(_calculateTimeTags(recipe.core.timeMinutes));

    // Allergen status using tri-valued logic
    allergenStatus.addAll(_calculateAllergenStatus(lookup));

    // Dietary status
    dietaryStatus.addAll(_calculateDietaryStatus(lookup));

    // Protein tags from ingredient groups
    tags.addAll(_calculateProteinTags(lookup));

    // Carb/base tags
    tags.addAll(_calculateCarbTags(lookup, recipe));

    // Cooking method tags from instructions
    tags.addAll(_calculateCookingMethodTags(recipe.core.instructions));

    // Dish type tags from title
    tags.addAll(_calculateDishTypeTags(recipe.core.title));

    return Phase1Result(
      tags: tags,
      allergenStatus: allergenStatus,
      dietaryStatus: dietaryStatus,
      lookup: lookup,
    );
  }

  /// Calculates time-based tags from recipe duration.
  Set<String> _calculateTimeTags(int? timeMinutes) {
    if (timeMinutes == null || timeMinutes <= 0) return {};

    final tags = <String>{};

    if (timeMinutes <= 15) tags.add('under-15-min');
    if (timeMinutes <= 30) tags.add('under-30-min');
    if (timeMinutes <= 45) tags.add('under-45-min');
    if (timeMinutes <= 60) tags.add('under-60-min');
    if (timeMinutes > 60) tags.add('över-60-min');

    return tags;
  }

  /// Calculates allergen status using tri-valued logic.
  ///
  /// CRITICAL: Never use boolean. Always CONTAINS/FREE/UNKNOWN.
  Map<String, TriState> _calculateAllergenStatus(
      IngredientLookupResult lookup) {
    final status = <String, TriState>{};

    // Process simple allergens first
    for (final allergen in AllergenConfig.simpleAllergens) {
      status[allergen.key] = lookup.getPropertyStatus(allergen.triggerProperty);
    }

    // Process combined allergens using OR logic
    for (final allergen in AllergenConfig.combinedAllergens) {
      if (lookup.coverage < 1.0) {
        status[allergen.key] = TriState.unknown;
      } else {
        final props = allergen.triggerProperties;
        status[allergen.key] = lookup.getCombinedPropertyStatus(props);
      }
    }

    return status;
  }

  /// Calculates dietary status.
  Map<String, TriState> _calculateDietaryStatus(IngredientLookupResult lookup) {
    final status = <String, TriState>{};

    for (final dietary in DietaryConfig.all) {
      if (dietary.requiresFullCoverage && lookup.coverage < 1.0) {
        status[dietary.key] = TriState.unknown;
        continue;
      }

      // Check excluded properties
      final hasExcluded = lookup.hasAnyProperty(dietary.excludedProperties);

      if (hasExcluded) {
        status[dietary.key] = TriState.contains;
      } else if (dietary.requiredProperties != null) {
        // Special case: pescetarian requires fish/shellfish
        final hasRequired = lookup.hasAnyProperty(dietary.requiredProperties!);
        // For pescetarian, we set a special status
        status[dietary.key] = hasRequired ? TriState.free : TriState.contains;
      } else {
        status[dietary.key] = TriState.free;
      }
    }

    return status;
  }

  /// Calculates protein tags from ingredient groups.
  Set<String> _calculateProteinTags(IngredientLookupResult lookup) {
    final tags = <String>{};

    // Poultry specifics
    final poultry = lookup.getIngredientsInGroup('protein/meat/poultry');
    for (final ingredient in poultry) {
      final nameLower = ingredient.swedish.toLowerCase();
      if (nameLower.contains('kyckling')) {
        tags.add('kyckling');
      } else if (nameLower.contains('anka')) {
        tags.add('anka');
      } else if (nameLower.contains('kalkon')) {
        tags.add('kalkon');
      }
    }

    // Beef
    if (lookup.hasGroup('protein/meat/beef')) {
      tags.add('nötkött');
    }

    // Pork
    if (lookup.hasGroup('protein/meat/pork')) {
      tags.add('fläskkött');
    }

    // Lamb
    if (lookup.hasGroup('protein/meat/lamb')) {
      tags.add('lamm');
    }

    // Game
    if (lookup.hasGroup('protein/meat/game')) {
      tags.add('vilt');
    }

    // Fish specifics
    final fish = lookup.getIngredientsInGroup('protein/seafood/fish');
    if (fish.isNotEmpty) {
      tags.add('fisk');
      for (final ingredient in fish) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('lax')) {
          tags.add('lax');
        } else if (nameLower.contains('torsk')) {
          tags.add('torsk');
        } else if (nameLower.contains('sill')) {
          tags.add('sill');
        }
      }
    }

    // Shellfish specifics
    final shellfish = lookup.getIngredientsInGroup('protein/seafood/shellfish');
    if (shellfish.isNotEmpty) {
      tags.add('skaldjur');
      for (final ingredient in shellfish) {
        final nameLower = ingredient.swedish.toLowerCase();
        if (nameLower.contains('räk') && ingredient.hasProperty('crustacean')) {
          tags.add('räkor');
        }
      }
    }

    // Plant-based protein
    final plantProtein = lookup.getIngredientsInGroup('protein/plant-based');
    for (final ingredient in plantProtein) {
      final nameLower = ingredient.swedish.toLowerCase();
      if (nameLower.contains('tofu')) {
        tags.add('tofu');
      }
    }

    // Legumes
    if (lookup.hasGroup('vegetable/legume')) {
      tags.add('baljväxter');
    }

    // Eggs (as main protein)
    if (lookup.hasGroup('protein/egg')) {
      tags.add('ägg');
    }

    return tags;
  }

  /// Calculates carb/base tags.
  Set<String> _calculateCarbTags(IngredientLookupResult lookup, Recipe recipe) {
    final tags = <String>{};

    // Check for pasta
    final hasPasta = lookup.matched.any((i) =>
        i.group.contains('pasta-bread') &&
        (i.swedish.toLowerCase().contains('pasta') ||
            i.swedish.toLowerCase().contains('spagetti') ||
            i.swedish.toLowerCase().contains('penne') ||
            i.swedish.toLowerCase().contains('lasagne') ||
            i.swedish.toLowerCase().contains('tagliatelle')));

    if (hasPasta) {
      tags.add('pastabaserad');
    }

    // Check for rice
    final hasRice = lookup.matched.any((i) =>
        i.swedish.toLowerCase().contains('ris') && i.group.contains('grain'));

    if (hasRice) {
      tags.add('risbaserad');
    }

    // Check for potato
    final hasPotato = lookup.matched.any((i) =>
        i.swedish.toLowerCase().contains('potatis') &&
        i.group.contains('vegetable/root'));

    if (hasPotato) {
      tags.add('potatisbaserad');
    }

    // Check for noodles
    final hasNoodles = lookup.matched.any((i) =>
        i.swedish.toLowerCase().contains('nudl') ||
        i.swedish.toLowerCase().contains('wontonnudl') ||
        i.swedish.toLowerCase().contains('risnudl') ||
        i.swedish.toLowerCase().contains('glasnudl'));

    if (hasNoodles) {
      tags.add('nudelbaserad');
    }

    // Check for bread
    final hasBread = lookup.matched.any((i) =>
        i.group.contains('grain/bread') ||
        i.swedish.toLowerCase().contains('bröd'));

    if (hasBread) {
      tags.add('brödbaserad');
    }

    // Check for whole grain
    if (lookup.hasGroup('grain/whole')) {
      tags.add('fullkorn');
    }

    return tags;
  }

  /// Calculates cooking method tags from instructions.
  Set<String> _calculateCookingMethodTags(List<String> instructions) {
    final tags = <String>{};
    final text = instructions.join(' ').toLowerCase();

    // Oven baked
    if ((text.contains('ugn') ||
            text.contains('°c') ||
            text.contains('grader')) &&
        !text.contains('micro')) {
      tags.add('ugnsbakad');
    }

    // Pan fried
    if (text.contains('stek') || text.contains('bryn')) {
      tags.add('stekt');
    }

    // Grilled
    if (text.contains('grill')) {
      tags.add('grillad');
    }

    // Boiled
    if (text.contains('koka') || text.contains('sjud')) {
      tags.add('kokt');
    }

    // Steamed
    if (text.contains('ångkok') || text.contains('ånga')) {
      tags.add('ångkokt');
    }

    // Poached
    if (text.contains('pochera')) {
      tags.add('pocherad');
    }

    // Deep fried
    if (text.contains('fritera')) {
      tags.add('friterad');
    }

    // Air fryer
    if (text.contains('airfryer') || text.contains('air fryer')) {
      tags.add('airfryer');
    }

    // Slow cooker
    if (text.contains('slow cooker') || text.contains('crock pot')) {
      tags.add('slow-cooker');
    }

    // Pressure cooker
    if (text.contains('tryckkokare') || text.contains('instant pot')) {
      tags.add('tryckkokare');
    }

    // Sous vide
    if (text.contains('sous vide') || text.contains('sous-vide')) {
      tags.add('sous-vide');
    }

    // Wok
    if (text.contains('wok')) {
      tags.add('wokad');
    }

    // Microwave
    if (text.contains('micro') || text.contains('mikro')) {
      tags.add('microugn');
    }

    // Smoked
    if (text.contains('rök') && !text.contains('röra')) {
      tags.add('rökt');
    }

    return tags;
  }

  /// Calculates dish type tags from recipe title.
  Set<String> _calculateDishTypeTags(String title) {
    final tags = <String>{};
    final titleLower = title.toLowerCase();

    final dishTypes = {
      'soppa': ['soppa', 'buljong'],
      'sallad': ['sallad'],
      'gryta': ['gryta'],
      'gratäng': ['gratäng'],
      'curry': ['curry'],
      'smörgås': ['smörgås', 'macka'],
      'hamburgare': ['hamburgare', 'burger'],
      'pizza': ['pizza'],
      'taco': ['taco', 'tacos'],
      'bowl': ['bowl', 'poké', 'poke'],
      'paj': ['paj', 'pie', 'quiche'],
      'kaka': ['kaka', 'tårta'],
      'bröd': ['bröd'],
      'köttbullar': ['köttbull'],
      'omelett': ['omelett'],
      'pannkaka': ['pannkak', 'crêpe', 'crepe'],
      'våffla': ['våffl'],
      'smoothie': ['smoothie'],
      'wok': ['wok'],
      'dipp': ['dipp', 'dip'],
      'sås': ['sås'],
    };

    for (final entry in dishTypes.entries) {
      for (final keyword in entry.value) {
        if (titleLower.contains(keyword)) {
          // Special case: don't tag 'kaka' if it's 'pannkaka'
          if (entry.key == 'kaka' && titleLower.contains('pannkak')) {
            continue;
          }
          tags.add(entry.key);
          break;
        }
      }
    }

    return tags;
  }
}

/// Result of Phase 1 calculation.
class Phase1Result {
  final Set<String> tags;
  final Map<String, TriState> allergenStatus;
  final Map<String, TriState> dietaryStatus;
  final IngredientLookupResult lookup;

  const Phase1Result({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.lookup,
  });

  /// Checks if a specific property exists in any ingredient.
  bool hasProperty(String property) => lookup.hasProperty(property);

  /// Checks if a specific tag was generated.
  bool hasTag(String tag) => tags.contains(tag);

  /// Gets allergen status for a specific allergen.
  TriState getAllergenStatus(String key) =>
      allergenStatus[key] ?? TriState.unknown;

  /// Gets dietary status for a specific diet.
  TriState getDietaryStatus(String key) =>
      dietaryStatus[key] ?? TriState.unknown;
}
