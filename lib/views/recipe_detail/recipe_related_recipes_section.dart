// lib/views/recipe_detail/recipe_related_recipes_section.dart
//
// BUT-1057: "Relaterade recept" and "Används i" sections for the detail view.
// Rendered only when there are links to show (empty → SizedBox.shrink).

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/image/image_config.dart';

/// Renders the "Relaterade recept" block in the recipe detail view.
///
/// Purely presentational: the parent resolves the linked recipes (from the
/// in-memory list) and passes them in via [related]. This widget never
/// touches the ServiceLocator (per lib/widgets/CLAUDE.md).
/// Hidden entirely when [related] is empty.
class RelatedRecipesSection extends StatelessWidget {
  final List<Recipe> related;

  const RelatedRecipesSection({super.key, required this.related});

  @override
  Widget build(BuildContext context) {
    if (related.isEmpty) return const SizedBox.shrink();

    return _RelatedSection(
      title: context.l10n.recipeRelatedSectionTitle,
      recipes: related,
    );
  }
}

/// Renders the "Används i" block — recipes that link TO this one.
///
/// Purely presentational: the parent computes the reverse-link list and
/// passes it in via [usedIn]. This widget never touches the ServiceLocator.
/// Hidden entirely when [usedIn] is empty.
class UsedInSection extends StatelessWidget {
  final List<Recipe> usedIn;

  const UsedInSection({super.key, required this.usedIn});

  @override
  Widget build(BuildContext context) {
    if (usedIn.isEmpty) return const SizedBox.shrink();

    return _RelatedSection(
      title: context.l10n.recipeUsedInSectionTitle,
      recipes: usedIn,
    );
  }
}

/// Shared layout: section header + horizontal scrolling thumbnails.
class _RelatedSection extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;

  const _RelatedSection({required this.title, required this.recipes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider + header
        Divider(color: cs.surfaceContainerHigh),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.paddingL,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        SizedBox(
          height: _thumbnailSize + AppDimensions.spacingMd,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.paddingL,
            ),
            itemCount: recipes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppDimensions.spacingMd),
            itemBuilder: (context, index) => _RelatedThumbnail(
              key: ValueKey(recipes[index].id),
              recipe: recipes[index],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }
}

const double _thumbnailSize = 100;

/// Square tappable thumbnail card for one related recipe.
class _RelatedThumbnail extends StatelessWidget {
  final Recipe recipe;

  const _RelatedThumbnail({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = recipe.displayThumbnailUrl;

    return Semantics(
      label: context.l10n.a11yRelatedRecipeThumbnail(recipe.title),
      button: true,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          Routes.recipeDetail,
          arguments: recipe,
        ),
        child: SizedBox(
          width: _thumbnailSize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or illustration
              Container(
                width: _thumbnailSize,
                height: _thumbnailSize - AppDimensions.spacingXl,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: url != null
                    ? SimpleImageWidget(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        config: ImageConfig.thumbnail(
                          heroTag: ImageConfig.recipeHeroTag(recipe.id),
                        ),
                      )
                    : Center(
                        child: VegetableIllustration(
                          type: VegetableIllustration.randomForRecipe(
                            recipe.id,
                          ),
                          size:
                              (_thumbnailSize - AppDimensions.spacingXl) * 0.65,
                          opacity: 0.8,
                        ),
                      ),
              ),
              // Title below
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: AppDimensions.spacingXxs,
                ),
                child: Text(
                  recipe.title,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
