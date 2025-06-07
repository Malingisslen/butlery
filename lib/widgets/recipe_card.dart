// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Återanvändbar widget för att visa receptkort
/// Kan användas i listor, arkiv, sökresultat etc.
///
/// ✨ 100% THEME-CENTRALISERAD - INGA HÅRDKODADE TEXTSTYLES!
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

    return Container(
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
    );
  }

  Widget _buildRecipeImage() {
    return Container(
      width: AppTheme.recipeImageSize,
      height: AppTheme.recipeImageSize,
      decoration: AppTheme.recipeImageDecoration,
      child: ClipRRect(
        borderRadius: AppTheme.roundRadius, // ✅ SEMANTISK RADIUS
        child:
            recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                ? Image.network(
                  recipe.imageUrl!,
                  width: AppTheme.recipeImageSize,
                  height: AppTheme.recipeImageSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                )
                : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: AppTheme.recipeImageSize,
      height: AppTheme.recipeImageSize,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: AppTheme.roundRadius, // ✅ SEMANTISK RADIUS
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: AppTheme.iconSizeLarge, // ✅ 32px från theme
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            recipe.title,
            style: AppTheme.cardTitleStyle, // ✅ SEMANTISK THEME STYLE
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
