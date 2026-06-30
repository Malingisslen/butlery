/// Journey test: onboarding flow from welcome to completion.
///
/// Exercises [OnboardingViewModel] through a simplified view that mirrors
/// the real onboarding wizard's structure (welcome → allergens → dietary →
/// import/skip → complete). We assert user-visible state transitions and
/// that the final completion call reaches UserService with the correct
/// preferences payload.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/import_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

// Pure mocks — no concrete overrides so when()/verify() work cleanly.
class _MockUserService extends Mock implements UserService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockRecipeEventsTracker extends Mock implements RecipeEventsTracker {}

class _MockMenuEventsTracker extends Mock implements MenuEventsTracker {}

class _MockShoppingEventsTracker extends Mock
    implements ShoppingEventsTracker {}

class _MockSocialEventsTracker extends Mock implements SocialEventsTracker {}

class _MockImportEventsTracker extends Mock implements ImportEventsTracker {}

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

/// Extracted onboarding body that watches [OnboardingViewModel] directly.
/// Mirrors the real onboarding wizard (age-gate → welcome → allergens →
/// dietary → import) without pulling in the full production view tree.
class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody({
    required this.onCompleted,
    required this.onAgeRejected,
  });

  final VoidCallback onCompleted;

  /// Fired when the age-gate advance returns [AgeGateAdvanceResult.rejected].
  /// In production this is `OnboardingView._handleAgeRejection`: sign-out +
  /// `Navigator.pushNamedAndRemoveUntil(Routes.auth)`. The journey stand-in
  /// swaps `home` to a `Key('start_screen')` widget — the user-visible
  /// equivalent (the wizard is gone; they're back at start/auth) and proves
  /// the UGC pages are unreachable after rejection.
  final VoidCallback onAgeRejected;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator — reflects the current VM page.
            Container(
              key: const Key('page_indicator'),
              padding: const EdgeInsets.all(8),
              color: cs.surfaceContainerHighest,
              child: Text('Sida ${viewModel.currentPage + 1} / 5'),
            ),
            Expanded(child: _buildPage(context, viewModel)),
            // Sticky footer with navigation.
            Container(
              padding: const EdgeInsets.all(8),
              color: cs.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    key: const Key('skip'),
                    onPressed: () async {
                      final ok = await viewModel.completeOnboarding();
                      if (ok) onCompleted();
                    },
                    child: const Text('Hoppa över'),
                  ),
                  if (!viewModel.isFirstPage)
                    TextButton(
                      key: const Key('back'),
                      onPressed: viewModel.previousPage,
                      child: const Text('Tillbaka'),
                    ),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      key: const Key('next'),
                      onPressed: viewModel.isCompleting
                          ? null
                          : () async {
                              if (viewModel.isLastPage) {
                                final ok = await viewModel.completeOnboarding();
                                if (ok) onCompleted();
                                return;
                              }
                              // FAITHFUL MIRROR of OnboardingView._handleNext
                              // (lib/views/onboarding/onboarding_view.dart
                              // ~L279-297): the server-side age check runs AT
                              // the gate (page 0 advance), NOT at completion.
                              // Verify-at-gate is the contract — a rejected
                              // under-15 user is routed away and the UGC pages
                              // (allergens/dietary/import) are never reached.
                              if (viewModel.isAgeGatePage) {
                                final result = await viewModel.verifyAgeGate();
                                switch (result) {
                                  case AgeGateAdvanceResult.rejected:
                                    // Prod: sign-out + pushNamedAndRemoveUntil
                                    // (Routes.auth). Stand-in: swap home to the
                                    // start screen. Do NOT advance.
                                    onAgeRejected();
                                    return;
                                  case AgeGateAdvanceResult.error:
                                    // Prod: showError(errorGeneric) and stay on
                                    // the gate. Stand-in: stay on page 0.
                                    return;
                                  case AgeGateAdvanceResult.compliant:
                                    break; // fall through to advance
                                }
                              }
                              viewModel.nextPage();
                            },
                      child: Text(viewModel.isLastPage ? 'Kom igång' : 'Nästa'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, OnboardingViewModel viewModel) {
    switch (viewModel.currentPage) {
      case 0:
        // Age-gate stand-in — two buttons that drop in a birth year directly
        // (adult vs clearly-under-15), parallel affordances. Keeps the journey
        // focused on the gate branch without wrapping a real dropdown.
        return Center(
          key: const Key('page_age_gate'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                key: const Key('age_gate_set_adult'),
                onPressed: () =>
                    viewModel.setBirthYear(DateTime.now().year - 25),
                child: const Text('Välj vuxet födelseår'),
              ),
              ElevatedButton(
                key: const Key('age_gate_set_minor'),
                onPressed: () =>
                    viewModel.setBirthYear(DateTime.now().year - 10),
                child: const Text('Välj barn-födelseår'),
              ),
            ],
          ),
        );
      case 1:
        return const Center(
          key: Key('page_welcome'),
          child: Text('Välkommen till Butlery'),
        );
      case 2:
        return SingleChildScrollView(
          key: const Key('page_allergens'),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: AllergenPreferenceOptions.allergens.entries.map((e) {
              final selected = viewModel.isAllergenSelected(e.key);
              return FilterChip(
                key: Key('allergen_${e.key}'),
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => viewModel.toggleAllergen(e.key),
              );
            }).toList(),
          ),
        );
      case 3:
        return SingleChildScrollView(
          key: const Key('page_dietary'),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: AllergenPreferenceOptions.dietary.entries.map((e) {
              final selected = viewModel.isDietaryPrefSelected(e.key);
              return FilterChip(
                key: Key('dietary_${e.key}'),
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => viewModel.toggleDietaryPref(e.key),
              );
            }).toList(),
          ),
        );
      case 4:
      default:
        return const Center(
          key: Key('page_import'),
          child: Text('Importera ditt första recept (eller hoppa över)'),
        );
    }
  }
}

