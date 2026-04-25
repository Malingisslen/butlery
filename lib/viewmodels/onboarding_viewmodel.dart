/// ViewModel for the onboarding wizard flow.
import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';

class OnboardingViewModel extends ChangeNotifier {
  // Swedish parental-consent threshold for data processing on social apps
  // (GDPR Art 8). Under this, sign-up is blocked.
  static const int minAgeYears = 15;

  int _currentPage = 0;
  final Set<String> _selectedAllergens = {};
  final Set<String> _selectedDietaryPrefs = {};
  int? _selectedBirthYear;
  bool _isCompleting = false;
  bool _started = false;
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

  void setPage(int page) {
    if (!_started) {
      _started = true;
      _analytics?.logEvent(name: 'onboarding_started');
    }
    _currentPage = page;
    _analytics?.logEvent(
      name: 'onboarding_page_viewed',
      parameters: {'page': _currentPage},
    );
    notifyListeners();
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

      // Seed starter recipes for new users (fire-and-forget, never blocks onboarding)
      _seedStarterRecipes();

      if (isSkip) {
        _analytics?.logEvent(
          name: 'onboarding_skipped',
          parameters: {'skipped_at_page': _currentPage},
        );
      } else {
        _analytics?.logEvent(
          name: 'onboarding_completed',
          parameters: {
            'allergen_count': _selectedAllergens.length,
            'dietary_count': _selectedDietaryPrefs.length,
          },
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
        name: 'onboarding_recipes_seeded',
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
