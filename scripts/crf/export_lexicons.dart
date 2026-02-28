/// Exports all ingredient-parsing lexicons to JSON for Python training parity.
///
/// The Dart constants (KnownIngredients, UnitDefinitions, PreparationWords)
/// are the single source of truth. This script dumps them to a JSON file
/// that train_crf.py loads, so both sides use identical lexicons.
///
/// Usage: dart run scripts/crf/export_lexicons.dart
///   → writes scripts/crf/data/lexicons.json
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

void main() {
  final lexicons = {
    'units': UnitDefinitions.standaloneUnits.toList()..sort(),
    'prep_words': PreparationWords.preparationStates.toList()..sort(),
    'size_words': PreparationWords.sizeDescriptors.toList()..sort(),
    'foods': KnownIngredients.all.toList()..sort(),
  };

  const outputPath = 'scripts/crf/data/lexicons.json';
  final json = const JsonEncoder.withIndent('  ').convert(lexicons);
  File(outputPath).writeAsStringSync('$json\n');

  stderr.writeln('Exported lexicons to $outputPath');
  stderr.writeln('  units: ${lexicons['units']!.length}');
  stderr.writeln('  prep_words: ${lexicons['prep_words']!.length}');
  stderr.writeln('  size_words: ${lexicons['size_words']!.length}');
  stderr.writeln('  foods: ${lexicons['foods']!.length}');
}
