/// Comprehensive performance monitoring service for tracking app performance metrics.
/// This service provides real-time performance monitoring and reporting for:
/// - Frame rendering performance
/// - Network request timing
/// - Cache hit rates
/// - Memory usage
/// - User interaction responsiveness
/// - Custom performance markers

import 'dart:async';
import 'dart:collection';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';

/// Performance metric types
enum MetricType {
  frameTime,
  networkRequest,
  cacheHit,
  memoryUsage,
  userInteraction,
  custom,
}

/// Performance metric data
class PerformanceMetric {
  final MetricType type;
  final String name;
  final double value;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.type,
    required this.name,
    required this.value,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? clock.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'value': value,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Performance threshold configuration
class PerformanceThresholds {
  final Duration maxFrameTime;
  final Duration maxNetworkTime;
  final double minCacheHitRate;
  final int maxMemoryMB;
  final Duration maxInteractionTime;

  const PerformanceThresholds({
    this.maxFrameTime = const Duration(milliseconds: 16), // 60 FPS
    this.maxNetworkTime = const Duration(seconds: 3),
    this.minCacheHitRate = 0.8, // 80% hit rate
    this.maxMemoryMB = 200,
    this.maxInteractionTime = const Duration(milliseconds: 100),
  });
}

/// Performance report summary
class PerformanceReport {
  final DateTime startTime;
  final DateTime endTime;
  final Map<MetricType, List<PerformanceMetric>> metrics;
  final Map<String, dynamic> summary;
  final List<String> warnings;

  PerformanceReport({
    required this.startTime,
    required this.endTime,
    required this.metrics,
    required this.summary,
    required this.warnings,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'duration': duration.inSeconds,
    'metrics': metrics.map(
      (k, v) => MapEntry(k.name, v.map((m) => m.toJson()).toList()),
    ),
    'summary': summary,
    'warnings': warnings,
  };
}

/// Performance monitoring service
class PerformanceMonitoringService extends BaseService {
  @override
  String get serviceName => 'PerformanceMonitoringService';

  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  // Configuration
  final PerformanceThresholds _thresholds = const PerformanceThresholds();
  final int _maxMetricsPerType = 1000;
  final Duration _reportInterval = const Duration(minutes: 5);

  // State
  final Map<MetricType, Queue<PerformanceMetric>> _metrics = {
    for (var type in MetricType.values) type: Queue<PerformanceMetric>(),
  };

  final Map<String, Stopwatch> _activeTimers = {};
  final List<String> _warnings = [];

  DateTime _sessionStartTime = clock.now();
  Timer? _reportTimer;
  bool _isMonitoring = false;

  // Frame tracking
  int _frameCount = 0;
  int _droppedFrames = 0;
  Duration _totalFrameTime = Duration.zero;

  // Network tracking
  int _networkRequestCount = 0;
  Duration _totalNetworkTime = Duration.zero;

  // Cache tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Initialize performance monitoring
  @override
  Future<void> onInitialize() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _sessionStartTime = clock.now();

    // Start frame monitoring
    _startFrameMonitoring();

    // Start periodic reporting
    _startPeriodicReporting();
  }

  /// Start monitoring frame rendering performance
  void _startFrameMonitoring() {
    if (!kReleaseMode) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
  }

  /// Handle frame timing callbacks
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameCount++;

      final buildDuration = timing.buildDuration;
      final rasterDuration = timing.rasterDuration;
      final totalDuration = buildDuration + rasterDuration;

      _totalFrameTime += totalDuration;

