/// Direct unit tests for the engagement read-models (BUT-1149 coverage burndown
/// — previously zero direct coverage).
///
/// Pure parse models for the admin engagement tab. Covers FeatureCounts.max
/// (busiest-single-feature floor), FeatureCounts.fromMap defaults, and
/// DailyEngagement.fromFirestore (date falls back to the doc id; a malformed
/// sub-field degrades to zeros rather than throwing).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/engagement_stats.dart';

void main() {
  group('FeatureCounts', () {
    test('max returns the busiest single feature', () {
      const f = FeatureCounts(cooked: 3, imported: 7, shared: 2, shopped: 5);
      expect(f.max, 7);
    });

    test('max is 0 when nothing happened', () {
      expect(const FeatureCounts().max, 0);
    });

    test('fromMap reads num counts and defaults missing keys to 0', () {
      // fromMap reads num-typed fields (as Firestore stores them); absent keys
      // default to 0 via the `?? 0` guard.
      final f = FeatureCounts.fromMap({
        'cooked': 4,
        'imported': 7,
        // shared/mealPlanned/shopped absent → 0
      });
      expect(f.cooked, 4);
      expect(f.imported, 7);
      expect(f.shared, 0);
      expect(f.mealPlanned, 0);
      expect(f.shopped, 0);
    });

    test('fromMap tolerates a null map', () {
      final f = FeatureCounts.fromMap(null);
      expect(f.max, 0);
    });
  });

  group('DailyEngagement.fromFirestore', () {
    test('parses date + nested feature windows', () {
      final d = DailyEngagement.fromFirestore('2026-01-10', {
        'date': '2026-01-10',
        'dau': {'cooked': 5},
        'wau7d': {'imported': 20},
        'wau28d': {'shopped': 50},
      });
      expect(d.date, '2026-01-10');
      expect(d.dau.cooked, 5);
      expect(d.wau7d.imported, 20);
      expect(d.wau28d.shopped, 50);
    });

    test('date falls back to the doc id when absent', () {
      final d = DailyEngagement.fromFirestore('2026-01-11', const {});
      expect(d.date, '2026-01-11');
      expect(d.dau.max, 0);
    });

    test('a malformed sub-field degrades to zeros', () {
      final d = DailyEngagement.fromFirestore('d', {
        'dau': 'not a map', // must not throw
      });
      expect(d.dau.max, 0);
    });
  });

  group('EngagementRaw', () {
    test('holds the user count and days', () {
      const raw = EngagementRaw(
        userCount: 42,
        days: [
          DailyEngagement(
            date: 'd0',
            dau: FeatureCounts(cooked: 1),
            wau7d: FeatureCounts(),
            wau28d: FeatureCounts(),
          ),
        ],
      );
      expect(raw.userCount, 42);
      expect(raw.days, hasLength(1));
    });
  });
}