Widget _testApp({
  required OnboardingViewModel viewModel,
  required VoidCallback onCompleted,
  required ValueNotifier<bool> ageRejected,
}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      // On age rejection, production signs out + replaces the whole navigation
      // stack with Routes.auth. The user-visible equivalent here is swapping
      // `home` away from the wizard to a start-screen stand-in — proving the
      // onboarding tree (and its UGC pages) is gone, not merely held back.
      home: ValueListenableBuilder<bool>(
        valueListenable: ageRejected,
        builder: (context, rejected, _) {
          if (rejected) {
            return const Scaffold(
              key: Key('start_screen'),
              body: Center(child: Text('Start')),
            );
          }
          return _OnboardingBody(
            onCompleted: onCompleted,
            onAgeRejected: () => ageRejected.value = true,
          );
        },
      ),
    ),
  );
}

void main() {
  late _MockUserService mockUserService;
  late _MockAnalyticsService mockAnalyticsService;
  late _MockUnifiedRecipeService mockRecipeService;
  late _MockAgeVerificationService mockAgeVerificationService;
  late OnboardingViewModel viewModel;
  late bool onboardingCompleted;
  late ValueNotifier<bool> ageRejected;

  setUpAll(() {
    registerFallbackValue(UserAllergenPreferences.defaults);
  });

  setUp(() {
    // The production ServiceLocator is what OnboardingViewModel resolves.
    // Wire it up with a fresh DIContainer → GetIt, then register mocks.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }
    if (getIt.isRegistered<AgeVerificationService>()) {
      getIt.unregister<AgeVerificationService>();
    }

    production.ServiceLocator.initialize(DIContainer());

    mockUserService = _MockUserService();
    mockAnalyticsService = _MockAnalyticsService();
    mockRecipeService = _MockUnifiedRecipeService();
    mockAgeVerificationService = _MockAgeVerificationService();
    // BUT-1386: the journey picks an adult birth year, so the VM calls the
    // age-verification CF before completing. Default to compliant.
    when(
      () => mockAgeVerificationService.verifyAge(any()),
    ).thenAnswer((_) async => true);

    // Stub analytics tracker getters so any nested lookups don't null-crash.
    when(
      () => mockAnalyticsService.recipe,
    ).thenReturn(_MockRecipeEventsTracker());
    when(() => mockAnalyticsService.menu).thenReturn(_MockMenuEventsTracker());
    when(
      () => mockAnalyticsService.shopping,
    ).thenReturn(_MockShoppingEventsTracker());
    when(
      () => mockAnalyticsService.social,
    ).thenReturn(_MockSocialEventsTracker());
    when(
      () => mockAnalyticsService.import,
    ).thenReturn(_MockImportEventsTracker());

    when(
      () => mockAnalyticsService.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockUserService.completeOnboardingWithPreferences(
        any(),
        onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
      ),
    ).thenAnswer((_) async {});

    // Starter-recipe seeding runs fire-and-forget; stub to succeed silently
    // so the background future completes without noise.
    when(
      () => mockRecipeService.createPersonalRecipe(
        title: any(named: 'title'),
        description: any(named: 'description'),
        ingredients: any(named: 'ingredients'),
        instructions: any(named: 'instructions'),
        mealType: any(named: 'mealType'),
        portions: any(named: 'portions'),
        timeMinutes: any(named: 'timeMinutes'),
        sourceUrl: any(named: 'sourceUrl'),
      ),
    ).thenAnswer((_) async => 'seeded_recipe_id');

    getIt.registerSingleton<UserService>(mockUserService);
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);
    getIt.registerSingleton<UnifiedRecipeService>(mockRecipeService);
    getIt.registerSingleton<AgeVerificationService>(mockAgeVerificationService);

    viewModel = OnboardingViewModel();
    onboardingCompleted = false;
    ageRejected = ValueNotifier<bool>(false);
  });

  tearDown(() {
    ageRejected.dispose();
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }
    if (getIt.isRegistered<AgeVerificationService>()) {
      getIt.unregister<AgeVerificationService>();
    }
    production.ServiceLocator.reset();
  });

  group('Onboarding journey', () {
    testWidgets(
      'age-gate → welcome → allergen tap → dietary tap → complete saves prefs',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onCompleted: () => onboardingCompleted = true,
            ageRejected: ageRejected,
          ),
        );

        // Page 0 — age gate is first.
        expect(find.byKey(const Key('page_age_gate')), findsOneWidget);
        expect(find.byKey(const Key('back')), findsNothing);
        expect(find.text('Sida 1 / 5'), findsOneWidget);

        // Pick an adult year, then advance to the welcome page.
        await tester.tap(find.byKey(const Key('age_gate_set_adult')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('page_welcome')), findsOneWidget);
        expect(find.text('Välkommen till Butlery'), findsOneWidget);
        expect(find.text('Sida 2 / 5'), findsOneWidget);

        // Advance to allergens.
        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('page_allergens')), findsOneWidget);
        expect(find.text('Sida 3 / 5'), findsOneWidget);

        // Toggle gluten — chip becomes selected, VM tracks it.
        await tester.tap(find.byKey(const Key('allergen_gluten')));
        await tester.pumpAndSettle();
        expect(viewModel.isAllergenSelected('gluten'), isTrue);
        expect(
          tester
              .widget<FilterChip>(find.byKey(const Key('allergen_gluten')))
              .selected,
          isTrue,
        );

        // Advance to dietary.
        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('page_dietary')), findsOneWidget);

        // Toggle vegansk.
        await tester.tap(find.byKey(const Key('dietary_vegansk')));
        await tester.pumpAndSettle();
        expect(viewModel.isDietaryPrefSelected('vegansk'), isTrue);

        // Advance to import page — primary button becomes "Kom igång".
        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('page_import')), findsOneWidget);
        expect(find.text('Kom igång'), findsOneWidget);
        expect(viewModel.isLastPage, isTrue);

        // Complete onboarding from the last page — not a skip.
        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();

        // User-visible result: onCompleted fired.
        expect(onboardingCompleted, isTrue);

        // UserService saw the combined preferences payload with no skip timestamp.
        final captured = verify(
          () => mockUserService.completeOnboardingWithPreferences(
            captureAny(),
            onboardingSkippedAt: captureAny(named: 'onboardingSkippedAt'),
          ),
        ).captured;
        final prefs = captured[0] as UserAllergenPreferences?;
        final skippedAt = captured[1] as DateTime?;
        expect(prefs, isNotNull);
        expect(prefs!.trackedAllergens, contains('gluten'));
        expect(prefs.trackedDietary, contains('vegansk'));
        expect(
          skippedAt,
          isNull,
          reason: 'Finished from last page is not a skip',
        );

        // Completed analytics fired with the selection counts.
        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_completed',
            parameters: {
              'allergen_count': 1,
              'dietary_count': 1,
            },
          ),
        ).called(1);

        // BUT-1437: the age check ran exactly ONCE — at the gate (page 0
        // advance via verifyAgeGate), NOT re-called at completion. The VM sets
        // `_ageVerifiedThisSession` on a compliant gate result so
        // completeOnboarding's belt skips re-verifying. This pins the
        // verify-at-gate contract the stub now mirrors from production.
        verify(() => mockAgeVerificationService.verifyAge(any())).called(1);
      },
    );

    testWidgets(
      'under-15 at the age gate is rejected → routed to start, UGC unreachable',
      (tester) async {
        // This case mocks the age-verification CF to REJECT (verifyAge → false),
        // proving the user-visible rejection contract from OnboardingView:
        // verify-at-gate, then route away so the allergen/dietary/import (UGC)
        // pages are never reachable.
        when(
          () => mockAgeVerificationService.verifyAge(any()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onCompleted: () => onboardingCompleted = true,
            ageRejected: ageRejected,
          ),
        );

        // Page 0 — age gate is first; the wizard is showing.
        expect(find.byKey(const Key('page_age_gate')), findsOneWidget);
        expect(find.byKey(const Key('start_screen')), findsNothing);

        // Declare a clearly-under-15 birth year, then attempt to advance.
        await tester.tap(find.byKey(const Key('age_gate_set_minor')));
        await tester.pumpAndSettle();
        expect(
          viewModel.computedAge,
          lessThan(OnboardingViewModel.minAgeYears),
          reason: 'The minor affordance must pick a year below the 15 floor',
        );

        await tester.tap(find.byKey(const Key('next')));
        await tester.pumpAndSettle();

        // User-visible result: routed to the start/auth stand-in. The whole
        // onboarding tree is gone — not merely held on page 0.
        expect(find.byKey(const Key('start_screen')), findsOneWidget);
        expect(find.byKey(const Key('page_age_gate')), findsNothing);

        // The UGC pages must be unreachable after rejection. The allergen page
        // never rendered, and there's no longer a wizard to advance into.
        expect(find.byKey(const Key('page_allergens')), findsNothing);
        expect(find.byKey(const Key('page_dietary')), findsNothing);
        expect(find.byKey(const Key('page_import')), findsNothing);
        expect(find.byKey(const Key('next')), findsNothing);

        // VM recorded the under-15 rejection.
        expect(viewModel.ageRejected, isTrue);
        expect(
          onboardingCompleted,
          isFalse,
          reason: 'A rejected user must not complete onboarding',
        );

        // The age check ran exactly once — at the gate. Completion was never
        // reached, so there's no second call to fold in.
        verify(() => mockAgeVerificationService.verifyAge(any())).called(1);
        verifyNever(
          () => mockUserService.completeOnboardingWithPreferences(
            any(),
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
          ),
        );
      },
    );

    testWidgets('skip from allergen page records skip timestamp + null prefs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          viewModel: viewModel,
          onCompleted: () => onboardingCompleted = true,
          ageRejected: ageRejected,
        ),
      );

      // Satisfy the age gate, then advance past welcome to allergens.
      await tester.tap(find.byKey(const Key('age_gate_set_adult')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next'))); // age-gate → welcome
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next'))); // welcome → allergens
      await tester.pumpAndSettle();
      expect(viewModel.currentPage, 2);

      // Skip without selecting anything. (This journey uses a stub onboarding
      // body that mirrors the VM flow; the real OnboardingView's skip-confirm
      // dialog lives in production UI, not here.)
      await tester.tap(find.byKey(const Key('skip')));
      await tester.pumpAndSettle();

      expect(onboardingCompleted, isTrue);

      // No allergens/dietary selected → null prefs, skip timestamp present.
      final captured = verify(
        () => mockUserService.completeOnboardingWithPreferences(
          captureAny(),
          onboardingSkippedAt: captureAny(named: 'onboardingSkippedAt'),
        ),
      ).captured;
      expect(
        captured[0],
        isNull,
        reason: 'No selections → VM passes null, not empty prefs',
      );
      expect(
        captured[1],
        isA<DateTime>(),
        reason: 'Skip before last page must stamp onboardingSkippedAt',
      );

      verify(
        () => mockAnalyticsService.logEvent(
          name: 'onboarding_skipped',
          parameters: {'skipped_at_page': 2},
        ),
      ).called(1);
    });
  });
}
