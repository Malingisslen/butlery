// lib/views/recipe_detail/recipe_detail_shared_widgets.dart
//
// Shared builder methods used by both mobile and tablet recipe detail layouts.
// Eliminates ~170 lines of duplication between recipe_detail_view.dart and
// recipe_detail_tablet_content.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared widget builders for recipe detail layouts (mobile + tablet).
abstract final class RecipeDetailSharedWidgets {
  /// Title section: title, source URL, metadata row, allergen badges, description.
  /// Wrapped in a decorated container with green bottom border.
  static Widget buildTitleSection({
    required BuildContext context,
    required Recipe recipe,
    required RecipeDetailViewModel viewModel,
    required RecipeDetailActions actions,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: AppDimensions.responsiveContentPadding(context),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: cs.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              recipe.title.toLowerCase(),
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: cs.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Semantics(
              link: true,
              child: GestureDetector(
                onTap: () => launchSourceUrl(context, recipe.sourceUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BUT-1041: platform-aware leading icon so video imports
                    // read as media at a glance, generic links as external.
                    Icon(
                      sourceIcon(recipe.sourceUrl!),
                      size: AppDimensions.iconSizeS,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.spacingXxs),
                    Flexible(
                      child: Text(
                        context.l10n.recipeSourceFrom(
                          Uri.tryParse(recipe.sourceUrl!)?.host ??
                              recipe.sourceUrl!,
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacingSm),
          RecipeDetailMetadata(
            viewModel: viewModel,
            currentPortions: actions.currentPortions,
            isScaled: actions.currentPortions != (recipe.portions ?? 1),
          ),
          Selector<UserService, UserAllergenPreferences>(
            selector: (_, svc) => svc.allergenPreferences,
            builder: (context, allergenPrefs, _) {
              final tagResult = recipe.tagResult;
              if (tagResult == null || !allergenPrefs.showOnDetail) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
                child: TagResultDisplay(
                  tagResult: tagResult,
                  userAllergenPrefs: allergenPrefs.trackedAllergens,
                  userDietaryPrefs: allergenPrefs.trackedDietary,
                  showCoverage: tagResult.coverage < 1.0,
                  isDegraded: ServiceLocator.tryGet<TaggingService>()
                          ?.isInDegradedMode ??
                      false,
                ),
              );
            },
          ),
          if (recipe.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
              child: Text(
                recipe.description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Completeness banner: shows missing fields and an edit button.
  static Widget buildCompletenessBanner(
    BuildContext context,
    Recipe recipe,
  ) {
    final cs = Theme.of(context).colorScheme;
    final missing = recipe.missingFields;
    final missingLabels = missing.map((f) => switch (f) {
          RecipeField.title => context.l10n.recipeImproveMissingTitle,
          RecipeField.ingredients =>
            context.l10n.recipeImproveMissingIngredients,
          RecipeField.instructions =>
            context.l10n.recipeImproveMissingInstructions,
          RecipeField.portions => context.l10n.recipeImproveMissingPortions,
          RecipeField.time => context.l10n.recipeImproveMissingTime,
          RecipeField.image => context.l10n.recipeImproveMissingImage,
        });
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 18, color: cs.primary),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                context.l10n.recipeImproveTitle,
                style: AppTextStyles.titleSmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            missingLabels.join(', '),
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                Routes.editRecipe,
                arguments: recipe,
              ),
              child: Text(context.l10n.commonEdit),
            ),
          ),
        ],
      ),
    );
  }

  /// BUT-1041: platform-aware icon for the recipe source link. Sniffs the
  /// host (no schema/enum migration needed) so YouTube/TikTok video imports
  /// read as media and generic web imports read as an external link.
  @visibleForTesting
  static IconData sourceIcon(String url) {
    final host = (Uri.tryParse(url)?.host.toLowerCase()).orEmpty();
    if (host.contains('youtube.') || host.contains('youtu.be')) {
      return Icons.play_circle_outline;
    }
    if (host.contains('tiktok.')) {
      return Icons.music_note;
    }
    return Icons.open_in_new;
  }

  /// Launches an external URL (best-effort, silent failure).
  static Future<void> launchSourceUrl(
    BuildContext context,
    String url,
  ) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Best-effort — silently ignore
    }
  }

  /// Opens fullscreen image viewer for the given image URLs.
  static void showFullscreenImage(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
