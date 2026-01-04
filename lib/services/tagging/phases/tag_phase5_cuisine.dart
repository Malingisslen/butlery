import 'package:butlery/models/recipe_unified.dart';
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
/// ## CRIT-7 Fix: Fallback Support
/// Phase 5 only needs Phase 1's ingredient lookup to detect cuisines.
/// If Phases 2-4 timeout or fail, Phase 5 can still run using [calculateFromPhase1].
class TagPhase5Cuisine {
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
    final tags = <String>{};

    for (final cuisine in CuisineConfig.cuisines) {
      if (cuisine.matches(recipe, p1.lookup)) {
        tags.add(cuisine.tag);
      }
    }

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
    final tags = <String>{};

    for (final cuisine in CuisineConfig.cuisines) {
      if (cuisine.matches(recipe, lookup)) {
        tags.add(cuisine.tag);
      }
    }

    return Phase5Result(
      tags: tags,
      phase4: p4!,
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
