// lib/widgets/empty_state.dart

import 'package:flutter/material.dart';
import 'action_button.dart';

/// Återanvändbar komponent för att visa tomma tillstånd
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.customAction,
  });

  const EmptyState.noRecipes({
    super.key,
    this.actionLabel = 'Lägg till recept',
    this.onAction,
  }) : icon = Icons.restaurant_menu,
       title = 'Inga recept ännu',
       subtitle =
           'Lägg till ditt första recept genom att trycka på "Lägg till"',
       customAction = null;

  const EmptyState.noSearchResults({super.key, this.actionLabel, this.onAction})
    : icon = Icons.search_off,
      title = 'Inga recept matchade din sökning',
      subtitle = 'Prova att söka på något annat eller rensa sökningen',
      customAction = null;

  const EmptyState.noMenu({
    super.key,
    this.actionLabel = 'Generera meny',
    this.onAction,
  }) : icon = Icons.restaurant,
       title = 'Ingen meny genererad ännu',
       subtitle = 'Skriv vad du vill ha eller tryck på knappen nedan',
       customAction = null;

  const EmptyState.noShoppingList({
    super.key,
    this.actionLabel = 'Skapa veckomeny',
    this.onAction,
  }) : icon = Icons.shopping_cart_outlined,
       title = 'Ingen meny att skapa inköpslista från',
       subtitle = 'Gå tillbaka och skapa en veckomeny först',
       customAction = null;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (customAction != null) ...[
              const SizedBox(height: 24),
              customAction!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ActionButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                icon: _getActionIcon(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData? _getActionIcon() {
    switch (icon) {
      case Icons.restaurant_menu:
        return Icons.add;
      case Icons.search_off:
        return Icons.clear;
      case Icons.restaurant:
        return Icons.auto_awesome;
      case Icons.shopping_cart_outlined:
        return Icons.restaurant;
      default:
        return null;
    }
  }
}
