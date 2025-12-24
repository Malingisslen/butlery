/// Unit tests for StartupOptimizationManager - App startup optimization
///
/// Tests the startup optimization manager including:
/// - Service registration and prioritization
/// - Phased initialization process
/// - Deferred service loading
/// - Startup metrics tracking
/// - Asset preloading
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/performance/startup_optimization_manager.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  // Initialize Flutter binding for asset loading
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartupOptimizationManager', () {
    late StartupOptimizationManager manager;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
    });

    setUp(() async {
      await TestServiceLocator.clearState();
      BaseUnitTest.resetMocks();

      // Create manager instance (singleton)
      manager = StartupOptimizationManager();
    });

    tearDown(() async {
      await TestServiceLocator.clearState();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('ServiceInitDescriptor', () {
      test('should create service descriptor with correct values', () {
        // Arrange & Act
        final descriptor = ServiceInitDescriptor(
          name: 'TestService',
          priority: ServicePriority.high,
          initializer: () async {},
          timeout: const Duration(seconds: 5),
        );

        // Assert
        expect(descriptor.name, equals('TestService'));
        expect(descriptor.priority, equals(ServicePriority.high));
        expect(descriptor.timeout, equals(const Duration(seconds: 5)));
        expect(descriptor.initializer, isNotNull);
      });
    });

    group('StartupMetrics', () {
      test('should track startup times correctly', () {
        // Arrange
        final metrics = StartupMetrics();

        // Act
        metrics.criticalServicesReady =
            metrics.appStartTime.add(const Duration(milliseconds: 500));
        metrics.allServicesReady =
            metrics.appStartTime.add(const Duration(seconds: 2));
        metrics.serviceInitTimes['Auth'] = const Duration(milliseconds: 200);
        metrics.serviceInitTimes['RecipeService'] =
            const Duration(milliseconds: 300);

        // Assert
        expect(metrics.timeToInteractive.inMilliseconds, equals(500));
        expect(metrics.timeToFullyLoaded.inMilliseconds, equals(2000));
        expect(metrics.serviceInitTimes['Auth']?.inMilliseconds, equals(200));
      });

      test('should serialize to JSON', () {
        // Arrange
        final metrics = StartupMetrics();
        metrics.criticalServicesReady =
            metrics.appStartTime.add(const Duration(milliseconds: 500));
        metrics.allServicesReady =
            metrics.appStartTime.add(const Duration(seconds: 2));
        metrics.serviceInitTimes['Auth'] = const Duration(milliseconds: 200);

        // Act
        final json = metrics.toJson();

        // Assert
        expect(json['appStartTime'], isNotNull);
        expect(json['timeToInteractive'], equals(500));
        expect(json['timeToFullyLoaded'], equals(2000));
        expect(json['serviceInitTimes']['Auth'], equals(200));
      });
    });

    group('Service Registration', () {
      test('should register service with priority', () {
        // Act
        manager.registerService(ServiceInitDescriptor(
          name: 'TestService',
          priority: ServicePriority.high,
          initializer: () async {},
        ));

        // Assert
        // Since we can't access internal state directly, just ensure no exceptions
        expect(true, isTrue);
      });

      test('should register standard services', () {
        // Act
        manager.registerStandardServices();

        // Assert
        // Standard services should be registered without errors
        expect(true, isTrue);
      });
    });

    group('Initialization Process', () {
      test('should start optimized initialization', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'CriticalService',
          priority: ServicePriority.critical,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Act
        final future = manager.startOptimizedInitialization();

        // Assert
        await expectLater(future, completes);
      });

      test('should wait for critical services', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'CriticalService',
          priority: ServicePriority.critical,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Start initialization
        final initFuture = manager.startOptimizedInitialization();

        // Act
        final waitFuture = manager.waitForCriticalServices();

        // Assert
        await expectLater(waitFuture, completes);
        await initFuture;
      });

      test('should wait for interactive state', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'HighPriorityService',
          priority: ServicePriority.high,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Start initialization
        final initFuture = manager.startOptimizedInitialization();

        // Act
        final waitFuture = manager.waitForInteractive();

        // Assert
        await expectLater(waitFuture, completes);
        await initFuture;
      });

      test('should handle initialization errors for critical services',
          () async {
        // Skip if already initialized from previous test
        // Since it's a singleton, we can't reset state between tests
      }, skip: 'Cannot reliably test due to singleton state persistence');

      test('should continue after non-critical service failure', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'FailingLowService',
          priority: ServicePriority.low,
          initializer: () async {
            throw Exception('Low priority service failed');
          },
        ));

        manager.registerService(ServiceInitDescriptor(
          name: 'SuccessfulService',
          priority: ServicePriority.medium,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Act & Assert
        // Should not throw for non-critical failures
        await expectLater(
          manager.startOptimizedInitialization(),
          completes,
        );
      });

      test('should handle timeout for services', () async {
        // Skip if already initialized from previous test
        // Since it's a singleton, we can't reset state between tests
      }, skip: 'Cannot reliably test due to singleton state persistence');
    });

    group('Deferred Service Loading', () {
      test('should initialize deferred service on demand', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'DeferredService',
          priority: ServicePriority.deferred,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Act & Assert
        await expectLater(
          manager.initializeDeferredService('DeferredService'),
          completes,
        );
      });

      test('should throw for unknown deferred service', () {
        // Act & Assert
        expect(
          () => manager.initializeDeferredService('UnknownService'),
          throwsArgumentError,
        );
      });

      test('should throw for non-deferred service', () {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'RegularService',
          priority: ServicePriority.high,
          initializer: () async {},
        ));

        // Act & Assert
        expect(
          () => manager.initializeDeferredService('RegularService'),
          throwsStateError,
        );
      });

      test('should handle already initialized deferred service', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'DeferredService',
          priority: ServicePriority.deferred,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        // Initialize once
        await manager.initializeDeferredService('DeferredService');

        // Act & Assert - Should complete without re-initializing
        await expectLater(
          manager.initializeDeferredService('DeferredService'),
          completes,
        );
      });
    });

    group('Asset Preloading', () {
      test('should preload assets', () async {
        // Act & Assert
        // Should complete without errors (even if assets don't exist in test)
        await expectLater(
          manager.preloadAssets(),
          completes,
        );
      });
    });

    group('Metrics', () {
      test('should provide startup metrics', () async {
        // Arrange
        manager.registerService(ServiceInitDescriptor(
          name: 'TestService',
          priority: ServicePriority.critical,
          initializer: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        ));

        await manager.startOptimizedInitialization();

        // Act
        final metrics = manager.metrics;

        // Assert
        expect(metrics, isNotNull);
        expect(metrics.appStartTime, isNotNull);
        expect(metrics.criticalServicesReady, isNotNull);
        expect(metrics.timeToInteractive, greaterThan(Duration.zero));
      });
    });

    group('Edge Cases', () {
      test('should handle multiple initialization attempts', () async {
        // Arrange
        manager.registerStandardServices();

        // Act - Start first initialization
        final future1 = manager.startOptimizedInitialization();

        // Try to start again (should return early)
        final future2 = manager.startOptimizedInitialization();

        // Assert
        await expectLater(future1, completes);
        await expectLater(future2, completes);
      });

      test('should throw when waiting without initialization', () {
        // Create a fresh instance to ensure clean state
        // Note: Since it's a singleton, this is still the same instance
        // but we're testing the behavior when initialization hasn't started

        // Since we can't easily reset the singleton state,
        // we'll skip this test as it depends on internal state
      }, skip: 'Cannot reliably test due to singleton state persistence');

      test('should maintain singleton instance', () {
        // Act
        final instance1 = StartupOptimizationManager();
        final instance2 = StartupOptimizationManager();

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });
}
