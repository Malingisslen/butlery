/// Service optimization utility providing performance monitoring, error handling, circuit breaker, and retry patterns.
import 'dart:async';
import 'dart:collection';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

class ServiceOptimizer with SingletonServiceMixin<ServiceOptimizer> {
  // Private constructor for singleton
  ServiceOptimizer._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory ServiceOptimizer() => SingletonServiceMixin.createSingleton(() => ServiceOptimizer._internal());

  // Performance tracking
  final Map<String, List<Duration>> _performanceMetrics = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, DateTime> _lastOperationTimes = {};

  // Error tracking
  final Map<String, List<String>> _errorLog = {};
  final Map<String, int> _errorCounts = {};

  // Memory optimization
  final Queue<String> _recentOperations = Queue<String>();
  static const int _maxRecentOperations = 1000;

  // ===== PERFORMANCE OPTIMIZATION =====

  /// Execute operation with performance monitoring
  Future<T> executeWithMonitoring<T>({
    required String operationName,
    required Future<T> Function() operation,
    Duration? timeoutDuration,
    String? serviceName,
  }) async {
    final stopwatch = Stopwatch()..start();
    final fullOperationName = serviceName != null ? '$serviceName.$operationName' : operationName;
    
    try {
      // Track operation start
      _lastOperationTimes[fullOperationName] = DateTime.now();
      _incrementOperationCount(fullOperationName);

      // Execute with optional timeout
      final result = timeoutDuration != null
          ? await operation().timeout(timeoutDuration)
          : await operation();

      // Track performance
      stopwatch.stop();
      _recordPerformance(fullOperationName, stopwatch.elapsed);

      // Log slow operations
      if (stopwatch.elapsed > const Duration(seconds: 2)) {
        AppLogger.warning('⏱️ Slow operation detected: $fullOperationName took ${stopwatch.elapsed.inMilliseconds}ms');
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      _recordError(fullOperationName, e.toString());
      
      AppLogger.error('❌ Operation failed: $fullOperationName (${stopwatch.elapsed.inMilliseconds}ms)', e);
      rethrow;
    } finally {
      _addToRecentOperations(fullOperationName);
    }
  }

  /// Execute operation with retry logic and exponential backoff
  Future<T> executeWithRetry<T>({
    required String operationName,
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    String? serviceName,
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;

    while (attempts < maxRetries) {
      try {
        return await executeWithMonitoring(
          operationName: operationName,
          operation: operation,
          serviceName: serviceName,
        );
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          AppLogger.error('🔄 Operation failed after $maxRetries retries: $operationName');
          rethrow;
        }

        AppLogger.warning('⚠️ Operation failed (attempt $attempts/$maxRetries): $operationName, retrying in ${currentDelay.inMilliseconds}ms');
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round());
      }
    }

    // This should never be reached, but satisfies the analyzer
    throw StateError('Unreachable code in executeWithRetry');
  }

  /// Execute operation with circuit breaker pattern
  Future<T> executeWithCircuitBreaker<T>({
    required String operationName,
    required Future<T> Function() operation,
    int failureThreshold = 5,
    Duration recoveryTime = const Duration(minutes: 1),
    String? serviceName,
  }) async {
    final circuitKey = serviceName != null ? '$serviceName.$operationName' : operationName;
    
    if (_isCircuitOpen(circuitKey, failureThreshold, recoveryTime)) {
      throw StateError('Circuit breaker is open for operation: $circuitKey');
    }

    try {
      final result = await executeWithMonitoring(
        operationName: operationName,
        operation: operation,
        serviceName: serviceName,
      );
      
      _recordSuccess(circuitKey);
      return result;
    } catch (e) {
      _recordError(circuitKey, e.toString());
      rethrow;
    }
  }

  // ===== ERROR HANDLING OPTIMIZATION =====

