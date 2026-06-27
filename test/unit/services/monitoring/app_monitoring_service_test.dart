/// BUT-1405: the web-forward policy for AppMonitoringService.recordError.
///
/// Only the severity policy is unit-testable here: the `kIsWeb` branch in
/// recordError (which actually forwards to WebErrorReporter) can't be exercised
/// under the Dart VM test runner, where `kIsWeb` is a compile-time `false`.
/// `shouldReportToWebError` is extracted precisely so the decision — forward
/// error/critical, never flood logWebError with info/warning — is pinned.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/monitoring/app_monitoring_service.dart';

void main() {
  group('AppMonitoringService.shouldReportToWebError (BUT-1405)', () {
    test('forwards alert-worthy severities (error, critical)', () {
      expect(
        AppMonitoringService.shouldReportToWebError(ErrorSeverity.error),
        isTrue,
      );
      expect(
        AppMonitoringService.shouldReportToWebError(ErrorSeverity.critical),
        isTrue,
      );
    });

    test('does NOT forward info or warning (avoid flooding logWebError)', () {
      expect(
        AppMonitoringService.shouldReportToWebError(ErrorSeverity.info),
        isFalse,
      );
      expect(
        AppMonitoringService.shouldReportToWebError(ErrorSeverity.warning),
        isFalse,
      );
    });

    test('every severity has a defined policy (no enum case unhandled)', () {
      for (final s in ErrorSeverity.values) {
        // Must not throw for any case, and the alert-worthy set is exactly
        // {error, critical}.
        final forwarded = AppMonitoringService.shouldReportToWebError(s);
        final expected =
            s == ErrorSeverity.error || s == ErrorSeverity.critical;
        expect(forwarded, expected, reason: 'policy mismatch for $s');
      }
    });
  });
}
