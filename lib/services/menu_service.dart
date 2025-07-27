// lib/services/menu_service.dart

import 'dart:math';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

/// Service för att generera veckomenyer - flyttar logik från VeckomenyView
/// Now using SingletonServiceMixin for standardized singleton pattern
class MenuService extends BaseService with SingletonServiceMixin<MenuService> {
  // Private constructor for singleton
  MenuService._internal();
  
  // Factory constructor using SingletonServiceMixin
  factory MenuService() => SingletonServiceMixin.createSingleton(() => MenuService._internal());
  
  @override
  String get serviceName => 'MenuService';

  /// Genererar meny baserat på textprompt (samma logik som tidigare)
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
