import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

class RecipeShelf extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;
  final void Function(Recipe) onRecipeTap;

  const RecipeShelf({
    super.key,
    required this.title,
    required this.recipes,
    required this.onRecipeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Text(title, style: AppTextStyles.sectionLabel),
        ),
        SizedBox(
          height: AppDimensions.thumbnailLargeSize + AppDimensions.spacingSm,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _ShelfCard(
                recipe: recipe,
                onTap: () => onRecipeTap(recipe),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Divider(
          height: 1,
          color: cs.outlineVariant.withValues(
            alpha: AppDimensions.opacityMediumLight,
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _ShelfCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbnail = recipe.displayThumbnailUrl;

    return Semantics(
      label: context.l10n.a11yShelfRecipeOpen(recipe.title),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppDimensions.imageSizeThumbnail + AppDimensions.spacingMd,
          margin: const EdgeInsetsDirectional.only(
            end: AppDimensions.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width:
                    AppDimensions.imageSizeThumbnail + AppDimensions.spacingMd,
                height: AppDimensions.imageSizeThumbnail,
                color: cs.surfaceContainerHighest,
                child: thumbnail != null
                    ? SimpleImageWidget(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        config: ImageConfig.thumbnail(),
                      )
                    : Center(
                        child: VegetableIllustration(
                          type: VegetableIllustration.randomForRecipe(
                            recipe.id,
                          ),
                          size: AppDimensions.imageSizeThumbnail / 2,
                          opacity: AppDimensions.opacityDark,
                        ),
                      ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                recipe.title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
