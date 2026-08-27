import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/import_events_tracker.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

// Pure mocks — no concrete overrides so when()/verify() work with mocktail
class _MockUserService extends Mock implements UserService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockMenuShoppingListGenerator extends Mock
    implements MenuShoppingListGenerator {}

class _MockRecipeEventsTracker extends Mock implements RecipeEventsTracker {}

class _MockMenuEventsTracker extends Mock implements MenuEventsTracker {}

class _MockShoppingEventsTracker extends Mock
    implements ShoppingEventsTracker {}

class _MockSocialEventsTracker extends Mock implements SocialEventsTracker {}

class _MockImportEventsTracker extends Mock implements ImportEventsTracker {}

class _MockOnboardingProgressService extends Mock
    implements OnboardingProgressService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  group('OnboardingViewModel', () {
    late OnboardingViewModel viewModel;
    late _MockUserService mockUserService;
    late _MockAnalyticsService mockAnalyticsService;
    late _MockAgeVerificationService mockAgeVerificationService;

    setUpAll(() {
      registerFallbackValue(UserAllergenPreferences.defaults);
      registerFallbackValue(OnboardingStep.ageGate);
    });

    setUp(() {
      // Fresh GetIt + production ServiceLocator so the VM can resolve services
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      if (getIt.isRegistered<AgeVerificationService>()) {
        getIt.unregister<AgeVerificationService>();
      }

      production.ServiceLocator.initialize(DIContainer());

      mockUserService = _MockUserService();
      mockAnalyticsService = _MockAnalyticsService();
      mockAgeVerificationService = _MockAgeVerificationService();
      // Default: the CF deems the account compliant. Tests that need the
      // under-15 / error paths override this. The VM only calls verifyAge when
      // a birth year was selected, so age-agnostic tests never hit it.
      when(
        () => mockAgeVerificationService.verifyAge(any()),
      ).thenAnswer(
        (_) async =>
            const AgeVerificationResult(compliant: true, isMinor: false),
      );

      // Stub tracker getters so production code can access them if needed
      when(
        () => mockAnalyticsService.recipe,
      ).thenReturn(_MockRecipeEventsTracker());
      when(
        () => mockAnalyticsService.menu,
      ).thenReturn(_MockMenuEventsTracker());
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
        () => mockUserService.completeOnboardingWithPreferences(
          any(),
          onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
          isMinor: any(named: 'isMinor'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAnalyticsService.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});

      getIt.registerSingleton<UserService>(mockUserService);
      getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);
      getIt.registerSingleton<AgeVerificationService>(
        mockAgeVerificationService,
      );

      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      if (getIt.isRegistered<AgeVerificationService>()) {
        getIt.unregister<AgeVerificationService>();
      }
    });

    group('completeOnboarding', () {
      test(
        'calls completeOnboardingWithPreferences with combined prefs',
        () async {
          viewModel.toggleAllergen('gluten');
          viewModel.toggleDietaryPref('vegansk');

          final result = await viewModel.completeOnboarding();

          expect(result, isTrue);
          final captured = verify(
            () => mockUserService.completeOnboardingWithPreferences(
              captureAny(),
              onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
              isMinor: any(named: 'isMinor'),
            ),
          ).captured;
          final prefs = captured.first as UserAllergenPreferences;
          expect(prefs.trackedAllergens, contains('gluten'));
          expect(prefs.trackedDietary, contains('vegansk'));
        },
      );

      test('passes null preferences when no selections', () async {
        final result = await viewModel.completeOnboarding();

        expect(result, isTrue);
        verify(
          () => mockUserService.completeOnboardingWithPreferences(
            null,
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            isMinor: any(named: 'isMinor'),
          ),
        ).called(1);
      });

      test('returns false when service throws', () async {
        when(
          () => mockUserService.completeOnboardingWithPreferences(
            any(),
            onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
            isMinor: any(named: 'isMinor'),
          ),
        ).thenThrow(Exception('Firestore write failed'));

        final result = await viewModel.completeOnboarding();

        expect(result, isFalse);
      });

      test('fires onboarding_completed analytics on success', () async {
        viewModel.setPage(4);

        await viewModel.completeOnboarding();

        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_completed',
            parameters: {
              'allergen_count': 0,
              'dietary_count': 0,
            },
          ),
        ).called(1);
      });

      test(
        'fires onboarding_skipped analytics when not on last page',
        () async {
          // Stay on page 0 (not last page)
          await viewModel.completeOnboarding();

          verify(
            () => mockAnalyticsService.logEvent(
              name: 'onboarding_skipped',
              parameters: {'skipped_at_page': 0},
            ),
          ).called(1);
        },
      );

      test(
        'BUT-545: fires onboarding_import_skipped when import never succeeded',
        () async {
          viewModel.setPage(4);
          await viewModel.completeOnboarding();

          verify(
            () => mockAnalyticsService.logEvent(
              name: 'onboarding_import_skipped',
              parameters: {'completed_via_skip': false},
            ),
          ).called(1);
        },
      );

      test(
        'BUT-545: does NOT fire onboarding_import_skipped after successful import',
        () async {
          viewModel.setPage(4);
          viewModel.markOnboardingImportSucceeded();

          await viewModel.completeOnboarding();

          verifyNever(
            () => mockAnalyticsService.logEvent(
              name: 'onboarding_import_skipped',
              parameters: any(named: 'parameters'),
            ),
          );
        },
      );

      // BUT-1386 (ADR-0002): the verifySignupAge CF is the age authority and
      // the sole writer of birthYear. The PRIMARY mint now happens at the
      // gate-advance ([verifyAgeGate]) — not at completion — so a session that
      // RESUMES past the age gate (where _selectedBirthYear is null again)
      // still has the claim and is never re-checked. Completion keeps only a
      // belt-and-suspenders re-check for a birth year held this session that
      // the gate handler somehow never verified.
      group('BUT-1386 server-side age verification at the gate', () {
        test(
          'verifyAgeGate calls the CF for the declared adult year and returns '
          'compliant, letting the user past the gate',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);

            final result = await viewModel.verifyAgeGate();

            expect(result, AgeGateAdvanceResult.compliant);
            verify(
              () => mockAgeVerificationService.verifyAge(
                DateTime.now().year - 30,
              ),
            ).called(1);
            expect(viewModel.ageRejected, isFalse);
          },
        );

        test(
          'BUT-1454: a minor gate-pass threads isMinor:true into completion so '
          'the profile is saved default-private (search-suppressed)',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 16); // 16 → minor
            when(
              () => mockAgeVerificationService.verifyAge(any()),
            ).thenAnswer(
              (_) async =>
                  const AgeVerificationResult(compliant: true, isMinor: true),
            );

            expect(
              await viewModel.verifyAgeGate(),
              AgeGateAdvanceResult.compliant,
            );
            final result = await viewModel.completeOnboarding();

            expect(result, isTrue);
            final captured = verify(
              () => mockUserService.completeOnboardingWithPreferences(
                any(),
                onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
                isMinor: captureAny(named: 'isMinor'),
              ),
            ).captured;
            expect(
              captured.single,
              isTrue,
              reason:
                  'the minor flag from the CF must reach the completion write '
                  'that stamps the profile',
            );
          },
        );

        test(
          'an adult gate-pass threads isMinor:false into completion',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);

            expect(
              await viewModel.verifyAgeGate(),
              AgeGateAdvanceResult.compliant,
            );
            await viewModel.completeOnboarding();

            final captured = verify(
              () => mockUserService.completeOnboardingWithPreferences(
                any(),
                onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
                isMinor: captureAny(named: 'isMinor'),
              ),
            ).captured;
            expect(captured.single, isFalse);
          },
        );

        test(
          'an under-15 rejection at the gate flags ageRejected and returns '
          'rejected (the CF already deleted the account)',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);
            when(
              () => mockAgeVerificationService.verifyAge(any()),
            ).thenAnswer(
              (_) async =>
                  const AgeVerificationResult(compliant: false, isMinor: false),
            );

            final result = await viewModel.verifyAgeGate();

            expect(result, AgeGateAdvanceResult.rejected);
            expect(
              viewModel.ageRejected,
              isTrue,
              reason:
                  'the view needs the typed rejection signal to show the '
                  'butler-voice message and route back to start',
            );
          },
        );

        test(
          'an infrastructure failure at the gate returns error WITHOUT flagging '
          'ageRejected (retry, not an under-15 rejection) so the gate is '
          'not passed',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);
            when(
              () => mockAgeVerificationService.verifyAge(any()),
            ).thenThrow(Exception('functions/internal'));

            final result = await viewModel.verifyAgeGate();

            expect(result, AgeGateAdvanceResult.error);
            expect(
              viewModel.ageRejected,
              isFalse,
              reason:
                  'a transient CF error must surface the generic retry '
                  'error, not the permanent under-15 rejection path',
            );
          },
        );

        test(
          'after a compliant gate pass, completion does NOT re-verify — the '
          'claim was already minted at the gate',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);
            await viewModel.verifyAgeGate();
            clearInteractions(mockAgeVerificationService);
            when(
              () => mockAgeVerificationService.verifyAge(any()),
            ).thenAnswer(
              (_) async =>
                  const AgeVerificationResult(compliant: true, isMinor: false),
            );

            final result = await viewModel.completeOnboarding();

            expect(result, isTrue);
            verifyNever(() => mockAgeVerificationService.verifyAge(any()));
          },
        );

        test(
          'a RESUMED session (re-enters past the gate, no birth year held) '
          'completes WITHOUT calling the CF — the claim was minted in the '
          'session that passed the gate',
          () async {
            // resolveResumePageIndex would drop the user at a page past the
            // age gate in a fresh VM where _selectedBirthYear is null.
            viewModel.setInitialPage(2);

            final result = await viewModel.completeOnboarding();

            expect(result, isTrue);
            verifyNever(() => mockAgeVerificationService.verifyAge(any()));
            verify(
              () => mockUserService.completeOnboardingWithPreferences(
                any(),
                onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
                isMinor: any(named: 'isMinor'),
              ),
            ).called(1);
          },
        );

        test(
          'belt-and-suspenders: a birth year held this session that the gate '
          'handler never verified is re-checked once at completion '
          '(idempotent CF)',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);

            final result = await viewModel.completeOnboarding();

            expect(result, isTrue);
            verify(
              () => mockAgeVerificationService.verifyAge(
                DateTime.now().year - 30,
              ),
            ).called(1);
            verify(
              () => mockUserService.completeOnboardingWithPreferences(
                any(),
                onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
                isMinor: any(named: 'isMinor'),
              ),
            ).called(1);
          },
        );

        test(
          'completion skips the CF entirely when no birth year was declared',
          () async {
            await viewModel.completeOnboarding();

            verifyNever(() => mockAgeVerificationService.verifyAge(any()));
          },
        );

        test(
          'an under-15 result via the completion belt flags ageRejected, '
          'returns false, and never marks onboarding complete',
          () async {
            viewModel.setBirthYear(DateTime.now().year - 30);
            when(
              () => mockAgeVerificationService.verifyAge(any()),
            ).thenAnswer(
              (_) async =>
                  const AgeVerificationResult(compliant: false, isMinor: false),
            );

            final result = await viewModel.completeOnboarding();

            expect(result, isFalse);
            expect(viewModel.ageRejected, isTrue);
            verifyNever(
              () => mockUserService.completeOnboardingWithPreferences(
                any(),
                onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
                isMinor: any(named: 'isMinor'),
              ),
            );
          },
        );
      });
    });

    group(
      'age gate requires an explicit choice (floor 15 — Dataskyddslag 2:4 §)',
      () {
        test('does not auto-select a birth year on init', () {
          // Compliance: pre-seeding an adult default would let anyone tap Next
          // without declaring their age. The gate must stay unset until a pick.
          expect(viewModel.selectedBirthYear, isNull);
          expect(
            viewModel.isAgeGatePassed,
            isFalse,
            reason: 'an unanswered gate must never count as passed',
          );
        });

        test('passes only after an adult year is explicitly selected', () {
          viewModel.setBirthYear(DateTime.now().year - 30);
          expect(viewModel.isAgeGatePassed, isTrue);
        });

        test('fails when the explicitly selected year is under 15', () {
          viewModel.setBirthYear(DateTime.now().year - 10);
          expect(viewModel.selectedBirthYear, isNotNull);
          expect(
            viewModel.isAgeGatePassed,
            isFalse,
            reason: 'the GDPR age block must engage on a deliberate young pick',
          );
        });

        test('clearing the selection re-locks the gate', () {
          viewModel.setBirthYear(DateTime.now().year - 30);
          expect(viewModel.isAgeGatePassed, isTrue);

          viewModel.setBirthYear(null);
          expect(viewModel.selectedBirthYear, isNull);
          expect(viewModel.isAgeGatePassed, isFalse);
        });

        test('pins the 15-year threshold exactly (15 passes, 14 fails)', () {
          // The Swedish Dataskyddslag 2:4 § social-service cutoff (15, ADR-0001)
          // is a hard legal boundary, so the exact edge is pinned: a `>=`→`>` or
          // minAgeYears change must fail here.
          viewModel.setBirthYear(DateTime.now().year - 15);
          expect(viewModel.isAgeGatePassed, isTrue, reason: 'age 15 must pass');

          viewModel.setBirthYear(DateTime.now().year - 14);
          expect(
            viewModel.isAgeGatePassed,
            isFalse,
            reason: 'age 14 must fail',
          );
        });
      },
    );

    group('completion timeout (bug 33)', () {
      test('a hung completion write surfaces an error (returns false) instead '
          'of hanging forever', () {
        // The user-prefs write never resolves — without the timeout the whole
        // onboarding spinner would hang. The bounded write throws
        // TimeoutException, caught -> returns false. fakeAsync advances the
        // virtual clock past the internal timeout without a real wall wait.
        fakeAsync((async) {
          when(
            () => mockUserService.completeOnboardingWithPreferences(
              any(),
              onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
              isMinor: any(named: 'isMinor'),
            ),
          ).thenAnswer((_) => Completer<void>().future);

          bool? result;
          viewModel.completeOnboarding().then((r) => result = r);

          // Before the timeout elapses the call is still pending.
          async.elapse(const Duration(seconds: 19));
          expect(result, isNull, reason: 'still waiting inside the timeout');

          // Past the 20s bound the timeout fires -> returns false.
          async.elapse(const Duration(seconds: 2));
          expect(
            result,
            isFalse,
            reason: 'a hung completion must degrade to an error, not hang',
          );
        });
      });
    });

    group('page navigation', () {
      test('setPage fires onboarding_page_viewed analytics', () {
        viewModel.setPage(2);

        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_page_viewed',
            parameters: {'page': 2},
          ),
        ).called(1);
      });

      test('setPage fires onboarding_started on first call', () {
        viewModel.setPage(0);

        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_started',
          ),
        ).called(1);
      });

      test('BUT-538: setPage dedupes onboarding_page_viewed per session', () {
        viewModel.setPage(1);
        viewModel.setPage(2);
        viewModel.setPage(1); // back-nav — should NOT fire again
        viewModel.setPage(2); // forward-revisit — should NOT fire again

        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_page_viewed',
            parameters: {'page': 1},
          ),
        ).called(1);
        verify(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_page_viewed',
            parameters: {'page': 2},
          ),
        ).called(1);
      });

      test(
        'BUT-538: setInitialPage marks page as already viewed (no re-fire on return)',
        () {
          viewModel.setInitialPage(3); // resume at page 3 — no analytics
          viewModel.setPage(0); // navigate back — fires once for 0
          viewModel.setPage(3); // forward to 3 — should NOT fire (resumed)

          verifyNever(
            () => mockAnalyticsService.logEvent(
              name: 'onboarding_page_viewed',
              parameters: {'page': 3},
            ),
          );
          verify(
            () => mockAnalyticsService.logEvent(
              name: 'onboarding_page_viewed',
              parameters: {'page': 0},
            ),
          ).called(1);
        },
      );

      test('nextPage does not fire analytics directly', () {
        // First setPage to start tracking
        viewModel.setPage(0);
        clearInteractions(mockAnalyticsService);

        // Re-stub after clear
        when(
          () => mockAnalyticsService.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ),
        ).thenAnswer((_) async {});

        viewModel.nextPage();

        verifyNever(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_page_viewed',
            parameters: any(named: 'parameters'),
          ),
        );
      });
    });

    // BUT-675: step-completion must persist during NORMAL forward navigation.
    // The real view advances by calling nextPage() (bumps _currentPage)
    // BEFORE the PageController animation fires onPageChanged -> setPage. The
    // regression was that persistence lived only in setPage's `page >
    // _currentPage` branch, which is already false by the time setPage runs,
    // so forward progress was never written — resume was effectively dead.
    group('BUT-675 step-completion persistence', () {
      late _MockOnboardingProgressService mockProgress;
      late OnboardingViewModel vm;

      setUp(() {
        mockProgress = _MockOnboardingProgressService();
        when(
          () => mockProgress.markStepComplete(
            userId: any(named: 'userId'),
            step: any(named: 'step'),
            isFinalStep: any(named: 'isFinalStep'),
          ),
        ).thenAnswer((_) async {});
        vm = OnboardingViewModel(
          progressService: mockProgress,
          userId: 'u1',
        );
      });

      tearDown(() => vm.dispose());

      test('forward nav via the real view sequence (nextPage then setPage) '
          'persists the step that was left', () async {
        // Mirror onboarding_view._handleNext + onPageChanged exactly: the VM
        // is bumped first, then the animation reports the new page.
        vm.setPage(0); // start at age-gate (also fires onboarding_started)
        vm.nextPage(); // user taps Next on page 0 -> _currentPage becomes 1
        vm.setPage(1); // PageController animation lands on page 1

        // The step LEFT was page 0 (age-gate). It must be persisted exactly
        // once, not as the final step.
        verify(
          () => mockProgress.markStepComplete(
            userId: 'u1',
            step: OnboardingStep.ageGate,
            isFinalStep: false,
          ),
        ).called(1);
      });

      test(
        'walking the whole wizard persists each step exactly once',
        () async {
          vm.setPage(0);
          // Pages 0->1->2->3->4: four forward hops, each leaving one step.
          for (var i = 0; i < 4; i++) {
            final from = vm.currentPage;
            vm.nextPage();
            vm.setPage(from + 1);
          }

          // Each of the four left-behind steps persisted once; never duplicated
          // by the trailing setPage (whose guard is false because nextPage
          // already advanced _currentPage).
          for (final step in [
            OnboardingStep.ageGate,
            OnboardingStep.welcome,
            OnboardingStep.allergens,
            OnboardingStep.dietary,
          ]) {
            verify(
              () => mockProgress.markStepComplete(
                userId: 'u1',
                step: step,
                isFinalStep: false,
              ),
            ).called(1);
          }
        },
      );

      test(
        'backward nav never persists a step (no resume downgrade)',
        () async {
          vm.setPage(0);
          vm.nextPage();
          vm.setPage(1);
          clearInteractions(mockProgress);

          vm.previousPage(); // _currentPage 1 -> 0
          vm.setPage(0); // animation lands back on 0

          verifyNever(
            () => mockProgress.markStepComplete(
              userId: any(named: 'userId'),
              step: any(named: 'step'),
              isFinalStep: any(named: 'isFinalStep'),
            ),
          );
        },
      );
    });
  });

  // BUT-930: after starter recipes seed, onboarding builds a sample weekly
  // menu plan from those recipes and generates its shopping list. These tests
  // wire the recipe/menu/shopping services (the suite above intentionally
  // omits them to exercise the graceful-degrade path).
  group('OnboardingViewModel sample-menu seeding (BUT-930)', () {
    late OnboardingViewModel viewModel;
    late _MockUserService mockUserService;
    late _MockAnalyticsService mockAnalyticsService;
    late _MockUnifiedRecipeService mockRecipeService;
    late _MockWeeklyMenuPlanService mockMenuService;
    late _MockMenuShoppingListGenerator mockShoppingGenerator;

    Recipe recipeWith(String id, String mealType) => Recipe(
      core: RecipeCore(
        id: id,
        title: 'r-$id',
        description: '',
        ingredients: const ['1 dl mjölk'],
        instructions: const ['gör'],
        imageUrls: const [],
        mealType: mealType,
        portions: 2,
        timeMinutes: 10,
        sourceUrl: 'Butlerys startrecept',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        createdBy: 'system',
      ),
      type: RecipeType.personal,
    );

    WeeklyMenuPlan emptyPlan() =>
        WeeklyMenuPlan.empty(userId: 'u1', date: DateTime(2026, 6, 8));

    setUpAll(() {
      registerFallbackValue(UserAllergenPreferences.defaults);
      registerFallbackValue(emptyPlan());
      registerFallbackValue(recipeWith('fallback', 'Middag'));
      registerFallbackValue(DayOfWeek.mon);
      registerFallbackValue(MealSlot.middag);
    });

    setUp(() {
      final getIt = GetIt.instance;
      for (final unregister in [
        () => getIt.isRegistered<UserService>()
            ? getIt.unregister<UserService>()
            : null,
        () => getIt.isRegistered<AnalyticsService>()
            ? getIt.unregister<AnalyticsService>()
            : null,
        () => getIt.isRegistered<UnifiedRecipeService>()
            ? getIt.unregister<UnifiedRecipeService>()
            : null,
        () => getIt.isRegistered<WeeklyMenuPlanService>()
            ? getIt.unregister<WeeklyMenuPlanService>()
            : null,
        () => getIt.isRegistered<MenuShoppingListGenerator>()
            ? getIt.unregister<MenuShoppingListGenerator>()
            : null,
      ]) {
        unregister();
      }

      production.ServiceLocator.initialize(DIContainer());

      mockUserService = _MockUserService();
      mockAnalyticsService = _MockAnalyticsService();
      mockRecipeService = _MockUnifiedRecipeService();
      mockMenuService = _MockWeeklyMenuPlanService();
      mockShoppingGenerator = _MockMenuShoppingListGenerator();

      when(
        () => mockUserService.completeOnboardingWithPreferences(
          any(),
          onboardingSkippedAt: any(named: 'onboardingSkippedAt'),
          isMinor: any(named: 'isMinor'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockUserService.currentUserId).thenReturn('u1');
      when(
        () => mockAnalyticsService.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});

      // Two seed recipes persist with fresh ids r1 (middag) + r2 (frukost).
      var created = 0;
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
      ).thenAnswer((_) async => 'r${++created}');
      when(
        () => mockRecipeService.getRecipeById('r1'),
      ).thenReturn(recipeWith('r1', 'Middag'));
      when(
        () => mockRecipeService.getRecipeById('r2'),
      ).thenReturn(recipeWith('r2', 'Frukost'));
      when(
        () => mockRecipeService.getRecipeById(any()),
      ).thenReturn(recipeWith('rX', 'Middag'));

      getIt.registerSingleton<UserService>(mockUserService);
      getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);
      getIt.registerSingleton<UnifiedRecipeService>(mockRecipeService);
      getIt.registerSingleton<WeeklyMenuPlanService>(mockMenuService);
      getIt.registerSingleton<MenuShoppingListGenerator>(mockShoppingGenerator);

      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
      final getIt = GetIt.instance;
      for (final t in [
        () => getIt.isRegistered<UserService>()
            ? getIt.unregister<UserService>()
            : null,
        () => getIt.isRegistered<AnalyticsService>()
            ? getIt.unregister<AnalyticsService>()
            : null,
        () => getIt.isRegistered<UnifiedRecipeService>()
            ? getIt.unregister<UnifiedRecipeService>()
            : null,
        () => getIt.isRegistered<WeeklyMenuPlanService>()
            ? getIt.unregister<WeeklyMenuPlanService>()
            : null,
        () => getIt.isRegistered<MenuShoppingListGenerator>()
            ? getIt.unregister<MenuShoppingListGenerator>()
            : null,
      ]) {
        t();
      }
    });

    test('seeds a non-empty menu plan and generates its shopping list when the '
        'week is empty', () async {
      when(
        () => mockMenuService.readWeek(any()),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan(), readFailed: false),
      );
      // Real addEntry semantics — delegate to a fresh service so the saved
      // plan is genuinely non-empty rather than a hand-rolled stub.
      final realAdder = WeeklyMenuPlanService(
        repository: _NoopMenuRepo(),
        userService: mockUserService,
      );
      when(
        () => mockMenuService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer(
        (inv) => realAdder.addEntry(
          plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
          day: inv.namedArguments[#day] as DayOfWeek,
          slot: inv.namedArguments[#slot] as MealSlot,
          recipe: inv.namedArguments[#recipe] as Recipe,
        ),
      );
      when(() => mockMenuService.save(any())).thenAnswer((_) async {});
      when(() => mockShoppingGenerator.generateForWeek(any())).thenAnswer(
        (_) async => const MenuShoppingGenerationResult(
          listId: 'list1',
          listName: 'Inköpslista v24',
          itemCount: 5,
          recipeCount: 2,
          unresolvedRecipes: 0,
        ),
      );

      await viewModel.completeOnboarding();

      final savedPlan =
          verify(() => mockMenuService.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(
        savedPlan.entries,
        isNotEmpty,
        reason: 'the saved sample plan must contain the seeded recipes',
      );
      verify(() => mockShoppingGenerator.generateForWeek(any())).called(1);
      verify(
        () => mockAnalyticsService.logEvent(
          name: 'onboarding_menu_seeded',
          parameters: any(named: 'parameters'),
        ),
      ).called(1);
    });

    test(
      'does not overwrite an existing non-empty plan (idempotent)',
      () async {
        final existing = realPlanWithOneEntry();
        when(
          () => mockMenuService.readWeek(any()),
        ).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: existing, readFailed: false),
        );

        await viewModel.completeOnboarding();

        verifyNever(
          () => mockMenuService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        );
        verifyNever(() => mockMenuService.save(any()));
        verifyNever(() => mockShoppingGenerator.generateForWeek(any()));
      },
    );

    // Wires mockMenuService.addEntry to a real WeeklyMenuPlanService so the
    // placement walk (day-skip, slot routing) runs with production semantics
    // instead of a hand-rolled stub. Shared by the placement-invariant tests.
    void wireRealAdderOnEmptyWeek() {
      when(
        () => mockMenuService.readWeek(any()),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan(), readFailed: false),
      );
      final realAdder = WeeklyMenuPlanService(
        repository: _NoopMenuRepo(),
        userService: mockUserService,
      );
      when(
        () => mockMenuService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer(
        (inv) => realAdder.addEntry(
          plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
          day: inv.namedArguments[#day] as DayOfWeek,
          slot: inv.namedArguments[#slot] as MealSlot,
          recipe: inv.namedArguments[#recipe] as Recipe,
        ),
      );
      when(() => mockMenuService.save(any())).thenAnswer((_) async {});
      when(() => mockShoppingGenerator.generateForWeek(any())).thenAnswer(
        (_) async => const MenuShoppingGenerationResult(
          listId: 'list1',
          listName: 'Inköpslista v24',
          itemCount: 0,
          recipeCount: 0,
          unresolvedRecipes: 0,
        ),
      );
    }

    test('two single-slot (middag) recipes land on different days, never '
        'colliding on the same slot', () async {
      // Every seeded recipe maps to MealSlot.middag — a single-recipe slot.
      // The placement walk MUST advance the day for each so they don't
      // overwrite each other. This is the BUT-930 invariant the happy-path
      // test (which only asserts non-empty) doesn't pin. The exact count is
      // driven by RecipeSeeds, so we assert the relationship, not a literal.
      when(() => mockRecipeService.getRecipeById(any())).thenAnswer(
        (inv) => recipeWith(inv.positionalArguments.first as String, 'Middag'),
      );
      wireRealAdderOnEmptyWeek();

      await viewModel.completeOnboarding();

      final savedPlan =
          verify(() => mockMenuService.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      final middagEntries = savedPlan.entries
          .where((e) => e.slot == MealSlot.middag)
          .toList();
      expect(
        middagEntries,
        isNotEmpty,
        reason: 'middag recipes must be placed',
      );
      expect(
        middagEntries.map((e) => e.day).toSet().length,
        middagEntries.length,
        reason:
            'each single-slot recipe must occupy a distinct day — no two '
            'middag recipes may collide on the same day/slot',
      );
    });

    test('every seeded recipe is placed deterministically — a Frukost recipe '
        'routes to övrigt and nothing is silently dropped (bug 34)', () async {
      // Reproduces the seed mix: several single-slot recipes plus one Frukost
      // (which maps to MealSlot.ovrigt). The old "one recipe per day across
      // all slots" walk could exhaust the leading days and drop the trailing
      // övrigt recipe. Slots are now independent, so all recipes land.
      final ids = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'];
      final mealTypes = {
        'r1': 'Middag',
        'r2': 'Middag',
        'r3': 'Middag',
        'r4': 'Middag',
        'r5': 'Lunch',
        'r6': 'Frukost', // -> MealSlot.ovrigt
      };
      var created = 0;
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
      ).thenAnswer(
        (_) async => created < ids.length ? ids[created++] : null,
      );
      for (final id in ids) {
        when(
          () => mockRecipeService.getRecipeById(id),
        ).thenReturn(recipeWith(id, mealTypes[id]!));
      }
      wireRealAdderOnEmptyWeek();

      await viewModel.completeOnboarding();

      final savedPlan =
          verify(() => mockMenuService.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      final placedIds = savedPlan.entries.map((e) => e.recipeId).toSet();
      expect(
        placedIds,
        containsAll(ids),
        reason:
            'no seeded recipe may be silently dropped — every recipe, '
            'including the Frukost->övrigt one, must be placed',
      );
      // The Frukost recipe must land specifically in the övrigt bucket.
      final ovrigtIds = savedPlan.entries
          .where((e) => e.slot == MealSlot.ovrigt)
          .map((e) => e.recipeId)
          .toSet();
      expect(
        ovrigtIds,
        contains('r6'),
        reason: 'a Frukost recipe routes to MealSlot.ovrigt',
      );
    });

    test('recipes whose createPersonalRecipe returns null are excluded from '
        'the seeded menu', () async {
      // The first seed persists (id "ok"), the rest mint null. Only the
      // non-null id may reach the menu — id != null is the BUT-930 filter.
      var call = 0;
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
      ).thenAnswer((_) async => (call++ == 0) ? 'ok' : null);
      when(
        () => mockRecipeService.getRecipeById('ok'),
      ).thenReturn(recipeWith('ok', 'Middag'));
      wireRealAdderOnEmptyWeek();

      await viewModel.completeOnboarding();

      final savedPlan =
          verify(() => mockMenuService.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(
        savedPlan.entries.map((e) => e.recipeId),
        ['ok'],
        reason: 'null-id seeds must not be placed in the sample menu',
      );
      // getRecipeById must never be asked for a null id.
      verifyNever(() => mockRecipeService.getRecipeById('null'));
    });

    test(
      'no recipes seeded → menu seeding is skipped entirely (no readWeek, no '
      'menu_seeded event)',
      () async {
        // Every seed fails to persist, so seededRecipeIds is empty and
        // _seedSampleMenu returns before touching any menu service.
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
        ).thenAnswer((_) async => null);

        final result = await viewModel.completeOnboarding();

        expect(result, isTrue, reason: 'onboarding still completes');
        verifyNever(() => mockMenuService.readWeek(any()));
        verifyNever(() => mockMenuService.save(any()));
        verifyNever(
          () => mockAnalyticsService.logEvent(
            name: 'onboarding_menu_seeded',
            parameters: any(named: 'parameters'),
          ),
        );
      },
    );

    test('a FAILED read seeds nothing — the idempotency guard cannot see it '
        '(BUT-1939)', () async {
      // The guard below the read is `if (plan.isNotEmpty) return;`. A failed
      // read used to arrive as an EMPTY plan, so the guard did not fire.
      // `addEntry` is the load-bearing stub: without it the mutant path throws
      // MissingStubError into `_seedSampleMenu`'s outer catch and the test
      // passes without the guard doing anything. `createPersonalRecipe` and
      // `getRecipeById` are already stubbed in setUp.
      when(
        () => mockMenuService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer(
        (inv) => inv.namedArguments[#plan] as WeeklyMenuPlan,
      );
      when(() => mockMenuService.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan(), readFailed: true),
      );

      await viewModel.completeOnboarding();

      verify(() => mockMenuService.readWeek(any())).called(1);
      verifyNever(() => mockMenuService.save(any()));
      verifyNever(() => mockShoppingGenerator.generateForWeek(any()));
      verifyNever(
        () => mockAnalyticsService.logEvent(
          name: 'onboarding_menu_seeded',
          parameters: any(named: 'parameters'),
        ),
      );
    });

    test('a save failure inside menu seeding does not fail onboarding '
        '(best-effort)', () async {
      when(
        () => mockMenuService.readWeek(any()),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan(), readFailed: false),
      );
      final realAdder = WeeklyMenuPlanService(
        repository: _NoopMenuRepo(),
        userService: mockUserService,
      );
      when(
        () => mockMenuService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer(
        (inv) => realAdder.addEntry(
          plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
          day: inv.namedArguments[#day] as DayOfWeek,
          slot: inv.namedArguments[#slot] as MealSlot,
          recipe: inv.namedArguments[#recipe] as Recipe,
        ),
      );
      when(
        () => mockMenuService.save(any()),
      ).thenThrow(Exception('menu write failed'));

      final result = await viewModel.completeOnboarding();

      expect(
        result,
        isTrue,
        reason:
            'menu seeding is best-effort; its failure must not block '
            'onboarding completion',
      );
      // The shopping generator runs only after a successful save, so a save
      // failure must short-circuit before it.
      verifyNever(() => mockShoppingGenerator.generateForWeek(any()));
    });
  });
}

// Minimal in-memory repo so a real WeeklyMenuPlanService can run addEntry()
// purely in memory inside the test (addEntry never touches the repo).
class _NoopMenuRepo implements WeeklyMenuPlanRepository {
  @override
  Future<WeeklyMenuPlan?> fetchForWeek({
    required String userId,
    required DateTime weekStart,
  }) async => null;

  @override
  Future<void> save(WeeklyMenuPlan plan) async {}

  @override
  Future<int> deleteAllByUser(String userId) async => 0;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 260,
  }) async => const [];

  @override
  Future<int> removeRecipeFromAllPlans({
    required String userId,
    required String recipeId,
  }) async => 0;
}

WeeklyMenuPlan realPlanWithOneEntry() {
  final base = WeeklyMenuPlan.empty(userId: 'u1', date: DateTime(2026, 6, 8));
  return base.copyWith(
    entries: [
      WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'existing',
        recipeTitle: 'redan här',
      ),
    ],
  );
}
