/// Icon constants for maintaining UI-agnostic ViewModels.

/// Semantic icon types used throughout the application.
enum IconType {
  /// Restaurant menus or food-related content
  restaurantMenu,
  
  /// Automatic fixes or smart suggestions
  autoFixHigh,
  
  /// Person or user profile
  person,
}

/// Maps semantic icon types to string identifiers.
class IconConstants {
  /// Icon type to string mapping
  static const Map<IconType, String> iconMap = {
    IconType.restaurantMenu: 'restaurant_menu',
    IconType.autoFixHigh: 'auto_fix_high',
    IconType.person: 'person',
  };
  
  /// Resolves icon type to string identifier
  static String getIconName(IconType iconType) {
    return iconMap[iconType] ?? 'help';
  }
}