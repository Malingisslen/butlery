/// ViewModel for the onboarding wizard flow.

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Outcome of the server-side age check run when the user advances past the
/// age-gate page (BUT-1386). The view branches on this to allow advancing,
/// route the under-15 rejection to start, or surface a retry error.
enum AgeGateAdvanceResult {
  /// CF accepted the year: the `ageCompliant` claim is minted and the token
  /// refreshed server-side. The user may advance past the gate.
  compliant,

  /// CF rejected the account as under-15 and has ALREADY deleted the Auth
  /// record. The view shows the butler-voice rejection and routes to start.
  rejected,

  /// Infrastructure failure (CF unreachable / timeout / internal). The gate is
  /// NOT passed; the view shows a retry error and keeps the user on page 0.
  error,
}

class OnboardingViewModel extends BaseViewModel {
  // Butlery's single minimum age. Basis: Sweden's Dataskyddslag 2 kap. 4 §
  // (information-society services with a *social* component) sets 15 — NOT
  // GDPR Art 8, whose Swedish floor is 13 and which does not mandate 15. Under
  // this, sign-up is blocked. See ADR-0001; kept in sync with firestore.rules
  // (settings/preferences) and UserProfile's birthYear invariant.
  static const int minAgeYears = 15;

  // BUT-33: upper bound on the onboarding-completion write so a hung Firebase
  // call surfaces an error (returns false -> the view shows errorGeneric)
  // instead of leaving the user stuck on the spinner indefinitely. Generous
  // enough to tolerate a slow-but-alive network; seeding is best-effort and
  // bounded separately so it can't extend the wait unboundedly either.
  static const Duration _completionTimeout = Duration(seconds: 20);

  /// Optional progress-service hook. When null we skip the persist writes —
  /// keeps existing tests that didn't register the service from breaking.
  final OnboardingProgressService? _progressService;

  /// Current user id, captured at construction so we don't have to thread it
  /// through every step-complete call site.
  final String? _userId;

  // BUT-744: initial page is page-level state, set by the view post-construction
  // via [setInitialPage]. The constructor takes only service-shaped dependencies
  // so the DI factory in ui_module.dart can be the single source of truth.
  OnboardingViewModel({
    OnboardingProgressService? progressService,
    String? userId,
  }) : _currentPage = 0,
       _progressService = progressService,
       _userId = userId;

  int _currentPage;
  final Set<String> _selectedAllergens = {};
  final Set<String> _selectedDietaryPrefs = {};
  int? _selectedBirthYear;
  bool _started = false;
  // BUT-1386 (ADR-0002): set when the verifySignupAge CF rejected the account
  // as under-15 (and has already deleted the Auth record server-side). The
  // view reads this after a false `completeOnboarding` to show the quiet
  // butler-voice rejection and route back to start, rather than the generic
  // retry error used for infrastructure failures.
  bool _ageRejected = false;
  // BUT-1386: set once the gate-advance CF call (verifyAgeGate) has confirmed
  // compliance THIS session, so [completeOnboarding] doesn't redundantly
  // re-call the CF. Stays false on a resumed session (the claim was already
  // minted in the session that passed the gate), which is exactly why the
  // completion belt only fires when a birth year is held this session AND
  // the gate handler hasn't already verified it.
  bool _ageVerifiedThisSession = false;
  // BUT-1454: captured from the verifySignupAge CF response when the gate (or
  // the belt-and-suspenders re-check) confirms compliance this session. A
  // compliant 15–17-year-old is a minor and is stamped onto the profile at
  // completion so `public_profiles.isSearchable` serializes false (default-
  // private search-suppression). Only meaningful once age is verified this
  // session; on a resumed session it stays false and the already-persisted
  // server value on the profile carries the minor status instead.
  bool _isMinor = false;
  // BUT-545: tracks whether the onboarding import page actually landed a
  // recipe, so [completeOnboarding] can fire `onboarding_import_skipped`
  // when the user advances past the import page without importing.
  bool _onboardingImportSucceeded = false;
  // BUT-538: per-session dedup so onboarding_page_viewed fires once per
  // unique page. Back-nav and skip-jumps no longer inflate funnel drop-off.
  final Set<int> _viewedPages = <int>{};
  late final AnalyticsService? _analytics =
      ServiceLocator.tryGet<AnalyticsService>();

  int get currentPage => _currentPage;
  Set<String> get selectedAllergens => Set.unmodifiable(_selectedAllergens);
  Set<String> get selectedDietaryPrefs =>
      Set.unmodifiable(_selectedDietaryPrefs);
  int? get selectedBirthYear => _selectedBirthYear;
  bool get isCompleting => isLoading;

