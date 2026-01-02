import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart'
    as static_allergen;
import 'package:butlery/services/tagging/config/dietary_config.dart'
    as static_dietary;

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
  /// Firebase-backed config (optional, falls back to static config).
  final FirebaseTagConfig? _firebaseConfig;

  /// Creates a Phase 1 calculator.
  ///
  /// If [firebaseConfig] is provided, uses Firebase-backed allergen and dietary
  /// configs. Otherwise falls back to hardcoded static configs.
  TagPhase1Base({FirebaseTagConfig? firebaseConfig})
      : _firebaseConfig = firebaseConfig;

  /// Calculates Phase 1 tags.
  Phase1Result calculate(IngredientLookupResult lookup, Recipe recipe) {
    final tags = <String>{};
    final decisions = <TagDecision>[];

    // Time tags from metadata
    tags.addAll(_calculateTimeTags(recipe.core.timeMinutes));

    // Allergen status using tri-valued logic (H3: with decision capture)
    final allergenResult = _calculateAllergenStatus(lookup);

    // Dietary status (H3: with decision capture)
    final dietaryResult = _calculateDietaryStatus(lookup);

    // Collect all decisions
    decisions.addAll(allergenResult.decisions);
    decisions.addAll(dietaryResult.decisions);

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
      allergenStatus: allergenResult.status,
      dietaryStatus: dietaryResult.status,
      lookup: lookup,
      decisions: decisions,
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
  /// H3: Returns both status map and decision logs.
  _StatusWithDecisions _calculateAllergenStatus(IngredientLookupResult lookup) {
    final status = <String, TriState>{};
    final decisions = <TagDecision>[];

    // Get allergen entries from Firebase config or fall back to static config
    final simpleAllergens = _firebaseConfig?.allergens.simpleAllergens;
    final combinedAllergens = _firebaseConfig?.allergens.combinedAllergens;

    // Process simple allergens first
    if (simpleAllergens != null) {
      // Use Firebase config
      for (final allergen in simpleAllergens) {
        final prop = allergen.triggerProperties.first;
        final result = lookup.getPropertyStatus(prop);
        status[allergen.key] = result;

        final (reason, triggers) = _explainAllergenDecision(
          lookup: lookup,
          property: prop,
          result: result,
        );
        decisions.add(TagDecision.allergen(
          key: allergen.key,
          result: result,
          reason: reason,
          triggeringIngredients: triggers,
        ));
      }
    } else {
      // Fall back to static config
      for (final allergen in static_allergen.AllergenConfig.simpleAllergens) {
        final result = lookup.getPropertyStatus(allergen.triggerProperty);
        status[allergen.key] = result;

        final (reason, triggers) = _explainAllergenDecision(
          lookup: lookup,
          property: allergen.triggerProperty,
          result: result,
        );
        decisions.add(TagDecision.allergen(
          key: allergen.key,
          result: result,
          reason: reason,
          triggeringIngredients: triggers,
        ));
      }
    }

    // Process combined allergens using OR logic
    if (combinedAllergens != null) {
      // Use Firebase config
      for (final allergen in combinedAllergens) {
        final props = allergen.triggerProperties;
        final result = lookup.getCombinedPropertyStatus(props);
        status[allergen.key] = result;

        final (reason, triggers) = _explainCombinedAllergenDecision(
          lookup: lookup,
          properties: props,
          result: result,
          allergenKey: allergen.key,
        );
        decisions.add(TagDecision.allergen(
          key: allergen.key,
          result: result,
          reason: reason,
          triggeringIngredients: triggers,
        ));
      }
    } else {
      // Fall back to static config
      for (final allergen in static_allergen.AllergenConfig.combinedAllergens) {
        final props = allergen.triggerProperties;
        final result = lookup.getCombinedPropertyStatus(props);
        status[allergen.key] = result;

        final (reason, triggers) = _explainCombinedAllergenDecision(
          lookup: lookup,
          properties: props,
          result: result,
          allergenKey: allergen.key,
        );
        decisions.add(TagDecision.allergen(
          key: allergen.key,
          result: result,
          reason: reason,
          triggeringIngredients: triggers,
        ));
      }
    }

    return _StatusWithDecisions(status: status, decisions: decisions);
  }

  /// H3: Explains why an allergen decision was made.
  (String reason, List<String>? triggers) _explainAllergenDecision({
    required IngredientLookupResult lookup,
    required String property,
    required TriState result,
  }) {
    final coveragePercent = (lookup.coverage * 100).round();

    if (lookup.coverage < 1.0) {
      return (
        'Coverage $coveragePercent% < 100% - cannot confirm',
        null,
      );
    }

    if (result == TriState.contains) {
      final triggers = lookup.matched
          .where((i) => i.hasProperty(property))
          .map((i) => i.swedish)
          .toList();
      return (
        'Ingredient with property "$property" found',
        triggers.isNotEmpty ? triggers : null,
      );
    }

    return (
      'No ingredients with property "$property" at 100% coverage',
      null,
    );
  }

  /// H3: Explains why a combined allergen decision was made.
  (String reason, List<String>? triggers) _explainCombinedAllergenDecision({
    required IngredientLookupResult lookup,
    required List<String> properties,
    required TriState result,
    required String allergenKey,
  }) {
    final coveragePercent = (lookup.coverage * 100).round();

    if (lookup.coverage < 1.0) {
      return (
        'Coverage $coveragePercent% < 100% - cannot confirm',
        null,
      );
    }

    if (result == TriState.contains) {
      // L1 fix: Use Set to deduplicate triggers - an ingredient with multiple
      // triggering properties (e.g., both crustacean AND mollusc) should only
      // appear once in the triggers list.
      final triggers = <String>{};
      for (final prop in properties) {
        triggers.addAll(
          lookup.matched
              .where((i) => i.hasProperty(prop))
              .map((i) => i.swedish),
        );
      }
      final propsStr = properties.join(' or ');
      return (
        'Ingredient with property ($propsStr) found',
        triggers.isNotEmpty ? triggers.toList() : null,
      );
    }

    final propsStr = properties.join(' or ');
    return (
      'No ingredients with properties ($propsStr) at 100% coverage',
      null,
    );
  }

  /// Calculates dietary status.
  /// H3: Returns both status map and decision logs.
  _StatusWithDecisions _calculateDietaryStatus(IngredientLookupResult lookup) {
    final status = <String, TriState>{};
    final decisions = <TagDecision>[];
    final coveragePercent = (lookup.coverage * 100).round();

    // Get dietary entries from Firebase config or fall back to static config
    final dietaryEntries = _firebaseConfig?.dietary.enabledEntries;

    if (dietaryEntries != null) {
      // Use Firebase config
      for (final dietary in dietaryEntries) {
        _processDietaryEntry(
          lookup: lookup,
          key: dietary.key,
          excludedProperties: dietary.excludedProperties,
          requiredProperties: dietary.requiredProperties.isEmpty
              ? null
              : dietary.requiredProperties,
          requiresFullCoverage: dietary.requiresFullCoverage,
          status: status,
          decisions: decisions,
          coveragePercent: coveragePercent,
        );
      }
    } else {
      // Fall back to static config
      for (final dietary in static_dietary.DietaryConfig.all) {
        _processDietaryEntry(
          lookup: lookup,
          key: dietary.key,
          excludedProperties: dietary.excludedProperties,
          requiredProperties: dietary.requiredProperties,
          requiresFullCoverage: dietary.requiresFullCoverage,
          status: status,
          decisions: decisions,
          coveragePercent: coveragePercent,
        );
      }
    }

    return _StatusWithDecisions(status: status, decisions: decisions);
  }

  /// Processes a single dietary entry and updates status/decisions.
  void _processDietaryEntry({
    required IngredientLookupResult lookup,
    required String key,
    required List<String> excludedProperties,
    required List<String>? requiredProperties,
    required bool requiresFullCoverage,
    required Map<String, TriState> status,
    required List<TagDecision> decisions,
    required int coveragePercent,
  }) {
    if (requiresFullCoverage && lookup.coverage < 1.0) {
      status[key] = TriState.unknown;
      decisions.add(TagDecision.dietary(
        key: key,
        result: TriState.unknown,
        reason: 'Coverage $coveragePercent% < 100% - cannot confirm',
      ));
      return;
    }

    // Check excluded properties
    final hasExcluded = lookup.hasAnyProperty(excludedProperties);

    if (hasExcluded) {
      // Has excluded ingredients (e.g., meat for pescetarian)
      status[key] = TriState.contains;

      // H3: Find triggering ingredients
      final triggers = <String>[];
      for (final prop in excludedProperties) {
        triggers.addAll(
          lookup.matched
              .where((i) => i.hasProperty(prop))
              .map((i) => i.swedish),
        );
      }
      decisions.add(TagDecision.dietary(
        key: key,
        result: TriState.contains,
        reason: 'Has excluded property (${excludedProperties.join(", ")})',
        triggeringIngredients: triggers.isNotEmpty ? triggers : null,
      ));
    } else if (requiredProperties != null) {
      // MED-6: PESCETARIAN LOGIC EXPLANATION
      //
      // Pescetarian is special because it requires BOTH:
      // 1. NO excluded properties (no meat - already checked above)
      // 2. HAS required properties (fish or shellfish)
      //
      // Decision tree for pescetarian:
      // ┌─ Has meat? ─────────────────────> CONTAINS (not pescetarian)
      // │   └─ No meat, has fish? ────────> FREE (valid pescetarian dish)
      // │       └─ No meat, no fish? ─────> UNKNOWN (might be vegetarian side)
      //
      // Why UNKNOWN and not FREE for no-meat-no-fish?
      // A recipe without fish is not "pescetarian-safe" - it just happens
      // to be compatible. We only claim FREE when the recipe positively
      // demonstrates pescetarian intent (includes seafood but no meat).
      final hasRequired = lookup.hasAnyProperty(requiredProperties);
      if (hasRequired) {
        // Has fish/shellfish, no meat = valid pescetarian dish
        status[key] = TriState.free;
        decisions.add(TagDecision.dietary(
          key: key,
          result: TriState.free,
          reason:
              'Has required (${requiredProperties.join(", ")}), no excluded',
        ));
      } else {
        // No fish AND no meat = unknown (could be vegetarian side dish)
        status[key] = TriState.unknown;
        decisions.add(TagDecision.dietary(
          key: key,
          result: TriState.unknown,
          reason:
              'No excluded but missing required (${requiredProperties.join(", ")})',
        ));
      }
    } else {
      status[key] = TriState.free;
      decisions.add(TagDecision.dietary(
        key: key,
        result: TriState.free,
        reason: 'No excluded properties at 100% coverage',
      ));
    }
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

    // L11: Expanded plant-based protein detection
    final plantProtein = lookup.getIngredientsInGroup('protein/plant-based');
    for (final ingredient in plantProtein) {
      final nameLower = ingredient.swedish.toLowerCase();
      if (nameLower.contains('tofu')) {
        tags.add('tofu');
      } else if (nameLower.contains('tempeh')) {
        tags.add('tempeh');
      } else if (nameLower.contains('seitan')) {
        tags.add('seitan');
      } else if (nameLower.contains('quorn')) {
        tags.add('quorn');
      } else if (nameLower.contains('sojafärs') ||
          nameLower.contains('växtfärs') ||
          nameLower.contains('veggofärs')) {
        tags.add('växtfärs');
      } else if (nameLower.contains('bönbiff') ||
          nameLower.contains('bönburgare')) {
        tags.add('bönprotein');
      } else if (nameLower.contains('oumph')) {
        tags.add('oumph');
      } else if (nameLower.contains('hälsans kök') ||
          nameLower.contains('halsans kok')) {
        tags.add('växtprotein');
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

    // Check for pasta (expanded to include more types)
    final pastaKeywords = [
      'pasta',
      'spagetti',
      'spaghetti',
      'penne',
      'lasagne',
      'tagliatelle',
      'fettuccine',
      'fettucine',
      'ravioli',
      'tortellini',
      'gnocchi',
      'rigatoni',
      'fusilli',
      'farfalle',
      'linguine',
      'orzo',
      'makaroner',
      'cannelloni',
    ];
    final hasPasta = lookup.matched.any((i) =>
        i.group.contains('pasta-bread') &&
        pastaKeywords.any((k) => i.swedish.toLowerCase().contains(k)));

    if (hasPasta) {
      tags.add('pastabaserad');
    }

    // Check for rice - use word boundary to avoid false positives
    // (e.g., "korianderfrisk" shouldn't match "ris")
    final ricePattern =
        RegExp(r'(?:^|[^a-zåäö])ris(?:[^a-zåäö]|$)', caseSensitive: false);
    final hasRice = lookup.matched.any((i) =>
        ricePattern.hasMatch(i.swedish.toLowerCase()) &&
        i.group.contains('grain'));

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
  ///
  /// Uses word boundary matching to avoid false positives from substrings.
  Set<String> _calculateCookingMethodTags(List<String> instructions) {
    final tags = <String>{};
    final text = instructions.join(' ').toLowerCase();

    // Helper for word boundary matching
    // Matches word at start boundary (no letter before) but allows suffixes.
    // This is intentional for Swedish where words commonly have suffixes:
    // e.g., "grilla" (to grill), "grillad" (grilled), "grillar" (grills)
    bool hasWord(String word) {
      // For Swedish, we match word stems that can have suffixes
      // Only check word START boundary to prevent false positives like "lugn" matching "ugn"
      final pattern = RegExp('(?:^|[^a-zåäö])$word', caseSensitive: false);
      return pattern.hasMatch(text);
    }

    // Oven baked - match "ugn" but not "lugn"
    if ((hasWord('ugn') || text.contains('°c') || hasWord('grader')) &&
        !hasWord('mikro') &&
        !hasWord('micro')) {
      tags.add('ugnsbakad');
    }

    // Pan fried - "stek", "steka", "stekt", "bryn", "bryna"
    if (hasWord('stek') || hasWord('bryn')) {
      tags.add('stekt');
    }

    // Grilled
    if (hasWord('grill')) {
      tags.add('grillad');
    }

    // Boiled - "koka", "kokar", "kokt", "sjud", "sjuda"
    if (hasWord('koka') || hasWord('kok') || hasWord('sjud')) {
      tags.add('kokt');
    }

    // Steamed
    if (hasWord('ångkok') || hasWord('ånga')) {
      tags.add('ångkokt');
    }

    // Poached
    if (hasWord('pochera') || hasWord('pocherad')) {
      tags.add('pocherad');
    }

    // Deep fried
    if (hasWord('fritera') || hasWord('friterad') || hasWord('fritering')) {
      tags.add('friterad');
    }

    // Air fryer - exact phrases
    if (text.contains('airfryer') || text.contains('air fryer')) {
      tags.add('airfryer');
    }

    // Slow cooker - exact phrases
    if (text.contains('slow cooker') || text.contains('crock pot')) {
      tags.add('slow-cooker');
    }

    // Pressure cooker
    if (hasWord('tryckkokare') || text.contains('instant pot')) {
      tags.add('tryckkokare');
    }

    // Sous vide - exact phrases
    if (text.contains('sous vide') || text.contains('sous-vide')) {
      tags.add('sous-vide');
    }

    // Wok - match "wok", "woka", "wokat"
    if (hasWord('wok')) {
      tags.add('wokad');
    }

    // Microwave
    if (hasWord('micro') || hasWord('mikro')) {
      tags.add('microugn');
    }

    // Smoked - "rök" but exclude "röra" and "rörelse"
    if (hasWord('rök') && !hasWord('röra') && !hasWord('rörelse')) {
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

  /// H3: Decision logs explaining why each allergen/dietary status was set.
  final List<TagDecision> decisions;

  const Phase1Result({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.lookup,
    this.decisions = const [],
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

  /// H3: Gets the decision that produced a specific allergen status.
  TagDecision? getAllergenDecision(String key) =>
      decisions.where((d) => d.type == 'allergen' && d.key == key).firstOrNull;

  /// H3: Gets the decision that produced a specific dietary status.
  TagDecision? getDietaryDecision(String key) =>
      decisions.where((d) => d.type == 'dietary' && d.key == key).firstOrNull;
}

/// H3: Helper class for returning both status and decisions.
class _StatusWithDecisions {
  final Map<String, TriState> status;
  final List<TagDecision> decisions;

  const _StatusWithDecisions({
    required this.status,
    required this.decisions,
  });
}
