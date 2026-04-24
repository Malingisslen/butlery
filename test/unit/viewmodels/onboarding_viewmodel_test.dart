import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/import_events_tracker.dart';

// Pure mocks — no concrete overrides so when()/verify() work with mocktail
class _MockUserService extends Mock implements UserService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockRecipeEventsTracker extends Mock implements RecipeEventsTracker {}

class _MockMenuEventsTracker extends Mock implements MenuEventsTracker {}

class _MockShoppingEventsTracker extends Mock
    implements ShoppingEventsTracker {}

class _MockSocialEventsTracker extends Mock implements SocialEventsTracker {}

class _MockImportEventsTracker extends Mock implements ImportEventsTracker {}

void main() {
  group('OnboardingViewModel', () {
    late OnboardingViewModel viewModel;
    late _MockUserService mockUserService;
    late _MockAnalyticsService mockAnalyticsService;

    setUpAll(() {
      registerFallbackValue(UserAllergenPreferences.defaults);
    });

    setUp(() {
      // Fresh GetIt + production ServiceLocator so the VM can resolve services
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }

      production.ServiceLocator.initialize(DIContainer());

      mockUserService = _MockUserService();
      mockAnalyticsService = _MockAnalyticsService();

      // Stub tracker getters so production code can access them if needed
      when(() => mockAnalyticsService.recipe)
          .thenReturn(_MockRecipeEventsTracker());
      when(() => mockAnalyticsService.menu)
          .thenReturn(_MockMenuEventsTracker());
      when(() => mockAnalyticsService.shopping)
          .thenReturn(_MockShoppingEventsTracker());
      when(() => mockAnalyticsService.social)
          .thenReturn(_MockSocialEventsTracker());
      when(() => mockAnalyticsService.import)
          .thenReturn(_MockImportEventsTracker());

      when(() => mockUserService.completeOnboardingWithPreferences(
            any(),
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            birthYear: any(named: 'birthYear'),
          )).thenAnswer((_) async {});

      when(() => mockAnalyticsService.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      getIt.registerSingleton<UserService>(mockUserService);
      getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
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
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            birthYear: any(named: 'birthYear'),
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
          () => mockUserService.completeOnboardingWithPreferences(
            null,
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            birthYear: any(named: 'birthYear'),
          ),
        ).called(1);
      });

      test('returns false when service throws', () async {
        when(() => mockUserService.completeOnboardingWithPreferences(
              any(),
              onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            )).thenThrow(Exception('Firestore write failed'));

        final result = await viewModel.completeOnboarding();

        expect(result, isFalse);
      });

      test('fires onboarding_completed analytics on success', () async {
        viewModel.setPage(4);

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
