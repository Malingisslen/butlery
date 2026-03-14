import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart'
    as static_dietary;
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Dietary status calculation for Phase 1.
class Phase1DietaryCalculator {
  /// Calculates dietary status.
  ///
  /// Returns both status map and decision logs.
  static StatusWithDecisions calculate(
    IngredientLookupResult lookup,
    FirebaseTagConfig? firebaseConfig,
  ) {
    final status = <String, TriState>{};
    final decisions = <TagDecision>[];
    final coveragePercent = (lookup.coverage * 100).round();

    final dietaryEntries = firebaseConfig?.dietary.enabledEntries;

    if (dietaryEntries != null) {
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
      AppLogger.warning(
        'Firebase dietary config unavailable - using static fallback. '
            'Admin config changes will not be applied.',
        'Phase1DietaryCalculator',
      );
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

    return StatusWithDecisions(status: status, decisions: decisions);
  }

  static void _processDietaryEntry({
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

    final hasExcluded = lookup.hasAnyProperty(excludedProperties);

    if (hasExcluded) {
      status[key] = TriState.contains;

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
      // HIGH-4: PESCETARIAN LOGIC
      // Pescetarian can eat any dish without meat - whether or not it contains fish.
      final hasRequired = lookup.hasAnyProperty(requiredProperties);
      if (hasRequired) {
        status[key] = TriState.free;
        decisions.add(TagDecision.dietary(
          key: key,
          result: TriState.free,
          reason:
              'Has required (${requiredProperties.join(", ")}), no excluded',
        ));
      } else {
        // HIGH-4: No fish AND no meat = FREE (vegetarian dishes are pescetarian-compatible)
        status[key] = TriState.free;
        decisions.add(TagDecision.dietary(
          key: key,
          result: TriState.free,
          reason:
              'No excluded properties (vegetarian dishes are pescetarian-compatible)',
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
}
