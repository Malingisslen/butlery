// lib/views/recipe_detail/recipe_detail_shared_widgets.dart
//
// Shared builder methods used by both mobile and tablet recipe detail layouts.
// Eliminates ~170 lines of duplication between recipe_detail_view.dart and
// recipe_detail_tablet_content.dart.

import 'package:butlery/core/utils/external_link.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/nutrition/recipe_nutrition_section.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/views/family/family_rating_breakdown.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/butlery_link.dart';

/// Shared widget builders for recipe detail layouts (mobile + tablet).
abstract final class RecipeDetailSharedWidgets {
  /// The provenance row under the title. Extracted from [buildTitleSection] so
  /// the link-vs-text decision is testable on its own: the parent composes
  /// `RecipeDetailMetadata`, which resolves services, and proving one branch
  /// should not require standing up a service locator.
  ///
  /// BUT-1819: `sourceUrl` is a PROVENANCE field, not a URL field. A dozen
  /// writers put a sentence in it — `'Butlerys receptsamling'` on the seeds,
  /// `'Från Butlerys arkiv'` on an archive import. `recipeCopiedFrom(title)`
  /// is written only by `RecipeFactory.createPersonalCopy`, which nothing calls
  /// today — the realtime copy uses a different sentence and copy-on-write
  /// keeps the original value, so no live path produces it.
  /// Accounts seeded before this ticket still hold the English
  /// `'Butlery recipe collection'`; nothing backfills them.
  /// Drawing all of them as links produced two dead affordances: a bare
  /// "Från " (empty host) and a doubled "Från Kopierat från: X" (`tryParse`
  /// returns null, so the `?? url` fallback prints the whole sentence — the
  /// SPACE before the colon breaks the parse, not the colon itself).
  ///
  /// Gating on the value BEING a link also makes a hostile `javascript:` source
  /// untappable rather than tappable-and-refused — the real protection for
  /// anything stored before the repository sanitizer started running.
  static Widget buildSourceRow(BuildContext context, Recipe recipe) {
    final cs = Theme.of(context).colorScheme;
    final url = recipe.sourceUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    if (!isSafeExternalUrl(url)) {
      // Plain text: no link semantics, no tap target, no icon, and NOT wrapped
      // in `recipeSourceFrom` — the raw value already reads as a sentence, and
      // that wrapper is what produced "Från ".
      return Padding(
        padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
        child: Text(
          url,
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
      child: ButleryLink(
        onTap: () => launchSourceUrl(context, url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BUT-1041: platform-aware leading icon so video imports read as
            // media at a glance, generic links as external.
            ButleryIcon(
              sourceIcon(url),
              size: AppDimensions.iconSizeS,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.space4),
            Flexible(
              child: Text(
                context.l10n.recipeSourceFrom(Uri.tryParse(url)?.host ?? url),
                // text.link (R8-11 = A).
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.modeColors.textLink,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Title section: title, source URL, metadata row, allergen badges, description.
  /// Wrapped in a decorated container with green bottom border.
  static Widget buildTitleSection({
    required BuildContext context,
    required Recipe recipe,
    required RecipeDetailViewModel viewModel,
    required RecipeDetailActions actions,
    bool canAddPhoto = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    // Without a photo the head is a typographic composition on paper, not a
    // tinted band under a picture (B-04).
    final hasPhoto = recipe.imageUrls.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: AppDimensions.responsiveContentPadding(context),
      decoration: hasPhoto
          ? BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border(bottom: BorderSide(color: cs.secondary, width: 3)),
            )
          : BoxDecoration(color: cs.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasPhoto) ..._typographicHeadLead(context, recipe),
          // The recipe's title under the media hero, as the view's heading,
          // written as the user wrote it (Komponentark v1:81-89 "Titeln står
          // under heron"; Skarmar v12 del 1 'Receptdetalj'). text.primary so
          // it reads on surface.raised in dark mode too; primary is ink in
          // both modes.
          Semantics(
            header: true,
            headingLevel: 1,
            child: Text(
              recipe.title,
              style: hasPhoto
                  ? AppTextStyles.headlineSmall.copyWith(
                      color: cs.onSurface,
                      letterSpacing: 1,
                    )
                  : AppTextStyles.displaySmall.copyWith(
                      color: cs.onSurface,
                      height: 1.12,
                    ),
            ),
          ),
          buildSourceRow(context, recipe),
          const SizedBox(height: AppDimensions.spacingSm),
          RecipeDetailMetadata(
            viewModel: viewModel,
            currentPortions: actions.currentPortions,
            isScaled: actions.currentPortions != (recipe.portions ?? 1),
            onAddPhoto: !hasPhoto && canAddPhoto
                ? () => actions.editRecipe(context)
                : null,
          ),
          // BUT-643: nutrition strip (setting) and the always-present button.
          RecipeNutritionSection(
            recipe: recipe,
            portions: actions.currentPortions,
          ),
          FamilyRatingBreakdown(recipe: recipe),
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
                  isDegraded:
                      ServiceLocator.tryGet<TaggingService>()
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

  /// The brand line and the category heading above the title of a recipe
  /// without a photo (Komponentark v1, "Utan foto · typografiskt huvud").
  static List<Widget> _typographicHeadLead(
    BuildContext context,
    Recipe recipe,
  ) {
    final cs = Theme.of(context).colorScheme;
    final category = recipe.mealType.trim();
    return [
      Row(
        children: [
          Container(
            key: const ValueKey('recipe-detail-brand-line'),
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: context.modeColors.progressIndicator,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(child: Divider(height: 1, color: cs.outlineVariant)),
        ],
      ),
      if (category.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          category.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: AppModeColors.textWarning(cs.brightness),
          ),
        ),
      ],
      const SizedBox(height: AppDimensions.spacingSm),
    ];
  }

  /// Completeness banner: shows missing fields and an edit button.
  static Widget buildCompletenessBanner(BuildContext context, Recipe recipe) {
    final cs = Theme.of(context).colorScheme;
    final missing = recipe.missingFields;
    final missingLabels = missing.map(
      (f) => switch (f) {
        RecipeField.title => context.l10n.recipeImproveMissingTitle,
        RecipeField.ingredients => context.l10n.recipeImproveMissingIngredients,
        RecipeField.instructions =>
          context.l10n.recipeImproveMissingInstructions,
        RecipeField.portions => context.l10n.recipeImproveMissingPortions,
        RecipeField.time => context.l10n.recipeImproveMissingTime,
        RecipeField.image => context.l10n.recipeImproveMissingImage,
      },
    );
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ButleryIcon(
                ButleryIcons.info,
                size: 18,
                color: cs.onSurface,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              // Flexible: the title must wrap at narrow widths (BUT-1230 —
              // an unbounded Text here overflowed the Row at <=420px).
              Flexible(
                child: Text(
                  context.l10n.recipeImproveTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
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
      return ButleryIcons.video;
    }
    if (host.contains('tiktok.')) {
      return ButleryIcons.video;
    }
    return ButleryIcons.externalLink;
  }

  /// Launches an external URL, telling the user when it does not open.
  ///
  /// BUT-1819: routed through `openExternalLink`, which refuses anything that
  /// is not http/https with a host. `buildSourceRow` draws the tap target ONLY
  /// for values that predicate accepts, so a `false` here means the OS refused
  /// a link the user could see and reasonably expect to work. This used to
  /// fail silently, which made that case a dead tap with no explanation — the
  /// same shape of lie the render guard was built to remove. Mirrors
  /// `RecipeDetailActions.handleSourceUrlClick`, which had the message already.
  static Future<void> launchSourceUrl(
    BuildContext context,
    String url,
  ) async {
    try {
      if (await openExternalLink(Uri.parse(url))) return;
      if (!context.mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.errorCouldNotOpenLink,
      );
    } catch (_) {
      if (!context.mounted) return;
      SnackBarUtils.showFailure(context, what: context.l10n.errorInvalidLink);
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
