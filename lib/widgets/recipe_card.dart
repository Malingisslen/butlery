// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Återanvändbar widget för att visa receptkort
/// Kan användas i listor, arkiv, sökresultat etc.
///
/// Använder AppTheme för styling - centraliserat och skalbart!
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
        borderRadius: BorderRadius.circular(16.0),
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
        borderRadius: BorderRadius.circular(35.0),
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
        borderRadius: BorderRadius.circular(35.0),
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: 32,
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 3,
      ),
      decoration: AppTheme.mealTypeChipDecoration(_getMealTypeColor()),
      child: Text(
        recipe.mealType,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
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
      style: AppTheme.recipeMetaStyle, // 100% från theme!
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
          size: 16,
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
              .map(
                (tag) => Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: 3,
                  ),
                  decoration: AppTheme.tagChipDecoration,
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  /// ✅ NU ANVÄNDER DEN THEME-FÄRGER ISTÄLLET FÖR HARDKODADE!
  Color _getMealTypeColor() {
    switch (recipe.mealType.toLowerCase()) {
      case 'frukost':
        return AppTheme.frukostColor; // ✅ Från theme
      case 'lunch':
        return AppTheme.lunchColor; // ✅ Från theme
      case 'middag':
        return AppTheme.middagColor; // ✅ Från theme
      case 'dessert':
        return AppTheme.dessertColor; // ✅ Från theme
      case 'mellanmål':
        return AppTheme.mellanmalColor; // ✅ Från theme
      case 'fika':
        return AppTheme.fikaColor; // ✅ Från theme
      default:
        return AppTheme.defaultMealColor; // ✅ Från theme
    }
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
