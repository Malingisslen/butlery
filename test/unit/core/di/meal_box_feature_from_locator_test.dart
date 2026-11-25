import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/meal_box_feature_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlags extends Mock implements FeatureFlagService {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  void register<T extends Object>(T service) {
    ServiceLocator.initialize(DIContainer());
    GetIt.instance.registerSingleton<T>(service);
  }

  group('mealBoxesEnabled', () {
    test('is off when the locator is not set up', () {
      expect(mealBoxesEnabled(), isFalse);
    });

    test('is off when no flag service is registered', () {
      ServiceLocator.initialize(DIContainer());
      expect(mealBoxesEnabled(), isFalse);
    });

    test('follows the flag service registered at call time', () {
      final flags = _MockFlags();
      register<FeatureFlagService>(flags);

      when(
        () => flags.isEnabled(FeatureFlags.enableMealBoxes),
      ).thenReturn(true);
      expect(mealBoxesEnabled(), isTrue);

      when(
        () => flags.isEnabled(FeatureFlags.enableMealBoxes),
      ).thenReturn(false);
      expect(mealBoxesEnabled(), isFalse);
    });

    test('is off when the flag service throws', () {
      final flags = _MockFlags();
      register<FeatureFlagService>(flags);
      when(() => flags.isEnabled(any())).thenThrow(StateError('broken'));

      expect(mealBoxesEnabled(), isFalse);
    });
  });

  group('logMealBoxEvent', () {
    test('does nothing when no analytics service is registered', () {
      expect(() => logMealBoxEvent('meal_box_offer_shown'), returnsNormally);
    });

    test('hands the name and parameters to the registered service', () async {
      final analytics = _MockAnalytics();
      register<AnalyticsService>(analytics);
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});

      logMealBoxEvent('meal_box_offer_saved', parameters: {'count': 2});
      await pumpEventQueue();

      verify(
        () => analytics.logEvent(
          name: 'meal_box_offer_saved',
          parameters: {'count': 2},
        ),
      ).called(1);
    });

    test('a synchronous throw never reaches the caller', () {
      final analytics = _MockAnalytics();
      register<AnalyticsService>(analytics);
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenThrow(StateError('broken'));

      expect(() => logMealBoxEvent('meal_box_offer_shown'), returnsNormally);
      verify(
        () => analytics.logEvent(
          name: 'meal_box_offer_shown',
          parameters: any(named: 'parameters'),
        ),
      ).called(1);
    });

    test('a failed future never surfaces as an uncaught error', () async {
      final analytics = _MockAnalytics();
      register<AnalyticsService>(analytics);
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) => Future<void>.error(StateError('broken')));

      logMealBoxEvent('meal_box_count_corrected');
      await pumpEventQueue();

      verify(
        () => analytics.logEvent(
          name: 'meal_box_count_corrected',
          parameters: any(named: 'parameters'),
        ),
      ).called(1);
    });
  });
}
