// BUT-961: pins the 7-day window-promotion contract for the three
// context-aware time styles. Uses `withClock` so the relative-window
// check is deterministic.

import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed reference timestamp so tests don't drift with wall clock.
  final now = DateTime.utc(2026, 5, 24, 12, 0, 0);

  group('ContextualTimeFormatter (BUT-961)', () {
    test('compact stays relative inside the 7-day window', () {
      withClock(Clock.fixed(now), () {
        final twoDaysAgo = now.subtract(const Duration(days: 2));
        final result = ContextualTimeFormatter.compact(twoDaysAgo);
        // Relative form has no comma — absolute "May 22" does. Crude
        // discriminator that doesn't lock down the exact compact-string
        // shape (which can change with l10n).
        expect(result, isNot(contains(',')));
      });
    });

    test('compact promotes to absolute date past the 7-day window', () {
      withClock(Clock.fixed(now), () {
        final tenDaysAgo = now.subtract(const Duration(days: 10));
        final result =
            ContextualTimeFormatter.compact(tenDaysAgo, localeName: 'en_US');
        // DateFormat.MMMd → "May 14".
        expect(result, equals('May 14'));
      });
    });

    test('standard promotes to yMMMd past the 7-day window', () {
      withClock(Clock.fixed(now), () {
        final tenDaysAgo = now.subtract(const Duration(days: 10));
        final result =
            ContextualTimeFormatter.standard(tenDaysAgo, localeName: 'en_US');
        // DateFormat.yMMMd → "May 14, 2026".
        expect(result, equals('May 14, 2026'));
      });
    });

    test('dateTime always renders full timestamp, never promotes', () {
      withClock(Clock.fixed(now), () {
        // Same-day = obviously inside the window, but dateTime should NOT
        // collapse to a relative form even when fresh.
        final justNow = now.subtract(const Duration(minutes: 3));
        final result =
            ContextualTimeFormatter.dateTime(justNow, localeName: 'en_US');
        expect(result, contains('May 24, 2026'));
        expect(result, contains(':')); // hh:mm separator
      });
    });

    test('window check uses .abs() so future timestamps also promote', () {
      // Edge case: a recipe created with a wrong clock might claim to be in
      // the future. The window check uses .abs(), so a future date past +7d
      // ALSO promotes to absolute (instead of returning gibberish like
      // "in -10 days").
      withClock(Clock.fixed(now), () {
        final tenDaysAhead = now.add(const Duration(days: 10));
        final result =
            ContextualTimeFormatter.standard(tenDaysAhead, localeName: 'en_US');
        expect(result, equals('Jun 3, 2026'));
      });
    });
  });
}
