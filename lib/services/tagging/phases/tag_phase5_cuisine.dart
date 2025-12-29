import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';

/// Phase 5: Cuisine detection requiring all previous phases.
///
/// Generates cuisine tags based on:
/// - Recipe title keywords (e.g., "Thai", "Pasta", "Taco")
/// - Ingredient patterns (e.g., soy sauce + sesame = Asian)
///
/// Supports 17 world cuisines including Swedish, Mediterranean, Asian, etc.
class TagPhase5Cuisine {
  /// Calculates Phase 5 cuisine tags.
  Phase5Result calculate(Phase4Result p4, Recipe recipe) {
    final tags = <String>{};

    // Check each cuisine for matches
    for (final cuisine in CuisineConfig.cuisines) {
      if (cuisine.matches(recipe, p4.phase1.lookup)) {
        tags.add(cuisine.tag);
      }
    }

    return Phase5Result(
      tags: tags,
      phase4: p4,
    );
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
