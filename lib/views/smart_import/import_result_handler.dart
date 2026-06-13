// Duplicate-detection and post-import navigation extracted from
// smart_import_view.dart to keep the parent under the 620-line baseline.
// All logic is identical — this is a pure relocation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';
import 'package:butlery/widgets/recipe/duplicate_merge_sheet.dart';

/// Handles the two post-import actions: duplicate detection and navigation.
///
/// Extracted from _SmartImportViewContentState so the parent stays under the
/// 620-line baseline. Call [checkForDuplicatesAndNavigate] after a successful
/// import — it will either navigate to the editor or show the duplicate sheet.
abstract final class ImportResultHandler {
  // Minimum Jaccard similarity to flag as potential duplicate
  static const _contentDuplicateThreshold = 0.6;

  // URL/title matches are at least this similar by definition
  static const _exactMatchMinScore = 0.8;

  /// Returns true when [score] meets or exceeds the content-duplicate
  /// threshold — i.e. the fingerprint similarity is high enough to surface
  /// the recipe as a candidate duplicate.
  ///
  /// Exposed for testing so the threshold boundary (0.6) can be pinned
  /// without any service/dialog scaffolding.
  @visibleForTesting
  static bool meetsContentDuplicateThreshold(double score) =>
      score >= _contentDuplicateThreshold;

  /// Clamps [score] to [_exactMatchMinScore] from below.
  ///
  /// URL / title matches carry [matchScore] == 1.0 as a sentinel; when the
  /// computed content similarity is below the exact-match floor the display
  /// value is clamped so the sheet never shows an unrealistically low
  /// percentage for a match already confirmed by URL or title.
  ///
  /// Exposed for testing so the 0.8 floor boundary can be pinned without
  /// any service/dialog scaffolding.
  @visibleForTesting
  static double clampToExactMatchFloor(double score) =>
      score < _exactMatchMinScore ? _exactMatchMinScore : score;

  /// Checks for duplicates and, if none (or user chose "save as new"),
  /// navigates to the recipe editor.
  ///
  /// Returns true if the caller should continue (save as new), false if
  /// navigation was already handled inside this method.
  static Future<bool> checkForDuplicates(
    BuildContext context,
    Recipe recipe,
  ) async {
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final fingerprinter = ContentFingerprint();

      // Check by source URL first (most reliable match)
      final sourceUrl = recipe.sourceUrl;
      List<Recipe> matches = [];
      double matchScore = 1.0;

      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        matches = await recipeService.findBySourceUrl(sourceUrl);
      }

      // Fall back to title match
      if (matches.isEmpty && recipe.title.isNotEmpty) {
        matches = await recipeService.findByTitle(recipe.title);
      }

      // Fall back to content fingerprint similarity
      if (matches.isEmpty && recipe.ingredients.isNotEmpty) {
        final allRecipes = recipeService.recipes;

        Recipe? bestMatch;
        double bestScore = 0.0;

        for (final existing in allRecipes) {
          if (existing.ingredients.isEmpty) continue;
          final score = fingerprinter.recipeSimilarity(
            titleA: recipe.title,
            ingredientsA: recipe.ingredients,
            titleB: existing.title,
            ingredientsB: existing.ingredients,
          );
          if (score > bestScore) {
            bestScore = score;
            bestMatch = existing;
          }
        }

        if (bestMatch != null && meetsContentDuplicateThreshold(bestScore)) {
          matches = [bestMatch];
          matchScore = bestScore;
        }
      }

      if (matches.isEmpty || !context.mounted) return true;

      // Compute similarity for display if not already set
      if (matchScore == 1.0 && matches.first.ingredients.isNotEmpty) {
        matchScore = fingerprinter.recipeSimilarity(
          titleA: recipe.title,
          ingredientsA: recipe.ingredients,
          titleB: matches.first.title,
          ingredientsB: matches.first.ingredients,
        );
        matchScore = clampToExactMatchFloor(matchScore);
      }

      final result = await showDuplicateMergeSheet(
        context: context,
        existingRecipe: matches.first,
        newRecipe: recipe,
        similarityScore: matchScore,
      );

      if (!context.mounted || result == null) return false;

      switch (result.choice) {
        case DuplicateMergeChoice.keepExisting:
          Navigator.of(context).pushReplacementNamed(
            Routes.recipeDetail,
            arguments: matches.first.id,
          );
          return false;

        case DuplicateMergeChoice.replaceWithNew:
          // Replace existing recipe content with new recipe data
          final merged = matches.first.copyWith(
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            timeMinutes: recipe.timeMinutes,
            portions: recipe.portions,
            imageUrls: recipe.imageUrls,
            sourceUrl: recipe.sourceUrl,
          );
          await recipeService.updateRecipe(merged);
          if (context.mounted) {
            SnackBarUtils.showSuccess(
                context, context.l10n.duplicateMergeSuccess);
            Navigator.of(context).pushReplacementNamed(
              Routes.recipeDetail,
              arguments: matches.first.id,
            );
          }
          return false;

        case DuplicateMergeChoice.saveAsNew:
          return true;

        case DuplicateMergeChoice.mergeBestFields:
          final merged = result.buildMergedRecipe();
          await recipeService.updateRecipe(merged);
          if (context.mounted) {
            SnackBarUtils.showSuccess(
                context, context.l10n.duplicateMergeSuccess);
            Navigator.of(context).pushReplacementNamed(
              Routes.recipeDetail,
              arguments: matches.first.id,
            );
          }
          return false;
      }
    } catch (_) {
      // If duplicate check fails, let the user proceed with the import
      return true;
    }
  }

  /// Navigates to the recipe editor with the imported recipe.
  ///
  /// BUT-1198: shows a non-blocking allergen-setup banner when the imported
  /// recipe contains an allergen the user hasn't configured. Reuses the
  /// deterministic Phase-1 allergen tags ImportManager already attached during
  /// import — no new LLM/network call. Shown via the app-level
  /// ScaffoldMessenger so it survives the pushReplacement and never gates the
  /// import.
  static void navigateToRecipeEditor(BuildContext context, Recipe recipe) {
    final prefs = ServiceLocator.get<UserService>().allergenPreferences;
    if (AllergenMismatch.unconfiguredContainedAllergens(recipe, prefs)
        .isNotEmpty) {
      AllergenSetupBanner.show(context);
    }

    HapticFeedback.mediumImpact();

    Navigator.of(context).pushReplacementNamed(
      Routes.manualEntry,
      arguments: {
        'initialRecipe': recipe,
        'isTemplate': true,
      },
    );
  }
}
