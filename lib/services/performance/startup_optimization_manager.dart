/// Startup optimization manager for reducing app launch time.
/// This service implements lazy loading and deferred initialization strategies
/// to minimize the time from app launch to first meaningful paint.
/// Features:
/// - Service priority-based initialization
/// - Lazy loading of non-critical services
/// - Splash screen preloading
/// - Background initialization queue
/// - Startup performance metrics

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service initialization priority levels
enum ServicePriority {
  critical, // Must be loaded before app can function (auth, permissions)
  high, // Needed for initial screen (recipe service for main view)
  medium, // Enhances UX but not immediately needed
  low, // Can be loaded in background
  deferred, // Load only when first accessed
}

/// Service initialization descriptor
class ServiceInitDescriptor {
  final String name;
  final ServicePriority priority;
  final Future<void> Function() initializer;
  final Duration? timeout;

  const ServiceInitDescriptor({
    required this.name,
    required this.priority,
    required this.initializer,
    this.timeout,
  });
}

/// Startup metrics for performance monitoring
class StartupMetrics {
  final DateTime appStartTime;
  DateTime? criticalServicesReady;
  DateTime? highPriorityReady;
  DateTime? allServicesReady;
  final Map<String, Duration> serviceInitTimes = {};

  StartupMetrics() : appStartTime = DateTime.now();

  Duration get timeToInteractive =>
      criticalServicesReady?.difference(appStartTime) ?? Duration.zero;

  Duration get timeToFullyLoaded =>
      allServicesReady?.difference(appStartTime) ?? Duration.zero;

  Map<String, dynamic> toJson() => {
        'appStartTime': appStartTime.toIso8601String(),
        'timeToInteractive': timeToInteractive.inMilliseconds,
        'timeToFullyLoaded': timeToFullyLoaded.inMilliseconds,
        'serviceInitTimes': serviceInitTimes.map(
          (k, v) => MapEntry(k, v.inMilliseconds),
        ),
      };
}

/// Startup optimization manager
class StartupOptimizationManager {
  static final StartupOptimizationManager _instance =
      StartupOptimizationManager._internal();
  factory StartupOptimizationManager() => _instance;
  StartupOptimizationManager._internal();

  // State
  final StartupMetrics _metrics = StartupMetrics();
  final Map<String, ServiceInitDescriptor> _services = {};
  final Set<String> _initializedServices = {};
  final Map<ServicePriority, List<ServiceInitDescriptor>> _priorityQueues = {
    ServicePriority.critical: [],
    ServicePriority.high: [],
    ServicePriority.medium: [],
    ServicePriority.low: [],
    ServicePriority.deferred: [],
  };

  bool _isInitializing = false;
  Completer<void>? _criticalServicesCompleter;
  Completer<void>? _interactiveCompleter;

  /// Register a service for initialization
  void registerService(ServiceInitDescriptor service) {
    _services[service.name] = service;
    _priorityQueues[service.priority]!.add(service);

    AppLogger.debug(
        'Registered service ${service.name} with priority ${service.priority}');
  }

  /// Register standard app services with appropriate priorities
  void registerStandardServices() {
    // Critical services - needed before anything else
    registerService(ServiceInitDescriptor(
      name: 'Firebase',
      priority: ServicePriority.critical,
      initializer: _initializeFirebase,
      timeout: const Duration(seconds: 10),
    ));

    registerService(ServiceInitDescriptor(
      name: 'Authentication',
      priority: ServicePriority.critical,
      initializer: _initializeAuth,
      timeout: const Duration(seconds: 5),
    ));

    registerService(ServiceInitDescriptor(
      name: 'Permissions',
      priority: ServicePriority.critical,
      initializer: _initializePermissions,
    ));

    // High priority - needed for initial screen
    registerService(ServiceInitDescriptor(
      name: 'RecipeService',
      priority: ServicePriority.high,
      initializer: _initializeRecipeService,
    ));

    registerService(ServiceInitDescriptor(
      name: 'LocalCache',
      priority: ServicePriority.high,
      initializer: _initializeLocalCache,
    ));

    // Medium priority - enhance UX
    registerService(ServiceInitDescriptor(
      name: 'IntelligentCache',
      priority: ServicePriority.medium,
      initializer: _initializeIntelligentCache,
    ));

    registerService(ServiceInitDescriptor(
      name: 'ImageOptimization',
      priority: ServicePriority.medium,
      initializer: _initializeImageOptimization,
    ));

    // Low priority - background features
    registerService(ServiceInitDescriptor(
      name: 'Analytics',
      priority: ServicePriority.low,
      initializer: _initializeAnalytics,
    ));

    registerService(ServiceInitDescriptor(
      name: 'NotificationService',
      priority: ServicePriority.low,
      initializer: _initializeNotifications,
    ));

    // Deferred - load only when needed
    registerService(ServiceInitDescriptor(
      name: 'SocialFeatures',
      priority: ServicePriority.deferred,
      initializer: _initializeSocialFeatures,
    ));

    registerService(ServiceInitDescriptor(
      name: 'RealtimeSync',
      priority: ServicePriority.deferred,
      initializer: _initializeRealtimeSync,
    ));
  }

