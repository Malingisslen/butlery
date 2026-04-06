import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart'
    as firebase_config;
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';

/// Phase 5: Cuisine detection.
///
/// Generates cuisine tags based on:
/// - Recipe title keywords (e.g., "Thai", "Pasta", "Taco")
/// - Ingredient patterns (e.g., soy sauce + sesame = Asian)
///
/// Supports 17 world cuisines including Swedish, Mediterranean, Asian, etc.
///
/// If [firebaseConfig] is provided, uses Firebase-backed cuisine definitions
/// (admin-editable without app release). Falls back to hardcoded static config.
///
/// ## CRIT-7 Fix: Fallback Support
/// Phase 5 only needs Phase 1's ingredient lookup to detect cuisines.
/// If Phases 2-4 timeout or fail, Phase 5 can still run using [calculateFromPhase1].
class TagPhase5Cuisine {
  final firebase_config.FirebaseTagConfig? _firebaseConfig;

  TagPhase5Cuisine({firebase_config.FirebaseTagConfig? firebaseConfig})
      : _firebaseConfig = firebaseConfig;

  /// Calculates Phase 5 cuisine tags (full chain).
  ///
  /// Use this when all phases completed successfully.
  Phase5Result calculate(Phase4Result p4, Recipe recipe) {
    return _calculateCuisines(recipe, p4.phase1.lookup, p4);
  }

  /// CRIT-7: Calculates Phase 5 cuisine tags with Phase 1 fallback.
  ///
  /// Use this when Phases 2-4 failed or timed out but we still want cuisine detection.
  /// Only requires Phase 1 results (ingredient lookup).
  Phase5ResultPartial calculateFromPhase1(Phase1Result p1, Recipe recipe) {
    final tags = _detectCuisines(recipe, p1.lookup);

    return Phase5ResultPartial(
      tags: tags,
      phase1: p1,
    );
  }

  Phase5Result _calculateCuisines(
    Recipe recipe,
    dynamic lookup,
    Phase4Result? p4,
  ) {
    final tags = _detectCuisines(recipe, lookup as IngredientLookupResult);

    return Phase5Result(
      tags: tags,
      phase4: p4!,
    );
  }

  /// Core cuisine detection using Firebase config with static fallback.
  /// If Schema.org provides an explicit cuisine, use it as a strong signal.
  Set<String> _detectCuisines(Recipe recipe, IngredientLookupResult lookup) {
    final tags = <String>{};

    // Schema.org cuisine is a strong signal — use it directly if available
    final schemaCuisine = recipe.cuisine;
    if (schemaCuisine != null && schemaCuisine.isNotEmpty) {
      final matched = _matchSchemaCuisineToTag(schemaCuisine);
      if (matched != null) {
        tags.add(matched);
        return tags;
      }
    }

    // Use Firebase cuisine entries if available
    final firebaseCuisines = _firebaseConfig?.cuisines.enabledEntries;
    if (firebaseCuisines != null && firebaseCuisines.isNotEmpty) {
      for (final cuisine in firebaseCuisines) {
        if (_matchesFirebaseCuisine(cuisine, recipe, lookup)) {
          tags.add(cuisine.getTag('sv'));
        }
      }
      return tags;
    }

    // Fall back to static config
    if (CuisineConfig.cuisines.isEmpty) {
      AppLogger.warning(
        'CuisineConfig.cuisines is empty - cuisine detection disabled',
        'TagPhase5Cuisine',
      );
    }

    for (final cuisine in CuisineConfig.cuisines) {
      if (cuisine.matches(recipe, lookup)) {
        tags.add(cuisine.tag);
      }
    }

    return tags;
  }

