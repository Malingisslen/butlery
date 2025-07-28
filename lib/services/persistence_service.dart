// lib/services/persistence_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// 💾 PERSISTENCE SERVICE - HANTERAR LOKAL DATALAGRING
///
/// Denna klass sköter all lagring av data mellan app-sessioner.
/// Använder SharedPreferences för att spara data lokalt på telefonen.
class PersistenceService {
  // Nycklar för att identifiera olika data i lagringen
  static const String _recipesKey = 'butlery_recipes';
  static const String _currentMenuKey = 'butlery_current_menu';
  static const String _lastUpdatedKey = 'butlery_last_updated';

  /// 📱 Hämtar SharedPreferences instansen
  /// Detta är "dörren" till telefonens lokala lagring
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // ==================== RECEPT PERSISTENCE ====================

  /// 💾 Sparar alla recept till lokal lagring
  /// Konverterar Recipe-objekt till JSON-text som kan sparas
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
