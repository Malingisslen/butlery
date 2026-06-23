import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Protein and carb/base tag calculation for Phase 1.
class Phase1NutritionCalculator {
  /// Calculates protein tags from ingredient groups.
  static Set<String> calculateProteinTags(IngredientLookupResult lookup) {
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

    if (lookup.hasGroup('protein/meat/beef')) tags.add('nötkött');
    if (lookup.hasGroup('protein/meat/pork')) tags.add('fläskkött');
    if (lookup.hasGroup('protein/meat/lamb')) tags.add('lamm');
    if (lookup.hasGroup('protein/meat/game')) tags.add('vilt');

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

    if (lookup.hasGroup('vegetable/legume')) tags.add('baljväxter');
    if (lookup.hasGroup('protein/egg')) tags.add('ägg');

    return tags;
  }

  static const _pastaKeywords = [
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

  /// Calculates carb/base tags.
  static Set<String> calculateCarbTags(
    IngredientLookupResult lookup,
    Recipe recipe,
  ) {
    final tags = <String>{};

    final hasPasta = lookup.matched.any(
      (i) =>
          i.group.contains('pasta-bread') &&
          _pastaKeywords.any((k) => i.swedish.toLowerCase().contains(k)),
    );
    if (hasPasta) tags.add('pastabaserad');

    // Use word boundary to avoid false positives (e.g., "korianderfrisk" → "ris")
    final hasRice = lookup.matched.any(
      (i) =>
          TagPhase1Base.containsSwedishWord(i.swedish.toLowerCase(), 'ris') &&
          i.group.contains('grain'),
    );
    if (hasRice) tags.add('risbaserad');

    final hasPotato = lookup.matched.any(
      (i) =>
          i.swedish.toLowerCase().contains('potatis') &&
          i.group.contains('vegetable/root'),
    );
    if (hasPotato) tags.add('potatisbaserad');

    final hasNoodles = lookup.matched.any((i) {
      final nameLower = i.swedish.toLowerCase();
      return nameLower.contains('nudl') ||
          nameLower.contains('wontonnudl') ||
          nameLower.contains('risnudl') ||
          nameLower.contains('glasnudl');
    });
    if (hasNoodles) tags.add('nudelbaserad');

    final hasBread = lookup.matched.any(
      (i) =>
          i.group.contains('grain/bread') ||
          i.swedish.toLowerCase().contains('bröd'),
    );
    if (hasBread) tags.add('brödbaserad');

    if (lookup.hasGroup('grain/whole')) tags.add('fullkorn');

    return tags;
  }
}
