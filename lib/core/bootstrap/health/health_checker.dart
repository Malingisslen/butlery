/// Health monitoring system for the application bootstrap process.
///
/// This file provides centralized health checking capabilities for
/// monitoring the application's initialization and ongoing health.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/utils/logger.dart';

/// Centralized health checker for the application.
///
/// Provides comprehensive health monitoring capabilities including:
/// - Service health validation
/// - Module health checking  
/// - Startup validation
/// - Ongoing health monitoring
class ApplicationHealthChecker {
  static final ApplicationHealthChecker _instance = ApplicationHealthChecker._internal();
  factory ApplicationHealthChecker() => _instance;
  ApplicationHealthChecker._internal();

  final DIContainer _container = DIContainer();
  DateTime? _lastHealthCheck;
  HealthReport? _lastHealthReport;

  /// Get the last health check time.
  DateTime? get lastHealthCheck => _lastHealthCheck;

  /// Get the last health report.
  HealthReport? get lastHealthReport => _lastHealthReport;

  /// Perform a comprehensive health check of the entire application.
  ///
  /// This includes checking:
  /// - All registered services
  /// - Module health status
  /// - Critical system components
  ///
  /// Returns a detailed health report.
  Future<HealthReport> performHealthCheck() async {
    if (kDebugMode) {
      AppLogger.debug('🔍 Performing comprehensive health check...');
    }

    try {
      _lastHealthCheck = DateTime.now();

      // Check DI container health
      final healthReport = await _container.checkHealth();
      _lastHealthReport = healthReport;

      if (kDebugMode) {
        AppLogger.debug('${healthReport.isHealthy ? '✅' : '❌'} Health check complete: ${healthReport.healthyCount}/${healthReport.totalCount} services healthy');
        
        if (!healthReport.isHealthy) {
          for (final unhealthy in healthReport.unhealthyServices) {
            AppLogger.error('  ❌ ${unhealthy.serviceName}: ${unhealthy.message}');
          }
        }
      }

      return healthReport;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('❌ Health check failed', e);
      }
      
      final errorReport = HealthReport([
        HealthCheckResult.unhealthy(
          'ApplicationHealthChecker',
          message: 'Health check failed: $e',
        ),
      ]);
      
      _lastHealthReport = errorReport;
      return errorReport;
    }
  }

  /// Check if the application is ready to serve requests.
  ///
  /// Performs a quick readiness check to determine if the application
  /// has completed initialization and is ready for use.
  Future<bool> isApplicationReady() async {
    try {
      // Check if DI container is initialized
      if (!_container.isInitialized) {
        return false;
      }

      // Perform a lightweight health check
      final healthReport = await performHealthCheck();
      
      // Consider the app ready if most services are healthy
      // Allow for some services to be temporarily unhealthy
      final healthyPercentage = healthReport.healthyCount / healthReport.totalCount;
      return healthyPercentage >= 0.8; // 80% of services must be healthy
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('❌ Readiness check failed', e);
      }
      return false;
    }
  }

  /// Wait for the application to become ready.
  ///
  /// Polls the application readiness status until it becomes ready
  /// or the timeout is reached.
  ///
  /// [timeout] Maximum time to wait for readiness
  /// [checkInterval] How often to check readiness status
  Future<bool> waitForApplicationReady({
    Duration timeout = const Duration(seconds: 30),
    Duration checkInterval = const Duration(milliseconds: 500),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      if (await isApplicationReady()) {
        if (kDebugMode) {
          AppLogger.success('✅ Application ready after ${stopwatch.elapsed.inSeconds}s');
        }
        return true;
      }
      
      await Future.delayed(checkInterval);
    }

    if (kDebugMode) {
      AppLogger.warning('⏰ Application readiness timeout after ${timeout.inSeconds}s');
    }
    return false;
  }

  /// Check health with a timeout.
  ///
  /// Useful for preventing health checks from hanging during startup.
  Future<HealthReport> performHealthCheckWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await performHealthCheck().timeout(timeout);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('⏰ Health check timed out: $e');
      }
      
      return HealthReport([
        HealthCheckResult.unhealthy(
          'ApplicationHealthChecker',
          message: 'Health check timed out: $e',
        ),
      ]);
    }
  }

  /// Get a summary of the application's health status.
  Map<String, dynamic> getHealthSummary() {
    final report = _lastHealthReport;
    
    return {
      'last_check': _lastHealthCheck?.toIso8601String(),
      'is_healthy': report?.isHealthy ?? false,
      'healthy_count': report?.healthyCount ?? 0,
      'total_count': report?.totalCount ?? 0,
      'unhealthy_services': report?.unhealthyServices.map((s) => s.serviceName).toList() ?? [],
      'container_initialized': _container.isInitialized,
    };
  }

  /// Start background health monitoring.
  ///
  /// Performs periodic health checks to monitor application health
  /// over time. Useful for detecting degradation in production.
  void startBackgroundMonitoring({
    Duration interval = const Duration(minutes: 5),
  }) {
    if (kDebugMode) {
      AppLogger.debug('🔄 Starting background health monitoring (interval: ${interval.inMinutes}m)');
    }

    // Schedule periodic health checks
    Timer.periodic(interval, (timer) async {
      try {
        await performHealthCheckWithTimeout();
      } catch (e) {
        if (kDebugMode) {
          AppLogger.warning('⚠️ Background health check failed: $e');
        }
      }
    });
  }
}