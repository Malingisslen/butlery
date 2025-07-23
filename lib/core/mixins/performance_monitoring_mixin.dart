/// 🔍 AI INFO BLOCK:
/// Component: Performance Monitoring Mixin - Mixin for service performance monitoring
/// File: lib/core/mixins/performance_monitoring_mixin.dart
/// Quick Guide: Provides performance monitoring capabilities to services
/// Dependencies IN: ServiceOptimizer, Logger
/// Dependencies OUT: Mixed into service classes
/// Data flow: Service operations -> Performance monitoring -> Metrics collection
/// State management: Tracks performance metrics per service
/// Purpose: Standardize performance monitoring across services
/// Common issues: Memory overhead, metric accuracy, cleanup
/// Test coverage: Unit tests for monitoring functionality
/// Performance: Minimal overhead monitoring
/// Analytics: Service performance metrics, bottleneck identification
/// Code smells: None - focused monitoring mixin
/// Connected to: ServiceOptimizer, all service classes
/// Used in phases: Phase 7 - Service Optimization

import 'dart:async';
import '../utils/service_optimizer.dart';
import '../utils/logger.dart';

/// Mixin for adding performance monitoring to services
/// 
/// Provides standardized performance monitoring capabilities:
/// - Operation timing and tracking
/// - Error rate monitoring
/// - Resource usage tracking
/// - Health check capabilities
mixin PerformanceMonitoringMixin {
  final ServiceOptimizer _optimizer = ServiceOptimizer();
  
  /// Service name for monitoring (override in implementing class)
  String get serviceName => runtimeType.toString();
  
  /// Whether performance monitoring is enabled
  bool get isMonitoringEnabled => true;

  // ===== MONITORED OPERATIONS =====

  /// Execute operation with performance monitoring
  Future<T> monitored<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration? timeout,
    int? maxRetries,
    bool useCircuitBreaker = false,
  }) async {
    if (!isMonitoringEnabled) {
      return await operation();
    }

    try {
      // Choose execution strategy based on parameters
      if (maxRetries != null && maxRetries > 1) {
        return await _optimizer.executeWithRetry(
          operationName: operationName,
          operation: operation,
          maxRetries: maxRetries,
          serviceName: serviceName,
        );
      } else if (useCircuitBreaker) {
        return await _optimizer.executeWithCircuitBreaker(
          operationName: operationName,
          operation: operation,
          serviceName: serviceName,
        );
      } else {
        return await _optimizer.executeWithMonitoring(
          operationName: operationName,
          operation: operation,
          timeoutDuration: timeout,
          serviceName: serviceName,
        );
      }
    } catch (e, stackTrace) {
      _optimizer.handleError(
        context: operationName,
        error: e,
        stackTrace: stackTrace,
        serviceName: serviceName,
      );
      rethrow;
    }
  }

  /// Execute batch operations with monitoring
  Future<List<T>> monitoredBatch<T>(
    Map<String, Future<T> Function()> operations, {
    bool stopOnFirstError = false,
  }) async {
    if (!isMonitoringEnabled) {
      final results = <T>[];
      for (final operation in operations.values) {
        try {
          results.add(await operation());
        } catch (e) {
          if (stopOnFirstError) rethrow;
        }
      }
      return results;
    }

    return await monitored(
      'batch_${operations.keys.join('_')}',
      () async {
        final futures = operations.values.map((op) => op()).toList();
        return stopOnFirstError 
            ? await Future.wait(futures)
            : await _waitAllSettled(futures);
      },
    );
  }

  // ===== HEALTH MONITORING =====

  /// Get performance statistics for this service
  Map<String, dynamic> getServicePerformanceStats() {
    final stats = <String, dynamic>{
      'serviceName': serviceName,
      'isMonitoringEnabled': isMonitoringEnabled,
      'operations': <Map<String, dynamic>>[],
    };

    // Get stats for all operations of this service
    // This would be enhanced to filter by service name prefix
    final healthMetrics = _optimizer.getServiceHealthMetrics();
    stats.addAll(healthMetrics);

    return stats;
  }

  /// Perform health check for this service
  Future<Map<String, dynamic>> performHealthCheck() async {
    return await monitored('health_check', () async {
      final healthCheck = <String, dynamic>{
        'serviceName': serviceName,
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'checks': <String, dynamic>{},
      };

      try {
        // Override in implementing class to add specific health checks
        final specificChecks = await performServiceSpecificHealthChecks();
        healthCheck['checks'].addAll(specificChecks);

        // Determine overall status
        final hasFailures = specificChecks.values.any((check) => 
            check is Map && check['status'] != 'healthy');
        
        healthCheck['status'] = hasFailures ? 'degraded' : 'healthy';
      } catch (e) {
        healthCheck['status'] = 'unhealthy';
        healthCheck['error'] = e.toString();
      }

      return healthCheck;
    });
  }

  /// Override in implementing class to add service-specific health checks
  Future<Map<String, dynamic>> performServiceSpecificHealthChecks() async {
    return {
      'basic': {
        'status': 'healthy',
        'description': 'Basic service availability',
      },
    };
  }

  // ===== RESOURCE MONITORING =====

  /// Track resource usage for an operation
  Future<T> withResourceTracking<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final startTime = DateTime.now();
    
    try {
      final result = await operation();
      final duration = DateTime.now().difference(startTime);
      
      if (duration > Duration(seconds: 1)) {
        AppLogger.info('⏱️ Resource-intensive operation: $serviceName.$operationName took ${duration.inMilliseconds}ms');
      }
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.warning('❌ Failed resource-intensive operation: $serviceName.$operationName (${duration.inMilliseconds}ms)');
      rethrow;
    }
  }

  /// Monitor memory-intensive operations
  Future<T> withMemoryTracking<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    // In a real implementation, this could track actual memory usage
    AppLogger.debug('🧠 Starting memory-intensive operation: $serviceName.$operationName');
    
    try {
      final result = await operation();
      AppLogger.debug('✅ Completed memory-intensive operation: $serviceName.$operationName');
      return result;
    } catch (e) {
      AppLogger.warning('❌ Failed memory-intensive operation: $serviceName.$operationName');
      rethrow;
    }
  }

  // ===== CLEANUP AND MAINTENANCE =====

  /// Cleanup old monitoring data
  void cleanupMonitoringData() {
    if (isMonitoringEnabled) {
      _optimizer.cleanupOldData();
      AppLogger.info('🧹 Cleaned up monitoring data for $serviceName');
    }
  }

  /// Dispose monitoring resources
  void disposeMonitoring() {
    if (isMonitoringEnabled) {
      cleanupMonitoringData();
      AppLogger.debug('🗑️ Disposed monitoring for $serviceName');
    }
  }

  // ===== PRIVATE HELPERS =====

  /// Wait for all futures to settle (don't fail on first error)
  Future<List<T>> _waitAllSettled<T>(List<Future<T>> futures) async {
    final results = <T>[];
    
    for (final future in futures) {
      try {
        results.add(await future);
      } catch (e) {
        AppLogger.warning('Batch operation failed: $e');
        // Continue with other operations
      }
    }
    
    return results;
  }
}

