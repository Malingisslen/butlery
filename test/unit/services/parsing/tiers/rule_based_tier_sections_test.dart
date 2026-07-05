/// Ingredient sections (PR #211) — RuleBasedTier `_applySections` seam.
///
/// The parsing golden fixtures only exercise the flag-ON, aligned path. These
/// pin the two branches goldens can't reach (testing-review Gap B):
///   - kill switch OFF → sections are NOT stamped (capture disabled).
///   - parsed/section length mismatch → fail open, no section stamped (a wrong
///     section is worse than none).
/// Plus the positive ON path end-to-end through the real Swedish classifier.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/rule_based_tier.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

/// Echoes each line back as a ParsedIngredient (name == line), 1:1.
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

/// Returns one FEWER parsed line than it received (a merge/drop), to trip the
/// length-mismatch fail-open guard.
class _ShrinkingStrategy extends IngredientParsingStrategy {
  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) async {
    final kept = lines.take(lines.length - 1).toList();
    if (kept.isEmpty) return FieldResult.failed('No ingredients found');
    return FieldResult.success([
      for (final l in kept)
        ParsedIngredient(
          name: l,
          originalLine: l,
          confidence: ParseConfidence.high,
        ),
    ]);
  }
}

ParsingContext grouped() => ParsingContext.fromText(
  text: '''
Kanelbullar

Ingredienser:
Deg:
5 dl vetemjöl
25 g jäst
Fyllning:
75 g smör
2 msk kanel

Gör så här:
Baka allt.
Servera.
''',
  source: ImportSource.text,
  userId: 'u',
  parserVersion: '2.0.0',
);

Future<List<ParsedIngredient>> sectionsOf(RuleBasedTier tier) async {
  final result = await tier.parse(grouped());
  expect(result.recipe, isNotNull, reason: 'grouped recipe should parse');
  return result.recipe!.ingredients.value!;
}

void main() {
  test(
    'flag ON (default): the classifier sections are stamped onto lines',
    () async {
      final tier = RuleBasedTier(ingredientStrategy: _EchoStrategy());
      final parsed = await sectionsOf(tier);

      expect(parsed.map((p) => p.name), [
        '5 dl vetemjöl',
        '25 g jäst',
        '75 g smör',
        '2 msk kanel',
      ]);
      expect(parsed.map((p) => p.section), [
        'Deg',
        'Deg',
        'Fyllning',
        'Fyllning',
      ]);
    },
  );

  test('length mismatch fails open: a strategy that drops a line leaves all '
      'sections null rather than misaligning them', () async {
    final tier = RuleBasedTier(ingredientStrategy: _ShrinkingStrategy());
    final parsed = await sectionsOf(tier);

    expect(
      parsed.every((p) => p.section == null),
      isTrue,
      reason: 'sections length != parsed length ⇒ stamp nothing',
    );
  });

  group('kill switch OFF', () {
    setUp(() {
      final flags = _MockFeatureFlags();
      when(
        () => flags.isEnabled(FeatureFlags.ingredientSectionCapture),
      ).thenReturn(false);
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FeatureFlagService>()) {
        getIt.unregister<FeatureFlagService>();
      }
      getIt.registerSingleton<FeatureFlagService>(flags);
      ServiceLocator.initialize(DIContainer());
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FeatureFlagService>()) {
        getIt.unregister<FeatureFlagService>();
      }
      ServiceLocator.reset();
    });

    test(
      'capture off ⇒ no sections stamped AND heading lines RETAINED as '
      'ingredients (Finding B: the flag fully reverts the text path)',
      () async {
        final tier = RuleBasedTier(ingredientStrategy: _EchoStrategy());
        final parsed = await sectionsOf(tier);

        expect(parsed, isNotEmpty);
        expect(
          parsed.every((p) => p.section == null),
          isTrue,
          reason: 'the flag gates _applySections',
        );
        // Before Finding B, heading lines were dropped even with capture off.
        // Now they are retained, so the flat tagging input is fully reverted.
        final names = parsed.map((p) => p.name).toList();
        expect(names, contains('Deg:'));
        expect(names, contains('Fyllning:'));
      },
    );
  });
}
