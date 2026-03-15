import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('OnboardingViewModel', () {
    late OnboardingViewModel viewModel;
    late MockUserService mockUserService;
    late MockAnalyticsService mockAnalyticsService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserAllergenPreferences.defaults);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockUserService = MockUserService();
      mockAnalyticsService = MockAnalyticsService();

      when(() => mockUserService.completeOnboardingWithPreferences(any()))
          .thenAnswer((_) async {});
      when(() => mockAnalyticsService.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      TestServiceLocator.registerMock<UserService>(mockUserService);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalyticsService);

      viewModel = OnboardingViewModel();
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('completeOnboarding', () {
      test('calls completeOnboardingWithPreferences with combined prefs',
          () async {
        viewModel.toggleAllergen('gluten');
        viewModel.toggleDietaryPref('vegansk');

        final result = await viewModel.completeOnboarding();

        expect(result, isTrue);
        final captured = verify(
          () => mockUserService.completeOnboardingWithPreferences(
            captureAny(),
          ),
        ).captured;
        final prefs = captured.first as UserAllergenPreferences;
        expect(prefs.trackedAllergens, contains('gluten'));
        expect(prefs.trackedDietary, contains('vegansk'));
      });

      test('passes null preferences when no selections', () async {
        final result = await viewModel.completeOnboarding();

        expect(result, isTrue);
        verify(
          () => mockUserService.completeOnboardingWithPreferences(null),
        ).called(1);
      });

      test('returns false when service throws', () async {
        when(() => mockUserService.completeOnboardingWithPreferences(any()))
            .thenThrow(Exception('Firestore write failed'));

        final result = await viewModel.completeOnboarding();

        expect(result, isFalse);
      });

      test('fires onboarding_completed analytics on success', () async {
        // Navigate to last page first
        viewModel.setPage(3);

        await viewModel.completeOnboarding();

        verify(() => mockAnalyticsService.logEvent(
              name: 'onboarding_completed',
              parameters: {
                'allergen_count': 0,
                'dietary_count': 0,
              },
            )).called(1);
      });

      test('fires onboarding_skipped analytics when not on last page',
          () async {
        // Stay on page 0 (not last page)
        await viewModel.completeOnboarding();

        verify(() => mockAnalyticsService.logEvent(
              name: 'onboarding_skipped',
              parameters: {'skipped_at_page': 0},
            )).called(1);
      });
    });

    group('page navigation', () {
      test('setPage fires onboarding_page_viewed analytics', () {
        viewModel.setPage(2);

        verify(() => mockAnalyticsService.logEvent(
              name: 'onboarding_page_viewed',
              parameters: {'page': 2},
            )).called(1);
      });

      test('setPage fires onboarding_started on first call', () {
        viewModel.setPage(0);

        verify(() => mockAnalyticsService.logEvent(
              name: 'onboarding_started',
            )).called(1);
      });

      test('nextPage does not fire analytics directly', () {
        // First setPage to start tracking
        viewModel.setPage(0);
        clearInteractions(mockAnalyticsService);

        // Re-stub after clear
        when(() => mockAnalyticsService.logEvent(
              name: any(named: 'name'),
              parameters: any(named: 'parameters'),
            )).thenAnswer((_) async {});

        viewModel.nextPage();

        verifyNever(() => mockAnalyticsService.logEvent(
              name: 'onboarding_page_viewed',
              parameters: any(named: 'parameters'),
            ));
      });
    });
  });
}
