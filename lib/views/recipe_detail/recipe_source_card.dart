// lib/views/recipe_detail/recipe_source_card.dart
//
// Where a web-imported recipe came from, who wrote it, and the way back to
// the page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/borrowed_image.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class RecipeSourceCard extends StatelessWidget {
  const RecipeSourceCard({
    super.key,
    required this.sourceUrl,
    this.sourceAuthor,
  });

  /// Must pass `isSafeExternalUrl`; the caller draws plain text otherwise.
  final String sourceUrl;
  final String? sourceAuthor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final site = sourceSiteName(sourceUrl) ?? sourceUrl;
    final author = sourceAuthor?.trim();
    final hasAuthor = author != null && author.isNotEmpty;

    return StyledCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One node for the credit, so a screen reader hears site and author
          // as a sentence instead of two fragments and a decorative icon.
          Semantics(
            label: hasAuthor
                ? context.l10n.a11yRecipeSourceCardWithAuthor(site, author)
                : context.l10n.a11yRecipeSourceCard(site),
            excludeSemantics: true,
            child: Row(
              children: [
                ButleryIcon(
                  // BUT-1041: a video import keeps its video mark.
                  RecipeDetailSharedWidgets.sourceIcon(sourceUrl) ==
                          ButleryIcons.video
                      ? ButleryIcons.video
                      : ButleryIcons.globe,
                  size: AppDimensions.iconSizeM,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.recipeSourceCardTitle(site),
                        style: AppTextStyles.cardTitle.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (hasAuthor)
                        Text(
                          context.l10n.recipeSourceAuthor(author),
                          style: AppTextStyles.captionText.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          ActionButtons.actionButton(
            context,
            key: const ValueKey('recipe-source-open-original'),
            label: context.l10n.recipeSourceOpenOriginal,
            icon: ButleryIcons.externalLink,
            style: ActionButtonStyle.secondary,
            isExpanded: true,
            onPressed: () => RecipeDetailSharedWidgets.launchSourceUrl(
              context,
              sourceUrl,
              inAppBrowser: true,
            ),
          ),
        ],
      ),
    );
  }
}
