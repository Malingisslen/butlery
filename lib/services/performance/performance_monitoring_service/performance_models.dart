import 'package:clock/clock.dart';

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
