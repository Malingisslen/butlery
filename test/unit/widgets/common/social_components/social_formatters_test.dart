/// Direct unit tests for [SocialFormatters] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Covers the two pieces of real, self-contained logic in this file: the
/// Swedish relative-time formatter (clock-driven, pinned with withClock) and the
/// k/M number abbreviation. The display-name / online / avatar / invitation
/// helpers just forward to SocialFacade, and getSocialColorScheme needs a
/// BuildContext — those belong with the facade tests / widget tests, not here.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/social_components/social_formatters.dart';

void main() {
  group('formatRelativeTime (Swedish)', () {
    final now = DateTime.utc(2026, 1, 15, 12);

    String ago(Duration d) => withClock(
      Clock.fixed(now),
      () => SocialFormatters.formatRelativeTime(now.subtract(d)),
    );

    test('under a minute → "just nu"', () {
      expect(ago(const Duration(seconds: 30)), 'just nu');
    });

    test('minutes', () {
      expect(ago(const Duration(minutes: 5)), '5 min sedan');
      expect(ago(const Duration(minutes: 59)), '59 min sedan');
    });

    test('hours', () {
      expect(ago(const Duration(hours: 3)), '3 timmar sedan');
    });

    test('days', () {
      expect(ago(const Duration(days: 3)), '3 dagar sedan');
    });

    test('weeks (floored)', () {
      expect(ago(const Duration(days: 21)), '3 veckor sedan');
      expect(ago(const Duration(days: 10)), '1 veckor sedan'); // 10/7 → 1
    });
  });

  group('formatNumberWithAbbreviation', () {
    test('numbers under 1000 are shown verbatim', () {
      expect(SocialFormatters.formatNumberWithAbbreviation(0), '0');
      expect(SocialFormatters.formatNumberWithAbbreviation(999), '999');
    });

    test('thousands use a k suffix, dropping ".0" on round values', () {
      expect(SocialFormatters.formatNumberWithAbbreviation(1000), '1k');
      expect(SocialFormatters.formatNumberWithAbbreviation(1500), '1.5k');
      expect(SocialFormatters.formatNumberWithAbbreviation(12000), '12k');
    });

    test('millions use an M suffix, dropping ".0" on round values', () {
      expect(SocialFormatters.formatNumberWithAbbreviation(1000000), '1M');
      expect(SocialFormatters.formatNumberWithAbbreviation(2500000), '2.5M');
    });
  });
}
