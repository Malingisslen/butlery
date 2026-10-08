import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/icons/pending_glyphs.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
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

    // Passing [icon] == ButleryIcons.x is a sentinel meaning "render no leading
    // visual at all" — neither illustration nor icon. Used by compact empty
    // states embedded in already-decorated surfaces. Named here so the
    // suppression is explicit rather than a silent magic-value check.
    final suppressLeadingVisual = icon == ButleryIcons.x;

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration or Icon
              if (!suppressLeadingVisual) ...[
                if (shouldUseIllustration && emptyConfig.illustration != null)
                  VegetableIllustration(
                    type: emptyConfig.illustration!,
                    size: iconSize ?? 100,
                  )
                else
                  ButleryIcon(
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
          icon: ButleryIcons.utensils,
          illustration: VegetableType.broccoli,
          title: l10n.emptyNoResults,
          subtitle: l10n.emptyNoRecipesSubtitle(l10n.commonAdd),
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noSearchResults:
        return _EmptyStateConfig(
          icon: ButleryIcons.searchOff,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoResults,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: ButleryIcons.x,
        );
      case EmptyStateVariant.noFriendsSearchResults:
        return _EmptyStateConfig(
          icon: ButleryIcons.searchOff,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoFriendsSearchTitle,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: ButleryIcons.x,
        );
      case EmptyStateVariant.noGroupsSearchResults:
        return _EmptyStateConfig(
          icon: ButleryIcons.searchOff,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoGroupsSearchTitle,
          subtitle: l10n.emptyNoSearchResultsSubtitle,
          actionIcon: ButleryIcons.x,
        );
      case EmptyStateVariant.noMenu:
        return _EmptyStateConfig(
          icon: ButleryIcons.utensils,
          illustration: VegetableType.peaPod,
          title: l10n.emptyNoMenuTitle,
          subtitle: l10n.emptyNoMenuSubtitle,
          actionIcon: null,
        );
      case EmptyStateVariant.noShoppingList:
        return _EmptyStateConfig(
          icon: ButleryIcons.shoppingCart,
          illustration: VegetableType.carrot,
          title: l10n.emptyNoShoppingListTitle,
          subtitle: l10n.emptyNoShoppingListSubtitle,
          actionIcon: ButleryIcons.utensils,
        );
      case EmptyStateVariant.noFriends:
        return _EmptyStateConfig(
          icon: ButleryIcons.users,
          // No illustration for social states - use icon
          title: l10n.emptyNoFriendsTitle,
          subtitle: l10n.emptyNoFriendsSubtitle,
          actionIcon: ButleryIcons.userPlus,
        );
      case EmptyStateVariant.noCategories:
        return _EmptyStateConfig(
          icon: ButleryIcons.grid,
          title: l10n.emptyNoCategoriesTitle,
          subtitle: l10n.emptyNoCategoriesSubtitle,
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noImages:
        return _EmptyStateConfig(
          icon: ButleryIcons.image,
          title: l10n.emptyNoImagesTitle,
          subtitle: l10n.emptyNoImagesSubtitle,
          actionIcon: ButleryIcons.camera,
        );
      case EmptyStateVariant.noTargets:
        return _EmptyStateConfig(
          icon: ButleryIcons.usersPlus,
          title: l10n.emptyNoTargetsTitle,
          subtitle: l10n.emptyNoTargetsSubtitle,
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noSavedMenus:
        return _EmptyStateConfig(
          icon: PendingGlyphs.savedTemplateOutline,
          illustration: VegetableType.peaPod,
          title: l10n.emptyNoSavedMenusTitle,
          subtitle: l10n.emptyNoSavedMenusSubtitle,
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noSharedShoppingLists:
        return _EmptyStateConfig(
          icon: ButleryIcons.shoppingCart,
          title: l10n.emptyNoSharedShoppingListsTitle,
          subtitle: l10n.emptyNoSharedShoppingListsSubtitle,
          actionIcon: null,
        );
      case EmptyStateVariant.noTags:
        return _EmptyStateConfig(
          icon: ButleryIcons.tag,
          illustration: VegetableType.mushroom,
          title: l10n.emptyNoTagsTitle,
          subtitle: l10n.emptyNoTagsSubtitle,
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noNotifications:
        // BUT-986: branded illustration instead of generic bell icon.
        // PeaPod chosen for the quiet/at-rest connotation.
        return _EmptyStateConfig(
          icon: Icons.notifications_none,
          illustration: VegetableType.peaPod,
          title: l10n.notificationsEmpty,
          subtitle: null,
          actionIcon: null,
        );
      case EmptyStateVariant.noComments:
        // BUT-986: branded illustration; mushroom matches the "be the first to
        // comment" tone (small, inviting).
        return _EmptyStateConfig(
          icon: ButleryIcons.messageSquare,
          illustration: VegetableType.mushroom,
          title: l10n.socialNoCommentsYet,
          subtitle: l10n.socialBeFirstToComment,
          actionIcon: null,
        );
      case EmptyStateVariant.noGroups:
        // BUT-979: branded peaPod illustration (matches noNotifications;
        // the "pod of peas together" reads as collaborative grouping).
        return _EmptyStateConfig(
          icon: ButleryIcons.users,
          illustration: VegetableType.peaPod,
          title: l10n.emptyNoGroupsTitle,
          subtitle: l10n.emptyNoGroupsSubtitle,
          actionIcon: ButleryIcons.plus,
        );
      case EmptyStateVariant.noConversations:
        return _EmptyStateConfig(
          icon: ButleryIcons.messageSquare,
          title: l10n.emptyNoConversationsTitle,
          subtitle: l10n.emptyNoConversationsSubtitle,
          actionIcon: null,
        );
      case EmptyStateVariant.generic:
      default:
        return _EmptyStateConfig(
          icon: ButleryIcons.info,
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
