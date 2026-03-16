/// Menu generation service using Swedish natural language parsing.
///
/// Parses requests like "3 middagar, 2 luncher" and randomly selects
/// matching recipes from the user's collection. NOT AI/LLM-based.
library;

import 'dart:math';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';

/// Generates menus by parsing Swedish meal requests and randomly selecting recipes.
///
/// Example: "tre frukoster och två middagar" → 3 breakfast + 2 dinner recipes
class MenuService extends BaseService {
  MenuService();

  @override
  String get serviceName => 'MenuService';

  /// Parses Swedish meal request and returns randomly selected recipes.
  ///
  /// Supports: "3 middagar", "tre frukoster och två luncher", etc.
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
        ) ??
        <String, List<Recipe>>{};
  }

  Map<String, List<Recipe>> _generateMenuFromPromptInternal(
    String input,
    List<Recipe> allRecipes,
  ) {
    if (input.trim().isEmpty) return {};

    final types = <String>{for (var r in allRecipes) r.mealType};

    // Swedish number words
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

    final counts = <String, int>{};
    final lowerInput = input.toLowerCase();

    // Split on explicit separators: comma, 'och', '&', semicolon
    final explicitParts = lowerInput.split(RegExp(r'[,&;]| och | & '));

    if (explicitParts.length > 1) {
      for (var part in explicitParts) {
        part = part.trim();
        if (part.isEmpty) continue;
        _parseMealPart(part, counts, types, parseNumber);
      }
    } else {
      final singlePart = explicitParts[0].trim();
      if (singlePart.isNotEmpty) {
        final patterns = _extractMealPatterns(singlePart);
        if (patterns.length > 1) {
          for (final pattern in patterns) {
            _parseMealPart(pattern, counts, types, parseNumber);
          }
        } else {
          _parseMealPart(singlePart, counts, types, parseNumber);
        }
      }
    }

    if (counts.isEmpty) return {};

    final rand = Random();
    final result = <String, List<Recipe>>{};
    final usedIds = <String>{};
    counts.forEach((mealType, count) {
      final bucket = allRecipes
          .where((r) =>
              r.mealType.toLowerCase() == mealType.toLowerCase() &&
              !usedIds.contains(r.id))
          .toList()
        ..shuffle(rand);
      final selected = bucket.take(min(count, bucket.length)).toList();
      for (final recipe in selected) {
        usedIds.add(recipe.id);
      }
      result[mealType] = selected;
    });

    return result;
  }

  /// Extracts quantity and meal type from a single part (e.g., "3 middagar").
  void _parseMealPart(
    String part,
    Map<String, int> counts,
    Set<String> types,
    int? Function(String) parseNumber,
  ) {
    part = part.trim();
    if (part.isEmpty) return;

    final match = RegExp(r'^(\d+|[a-zåäö]+)').firstMatch(part);
    if (match == null) return;

    final raw = match.group(1)!;
    final num = parseNumber(raw) ?? 0;
    if (num <= 0) return;

    final keyword = part.substring(match.end).trim();
    if (keyword.isEmpty) return;

    final type = _detectType(keyword, types);
    if (type != null) {
      counts[type] = (counts[type] ?? 0) + num;
    }
  }

  /// Finds "quantity + meal type" patterns in space-separated text.
  List<String> _extractMealPatterns(String input) {
    final patterns = <String>[];
    final words = input.split(RegExp(r'\s+'));

    for (int i = 0; i < words.length - 1; i++) {
      final currentWord = words[i];
      final nextWord = words[i + 1];

      final isNumber = RegExp(
        r'^(\d+|en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio)$',
      ).hasMatch(currentWord);

      final isMealType = RegExp(
        r'^(frukost|lunch|middag|dessert|mellanmål|fika)',
        caseSensitive: false,
      ).hasMatch(nextWord);

      if (isNumber && isMealType) {
        patterns.add('$currentWord $nextWord');
      }
    }

    return patterns;
  }

  /// Normalizes plural forms and matches against available meal types.
  String? _detectType(String input, Set<String> available) {
    // Explicit Swedish plural-to-singular map (avoids over-stripping with regex)
    const pluralMap = {
      'middagar': 'middag',
      'luncher': 'lunch',
      'frukostar': 'frukost',
      'frukoster': 'frukost',
      'desserter': 'dessert',
      'efterrätter': 'efterrätt',
      'mellanmål': 'mellanmål',
      'fikor': 'fika',
    };

    final norm = input.replaceAll(RegExp(r'\d+'), '').trim();
    final singular = pluralMap[norm] ?? norm;

    for (var type in available) {
      final low = type.toLowerCase();
      if (low == singular || low.startsWith(singular)) return type;
    }
    return null;
  }
}
