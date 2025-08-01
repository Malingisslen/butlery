/// Comprehensive shopping list constants implementing unified UI and synchronization timing for collaborative shopping features.
///
/// This constants class serves as the centralized configuration system for all shopping list functionality
/// throughout the Butlery application, providing standardized values for UI dimensions, animation timing,
/// synchronization parameters, and cache management. It ensures consistent behavior across collaborative
/// shopping features, unified shopping services, and the Swedish cooking application's shopping list
/// management capabilities while maintaining optimal user experience and performance characteristics.
///
/// ## Core Architecture Features
/// 
/// **UI Configuration Management**
/// - Bottom sheet sizing and layout dimensions for consistent modal behavior
/// - Animation timing constants for smooth user interface transitions
/// - Floating action button positioning for Swedish design preferences
/// - Handle dimensions for gesture-based sheet manipulation
/// 
/// **Synchronization Intelligence**
/// - Debounce timing for real-time collaborative editing performance
/// - Retry logic configuration for reliable network synchronization
/// - Cache expiration management for optimal data freshness
/// - Snackbar timing for user feedback and notification consistency
/// 
/// **Collaborative Shopping Integration**
/// - Standardized timing values for UnifiedShoppingService operations
/// - Consistent animation duration across collaborative shopping views
/// - Optimized sync debounce for multi-user shopping list editing
/// - Cache management aligned with collaborative data requirements
/// 
/// ## Usage Examples
/// 
/// **Bottom Sheet Configuration:**
/// ```dart
/// showModalBottomSheet(
///   constraints: BoxConstraints(
///     maxHeight: MediaQuery.of(context).size.height * 
///       ShoppingListConstants.bottomSheetMaxHeight,
///   ),
///   // Uses standardized height ratio for consistent modal sizing
/// );
/// ```
/// 
/// **Animation Integration:**
/// ```dart
/// AnimatedContainer(
///   duration: ShoppingListConstants.animationDuration,
///   // Ensures consistent animation timing across shopping features
/// );
/// ```
/// 
/// **Synchronization Configuration:**
/// ```dart
/// Timer.periodic(ShoppingListConstants.syncDebounce, (_) {
///   // Synchronized with collaborative editing requirements
///   await _syncShoppingListChanges();
/// });
/// ```
/// 
/// **Cache Management:**
/// ```dart
/// final isExpired = lastUpdate.difference(DateTime.now()) > 
///   ShoppingListConstants.cacheExpiration;
/// // Aligned with collaborative data freshness requirements
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **UI Responsiveness**: Optimized animation timing for 60fps performance
/// - **Sync Efficiency**: Debounce timing balances responsiveness with server load
/// - **Cache Strategy**: 24-hour expiration optimizes data freshness vs. performance
/// - **Error Recovery**: Retry configuration ensures reliable collaborative synchronization
/// 
/// ## Swedish Design Integration
/// 
/// - Bottom sheet dimensions follow Swedish mobile design guidelines
/// - Animation timing optimized for calm, smooth user experience
/// - Handle dimensions provide accessible gesture interaction
/// - Floating action button positioning aligned with Swedish UI patterns
/// 
/// This constants class is essential for maintaining consistent shopping list behavior across
/// all collaborative features while ensuring optimal performance and user experience in the
/// Swedish cooking application architecture.

class ShoppingListConstants {
  // Förhindra instansiering
  ShoppingListConstants._();

  // Bottom sheet
  static const double bottomSheetMaxHeight = 0.7;
  static const double handleWidth = 40.0;
  static const double handleHeight = 4.0;

  // Timing
  static const Duration snackBarDuration = Duration(seconds: 1);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDuration = Duration(milliseconds: 300);

  // Layout
  static const double fabPadding = 56.0;

  // Synk
  static const Duration syncDebounce = Duration(seconds: 2);
  static const int maxRetries = 3;

  // Cache
  static const Duration cacheExpiration = Duration(hours: 24);
}
