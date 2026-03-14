import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart'
    as static_allergen;
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Allergen status calculation for Phase 1.
class Phase1AllergenCalculator {
  /// Calculates allergen status using tri-valued logic.
  ///
  /// Returns both status map and decision logs.
  static StatusWithDecisions calculate(
    IngredientLookupResult lookup,
    FirebaseTagConfig? firebaseConfig,
  ) {
    final status = <String, TriState>{};
    final decisions = <TagDecision>[];

    final simpleAllergens = firebaseConfig?.allergens.simpleAllergens;
    final combinedAllergens = firebaseConfig?.allergens.combinedAllergens;

    // Process simple allergens first
    if (simpleAllergens != null) {
      for (final allergen in simpleAllergens) {
        if (allergen.triggerProperties.isEmpty) {
          AppLogger.error(
            'CRIT-1: Allergen "${allergen.key}" has empty triggerProperties - '
                'check Firebase config. Skipping this allergen.',
            'Phase1AllergenCalculator',
          );
          continue;
        }
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
      AppLogger.warning(
        'Firebase allergen config unavailable - using static fallback. '
            'Admin config changes will not be applied.',
        'Phase1AllergenCalculator',
      );
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
      for (final allergen in combinedAllergens) {
        final props = allergen.triggerProperties;
        if (props.isEmpty) {
          AppLogger.error(
            'CRIT-1: Combined allergen "${allergen.key}" has empty triggerProperties - '
                'check Firebase config. Skipping this allergen.',
            'Phase1AllergenCalculator',
          );
          continue;
        }
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

    return StatusWithDecisions(status: status, decisions: decisions);
  }

  static (String reason, List<String>? triggers) _explainAllergenDecision({
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

  static (String reason, List<String>? triggers)
      _explainCombinedAllergenDecision({
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
}
