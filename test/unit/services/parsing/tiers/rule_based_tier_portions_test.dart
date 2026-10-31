/// Malin 2026-10-31: pasted text that states no servings stores none, so the
/// user fills them in rather than inheriting a guessed 4.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/rule_based_tier.dart';

class _EchoStrategy extends IngredientParsingStrategy {
  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) async {
    if (lines.isEmpty) return FieldResult.failed('No ingredients found');
    return FieldResult.success([
      for (final l in lines)
        ParsedIngredient(
          name: l,
          originalLine: l,
          confidence: ParseConfidence.high,
        ),
    ]);
  }
}

Future<FieldResult<int>> portionsOf(String text) async {
  final tier = RuleBasedTier(ingredientStrategy: _EchoStrategy());
  final result = await tier.parse(
    ParsingContext.fromText(
      text: text,
      source: ImportSource.text,
      userId: 'u',
      parserVersion: '2.0.0',
    ),
  );
  expect(result.recipe, isNotNull, reason: 'the recipe should parse');
  return result.recipe!.portions;
}

void main() {
  const body = '''
Ingredienser:
5 dl vetemjöl
25 g jäst
75 g smör

Gör så här:
Baka allt.
Servera.
''';

  test('text without servings stores no portions', () async {
    final portions = await portionsOf('Kanelbullar\n\n$body');

    expect(portions.value, isNull);
    expect(portions.confidence, ParseConfidence.failed);
  });

  test('text that states servings keeps them', () async {
    final portions = await portionsOf('Kanelbullar\n6 portioner\n\n$body');

    expect(portions.value, 6);
  });
}
