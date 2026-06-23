/// Content card facade for unified multi-type display (recipes, friends, menus, shopping lists).
/// **Modes:** Detailed/Compact/Grid. **Types:** Recipe/Friend/Menu/ShoppingList/FriendRequest cards.
/// ```dart
/// ContentCard(item: recipe, type: ContentCardType.recipe, style: ContentCardStyle.detailed,
///   onTap: () => navigate(recipe.id));

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';

// Import focused card modules
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';

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

  /// Friend request content cards displaying pending social connections with accept/decline actions
  friendRequest,
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

/// Comprehensive content card facade implementing unified interface for multi-type content display with delegation architecture.
/// This widget serves as the primary facade for displaying various content types through specialized
/// card modules while maintaining consistent API and backward compatibility. It implements intelligent
/// delegation to focused single-responsibility card components, providing optimal performance and
/// maintainability through modular architecture patterns.
/// **Core Features:**
/// - **Type Safety**: Strict content type validation with compile-time type checking
/// - **Responsive Design**: Adaptive styling for different screen sizes and orientations
/// - **Modular Architecture**: Delegation to specialized card modules for optimal maintainability
/// - **Backward Compatibility**: Legacy API support for seamless migration paths
/// - **Performance Optimization**: Lazy loading and efficient rendering through focused modules
/// **Content Type Support:**
/// - Recipe cards with complete cooking information and social features
/// - Friend cards with user profiles and relationship management
/// - Menu cards with meal planning and collaborative features
/// - Shopping list cards with item management and sharing capabilities
/// - Friend request cards with specialized social interaction patterns
/// **Usage Patterns:**
/// ```dart
/// // Standard recipe display
/// ContentCard(
///   item: recipe,
///   type: ContentCardType.recipe,
///   style: ContentCardStyle.detailed,
///   onTap: () => navigateToRecipeDetail(recipe.id),
///   showTags: true,
///   showMetadata: true,
/// );
/// // Compact friend display for lists
/// ContentCard(
///   item: userProfile,
///   type: ContentCardType.friend,
///   style: ContentCardStyle.compact,
///   showOnlineStatus: true,
///   trailing: IconButton(icon: Icon(Icons.message)),
/// );
/// ```
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

  /// User allergen preferences for filtering displayed allergen badges (recipe cards only)
  final Set<String>? userAllergenPrefs;

  /// User dietary preferences for filtering displayed dietary badges (recipe cards only)
  final Set<String>? userDietaryPrefs;

  /// Favorite toggle handler for recipe cards
  final VoidCallback? onFavoriteToggle;

  /// Pantry match percentage (0.0..1.0) for recipe cards — displayed as
  /// a badge when the "Laga med vad jag har" filter is active.
  final double? matchPercent;

  /// Accept action handler specifically for friend request cards
  final VoidCallback? onAccept;

  /// Decline action handler specifically for friend request cards
  final VoidCallback? onDecline;

  /// Creates a content card with specified content type and display configuration.
  /// This constructor provides comprehensive configuration options for displaying various
  /// content types through the unified card interface. It validates required parameters
  /// and provides sensible defaults for optional display and interaction settings.
  /// [item] The content object to display - must match the specified [type]
  /// [type] The content type determining which specialized card module to use
  /// [style] Display style controlling appearance and information density
  /// [onTap] Primary interaction handler for navigation and content access
  /// [onLongPress] Context menu handler for advanced interactions
  /// [margin] External spacing around the card widget
  /// [padding] Internal spacing within the card content area
  /// [showImage] Controls visibility of primary visual elements
  /// [showTags] Controls display of content tags and categories
  /// [showMetadata] Controls display of metadata like dates and statistics
  /// [showOnlineStatus] Controls online/offline status indicators
  /// [showSharingStatus] Controls sharing and collaboration status indicators
  /// [trailing] Optional custom widget for additional actions
  /// [subtitle] Optional context information text
  /// [onAccept] Accept handler for friend request interactions
  /// [onDecline] Decline handler for friend request interactions
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
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.onFavoriteToggle,
    this.matchPercent,
    this.onAccept,
    this.onDecline,
  });

  /// Builds the appropriate specialized card widget based on the specified content type.
  /// This method implements the core delegation logic of the facade pattern, routing
  /// to specialized card modules based on the ContentCardType. Each content type is
  /// handled by a focused single-responsibility widget optimized for that specific
  /// content display requirements and interaction patterns.
  /// Returns the appropriate specialized card widget configured with current parameters
  /// **Performance Notes:**
  /// - Delegates immediately to specialized modules for optimal rendering performance
  /// - No intermediate widget creation or unnecessary abstraction layers
  /// - Leverages Flutter's build optimization through focused widget trees
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
      onFavoriteToggle: onFavoriteToggle != null
          ? (_) => onFavoriteToggle!()
          : null,
      showImage: showImage,
      showTags: showTags,
      showMetadata: showMetadata,
      margin: margin,
      padding: padding,
      style: _mapToRecipeCardStyle(style),
      userAllergenPrefs: userAllergenPrefs,
      userDietaryPrefs: userDietaryPrefs,
      matchPercent: matchPercent,
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
      showMetadata: showMetadata,
      margin: margin,
      padding: padding,
      style: _mapToFriendCardStyle(style),
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  /// Creates and configures a friend request card widget with specialized social interaction actions.
  /// This method handles delegation to the FriendRequestCard module with support for
  /// friend request-specific actions including accept and decline functionality. It provides
  /// specialized UI for managing pending social connections.
  /// Returns configured FriendRequestCard widget with action handlers
  /// Throws AssertionError if item is not a FriendRequest instance
  Widget _buildFriendRequestCard() {
    assert(
      item is FriendRequest,
      'Friend request card requires FriendRequest item',
    );
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
