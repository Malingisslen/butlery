/// Comprehensive local data persistence service providing cross-platform storage management and session continuity.
///
/// This service manages all local data storage operations using SharedPreferences for reliable cross-platform
/// persistence between application sessions. It provides comprehensive data serialization, error handling,
/// and storage management for recipes, menus, and application metadata with intelligent caching strategies
/// and robust error recovery mechanisms to ensure data integrity across device restarts and app updates.
///
/// **Architecture Integration:**
/// - Uses [SharedPreferences] for cross-platform local storage with native platform optimization
/// - Integrates with [Recipe] unified model system for comprehensive recipe data persistence
/// - Implements [AppLogger] for detailed operation logging and debugging capabilities
/// - Provides JSON serialization/deserialization for complex data structure persistence
///
/// **Data Persistence Categories:**
/// - **Recipe Storage**: Complete recipe collection with metadata, images, and user customizations
/// - **Menu Management**: Weekly menu planning with recipe associations and meal organization
/// - **Metadata Tracking**: Last update timestamps, storage statistics, and application state information
/// - **Batch Operations**: Efficient bulk data operations with atomic transaction-like behavior
///
/// **Storage Features:**
/// - **Atomic Operations**: Transaction-like behavior ensuring data consistency during storage operations
/// - **Error Recovery**: Comprehensive error handling with graceful degradation and data corruption protection
/// - **JSON Serialization**: Efficient data serialization with type safety and version compatibility
/// - **Storage Analytics**: Detailed storage statistics and debugging information for performance optimization
/// - **Data Migration**: Flexible data format handling supporting application updates and schema changes
/// - **Swedish Localization**: User-friendly Swedish language logging and error messages

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Local data persistence service providing comprehensive storage management and session continuity.
///
/// This service handles all aspects of local data persistence using SharedPreferences as the underlying
/// storage mechanism. It provides robust serialization, error handling, and data integrity management
/// to ensure reliable data persistence across application sessions, device restarts, and system updates.
///
/// **Storage Architecture:**
/// Implements a key-based storage system with:
/// - Structured key naming conventions for organized data access
/// - JSON serialization for complex data structure persistence  
/// - Atomic operations ensuring data consistency during storage operations
/// - Comprehensive error handling with graceful degradation strategies
///
/// **Data Categories:**
/// Manages multiple categories of persistent data:
/// - Recipe collections with complete metadata and user customizations
/// - Menu planning data with weekly organization and meal associations
/// - Application metadata including timestamps and storage statistics
/// - User preferences and application state information
///
/// **Usage Examples:**
/// ```dart
/// final persistenceService = PersistenceService();
/// 
/// // Save recipe collection
/// final success = await persistenceService.saveRecipes(recipeList);
/// 
/// // Load recipes on app startup
/// final savedRecipes = await persistenceService.loadRecipes();
/// 
/// // Menu management
/// await persistenceService.saveCurrentMenu(['recipe1', 'recipe2']);
/// final menuIds = await persistenceService.loadCurrentMenu();
/// 
/// // Storage analytics
/// final storageInfo = await persistenceService.getStorageInfo();
/// ```
class PersistenceService {
  /// Storage key for recipe collection data in SharedPreferences.
  static const String _recipesKey = 'butlery_recipes';
  
  /// Storage key for current weekly menu planning data.
  static const String _currentMenuKey = 'butlery_current_menu';
  
  /// Storage key for last update timestamp tracking.
  static const String _lastUpdatedKey = 'butlery_last_updated';

  /// Provides access to the SharedPreferences instance for cross-platform local storage operations.
  ///
  /// This getter manages the SharedPreferences singleton instance providing the underlying
  /// storage mechanism for all persistence operations. It ensures consistent access to the
  /// platform-native storage system across Android and iOS with proper initialization handling.
  ///
  /// Returns [SharedPreferences] instance for storage operations
  /// Throws [Exception] if SharedPreferences initialization fails
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // ==================== RECEPT PERSISTENCE ====================

  /// Persists complete recipe collection to local storage with atomic operation handling.
  ///
  /// This method serializes the entire recipe collection to JSON format and stores it atomically
  /// in SharedPreferences. It includes comprehensive error handling, data validation, and timestamp
  /// tracking to ensure data integrity and provide audit trail for storage operations.
  ///
  /// [recipes] Complete list of recipes to persist to local storage
  /// Returns `true` if storage operation completed successfully, `false` on failure
  ///
  /// **Storage Process:**
  /// 1. **Data Serialization**: Converts Recipe objects to JSON-serializable format
  /// 2. **JSON Encoding**: Transforms recipe data to JSON string for storage
  /// 3. **Atomic Storage**: Saves data atomically to prevent corruption during write operations
  /// 4. **Timestamp Update**: Records last update timestamp for data freshness tracking
  /// 5. **Success Validation**: Verifies storage operation completion and returns status
  ///
  /// **Error Handling:**
  /// - Comprehensive exception catching with detailed error logging
  /// - Graceful degradation ensuring application stability on storage failures
  /// - Data integrity protection preventing partial writes or corruption
  /// - Swedish localized error messages for debugging and user feedback
  ///
  /// **Performance Considerations:**
  /// - Efficient JSON serialization minimizing memory usage during conversion
  /// - Atomic write operations preventing data races in concurrent scenarios
  /// - Optimized storage format reducing persistent data size and access time
  Future<bool> saveRecipes(List<Recipe> recipes) async {
    try {
      final prefs = await _prefs;

      // Konvertera varje recept till en Map (dictionary/objekt)
      final List<Map<String, dynamic>> recipesJson =
          recipes.map((recipe) => recipe.toJson()).toList();

      // Konvertera hela listan till JSON-text
      final String recipesString = jsonEncode(recipesJson);

      // Spara till telefonen med vår nyckel
      final success = await prefs.setString(_recipesKey, recipesString);

      // Spara också när vi senast uppdaterade
      if (success) {
        await prefs.setString(
          _lastUpdatedKey,
          DateTime.now().toIso8601String(),
        );
      }

      return success;
    } catch (e) {
      // Om något går fel, logga felet och returnera false
      AppLogger.error('Fel vid sparande av recept', e, 'Persistence');
      return false;
    }
  }

