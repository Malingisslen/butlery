/// Service health checking interfaces for the modular DI system.
/// This file defines interfaces and utilities for monitoring the health
/// of services within the dependency injection system. Health checks are
/// used during startup validation and ongoing monitoring.
library;

/// Interface for services that support health checking.
/// Services can implement this interface to provide custom health
/// validation logic beyond simple instantiation checks.

import 'package:clock/clock.dart';

abstract class HealthCheckable {
  /// Perform a health check on this service.
  /// Returns `true` if the service is healthy and ready for use.
  /// Should perform minimal validation to avoid performance impact.
  /// Example implementations:
  /// - Database connection: verify connection is active
  /// - Auth service: verify token is valid
  /// - Cache service: verify cache is accessible
  Future<bool> healthCheck();

  /// Get a human-readable health status description.
  /// Used for debugging and monitoring dashboards.
  /// Should be brief but informative.
  String get healthStatus;
}

/// Health check result containing status and diagnostic information.
class HealthCheckResult {
  final bool isHealthy;
  final String serviceName;
  final String? message;
  final DateTime checkedAt;
  final Duration? responseTime;

  HealthCheckResult({
    required this.isHealthy,
    required this.serviceName,
    this.message,
    DateTime? checkedAt,
    this.responseTime,
  }) : checkedAt = checkedAt ?? clock.now();

  /// Create a healthy result.
  factory HealthCheckResult.healthy(
    String serviceName, {
    String? message,
    Duration? responseTime,
  }) {
    return HealthCheckResult(
      isHealthy: true,
      serviceName: serviceName,
      message: message,
      responseTime: responseTime,
    );
  }

  /// Create an unhealthy result.
  factory HealthCheckResult.unhealthy(
    String serviceName, {
    String? message,
    Duration? responseTime,
  }) {
    return HealthCheckResult(
      isHealthy: false,
      serviceName: serviceName,
      message: message,
      responseTime: responseTime,
    );
  }

  @override
  String toString() {
    final status = isHealthy ? '✅ HEALTHY' : '❌ UNHEALTHY';
    final time =
        responseTime != null ? ' (${responseTime!.inMilliseconds}ms)' : '';
    final msg = message != null ? ': $message' : '';
    return '$status $serviceName$time$msg';
  }
}

/// Aggregated health check results for multiple services.
class HealthReport {
  final List<HealthCheckResult> results;
  final DateTime generatedAt;

  HealthReport(this.results) : generatedAt = clock.now();

  /// Whether all services are healthy.
  bool get isHealthy => results.every((result) => result.isHealthy);

  /// Number of healthy services.
  int get healthyCount => results.where((result) => result.isHealthy).length;

  /// Number of unhealthy services.
  int get unhealthyCount => results.length - healthyCount;

  /// Total number of services checked.
  int get totalCount => results.length;

  /// Get unhealthy services.
  List<HealthCheckResult> get unhealthyServices =>
      results.where((result) => !result.isHealthy).toList();

  /// Get summary statistics.
  Map<String, dynamic> get summary => {
        'healthy': healthyCount,
        'unhealthy': unhealthyCount,
        'total': totalCount,
        'overall_status': isHealthy ? 'HEALTHY' : 'UNHEALTHY',
        'generated_at': generatedAt.toIso8601String(),
      };

  @override
  String toString() {
    final status = isHealthy ? '✅ ALL HEALTHY' : '❌ ISSUES DETECTED';
    return '$status ($healthyCount/$totalCount services healthy)';
  }
}

/// Utility class for performing health checks on services.
class HealthChecker {
  /// Check health of a single service.
  /// If the service implements [HealthCheckable], uses its custom health check.
  /// Otherwise, performs basic instantiation check.
  static Future<HealthCheckResult> checkService(
    String serviceName,
    dynamic service,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (service is HealthCheckable) {
        final isHealthy = await service.healthCheck();
        stopwatch.stop();

        return HealthCheckResult(
          isHealthy: isHealthy,
          serviceName: serviceName,
          message:
              isHealthy ? service.healthStatus : 'Custom health check failed',
          responseTime: stopwatch.elapsed,
        );
      } else {
        // Basic check - service exists and is not null
        final isHealthy = service != null;
        stopwatch.stop();

        return HealthCheckResult(
          isHealthy: isHealthy,
          serviceName: serviceName,
          message: isHealthy ? 'Service instantiated' : 'Service is null',
          responseTime: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult.unhealthy(
        serviceName,
        message: 'Health check failed: $e',
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// Check health of multiple services.
  /// Performs health checks in parallel for better performance.
  static Future<HealthReport> checkServices(
    Map<String, dynamic> services,
  ) async {
    final futures = services.entries
        .map((entry) => checkService(entry.key, entry.value))
        .toList();

    final results = await Future.wait(futures);
    return HealthReport(results);
  }

  /// Check health with timeout.
  /// Useful for preventing health checks from hanging the application.
  static Future<HealthCheckResult> checkServiceWithTimeout(
    String serviceName,
    dynamic service, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      return await checkService(serviceName, service).timeout(timeout);
    } catch (e) {
      return HealthCheckResult.unhealthy(
        serviceName,
        message: 'Health check timed out: $e',
      );
    }
  }
}
