/// Comprehensive application provider system implementing widget-friendly dependency injection access for Swedish cooking application UI.
/// This provider system serves as the foundational service access infrastructure throughout the Butlery application's UI layer,
/// wrapping the DI container with a clean, widget-friendly interface for accessing services while managing container lifecycle
/// and providing convenient access methods. It ensures reliable service availability across the widget tree while providing
/// comprehensive monitoring and error handling for Swedish cooking application's complex UI service dependencies, collaborative
/// features, and real-time synchronization requirements that demand proper service access and initialization state management.
/// ## Core Architecture Features
/// **Widget-Friendly Service Access**
/// - InheritedWidget-based service access with automatic dependency propagation through widget tree
/// - Context-based service resolution with convenient extension methods and type-safe access
/// - Application readiness management with loading states and initialization monitoring
/// - Error handling with graceful fallbacks and comprehensive error reporting mechanisms
/// **Comprehensive Lifecycle Management**
/// - Application initialization state tracking with progress monitoring and status reporting
/// - Service health monitoring integration with real-time status updates and alerting
/// - Container lifecycle management with proper cleanup and resource disposal
/// - Ready state management with conditional UI rendering and loading state handling
/// **Developer Experience Optimization**
/// - Extension methods for convenient service access from BuildContext instances
/// - Global service locator for non-widget contexts with proper error handling
/// - Application ready builder widget for conditional rendering based on initialization state
/// - Comprehensive error messages with helpful debugging information and recovery guidance
/// ## Usage Examples
/// **Basic Application Setup:**
/// ```dart
/// void main() async {
///   await ApplicationBootstrap.initialize();
///   runApp(
///     ApplicationProvider(
///       container: DIContainer(),
///       bootstrap: ApplicationBootstrap(),
///       child: MaterialApp(
///         home: ApplicationReadyBuilder(
///           child: MyHomePage(),
///           loadingWidget: SplashScreen(),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
/// **Service Access in Widgets:**
/// ```dart
/// class RecipeListWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     // Direct context extension usage
///     final recipeService = context.get<RecipeService>();
///     final authService = context.get<AuthService>();
///     // Check service availability
///     if (context.isServiceRegistered<NotificationService>()) {
///       final notificationService = context.get<NotificationService>();
///     }
///     return ListView.builder(
///       itemBuilder: (context, index) => RecipeCard(),
///     );
///   }
/// }
/// ```
/// **Health Monitoring Integration:**
/// ```dart
/// class HealthMonitoringWidget extends StatefulWidget {
///   @override
///   _HealthMonitoringWidgetState createState() => _HealthMonitoringWidgetState();
/// }
/// class _HealthMonitoringWidgetState extends State<HealthMonitoringWidget> {
///   Map<String, dynamic>? healthStatus;
///   @override
///   void initState() {
///     super.initState();
///     _checkHealth();
///   }
///   Future<void> _checkHealth() async {
///     final status = await context.getAppHealthStatus();
///     setState(() => healthStatus = status);
///   }
///   @override
///   Widget build(BuildContext context) {
///     return HealthStatusDisplay(status: healthStatus);
///   }
/// }
/// ```
/// **Global Service Access:**
/// ```dart
/// class BackgroundTaskManager {
///   static Future<void> performBackgroundSync() async {
///     // Access services outside widget tree
///     final syncService = ServiceLocator.get<SyncService>();
///     final dataService = ServiceLocator.get<DataService>();
///     await syncService.performSync();
///     await dataService.processOfflineChanges();
///   }
/// }
/// ```
/// ## Performance Characteristics
/// - **Service Access Efficiency**: Optimized service resolution with minimal widget tree traversal
/// - **Memory Management**: Proper InheritedWidget lifecycle with automatic cleanup and disposal
/// - **Health Monitoring**: Efficient health checking with minimal UI performance impact
/// - **Initialization Tracking**: Fast readiness checking with cached state and minimal overhead
/// ## Integration Patterns
/// - **Widget Tree**: Primary service provider for all UI components and widget-based service access
/// - **Application Lifecycle**: Integrates with bootstrap system for proper initialization sequencing
/// - **Service Resolution**: Provides centralized service access for all UI-driven operations
/// - **Health Monitoring**: Real-time service health integration for production monitoring and alerting
/// This application provider system is essential for reliable, convenient, and properly managed service
/// access throughout the Swedish cooking application's UI layer while providing comprehensive initialization
/// tracking and health monitoring for production-grade service availability and error handling.
library;

import 'package:flutter/material.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';

/// Comprehensive application provider widget that enables widget-friendly dependency injection access throughout the application.
/// This InheritedWidget wraps the entire application to provide clean, type-safe access to the dependency injection
/// container and application bootstrap system. It manages container lifecycle, tracks initialization state, and provides
/// convenient methods for service access across the widget tree with proper error handling.
/// **Key Features:**
/// - InheritedWidget-based service access with automatic dependency propagation through widget tree
/// - Application readiness tracking with initialization state monitoring and health validation
/// - Context-based service resolution with convenient extension methods and type-safe access
/// - Comprehensive error handling with helpful debugging information and recovery guidance
/// - Health monitoring integration with real-time service status and alerting capabilities
/// - Lifecycle management with proper cleanup and resource disposal mechanisms
/// **Integration Points:**
/// - Wraps the entire application providing service access to all child widgets
/// - Integrates with ApplicationBootstrap for initialization state tracking and monitoring
/// - Connects with DIContainer for service resolution and health validation
/// - Provides foundation for ApplicationReadyBuilder and other infrastructure widgets
/// **Example Usage:**
/// ```dart
/// // Application root setup
/// ApplicationProvider(
///   container: DIContainer(),
///   bootstrap: ApplicationBootstrap(),
///   child: MaterialApp(
///     home: ApplicationReadyBuilder(
///       child: MyHomePage(),
///       loadingWidget: SplashScreen(),
///     ),
///   ),
/// )
/// // Service access in widgets
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final authService = ApplicationProvider.of(context).get<AuthService>();
///     return ServiceAwareWidget(authService: authService);
///   }
/// }
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
  /// Throws an exception if ApplicationProvider is not found in the tree.
  static ApplicationProvider of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ApplicationProvider>();
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
      'unhealthy_services':
          healthReport.unhealthyServices.map((s) => s.serviceName).toList(),
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
  /// Shorthand for `ApplicationProvider.of(context).get<T>()`.
  /// Example usage:
  /// ```dart
  /// final authService = context.get<AuthService>();
  /// ```
  T get<T extends Object>() => ApplicationProvider.of(this).get<T>();

  /// Check if a service is registered in the DI container.
  /// Shorthand for `ApplicationProvider.of(context).isRegistered<T>()`.
  bool isServiceRegistered<T extends Object>() =>
      ApplicationProvider.of(this).isRegistered<T>();

  /// Get the application health status.
  /// Shorthand for `ApplicationProvider.of(context).getHealthStatus()`.
  Future<Map<String, dynamic>> getAppHealthStatus() =>
      ApplicationProvider.of(this).getHealthStatus();

  /// Whether the application is fully initialized and ready.
  bool get isAppReady => ApplicationProvider.of(this).isReady;
}

/// Widget that builds its child only when the application is ready.
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
      return _buildErrorWidget(context, 'ApplicationProvider not found');
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

  Widget _buildErrorWidget(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Application Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
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

  /// Try to get a service from the global container.
  /// Returns null if the service is not registered or container not initialized.
  static T? tryGet<T extends Object>() {
    if (_container == null) return null;
    try {
      return _container!.get<T>();
    } catch (e) {
      return null;
    }
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