/// Enhanced performance monitoring for critical services
mixin CriticalServiceMonitoringMixin on PerformanceMonitoringMixin {
  @override
  bool get isMonitoringEnabled => true; // Always enabled for critical services

  /// Critical operation with enhanced monitoring
  Future<T> criticalOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await monitored(
      operationName,
      operation,
      timeout: timeout,
      maxRetries: 3,
      useCircuitBreaker: true,
    );
  }

  /// Alert on performance degradation
  void checkPerformanceDegradation() {
    final stats = getServicePerformanceStats();
    final errorRate = double.tryParse(stats['errorRate'] ?? '0') ?? 0.0;
    final avgResponseTime = stats['averageResponseTime'] as int? ?? 0;

    if (errorRate > 5.0) {
      AppLogger.error('🚨 High error rate detected in $serviceName: ${errorRate.toStringAsFixed(2)}%');
    }

    if (avgResponseTime > 2000) {
      AppLogger.warning('⚠️ High response time detected in $serviceName: ${avgResponseTime}ms');
    }
  }

  @override
  Future<Map<String, dynamic>> performServiceSpecificHealthChecks() async {
    final checks = await super.performServiceSpecificHealthChecks();
    
    // Add critical service specific checks
    final stats = getServicePerformanceStats();
    final errorRate = double.tryParse(stats['errorRate'] ?? '0') ?? 0.0;
    
    checks['errorRate'] = {
      'status': errorRate < 5.0 ? 'healthy' : 'degraded',
      'value': errorRate,
      'threshold': 5.0,
      'unit': '%',
    };

    checks['responseTime'] = {
      'status': (stats['averageResponseTime'] as int? ?? 0) < 2000 ? 'healthy' : 'degraded',
      'value': stats['averageResponseTime'],
      'threshold': 2000,
      'unit': 'ms',
    };

    return checks;
  }
}