  /// BUT-1386: true when the last [completeOnboarding] failed because the
  /// server-side age check rejected the account as under-15. Distinguishes the
  /// rejection path (show butler rejection + route to start) from a generic
  /// infrastructure failure (show retry error).
  bool get ageRejected => _ageRejected;
  // Page order: age-gate (0), welcome (1), allergen (2), dietary (3), import (4)
  static const int _lastPageIndex = 4;
  bool get isLastPage => _currentPage == _lastPageIndex;
  bool get isFirstPage => _currentPage == 0;
  bool get isAgeGatePage => _currentPage == 0;

  /// Computed age from selected birth year (using Jan 1 cutoff since we only
  /// have year granularity — this is conservative: we treat people as their
  /// lowest possible age for that year).
  int? get computedAge {
    if (_selectedBirthYear == null) return null;
    return clock.now().year - _selectedBirthYear!;
  }

  bool get isAgeGatePassed {
    final age = computedAge;
    return age != null && age >= minAgeYears;
  }

  // Compliance (GDPR Art 8): the age gate must NOT auto-select a birth year.
  // Pre-seeding an adult default would let anyone — including an under-age
  // child — tap "Next" without ever declaring their age, defeating the gate.
  // `selectedBirthYear` therefore stays null until the user picks explicitly,
  // and the wizard keeps "Next" disabled while it is null.

  void setBirthYear(int? year) {
    _selectedBirthYear = year;
    notifyListeners();
  }

  /// BUT-1386 (ADR-0002): run the server-side age check at the MOMENT the user
  /// passes the age gate (page 0 advance) — NOT at completion. The CF is the
  /// sole age authority and the only writer of `birthYear`; on a compliant
  /// result it mints the `ageCompliant` claim and force-refreshes the token.
  ///
  /// Minting here (rather than at completion) is the fix for the resume bug:
  /// onboarding can span sessions, and `_selectedBirthYear` is in-memory only.
  /// A user who passes the client gate, abandons, and resumes in a later
  /// session re-enters PAST the gate with `_selectedBirthYear == null`, so a
  /// completion-time check would be skipped and the claim never minted. By
  /// minting at the gate, the claim persists server-side and the resumed
  /// session already carries it — no re-verification needed.
  ///
  /// Returns [AgeGateAdvanceResult]; the view decides navigation from it.
  Future<AgeGateAdvanceResult> verifyAgeGate() async {
    final year = _selectedBirthYear;
    // Defensive: the view keeps "Next" disabled until a year is picked, so this
    // should never be null here. Treat a missing year as a non-pass.
    if (year == null) return AgeGateAdvanceResult.error;

    setLoading(true);
    _ageRejected = false;
    try {
      final result = await ServiceLocator.get<AgeVerificationService>()
          .verifyAge(year)
          .timeout(_completionTimeout);
      if (isDisposed) return AgeGateAdvanceResult.error;
      if (!result.compliant) {
        AppLogger.info('Age gate rejected the account as under-15');
        _ageRejected = true;
        return AgeGateAdvanceResult.rejected;
      }
      _ageVerifiedThisSession = true;
      // BUT-1454: remember the minor status so completion can suppress search.
      _isMinor = result.isMinor;
      return AgeGateAdvanceResult.compliant;
    } catch (e) {
      AppLogger.error('Age gate verification failed', e);
      return AgeGateAdvanceResult.error;
    } finally {
      setLoading(false);
    }
  }

  /// Called by [OnboardingImportPage] when an import lands successfully so
  /// the wizard knows not to treat the import page as skipped (BUT-545).
  void markOnboardingImportSucceeded() {
    _onboardingImportSucceeded = true;
  }

  /// Resume jump applied by the view post-construction. Bypasses `setPage`'s
  /// analytics + step-completion side-effects — the user is _arriving_ at
  /// this page (resume), not _finishing_ a previous one.
  void setInitialPage(int page) {
    if (_currentPage == page) return;
    _currentPage = page;
    // Mark resumed page as already viewed so a later setPage(page) doesn't
    // re-fire onboarding_page_viewed when the user navigates back to it.
    _viewedPages.add(page);
    notifyListeners();
  }