  /// Map a Schema.org cuisine string (e.g., "Italian", "Thai") to a known tag.
  String? _matchSchemaCuisineToTag(String schemaCuisine) {
    final lower = schemaCuisine.toLowerCase();
    // Check Firebase config first
    final firebaseCuisines = _firebaseConfig?.cuisines.enabledEntries;
    if (firebaseCuisines != null) {
      for (final c in firebaseCuisines) {
        if (c.titleKeywords.any((kw) => lower.contains(kw.toLowerCase()))) {
          return c.getTag('sv');
        }
      }
    }
    // Fallback to static config
    for (final c in CuisineConfig.cuisines) {
      if (c.titleKeywords.any((kw) => lower.contains(kw.toLowerCase()))) {
        return c.tag;
      }
    }
    return null;
  }

  /// Matches a recipe against a Firebase cuisine entry, respecting matchMode.
  bool _matchesFirebaseCuisine(
    firebase_config.CuisineEntry cuisine,
    Recipe recipe,
    IngredientLookupResult lookup,
  ) {
    switch (cuisine.matchMode) {
      case firebase_config.CuisineMatchMode.titleOnly:
        return _hasTitleMatch(cuisine, recipe);
      case firebase_config.CuisineMatchMode.ingredientsOnly:
        return _hasIngredientMatch(cuisine, lookup);
      case firebase_config.CuisineMatchMode.titleAndIngredients:
        return _hasTitleMatch(cuisine, recipe) &&
            _hasIngredientMatch(cuisine, lookup);
      case firebase_config.CuisineMatchMode.titleOrIngredients:
        return _hasTitleMatch(cuisine, recipe) ||
            _hasIngredientMatch(cuisine, lookup);
    }
  }

  bool _hasTitleMatch(
    firebase_config.CuisineEntry cuisine,
    Recipe recipe,
  ) {
    final title = recipe.core.title.toLowerCase();
    for (final keyword in cuisine.titleKeywords) {
      if (title.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool _hasIngredientMatch(
    firebase_config.CuisineEntry cuisine,
    IngredientLookupResult lookup,
  ) {
    int matches = 0;

    for (final ingredient in lookup.matched) {
      final name = ingredient.swedish.toLowerCase();
      final group = ingredient.group.toLowerCase();

      for (final keyword in cuisine.ingredientKeywords) {
        if (name.contains(keyword.toLowerCase())) {
          matches++;
          break;
        }
      }

      for (final groupPattern in cuisine.ingredientGroups) {
        if (group.contains(groupPattern.toLowerCase())) {
          matches++;
          break;
        }
      }
    }

    return matches >= cuisine.minIngredientMatches;
  }
}

/// Result of Phase 5 calculation.
class Phase5Result {
  final Set<String> tags;
  final Phase4Result phase4;

  const Phase5Result({
    required this.tags,
    required this.phase4,
  });

  /// Gets all tags from all phases combined.
  Set<String> get allTags => {
        ...phase4.allTags,
        ...tags,
      };

  /// Convenience: Check if a tag exists in any phase.
  bool hasTag(String tag) => allTags.contains(tag);

  /// Convenience: Access Phase 1 result.
  Phase1Result get phase1 => phase4.phase1;

  /// Convenience: Access Phase 2 result.
  Phase2Result get phase2 => phase4.phase2;

  /// Convenience: Access Phase 3 result.
  Phase3Result get phase3 => phase4.phase3;
}

/// CRIT-7: Partial result when only Phase 1 is available.
///
/// Used when Phases 2-4 fail or timeout but we still want cuisine detection.
/// Contains only Phase 5 cuisine tags and Phase 1 reference (no access to
/// intermediate phase results).
class Phase5ResultPartial {
  final Set<String> tags;
  final Phase1Result phase1;

  const Phase5ResultPartial({
    required this.tags,
    required this.phase1,
  });

  /// Gets all tags (Phase 1 + Phase 5 cuisine tags).
  Set<String> get allTags => {
        ...phase1.tags,
        ...tags,
      };

  /// Convenience: Check if a tag exists.
  bool hasTag(String tag) => allTags.contains(tag);
}
