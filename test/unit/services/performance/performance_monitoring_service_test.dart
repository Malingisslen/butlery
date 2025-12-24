/// Unit tests for PerformanceMonitoringService - Comprehensive performance monitoring
///
/// Tests the performance monitoring service including:
/// - Performance metric recording and tracking
/// - Timer management for performance measurements
/// - Threshold monitoring and warnings
/// - Report generation and analytics
/// - Frame monitoring and cache tracking
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/performance/performance_monitoring_service.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  // Initialize Flutter binding for SchedulerBinding access
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PerformanceMonitoringService', () {
    late PerformanceMonitoringService service;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
    });

    setUp(() async {
      await TestServiceLocator.clearState();
      BaseUnitTest.resetMocks();

      // Create service instance (singleton)
      service = PerformanceMonitoringService();
      service.clearMetrics(); // Ensure clean state
    });

    tearDown(() async {
      service.clearMetrics();
      // Don't dispose service in tearDown since it's a singleton
      // and dispose may fail if not initialized
      await TestServiceLocator.clearState();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('PerformanceMetric', () {
      test('should create metric with correct values', () {
        // Arrange & Act
        final metric = PerformanceMetric(
          type: MetricType.networkRequest,
          name: 'api_call',
          value: 150.5,
          metadata: {'url': '/api/recipes'},
        );

        // Assert
        expect(metric.type, equals(MetricType.networkRequest));
        expect(metric.name, equals('api_call'));
        expect(metric.value, equals(150.5));
        expect(metric.metadata?['url'], equals('/api/recipes'));
        expect(metric.timestamp, isNotNull);
      });

      test('should serialize to JSON correctly', () {
        // Arrange
        final metric = PerformanceMetric(
          type: MetricType.cacheHit,
          name: 'recipe_cache',
          value: 1.0,
          metadata: {'key': 'recipe_123'},
        );

        // Act
        final json = metric.toJson();

        // Assert
        expect(json['type'], equals('cacheHit'));
        expect(json['name'], equals('recipe_cache'));
        expect(json['value'], equals(1.0));
        expect(json['metadata']['key'], equals('recipe_123'));
        expect(json['timestamp'], isNotNull);
      });
    });

    group('PerformanceThresholds', () {
      test('should have correct default values', () {
        // Arrange & Act
        const thresholds = PerformanceThresholds();

        // Assert
        expect(thresholds.maxFrameTime.inMilliseconds, equals(16)); // 60 FPS
        expect(thresholds.maxNetworkTime.inSeconds, equals(3));
        expect(thresholds.minCacheHitRate, equals(0.8));
        expect(thresholds.maxMemoryMB, equals(200));
        expect(thresholds.maxInteractionTime.inMilliseconds, equals(100));
      });

      test('should allow custom threshold values', () {
        // Arrange & Act
        const thresholds = PerformanceThresholds(
          maxFrameTime: Duration(milliseconds: 33), // 30 FPS
          maxNetworkTime: Duration(seconds: 5),
          minCacheHitRate: 0.9,
          maxMemoryMB: 300,
          maxInteractionTime: Duration(milliseconds: 200),
        );

        // Assert
        expect(thresholds.maxFrameTime.inMilliseconds, equals(33));
        expect(thresholds.maxNetworkTime.inSeconds, equals(5));
        expect(thresholds.minCacheHitRate, equals(0.9));
        expect(thresholds.maxMemoryMB, equals(300));
        expect(thresholds.maxInteractionTime.inMilliseconds, equals(200));
      });
    });

    group('Initialization', () {
      test('should initialize service successfully', () {
        // Act
        service.initialize();

        // Assert
        // Since we can't easily access internal state, just ensure no exceptions
        expect(true, isTrue);
      });

      test('should handle multiple initialization calls', () {
        // Act
        service.initialize();
        service.initialize(); // Should not cause issues

        // Assert
        expect(true, isTrue);
      });
    });

    group('Metric Recording', () {
      test('should record performance metrics', () {
        // Arrange
        final metric = PerformanceMetric(
          type: MetricType.custom,
          name: 'test_operation',
          value: 42.0,
        );

        // Act
        service.recordMetric(metric);

        // Assert
        // Verify through report generation
        final report = service.generateReport();
        expect(report.metrics[MetricType.custom], isNotEmpty);
      });

      test('should maintain queue size limit', () {
        // Act - Record more than max metrics (1000)
        for (int i = 0; i < 1100; i++) {
          service.recordMetric(PerformanceMetric(
            type: MetricType.custom,
            name: 'metric_$i',
            value: i.toDouble(),
          ));
        }

        // Assert
        final report = service.generateReport();
        expect(
            report.metrics[MetricType.custom]!.length, lessThanOrEqualTo(1000));
      });
    });

    group('Timer Management', () {
      test('should start and stop timers correctly', () async {
        // Act
        service.startTimer('test_timer');
        await Future.delayed(const Duration(milliseconds: 50));
        service.stopTimer('test_timer');

        // Assert
        final report = service.generateReport();
        final metrics = report.metrics[MetricType.custom] ?? [];
        final timerMetric = metrics.firstWhere(
          (m) => m.name == 'test_timer',
          orElse: () => throw Exception('Timer metric not found'),
        );

        expect(timerMetric.value,
            greaterThanOrEqualTo(45.0)); // Allow some variance
        expect(
            timerMetric.value, lessThan(200.0)); // Allow more variance for CI
      });

      test('should handle stopping non-existent timer', () {
        // Act & Assert
        // Should not throw
        service.stopTimer('non_existent_timer');
      });

      test('should support custom metadata for timers', () {
        // Act
        service.startTimer('api_call');
        service.stopTimer(
          'api_call',
          type: MetricType.networkRequest,
          metadata: {'endpoint': '/api/recipes'},
        );

        // Assert
        final report = service.generateReport();
        final metrics = report.metrics[MetricType.networkRequest] ?? [];
        final apiMetric = metrics.firstWhere(
          (m) => m.name == 'api_call',
          orElse: () => throw Exception('API metric not found'),
        );

        expect(apiMetric.metadata?['endpoint'], equals('/api/recipes'));
      });
    });

    group('Network Request Tracking', () {
      test('should record network request metrics', () {
        // Act
        service.recordNetworkRequest(
          'https://api.example.com/recipes',
          const Duration(milliseconds: 500),
          statusCode: 200,
          byteSize: 1024,
        );

        // Assert
        final report = service.generateReport();
        expect(report.summary['networkRequests'], equals(1));
        expect(report.summary['avgNetworkTime'], equals('500'));
      });

      test('should generate warning for slow requests', () {
        // Act
        service.recordNetworkRequest(
          'https://api.example.com/slow',
          const Duration(seconds: 4), // Exceeds 3s threshold
        );

        // Assert
        final report = service.generateReport();
        expect(report.warnings, isNotEmpty);
        // Check that slow network warning exists in the warnings list
        expect(report.warnings.any((w) => w.contains('Slow network request')),
            isTrue);
      });
    });

    group('Cache Tracking', () {
      test('should track cache hits and misses', () {
        // Act
        service.recordCacheAccess(true, key: 'recipe_1');
        service.recordCacheAccess(true, key: 'recipe_2');
        service.recordCacheAccess(false, key: 'recipe_3');

        // Assert
        final report = service.generateReport();
        expect(report.summary['cacheHitRate'], equals('66.7')); // 2/3 = 66.7%
        expect(report.summary['totalCacheAccesses'], equals(3));
      });

      test('should generate warning for low cache hit rate', () {
        // Act - Create low hit rate (below 80% threshold)
        for (int i = 0; i < 10; i++) {
          service.recordCacheAccess(i < 3); // 30% hit rate
        }

        // Assert
        final report = service.generateReport();
        expect(report.warnings, isNotEmpty);
        expect(report.warnings.last, contains('Low cache hit rate'));
      });
    });

    group('Memory Usage Tracking', () {
      test('should record memory usage metrics', () {
        // Act
        service.recordMemoryUsage(150, 500);

        // Assert
        final report = service.generateReport();
        final metrics = report.metrics[MetricType.memoryUsage] ?? [];
        expect(metrics, isNotEmpty);

        final memoryMetric = metrics.last;
        expect(memoryMetric.value, equals(150.0));
        expect(memoryMetric.metadata?['totalMB'], equals(500));
        expect(memoryMetric.metadata?['percentUsed'], equals('30.0'));
      });

      test('should generate warning for high memory usage', () {
        // Act
        service.recordMemoryUsage(250, 300); // Exceeds 200MB threshold

        // Assert
        final report = service.generateReport();
        expect(report.warnings, isNotEmpty);
        expect(report.warnings.any((w) => w.contains('High memory usage')),
            isTrue);
      });
    });

    group('User Interaction Tracking', () {
      test('should record user interaction timing', () {
        // Act
        service.recordUserInteraction(
          'button_tap',
          const Duration(milliseconds: 50),
        );

        // Assert
        final report = service.generateReport();
        final metrics = report.metrics[MetricType.userInteraction] ?? [];
        expect(metrics, isNotEmpty);
        expect(metrics.last.name, equals('button_tap'));
        expect(metrics.last.value, equals(50.0));
      });

      test('should generate warning for slow interactions', () {
        // Act
        service.recordUserInteraction(
          'heavy_operation',
          const Duration(milliseconds: 200), // Exceeds 100ms threshold
        );

        // Assert
        final report = service.generateReport();
        expect(report.warnings, isNotEmpty);
        expect(
            report.warnings.any((w) => w.contains('Slow interaction response')),
            isTrue);
      });
    });

    group('Report Generation', () {
      test('should generate comprehensive report', () {
        // Arrange
        service.recordNetworkRequest(
            'api/test', const Duration(milliseconds: 100));
        service.recordCacheAccess(true);
        service.recordCacheAccess(false);
        service.recordMemoryUsage(100, 200);

        // Act
        final report = service.generateReport();

        // Assert
        expect(report.startTime, isNotNull);
        expect(report.endTime, isNotNull);
        expect(report.duration, greaterThan(Duration.zero));
        expect(report.metrics, isNotEmpty);
        expect(report.summary, isNotEmpty);
        expect(report.summary['networkRequests'], equals(1));
        expect(report.summary['cacheHitRate'], equals('50.0'));
      });

      test('should serialize report to JSON', () {
        // Arrange
        service.recordNetworkRequest(
            'api/test', const Duration(milliseconds: 100));

        // Act
        final report = service.generateReport();
        final json = report.toJson();

        // Assert
        expect(json['startTime'], isNotNull);
        expect(json['endTime'], isNotNull);
        expect(json['duration'], isA<int>());
        expect(json['metrics'], isA<Map>());
        expect(json['summary'], isA<Map>());
        expect(json['warnings'], isA<List>());
      });
    });

    group('Performance Extensions', () {
      test('should track async operations', () async {
        // Act
        final result = await service.trackAsync(
          'async_operation',
          () async {
            await Future.delayed(const Duration(milliseconds: 50));
            return 'result';
          },
        );

        // Assert
        expect(result, equals('result'));

        final report = service.generateReport();
        final metrics = report.metrics[MetricType.custom] ?? [];
        final metric = metrics.firstWhere(
          (m) => m.name == 'async_operation',
          orElse: () => throw Exception('Async metric not found'),
        );

        expect(metric.value, greaterThanOrEqualTo(45.0)); // Allow some variance
      });

      test('should track sync operations', () {
        // Act
        final result = service.trackSync(
          'sync_operation',
          () => 42,
        );

        // Assert
        expect(result, equals(42));

        final report = service.generateReport();
        final metrics = report.metrics[MetricType.custom] ?? [];
        expect(metrics.any((m) => m.name == 'sync_operation'), isTrue);
      });

      test('should handle errors in tracked operations', () async {
        // Act & Assert
        try {
          await service.trackAsync(
            'failing_operation',
            () async => throw Exception('Test error'),
          );
        } catch (e) {
          // Expected exception
        }

        // Verify error was recorded
        final report = service.generateReport();
        final metrics = report.metrics[MetricType.custom] ?? [];

        // The metric should exist even though the operation failed
        expect(metrics.any((m) => m.name == 'failing_operation'), isTrue);

        final metric = metrics.firstWhere(
          (m) => m.name == 'failing_operation',
        );

        expect(metric.metadata?['error'], contains('Test error'));
      });
    });

    group('Current Summary', () {
      test('should provide current performance summary', () {
        // Arrange
        service.recordNetworkRequest(
            'api/test', const Duration(milliseconds: 100));
        service.recordCacheAccess(true);
        service.recordCacheAccess(true);
        service.recordCacheAccess(false);

        // Act
        final summary = service.getCurrentSummary();

        // Assert
        expect(summary['networkRequests'], equals(1));
        expect(summary['cacheHitRate'], equals('66.7'));
        expect(summary['frameRate'], isNotNull);
      });
    });

    group('Metric Clearing', () {
      test('should clear all metrics', () {
        // Arrange
        service.recordNetworkRequest(
            'api/test', const Duration(milliseconds: 100));
        service.recordCacheAccess(true);
        service.recordMemoryUsage(100, 200);

        // Act
        service.clearMetrics();

        // Assert
        final report = service.generateReport();
        expect(report.summary['networkRequests'], equals(0));
        expect(report.summary['totalCacheAccesses'], equals(0));
        // Note: warnings may be generated during report generation if thresholds are violated
        // The important thing is that the metrics themselves are cleared
      });
    });

    group('Edge Cases', () {
      test('should handle empty metrics gracefully', () {
        // Act
        final report = service.generateReport();

        // Assert
        expect(report.metrics, isNotEmpty); // Has empty queues for each type
        expect(report.summary['frameRate'], equals('0.0'));
        expect(report.summary['networkRequests'], equals(0));
        expect(report.summary['cacheHitRate'], equals('0.0'));
      });

      test('should handle disposal without initialization', () {
        // Act & Assert
        // Should not throw - using a fresh singleton instance
        expect(() => PerformanceMonitoringService().dispose(), returnsNormally);
      });

      test('should maintain singleton instance', () {
        // Act
        final instance1 = PerformanceMonitoringService();
        final instance2 = PerformanceMonitoringService();

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });
}
