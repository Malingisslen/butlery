// lib/core/constants/shopping_list_constants.dart


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
