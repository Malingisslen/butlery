/// ViewModel for the onboarding wizard flow.
import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';

class OnboardingViewModel extends ChangeNotifier {
  int _currentPage = 0;
  final Set<String> _selectedAllergens = {};
  final Set<String> _selectedDietaryPrefs = {};
  bool _isCompleting = false;
  bool _started = false;
  late final AnalyticsService? _analytics =
      ServiceLocator.tryGet<AnalyticsService>();

  int get currentPage => _currentPage;
  Set<String> get selectedAllergens => Set.unmodifiable(_selectedAllergens);
  Set<String> get selectedDietaryPrefs =>
      Set.unmodifiable(_selectedDietaryPrefs);
  bool get isCompleting => _isCompleting;
  static const int _lastPageIndex = 3;
  bool get isLastPage => _currentPage == _lastPageIndex;
  bool get isFirstPage => _currentPage == 0;

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
    } catch (e) {
      AppLogger.warning('Failed to seed starter recipes: $e');
    }
  }
}