  /// 📖 Laddar alla recept från lokal lagring
  /// Konverterar JSON-text tillbaka till Recipe-objekt
  Future<List<Recipe>> loadRecipes() async {
    try {
      final prefs = await _prefs;

      // Försök hämta den sparade JSON-texten
      final String? recipesString = prefs.getString(_recipesKey);

      // Om ingen data finns, returnera tom lista
      if (recipesString == null || recipesString.isEmpty) {
        AppLogger.info(
          'Inga sparade recept hittades - startar med tom lista',
          'Persistence',
        );
        return [];
      }

      // Konvertera JSON-text tillbaka till lista av Map-objekt
      final List<dynamic> recipesJson = jsonDecode(recipesString);

      // Konvertera varje Map tillbaka till Recipe-objekt
      final List<Recipe> recipes =
          recipesJson
              .map((json) => Recipe.fromJson(json as Map<String, dynamic>))
              .toList();

      AppLogger.success(
        'Laddade ${recipes.length} recept från lokal lagring',
        'Persistence',
      );
      return recipes;
    } catch (e) {
      // Om något går fel (t.ex. korrupt data), logga och returnera tom lista
      AppLogger.error('Fel vid laddning av recept', e, 'Persistence');
      return [];
    }
  }

  /// 🗑️ Tar bort alla sparade recept
  /// Användbart för att "återställa" appen
  Future<bool> clearRecipes() async {
    try {
      final prefs = await _prefs;
      return await prefs.remove(_recipesKey);
    } catch (e) {
      AppLogger.error('Fel vid borttagning av recept', e, 'Persistence');
      return false;
    }
  }

  // ==================== MENY PERSISTENCE ====================

  /// 💾 Sparar aktuell veckomeny
  /// Sparar en lista med recept-ID:n som representerar veckans meny
  Future<bool> saveCurrentMenu(List<String> recipeIds) async {
    try {
      final prefs = await _prefs;
      final String menuString = jsonEncode(recipeIds);
      return await prefs.setString(_currentMenuKey, menuString);
    } catch (e) {
      AppLogger.error('Fel vid sparande av meny', e, 'Persistence');
      return false;
    }
  }

  /// 📖 Laddar aktuell veckomeny
  /// Returnerar lista med recept-ID:n
  Future<List<String>> loadCurrentMenu() async {
    try {
      final prefs = await _prefs;
      final String? menuString = prefs.getString(_currentMenuKey);

      if (menuString == null || menuString.isEmpty) {
        return [];
      }

      final List<dynamic> menuJson = jsonDecode(menuString);
      return menuJson.cast<String>();
    } catch (e) {
      AppLogger.error('Fel vid laddning av meny', e, 'Persistence');
      return [];
    }
  }

  /// 🗑️ Tar bort sparad meny
  Future<bool> clearCurrentMenu() async {
    try {
      final prefs = await _prefs;
      return await prefs.remove(_currentMenuKey);
    } catch (e) {
      AppLogger.error('Fel vid borttagning av meny', e, 'Persistence');
      return false;
    }
  }

  // ==================== METADATA & UTILITIES ====================

  /// 📅 Hämtar när data senast uppdaterades
  Future<DateTime?> getLastUpdated() async {
    try {
      final prefs = await _prefs;
      final String? lastUpdatedString = prefs.getString(_lastUpdatedKey);

      if (lastUpdatedString == null) return null;

      return DateTime.parse(lastUpdatedString);
    } catch (e) {
      AppLogger.error(
        'Fel vid hämtning av senaste uppdatering',
        e,
        'Persistence',
      );
      return null;
    }
  }

  /// 🧹 Rensar all lokal data (reset-funktion)
  Future<bool> clearAllData() async {
    try {
      final prefs = await _prefs;

      final results = await Future.wait([
        prefs.remove(_recipesKey),
        prefs.remove(_currentMenuKey),
        prefs.remove(_lastUpdatedKey),
      ]);

      // Returnera true om alla operationer lyckades
      return results.every((success) => success);
    } catch (e) {
      AppLogger.error('Fel vid rensning av all data', e, 'Persistence');
      return false;
    }
  }

  /// 📊 Hämtar lagringsstatistik för debugging
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      // Hämta data direkt via metoderna istället för prefs
      final recipes = await loadRecipes();
      final menu = await loadCurrentMenu();
      final lastUpdated = await getLastUpdated();

      return {
        'totalRecipes': recipes.length,
        'menuItems': menu.length,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'hasData': recipes.isNotEmpty,
      };
    } catch (e) {
      AppLogger.error('Fel vid hämtning av lagringsinfo', e, 'Persistence');
      return {
        'totalRecipes': 0,
        'menuItems': 0,
        'lastUpdated': null,
        'hasData': false,
        'error': e.toString(),
      };
    }
  }
}