  /// Start the optimized initialization process
  Future<void> startOptimizedInitialization() async {
    if (_isInitializing) {
      AppLogger.warning('Initialization already in progress');
      return;
    }

    _isInitializing = true;
    _criticalServicesCompleter = Completer<void>();
    _interactiveCompleter = Completer<void>();

    AppLogger.info('🚀 Starting optimized app initialization...');

    try {
      // Phase 1: Critical services (blocking)
      await _initializePriority(ServicePriority.critical);
      _metrics.criticalServicesReady = DateTime.now();
      _criticalServicesCompleter!.complete();

      AppLogger.success(
          '✅ Critical services ready in ${_metrics.timeToInteractive.inMilliseconds}ms');

      // Phase 2: High priority services (blocking for interactive)
      await _initializePriority(ServicePriority.high);
      _metrics.highPriorityReady = DateTime.now();
      _interactiveCompleter!.complete();

      AppLogger.success(
          '✅ App interactive in ${_metrics.highPriorityReady!.difference(_metrics.appStartTime).inMilliseconds}ms');

      // Phase 3: Medium and low priority (non-blocking background)
      _initializeInBackground();
    } catch (e) {
      AppLogger.error('❌ Startup initialization failed: $e');
      _criticalServicesCompleter?.completeError(e);
      _interactiveCompleter?.completeError(e);
      rethrow;
    }
  }

  /// Wait for critical services to be ready
  Future<void> waitForCriticalServices() async {
    if (_criticalServicesCompleter == null) {
      throw StateError('Initialization not started');
    }

    await _criticalServicesCompleter!.future;
  }

  /// Wait for app to be interactive
  Future<void> waitForInteractive() async {
    if (_interactiveCompleter == null) {
      throw StateError('Initialization not started');
    }

    await _interactiveCompleter!.future;
  }

  /// Initialize services of a specific priority
  Future<void> _initializePriority(ServicePriority priority) async {
    final services = _priorityQueues[priority] ?? [];

    if (services.isEmpty) return;

    AppLogger.info(
        'Initializing ${services.length} ${priority.name} priority services...');

    // Initialize in parallel where possible
    final futures = <Future>[];

    for (final service in services) {
      futures.add(_initializeService(service));
    }

    await Future.wait(futures);
  }

  /// Initialize background services
  void _initializeInBackground() {
    Future.microtask(() async {
      try {
        // Medium priority
        await _initializePriority(ServicePriority.medium);

        // Low priority
        await _initializePriority(ServicePriority.low);

        _metrics.allServicesReady = DateTime.now();

        AppLogger.success(
            '✅ All services initialized in ${_metrics.timeToFullyLoaded.inMilliseconds}ms');

        // Log detailed metrics
        _logStartupMetrics();
      } catch (e) {
        AppLogger.error('Background initialization failed: $e');
      }
    });
  }

  /// Initialize a single service
  Future<void> _initializeService(ServiceInitDescriptor service) async {
    if (_initializedServices.contains(service.name)) {
      return; // Already initialized
    }

    final startTime = DateTime.now();

    try {
      AppLogger.debug('Initializing ${service.name}...');

      if (service.timeout != null) {
        await service.initializer().timeout(
          service.timeout!,
          onTimeout: () {
            throw TimeoutException('${service.name} initialization timed out');
          },
        );
      } else {
        await service.initializer();
      }

      final duration = DateTime.now().difference(startTime);
      _metrics.serviceInitTimes[service.name] = duration;
      _initializedServices.add(service.name);

      AppLogger.debug(
          '✓ ${service.name} initialized in ${duration.inMilliseconds}ms');
    } catch (e) {
      AppLogger.error('Failed to initialize ${service.name}: $e');

      // Critical services must succeed
      if (service.priority == ServicePriority.critical) {
        rethrow;
      }
    }
  }