  /// Enhanced error handler with categorization and recovery suggestions
  void handleError({
    required String context,
    required dynamic error,
    StackTrace? stackTrace,
    String? userId,
    Map<String, dynamic>? additionalData,
    String? serviceName,
  }) {
    final errorCategory = _categorizeError(error);
    final fullContext = serviceName != null ? '$serviceName.$context' : context;
    
    final errorDetails = {
      'error': error.toString(),
      'category': errorCategory,
      'timestamp': DateTime.now().toIso8601String(),
      'context': fullContext,
      'userId': userId,
      'additionalData': additionalData,
      'recoverySuggestion': _getRecoverySuggestion(errorCategory),
    };

    _recordError(fullContext, error.toString());
    
    // Log based on severity
    switch (errorCategory) {
      case ErrorCategory.network:
        AppLogger.warning('🌐 Network error in $fullContext: $error');
        break;
      case ErrorCategory.permission:
        AppLogger.warning('🔒 Permission error in $fullContext: $error');
        break;
      case ErrorCategory.validation:
        AppLogger.info('✅ Validation error in $fullContext: $error');
        break;
      case ErrorCategory.system:
        AppLogger.error('🔥 System error in $fullContext: $error', error);
        break;
      case ErrorCategory.unknown:
        AppLogger.error('❓ Unknown error in $fullContext: $error', error);
        break;
    }

    // Report critical errors
    if (errorCategory == ErrorCategory.system || _getErrorCount(fullContext) > 10) {
      _reportCriticalError(errorDetails);
    }
  }

