import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          child: SectionHeading(title),
        ),
        SizedBox(
          height: AppDimensions.thumbnailLargeSize + AppDimensions.space8,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
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
        const SizedBox(height: AppDimensions.space8),
        const SizedBox(height: 1, child: ButleryDivider()),
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
      label: context.l10n.a11yShelfRecipeOpen,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppDimensions.imageSizeThumbnail + AppDimensions.space16,
          margin: const EdgeInsetsDirectional.only(
            end: AppDimensions.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppDimensions.imageSizeThumbnail + AppDimensions.space16,
                height: AppDimensions.imageSizeThumbnail,
                color: cs.surfaceContainerHighest,
                child: thumbnail != null
                    ? SimpleImageWidget(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        config: ImageConfig.thumbnail(),
                      )
                    : RecipeInitialPlate(
                        title: recipe.title,
                        letterSize: AppDimensions.imageSizeThumbnail * 0.35,
                      ),
              ),
              const SizedBox(height: AppDimensions.space4),
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