      // Check if frame was dropped (took longer than 16ms)
      if (totalDuration > _thresholds.maxFrameTime) {
        _droppedFrames++;

        recordMetric(
          PerformanceMetric(
            type: MetricType.frameTime,
            name: 'dropped_frame',
            value: totalDuration.inMicroseconds / 1000.0, // Convert to ms
            metadata: {
              'buildTime': buildDuration.inMicroseconds / 1000.0,
              'rasterTime': rasterDuration.inMicroseconds / 1000.0,
            },
          ),
        );

        if (totalDuration.inMilliseconds > 50) {
          _addWarning('Severe frame drop: ${totalDuration.inMilliseconds}ms');
        }
      }
    }
  }

  /// Record a performance metric
  void recordMetric(PerformanceMetric metric) {
    final queue = _metrics[metric.type]!;

    // Maintain queue size limit
    if (queue.length >= _maxMetricsPerType) {
      queue.removeFirst();
    }

    queue.add(metric);

    // Check thresholds
    _checkThresholds(metric);
  }

  /// Start a performance timer
  void startTimer(String name) {
    _activeTimers[name] = Stopwatch()..start();
  }

  /// Stop a timer and record the duration
  void stopTimer(
    String name, {
    MetricType type = MetricType.custom,
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = _activeTimers.remove(name);

    if (stopwatch == null) {
      AppLogger.warning('Timer not found: $name');
      return;
    }

    stopwatch.stop();

    recordMetric(
      PerformanceMetric(
        type: type,
        name: name,
        value: stopwatch.elapsedMilliseconds.toDouble(),
        metadata: metadata,
      ),
    );
  }

  /// Record a network request
  void recordNetworkRequest(
    String url,
    Duration duration, {
    int? statusCode,
    int? byteSize,
  }) {
    _networkRequestCount++;
    _totalNetworkTime += duration;

    recordMetric(
      PerformanceMetric(
        type: MetricType.networkRequest,
        name: 'network_request',
        value: duration.inMilliseconds.toDouble(),
        metadata: {
          'url': url,
          'statusCode': statusCode,
          'byteSize': byteSize,
        },
      ),
    );

    if (duration > _thresholds.maxNetworkTime) {
      _addWarning('Slow network request: $url (${duration.inSeconds}s)');
    }
  }

  /// Record a cache access
  void recordCacheAccess(bool hit, {String? key, int? size}) {
    if (hit) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }

    recordMetric(
      PerformanceMetric(
        type: MetricType.cacheHit,
        name: hit ? 'cache_hit' : 'cache_miss',
        value: hit ? 1.0 : 0.0,
        metadata: {
          'key': key,
          'size': size,
        },
      ),
    );
  }

  /// Record memory usage
  void recordMemoryUsage(int usedMB, int totalMB) {
    recordMetric(
      PerformanceMetric(
        type: MetricType.memoryUsage,
        name: 'memory_usage',
        value: usedMB.toDouble(),
        metadata: {
          'totalMB': totalMB,
          'percentUsed': (usedMB / totalMB * 100).toStringAsFixed(1),
        },
      ),
    );

    if (usedMB > _thresholds.maxMemoryMB) {
      _addWarning('High memory usage: ${usedMB}MB');
    }
  }

  /// Record user interaction timing
  void recordUserInteraction(String interaction, Duration responseTime) {
    recordMetric(
      PerformanceMetric(
        type: MetricType.userInteraction,
        name: interaction,
        value: responseTime.inMilliseconds.toDouble(),
      ),
    );

    if (responseTime > _thresholds.maxInteractionTime) {
      _addWarning(
        'Slow interaction response: $interaction (${responseTime.inMilliseconds}ms)',
      );
    }
  }

  /// Check metric against thresholds
  void _checkThresholds(PerformanceMetric metric) {
    // Threshold checking logic is implemented in individual record methods
  }

  /// Add a performance warning
  void _addWarning(String warning) {
    _warnings.add('[${clock.now().toIso8601String()}] $warning');
    AppLogger.warning('Performance: $warning');

    // Keep warnings list manageable
    if (_warnings.length > 100) {
      _warnings.removeAt(0);
    }
  }

  /// Start periodic performance reporting
  void _startPeriodicReporting() {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      final report = generateReport();
      _sendReport(report);
    });
  }

  /// Generate a performance report
  PerformanceReport generateReport() {
    final now = clock.now();
    final avgFrameTime = _frameCount > 0
        ? _totalFrameTime.inMicroseconds /
              _frameCount /
              1000.0 // ms
        : 0.0;

    final frameRate = _frameCount > 0
        ? (1000.0 / avgFrameTime).toStringAsFixed(1)
        : '0.0';

    final cacheHitRate = (_cacheHits + _cacheMisses) > 0
        ? _cacheHits / (_cacheHits + _cacheMisses)
        : 0.0;

    final avgNetworkTime = _networkRequestCount > 0
        ? _totalNetworkTime.inMilliseconds / _networkRequestCount
        : 0.0;

    final summary = {
      'frameRate': frameRate,
      'droppedFrames': _droppedFrames,
      'droppedFramePercent': _frameCount > 0
          ? (_droppedFrames / _frameCount * 100).toStringAsFixed(1)
          : '0.0',
      'avgFrameTime': avgFrameTime.toStringAsFixed(2),
      'networkRequests': _networkRequestCount,
      'avgNetworkTime': avgNetworkTime.toStringAsFixed(0),
      'cacheHitRate': (cacheHitRate * 100).toStringAsFixed(1),
      'totalCacheAccesses': _cacheHits + _cacheMisses,
    };

    // Check performance health
    if (cacheHitRate < _thresholds.minCacheHitRate) {
      _addWarning(
        'Low cache hit rate: ${(cacheHitRate * 100).toStringAsFixed(1)}%',
      );
    }

    return PerformanceReport(
      startTime: _sessionStartTime,
      endTime: now,
      metrics: _metrics.map((k, v) => MapEntry(k, v.toList())),
      summary: summary,
      warnings: List.from(_warnings),
    );
  }

  /// Send performance report to analytics
  void _sendReport(PerformanceReport report) {
    try {
      final analytics = FirebaseAnalytics.instance;

      // Log key metrics
      analytics.logEvent(
        name: AnalyticsEvents.performanceReport,
        parameters: {
          'frame_rate': report.summary['frameRate'],
          'dropped_frames': report.summary['droppedFrames'],
          'cache_hit_rate': report.summary['cacheHitRate'],
          'network_requests': report.summary['networkRequests'],
          'session_duration': report.duration.inSeconds,
        },
      );

      // Log warnings if any
      if (report.warnings.isNotEmpty) {
        analytics.logEvent(
          name: AnalyticsEvents.performanceWarnings,
          parameters: {
            'warning_count': report.warnings.length,
            'latest_warning': report.warnings.last,
          },
        );
      }

      AppLogger.info('📊 Performance report sent to analytics');
    } catch (e) {
      AppLogger.error('Failed to send performance report: $e');
    }
  }

  /// Get current performance summary
  Map<String, dynamic> getCurrentSummary() {
    final report = generateReport();
    return report.summary;
  }

  /// Clear all metrics
  void clearMetrics() {
    for (final queue in _metrics.values) {
      queue.clear();
    }

    _frameCount = 0;
    _droppedFrames = 0;
    _totalFrameTime = Duration.zero;
    _networkRequestCount = 0;
    _totalNetworkTime = Duration.zero;
    _cacheHits = 0;
    _cacheMisses = 0;
    _warnings.clear();

    AppLogger.info('Performance metrics cleared');
  }

  /// Stop performance monitoring
  @override
  Future<void> onDispose() async {
    _reportTimer?.cancel();

    // Only remove callback if monitoring was started
    if (_isMonitoring && !kReleaseMode) {
      try {
        SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
      } catch (e) {
        // Callback might not have been added, ignore
      }
    }

    _isMonitoring = false;
  }
}

/// Extension for easy performance tracking
extension PerformanceTracking on PerformanceMonitoringService {
  /// Track async operation performance
  Future<T> trackAsync<T>(
    String name,
    Future<T> Function() operation, {
    MetricType type = MetricType.custom,
  }) async {
    startTimer(name);

    try {
      final result = await operation();
      stopTimer(name, type: type);
      return result;
    } catch (e) {
      stopTimer(name, type: type, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  /// Track sync operation performance
  T trackSync<T>(
    String name,
    T Function() operation, {
    MetricType type = MetricType.custom,
  }) {
    startTimer(name);

    try {
      final result = operation();
      stopTimer(name, type: type);
      return result;
    } catch (e) {
      stopTimer(name, type: type, metadata: {'error': e.toString()});
      rethrow;
    }
  }
}
