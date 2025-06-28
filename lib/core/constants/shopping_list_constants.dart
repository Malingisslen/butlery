// lib/core/constants/shopping_list_constants.dart

/// 🔍 AI INFO BLOCK:
/// Component: Shopping List Constants
/// File: core/constants/shopping_list_constants.dart
/// Quick Guide: Centraliserade konstanter för shopping list
/// Dependencies IN: None
/// Dependencies OUT: Used by shopping list widgets
/// Data flow: Static constants
/// State management: N/A
/// Purpose: Eliminera magic numbers och centralisera värden
/// Common issues: N/A
/// Test coverage: N/A
/// Performance: ⚡ Compile-time constants
/// Analytics: N/A
/// Code smells: ✅ Clean constants definition
/// Connected to: All shopping list components
/// Used in phases: Shopping list feature

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
