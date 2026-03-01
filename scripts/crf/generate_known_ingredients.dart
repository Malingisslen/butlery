/// Generates lib/constants/known_ingredients.dart from Firebase export.
///
/// Two-step pipeline (Firebase = source of truth):
///   1. Export: cd functions && npx ts-node src/admin/export-ingredients.ts
///   2. Generate: dart run scripts/crf/generate_known_ingredients.dart
///
/// The generated file provides offline fallback for CRF feature extraction.
/// At runtime, [IngredientRegistryService] enriches with live Firestore data.
library;

import 'dart:convert';
import 'dart:io';

/// Maps Firebase group paths to Dart category names.
const _groupToCategory = {
  // Protein groups
  'protein/dairy': 'dairy',
  'protein/egg': 'eggs',
  'protein/meat': 'meat',
  'protein/seafood': 'seafood',
  'protein/plant-based': 'other',
  'protein': 'meat', // fallback for unmapped protein subcategories

  // Vegetable groups
  'vegetable': 'vegetables',

  // Fruit groups
  'fruit': 'fruits',

  // Grain groups
  'grain/bread': 'bread',
  'grain/pasta-bread': 'grains',
  'grain': 'grains',

  // Fat groups
  'fat/oil': 'oils',
  'fat/solid': 'oils', // butter, margarine etc. → oils & fats
  'fat': 'oils',

  // Spice groups
  'spice': 'spices',

  // Other groups
  'other/condiment': 'condiments',
  'other/sweetener': 'sweeteners',
  'other/beverage': 'beverages',
  'other/nut-seed': 'nuts_seeds',
  'other/baking': 'baking',
  'other/dessert': 'other',
  'other/liquid': 'other',
  'other/prepared-meal': 'other',
  'other': 'other',
};

/// Resolves a Firebase group path to a Dart category.
/// Tries exact match first, then walks up the hierarchy.
String _resolveCategory(String group) {
  if (group.isEmpty) return 'other';

  // Try exact match
  if (_groupToCategory.containsKey(group)) return _groupToCategory[group]!;

  // Try parent paths (e.g., 'protein/meat/poultry' → 'protein/meat' → 'protein')
  final parts = group.split('/');
  for (var i = parts.length - 1; i >= 1; i--) {
    final parent = parts.sublist(0, i).join('/');
    if (_groupToCategory.containsKey(parent)) return _groupToCategory[parent]!;
  }

  // Top-level fallback
  if (_groupToCategory.containsKey(parts.first)) {
    return _groupToCategory[parts.first]!;
  }

  return 'other';
}

