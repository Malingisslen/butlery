/// Application provider for clean dependency injection access.
///
/// This provider wraps the DI container and provides a clean, widget-friendly
/// interface for accessing services throughout the application. It manages
/// the lifecycle of the DI container and provides convenient access methods.
library;

import 'package:flutter/material.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';

/// Application provider widget that provides DI access to child widgets.
///
/// This widget should wrap the entire application to provide access to
/// the dependency injection container. It manages the container lifecycle
/// and provides convenient methods for service access.
///
/// Example usage:
/// ```dart
/// ApplicationProvider(
///   child: MaterialApp(
///     home: MyHomePage(),
///   ),
/// )
/// ```
class ApplicationProvider extends InheritedWidget {
  /// The DI container instance.
  final DIContainer container;

  /// The application bootstrap instance.
  final ApplicationBootstrap bootstrap;

  const ApplicationProvider({
    super.key,
    required this.container,
    required this.bootstrap,
    required super.child,
  });

  /// Get the ApplicationProvider from the widget tree.
  ///
  /// Throws an exception if ApplicationProvider is not found in the tree.
  static ApplicationProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ApplicationProvider>();
    if (provider == null) {
      throw Exception(
        'ApplicationProvider not found in widget tree. '
        'Make sure to wrap your app with ApplicationProvider.',
      );
    }
    return provider;
  }

  /// Get the ApplicationProvider from the widget tree, returning null if not found.
  static ApplicationProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ApplicationProvider>();
  }

  /// Get a service from the DI container.
  ///
  /// Example usage:
  /// ```dart
  /// final authService = ApplicationProvider.of(context).get<AuthService>();
  /// ```
  T get<T extends Object>() => container.get<T>();

  /// Check if a service is registered in the DI container.
  bool isRegistered<T extends Object>() => container.isRegistered<T>();

  /// Get the current health status of all services.
  Future<Map<String, dynamic>> getHealthStatus() async {
    final healthReport = await container.checkHealth();
    return {
      'is_healthy': healthReport.isHealthy,
      'healthy_count': healthReport.healthyCount,
      'total_count': healthReport.totalCount,
      'unhealthy_services': healthReport.unhealthyServices.map((s) => s.serviceName).toList(),
      'bootstrap_initialized': bootstrap.isInitialized,
      'container_initialized': container.isInitialized,
    };
  }

  /// Whether the application is fully initialized and ready.
  bool get isReady => bootstrap.isInitialized && container.isInitialized;

  @override
  bool updateShouldNotify(ApplicationProvider oldWidget) {
    // Notify if the container instance changes
    return container != oldWidget.container || bootstrap != oldWidget.bootstrap;
  }
}

/// Extension methods for convenient service access from BuildContext.
extension ApplicationProviderExtension on BuildContext {
  /// Get a service from the DI container.
  ///
  /// Shorthand for `ApplicationProvider.of(context).get<T>()`.
  ///
  /// Example usage:
  /// ```dart
  /// final authService = context.get<AuthService>();
  /// ```
  T get<T extends Object>() => ApplicationProvider.of(this).get<T>();

  /// Check if a service is registered in the DI container.
  ///
  /// Shorthand for `ApplicationProvider.of(context).isRegistered<T>()`.
  bool isServiceRegistered<T extends Object>() => 
      ApplicationProvider.of(this).isRegistered<T>();

  /// Get the application health status.
  ///
  /// Shorthand for `ApplicationProvider.of(context).getHealthStatus()`.
  Future<Map<String, dynamic>> getAppHealthStatus() => 
      ApplicationProvider.of(this).getHealthStatus();

  /// Whether the application is fully initialized and ready.
  bool get isAppReady => ApplicationProvider.of(this).isReady;
}

/// Widget that builds its child only when the application is ready.
///
/// Shows a loading widget while the application is initializing, then
/// builds the child widget once initialization is complete.
class ApplicationReadyBuilder extends StatelessWidget {
  /// The widget to build when the application is ready.
  final Widget child;

  /// The widget to build while the application is initializing.
  final Widget? loadingWidget;

  /// Callback called when the application becomes ready.
  final VoidCallback? onReady;

  const ApplicationReadyBuilder({
    super.key,
    required this.child,
    this.loadingWidget,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final provider = ApplicationProvider.maybeOf(context);
    
    if (provider == null) {
      // No provider found - return error widget
      return _buildErrorWidget('ApplicationProvider not found');
    }

    if (!provider.isReady) {
      // Application not ready - show loading
      return loadingWidget ?? _buildDefaultLoadingWidget();
    }

    // Application ready - call callback if provided
    if (onReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady!());
    }

    return child;
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Initializing application...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Application Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Service locator helper for accessing services outside of the widget tree.
///
/// This provides a global way to access services when you don't have access
/// to a BuildContext. Should be used sparingly - prefer the widget-based
/// approach when possible.
class ServiceLocator {
  static DIContainer? _container;

  /// Initialize the service locator with a DI container.
  static void initialize(DIContainer container) {
    _container = container;
  }

  /// Get a service from the global container.
  ///
  /// Throws an exception if the service locator is not initialized or
  /// the service is not registered.
  static T get<T extends Object>() {
    if (_container == null) {
      throw Exception(
        'ServiceLocator not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _container!.get<T>();
  }

  /// Check if a service is registered.
  static bool isRegistered<T extends Object>() {
    if (_container == null) return false;
    return _container!.isRegistered<T>();
  }

  /// Reset the service locator (for testing).
  static void reset() {
    _container = null;
  }

  /// Whether the service locator is initialized.
  static bool get isInitialized => _container != null;
}