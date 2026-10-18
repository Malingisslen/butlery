import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/views/admin/ops_event_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsSv();

  test(
    'the rate-limit abuse alert reads as Swedish, not as its type (BUT-2138)',
    () {
      expect(
        opsEventLabel(l10n, 'rate_limit_abuse_threshold_reached'),
        'Konto upprepat stoppat av spärren samma dygn',
      );
    },
  );

  test('an unknown type still falls back to its own words', () {
    expect(opsEventLabel(l10n, 'some_new_job'), 'Some new job');
  });
}
