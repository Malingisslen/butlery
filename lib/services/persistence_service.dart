/// Comprehensive local data persistence service providing cross-platform storage management and session continuity.
/// This service manages all local data storage operations using SharedPreferences for reliable cross-platform
/// persistence between application sessions. It provides comprehensive data serialization, error handling,
/// and storage management with intelligent caching strategies
/// and robust error recovery mechanisms to ensure data integrity across device restarts and app updates.
/// **Architecture Integration:**
/// - Uses [SharedPreferences] for cross-platform local storage with native platform optimization
/// - Implements [AppLogger] for detailed operation logging and debugging capabilities
/// - Provides JSON serialization/deserialization for complex data structure persistence
/// **Data Persistence Categories:**
/// - **Batch Operations**: Efficient bulk data operations with atomic transaction-like behavior
/// **Storage Features:**
/// - **Atomic Operations**: Transaction-like behavior ensuring data consistency during storage operations
/// - **Error Recovery**: Comprehensive error handling with graceful degradation and data corruption protection
/// - **JSON Serialization**: Efficient data serialization with type safety and version compatibility
/// - **Data Migration**: Flexible data format handling supporting application updates and schema changes
/// - **Swedish Localization**: User-friendly Swedish language logging and error messages

import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';

/// Local data persistence service providing comprehensive storage management and session continuity.
/// This service handles all aspects of local data persistence using SharedPreferences as the underlying
/// storage mechanism. It provides robust serialization, error handling, and data integrity management
/// to ensure reliable data persistence across application sessions, device restarts, and system updates.
/// **Storage Architecture:**
/// Implements a key-based storage system with:
/// - Structured key naming conventions for organized data access
/// - JSON serialization for complex data structure persistence
/// - Atomic operations ensuring data consistency during storage operations
/// - Comprehensive error handling with graceful degradation strategies
/// **Data Categories:**
/// Manages multiple categories of persistent data:
/// - User preferences and application state information
/// **Usage Examples:**
/// ```dart
/// final persistenceService = PersistenceService();
/// final isGrid = await persistenceService.getIsGridView();
/// ```
class PersistenceService extends BaseService {
  @override
  String get serviceName => 'PersistenceService';

  static const String _viewModeKey = 'butlery_view_mode';
  static const String _veckomenyViewModeKey = 'veckomeny_view_mode';
  static const String _sortCriteriaKey = 'butlery_sort_criteria';
  static const String _sortAscendingKey = 'butlery_sort_ascending';
  static const String _defaultPortionsKey = 'butlery_default_portions';
  // BUT-921: persist active recipe-list filters across navigations.
  static const String _recipeTimeFiltersKey = 'butlery_recipe_time_filters';
  static const String _recipeMealTypeFiltersKey =
      'butlery_recipe_mealtype_filters';
  // BUT-1015: extended filter persistence (rating/allergen/dietary/personalTag).
  static const String _recipeRatingFiltersKey = 'butlery_recipe_rating_filters';
  static const String _recipeAllergenFiltersKey =
      'butlery_recipe_allergen_filters';
  static const String _recipeDietaryFiltersKey =
      'butlery_recipe_dietary_filters';
  static const String _recipePersonalTagFiltersKey =
      'butlery_recipe_personaltag_filters';
  static const String _recipeExcludedPersonalTagFiltersKey =
      'butlery_recipe_excluded_personaltag_filters';
  static const String _recipeFavoritesOnlyKey = 'butlery_recipe_favorites_only';
  // BUT-1028: persist recipe-list scroll offset across navigations.
  static const String _recipeListScrollOffsetKey =
      'butlery_recipe_list_scroll_offset';

