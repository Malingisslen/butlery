/// Route observer that automatically tracks screen performance with Firebase Performance.
/// This observer integrates with Flutter's navigation system and Firebase Performance
/// Monitoring to provide automatic performance tracking for all screens. It measures
/// screen rendering time, transition duration, and navigation patterns, helping identify
/// performance bottlenecks and slow screens.
/// ## Core Behavior
/// The observer creates Firebase Performance traces for these navigation events:
/// - **Route Push**: Starts a new screen trace when a route is pushed
/// - **Route Pop**: Stops the screen trace when a route is popped
/// - **Route Replace**: Stops old trace and starts new trace
/// Each trace is named with pattern: `screen_{route_name}` and includes:
/// - Screen rendering duration
/// - Previous screen context (for navigation flow analysis)
/// - Route configuration attributes
/// ## Integration
/// Register this observer in your MaterialApp's navigatorObservers:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     PerformanceNavigatorObserver(),
///     // other observers...
///   ],
/// )
/// ```
/// ## Firebase Console
/// After 24 hours, view traces in Firebase Console:
/// - Performance → Custom Traces → Filter by "screen_"
/// - See percentiles (p50, p90, p99) for each screen
/// - Identify slow screens and performance regressions
/// ## Usage Example
/// ```dart
/// // User navigates to recipe detail
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => RecipeDetailView(),
///     settings: RouteSettings(name: 'recipe_detail'), // Important!
///   ),
/// );
/// // PerformanceNavigatorObserver automatically:
/// // 1. Starts trace: screen_recipe_detail
/// // 2. Records screen rendering time
/// // 3. Stops trace when user navigates away
/// // 4. Data appears in Firebase Console after 24 hours
/// ```
/// ## Route Naming Convention
/// For accurate tracking, ensure all routes have meaningful names:
/// - ✅ Good: `settings.name = 'recipe_detail'`
/// - ✅ Good: `settings.name = 'shopping_list'`
/// - ❌ Bad: `settings.name = null` (will be tracked as 'unknown_screen')

import 'package:flutter/material.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';

/// Route observer that automatically tracks screen performance with Firebase.
/// This observer listens to navigation events and creates Firebase Performance
/// traces for each screen, measuring rendering time and navigation patterns.
class PerformanceNavigatorObserver extends NavigatorObserver {
  /// Map of active routes to their performance traces.
  /// We track traces by route instance to ensure proper cleanup when
  /// routes are popped from the navigation stack.
  final Map<Route<dynamic>, Trace> _activeTraces = {};

  /// Creates a performance navigator observer.
  PerformanceNavigatorObserver();

  /// Starts performance trace when a new route is pushed.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    final routeName = _getRouteName(route);
    _startScreenTrace(
      route,
      routeName,
      previousScreen: previousRoute != null
          ? _getRouteName(previousRoute)
          : null,
    );
  }

  /// Stops performance trace when a route is popped.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    _stopScreenTrace(route);
  }

  /// Handles route replacement by stopping old trace and starting new trace.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (oldRoute != null) {
      _stopScreenTrace(oldRoute);
    }

    if (newRoute != null) {
      final routeName = _getRouteName(newRoute);
      _startScreenTrace(
        newRoute,
        routeName,
        replacedScreen: oldRoute != null ? _getRouteName(oldRoute) : null,
      );
    }
  }

  /// Extracts route name from RouteSettings, with fallback for unnamed routes.
  String _getRouteName(Route<dynamic> route) {
    final routeName = route.settings.name;

    if (routeName != null && routeName.isNotEmpty) {
      // Remove leading slash if present for cleaner trace names
      return routeName.startsWith('/') ? routeName.substring(1) : routeName;
    }

    // Fallback for routes without names
    return 'unknown_screen';
  }

  /// Starts a Firebase Performance trace for the given route.
  /// Adds optional attributes for navigation context (previous/replaced screens).
  Future<void> _startScreenTrace(
    Route<dynamic> route,
    String screenName, {
    String? previousScreen,
    String? replacedScreen,
  }) async {
    try {
      // Create trace with screen_ prefix for easy filtering in Firebase Console
      final traceName = 'screen_$screenName';
      final trace = await FirebasePerformanceService.startTrace(traceName);

      // Add navigation context attributes
      if (previousScreen != null) {
        trace.putAttribute('previous_screen', previousScreen);
      }

      if (replacedScreen != null) {
        trace.putAttribute('replaced_screen', replacedScreen);
      }

      // Track route configuration
      if (route.settings.arguments != null) {
        trace.putAttribute('has_arguments', 'true');
      }

      // Store trace for later cleanup
      _activeTraces[route] = trace;

      AppLogger.debug(
        '📊 Performance: Started screen trace for $screenName '
        '${previousScreen != null ? '(from: $previousScreen)' : ''}',
      );
    } catch (e) {
      AppLogger.warning(
        'Performance: Failed to start screen trace for $screenName: $e',
      );
    }
  }

  /// Stops the Firebase Performance trace for the given route.
  Future<void> _stopScreenTrace(Route<dynamic> route) async {
    try {
      final trace = _activeTraces.remove(route);

      if (trace != null) {
        await trace.stop();

        final routeName = _getRouteName(route);
        AppLogger.debug('📊 Performance: Stopped screen trace for $routeName');
      }
    } catch (e) {
      final routeName = _getRouteName(route);
      AppLogger.warning(
        'Performance: Failed to stop screen trace for $routeName: $e',
      );
    }
  }

  /// Disposes all active traces (useful for testing or cleanup).
  Future<void> dispose() async {
    try {
      // Stop all active traces
      final traces = List<Trace>.from(_activeTraces.values);
      _activeTraces.clear();

      for (final trace in traces) {
        try {
          await trace.stop();
        } catch (e) {
          // Continue disposing other traces even if one fails
          AppLogger.warning(
            'Performance: Failed to stop trace during dispose: $e',
          );
        }
      }

      AppLogger.debug(
        '📊 Performance: Disposed all active screen traces (${traces.length})',
      );
    } catch (e) {
      AppLogger.error('Performance: Failed to dispose traces: $e');
    }
  }
}
