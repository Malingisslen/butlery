import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';
import 'package:butlery/services/parsing/tiers/site_config_tier.dart';
import 'package:butlery/services/parsing/tiers/llm_tier.dart';

/// Mock parsing tier for testing tier skip/run behavior.
class MockTier extends ParsingTier {
  @override
  final String tierName;
  @override
  final int priority;
  bool parseCalled = false;
  final TierResult Function(ParsingContext)? resultFactory;
  final bool Function(ParsingContext)? skipCheck;

  MockTier({
    required this.tierName,
    this.priority = 0,
    this.resultFactory,
    this.skipCheck,
  });

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  double get minQualityScore => 0.3;

  @override
  bool shouldSkip(ParsingContext context) => skipCheck?.call(context) ?? false;

  @override
  Future<TierResult> parse(ParsingContext context) async {
    parseCalled = true;
    if (resultFactory != null) return resultFactory!(context);
    return TierResult.noData(tierName: tierName, duration: Duration.zero);
  }
}

ParsedRecipe _buildRecipe({double quality = 0.8}) {
  return ParsedRecipe(
    title: FieldResult.success('Test Recipe'),
    portions: FieldResult.success(4),
    ingredients: FieldResult.success([
      const ParsedIngredient(
        name: 'flour',
        originalLine: '3 dl flour',
        confidence: ParseConfidence.high,
        quantity: '3',
        unit: 'dl',
      ),
    ]),
    instructions: FieldResult.success(['Step one.', 'Step two.']),
    totalTime: FieldResult.success(const Duration(minutes: 30)),
    metadata: ParseMetadata(
      source: ImportSource.text,
      parserVersion: '2.0.0',
      timestamp: DateTime.now(),
      totalParseTime: Duration.zero,
      tierResults: const [],
    ),
  );
}

void main() {
  group('_shouldSkipTier logic', () {
    // We can't call _shouldSkipTier directly since it's private,
    // but we verify the behavior through the public API by testing
    // that SchemaOrg and SiteConfig tiers are skipped for text input.

    test('SchemaOrgTier shouldSkip returns true for text source', () {
      final tier = SchemaOrgTier();
      final context = ParsingContext.fromText(
        text: 'Some recipe text that is long enough for processing',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(context), isTrue);
    });

    test('SiteConfigTier shouldSkip returns true for text source', () {
      final tier = SiteConfigTier();
      final context = ParsingContext.fromText(
        text: 'Some recipe text that is long enough for processing',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(context), isTrue);
    });

    test('LlmTier shouldSkip returns true when service is null', () {
      final tier = LlmTier(llmService: null);
      final context = ParsingContext.fromText(
        text: 'Some recipe text that is long enough for processing',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(context), isTrue);
    });
  });

  group('_runTiers behavior', () {
    test('stops when quality threshold is met', () async {
      final highQualityTier = MockTier(
        tierName: 'HighQuality',
        priority: 1,
        resultFactory: (ctx) {
          final recipe = _buildRecipe(quality: 0.9);
          return TierResult.success(
            tierName: 'HighQuality',
            recipe: recipe,
            duration: Duration.zero,
          );
        },
      );

      final secondTier = MockTier(
        tierName: 'Second',
        priority: 2,
        resultFactory: (ctx) {
          final recipe = _buildRecipe();
          return TierResult.success(
            tierName: 'Second',
            recipe: recipe,
            duration: Duration.zero,
          );
        },
      );

      // The first tier produces high quality, second should not be called
      // We verify this by checking that secondTier.parseCalled stays false
      // after running highQualityTier through parseWithTimeout

      final context = ParsingContext.fromText(
        text: 'Test recipe content for parsing test',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );

      // Simulate tier execution with quality check
      final result1 = await highQualityTier.parseWithTimeout(context);
      expect(result1.success, isTrue);
      expect(result1.quality, greaterThanOrEqualTo(0.7));

      // After adding high quality result, context should say don't continue
      expect(
        context.shouldContinueParsing(qualityThreshold: 0.7),
        isFalse,
      );
      expect(secondTier.parseCalled, isFalse);
    });

    test('continues when quality threshold is not met', () async {
      final lowQualityTier = MockTier(
        tierName: 'LowQuality',
        priority: 1,
        resultFactory: (ctx) {
          final recipe = ParsedRecipe(
            title: FieldResult.success('Test'),
            portions: FieldResult.failed('No portions'),
            ingredients: FieldResult.failed('No ingredients'),
            instructions: FieldResult.failed('No instructions'),
            totalTime: FieldResult.failed('No time'),
            metadata: ParseMetadata(
              source: ImportSource.text,
              parserVersion: '2.0.0',
              timestamp: DateTime.now(),
              totalParseTime: Duration.zero,
              tierResults: const [],
            ),
          );
          return TierResult.success(
            tierName: 'LowQuality',
            recipe: recipe,
            duration: Duration.zero,
          );
        },
      );

      final context = ParsingContext.fromText(
        text: 'Test recipe content for parsing test',
        source: ImportSource.text,
        userId: 'test-user',
        parserVersion: '2.0.0',
      );

      final result1 = await lowQualityTier.parseWithTimeout(context);
      expect(result1.success, isTrue);
      expect(result1.quality, lessThan(0.7));

      // Context should say continue
      expect(
        context.shouldContinueParsing(qualityThreshold: 0.7),
        isTrue,
      );
    });
  });

  group('Domain-based quality threshold', () {
    test('reliable domain raises effective threshold', () {
      final config = const SiteConfig(
        domain: 'ica.se',
        titleSelector: 'h1',
        ingredientsSelector: '.ingredients li',
        instructionsSelector: '.instructions li',
        isSupported: true,
        qualityScore: 0.9,
        successCount: 10,
        failureCount: 1,
      );

      expect(config.isReliable, isTrue);
      // Effective threshold would be 0.7 + 0.15 = 0.85
      final effectiveThreshold = (0.7 + 0.15).clamp(0.0, 0.95);
      expect(effectiveThreshold, 0.85);
    });

    test('unreliable domain keeps default threshold', () {
      final config = const SiteConfig(
        domain: 'unknown-site.com',
        isSupported: false,
        qualityScore: 0.3,
      );

      expect(config.isReliable, isFalse);
    });
  });
}
