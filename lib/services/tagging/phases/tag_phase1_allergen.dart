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
  /// The marine detail properties. A row carrying [_genericMarineProperty]
  /// and none of these is marine of an unknown kind (register audit
  /// 2026-07-01: the validated skaldjursfond row), so no allergen that
  /// triggers on one of these can be proven absent from it.
  static const Set<String> _marineDetailProperties = {
    'fish',
    'crustacean',
    'mollusc',
  };

  static const String _genericMarineProperty = 'seafood';

  /// Calculates allergen status using tri-valued logic.
  ///
  /// A matched trigger gives CONTAINS whatever the coverage; coverage < 100%
  /// only withholds FREE (BUT-2247).
  ///
  /// Returns both status map and decision logs.
  static StatusWithDecisions calculate(
    IngredientLookupResult lookup,
    FirebaseTagConfig? firebaseConfig,
  ) {
    final status = <String, TriState>{};
    final decisions = <TagDecision>[];
    final triggersByKey = <String, List<String>>{};

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
        triggersByKey[allergen.key] = [prop];

        final (reason, triggers) = _explainAllergenDecision(
          lookup: lookup,
          property: prop,
          result: result,
        );
        decisions.add(
          TagDecision.allergen(
            key: allergen.key,
            result: result,
            reason: reason,
            triggeringIngredients: triggers,
          ),
        );
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
        triggersByKey[allergen.key] = [allergen.triggerProperty];

        final (reason, triggers) = _explainAllergenDecision(
          lookup: lookup,
          property: allergen.triggerProperty,
          result: result,
        );
        decisions.add(
          TagDecision.allergen(
            key: allergen.key,
            result: result,
            reason: reason,
            triggeringIngredients: triggers,
          ),
        );
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
        triggersByKey[allergen.key] = props;

        final (reason, triggers) = _explainCombinedAllergenDecision(
          lookup: lookup,
          properties: props,
          result: result,
          allergenKey: allergen.key,
        );
        decisions.add(
          TagDecision.allergen(
            key: allergen.key,
            result: result,
            reason: reason,
            triggeringIngredients: triggers,
          ),
        );
      }
    } else {
      for (final allergen in static_allergen.AllergenConfig.combinedAllergens) {
        final props = allergen.triggerProperties;
        final result = lookup.getCombinedPropertyStatus(props);
        status[allergen.key] = result;
        triggersByKey[allergen.key] = props;

        final (reason, triggers) = _explainCombinedAllergenDecision(
          lookup: lookup,
          properties: props,
          result: result,
          allergenKey: allergen.key,
        );
        decisions.add(
          TagDecision.allergen(
            key: allergen.key,
            result: result,
            reason: reason,
            triggeringIngredients: triggers,
          ),
        );
      }
    }

    _withholdMarineFreeOnGenericSeafood(
      lookup: lookup,
      status: status,
      decisions: decisions,
      triggersByKey: triggersByKey,
    );

    return StatusWithDecisions(status: status, decisions: decisions);
  }

  /// A matched row that says only "marine" cannot prove any marine allergen
  /// absent: every FREE on an allergen with a marine detail property among
  /// its triggers becomes UNKNOWN. CONTAINS verdicts are left alone.
  static void _withholdMarineFreeOnGenericSeafood({
    required IngredientLookupResult lookup,
    required Map<String, TriState> status,
    required List<TagDecision> decisions,
    required Map<String, List<String>> triggersByKey,
  }) {
    final genericMarineRows = lookup.matched
        .where(
          (i) =>
              i.hasProperty(_genericMarineProperty) &&
              !i.hasAnyProperty(_marineDetailProperties),
        )
        .map((i) => i.swedish)
        .toList();
    if (genericMarineRows.isEmpty) return;

    for (final entry in triggersByKey.entries) {
      final key = entry.key;
      final isMarineKey = entry.value.any(_marineDetailProperties.contains);
      if (!isMarineKey || status[key] != TriState.free) continue;

      status[key] = TriState.unknown;
      decisions.removeWhere((d) => d.type == 'allergen' && d.key == key);
      decisions.add(
        TagDecision.allergen(
          key: key,
          result: TriState.unknown,
          reason:
              'Ingredient with only the generic "$_genericMarineProperty" '
              'property - cannot confirm which marine allergen',
          triggeringIngredients: genericMarineRows,
        ),
      );
    }
  }

  static (String reason, List<String>? triggers) _explainAllergenDecision({
    required IngredientLookupResult lookup,
    required String property,
    required TriState result,
  }) {
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

    if (lookup.coverage < 1.0) {
      final coveragePercent = (lookup.coverage * 100).round();
      return (
        'Coverage $coveragePercent% < 100% - cannot confirm',
        null,
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

    if (lookup.coverage < 1.0) {
      final coveragePercent = (lookup.coverage * 100).round();
      return (
        'Coverage $coveragePercent% < 100% - cannot confirm',
        null,
      );
    }

    final propsStr = properties.join(' or ');
    return (
      'No ingredients with properties ($propsStr) at 100% coverage',
      null,
    );
  }
}
