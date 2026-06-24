import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';
import 'package:butlery/services/content_detector_service.dart';

/// Tracks import-related analytics events
class ImportEventsTracker extends BaseTracker {
  final BaseService? _parentService;

  ImportEventsTracker({required super.repository, BaseService? parentService})
    : _parentService = parentService;

  /// Log import start event
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
    String imageFormat = 'unknown',
  }) async {
    if (!await hasAnalyticsConsent()) return;

    if (_parentService != null) {
      await _parentService.executeServiceOperation(
        () async {
          await repository.logImportStarted(
            source: source,
            platform: platform,
            sessionId: sessionId,
            imageFormat: imageFormat,
          );
        },
        operationName: 'Log import started',
        requiresAuth: false,
        requiresNetwork: false,
      );
    } else {
      await repository.logImportStarted(
        source: source,
        platform: platform,
        sessionId: sessionId,
        imageFormat: imageFormat,
      );
    }
  }

  /// Log successful import
  ///
  /// [imageFormat] / [imageFormatSent] (BUT-662): tag the original
  /// magic-byte-detected format and the format actually delivered to OCR
  /// after HEIC→JPEG conversion. Both default to `'unknown'` for non-photo
  /// import paths.
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
    String imageFormat = 'unknown',
    String imageFormatSent = 'unknown',
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logImportSuccess(
      source: source,
      platform: platform,
      recipeLength: recipeLength,
      sessionId: sessionId,
      imageFormat: imageFormat,
      imageFormatSent: imageFormatSent,
    );
  }

  /// Log import cancelled
  Future<void> logImportCancelled({
    required String source,
    String? sessionId,
  }) async {
    await logEvent(
      name: AnalyticsEvents.importCancelled,
      parameters: {
        'source': source,
        'session_id': ?sessionId,
      },
    );
  }

  /// BUT-1037: user dismissed the "doesn't look like a recipe" warn dialog
  /// instead of forcing the import — one paid LLM parse avoided. [source]
  /// identifies the import surface (e.g. `text_paste`).
  Future<void> logWarnDialogCancelled({required String source}) async {
    await logEvent(
      name: AnalyticsEvents.importWarnDialogCancelled,
      parameters: {'source': source},
    );
  }

  /// Log extraction error (exempt from consent - error tracking)
  Future<void> logExtractionError({
    required String url,
    required SourcePlatform platform,
    required String error,
    String? errorType,
    String imageFormat = 'unknown',
  }) async {
    await repository.logExtractionError(
      url: url,
      platform: platform.toString().split('.').last,
      error: error,
      errorType: errorType,
      imageFormat: imageFormat,
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
