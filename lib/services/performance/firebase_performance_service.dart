// lib/services/performance/firebase_performance_service.dart

import 'package:firebase_performance/firebase_performance.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase Performance Monitoring Service
/// Provides centralized Firebase Performance monitoring for:
/// - Screen rendering traces
/// - Network request monitoring
/// - Custom performance traces
/// - Key user flow metrics
/// Usage:
/// ```dart
/// // Start a trace
/// final trace = await FirebasePerformanceService.startTrace('load_recipe');
/// // ... perform operation ...
/// await trace.stop();
/// // Monitor specific metric
/// trace.incrementMetric('recipe_count', 1);
/// trace.putAttribute('recipe_type', 'imported');
/// ```
class FirebasePerformanceService {
  static FirebasePerformance? _instance;

  /// Get Firebase Performance instance
  static FirebasePerformance get instance {
    _instance ??= FirebasePerformance.instance;
    return _instance!;
  }

  /// Whether performance monitoring is enabled
  static bool _isEnabled = true;

  /// Enable/disable performance monitoring
  static Future<void> setPerformanceCollectionEnabled(bool enabled) async {
    try {
      await instance.setPerformanceCollectionEnabled(enabled);
      _isEnabled = enabled;
      AppLogger.info(
        '🎯 Firebase Performance monitoring ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      AppLogger.error('Failed to set performance collection: $e');
    }
  }

  /// Start a custom trace
  static Future<Trace> startTrace(String traceName) async {
    if (!_isEnabled) {
      // Return a no-op trace if disabled
      return _NoOpTrace(traceName);
    }

    try {
      final trace = instance.newTrace(traceName);
      await trace.start();
      AppLogger.debug('🎯 Started trace: $traceName');
      return trace;
    } catch (e) {
      AppLogger.error('Failed to start trace $traceName: $e');
      return _NoOpTrace(traceName);
    }
  }

  /// Execute operation with automatic trace
  static Future<T> traceOperation<T>(
    String traceName,
    Future<T> Function(Trace trace) operation, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  }) async {
    final trace = await startTrace(traceName);

    try {
      // Add attributes
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }

      // Execute operation
      final result = await operation(trace);

      // Add metrics
      if (metrics != null) {
        for (final entry in metrics.entries) {
          trace.setMetric(entry.key, entry.value);
        }
      }

      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('error', e.toString());
      await trace.stop();
      rethrow;
    }
  }

  /// Trace recipe loading operation
  static Future<T> traceRecipeLoad<T>(
    Future<T> Function(Trace trace) operation, {
    String? recipeId,
    String? source,
  }) async {
    return await traceOperation(
      'recipe_load',
      operation,
      attributes: {
        if (recipeId != null) 'recipe_id': recipeId,
        if (source != null) 'source': source,
      },
    );
  }

  /// Trace search operation
  static Future<T> traceSearch<T>(
    Future<T> Function(Trace trace) operation, {
    String? searchType,
    int? resultCount,
  }) async {
    return await traceOperation(
      'search_operation',
      operation,
      attributes: {
        if (searchType != null) 'search_type': searchType,
      },
      metrics: {
        if (resultCount != null) 'result_count': resultCount,
      },
    );
  }

  /// Trace image upload operation
  static Future<T> traceImageUpload<T>(
    Future<T> Function(Trace trace) operation, {
    int? imageSize,
    String? imageFormat,
  }) async {
    return await traceOperation(
      'image_upload',
      operation,
      attributes: {
        if (imageFormat != null) 'format': imageFormat,
      },
      metrics: {
        if (imageSize != null) 'size_bytes': imageSize,
      },
    );
  }

  /// Trace navigation to screen
  static Future<T> traceScreenLoad<T>(
    String screenName,
    Future<T> Function(Trace trace) operation,
  ) async {
    return await traceOperation(
      'screen_$screenName',
      operation,
      attributes: {
        'screen_name': screenName,
      },
    );
  }

  /// Trace Firebase query operation
  static Future<T> traceFirebaseQuery<T>(
    Future<T> Function(Trace trace) operation, {
    required String collection,
    int? resultCount,
  }) async {
    return await traceOperation(
      'firebase_query_$collection',
      operation,
      attributes: {
        'collection': collection,
      },
      metrics: {
        if (resultCount != null) 'result_count': resultCount,
      },
    );
  }

  /// Trace social interaction
  static Future<T> traceSocialInteraction<T>(
    String interactionType,
    Future<T> Function(Trace trace) operation, {
    String? targetType,
  }) async {
    return await traceOperation(
      'social_$interactionType',
      operation,
      attributes: {
        'interaction_type': interactionType,
        if (targetType != null) 'target_type': targetType,
      },
    );
  }

  /// Create HTTP metric for monitoring network requests
  static HttpMetric httpMetric(
    String url,
    HttpMethod method,
  ) {
    return instance.newHttpMetric(url, method);
  }

  /// Execute HTTP request with automatic metric collection
  static Future<T> traceHttpRequest<T>(
    String url,
    HttpMethod method,
    Future<T> Function(HttpMetric metric) operation, {
    int? requestPayloadSize,
    String? contentType,
  }) async {
    if (!_isEnabled) {
      return await operation(_NoOpHttpMetric(url, method));
    }

    final metric = httpMetric(url, method);

    try {
      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }
      if (contentType != null) {
        metric.putAttribute('content_type', contentType);
      }

      await metric.start();
      final result = await operation(metric);
      await metric.stop();

      return result;
    } catch (e) {
      metric.putAttribute('error', e.toString());
      await metric.stop();
      rethrow;
    }
  }
}

/// No-op trace for when performance monitoring is disabled
class _NoOpTrace implements Trace {
  _NoOpTrace(String name);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void incrementMetric(String metricName, int incrementBy) {}

  @override
  int getMetric(String metricName) => 0;

  @override
  void setMetric(String metricName, int value) {}

  @override
  void putAttribute(String attribute, String value) {}

  @override
  void removeAttribute(String attribute) {}

  @override
  String? getAttribute(String attribute) => null;

  @override
  Map<String, String> getAttributes() => {};
}

/// No-op HTTP metric for when performance monitoring is disabled
class _NoOpHttpMetric implements HttpMetric {
  final String _url;
  final HttpMethod _method;

  _NoOpHttpMetric(this._url, this._method);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void putAttribute(String attribute, String value) {}

  @override
  void removeAttribute(String attribute) {}

  @override
  String? getAttribute(String attribute) => null;

  @override
  Map<String, String> getAttributes() => {};

  HttpMethod? get httpMethod => _method;

  String? get url => _url;

  @override
  set httpResponseCode(int? httpResponseCode) {}

  @override
  int? get httpResponseCode => null;

  @override
  set requestPayloadSize(int? requestPayloadSize) {}

  @override
  int? get requestPayloadSize => null;

  @override
  set responseContentType(String? responseContentType) {}

  @override
  String? get responseContentType => null;

  @override
  set responsePayloadSize(int? responsePayloadSize) {}

  @override
  int? get responsePayloadSize => null;
}
