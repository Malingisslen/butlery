import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/tiers/llm_tier.dart';
import 'package:butlery/services/parsing/tiers/rule_based_tier.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/common/recipe_merger.dart';

import '../fixtures/swedish_sites/ica_test_data.dart';
import '../fixtures/swedish_sites/arla_test_data.dart';

/// Mock LlmService that replays a canned ExtractedRecipe.
///
/// Pattern mirrors `test/unit/services/parsing/tiers/llm_tier_test.dart`'s
/// MockLlmService — the seam is `LlmService.structureRecipe`, not the
/// underlying Cloud Functions HTTP call. This keeps the test deterministic,
/// hermetic (no Firebase init), and fast.
///
/// The trade-off vs HTTP-level mocking: we don't exercise the
/// `FirebaseFunctions.httpsCallable` plumbing (request envelope, error
/// translation in `LlmException.fromFirebase`). Those are covered by the
/// dedicated `LlmService` tests. The golden suite's job is to lock the
/// **tier-level contract**: given a known LLM response, does `LlmTier`
/// validate, normalize, and shape it into the expected `ParsedRecipe`?
class _GoldenMockLlmService implements LlmService {
  StructureRecipeResponse? nextResponse;

  @override
  Future<StructureRecipeResponse> structureRecipe({
    required String text,
    StructureMode mode = StructureMode.extract,
    String? sourceUrl,
    Map<String, dynamic>? partialData,
  }) async {
    return nextResponse ??
        const StructureRecipeResponse(success: false, estimatedCost: 0.0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Load eagerly so test names can reference dataset entries
  final file = File('test/golden/parsing_golden_dataset.json');
  final dataset = jsonDecode(file.readAsStringSync()) as List;

  final schemaOrgTier = SchemaOrgTier();
  final ruleBasedTier = RuleBasedTier();
  final merger = RecipeMerger();

  final fixtures = <String, String>{
    'IcaTestFixtures.kottbullarComplete': IcaTestFixtures.kottbullarComplete,
    'IcaTestFixtures.recipeWithoutJsonLd': IcaTestFixtures.recipeWithoutJsonLd,
    'IcaTestFixtures.recipeWithSwedishChars':
        IcaTestFixtures.recipeWithSwedishChars,
    'ArlaTestFixtures.chokladbollarComplete':
        ArlaTestFixtures.chokladbollarComplete,
  };

  group('Parsing golden dataset', () {
    for (var i = 0; i < dataset.length; i++) {
      final entry = dataset[i] as Map<String, dynamic>;
      final id = entry['id'] as String;
      final tier = (entry['tier'] as String?) ?? 'schemaOrg';

      test('[$id] ($tier)', () async {
        final expected = entry['expected'] as Map<String, dynamic>;

        // Dispatch on tier. Each branch builds a ParsingContext appropriate
        // for that tier's input shape (HTML for schemaOrg, plaintext for
        // ruleBased and llm), runs the tier, and hands the result to the
        // shared assertion block below.
        final dynamic recipe;
        switch (tier) {
          case 'schemaOrg':
            recipe = await _runSchemaOrg(
              entry: entry,
              fixtures: fixtures,
              schemaOrgTier: schemaOrgTier,
              merger: merger,
              id: id,
            );
            // SchemaOrg-only smoke without JSON-LD — no result expected.
            if (entry['schemaOrgOnly'] == true) return;
            break;
          case 'ruleBased':
            recipe = await _runRuleBased(
              entry: entry,
              tier: ruleBasedTier,
              id: id,
            );
            break;
          case 'llm':
            recipe = await _runLlm(entry: entry, id: id);
            break;
          default:
            fail('Unknown tier "$tier" for entry $id');
        }

        expect(recipe, isNotNull, reason: '$id: tier produced null recipe');

        if (expected.containsKey('titleContains')) {
          expect(
            recipe.title.value?.toString().toLowerCase(),
            contains((expected['titleContains'] as String).toLowerCase()),
            reason: '$id: title mismatch',
          );
        }

        if (expected.containsKey('portions')) {
          expect(
            recipe.portions.value,
            equals(expected['portions']),
            reason: '$id: portions mismatch',
          );
        }

        final ingredients = (recipe.ingredients.value ?? []) as List;

        if (expected.containsKey('ingredientCountMin')) {
          expect(
            ingredients.length,
            greaterThanOrEqualTo(expected['ingredientCountMin'] as int),
            reason: '$id: too few ingredients',
          );
        }

        if (expected.containsKey('ingredientSubstrings')) {
          final substrings =
              (expected['ingredientSubstrings'] as List).cast<String>();
          // Schema-org/RuleBased ingredients have `originalLine`; LLM-tier
          // ingredients populate `originalLine` from the formatted string —
          // both expose the field, so the assertion shape is identical.
          final ingredientText = ingredients.map((dynamic ing) {
            final original = ing.originalLine as String?;
            final name = ing.name as String?;
            return '${original ?? ''} ${name ?? ''}'.toLowerCase();
          }).join(' ');
          for (final sub in substrings) {
            expect(
              ingredientText,
              contains(sub.toLowerCase()),
              reason: '$id: ingredient "$sub" not found',
            );
          }
        }

        final instructions = (recipe.instructions.value ?? []) as List;

        if (expected.containsKey('instructionCountMin')) {
          expect(
            instructions.length,
            greaterThanOrEqualTo(expected['instructionCountMin'] as int),
            reason: '$id: too few instructions',
          );
        }

        if (expected.containsKey('instructionSubstrings')) {
          final substrings =
              (expected['instructionSubstrings'] as List).cast<String>();
          final instructionText =
              instructions.map((s) => s.toString().toLowerCase()).join(' ');
          for (final sub in substrings) {
            expect(
              instructionText,
              contains(sub.toLowerCase()),
              reason: '$id: instruction substring "$sub" not found',
            );
          }
        }

        if (expected.containsKey('totalTimeMinutes')) {
          expect(
            recipe.totalTime.value?.inMinutes,
            equals(expected['totalTimeMinutes']),
            reason: '$id: totalTimeMinutes mismatch',
          );
        }

        if (expected.containsKey('minQuality')) {
          expect(
            recipe.overallQuality,
            greaterThanOrEqualTo(expected['minQuality'] as double),
            reason: '$id: quality too low',
          );
        }
      });
    }
  });
}

Future<dynamic> _runSchemaOrg({
  required Map<String, dynamic> entry,
  required Map<String, String> fixtures,
  required SchemaOrgTier schemaOrgTier,
  required RecipeMerger merger,
  required String id,
}) async {
  final domain = entry['domain'] as String;
  final fixtureKey = entry['fixture'] as String;
  final html = fixtures[fixtureKey];
  if (html == null) fail('Unknown fixture: $fixtureKey for entry $id');

  final context = ParsingContext.fromUrl(
    url: 'https://$domain/test-recipe',
    htmlContent: html,
    userId: 'golden-test',
    parserVersion: '2.0.0',
  );

  final result = await schemaOrgTier.parseWithTimeout(context);
  return merger.merge([result]);
}

Future<dynamic> _runRuleBased({
  required Map<String, dynamic> entry,
  required RuleBasedTier tier,
  required String id,
}) async {
  final text = entry['text'] as String?;
  if (text == null || text.isEmpty) {
    fail('$id: ruleBased entry missing required `text` field');
  }
  final context = ParsingContext.fromText(
    text: text,
    source: ImportSource.text,
    userId: 'golden-test',
    parserVersion: '2.0.0',
  );
  final result = await tier.parseWithTimeout(context);
  expect(result.success, isTrue, reason: '$id: ruleBased tier did not succeed');
  return result.recipe;
}

Future<dynamic> _runLlm({
  required Map<String, dynamic> entry,
  required String id,
}) async {
  final text = entry['text'] as String?;
  final mockJson = entry['mockResponse'] as Map<String, dynamic>?;
  if (text == null || text.isEmpty) {
    fail('$id: llm entry missing required `text` field');
  }
  if (mockJson == null) {
    fail('$id: llm entry missing required `mockResponse` field');
  }

  final mockService = _GoldenMockLlmService()
    ..nextResponse = StructureRecipeResponse(
      success: true,
      recipe: ExtractedRecipe.fromJson(mockJson),
      estimatedCost: 0.01,
    );
  final tier = LlmTier(llmService: mockService);

  final context = ParsingContext.fromText(
    text: text,
    source: ImportSource.text,
    userId: 'golden-test',
    parserVersion: '2.0.0',
  );

  final result = await tier.parseWithTimeout(context);
  expect(result.success, isTrue, reason: '$id: llm tier did not succeed');
  return result.recipe;
}
