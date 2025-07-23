// lib/widgets/common/state/legacy_state_widgets.dart

import 'package:flutter/material.dart';
import '../state_widget.dart';
import 'skeleton_components.dart';

/// ===== LEGACY ALIASES FÖR BAKÅTKOMPATIBILITET =====

/// Ersätter den gamla EmptyState klassen
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
  })  : icon = Icons.restaurant_menu,
        title = 'Inga recept ännu',
        subtitle =
            'Lägg till ditt första recept genom att trycka på "Lägg till"',
        customAction = null;

  const EmptyState.noSearchResults({
    super.key,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.search_off,
        title = 'Inga recept matchade din sökning',
        subtitle = 'Prova att söka på något annat eller rensa sökningen',
        customAction = null;

  const EmptyState.noMenu({
    super.key,
    this.actionLabel = 'Generera meny',
    this.onAction,
  })  : icon = Icons.restaurant,
        title = 'Ingen meny genererad ännu',
        subtitle = 'Skriv vad du vill ha eller tryck på knappen nedan',
        customAction = null;

  const EmptyState.noShoppingList({
    super.key,
    this.actionLabel = 'Skapa veckomeny',
    this.onAction,
  })  : icon = Icons.shopping_cart_outlined,
        title = 'Ingen meny att skapa inköpslista från',
        subtitle = 'Gå tillbaka och skapa en veckomeny först',
        customAction = null;

  @override
  Widget build(BuildContext context) {
    return StateWidget.empty(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      customAction: customAction,
    );
  }
}

/// Ersätter den gamla SkeletonLoader klassen
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonComponents.skeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

/// Ersätter RecipeCardSkeleton
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StateWidget.skeletonRecipeCard();
  }
}

/// Ersätter RecipeListSkeleton
class RecipeListSkeleton extends StatelessWidget {
  final int itemCount;

  const RecipeListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return StateWidget.skeletonRecipeList(itemCount: itemCount);
  }
}