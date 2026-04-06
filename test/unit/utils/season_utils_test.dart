/// Unit tests for SeasonUtils — Swedish season tag by date.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/utils/season_utils.dart';

void main() {
  group('SeasonUtils', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    group('currentSeasonTag', () {
      test('January is vinter', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 1, 15)), 'vinter');
      });

      test('February is vinter', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 2, 15)), 'vinter');
      });

      test('March 1 is vår (boundary)', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 3, 1)), 'vår');
      });

      test('April is vår', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 4, 15)), 'vår');
      });

      test('May is vår', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 5, 31)), 'vår');
      });

      test('June 1 is sommar (boundary)', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 6, 1)), 'sommar');
      });

      test('July is sommar', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 7, 15)), 'sommar');
      });

      test('August is sommar', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 8, 31)), 'sommar');
      });

      test('September 1 is höst (boundary)', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 9, 1)), 'höst');
      });

      test('October is höst', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 10, 15)), 'höst');
      });

      test('November is höst', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 11, 30)), 'höst');
      });

      test('December 1 is vinter (boundary)', () {
        expect(SeasonUtils.currentSeasonTag(DateTime(2026, 12, 1)), 'vinter');
      });
    });
  });
}
