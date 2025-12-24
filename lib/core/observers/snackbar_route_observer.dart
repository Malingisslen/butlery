/// Route observer that automatically dismisses snackbars on navigation events.
/// This observer integrates with Flutter's navigation system to provide automatic
/// snackbar cleanup when users navigate between screens. It ensures that success,
/// error, warning, and info messages don't linger when users move to different views,
/// providing a clean and non-distracting user experience.
/// ## Core Behavior
/// The observer clears all active snackbars on these navigation events:
/// - **Route Push**: When a new route is pushed onto the stack
/// - **Route Pop**: When the current route is popped from the stack
/// - **Route Replace**: When a route replaces another in the stack
/// ## Integration
/// Register this observer in your MaterialApp's navigatorObservers:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     SnackbarRouteObserver(),
///     // other observers...
///   ],
/// )
/// ```
/// ## Usage Example
/// ```dart
/// // User performs action that shows snackbar
/// SnackBarUtils.showSuccess(context, 'Recipe saved!');
/// // User navigates to another screen
/// Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetail()));
/// // SnackbarRouteObserver automatically clears the snackbar
/// // No lingering message on the new screen
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart';

/// Route observer that automatically dismisses snackbars on navigation.
/// This observer listens to navigation events and clears any active snackbars
/// to prevent them from lingering when users navigate between screens.
class SnackbarRouteObserver extends NavigatorObserver {
  /// Creates a snackbar route observer.
  SnackbarRouteObserver();

  /// Clears snackbars when a new route is pushed.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _clearSnackbars('didPush: ${route.settings.name}');
  }

  /// Clears snackbars when a route is popped.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _clearSnackbars('didPop: ${route.settings.name}');
  }

  /// Clears snackbars when a route is replaced.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _clearSnackbars(
        'didReplace: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}');
  }

  /// Internal method to clear snackbars safely.
  void _clearSnackbars(String navigationEvent) {
    try {
      // Get the navigator's context
      final context = navigator?.context;

      if (context != null && context.mounted) {
        // Clear all active snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        AppLogger.debug(
            'SnackbarRouteObserver: Cleared snackbars on $navigationEvent');
      }
    } catch (e) {
      // Fail silently - snackbar clearing is not critical
      AppLogger.warning(
          'SnackbarRouteObserver: Failed to clear snackbars on $navigationEvent: $e');
    }
  }
}
