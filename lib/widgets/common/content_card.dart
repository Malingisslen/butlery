/// Content card facade for unified multi-type display (recipes, friends, menus,
/// shopping lists). Modes: detailed / compact / grid.

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';

// Import focused card modules
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

// Re-export for backward compatibility
export 'package:butlery/widgets/recipe/recipe_card.dart' show RecipeCardStyle;
export 'content_cards/friend_card.dart' show FriendCardStyle;
export 'content_cards/menu_card.dart' show MenuCardStyle;
export 'content_cards/shopping_list_card.dart' show ShoppingListCardStyle;

/// Content card type enumeration defining supported content types for unified card display system.
/// This enumeration provides type safety and clear categorization for different content types
/// supported by the ContentCard facade, enabling proper delegation to specialized card modules
/// and consistent content type handling across the application.
enum ContentCardType {
  /// Recipe content cards displaying cooking recipes with ingredients, instructions, and metadata
  recipe,

  /// Menu content cards displaying weekly meal plans with recipe collections and sharing features
  menu,

  /// Shopping list content cards displaying collaborative shopping lists with item management
  shoppingList,

  /// Friend content cards displaying user profiles with social relationship information
  friend,
}

/// Content card style enumeration defining display modes for responsive and context-aware card rendering.
/// This enumeration provides consistent styling options across all content types, enabling
/// responsive design patterns and optimized display for different UI contexts and screen sizes.
enum ContentCardStyle {
  /// Detailed display mode showing complete content information with images, descriptions, and full metadata
  detailed,

  /// Compact display mode optimized for space efficiency in list views and mobile interfaces
  compact,

  /// Grid display mode optimized for grid-based layouts and responsive multi-column displays
  grid,
}

/// Facade that renders one of four content types through a focused card module.
///
/// Delegation only: every visual decision lives in the specialised card
/// ([RecipeCard], [FriendCard], [MenuCard], [ShoppingListCard]). This class just maps the shared parameters onto
/// whichever one [type] selects, so a caller can swap content types without
/// learning four APIs.
class ContentCard extends StatelessWidget {
  /// Content item to display - type depends on ContentCardType specified
  final dynamic item;

  /// Content type determining which specialized card module to delegate to
  final ContentCardType type;

  /// Display style controlling card appearance and information density
  final ContentCardStyle style;

  /// Primary tap handler for content interaction and navigation
  final VoidCallback? onTap;

  /// Long press handler for context menus and advanced interactions
  final VoidCallback? onLongPress;

  /// External margin spacing around the card widget
  final EdgeInsets? margin;

  /// Internal padding within the card content area
  final EdgeInsets? padding;

  /// Controls visibility of primary content images and visual elements
  final bool showImage;

  /// Controls visibility of content tags, categories, and classification labels
  final bool showTags;

  /// Controls visibility of metadata information such as creation date, author, and statistics
  final bool showMetadata;

  /// Controls visibility of online/offline status indicators for user-related content
  final bool showOnlineStatus;

  /// Controls visibility of sharing status and collaboration indicators
  final bool showSharingStatus;

  /// Optional trailing widget for custom actions and controls
  final Widget? trailing;

  /// Optional subtitle text for additional context information
  final String? subtitle;

  /// Pantry match percentage (0.0..1.0) for recipe cards — displayed as
  /// a badge when the "Laga med vad jag har" filter is active.
  final double? matchPercent;

  /// Pooled "Butlery-betyget" stats for this recipe's dish, when the feature is
  /// on and the pool clears the display floor. Null → the card shows the
  /// per-copy rating (decision 9 fallback).
  final PooledStats? pooledStats;