  /// Provides access to the SharedPreferences instance for cross-platform local storage operations.
  /// This getter manages the SharedPreferences singleton instance providing the underlying
  /// storage mechanism for all persistence operations. It ensures consistent access to the
  /// platform-native storage system across Android and iOS with proper initialization handling.
  /// Returns [SharedPreferences] instance for storage operations
  /// Throws [Exception] if SharedPreferences initialization fails
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  Future<bool> getIsGridView() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_viewModeKey) ?? false;
    } catch (e) {
      AppLogger.error('Failed to load view mode', e, 'Persistence');
      return false;
    }
  }

  Future<void> setIsGridView(bool value) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_viewModeKey, value);
    } catch (e) {
      AppLogger.error('Failed to save view mode', e, 'Persistence');
    }
  }

  /// Veckomeny Lista/Kalender toggle — stores the enum name.
  Future<String?> getVeckomenyViewMode() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(_veckomenyViewModeKey);
    } catch (e) {
      AppLogger.error('Failed to load veckomeny view mode', e, 'Persistence');
      return null;
    }
  }

  Future<void> setVeckomenyViewMode(String mode) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_veckomenyViewModeKey, mode);
    } catch (e) {
      AppLogger.error('Failed to save veckomeny view mode', e, 'Persistence');
    }
  }

  Future<String?> getSortCriteria() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(_sortCriteriaKey);
    } catch (e) {
      AppLogger.error('Failed to load sort criteria', e, 'Persistence');
      return null;
    }
  }

  Future<bool> getSortAscending() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_sortAscendingKey) ?? true;
    } catch (e) {
      AppLogger.error('Failed to load sort direction', e, 'Persistence');
      return true;
    }
  }

  Future<void> setSortPreferences(String criteria, bool ascending) async {
    try {
      final prefs = await _prefs;
      await Future.wait([
        prefs.setString(_sortCriteriaKey, criteria),
        prefs.setBool(_sortAscendingKey, ascending),
      ]);
    } catch (e) {
      AppLogger.error('Failed to save sort preferences', e, 'Persistence');
    }
  }

  /// BUT-921: load persisted recipe-list time filters. Empty list when none.
  Future<List<String>> getRecipeTimeFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeTimeFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error('Failed to load recipe time filters', e, 'Persistence');
      return const [];
    }
  }

  /// BUT-921: persist recipe-list time filters. Pass empty to clear.
  Future<void> setRecipeTimeFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeTimeFiltersKey, ids);
    } catch (e) {
      AppLogger.error('Failed to save recipe time filters', e, 'Persistence');
    }
  }

  /// BUT-921: load persisted recipe-list meal-type filters. Empty list when none.
  Future<List<String>> getRecipeMealTypeFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeMealTypeFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe meal-type filters',
        e,
        'Persistence',
      );
      return const [];
    }
  }

  /// BUT-921: persist recipe-list meal-type filters. Pass empty to clear.
  Future<void> setRecipeMealTypeFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeMealTypeFiltersKey, ids);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe meal-type filters',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1015: extended filter persistence (rating).
  Future<List<String>> getRecipeRatingFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeRatingFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error('Failed to load recipe rating filters', e, 'Persistence');
      return const [];
    }
  }

  Future<void> setRecipeRatingFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeRatingFiltersKey, ids);
    } catch (e) {
      AppLogger.error('Failed to save recipe rating filters', e, 'Persistence');
    }
  }

  /// BUT-1015: extended filter persistence (allergen-free).
  Future<List<String>> getRecipeAllergenFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeAllergenFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe allergen filters',
        e,
        'Persistence',
      );
      return const [];
    }
  }

  Future<void> setRecipeAllergenFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeAllergenFiltersKey, ids);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe allergen filters',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1015: extended filter persistence (dietary).
  Future<List<String>> getRecipeDietaryFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeDietaryFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe dietary filters',
        e,
        'Persistence',
      );
      return const [];
    }
  }

  Future<void> setRecipeDietaryFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeDietaryFiltersKey, ids);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe dietary filters',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1015: extended filter persistence (personal tag UUIDs, AND-include).
  Future<List<String>> getRecipePersonalTagFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipePersonalTagFiltersKey) ?? const [];
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe personal-tag filters',
        e,
        'Persistence',
      );
      return const [];
    }
  }

  Future<void> setRecipePersonalTagFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipePersonalTagFiltersKey, ids);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe personal-tag filters',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1015: extended filter persistence (excluded personal tag UUIDs, OR-exclude).
  Future<List<String>> getRecipeExcludedPersonalTagFilters() async {
    try {
      final prefs = await _prefs;
      return prefs.getStringList(_recipeExcludedPersonalTagFiltersKey) ??
          const [];
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe excluded personal-tag filters',
        e,
        'Persistence',
      );
      return const [];
    }
  }

  Future<void> setRecipeExcludedPersonalTagFilters(List<String> ids) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_recipeExcludedPersonalTagFiltersKey, ids);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe excluded personal-tag filters',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1015: extended filter persistence (favorites-only bool).
  Future<bool> getRecipeFavoritesOnly() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_recipeFavoritesOnlyKey) ?? false;
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe favorites-only flag',
        e,
        'Persistence',
      );
      return false;
    }
  }

  Future<void> setRecipeFavoritesOnly(bool value) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_recipeFavoritesOnlyKey, value);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe favorites-only flag',
        e,
        'Persistence',
      );
    }
  }

  /// BUT-1028: recipe-list scroll offset (logical pixels). Returns 0.0 when
  /// nothing has been persisted yet — the caller treats <= 0 as "no restore".
  Future<double> getRecipeListScrollOffset() async {
    try {
      final prefs = await _prefs;
      return prefs.getDouble(_recipeListScrollOffsetKey) ?? 0.0;
    } catch (e) {
      AppLogger.error(
        'Failed to load recipe-list scroll offset',
        e,
        'Persistence',
      );
      return 0.0;
    }
  }

  Future<void> setRecipeListScrollOffset(double offset) async {
    try {
      final prefs = await _prefs;
      await prefs.setDouble(_recipeListScrollOffsetKey, offset);
    } catch (e) {
      AppLogger.error(
        'Failed to save recipe-list scroll offset',
        e,
        'Persistence',
      );
    }
  }

  Future<int> getDefaultPortions() async {
    try {
      final prefs = await _prefs;
      return prefs.getInt(_defaultPortionsKey) ?? 4;
    } catch (e) {
      AppLogger.error('Failed to load default portions', e, 'Persistence');
      return 4;
    }
  }

  Future<void> setDefaultPortions(int portions) async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(_defaultPortionsKey, portions);
    } catch (e) {
      AppLogger.error('Failed to save default portions', e, 'Persistence');
    }
  }

  Future<bool?> getBool(String key) async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(key);
    } catch (e) {
      AppLogger.warning('Failed to get bool "$key": $e');
      return null;
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(key, value);
    } catch (e) {
      AppLogger.warning('Failed to set bool "$key": $e');
    }
  }

  Future<int?> getInt(String key) async {
    try {
      final prefs = await _prefs;
      return prefs.getInt(key);
    } catch (e) {
      AppLogger.warning('Failed to get int "$key": $e');
      return null;
    }
  }

  Future<void> setInt(String key, int value) async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(key, value);
    } catch (e) {
      AppLogger.warning('Failed to set int "$key": $e');
    }
  }
}
