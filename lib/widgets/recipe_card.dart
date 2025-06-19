// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import 'optimized_card.dart';
import 'cached_recipe_image.dart';

/// Återanvändbar widget för att visa receptkort
/// Kan användas i listor, arkiv, sökresultat etc.
///
/// ✨ 100% THEME-CENTRALISERAD - INGA HÅRDKODADE TEXTSTYLES!
/// ✨ UPPDATERAD MED "SENAST TILLAGAD" VISNING
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final Widget? trailing; // För t.ex. checkbox i arkivvyn
  final bool showFullDetails; // Visa alla detaljer eller bara grund-info

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.trailing,
    this.showFullDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OptimizedCard(
      // ✅ LÄGG TILL WRAPPER
      child: Container(
        margin: AppTheme.recipeCardMargin,
        decoration: AppTheme.recipeCardDecoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.extraLargeRadius, // ✅ SEMANTISK RADIUS
          child: Padding(
            padding: AppTheme.recipeCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Receptbild eller ikon (100% theme-styrd)
                _buildRecipeImage(),
                SizedBox(width: AppTheme.spacingMd),

                // Receptinformation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titel och måltidstyp
                      _buildTitle(theme),
                      SizedBox(height: AppTheme.spacingSm - 2), // 6px
                      // Portioner och tid (använder theme-style)
                      _buildMetadata(),

                      // NY! Visa "Senast tillagad" om det finns
                      if (recipe.lastCookedText != null) ...[
                        SizedBox(height: AppTheme.spacingXs),
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: AppTheme.iconSizeSmall,
                              color:
                                  recipe.wasCookedRecently
                                      ? AppTheme.successColor
                                      : AppTheme.textSecondary,
                            ),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              recipe.lastCookedText!,
                              style: AppTheme.captionStyle.copyWith(
                                color:
                                    recipe.wasCookedRecently
                                        ? AppTheme.successColor
                                        : AppTheme.textSecondary,
                                fontWeight:
                                    recipe.wasCookedRecently
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],

                      SizedBox(height: AppTheme.spacingSm),

                      // Betyg (theme-färger)
                      if (recipe.rating != null) ...[
                        _buildRating(),
                        SizedBox(height: AppTheme.spacingSm - 2),
                      ],

                      // Beskrivning (om showFullDetails)
                      if (showFullDetails && recipe.description.isNotEmpty) ...[
                        Text(
                          recipe.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppTheme.spacingSm),
                      ],

                      // Taggar (theme-styling)
                      if (showFullDetails &&
                          recipe.tags != null &&
                          recipe.tags!.isNotEmpty) ...[
                        _buildTags(),
                      ],
                    ],
                  ),
                ),

                // Trailing widget (t.ex. checkbox)
                if (trailing != null) ...[
                  SizedBox(width: AppTheme.spacingSm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeImage() {
    return CachedRecipeImage(
      imageUrls: recipe.imageUrls,
      size: AppTheme.recipeImageSize,
      borderRadius: AppTheme.roundRadius,
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: AppTheme.cardTitleStyle, // ✅ SEMANTISK THEME STYLE
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // NY! Visa länk-ikon om sourceUrl finns
              if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) ...[
                SizedBox(width: AppTheme.spacingXs),
                Icon(
                  Icons.link,
                  size: AppTheme.iconSizeInfo, // 18px
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: AppTheme.spacingSm),
        _buildMealTypeChip(),
      ],
    );
  }

  Widget _buildMealTypeChip() {
    return AppTheme.mealTypeChip(recipe.mealType); // ✅ SEMANTISK WIDGET
  }

  Widget _buildMetadata() {
    final portionsText =
        recipe.portions != null
            ? '${recipe.portions} portioner'
            : '? portioner';
    final timeText =
        recipe.timeMinutes != null
            ? '${recipe.timeMinutes} minuter tillagningstid'
            : '? minuter';

    return Text(
      '$portionsText | $timeText',
      style: AppTheme.metadataStyle, // ✅ SEMANTISK THEME STYLE
    );
  }

  Widget _buildRating() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final rating = recipe.rating ?? 0;
        IconData icon;
        if (index + 1 <= rating) {
          icon = Icons.star;
        } else if (index + 0.5 <= rating) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(
          icon,
          size: AppTheme.iconSizeSmall, // ✅ 16px från theme
          color: AppTheme.starColor, // Från theme!
        );
      }),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: AppTheme.spacingSm - 2, // 6px
      runSpacing: AppTheme.spacingXs,
      children:
          recipe.tags!
              .take(3)
              .map((tag) => AppTheme.tagChip(tag)) // ✅ SEMANTISK WIDGET
              .toList(),
    );
  }
}

/// Kompakt variant för användning i arkivlistor eller små utrymmen
class CompactRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return RecipeCard(
      recipe: recipe,
      onTap: onTap,
      trailing: trailing,
      showFullDetails: false,
    );
  }
}
