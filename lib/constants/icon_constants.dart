/// Icon constants for maintaining UI-agnostic ViewModels in the Butlery application.
///
/// This module provides a centralized way to reference icons used throughout the app
/// while keeping ViewModels independent of specific UI frameworks. The ViewModel layer
/// can reference icon semantics without depending on Flutter's icon system directly.
///
/// **Architecture Integration:**
/// - Used by ViewModels to provide icon hints to Views
/// - Maintains separation between presentation logic and UI implementation
/// - Supports theming and icon customization at the UI layer
///
/// **Usage Example:**
/// ```dart
/// // In ViewModel
/// String getActionIcon() => IconConstants.getIconName(IconType.autoFixHigh);
/// 
/// // In View
/// Icon(Icons.valueOf(viewModel.getActionIcon()))
/// ```

/// Enumeration of semantic icon types used throughout the application.
///
/// Each enum value represents a semantic meaning rather than a specific icon,
/// allowing for flexible UI implementation and theming.
enum IconType {
  /// Icon representing restaurant menus or food-related content
  restaurantMenu,
  
  /// Icon representing automatic fixes or smart suggestions
  autoFixHigh,
  
  /// Icon representing a person or user profile
  person,
}

/// Central registry for mapping semantic icon types to string identifiers.
///
/// This class provides the bridge between semantic icon meanings and their
/// concrete representations, supporting UI flexibility and theming.
///
/// **Design Pattern:**
/// Uses the Strategy pattern to allow different icon implementations
/// without changing the semantic meaning throughout the application.
class IconConstants {
  /// Mapping from semantic icon types to string identifiers.
  ///
  /// These strings correspond to Material Design icon names that can be
  /// resolved by the UI layer into actual icon widgets.
  static const Map<IconType, String> iconMap = {
    IconType.restaurantMenu: 'restaurant_menu',
    IconType.autoFixHigh: 'auto_fix_high',
    IconType.person: 'person',
  };
  
  /// Resolves an icon type to its string identifier.
  ///
  /// [iconType] The semantic icon type to resolve
  /// Returns the corresponding icon name string, or 'help' as fallback
  ///
  /// **Error Handling:**
  /// Returns a safe default ('help') for unknown icon types to prevent
  /// runtime failures in the UI layer.
  static String getIconName(IconType iconType) {
    return iconMap[iconType] ?? 'help';
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}