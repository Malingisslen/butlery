import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';

void main() {
  final l = AppLocalizationsSv();
  final now = DateTime(2026, 10, 14, 9);

  setUpAll(() => initializeDateFormatting('sv'));

  String label(DateTime at) => ContentTimeLabels.relativeDayLabel(l, at, now);

  test('says today, yesterday and up to three days in words', () {
    expect(label(DateTime(2026, 10, 14, 1)), 'I dag');
    expect(label(DateTime(2026, 10, 13, 23)), 'I går');
    expect(label(DateTime(2026, 10, 12)), '2 dagar sedan');
    expect(label(DateTime(2026, 10, 11)), '3 dagar sedan');
  });

  test(
    'switches to the date after three days, with the year only when it differs',
    () {
      expect(label(DateTime(2026, 10, 10)), '10 oktober');
      expect(label(DateTime(2025, 12, 24)), '24 december 2025');
    },
  );

  test('counts calendar days, so a date in the future reads as today', () {
    expect(label(DateTime(2026, 10, 16)), 'I dag');
  });
}
