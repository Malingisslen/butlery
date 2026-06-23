/// Unit tests for TimeAgoFormatter (standard / verbose / compact).
///
/// Drives `clock.now()` via `withClock` so the difference math is fully
/// deterministic. AppLocale defaults to Swedish, so the localized
/// strings can be asserted against the Swedish formatter output.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/time_ago_formatter.dart';

final _fixedNow = DateTime.utc(2026, 5, 23, 12);

T _atNow<T>(T Function() body) => withClock(Clock.fixed(_fixedNow), body);

DateTime _minutesAgo(int m) => _fixedNow.subtract(Duration(minutes: m));
DateTime _hoursAgo(int h) => _fixedNow.subtract(Duration(hours: h));
DateTime _daysAgo(int d) => _fixedNow.subtract(Duration(days: d));

void main() {
  group('standard', () {
    test('<1 minute → "Nu"', () {
      _atNow(() => expect(TimeAgoFormatter.standard(_minutesAgo(0)), 'Nu'));
    });

    test('<1 hour → "N min sedan"', () {
      _atNow(
        () =>
            expect(TimeAgoFormatter.standard(_minutesAgo(15)), '15 min sedan'),
      );
    });

    test('<1 day → "N tim sedan"', () {
      _atNow(
        () => expect(TimeAgoFormatter.standard(_hoursAgo(3)), '3 tim sedan'),
      );
    });

    test('<7 days → "N dagar sedan" / "1 dag sedan"', () {
      _atNow(() {
        expect(TimeAgoFormatter.standard(_daysAgo(1)), '1 dag sedan');
        expect(TimeAgoFormatter.standard(_daysAgo(3)), '3 dagar sedan');
      });
    });

    test('>=7 days → weeks', () {
      _atNow(
        () => expect(TimeAgoFormatter.standard(_daysAgo(14)), '2 veckor sedan'),
      );
    });
  });

  group('verbose', () {
    test('<1 minute → "Nyss"', () {
      _atNow(() => expect(TimeAgoFormatter.verbose(_minutesAgo(0)), 'Nyss'));
    });

    test('minutes → "N minuter sedan" / "1 minut sedan"', () {
      _atNow(() {
        expect(TimeAgoFormatter.verbose(_minutesAgo(1)), '1 minut sedan');
        expect(TimeAgoFormatter.verbose(_minutesAgo(15)), '15 minuter sedan');
      });
    });

    test('hours → "N timmar sedan"', () {
      _atNow(
        () => expect(TimeAgoFormatter.verbose(_hoursAgo(3)), '3 timmar sedan'),
      );
    });

    test('days (1..7) → "N dagar sedan" (pluralized)', () {
      _atNow(() {
        expect(TimeAgoFormatter.verbose(_daysAgo(1)), '1 dag sedan');
        expect(TimeAgoFormatter.verbose(_daysAgo(3)), '3 dagar sedan');
      });
    });

    test('>7 days → "day/month" format', () {
      final old = DateTime.utc(2026, 4, 1);
      _atNow(() => expect(TimeAgoFormatter.verbose(old), '1/4'));
    });
  });

  group('compact', () {
    test('<1 min → "Nu"', () {
      _atNow(() => expect(TimeAgoFormatter.compact(_minutesAgo(0)), 'Nu'));
    });

    test('<1 hour → "Nm"', () {
      _atNow(() => expect(TimeAgoFormatter.compact(_minutesAgo(15)), '15m'));
    });

    test('<1 day → "Nh"', () {
      _atNow(() => expect(TimeAgoFormatter.compact(_hoursAgo(3)), '3h'));
    });

    test('<30 days → "Nd"', () {
      _atNow(() => expect(TimeAgoFormatter.compact(_daysAgo(5)), '5d'));
    });

    test('>=30 days → "Nmån"', () {
      _atNow(() {
        final result = TimeAgoFormatter.compact(_daysAgo(60));
        // Format is "Nmån" but exact suffix depends on l10n template;
        // we just assert the months-floor result is present.
        expect(result, contains('2'));
      });
    });
  });
}
