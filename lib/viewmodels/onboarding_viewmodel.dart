/// ViewModel for the onboarding wizard flow.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';

class OnboardingViewModel extends ChangeNotifier {
  // Swedish parental-consent threshold for data processing on social apps
  // (GDPR Art 8). Under this, sign-up is blocked.
  static const int minAgeYears = 15;

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
  })  : _currentPage = 0,
        _progressService = progressService,
        _userId = userId;

  int _currentPage;
  final Set<String> _selectedAllergens = {};
  final Set<String> _selectedDietaryPrefs = {};
  int? _selectedBirthYear;
  bool _isCompleting = false;
  bool _started = false;
  // BUT-545: tracks whether the onboarding import page actually landed a
  // recipe, so [completeOnboarding] can fire `onboarding_import_skipped`
  // when the user advances past the import page without importing.
  bool _onboardingImportSucceeded = false;
  late final AnalyticsService? _analytics =
      ServiceLocator.tryGet<AnalyticsService>();

  int get currentPage => _currentPage;
  Set<String> get selectedAllergens => Set.unmodifiable(_selectedAllergens);
  Set<String> get selectedDietaryPrefs =>
      Set.unmodifiable(_selectedDietaryPrefs);
  int? get selectedBirthYear => _selectedBirthYear;
  bool get isCompleting => _isCompleting;
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
    return DateTime.now().year - _selectedBirthYear!;
  }

  bool get isAgeGatePassed {
    final age = computedAge;
    return age != null && age >= minAgeYears;
  }

  void setBirthYear(int? year) {
    _selectedBirthYear = year;
    notifyListeners();
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
    _analytics?.logEvent(
      name: AnalyticsEvents.onboardingPageViewed,
      parameters: {'page': _currentPage},
    );
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
    _isCompleting = true;
    notifyListeners();

    try {
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
      await userService.completeOnboardingWithPreferences(
        prefs,
        onboardingSkippedAt: isSkip ? DateTime.now() : null,
        birthYear: _selectedBirthYear,
      );

      // BUT-675: stamp `completed: true` on the progress doc so AuthWrapper
      // routes home (not back into onboarding) on the next cold start.
      if (_progressService != null && _userId != null) {
        unawaited(_progressService.markStepComplete(
          userId: _userId,
          step: OnboardingStep.firstRecipe,
          isFinalStep: true,
        ));
      }

      // Seed starter recipes for new users (fire-and-forget, never blocks onboarding)
      _seedStarterRecipes();

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
      _isCompleting = false;
      notifyListeners();
    }
  }

  /// Seeds starter recipes so new users don't see an empty app.
  /// Runs in the background — failures are logged but never surface to the user.
  Future<void> _seedStarterRecipes() async {
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final seeds = RecipeSeeds.allRecipes;

      for (final seed in seeds) {
        try {
          await recipeService.createPersonalRecipe(
            title: seed.core.title,
            description: seed.core.description,
            ingredients: seed.core.ingredients,
            instructions: seed.core.instructions,
            mealType: seed.core.mealType,
            portions: seed.core.portions,
            timeMinutes: seed.core.timeMinutes,
            sourceUrl: 'Butlery starter recipes',
          );
        } catch (e) {
          AppLogger.warning('Failed to seed recipe "${seed.core.title}": $e');
        }
      }

      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingRecipesSeeded,
        parameters: {'count': seeds.length},
      );
      AppLogger.info('Seeded ${seeds.length} starter recipes');

      // BUT-618: stamp `first_recipe_source = 'seed'` if this is the user's
      // first recipe surface. Dedupe is handled inside the helper.
      final userService = ServiceLocator.tryGet<UserService>();
      await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: _analytics,
        userId: userService?.currentUserId,
        source: 'seed',
      );
    } catch (e) {
      AppLogger.warning('Failed to seed starter recipes: $e');
    }
  }
}
