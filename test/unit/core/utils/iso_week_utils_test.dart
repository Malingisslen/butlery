import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekStartOf', () {
    test('Monday maps to itself at 00:00', () {
      final input = DateTime(2026, 4, 6, 14, 30); // Mon
      expect(IsoWeekUtils.weekStartOf(input), DateTime(2026, 4, 6));
    });

    test('Sunday rolls back 6 days to Monday', () {
      final input = DateTime(2026, 4, 12, 23, 59); // Sun
      expect(IsoWeekUtils.weekStartOf(input), DateTime(2026, 4, 6));
    });

    test('Wednesday rolls back 2 days', () {
      final input = DateTime(2026, 4, 8, 9, 0); // Wed
      expect(IsoWeekUtils.weekStartOf(input), DateTime(2026, 4, 6));
    });

    test('crosses month boundary', () {
      final input = DateTime(2026, 5, 1); // Fri
      expect(IsoWeekUtils.weekStartOf(input), DateTime(2026, 4, 27));
    });
  });

  group('isoWeekNumber', () {
    test('2026-04-11 (Sat of Vecka 15)', () {
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2026, 4, 11)), 15);
    });

    test('2026-01-05 is ISO week 2', () {
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2026, 1, 5)), 2);
    });

    test('2025-12-29 is ISO week 1 of 2026 (boundary rollover)', () {
      // Mon 2025-12-29 belongs to ISO week 1 of 2026 because the first
      // Thursday of 2026 is 2026-01-01.
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2025, 12, 29)), 1);
      expect(IsoWeekUtils.isoWeekYear(DateTime(2025, 12, 29)), 2026);
    });

    test('2021-01-01 is ISO week 53 of 2020', () {
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2021, 1, 1)), 53);
      expect(IsoWeekUtils.isoWeekYear(DateTime(2021, 1, 1)), 2020);
    });

    test('year with week 53 (leap + Wednesday) — 2020', () {
      // 2020 is a leap year starting on Wed; ISO week 53 exists.
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2020, 12, 28)), 53);
    });

    test('year without week 53 rolls to week 1 — 2022', () {
      // Jan 1 2023 is Sun — 2022 has 52 ISO weeks only.
      expect(IsoWeekUtils.isoWeekNumber(DateTime(2022, 12, 31)), 52);
    });
  });

  group('weekIdFor', () {
    test('zero-pads single-digit week numbers', () {
      final id = IsoWeekUtils.weekIdFor('abc123', DateTime(2026, 2, 2));
      expect(id, 'abc123_2026-W06');
    });

    test('two-digit weeks kept verbatim', () {
      final id = IsoWeekUtils.weekIdFor('abc123', DateTime(2026, 4, 11));
      expect(id, 'abc123_2026-W15');
    });

    test('same userId + same ISO week yields identical ID across days', () {
      final monday = IsoWeekUtils.weekIdFor('abc', DateTime(2026, 4, 6));
      final sunday = IsoWeekUtils.weekIdFor('abc', DateTime(2026, 4, 12));
      expect(monday, sunday);
      expect(monday, 'abc_2026-W15');
    });

    test('week-year boundary: 2025-12-29 stamps as 2026-W01', () {
      // Critical: prevents the upsert key from drifting across the New Year
      // boundary and creating duplicate Firestore docs.
      final id = IsoWeekUtils.weekIdFor('user', DateTime(2025, 12, 29));
      expect(id, 'user_2026-W01');
    });
  });
}
