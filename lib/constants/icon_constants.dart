// lib/constants/icon_constants.dart

/// Constants for icons used in ViewModels
/// This allows ViewModels to remain UI-agnostic while still providing icon information
enum IconType {
  restaurantMenu,
  autoFixHigh,
  person,
}

/// Maps icon types to their string representations
class IconConstants {
  static const Map<IconType, String> iconMap = {
    IconType.restaurantMenu: 'restaurant_menu',
    IconType.autoFixHigh: 'auto_fix_high',
    IconType.person: 'person',
  };
  
  /// Get icon name for a specific icon type
  static String getIconName(IconType iconType) {
    return iconMap[iconType] ?? 'help';
  }
}