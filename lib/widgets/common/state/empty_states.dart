import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// EmptyStates - Empty state implementations with vegetable illustrations.
///
/// **UI Redesign:** Updated to use hand-drawn vegetable illustrations
/// instead of generic icons for main empty states.
///
/// Illustration mapping:
/// - No recipes → Broccoli
/// - No search results → Mushroom
/// - No menu → Pea pod (static)
/// - No shopping items → Carrot
/// - Error states → Red onion
class EmptyStates {
  /// Build empty state based on variant.
  ///
  /// If [useIllustration] is true (default for main states), uses vegetable
  /// illustrations. Set to false to use icons instead.
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
    bool? useIllustration,
  }) {
    final emptyConfig = _getEmptyStateConfig(context, variant);
    final shouldUseIllustration =
        useIllustration ?? emptyConfig.illustration != null;

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration or Icon
              if (icon != Icons.clear) ...[
                if (shouldUseIllustration && emptyConfig.illustration != null)
                  VegetableIllustration(
                    type: emptyConfig.illustration!,
                    size: iconSize ?? 100,
                  )
                else
                  Icon(
                    icon ?? emptyConfig.icon,
                    size: iconSize ?? AppDimensions.iconSizeXl,
                    color: iconColor ?? Theme.of(context).colorScheme.outline,
                  ),
                const SizedBox(height: AppDimensions.spacingLg),
              ],

              // Title (using emptyStateTitle style)
              Text(
                title ?? emptyConfig.title,
                style: AppTextStyles.emptyStateTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              // Subtitle
              if (subtitle != null || emptyConfig.subtitle != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  subtitle ?? emptyConfig.subtitle!,
                  style: AppTextStyles.emptyStateBody,
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

  static _EmptyStateConfig _getEmptyStateConfig(
    BuildContext context,
    EmptyStateVariant? variant,
  ) {
    final l10n = context.l10n;

    switch (variant) {
      case EmptyStateVariant.noRecipes:
        return _EmptyStateConfig(
          icon: Icons.restaurant_menu,
          illustration: VegetableType.broccoli,
          title: l10n.emptyNoResults,
          subtitle: l10n.emptyNoRecipesSubtitle(l10n.commonAdd),
          actionIcon: AdaptiveIcons.add,
        );
      case EmptyStateVariant.noSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoResults,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: Icons.clear,
        );
      case EmptyStateVariant.noFriendsSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoFriendsSearchTitle,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: Icons.clear,
        );
      case EmptyStateVariant.noGroupsSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoGroupsSearchTitle,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: Icons.clear,
        );
      case EmptyStateVariant.noMenu:
        return _EmptyStateConfig(
          icon: Icons.restaurant_menu,
          illustration: VegetableType.peaPod,
          title: l10n.emptyNoMenuTitle,
          subtitle: l10n.emptyNoMenuSubtitle,
          actionIcon: null,
        );
      case EmptyStateVariant.noShoppingList:
        return _EmptyStateConfig(
          icon: AdaptiveIcons.cartOutlined,
          illustration: VegetableType.carrot,
          title: l10n.emptyNoShoppingListTitle,
          subtitle: l10n.emptyNoShoppingListSubtitle,
          actionIcon: AdaptiveIcons.restaurant,
        );
      case EmptyStateVariant.noFriends:
        return _EmptyStateConfig(
          icon: AdaptiveIcons.peopleOutlined,
          // No illustration for social states - use icon
          title: l10n.emptyNoFriendsTitle,
          subtitle: l10n.emptyNoFriendsSubtitle,
          actionIcon: Icons.person_add,
        );
      case EmptyStateVariant.noCategories:
        return _EmptyStateConfig(
          icon: Icons.category,
          title: l10n.emptyNoCategoriesTitle,
          subtitle: l10n.emptyNoCategoriesSubtitle,
          actionIcon: AdaptiveIcons.add,
        );
      case EmptyStateVariant.noImages:
        return _EmptyStateConfig(
          icon: Icons.image_outlined,
          title: l10n.emptyNoImagesTitle,
          subtitle: l10n.emptyNoImagesSubtitle,
          actionIcon: Icons.add_a_photo,
        );
      case EmptyStateVariant.noTargets:
        return _EmptyStateConfig(
          icon: Icons.group_add,
          title: l10n.emptyNoTargetsTitle,
          subtitle: l10n.emptyNoTargetsSubtitle,
          actionIcon: AdaptiveIcons.add,
        );
      case EmptyStateVariant.noSavedMenus:
        return _EmptyStateConfig(
          icon: AdaptiveIcons.bookmarkOutlined,
          illustration: VegetableType.peaPod,
          title: l10n.emptyNoSavedMenusTitle,
          subtitle: l10n.emptyNoSavedMenusSubtitle,
          actionIcon: AdaptiveIcons.add,
        );
      case EmptyStateVariant.noSharedShoppingLists:
        return _EmptyStateConfig(
          icon: Icons.shopping_cart_outlined,
          title: l10n.emptyNoSharedShoppingListsTitle,
          subtitle: l10n.emptyNoSharedShoppingListsSubtitle,
          actionIcon: null,
        );
      case EmptyStateVariant.generic:
      default:
        return _EmptyStateConfig(
          icon: AdaptiveIcons.infoOutlined,
          title: l10n.emptyGenericTitle,
          subtitle: null,
          actionIcon: null,
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final VegetableType? illustration;
  final String title;
  final String? subtitle;
  final IconData? actionIcon;

  const _EmptyStateConfig({
    required this.icon,
    this.illustration,
    required this.title,
    this.subtitle,
    this.actionIcon,
  });
}