  /// [item] must match [type] — the delegating builder asserts it.
  const ContentCard({
    super.key,
    required this.item,
    required this.type,
    this.style = ContentCardStyle.detailed,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.padding,
    this.showImage = true,
    this.showTags = true,
    this.showMetadata = true,
    this.showOnlineStatus = false,
    this.showSharingStatus = false,
    this.trailing,
    this.subtitle,
    this.matchPercent,
    this.pooledStats,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate to the appropriate focused module based on content type
    switch (type) {
      case ContentCardType.recipe:
        return _buildRecipeCard();
      case ContentCardType.friend:
        return _buildFriendCard();
      case ContentCardType.menu:
        return _buildMenuCard();
      case ContentCardType.shoppingList:
        return _buildShoppingListCard();
    }
  }

  /// Creates and configures a recipe card widget with proper type validation and parameter mapping.
  /// This method handles delegation to the RecipeCard module with comprehensive parameter
  /// mapping and type safety validation. It ensures the provided item is a valid Recipe
  /// instance and maps generic ContentCard parameters to RecipeCard-specific configurations.
  /// Returns configured RecipeCard widget with all applicable parameters mapped
  /// Throws AssertionError if item is not a Recipe instance
  Widget _buildRecipeCard() {
    assert(item is Recipe, 'Recipe card requires Recipe item');
    final recipe = item as Recipe;

    return RecipeCard(
      recipe: recipe,
      onTap: onTap != null ? (_) => onTap!() : null,
      onLongPress: onLongPress != null ? (_) => onLongPress!() : null,
      showImage: showImage,
      showMetadata: showMetadata,
      margin: margin,
      padding: padding,
      style: _mapToRecipeCardStyle(style),
      matchPercent: matchPercent,
      pooledStats: pooledStats,
    );
  }

  /// Creates and configures a friend card widget with user profile display and social features.
  /// This method handles delegation to the FriendCard module with comprehensive social
  /// feature support including online status, relationship management, and custom actions.
  /// It maps generic parameters to friend-specific display configurations.
  /// Returns configured FriendCard widget with social features enabled
  /// Throws AssertionError if item is not a UserProfile instance
  Widget _buildFriendCard() {
    assert(item is UserProfile, 'Friend card requires UserProfile item');
    final user = item as UserProfile;

    return FriendCard(
      user: user,
      onTap: onTap,
      onLongPress: onLongPress,
      showAvatar: showImage,
      showOnlineStatus: showOnlineStatus,
      margin: margin,
      padding: padding,
      style: _mapToFriendCardStyle(style),
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  /// Creates and configures a menu card widget with meal planning and collaboration features.
  /// This method handles delegation to the MenuCard module with support for weekly menu
  /// display, sharing status, and collaborative meal planning features. It maps generic
  /// parameters to menu-specific display configurations.
  /// Returns configured MenuCard widget with meal planning features
  Widget _buildMenuCard() {
    // Menu model not yet defined, so we accept dynamic for now
    return MenuCard(
      menu: item,
      onTap: onTap,
      onLongPress: onLongPress,
      showPreview: showTags, // Map showTags to showPreview for menus
      showMetadata: showMetadata,
      showSharingStatus: showSharingStatus,
      margin: margin,
      padding: padding,
      style: _mapToMenuCardStyle(style),
    );
  }

  /// Creates and configures a shopping list card widget with collaborative list management features.
  /// This method handles delegation to the ShoppingListCard module with support for
  /// collaborative shopping list display, item preview, and sharing status indicators.
  /// It provides specialized UI for shopping list management and collaboration.
  /// Returns configured ShoppingListCard widget with collaboration features
  Widget _buildShoppingListCard() {
    // Shopping list model not yet defined, so we accept dynamic for now
    return ShoppingListCard(
      shoppingList: item,
      onTap: onTap,
      onLongPress: onLongPress,
      showPreview: showTags, // Map showTags to showPreview for shopping lists
      showMetadata: showMetadata,
      showSharingStatus: showSharingStatus,
      margin: margin,
      padding: padding,
      style: _mapToShoppingListCardStyle(style),
    );
  }

  // Style mapping methods to convert from generic ContentCardStyle to specific card styles
  RecipeCardStyle _mapToRecipeCardStyle(ContentCardStyle style) {
    switch (style) {
      case ContentCardStyle.detailed:
        return RecipeCardStyle.detailed;
      case ContentCardStyle.compact:
        return RecipeCardStyle.compact;
      case ContentCardStyle.grid:
        return RecipeCardStyle.grid;
    }
  }

  FriendCardStyle _mapToFriendCardStyle(ContentCardStyle style) {
    switch (style) {
      case ContentCardStyle.detailed:
        return FriendCardStyle.detailed;
      case ContentCardStyle.compact:
        return FriendCardStyle.compact;
      case ContentCardStyle.grid:
        return FriendCardStyle.list; // Grid maps to list for friends
    }
  }

  MenuCardStyle _mapToMenuCardStyle(ContentCardStyle style) {
    switch (style) {
      case ContentCardStyle.detailed:
        return MenuCardStyle.detailed;
      case ContentCardStyle.compact:
        return MenuCardStyle.compact;
      case ContentCardStyle.grid:
        return MenuCardStyle.grid;
    }
  }

  ShoppingListCardStyle _mapToShoppingListCardStyle(ContentCardStyle style) {
    switch (style) {
      case ContentCardStyle.detailed:
        return ShoppingListCardStyle.detailed;
      case ContentCardStyle.compact:
        return ShoppingListCardStyle.compact;
      case ContentCardStyle.grid:
        return ShoppingListCardStyle.grid;
    }
  }

  // Static factory methods for backward compatibility (legacy API support)

  /// Legacy method: Create recipe card (backward compatibility)
  static Widget recipe({
    required Recipe recipe,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsets? margin,
    EdgeInsets? padding,
    bool showImage = true,
    bool showTags = true,
    bool showMetadata = true,
  }) {
    return ContentCard(
      item: recipe,
      type: ContentCardType.recipe,
      style: ContentCardStyle.detailed,
      onTap: onTap,
      onLongPress: onLongPress,
      margin: margin,
      padding: padding,
      showImage: showImage,
      showTags: showTags,
      showMetadata: showMetadata,
    );
  }

  /// Legacy method: Create compact recipe card (backward compatibility)
  static Widget compactRecipe({
    required Recipe recipe,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsets? margin,
    EdgeInsets? padding,
    bool showImage = true,
    bool showMetadata = true,
  }) {
    return ContentCard(
      item: recipe,
      type: ContentCardType.recipe,
      style: ContentCardStyle.compact,
      onTap: onTap,
      onLongPress: onLongPress,
      margin: margin,
      padding: padding,
      showImage: showImage,
      showTags: false,
      showMetadata: showMetadata,
    );
  }

  /// Legacy method: Create friend card (backward compatibility)
  static Widget friend({
    required UserProfile user,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsets? margin,
    EdgeInsets? padding,
    bool showAvatar = true,
    bool showOnlineStatus = false,
    bool showMetadata = true,
    Widget? trailing,
  }) {
    return ContentCard(
      item: user,
      type: ContentCardType.friend,
      style: ContentCardStyle.detailed,
      onTap: onTap,
      onLongPress: onLongPress,
      margin: margin,
      padding: padding,
      showImage: showAvatar,
      showOnlineStatus: showOnlineStatus,
      showMetadata: showMetadata,
      trailing: trailing,
    );
  }
}
