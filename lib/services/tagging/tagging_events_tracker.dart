import 'package:butlery/repositories/interfaces/analytics_repository.dart';

/// Tracks tagging-related analytics events.
/// Uses AnalyticsRepository to log events without direct Firebase dependency.
class TaggingEventsTracker {
  final AnalyticsRepository _analytics;

  TaggingEventsTracker(this._analytics);

  /// Log tagging performance metrics.
  Future<void> logTaggingPerformance({
    required int totalMs,
    required int lookupMs,
    int? generateMs,
    required int ingredientCount,
    required int tagCount,
    required double coveragePercent,
    required String status,
  }) async {
    await _analytics.logEvent(
      name: 'tagging_performance',
      parameters: {
        'total_ms': totalMs,
        'lookup_ms': lookupMs,
        'generate_ms': generateMs ?? 0,
        'ingredient_count': ingredientCount,
        'tag_count': tagCount,
        'coverage_percent': coveragePercent.round(),
        'status': status,
      },
    );
  }

  /// Log when a recipe is tagged.
  Future<void> logRecipeTagged({
    required String recipeId,
    required int tagCount,
    required double coverage,
    required bool hasAllergens,
    required bool hasDietary,
  }) async {
    await _analytics.logEvent(
      name: 'recipe_tagged',
      parameters: {
        'recipe_id': recipeId,
        'tag_count': tagCount,
        'coverage_percent': (coverage * 100).round(),
        'has_allergens': hasAllergens,
        'has_dietary': hasDietary,
      },
    );
  }

  /// Log when ingredient lookup fails to find matches.
  Future<void> logUnknownIngredients({
    required List<String> unknownIngredients,
    required int totalIngredients,
  }) async {
    await _analytics.logEvent(
      name: 'unknown_ingredients',
      parameters: {
        'unknown_count': unknownIngredients.length,
        'total_count': totalIngredients,
        'unknown_rate': totalIngredients > 0
            ? (unknownIngredients.length / totalIngredients * 100).round()
            : 0,
      },
    );
  }

  /// Log personal tag creation.
  Future<void> logPersonalTagCreated({
    required String tagName,
    required bool hasRules,
    required int ruleCount,
  }) async {
    await _analytics.logEvent(
      name: 'personal_tag_created',
      parameters: {
        'tag_name_length': tagName.length,
        'has_rules': hasRules,
        'rule_count': ruleCount,
      },
    );
  }

  /// Log personal tag rule triggered.
  Future<void> logPersonalTagRuleTriggered({
    required String tagName,
    required String ruleType,
    required int matchedIngredients,
  }) async {
    await _analytics.logEvent(
      name: 'personal_tag_rule_triggered',
      parameters: {
        'tag_name_length': tagName.length,
        'rule_type': ruleType,
        'matched_count': matchedIngredients,
      },
    );
  }

  /// Log data integrity status.
  Future<void> logDataIntegrityCheck({
    required String recipeId,
    required String status,
  }) async {
    await _analytics.logEvent(
      name: 'data_integrity_check',
      parameters: {
        'recipe_id': recipeId,
        'status': status,
      },
    );
  }
}
