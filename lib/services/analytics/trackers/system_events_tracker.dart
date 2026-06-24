import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks system and error-related analytics events
/// Error events exempt from consent check (service operation tracking)
class SystemEventsTracker extends BaseTracker {
  final BaseService? _parentService;

  SystemEventsTracker({required super.repository, BaseService? parentService})
    : _parentService = parentService;

  /// Log error occurred (exempt from consent - error tracking)
  Future<void> logErrorOccurred({
    required String errorCode,
    required String errorType,
    String? userAction,
    String? stackTrace,
  }) async {
    Future<void> doLog() async {
      await repository.logEvent(
        name: AnalyticsEvents.errorOccurred,
        parameters: {
          'error_code': errorCode,
          'error_type': errorType,
          'user_action': ?userAction,
          if (stackTrace != null)
            'stack_trace': stackTrace.substring(
              0,
              stackTrace.length > 500 ? 500 : stackTrace.length,
            ),
        },
      );
    }

    if (_parentService != null) {
      await _parentService.executeServiceOperation(
        doLog,
        operationName: 'Log error',
        requiresAuth: false,
        requiresNetwork: false,
      );
    } else {
      await doLog();
    }
  }

  /// Log network error (exempt from consent - error tracking)
  Future<void> logNetworkError({
    required String endpoint,
    required int statusCode,
    String? errorMessage,
  }) async {
    await logEvent(
      name: AnalyticsEvents.networkError,
      parameters: {
        'endpoint': endpoint,
        'status_code': statusCode,
        'error_message': ?errorMessage,
      },
    );
  }

  /// Log slow operation (exempt from consent - performance tracking)
  Future<void> logSlowOperation({
    required String operationName,
    required int durationMs,
    int? thresholdMs,
  }) async {
    await logEvent(
      name: AnalyticsEvents.slowOperation,
      parameters: {
        'operation_name': operationName,
        'duration_ms': durationMs,
        'threshold_ms': ?thresholdMs,
      },
    );
  }
}
