// lib/widgets/common/state/empty_states.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../utility_components.dart';
import 'state_enums.dart';

/// EmptyStates - Empty state implementations
///
/// Handles different empty state variants with appropriate icons and messages.
class EmptyStates {
  /// Build empty state based on variant
  static Widget buildEmptyState(
    BuildContext context, {
    required EmptyStateVariant? variant,
    String? title,
    String? subtitle,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? customAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    final emptyConfig = _getEmptyStateConfig(variant);

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikon
              Icon(
                icon ?? emptyConfig.icon,
                size: iconSize ?? AppDimensions.iconSizeXl,
                color: iconColor ?? Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Titel
              Text(
                title ?? emptyConfig.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),

              // Subtitle
              if (subtitle != null || emptyConfig.subtitle != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  subtitle ?? emptyConfig.subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Action
              if (customAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                customAction,
              ] else if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                  icon: emptyConfig.actionIcon,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _EmptyStateConfig _getEmptyStateConfig(EmptyStateVariant? variant) {
    switch (variant) {
      case EmptyStateVariant.noRecipes:
        return _EmptyStateConfig(
          icon: Icons.restaurant_menu,
          title: 'Inga recept ännu',
          subtitle:
              'Lägg till ditt första recept genom att trycka på "Lägg till"',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          title: 'Inga recept matchade din sökning',
          subtitle: 'Prova att söka på något annat eller rensa sökningen',
          actionIcon: Icons.clear,
        );
      case EmptyStateVariant.noMenu:
        return _EmptyStateConfig(
          icon: Icons.restaurant,
          title: 'Ingen meny genererad ännu',
          subtitle: 'Skriv vad du vill ha eller tryck på knappen nedan',
          actionIcon: Icons.auto_awesome,
        );
      case EmptyStateVariant.noShoppingList:
        return _EmptyStateConfig(
          icon: Icons.shopping_cart_outlined,
          title: 'Ingen meny att skapa inköpslista från',
          subtitle: 'Gå tillbaka och skapa en veckomeny först',
          actionIcon: Icons.restaurant,
        );
      case EmptyStateVariant.noFriends:
        return _EmptyStateConfig(
          icon: Icons.people_outline,
          title: 'Inga vänner ännu',
          subtitle: 'Lägg till vänner för att dela recept och menyer',
          actionIcon: Icons.person_add,
        );
      case EmptyStateVariant.noCategories:
        return _EmptyStateConfig(
          icon: Icons.category,
          title: 'Inga kategorier skapade',
          subtitle: 'Skapa din första kategori för att organisera dina vänner',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noImages:
        return _EmptyStateConfig(
          icon: Icons.image_outlined,
          title: 'Inga bilder tillagda',
          subtitle: 'Lägg till bilder för att göra ditt recept mer attraktivt',
          actionIcon: Icons.add_a_photo,
        );
      case EmptyStateVariant.noTargets:
        return _EmptyStateConfig(
          icon: Icons.group_add,
          title: 'Inga destinationer tillgängliga',
          subtitle:
              'Lägg till vänner eller grupper för att kunna dela innehåll',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noSavedMenus:
        return _EmptyStateConfig(
          icon: Icons.bookmark_outline,
          title: 'Inga sparade menyer',
          subtitle: 'Skapa och spara menyer för att enkelt ladda dem senare',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.generic:
      default:
        return _EmptyStateConfig(
          icon: Icons.info_outline,
          title: 'Inget innehåll att visa',
          subtitle: null,
          actionIcon: null,
        );
    }
  }
}

/// ===== CONFIGURATION CLASSES =====

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? actionIcon;

  const _EmptyStateConfig({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionIcon,
  });
}