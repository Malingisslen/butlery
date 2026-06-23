// lib/services/monitoring/app_monitoring_service.dart

import 'package:clock/clock.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Application monitoring service for alerting and observability.
///
/// Integrates with Firebase Crashlytics and Performance to provide:
/// - Error tracking with severity levels
/// - Custom metrics for business KPIs
/// - Performance traces for critical paths
/// - Health check status for uptime monitoring
///
/// Usage:
/// ```dart
/// final monitoring = ServiceLocator.get<AppMonitoringService>();
/// monitoring.recordBusinessMetric('recipe_created', value: 1);
/// monitoring.recordError('api_error', error, StackTrace.current, severity: ErrorSeverity.warning);
/// ```
class AppMonitoringService {
  final FirebaseCrashlytics _crashlytics;
  final FirebasePerformance _performance;

  final Map<String, Trace> _activeTraces = {};
  final Map<String, int> _metricCounters = {};

  AppMonitoringService({
    FirebaseCrashlytics? crashlytics,
    FirebasePerformance? performance,
  }) : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance,
       _performance = performance ?? FirebasePerformance.instance;

  /// Record a business metric for monitoring dashboards.
  ///
  /// Metrics are logged to Crashlytics custom keys and can be used
  /// in GCP Cloud Monitoring custom metrics dashboards.
  void recordBusinessMetric(String name, {int value = 1}) {
    if (kIsWeb) return; // Crashlytics not available on web

    try {
      _metricCounters[name] = (_metricCounters[name] ?? 0) + value;
      _crashlytics.setCustomKey('metric_$name', _metricCounters[name]!);

      AppLogger.debug(
        'Recorded metric: $name = $value (total: ${_metricCounters[name]})',
      );
    } catch (e) {
      AppLogger.warning('Failed to record metric $name: $e');
    }
  }

  /// Record an error with severity for alerting.
  ///
  /// Severity levels:
  /// - [ErrorSeverity.info]: Logged but no alert
  /// - [ErrorSeverity.warning]: Logged with warning flag, may trigger alert if threshold exceeded
  /// - [ErrorSeverity.error]: Logged as non-fatal error, triggers alert
  /// - [ErrorSeverity.critical]: Logged as fatal error, immediate alert
  void recordError(
    String category,
    dynamic error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, String>? metadata,
  }) {
    if (kIsWeb) return; // Crashlytics not available on web

    try {
      // Set error metadata
      _crashlytics.setCustomKey('error_category', category);
      _crashlytics.setCustomKey('error_severity', severity.name);

      if (metadata != null) {
        for (final entry in metadata.entries) {
          _crashlytics.setCustomKey('error_${entry.key}', entry.value);
        }
      }

      // Determine if this is a fatal error
      final isFatal = severity == ErrorSeverity.critical;

      // Record the error (async; absorb platform-channel failures so they
      // don't escape the sync try/catch as unhandled errors).
      _crashlytics
          .recordError(
            error,
            stackTrace ?? StackTrace.current,
            reason: '$category (${severity.name})',
            fatal: isFatal,
          )
          .catchError((_) {});

      // Increment error counter
      _metricCounters['error_count'] =
          (_metricCounters['error_count'] ?? 0) + 1;
      _metricCounters['error_$category'] =
          (_metricCounters['error_$category'] ?? 0) + 1;

      AppLogger.debug('Recorded error: $category (${severity.name})');
    } catch (e) {
      AppLogger.warning('Failed to record error $category: $e');
    }
  }

  /// Start a performance trace for a critical operation.
  ///
  /// Returns a trace ID that must be passed to [stopTrace].
  /// Traces are automatically reported to Firebase Performance.
  Future<String> startTrace(String name) async {
    try {
      final trace = _performance.newTrace(name);
      await trace.start();

      final traceId = '${name}_${DateTime.now().millisecondsSinceEpoch}';
      _activeTraces[traceId] = trace;

      return traceId;
    } catch (e) {
      AppLogger.warning('Failed to start trace $name: $e');
      return '';
    }
  }

  /// Stop a performance trace and report metrics.
  Future<void> stopTrace(String traceId, {Map<String, int>? metrics}) async {
    try {
      final trace = _activeTraces.remove(traceId);
      if (trace == null) {
        AppLogger.warning('Trace $traceId not found');
        return;
      }

      // Add custom metrics to the trace
      if (metrics != null) {
        for (final entry in metrics.entries) {
          trace.setMetric(entry.key, entry.value);
        }
      }

      await trace.stop();
    } catch (e) {
      AppLogger.warning('Failed to stop trace $traceId: $e');
    }
  }

  /// Record a custom attribute for the current session.
  ///
  /// Useful for segmenting crash reports and performance data.
  void setUserProperty(String key, String value) {
    if (kIsWeb) return;

    try {
      _crashlytics.setCustomKey(key, value).catchError((_) {});
    } catch (e) {
      AppLogger.warning('Failed to set user property $key: $e');
    }
  }

  /// Get current health status for monitoring endpoints.
  HealthStatus getHealthStatus() {
    return HealthStatus(
      isHealthy: true,
      errorCount: _metricCounters['error_count'] ?? 0,
      metrics: Map.from(_metricCounters),
      timestamp: clock.now(),
    );
  }

  /// Log a breadcrumb for debugging crash reports.
  void logBreadcrumb(String message, {Map<String, String>? data}) {
    if (kIsWeb) return;

    try {
      final dataString = data != null
          ? data.entries.map((e) => '${e.key}=${e.value}').join(', ')
          : '';
      _crashlytics
          .log('$message ${dataString.isNotEmpty ? "[$dataString]" : ""}')
          .catchError((_) {});
    } catch (e) {
      AppLogger.warning('Failed to log breadcrumb: $e');
    }
  }

  /// Clear all active traces (for cleanup on logout/reset).
  Future<void> clearTraces() async {
    for (final trace in _activeTraces.values) {
      try {
        await trace.stop();
      } catch (e) {
        AppLogger.warning('Failed to stop performance trace: $e');
      }
    }
    _activeTraces.clear();
  }
}

/// Error severity levels for alerting thresholds.
enum ErrorSeverity {
  /// Informational - logged but no alert
  info,

  /// Warning - may trigger alert if threshold exceeded
  warning,

  /// Error - triggers alert notification
  error,

  /// Critical - immediate alert and potential page
  critical,
}

/// Health status for monitoring endpoints.
class HealthStatus {
  final bool isHealthy;
  final int errorCount;
  final Map<String, int> metrics;
  final DateTime timestamp;

  const HealthStatus({
    required this.isHealthy,
    required this.errorCount,
    required this.metrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'healthy': isHealthy,
    'error_count': errorCount,
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
  };
}
