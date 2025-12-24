import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';
import 'package:butlery/core/base/base_service.dart';

/// Tracks import-related analytics events
class ImportEventsTracker extends BaseTracker {
  final BaseService? _parentService;

  ImportEventsTracker({required super.repository, BaseService? parentService})
      : _parentService = parentService;

  /// Log import start event
  Future<void> logImportStarted({
    required String source,
    String? platform,
  }) async {
    if (!await hasAnalyticsConsent()) return;

    if (_parentService != null) {
      await _parentService.executeServiceOperation(
        () async {
          await repository.logImportStarted(source: source, platform: platform);
        },
        operationName: 'Log import started',
        requiresAuth: false,
        requiresNetwork: false,
      );
    } else {
      await repository.logImportStarted(source: source, platform: platform);
    }
  }

  /// Log successful import
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logImportSuccess(
      source: source,
      platform: platform,
      recipeLength: recipeLength,
    );
  }

  /// Log extraction error (exempt from consent - error tracking)
  Future<void> logExtractionError({
    required String url,
    required SourcePlatform platform,
    required String error,
    String? errorType,
  }) async {
    await repository.logExtractionError(
      url: url,
      platform: platform.toString().split('.').last,
      error: error,
      errorType: errorType,
    );
  }

  /// Log manual copy fallback usage
  Future<void> logManualCopyFallback({
    required SourcePlatform platform,
    String? reason,
  }) async {
    await repository.logManualCopyFallback(
      platform: platform.toString().split('.').last,
      reason: reason,
    );
  }
}
