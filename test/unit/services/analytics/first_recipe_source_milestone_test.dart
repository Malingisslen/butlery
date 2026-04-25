import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('FirstRecipeSourceMilestone (BUT-618)', () {
    late _MockAnalyticsService analytics;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Empty SharedPreferences per test so milestone state doesn't leak.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      analytics = _MockAnalyticsService();
      when(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('sets first_recipe_source on first recipe with import source',
        () async {
      final fired = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-1',
        source: 'import',
      );

      expect(fired, isTrue);
      verify(() => analytics.setUserProperty(
            name: 'first_recipe_source',
            value: 'import',
          )).called(1);
    });

    test('sets first_recipe_source on first recipe with manual source',
        () async {
      final fired = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-2',
        source: 'manual',
      );

      expect(fired, isTrue);
      verify(() => analytics.setUserProperty(
            name: 'first_recipe_source',
            value: 'manual',
          )).called(1);
    });

    test('sets first_recipe_source on first recipe with seed source', () async {
      final fired = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-3',
        source: 'seed',
      );

      expect(fired, isTrue);
      verify(() => analytics.setUserProperty(
            name: 'first_recipe_source',
            value: 'seed',
          )).called(1);
    });

    test('does NOT overwrite on subsequent calls for same user', () async {
      // First — sets manual.
      final first = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-4',
        source: 'manual',
      );
      expect(first, isTrue);

      clearInteractions(analytics);

      // Second — would set import, but must be deduped.
      final second = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-4',
        source: 'import',
      );
      expect(second, isFalse);

      verifyNever(() => analytics.setUserProperty(
            name: 'first_recipe_source',
            value: any(named: 'value'),
          ));
    });

    test('dedupe is per-user — different uid still sets', () async {
      await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-A',
        source: 'manual',
      );
      clearInteractions(analytics);

      final fired = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: 'user-B',
        source: 'import',
      );

      expect(fired, isTrue);
      verify(() => analytics.setUserProperty(
            name: 'first_recipe_source',
            value: 'import',
          )).called(1);
    });

    test('skips when userId is null/empty', () async {
      final firedNull = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: null,
        source: 'manual',
      );
      final firedEmpty = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: analytics,
        userId: '',
        source: 'manual',
      );

      expect(firedNull, isFalse);
      expect(firedEmpty, isFalse);
      verifyNever(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          ));
    });

    test('skips when analytics is null', () async {
      final fired = await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: null,
        userId: 'user-5',
        source: 'manual',
      );

      expect(fired, isFalse);
    });
  });
}
