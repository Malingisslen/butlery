// lib/widgets/common/content_cards/menu_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Focused module for menu card components
/// This module handles ONLY menu card display responsibilities:
/// - Menu card rendering with menu-specific data
/// - Menu metadata display (recipe count, duration, etc.)
/// - Menu sharing status and collaborative indicators
/// - Menu-specific styling and theming
/// - Menu preview with recipe list
/// ❌ DOES NOT CONTAIN: Recipe cards, friend cards, shopping list cards, generic content logic
class MenuCard extends StatelessWidget {
  final dynamic menu; // Can be SharedMenu, RealtimeMenu, or Map<String, List<Recipe>>
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showPreview;
  final bool showMetadata;
  final bool showSharingStatus;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final MenuCardStyle style;

  const MenuCard({
    super.key,
    required this.menu,
    this.onTap,
    this.onLongPress,
    this.showPreview = true,
    this.showMetadata = true,
    this.showSharingStatus = false,
    this.margin,
    this.padding,
    this.style = MenuCardStyle.detailed,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: margin ?? _getDefaultMargin(),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Container(
              padding: padding ?? _getDefaultPadding(),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(color: AppColors.textLight, width: AppDimensions.borderWidthThin),
              ),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (style) {
      case MenuCardStyle.detailed:
        return _buildDetailedContent(context);
      case MenuCardStyle.compact:
        return _buildCompactContent(context);
      case MenuCardStyle.grid:
        return _buildGridContent(context);
    }
  }

  Widget _buildDetailedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuHeader(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingS),
          _buildMenuMetadata(context),
        ],
        if (showPreview) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildMenuPreview(context),
        ],
        if (showSharingStatus) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildSharingStatus(context),
        ],
      ],
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMenuHeader(context),
              if (showMetadata) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildMenuMetadata(context),  
              ],
            ],
          ),
        ),
        if (showSharingStatus) _buildSharingIndicator(context),
      ],
    );
  }

  Widget _buildGridContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuHeader(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildMenuMetadata(context),
        ],
        if (showSharingStatus) ...[
          const SizedBox(height: AppDimensions.spacingS),
          _buildSharingIndicator(context),
        ],
      ],
    );
  }

  Widget _buildMenuHeader(BuildContext context) {
    final title = _getMenuTitle();
    return Row(
      children: [
        const Icon(
          Icons.restaurant_menu,
          size: AppDimensions.iconSizeM,
          color: AppColors.textMedium,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Text(
            title,
            style: style == MenuCardStyle.compact 
                ? AppTextStyles.bodyLarge
                : AppTextStyles.titleMedium,
            maxLines: style == MenuCardStyle.compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuMetadata(BuildContext context) {
    final recipeCount = _getRecipeCount();
    final duration = _getMenuDuration();
    
    final metadata = <String>[];
    if (recipeCount > 0) {
      metadata.add('$recipeCount recept');
    }
    if (duration != null) {
      metadata.add(duration);
    }

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      metadata.join(' • '),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
    );
  }

  Widget _buildMenuPreview(BuildContext context) {
    final allRecipes = _getMenuRecipes();
    
    if (allRecipes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        decoration: BoxDecoration(
          color: AppColors.backgroundTint,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: AppDimensions.iconSizeS,
              color: AppColors.textMedium,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Inga recept i menyn',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            ),
          ],
        ),
      );
    }

    final recipesToShow = allRecipes.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recept i menyn:',
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        ...recipesToShow.map((recipe) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.textMedium,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Text(
                  _getRecipeTitle(recipe),
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        if (allRecipes.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              '+ ${allRecipes.length - 3} fler recept',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            ),
          ),
      ],
    );
  }

  Widget _buildSharingStatus(BuildContext context) {
    final isShared = _isMenuShared();
    final memberCount = _getMenuMemberCount();
    
    if (!isShared) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: AppDimensions.iconSizeS,
            color: Colors.blue[700],
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            memberCount > 0 
                ? 'Delad med $memberCount personer'
                : 'Delad meny',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingIndicator(BuildContext context) {
    final isShared = _isMenuShared();
    
    if (!isShared) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXs),
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.people,
        size: AppDimensions.iconSizeS,
        color: Colors.white,
      ),
    );
  }

  // Helper methods to extract data from the menu object
  // These will need to be updated when the actual menu model is available
  
  String _getMenuTitle() {
    if (menu is SharedMenu) {
      final sharedMenu = menu as SharedMenu;
      return sharedMenu.menuTitle;
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.menuTitle;
    } else if (menu is Map<String, List<Recipe>>) {
      return 'Generated Menu';
    }
    return 'Unnamed Menu';
  }

  int _getRecipeCount() {
    if (menu is SharedMenu) {
      final sharedMenu = menu as SharedMenu;
      return sharedMenu.totalRecipeCount;
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.menuSnapshot.values.fold(0, (total, recipes) => total + recipes.length);
    } else if (menu is Map<String, List<Recipe>>) {
      final menuMap = menu as Map<String, List<Recipe>>;
      return menuMap.values.fold(0, (total, recipes) => total + recipes.length);
    }
    return 0;
  }

  String? _getMenuDuration() {
    if (menu is SharedMenu) {
      final sharedMenu = menu as SharedMenu;
      return sharedMenu.timeAgoText;
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.lastEditedTimeAgo;
    }
    return null;
  }

  List<Recipe> _getMenuRecipes() {
    if (menu is SharedMenu) {
      final sharedMenu = menu as SharedMenu;
      return sharedMenu.menuSnapshot.values.expand((recipes) => recipes).toList();
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.allUniqueRecipes;
    } else if (menu is Map<String, List<Recipe>>) {
      final menuMap = menu as Map<String, List<Recipe>>;
      return menuMap.values.expand((recipes) => recipes).toList();
    }
    return [];
  }

  String _getRecipeTitle(Recipe recipe) {
    return recipe.core.title;
  }

  bool _isMenuShared() {
    if (menu is SharedMenu) {
      return true; // SharedMenu is always shared
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.participantCount > 1;
    }
    return false;
  }

  int _getMenuMemberCount() {
    if (menu is SharedMenu) {
      // TODO (Issue #014): Member count no longer stored in model.
      // Need async repository call or cached count. Return 0 for now.
      return 0;
    } else if (menu is RealtimeMenu) {
      final realtimeMenu = menu as RealtimeMenu;
      return realtimeMenu.participantCount;
    }
    return 0;
  }

  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case MenuCardStyle.compact:
        return const EdgeInsets.only(bottom: AppDimensions.spacingXs);
      case MenuCardStyle.grid:
        return const EdgeInsets.all(AppDimensions.spacingS);
      case MenuCardStyle.detailed:
        return EdgeInsets.zero;
    }
  }

  EdgeInsets _getDefaultPadding() {
    switch (style) {
      case MenuCardStyle.compact:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingS,
        );
      case MenuCardStyle.grid:
        return const EdgeInsets.all(AppDimensions.spacingS);
      case MenuCardStyle.detailed:
        return const EdgeInsets.all(AppDimensions.spacingS);
    }
  }
}

/// Menu card display styles
enum MenuCardStyle {
  detailed,  // Full visning med alla detaljer
  compact,   // Kompakt visning för listor
  grid,      // För grid-layout
}