  /// Get error recovery suggestion
  String _getRecoverySuggestion(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Check internet connection and retry';
      case ErrorCategory.permission:
        return 'Verify user permissions and authentication';
      case ErrorCategory.validation:
        return 'Check input data format and requirements';
      case ErrorCategory.system:
        return 'Report to support team for investigation';
      case ErrorCategory.unknown:
        return 'Retry operation or contact support if problem persists';
    }
  }

  // ===== PERFORMANCE ANALYTICS =====

  /// Get performance statistics for an operation
  Map<String, dynamic> getPerformanceStats(String operationName) {
    final metrics = _performanceMetrics[operationName] ?? [];
    if (metrics.isEmpty) return {};

    final durations = metrics.map((d) => d.inMilliseconds).toList();
    durations.sort();

    return {
      'operationName': operationName,
      'totalExecutions': _operationCounts[operationName] ?? 0,
      'averageMs': durations.isEmpty ? 0 : (durations.reduce((a, b) => a + b) / durations.length).round(),
      'medianMs': durations.isEmpty ? 0 : durations[durations.length ~/ 2],
      'minMs': durations.isEmpty ? 0 : durations.first,
      'maxMs': durations.isEmpty ? 0 : durations.last,
      'p95Ms': durations.isEmpty ? 0 : durations[(durations.length * 0.95).floor()],
      'lastExecuted': _lastOperationTimes[operationName]?.toIso8601String(),
      'errorCount': _errorCounts[operationName] ?? 0,
      'errorRate': _calculateErrorRate(operationName),
    };
  }

  /// Get overall service health metrics
  Map<String, dynamic> getServiceHealthMetrics() {
    final totalOperations = _operationCounts.values.fold(0, (a, b) => a + b);
    final totalErrors = _errorCounts.values.fold(0, (a, b) => a + b);
    
    final allDurations = _performanceMetrics.values
        .expand((list) => list)
        .map((d) => d.inMilliseconds)
        .toList();
    
    final averageResponseTime = allDurations.isEmpty 
        ? 0 
        : (allDurations.reduce((a, b) => a + b) / allDurations.length).round();

    return {
      'totalOperations': totalOperations,
      'totalErrors': totalErrors,
      'errorRate': totalOperations > 0 ? (totalErrors / totalOperations * 100).toStringAsFixed(2) : '0.00',
      'averageResponseTime': averageResponseTime,
      'activeOperations': _recentOperations.length,
      'serviceUptime': DateTime.now().difference(DateTime.now().subtract(const Duration(hours: 1))).inMinutes, // Placeholder
      'topErrorOperations': _getTopErrorOperations(),
      'slowestOperations': _getSlowestOperations(),
    };
  }

  /// Clear old performance data to prevent memory leaks
  void cleanupOldData({Duration? olderThan}) {
    final cutoff = DateTime.now().subtract(olderThan ?? const Duration(hours: 24));
    
    // Clear old performance metrics
    _performanceMetrics.removeWhere((key, value) {
      final lastExecution = _lastOperationTimes[key];
      return lastExecution != null && lastExecution.isBefore(cutoff);
    });

    // Clear old error logs
    _errorLog.removeWhere((key, value) {
      final lastExecution = _lastOperationTimes[key];
      return lastExecution != null && lastExecution.isBefore(cutoff);
    });

    // Trim recent operations queue
    while (_recentOperations.length > _maxRecentOperations) {
      _recentOperations.removeFirst();
    }

    AppLogger.info('🧹 ServiceOptimizer: Cleaned up old data (cutoff: ${cutoff.toIso8601String()})');
  }

  // ===== PRIVATE HELPER METHODS =====

  void _recordPerformance(String operationName, Duration duration) {
    _performanceMetrics.putIfAbsent(operationName, () => <Duration>[]);
    _performanceMetrics[operationName]!.add(duration);
    
    // Keep only recent metrics to prevent memory leak
    if (_performanceMetrics[operationName]!.length > 100) {
      _performanceMetrics[operationName]!.removeAt(0);
    }
  }

  void _recordError(String operationName, String error) {
    _errorLog.putIfAbsent(operationName, () => <String>[]);
    _errorLog[operationName]!.add(error);
    _errorCounts[operationName] = (_errorCounts[operationName] ?? 0) + 1;
    
    // Keep only recent errors to prevent memory leak
    if (_errorLog[operationName]!.length > 50) {
      _errorLog[operationName]!.removeAt(0);
    }
  }

  void _recordSuccess(String operationName) {
    // Reset error count on success for circuit breaker
    // Could implement more sophisticated success tracking here
  }

  void _incrementOperationCount(String operationName) {
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
  }

  void _addToRecentOperations(String operationName) {
    _recentOperations.add('${DateTime.now().toIso8601String()}: $operationName');
    
    if (_recentOperations.length > _maxRecentOperations) {
      _recentOperations.removeFirst();
    }
  }

  ErrorCategory _categorizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('timeout')) {
      return ErrorCategory.network;
    }
    if (errorStr.contains('permission') || errorStr.contains('unauthorized') || errorStr.contains('forbidden')) {
      return ErrorCategory.permission;
    }
    if (errorStr.contains('validation') || errorStr.contains('invalid') || errorStr.contains('format')) {
      return ErrorCategory.validation;
    }
    if (errorStr.contains('system') || errorStr.contains('internal') || errorStr.contains('fatal')) {
      return ErrorCategory.system;
    }
    
    return ErrorCategory.unknown;
  }

  bool _isCircuitOpen(String operationName, int threshold, Duration recoveryTime) {
    final errorCount = _errorCounts[operationName] ?? 0;
    final lastOperation = _lastOperationTimes[operationName];
    
    if (errorCount < threshold) return false;
    
    if (lastOperation != null) {
      final timeSinceLastOperation = DateTime.now().difference(lastOperation);
      return timeSinceLastOperation < recoveryTime;
    }
    
    return false;
  }

  int _getErrorCount(String operationName) => _errorCounts[operationName] ?? 0;

  double _calculateErrorRate(String operationName) {
    final total = _operationCounts[operationName] ?? 0;
    final errors = _errorCounts[operationName] ?? 0;
    return total > 0 ? (errors / total * 100) : 0.0;
  }

  List<Map<String, dynamic>> _getTopErrorOperations() {
    final entries = _errorCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => {
      'operation': e.key,
      'errorCount': e.value,
      'errorRate': _calculateErrorRate(e.key).toStringAsFixed(2),
    }).toList();
  }

  List<Map<String, dynamic>> _getSlowestOperations() {
    final operationAvgTimes = <String, double>{};
    
    for (final entry in _performanceMetrics.entries) {
      if (entry.value.isNotEmpty) {
        final avgMs = entry.value.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / entry.value.length;
        operationAvgTimes[entry.key] = avgMs;
      }
    }
    
    final entries = operationAvgTimes.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => {
      'operation': e.key,
      'averageMs': e.value.round(),
    }).toList();
  }

  void _reportCriticalError(Map<String, dynamic> errorDetails) {
    // In a real implementation, this would send to error reporting service
    AppLogger.error('🚨 CRITICAL ERROR DETECTED: ${errorDetails['context']} - ${errorDetails['error']}');
  }
}

/// Error categorization for better handling
enum ErrorCategory {
  network,
  permission,
  validation,
  system,
  unknown,
}