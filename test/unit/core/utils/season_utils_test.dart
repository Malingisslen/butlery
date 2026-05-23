/// Unit tests for SeasonUtils — Swedish-season tag from month.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/season_utils.dart';

void main() {
  group('currentSeasonTag', () {
    test('March – May → vår', () {
      for (final m in [3, 4, 5]) {
        expect(
          SeasonUtils.currentSeasonTag(DateTime(2026, m, 15)),
          'vår',
          reason: 'month $m',
        );
      }
    });

    test('June – August → sommar', () {
      for (final m in [6, 7, 8]) {
        expect(
          SeasonUtils.currentSeasonTag(DateTime(2026, m, 15)),
          'sommar',
          reason: 'month $m',
        );
      }
    });

    test('September – November → höst', () {
      for (final m in [9, 10, 11]) {
        expect(
          SeasonUtils.currentSeasonTag(DateTime(2026, m, 15)),
          'höst',
          reason: 'month $m',
        );
      }
    });

    test('December / January / February → vinter', () {
      for (final m in [12, 1, 2]) {
        expect(
          SeasonUtils.currentSeasonTag(DateTime(2026, m, 15)),
          'vinter',
          reason: 'month $m',
        );
      }
    });

    test('defaults to clock.now() when no arg', () {
      // Drive deterministically via withClock so this doesn't depend on
      // wall-clock when the suite runs.
      withClock(Clock.fixed(DateTime(2026, 7, 1)), () {
        expect(SeasonUtils.currentSeasonTag(), 'sommar');
      });
    });
  });
}
