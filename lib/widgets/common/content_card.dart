// lib/widgets/common/content_card.dart - Clean facade with delegation pattern

import 'package:flutter/material.dart';
import '../../models/recipe_unified.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';

// Import focused card modules
import 'content_cards/recipe_card.dart';
import 'content_cards/friend_card.dart';
import 'content_cards/menu_card.dart';
import 'content_cards/shopping_list_card.dart';

// Re-export for backward compatibility
export 'content_cards/recipe_card.dart' show RecipeCardStyle;
export 'content_cards/friend_card.dart' show FriendCardStyle;
export 'content_cards/menu_card.dart' show MenuCardStyle;
export 'content_cards/shopping_list_card.dart' show ShoppingListCardStyle;

/// 🚀 ContentCard - Clean facade for all content card types
///
/// Clean facade that delegates to focused single-responsibility card modules:
/// - ✅ Recipe cards (delegates to RecipeCard)
/// - ✅ Friend cards (delegates to FriendCard & FriendRequestCard)  
/// - ✅ Menu cards (delegates to MenuCard)
/// - ✅ Shopping list cards (delegates to ShoppingListCard)
/// - ✅ 100% backward compatibility maintained
/// - ✅ Clean modular architecture for maintainability
///
/// MIGRATION GUIDE:
/// ```dart
/// // Before:
/// ContentCard(
///   item: recipe,
///   type: ContentCardType.recipe,
///   style: ContentCardStyle.detailed,
/// )
///
/// // After (still works the same):
/// ContentCard(
///   item: recipe,
///   type: ContentCardType.recipe,
///   style: ContentCardStyle.detailed,
/// )
/// 
/// // Or use focused components directly:
/// RecipeCard(
///   recipe: recipe,
///   style: RecipeCardStyle.detailed,
/// )
/// ```
///
/// ARCHITECTURE:
/// This file now serves as a clean facade that delegates to focused modules:
/// - Each module has a single responsibility for one content type
/// - Backward compatibility maintained through delegation
/// - Better maintainability with focused concerns
/// - Easier testing with isolated modules

/// Enum för olika kort-typer
enum ContentCardType {
  recipe,
  menu,
  shoppingList,
  friend,
  friendRequest,
}

/// Enum för olika display-stilar
enum ContentCardStyle {
  detailed, // Full visning med alla detaljer
  compact, // Kompakt visning utan beskrivning/taggar
  grid, // För grid-layout
}

/// Main ContentCard facade that delegates to focused modules
class ContentCard extends StatelessWidget {
  final dynamic item;
  final ContentCardType type;
  final ContentCardStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool showImage;
  final bool showTags;
  final bool showMetadata;
  final bool showOnlineStatus;
  final bool showSharingStatus;
  final Widget? trailing;
  final String? subtitle;

  // Accept actions for friend requests
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

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
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate to the appropriate focused module based on content type
    switch (type) {
      case ContentCardType.recipe:
        return _buildRecipeCard();
      case ContentCardType.friend:
        return _buildFriendCard();
      case ContentCardType.friendRequest:
        return _buildFriendRequestCard();
      case ContentCardType.menu:
        return _buildMenuCard();
      case ContentCardType.shoppingList:
        return _buildShoppingListCard();
    }
  }

  Widget _buildRecipeCard() {
    assert(item is Recipe, 'Recipe card requires Recipe item');
    final recipe = item as Recipe;
    
    return RecipeCard(
      recipe: recipe,
      onTap: onTap,
      onLongPress: onLongPress,
      showImage: showImage,
      showTags: showTags,
      showMetadata: showMetadata,
      margin: margin,
      padding: padding,
      style: _mapToRecipeCardStyle(style),
    );
  }

  Widget _buildFriendCard() {
    assert(item is UserProfile, 'Friend card requires UserProfile item');
    final user = item as UserProfile;
    
    return FriendCard(
      user: user,
      onTap: onTap,
      onLongPress: onLongPress,
      showAvatar: showImage,
      showOnlineStatus: showOnlineStatus,
      showMetadata: showMetadata,
      margin: margin,
      padding: padding,
      style: _mapToFriendCardStyle(style),
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  Widget _buildFriendRequestCard() {
    assert(item is FriendRequest, 'Friend request card requires FriendRequest item');
    final friendRequest = item as FriendRequest;
    
    return FriendRequestCard(
      friendRequest: friendRequest,
      onAccept: onAccept,
      onDecline: onDecline,
      onTap: onTap,
      margin: margin,
      padding: padding,
    );
  }

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
      showTags: false, // Compact doesn't show tags
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

  /// Legacy method: Create friend request card (backward compatibility)
  static Widget friendRequest({
    required FriendRequest friendRequest,
    VoidCallback? onAccept,
    VoidCallback? onDecline,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsets? margin,
    EdgeInsets? padding,
    bool showAvatar = true,
    bool showMetadata = true,
  }) {
    return ContentCard(
      item: friendRequest,
      type: ContentCardType.friendRequest,
      style: ContentCardStyle.detailed,
      onAccept: onAccept,
      onDecline: onDecline,
      onTap: onTap,
      onLongPress: onLongPress,
      margin: margin,
      padding: padding,
      showImage: showAvatar,
      showMetadata: showMetadata,
    );
  }
}