/// Intelligent menu generation service with natural language processing and meal planning capabilities.
///
/// This singleton service provides sophisticated menu generation functionality using natural language
/// processing to interpret Swedish meal planning requests and generate optimized weekly menus from
/// available recipes. It implements advanced text parsing, meal type detection, and intelligent
/// recipe selection algorithms for comprehensive meal planning experiences.
///
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns and error handling
/// - Uses [SingletonServiceMixin] for standardized singleton implementation and lifecycle management
/// - Integrates with Recipe models for comprehensive meal planning and menu generation
/// - Provides natural language processing for Swedish meal planning instructions
/// - Coordinates with recipe management system for intelligent menu composition
///
/// **Menu Generation Features:**
/// - **Natural Language Processing**: Sophisticated parsing of Swedish meal planning requests
/// - **Meal Type Detection**: Intelligent detection of meal categories (breakfast, lunch, dinner, etc.)
/// - **Quantity Processing**: Support for both numeric and Swedish word-based quantity specification
/// - **Random Selection**: Intelligent randomization ensuring variety in generated menus
/// - **Flexible Input**: Support for complex meal planning instructions with multiple meal types
/// - **Error Handling**: Graceful handling of invalid or incomplete meal planning requests
///
/// **Swedish Language Support:**
/// - **Word-to-Number Conversion**: Complete support for Swedish numeric words (en, två, tre, etc.)
/// - **Meal Type Recognition**: Swedish meal type keywords with fuzzy matching capabilities
/// - **Complex Parsing**: Support for Swedish conjunctions and meal planning syntax
/// - **Localized Interface**: Swedish-focused natural language processing for authentic user experience

import 'dart:math';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';
/// Singleton menu generation service with advanced natural language processing for Swedish meal planning.
///
/// This service provides comprehensive menu generation capabilities using sophisticated natural language
/// processing to interpret Swedish meal planning requests. It implements intelligent text parsing,
/// meal type detection, and optimized recipe selection for creating varied and balanced weekly menus.
///
/// **Singleton Architecture:**
/// Uses the SingletonServiceMixin pattern for:
/// - Consistent singleton implementation across the application
/// - Memory-efficient single instance management
/// - Standardized service lifecycle and error handling
///
/// **Natural Language Processing:**
/// Implements sophisticated Swedish language processing including:
/// - Numeric word conversion (en, två, tre → 1, 2, 3)
/// - Meal type detection with fuzzy matching
/// - Complex syntax parsing with conjunctions and separators
/// - Error-tolerant input processing with graceful fallbacks
///
/// **Usage Examples:**
/// ```dart
/// final menuService = MenuService();
/// 
/// // Generate menu from Swedish natural language
/// final menu = await menuService.generateMenuFromPrompt(
///   'tre frukoster och två middagar',
///   availableRecipes,
/// );
/// 
/// // Complex meal planning
/// final complexMenu = await menuService.generateMenuFromPrompt(
///   'fem frukoster, tre luncher och fyra middagar',
///   recipeCollection,
/// );
/// ```
class MenuService extends BaseService with SingletonServiceMixin<MenuService> {
  /// Private constructor for singleton pattern implementation.
  MenuService._internal();
  
  /// Factory constructor using SingletonServiceMixin for standardized singleton creation.
  factory MenuService() => SingletonServiceMixin.createSingleton(() => MenuService._internal());
  
  @override
  String get serviceName => 'MenuService';

  /// Generates a weekly menu based on Swedish natural language meal planning instructions.
  ///
  /// This method processes Swedish text input to extract meal planning requirements and generates
  /// an optimized menu by intelligently selecting recipes from the provided collection. It supports
  /// complex meal planning syntax with multiple meal types and quantities.
  ///
  /// [input] Swedish natural language meal planning instructions (e.g., "tre frukoster och två middagar")
  /// [allRecipes] Collection of available recipes to generate the menu from
  /// Returns a map of meal types to selected recipes, empty map if parsing fails
  /// 
  /// **Supported Input Formats:**
  /// - Numeric quantities: "3 frukoster, 2 middagar"
  /// - Swedish word numbers: "tre frukoster, två middagar"
  /// - Complex syntax: "fem frukoster och tre luncher, fyra middagar"
  /// - Multiple separators: commas, "och", "&", semicolons
  /// 
  /// **Example Usage:**
  /// ```dart
  /// final menu = await menuService.generateMenuFromPrompt(
  ///   'tre frukoster och två middagar',
  ///   recipeCollection,
  /// );
  /// // Returns: {'frukost': [recipe1, recipe2, recipe3], 'middag': [recipe4, recipe5]}
  /// ```
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes,
  ) async {
    return await executeServiceOperation(
      () async {
        return _generateMenuFromPromptInternal(input, allRecipes);
      },
      operationName: 'Generate menu from prompt',
      defaultValue: <String, List<Recipe>>{},
      requiresAuth: false,
    ) ?? <String, List<Recipe>>{};
  }

  Map<String, List<Recipe>> _generateMenuFromPromptInternal(
    String input,
    List<Recipe> allRecipes,
  ) {
    if (input.trim().isEmpty) return {};

    // Tillgängliga måltidstyper
    final types = <String>{for (var r in allRecipes) r.mealType};

    // Svenska talord
    final word2num = <String, int>{
      'en': 1,
      'ett': 1,
      'två': 2,
      'tre': 3,
      'fyra': 4,
      'fem': 5,
      'sex': 6,
      'sju': 7,
      'åtta': 8,
      'nio': 9,
      'tio': 10,
    };

    int? parseNumber(String s) => int.tryParse(s) ?? word2num[s];

    // Dela prompt på kommatecken, 'och', '&' eller ';'
    final parts = input.toLowerCase().split(RegExp(r'[,&;]| och | & '));
    final counts = <String, int>{};

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      // Matcha siffror eller ordade tal i början
      final match = RegExp(r'^(\d+|[a-zåäö]+)').firstMatch(part);
      if (match == null) continue;
      final raw = match.group(1)!;
      final num = parseNumber(raw) ?? 0;
      if (num <= 0) continue;

      // Resterande ord är måltidstyp
      final keyword = part.substring(raw.length).trim();
      final type = _detectType(keyword, types);
      if (type != null) {
        counts[type] = (counts[type] ?? 0) + num;
      }
    }

    // Om inga instruktioner hittas => returnera tom meny
    if (counts.isEmpty) return {};

    // Slumpa recept per vald typ
    final rand = Random();
    final result = <String, List<Recipe>>{};
    counts.forEach((mealType, count) {
      final bucket =
          allRecipes.where((r) => r.mealType == mealType).toList()
            ..shuffle(rand);
      // Ta så många som önskat (eller färre om inte tillräckligt många finns)
      result[mealType] = bucket.take(min(count, bucket.length)).toList();
    });

    return result;
  }

  /// Normaliserar pluralformer och matchar mot tillgängliga typer
  String? _detectType(String input, Set<String> available) {
    final norm =
        input
            .replaceAll(RegExp(r'\d+'), '')
            .replaceAll(RegExp(r'(ar|er)$', unicode: true), '')
            .trim();
    for (var type in available) {
      final low = type.toLowerCase();
      if (low == norm || low.startsWith(norm)) return type;
    }
    return null;
  }
}
