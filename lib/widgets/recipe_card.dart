// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Återanvändbar widget för att visa receptkort
/// Kan användas i listor, arkiv, sökresultat etc.
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receptbild eller ikon
              _buildRecipeImage(),
              const SizedBox(width: 12),

              // Receptinformation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel och måltidstyp
                    _buildTitle(theme),
                    const SizedBox(height: 4),

                    // Beskrivning (om showFullDetails)
                    if (showFullDetails && recipe.description.isNotEmpty) ...[
                      Text(
                        recipe.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Portioner och tid
                    _buildMetadata(theme),

                    // Taggar
                    if (showFullDetails &&
                        recipe.tags != null &&
                        recipe.tags!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildTags(),
                    ],

                    // Betyg
                    if (showFullDetails && recipe.rating != null) ...[
                      const SizedBox(height: 4),
                      _buildRating(),
                    ],
                  ],
                ),
              ),

              // Trailing widget (t.ex. checkbox)
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        color: Colors.grey[200],
        child:
            recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                ? Image.network(
                  recipe.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => const Icon(
                        Icons.restaurant_menu,
                        size: 30,
                        color: Colors.grey,
                      ),
                )
                : const Icon(
                  Icons.restaurant_menu,
                  size: 30,
                  color: Colors.grey,
                ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getMealTypeColor(),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            recipe.mealType,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(ThemeData theme) {
    final portionsText =
        recipe.portions != null ? '${recipe.portions} port' : '? port';
    final timeText =
        recipe.timeMinutes != null ? '${recipe.timeMinutes} min' : '? min';

    return Row(
      children: [
        Icon(
          Icons.people_outline,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          portionsText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.access_time,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children:
          recipe.tags!
              .take(3)
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ),
              )
              .toList(),
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
        return Icon(icon, size: 14, color: Colors.amber);
      }),
    );
  }

  Color _getMealTypeColor() {
    switch (recipe.mealType.toLowerCase()) {
      case 'frukost':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'middag':
        return Colors.blue;
      case 'dessert':
        return Colors.pink;
      case 'mellanmål':
        return Colors.purple;
      case 'fika':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

/// Kompakt variant för använding i arkivlistor eller små utrymmen
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