  /// Initialize a deferred service on demand
  Future<void> initializeDeferredService(String serviceName) async {
    final service = _services[serviceName];

    if (service == null) {
      throw ArgumentError('Unknown service: $serviceName');
    }

    if (service.priority != ServicePriority.deferred) {
      throw StateError('Service $serviceName is not deferred');
    }

    if (_initializedServices.contains(serviceName)) {
      return; // Already initialized
    }

    AppLogger.info('Loading deferred service: $serviceName');

    await _initializeService(service);
  }

  /// Preload critical assets during splash screen
  Future<void> preloadAssets() async {
    try {
      AppLogger.info('Preloading critical assets...');

      // Preload fonts
      await _preloadFonts();

      // Preload critical images
      await _preloadImages();

      // Warm up shaders
      await _warmUpShaders();

      AppLogger.success('✅ Assets preloaded');
    } catch (e) {
      AppLogger.error('Asset preloading failed: $e');
    }
  }

  Future<void> _preloadFonts() async {
    // Load custom fonts if any
  }

  Future<void> _preloadImages() async {
    // Preload app logo, common icons, etc.
    final images = [
      'assets/images/logo.png',
      'assets/images/placeholder.png',
    ];

    for (final image in images) {
      try {
        await rootBundle.load(image);
      } catch (e) {
        AppLogger.debug('Failed to preload image $image: $e');
      }
    }
  }

  Future<void> _warmUpShaders() async {
    // Shader warm-up primarily benefits iOS with Impeller renderer
    // Android uses Skia which handles shader compilation differently
    if (!Platform.isIOS) return;

    try {
      AppLogger.debug('Warming up shaders for iOS...');

      // Create off-screen picture recorder to compile common shaders
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final paint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      // Warm up rounded rectangle shader (cards, buttons, chips)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 50),
          const Radius.circular(AppDimensions.borderRadiusM),
        ),
        paint,
      );

      // Warm up shadow shader (elevation, Material surfaces)
      canvas.drawShadow(
        Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100)),
        Colors.black,
        4.0,
        false,
      );

      // Warm up gradient shader (app bar, buttons, decorations)
      paint.shader = const LinearGradient(
        colors: [Colors.blue, Colors.purple],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);

      // Warm up circle shader (avatars, FAB, icons)
      paint.shader = null;
      paint.color = Colors.green;
      canvas.drawCircle(const Offset(50, 50), 25, paint);

      // Warm up border shader (outlined buttons, text fields)
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 40),
          const Radius.circular(AppDimensions.borderRadius20),
        ),
        paint,
      );

      // Complete recording and render to trigger shader compilation
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      image.dispose();
      picture.dispose();

      AppLogger.debug('Shader warm-up complete');
    } catch (e) {
      // Non-critical - app will still work, just with potential first-frame jank
      AppLogger.debug('Shader warm-up failed (non-critical): $e');
    }
  }

  /// Log detailed startup metrics
  void _logStartupMetrics() {
    AppLogger.info('📊 Startup Metrics:');
    AppLogger.info(
        '  Time to interactive: ${_metrics.timeToInteractive.inMilliseconds}ms');
    AppLogger.info(
        '  Time to fully loaded: ${_metrics.timeToFullyLoaded.inMilliseconds}ms');

    AppLogger.info('  Service initialization times:');
    _metrics.serviceInitTimes.forEach((name, duration) {
      AppLogger.info('    $name: ${duration.inMilliseconds}ms');
    });
  }

  /// Get startup metrics
  StartupMetrics get metrics => _metrics;

  // Service initializers (these would be implemented based on actual services)

  Future<void> _initializeFirebase() async {
    // Simulate Firebase initialization
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _initializeAuth() async {
    // Initialize authentication
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _initializePermissions() async {
    // Initialize permission service
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _initializeRecipeService() async {
    // Initialize recipe service
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _initializeLocalCache() async {
    // Initialize Hive cache
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _initializeIntelligentCache() async {
    // Initialize intelligent cache manager
    await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _initializeImageOptimization() async {
    // Initialize image optimization
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _initializeAnalytics() async {
    // Initialize analytics
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _initializeNotifications() async {
    // Initialize notifications
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _initializeSocialFeatures() async {
    // Initialize social features
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _initializeRealtimeSync() async {
    // Initialize realtime sync
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
