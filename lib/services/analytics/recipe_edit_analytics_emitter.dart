/// Emits the `recipe_edited` and (when applicable) `post_import_edit`
/// analytics events from a single diff input.
///
/// Extracted from `RecipePersistenceManager` so the manager only coordinates
/// persistence; analytics emission is the emitter's sole responsibility.
/// Two events share the same diff inputs but feed different funnels:
/// `recipe_edited` is the broad edit signal, `post_import_edit` measures
/// parse-quality cleanup behavior in the days after an import.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/post_import_edit_decider.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/utils/recipe_diff.dart';

class RecipeEditAnalyticsEmitter {
  final AnalyticsService? _analytics;

  RecipeEditAnalyticsEmitter({AnalyticsService? analytics})
    : _analytics = analytics ?? ServiceLocator.tryGet<AnalyticsService>();

  /// Compute the diff between [original] and [savedRecipe] and emit:
  ///   - `recipe_edited` (always when the recipe has a previous state).
  ///   - `post_import_edit` (only when [PostImportEditDecider] returns a
  ///     non-null payload — i.e. the recipe was imported and is still inside
  ///     [windowDays] of its import time).
  ///
  /// [tierUsed] is the parse tier captured at import time; pass null when
  /// unknown (e.g. on edits past the first post-import save). The decider
  /// omits the field from the analytics payload rather than guessing.
  void emit({
    required String recipeId,
    required Recipe original,
    required Recipe savedRecipe,
    String? tierUsed,
    int windowDays = kPostImportEditWindowDays,
  }) {
    final changed = diffRecipeFields(original, savedRecipe);

    _analytics?.recipe.logRecipeEdited(
      recipeId: recipeId,
      fieldsChanged: changed.isEmpty ? null : changed,
    );

    final params = PostImportEditDecider.build(
      recipeId: recipeId,
      fieldsChanged: changed,
      sourceUrl: original.sourceUrl,
      importedAt: original.createdAt,
      now: clock.now(),
      tierUsed: tierUsed,
      windowDays: windowDays,
    );
    if (params == null) return;

    _analytics?.logEvent(
      name: AnalyticsEvents.postImportEdit,
      parameters: params,
    );
  }
}

/// Window after import during which a `recipe_edited` event also fires the
/// dedicated `post_import_edit` event. Long enough to capture genuine
/// post-import cleanup, short enough that ordinary long-term edits don't
/// pollute parse-quality metrics.
const int kPostImportEditWindowDays = 30;