void main() {
  const inputPath = 'scripts/crf/data/firebase_ingredients.json';
  const outputPath = 'lib/constants/known_ingredients.dart';

  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Error: $inputPath not found.');
    stderr.writeln(
        'Run first: cd functions && npx ts-node src/admin/export-ingredients.ts');
    exit(1);
  }

  final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  stderr.writeln('Read ${json.length} ingredients from $inputPath');

  // Group ingredients by category
  final categories = <String, Set<String>>{};
  final compoundNames = <String>{};
  var aliasCount = 0;

  for (final item in json) {
    final swedish = (item['swedish'] as String).toLowerCase().trim();
    final group = item['group'] as String? ?? '';
    final aliases = (item['aliasesSv'] as List<dynamic>?)
            ?.map((a) => (a as String).toLowerCase().trim())
            .where((a) => a.isNotEmpty)
            .toList() ??
        [];
    final isCompound = item['isCompoundName'] as bool? ?? false;

    if (swedish.isEmpty) continue;

    final category = _resolveCategory(group);
    categories.putIfAbsent(category, () => <String>{});
    categories[category]!.add(swedish);

    // Add aliases to the same category
    for (final alias in aliases) {
      categories[category]!.add(alias);
      aliasCount++;
    }

    // Collect compound names
    if (isCompound) {
      compoundNames.add(swedish);
      for (final alias in aliases) {
        compoundNames.add(alias);
      }
    }
  }

  // Define the category order (matches original file structure)
  const categoryOrder = [
    'dairy',
    'meat',
    'seafood',
    'vegetables',
    'fruits',
    'grains',
    'bread',
    'condiments',
    'spices',
    'oils',
    'sweeteners',
    'nuts_seeds',
    'baking',
    'canned',
    'beverages',
    'alcohol',
    'eggs',
    'other',
  ];

  // Map category names to Dart field names
  const categoryToField = {
    'dairy': 'dairy',
    'meat': 'meat',
    'seafood': 'seafood',
    'vegetables': 'vegetables',
    'fruits': 'fruits',
    'grains': 'grains',
    'bread': 'bread',
    'condiments': 'condiments',
    'spices': 'spices',
    'oils': 'oils',
    'sweeteners': 'sweeteners',
    'nuts_seeds': 'nutsAndSeeds',
    'baking': 'baking',
    'canned': 'canned',
    'beverages': 'beverages',
    'alcohol': 'alcohol',
    'eggs': 'eggs',
    'other': 'other',
  };

  // Map category names to display labels
  const categoryToLabel = {
    'dairy': 'Dairy products',
    'meat': 'Meat and poultry',
    'seafood': 'Fish and seafood',
    'vegetables': 'Vegetables',
    'fruits': 'Fruits and berries',
    'grains': 'Grains, pasta, and rice',
    'bread': 'Bread',
    'condiments': 'Condiments and sauces',
    'spices': 'Spices and herbs',
    'oils': 'Oils and fats',
    'sweeteners': 'Sweeteners',
    'nuts_seeds': 'Nuts and seeds',
    'baking': 'Baking ingredients',
    'canned': 'Canned and preserved',
    'beverages': 'Beverages',
    'alcohol': 'Alcohol',
    'eggs': 'Eggs and egg products',
    'other': 'Other ingredients',
  };

  // Generate Dart source
  final buf = StringBuffer();

  buf.writeln(
      '/// Static ingredient registry generated from Firebase Firestore.');
  buf.writeln('///');
  buf.writeln('/// AUTO-GENERATED — do not edit manually.');
  buf.writeln('/// Regenerate with:');
  buf.writeln(
      '///   1. cd functions && npx ts-node src/admin/export-ingredients.ts');
  buf.writeln('///   2. dart run scripts/crf/generate_known_ingredients.dart');
  buf.writeln('///');
  buf.writeln(
      '/// This serves as offline fallback for CRF parsing. At runtime,');
  buf.writeln(
      '/// [IngredientRegistryService] enriches with live Firestore data.');
  buf.writeln('class KnownIngredients {');
  buf.writeln('  KnownIngredients._();');
  buf.writeln();

  // Write each category set
  var totalIngredients = 0;
  final usedCategories = <String>[];

  for (final cat in categoryOrder) {
    final items = categories[cat];
    if (items == null || items.isEmpty) continue;

    usedCategories.add(cat);
    final fieldName = categoryToField[cat]!;
    final label = categoryToLabel[cat]!;
    final sorted = items.toList()..sort();
    totalIngredients += sorted.length;

    buf.writeln('  /// $label');
    buf.writeln('  static const Set<String> $fieldName = {');
    for (final item in sorted) {
      buf.writeln("    '${_escape(item)}',");
    }
    buf.writeln('  };');
    buf.writeln();
  }

  // Write compound names
  final sortedCompounds = compoundNames.toList()..sort();
  buf.writeln('  /// Compound ingredient names that should NOT be split.');
  buf.writeln('  /// Sourced from Firebase isCompoundName flag.');
  buf.writeln('  static const Set<String> compoundNames = {');
  for (final name in sortedCompounds) {
    buf.writeln("    '${_escape(name)}',");
  }
  buf.writeln('  };');
  buf.writeln();

  // Write 'all' set
  buf.writeln('  /// All known ingredients combined');
  buf.writeln('  static final Set<String> all = {');
  for (final cat in usedCategories) {
    buf.writeln('    ...${categoryToField[cat]},');
  }
  buf.writeln('    ...compoundNames,');
  buf.writeln('  };');
  buf.writeln();

  // Write utility methods
  buf.writeln('  /// Check if ingredient is known');
  buf.writeln('  static bool isKnown(String ingredient) {');
  buf.writeln('    return all.contains(ingredient.toLowerCase());');
  buf.writeln('  }');
  buf.writeln();

  buf.writeln(
      '  /// Check if ingredient is a compound name that should not be split');
  buf.writeln('  static bool isCompoundName(String ingredient) {');
  buf.writeln('    return compoundNames.contains(ingredient.toLowerCase());');
  buf.writeln('  }');
  buf.writeln();

  // Write getCategory
  buf.writeln('  /// Get category for ingredient');
  buf.writeln('  static String? getCategory(String ingredient) {');
  buf.writeln('    final lower = ingredient.toLowerCase();');
  buf.writeln();
  for (final cat in usedCategories) {
    final fieldName = categoryToField[cat]!;
    buf.writeln(
        "    if ($fieldName.contains(lower)) return '${cat == 'nuts_seeds' ? 'nuts_seeds' : cat}';");
  }
  buf.writeln();
  buf.writeln('    return null;');
  buf.writeln('  }');
  buf.writeln();

  // Write getIngredientsInCategory
  buf.writeln('  /// Get all ingredients in a category');
  buf.writeln(
      '  static Set<String>? getIngredientsInCategory(String category) {');
  buf.writeln('    switch (category.toLowerCase()) {');
  for (final cat in usedCategories) {
    final fieldName = categoryToField[cat]!;
    buf.writeln("      case '$cat':");
    buf.writeln('        return $fieldName;');
  }
  buf.writeln('      default:');
  buf.writeln('        return null;');
  buf.writeln('    }');
  buf.writeln('  }');
  buf.writeln();

  // Write getAllCategories
  buf.writeln('  /// Get all categories');
  buf.writeln('  static List<String> getAllCategories() {');
  buf.writeln('    return [');
  for (final cat in usedCategories) {
    buf.writeln("      '$cat',");
  }
  buf.writeln('    ];');
  buf.writeln('  }');

  buf.writeln('}');

  // Write output
  File(outputPath).writeAsStringSync(buf.toString());

  stderr.writeln('Generated $outputPath');
  stderr.writeln('  Total ingredients: $totalIngredients');
  stderr.writeln('  Aliases included: $aliasCount');
  stderr.writeln('  Compound names: ${compoundNames.length}');
  stderr.writeln('  Categories: ${usedCategories.length}');
  for (final cat in usedCategories) {
    stderr.writeln('    $cat: ${categories[cat]!.length}');
  }
}

/// Escape single quotes in ingredient names.
String _escape(String s) => s.replaceAll("'", "\\'");