  void setPage(int page) {
    if (!_started) {
      _started = true;
      _analytics?.logEvent(name: AnalyticsEvents.onboardingStarted);
    }
    // BUT-675: persist progress when advancing forward. We only mark the
    // step that's being LEFT (the previous _currentPage), since that's the
    // step the user just finished. Backwards/skip-jumps don't downgrade.
    if (page > _currentPage) {
      _persistStepCompletion(_currentPage);
    }
    _currentPage = page;
    if (_viewedPages.add(_currentPage)) {
      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingPageViewed,
        parameters: {'page': _currentPage},
      );
    }
    notifyListeners();
  }

  /// Best-effort persist of the step the user just finished. Fire-and-forget.
  void _persistStepCompletion(int finishedPageIndex) {
    final svc = _progressService;
    final uid = _userId;
    if (svc == null || uid == null) return;
    final step = OnboardingStep.fromPageIndex(finishedPageIndex);
    if (step == null) return;
    // The full-completion (`completed: true`) flag is written from
    // [completeOnboarding]; intermediate steps stay false.
    svc.markStepComplete(
      userId: uid,
      step: step,
      isFinalStep: false,
    );
  }

  void nextPage() {
    if (_currentPage < _lastPageIndex) {
      // BUT-675: persist the step being LEFT here, because the view calls
      // nextPage() (which bumps _currentPage) BEFORE the PageController
      // animation fires onPageChanged -> setPage. By the time setPage(newPage)
      // runs, _currentPage already equals newPage, so setPage's `page >
      // _currentPage` guard is false and would never persist forward nav.
      // Persisting here is the single source of truth for forward progress;
      // setPage's branch still covers programmatic/non-animated jumps.
      _persistStepCompletion(_currentPage);
      _currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      notifyListeners();
    }
  }

  void toggleAllergen(String allergen) {
    if (_selectedAllergens.contains(allergen)) {
      _selectedAllergens.remove(allergen);
    } else {
      _selectedAllergens.add(allergen);
    }
    notifyListeners();
  }

  void toggleDietaryPref(String pref) {
    if (_selectedDietaryPrefs.contains(pref)) {
      _selectedDietaryPrefs.remove(pref);
    } else {
      _selectedDietaryPrefs.add(pref);
    }
    notifyListeners();
  }

  bool isAllergenSelected(String allergen) =>
      _selectedAllergens.contains(allergen);

  bool isDietaryPrefSelected(String pref) =>
      _selectedDietaryPrefs.contains(pref);

  /// Saves preferences and marks onboarding as completed.
  /// Returns true on success.
  Future<bool> completeOnboarding() async {
    setLoading(true);
    _ageRejected = false;

    try {
      // BUT-1386 (ADR-0002): the PRIMARY age mint happens at the gate
      // ([verifyAgeGate]), so a resumed session — which re-enters past the gate
      // with `_selectedBirthYear == null` — already carries the claim and is
      // not re-checked here. This is a belt-and-suspenders only: if a birth
      // year is still held this session but the gate handler never verified it
      // (a path that shouldn't exist — you can't pass page 0 without
      // verifying), re-run the idempotent CF before the onboarding write.
      //   - `false` => under-15: the CF has ALREADY deleted the Auth account.
      //     Flag the rejection and bail BEFORE seeding/marking onboarding done.
      //   - throws => infrastructure failure: return false for a retry error.
      if (_selectedBirthYear != null && !_ageVerifiedThisSession) {
        final AgeVerificationResult ageResult;
        try {
          ageResult = await ServiceLocator.get<AgeVerificationService>()
              .verifyAge(_selectedBirthYear!)
              .timeout(_completionTimeout);
        } catch (e) {
          AppLogger.error('Age verification failed', e);
          return false;
        }
        if (!ageResult.compliant) {
          AppLogger.info('Age verification rejected the account (under-15)');
          _ageRejected = true;
          return false;
        }
        // BUT-1454: capture minor status on this rare belt path too.
        _isMinor = ageResult.isMinor;
      }

      final userService = ServiceLocator.get<UserService>();

      // Save preferences and mark onboarding complete in a single write
      final prefs =
          (_selectedAllergens.isNotEmpty || _selectedDietaryPrefs.isNotEmpty)
          ? UserAllergenPreferences(
              trackedAllergens: _selectedAllergens,
              trackedDietary: _selectedDietaryPrefs,
            )
          : null;
      final isSkip = _currentPage < _lastPageIndex;
      // BUT-33: bound the critical completion write — a hung call must surface
      // an error rather than hang the onboarding spinner forever. A timeout
      // throws TimeoutException, caught below -> returns false.
      await userService
          .completeOnboardingWithPreferences(
            prefs,
            onboardingSkippedAt: isSkip ? clock.now() : null,
            // BUT-1454: stamp the minor flag onto the completion write so the
            // public_profiles doc serializes isSearchable:false immediately.
            isMinor: _isMinor,
          )
          .timeout(_completionTimeout);

      // BUT-675: stamp `completed: true` on the progress doc so AuthWrapper
      // routes home (not back into onboarding) on the next cold start.
      if (_progressService != null && _userId != null) {
        unawaited(
          _progressService.markStepComplete(
            userId: _userId,
            step: OnboardingStep.firstRecipe,
            isFinalStep: true,
          ),
        );
      }

      // BUT-926: await seeding so the spinner stays up until the user has
      // something to land on. Fire-and-forget previously left users arriving
      // at an empty home if the writes hadn't finished. Per-recipe failures
      // are still tolerated inside `_seedStarterRecipes` — only an outer
      // infrastructure error (e.g. UnifiedRecipeService not registered) gets
      // caught by the method's outer try/catch, and that just degrades to
      // zero-seeded silently. Outcome is surfaced via analytics so a
      // post-launch failure-rate is observable.
      final seededRecipeIds = await _seedStarterRecipes();

      // BUT-930: turn the freshly seeded recipes into a sample weekly menu
      // plan plus a matching shopping list, so the new user lands on a
      // populated menu and shopping list instead of two empty screens. Best
      // effort and idempotent — never blocks onboarding completion.
      await _seedSampleMenu(seededRecipeIds);

      if (isSkip) {
        _analytics?.logEvent(
          name: AnalyticsEvents.onboardingSkipped,
          parameters: {'skipped_at_page': _currentPage},
        );
      } else {
        _analytics?.logEvent(
          name: AnalyticsEvents.onboardingCompleted,
          parameters: {
            'allergen_count': _selectedAllergens.length,
            'dietary_count': _selectedDietaryPrefs.length,
          },
        );
      }

      // BUT-545: if the user reached the end of the wizard (skip-to-end
      // counts here too — they did pass through the import step) without
      // a successful import, record the skip so the activation funnel can
      // measure import-page conversion separately from the broader skip.
      if (!_onboardingImportSucceeded) {
        _analytics?.logEvent(
          name: AnalyticsEvents.onboardingImportSkipped,
          parameters: {'completed_via_skip': isSkip},
        );
      }

      AppLogger.success('Onboarding completed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to complete onboarding', e);
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Seeds starter recipes so new users don't see an empty app.
  ///
  /// Awaited from [completeOnboarding] so the onboarding spinner reflects
  /// the true wait. Per-recipe failures are tolerated (logged + counted);
  /// when at least one fails, a typed analytics event surfaces the partial
  /// failure for observability. Outer infrastructure errors (e.g. service
  /// not registered in tests) are swallowed — onboarding must not fail
  /// because seeding can't run.
  ///
  /// Returns the persisted ids of the recipes that seeded successfully, in
  /// seed order — BUT-930 needs these to build the sample menu plan. The
  /// id is taken from [UnifiedRecipeService.createPersonalRecipe]'s return
  /// (the service mints a fresh id; the seed's own id is not the stored one).
  Future<List<String>> _seedStarterRecipes() async {
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final seeds = RecipeSeeds.allRecipes;
      final seededIds = <String>[];

      for (final seed in seeds) {
        try {
          final id = await recipeService.createPersonalRecipe(
            title: seed.core.title,
            description: seed.core.description,
            ingredients: seed.core.ingredients,
            instructions: seed.core.instructions,
            mealType: seed.core.mealType,
            portions: seed.core.portions,
            timeMinutes: seed.core.timeMinutes,
            sourceUrl: 'Butlerys startrecept',
          );
          if (id != null) seededIds.add(id);
        } catch (e) {
          AppLogger.warning('Failed to seed recipe "${seed.core.title}": $e');
        }
      }

      final seeded = seededIds.length;
      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingRecipesSeeded,
        parameters: {'count': seeded, 'attempted': seeds.length},
      );
      final failed = seeds.length - seeded;
      if (failed > 0) {
        _analytics?.logEvent(
          name: AnalyticsEvents.onboardingRecipesSeedFailed,
          parameters: {'failed': failed, 'attempted': seeds.length},
        );
      }
      AppLogger.info('Seeded $seeded/${seeds.length} starter recipes');

      // BUT-618: stamp `first_recipe_source = 'seed'` if this is the user's
      // first recipe surface. Dedupe is handled inside the helper.
      final userService = ServiceLocator.tryGet<UserService>();
      await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: _analytics,
        userId: userService?.currentUserId,
        source: 'seed',
      );
      return seededIds;
    } catch (e) {
      AppLogger.warning('Failed to seed starter recipes: $e');
      return const [];
    }
  }

  /// BUT-930: builds a sample weekly-menu plan from the just-seeded recipes
  /// and generates its shopping list, so a brand-new user opens the menu and
  /// shopping tabs to populated content rather than empty states.
  ///
  /// Best-effort and idempotent, mirroring [_seedStarterRecipes]:
  /// - If the menu/shopping services aren't registered (e.g. unit tests that
  ///   only wire the recipe service) the outer try/catch swallows the lookup
  ///   failure and onboarding still completes.
  /// - The plan is only seeded when the current week is empty — re-running
  ///   onboarding (or a partial retry) never double-stacks entries. The
  ///   shopping-list generator is itself idempotent per ISO week.
  ///
  /// Recipes are routed to the lunch / middag / övrigt slot by their
  /// `mealType`, then placed deterministically into the first free day for
  /// THAT slot. Slots are independent — a lunch and a middag can share Monday —
  /// so placement never silently drops a recipe just because earlier recipes
  /// used up the leading days (the old "one recipe per day across all slots"
  /// walk could discard the breakfast/övrigt recipe). Single-recipe slots
  /// (lunch/middag) hold one per day across the seven days; övrigt is a
  /// multi-recipe bucket that stacks, so it always has room.
  Future<void> _seedSampleMenu(List<String> seededRecipeIds) async {
    if (seededRecipeIds.isEmpty) return;
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final menuService = ServiceLocator.get<WeeklyMenuPlanService>();
      final shoppingGenerator = ServiceLocator.get<MenuShoppingListGenerator>();
      final now = clock.now();

      final read = await menuService.readWeek(now);
      if (read.readFailed) {
        // BUT-1939. `getWeek` returned an empty plan for a week it could not
        // read, so `isNotEmpty` was false and the idempotency guard below did
        // not fire. Refusing is safe — it gates no navigation.
        AppLogger.warning(
          'Sample menu: skipped, the week could not be read',
        );
        return;
      }
      var plan = read.plan;
      // Idempotency: never overwrite or stack onto a plan the user already
      // has for this week (covers onboarding re-entry / partial retries).
      if (plan.isNotEmpty) return;

      // Track the next free day per single-recipe slot so each gets its own
      // Monday→Sunday fill independent of the other slots. Multi slots (övrigt)
      // stack on Monday — they're unbounded so there's no day to run out of.
      final nextDayForSlot = <MealSlot, int>{};
      var placed = 0;
      var dropped = 0;
      for (final recipeId in seededRecipeIds) {
        final recipe = recipeService.getRecipeById(recipeId);
        if (recipe == null) continue;
        final slot = mapMealTypeToSlot(recipe.mealType);

        final int dayIndex;
        if (slot.isMulti) {
          // Multi slot: stack everything on Monday — capacity is unbounded.
          dayIndex = DayOfWeek.mon.index;
        } else {
          // Single slot: take the next free day for this slot specifically.
          dayIndex = nextDayForSlot[slot] ?? DayOfWeek.mon.index;
          if (dayIndex > DayOfWeek.sun.index) {
            // This slot is full across the whole week — skip rather than
            // double-book. With the current seed set this never triggers.
            dropped++;
            continue;
          }
          nextDayForSlot[slot] = dayIndex + 1;
        }

        plan = menuService.addEntry(
          plan: plan,
          day: DayOfWeek.values[dayIndex],
          slot: slot,
          recipe: recipe,
        );
        placed++;
      }

      if (dropped > 0) {
        AppLogger.warning(
          'Sample menu: $dropped seeded recipe(s) had no free single-slot day',
        );
      }
      if (placed == 0) return;
      await menuService.save(plan);

      final shoppingResult = await shoppingGenerator.generateForWeek(now);
      final shoppingItems = shoppingResult?.itemCount ?? 0;

      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingMenuSeeded,
        parameters: {
          'menuEntries': placed,
          'shoppingItems': shoppingItems,
        },
      );
      AppLogger.info(
        'Seeded sample menu: $placed entries, $shoppingItems shopping items',
      );
    } catch (e) {
      AppLogger.warning('Failed to seed sample menu: $e');
    }
  }
}
