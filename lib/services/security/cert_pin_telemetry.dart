/// Shared telemetry for SSL pin mismatches (BUT-427).
///
/// Both [PinnedHttpClient] (http package) and [PinningDioInterceptor] (Dio,
/// for Algolia) report mismatches via this helper so the analytics shape
/// stays in one place.
library;

import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

/// Logs `ssl_pin_mismatch` analytics event. Best-effort — never throws.
///
/// The wrapped HTTP request still throws — soft-fail at the app level
/// (network-error UX), not at the cert level.
void reportSslPinMismatch(String host, String errorKind, Object? error) {
  AnalyticsService.tryLog(
    AnalyticsEvents.sslPinMismatch,
    parameters: <String, Object>{
      'host': host,
      'error_kind': errorKind,
    },
  );
}
