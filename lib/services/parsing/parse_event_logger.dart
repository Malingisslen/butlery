import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

/// Fire-and-forget logger for recipe parse events via Cloud Function.
/// Used by both RecipeParserService and UrlImportStrategy.
class ParseEventLogger {
  // Lazy so the Firebase app doesn't have to be initialised at construction.
  // Integration/unit tests that only exercise parsing logic (no Firebase)
  // would otherwise throw "No Firebase App '[DEFAULT]'" just from creating
  // a UrlImportStrategy.
  FirebaseFunctions? _functionsCache;
  // logParseEvent deploys to europe-west1 (setGlobalOptions in functions/src
  // index.ts). The default instance targets us-central1, so calling it there
  // returns NOT_FOUND and silently drops every parse-event log. Pin the region.
  FirebaseFunctions get _functions =>
      _functionsCache ??= FirebaseFunctions.instanceFor(region: 'europe-west1');

  void logEvent({
    required String? url,
    required String source,
    required bool success,
    bool fromCache = false,
    required int parseTimeMs,
    String? parserVersion,
    String? domain,
    String? successfulTier,
    double? finalQuality,
    bool? usedLlm,
    double? totalCostSek,
    List<Map<String, dynamic>>? tierAttempts,
    bool unknownDomain = false,
    String? promptVersion,
  }) {
    try {
      final payload = <String, dynamic>{
        'url': url,
        'source': source,
        'success': success,
        'fromCache': fromCache,
        'parseTimeMs': parseTimeMs,
        if (parserVersion != null) 'parserVersion': parserVersion,
        if (domain != null) 'domain': domain,
        if (successfulTier != null) 'successfulTier': successfulTier,
        if (finalQuality != null) 'finalQuality': finalQuality,
        if (usedLlm != null) 'usedLlm': usedLlm,
        if (totalCostSek != null) 'totalCostSek': totalCostSek,
        if (tierAttempts != null) 'tierAttempts': tierAttempts,
        if (unknownDomain) 'unknownDomain': true,
        if (promptVersion != null) 'promptVersion': promptVersion,
      };

      unawaited(
        _functions
            .httpsCallable('logParseEvent')
            .call<Map<String, dynamic>>(payload)
            .then((_) {})
            .catchError((Object e) {
              AppLogger.debug('ParseEventLogger: logging failed: $e');
              _emitFailureMetric(e);
            }),
      );
    } catch (e) {
      AppLogger.debug('ParseEventLogger: payload error: $e');
      _emitFailureMetric(e);
    }
  }

  /// BUT-616: surface the silent loss so dashboards can measure failure rate
  /// against the success volume. Best-effort — never re-throws.
  void _emitFailureMetric(Object error) {
    final code = error is FirebaseFunctionsException ? error.code : 'unknown';
    final cause = error.toString();
    AnalyticsService.tryLog(
      AnalyticsEvents.parseEventLogFailed,
      parameters: {
        'error_code': code,
        // Firebase Analytics param values cap at 100 chars; truncate well
        // under the cap to leave headroom and keep cardinality bounded.
        'cause': cause.length > 50 ? cause.substring(0, 50) : cause,
      },
    );
  }
}
