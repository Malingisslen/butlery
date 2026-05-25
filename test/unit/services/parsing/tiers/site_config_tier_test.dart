/// Intent tests for `SiteConfigTier` — Tier 2 of the recipe parser cascade.
///
/// Behaviours pinned here:
/// - `shouldSkip` rejects non-URL sources, empty content, missing domain.
/// - `_loadConfig` precedence: preloadedConfig wins over configLoader.
/// - Missing/null loader path returns no config (skipped result).
/// - Config without any selectors → skipped (`!hasSelectors`).
/// - Config with `isSupported: false` → skipped even when selectors present.
/// - End-to-end happy path: title + ingredients + instructions extracted.
/// - Fallback selectors trigger when primary returns empty/no match.
/// - Fallback selectors do NOT trigger when primary succeeds.
/// - Invalid CSS selectors are swallowed (no throw) and treated as no-match.
/// - Image selector: prefers `src`, falls back to `data-src` and `data-lazy-src`.
/// - Image selector: rejects non-http URLs (relative paths, javascript:).
/// - Portions: extracts first number, caps at kMaxPortions, rejects 0.
/// - Time: parses Swedish "tim/min", English "h/min/hour", bare numbers.
/// - Empty ingredients short-circuits to noData (title alone is not enough).
/// - Step-number prefixes ("1. ", "2) ") stripped from instructions.
/// - Document cache: parsed Document stored on context.parsedDocument and reused.
/// - Tier properties: priority=2, tierName=SiteConfig, timeout=10s.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/site_config_tier.dart';

/// Stub IngredientParsingStrategy — records what lines the tier handed off
/// and echoes them back as parsed ingredients. Bypasses CRF asset loading.
class _RecordingStrategy extends IngredientParsingStrategy {
  List<String>? receivedLines;
  bool? receivedOcrFlag;
  bool failOnNext = false;

  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) async {
    receivedLines = List.of(lines);
    receivedOcrFlag = ocrCorrection;
    if (failOnNext || lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }
    return FieldResult.success(
      lines
          .map((l) => ParsedIngredient(
                name: l,
                originalLine: l,
                confidence: ParseConfidence.high,
              ))
          .toList(),
    );
  }
}

/// Builds a minimal HTML page exposing the selectors used in the tests.
String htmlWith({
  String title = 'Pannkakor',
  List<String> ingredients = const ['3 dl mjol', '6 dl mjolk', '3 agg'],
  List<String> instructions = const [
    '1. Blanda mjol och mjolk.',
    '2. Tillsatt agg.',
    '3. Stek i smor.',
  ],
  String portions = '4 portioner',
  String time = '45 min',
  String imageUrl = 'https://example.com/pancakes.jpg',
  String description = 'Klassiska svenska pannkakor',
  String titleClass = 'recipe-title',
  String ingredientClass = 'ingredient',
  String instructionClass = 'instruction',
}) {
  final ingredientLis =
      ingredients.map((i) => '<li class="$ingredientClass">$i</li>').join();
  final instructionLis =
      instructions.map((i) => '<li class="$instructionClass">$i</li>').join();
  return '''
<!DOCTYPE html>
<html>
<head><title>Page</title></head>
<body>
  <h1 class="$titleClass">$title</h1>
  <p class="description">$description</p>
  <span class="portions">$portions</span>
  <span class="time">$time</span>
  <img class="hero" src="$imageUrl" />
  <ul class="ingredients">$ingredientLis</ul>
  <ol class="instructions">$instructionLis</ol>
</body>
</html>
''';
}

ParsingContext urlContextFor(
  String html, {
  String url = 'https://example.com/recipe',
}) {
  return ParsingContext.fromUrl(
    url: url,
    htmlContent: html,
    userId: 'test-user',
    parserVersion: '2.0.0',
  );
}

/// A fully-wired SiteConfig that matches the helper-generated HTML.
SiteConfig fullConfig({
  String domain = 'example.com',
  bool isSupported = true,
  String? titleSelector = '.recipe-title',
  String? titleFallback,
  String? ingredientsSelector = '.ingredient',
  String? ingredientsFallback,
  String? instructionsSelector = '.instruction',
  String? instructionsFallback,
  String? portionsSelector = '.portions',
  String? timeSelector = '.time',
  String? imageSelector = 'img.hero',
  String? descriptionSelector = '.description',
}) {
  return SiteConfig(
    domain: domain,
    isSupported: isSupported,
    titleSelector: titleSelector,
    titleSelectorFallback: titleFallback,
    ingredientsSelector: ingredientsSelector,
    ingredientsSelectorFallback: ingredientsFallback,
    instructionsSelector: instructionsSelector,
    instructionsSelectorFallback: instructionsFallback,
    portionsSelector: portionsSelector,
    timeSelector: timeSelector,
    imageSelector: imageSelector,
    descriptionSelector: descriptionSelector,
  );
}

void main() {
  late _RecordingStrategy strategy;

  setUp(() {
    strategy = _RecordingStrategy();
  });

  // ----- shouldSkip --------------------------------------------------------

  group('shouldSkip', () {
    /// Tier 2 only runs against URL imports; the per-domain config has no
    /// meaning for text/photo input. Skipping early saves the parse cycle.
    test('skips non-URL sources (text)', () {
      final tier =
          SiteConfigTier(ingredientStrategy: strategy, preloadedConfig: null);
      final ctx = ParsingContext.fromText(
        text: htmlWith(),
        source: ImportSource.text,
        userId: 'u',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(ctx), isTrue);
    });

    /// Photo sources never carry parseable HTML — skip without loading.
    test('skips photo sources', () {
      final tier = SiteConfigTier(ingredientStrategy: strategy);
      final ctx = ParsingContext.fromText(
        text: htmlWith(),
        source: ImportSource.photo,
        userId: 'u',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(ctx), isTrue);
    });

    /// Empty content means upstream fetch failed — no selectors can match
    /// nothing, so don't even attempt to load the config.
    test('skips empty content', () {
      final tier = SiteConfigTier(ingredientStrategy: strategy);
      final ctx = urlContextFor('');
      expect(tier.shouldSkip(ctx), isTrue);
    });

    /// URL with valid HTML + extractable domain → proceed.
    test('does not skip URL source with HTML and domain', () {
      final tier = SiteConfigTier(ingredientStrategy: strategy);
      final ctx = urlContextFor(htmlWith());
      expect(tier.shouldSkip(ctx), isFalse);
    });
  });

  // ----- config loading precedence -----------------------------------------

  group('_loadConfig precedence', () {
    /// `preloadedConfig` is the injection seam used in tests and trumps any
    /// loader. If a future refactor inverts this, every test in this file
    /// would behave unexpectedly — so pin it as contract.
    test('preloadedConfig wins over configLoader', () async {
      final preloaded = fullConfig(domain: 'preloaded.com');
      var loaderCalled = false;
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: preloaded,
        configLoader: (domain) async {
          loaderCalled = true;
          return fullConfig(domain: 'loader.com');
        },
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(loaderCalled, isFalse,
          reason: 'preloaded config must short-circuit the loader call');
    });

    /// configLoader is invoked with the context's domain — not the raw URL
    /// or some derived form. The Firestore key is the domain, off-by-one
    /// here would miss every config.
    test('configLoader is invoked with context.domain', () async {
      String? loaderDomain;
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        configLoader: (domain) async {
          loaderDomain = domain;
          return fullConfig(domain: domain);
        },
      );
      final ctx = urlContextFor(
        htmlWith(),
        url: 'https://www.koket.se/recept/pannkakor?utm=foo',
      );

      await tier.parse(ctx);

      expect(loaderDomain, 'koket.se',
          reason: 'ParsingContext strips www. and querystring '
              '— loader must see canonical domain');
    });

    /// With neither preloaded nor loader, the tier returns a skipped
    /// result rather than crashing on null. This is the fallback that
    /// matters when no Firestore is wired up (e.g. offline).
    test('no preload + no loader → skipped (not parseError)', () async {
      final tier = SiteConfigTier(ingredientStrategy: strategy);
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.skipped);
    });

    /// configLoader returning null is the "domain not in Firestore" case
    /// — must surface as skipped, NOT parseError. Cross-tier orchestrator
    /// relies on this to keep cascading to rule-based / LLM tiers.
    test('configLoader returning null → skipped', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        configLoader: (_) async => null,
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.failureReason, TierFailureReason.skipped);
    });
  });

  // ----- config gate (hasSelectors / isSupported) --------------------------

  group('config validity gates', () {
    /// A SiteConfig with no selector fields at all is effectively a "we
    /// have a domain entry but no rules yet" placeholder. Tier MUST skip.
    test('config without any selectors → skipped', () async {
      final empty = SiteConfig(domain: 'example.com'); // all selectors null
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: empty,
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(empty.hasSelectors, isFalse,
          reason: 'pre-flight: empty config should report no selectors');
      expect(result.failureReason, TierFailureReason.skipped);
    });

    /// `isSupported: false` is the admin kill-switch — used when a site's
    /// config drifts faster than we can update Firestore. MUST skip even
    /// if selectors are present.
    test('isSupported=false → skipped even with selectors', () async {
      final unsupported = fullConfig(isSupported: false);
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: unsupported,
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.failureReason, TierFailureReason.skipped);
      expect(strategy.receivedLines, isNull,
          reason: 'unsupported site must NOT invoke ingredient strategy');
    });
  });

  // ----- happy path --------------------------------------------------------

  group('parse - happy path', () {
    /// End-to-end: every selector resolves, ingredients flow through the
    /// strategy, the recipe carries the expected confidence levels.
    test('extracts full recipe from selectors', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.tierName, 'SiteConfig');

      final recipe = result.recipe!;
      expect(recipe.title.value, 'Pannkakor');
      expect(recipe.title.confidence, ParseConfidence.high);
      expect(recipe.portions.value, 4);
      expect(recipe.totalTime.value, const Duration(minutes: 45));
      expect(recipe.imageUrl, 'https://example.com/pancakes.jpg');
      expect(recipe.description, 'Klassiska svenska pannkakor');

      // Ingredients flowed through the strategy — text was whitespace-
      // normalised on the way through.
      expect(strategy.receivedLines, [
        '3 dl mjol',
        '6 dl mjolk',
        '3 agg',
      ]);
      expect(strategy.receivedOcrFlag, isFalse,
          reason: 'URL source must NOT request OCR correction');

      // Instructions: step-number prefixes stripped.
      expect(recipe.instructions.value, [
        'Blanda mjol och mjolk.',
        'Tillsatt agg.',
        'Stek i smor.',
      ]);

      // Metadata threading.
      expect(recipe.metadata.source, ImportSource.url);
      expect(recipe.metadata.domain, 'example.com');
      expect(recipe.metadata.parserVersion, '2.0.0');
    });
  });

  // ----- fallback selectors ------------------------------------------------

  group('selector fallback', () {
    /// Sites A/B test their markup constantly. When the primary title
    /// selector returns empty (the redesign moved the H1), the fallback
    /// MUST kick in. Off-by-one in the empty-check (`!=null` instead of
    /// `isNotEmpty`) would silently take an empty string and miss the
    /// fallback.
    test('title falls back when primary selector returns empty', () async {
      final config = fullConfig(
        titleSelector: '.nope-not-here',
        titleFallback: '.recipe-title',
      );
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(htmlWith(title: 'FallbackTitle'));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.title.value, 'FallbackTitle');
    });

    /// Primary success must NOT trigger fallback evaluation — otherwise a
    /// redesign that re-uses the old class for a non-title element would
    /// silently clobber the correct value.
    test('fallback is NOT used when primary selector succeeds', () async {
      // Primary `.recipe-title` resolves to "Real". Fallback `h1` would
      // resolve to the same element, but we want to be sure the primary
      // is what wins. Use a fallback that would yield a different result
      // if it were consulted.
      final html = '''
<html><body>
  <h1 class="recipe-title">Real</h1>
  <h1 class="wrong">Wrong</h1>
  <ul><li class="ingredient">1 dl mjol</li></ul>
  <ol><li class="instruction">stir</li></ol>
</body></html>
''';
      final config = fullConfig(
        titleSelector: '.recipe-title',
        titleFallback: '.wrong',
      );
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.recipe!.title.value, 'Real',
          reason: 'primary selector must win when it returns a value');
    });

    /// Ingredient fallback is the most load-bearing fallback — without
    /// ingredients, the tier returns noData regardless of everything
    /// else. Pin that empty list (no matches) triggers the fallback.
    test('ingredients fall back when primary matches nothing', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <ul class="ingredients">
    <li class="ingredient-v2">3 dl mjol</li>
    <li class="ingredient-v2">2 agg</li>
  </ul>
  <ol><li class="instruction">stir</li></ol>
</body></html>
''';
      final config = fullConfig(
        ingredientsSelector: '.ingredient', // matches 0 elements
        ingredientsFallback: '.ingredient-v2',
      );
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(strategy.receivedLines, ['3 dl mjol', '2 agg']);
    });
  });

  // ----- selector resilience ----------------------------------------------

  group('selector error handling', () {
    /// Invalid CSS selectors (sketchy admin entries in Firestore) MUST NOT
    /// crash the tier — they should be logged and treated as no-match.
    /// Otherwise one bad config row would tank every parse against that
    /// domain.
    test('invalid CSS selector does not throw, treated as no-match', () async {
      final config = fullConfig(
        titleSelector: ':::not a valid selector:::',
        titleFallback: '.recipe-title',
      );
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(htmlWith());

      // The crucial expectation: no throw.
      final result = await tier.parse(ctx);

      expect(result.success, isTrue,
          reason: 'invalid primary selector must fall back, not crash');
      expect(result.recipe!.title.value, 'Pannkakor');
    });

    /// Empty ingredients list (no matches, no fallback) → noData, not
    /// success with an empty recipe. This is the "minimum requirements"
    /// gate: a recipe without ingredients is not a recipe.
    test('no ingredients found anywhere → noData', () async {
      final config = fullConfig(
        ingredientsSelector: '.ingredient-missing',
        ingredientsFallback: null,
      );
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.noData);
    });

    /// Strategy returns failed → tier returns noData (the "no usable
    /// ingredients" gate fires even when the selector matched lines).
    test('strategy returning failed ingredients → noData', () async {
      strategy.failOnNext = true;
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.failureReason, TierFailureReason.noData);
    });
  });

  // ----- image extraction --------------------------------------------------

  group('image extraction', () {
    /// `src` attribute is the standard — pinned as the happy path.
    test('extracts http URL from src attribute', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(
        htmlWith(imageUrl: 'https://cdn.example.com/x.jpg'),
      );

      final result = await tier.parse(ctx);

      expect(result.recipe!.imageUrl, 'https://cdn.example.com/x.jpg');
    });

    /// Lazy-loaded images use `data-src` — common pattern on cooking sites.
    /// Tier MUST fall through src→data-src to catch them.
    test('falls back from missing src to data-src', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <img class="hero" data-src="https://lazy.example.com/y.jpg" />
  <ul><li class="ingredient">1 dl x</li></ul>
  <ol><li class="instruction">s</li></ol>
</body></html>
''';
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.recipe!.imageUrl, 'https://lazy.example.com/y.jpg');
    });

    /// `data-lazy-src` is the WordPress lazy-load plugin variant.
    test('falls back further to data-lazy-src', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <img class="hero" data-lazy-src="https://wp.example.com/z.jpg" />
  <ul><li class="ingredient">1 dl x</li></ul>
  <ol><li class="instruction">s</li></ol>
</body></html>
''';
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.recipe!.imageUrl, 'https://wp.example.com/z.jpg');
    });

    /// Relative paths and javascript: URLs MUST be rejected. The
    /// startsWith('http') guard is the only thing standing between us and
    /// rendering arbitrary src attributes downstream — flipping it from
    /// `startsWith` to `contains` would let `javascript:http(...)` through.
    test('non-http URL is rejected (returns null)', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <img class="hero" src="/relative/path.jpg" />
  <ul><li class="ingredient">1 dl x</li></ul>
  <ol><li class="instruction">s</li></ol>
</body></html>
''';
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.recipe!.imageUrl, isNull);
    });

    /// Missing image is acceptable — recipe must still surface.
    test('missing image selector hit → null, recipe still parses', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <ul><li class="ingredient">1 dl x</li></ul>
  <ol><li class="instruction">s</li></ol>
</body></html>
''';
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.imageUrl, isNull);
    });
  });

  // ----- portions ----------------------------------------------------------

  group('portions extraction', () {
    Future<FieldResult<int>?> portionsFor(String portionsText) async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith(portions: portionsText));
      final result = await tier.parse(ctx);
      return result.recipe?.portions;
    }

    /// Swedish "4 portioner" — the standard form.
    test('extracts first integer from text', () async {
      final p = await portionsFor('4 portioner');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.medium);
    });

    /// `0` portions is meaningless and would brick downstream multipliers.
    /// The `> 0` guard MUST reject it → falls back to default 4 low-conf.
    test('zero portions → fallback to default (defends > 0 guard)', () async {
      final p = await portionsFor('0 portioner');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.low,
          reason: 'fallback must surface low-confidence');
    });

    /// `9999 portions` would crash menu generation if it got through —
    /// kMaxPortions cap MUST reject it.
    test('absurdly large portions → fallback', () async {
      final p = await portionsFor('9999 servings');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.low);
    });

    /// Selector matches but text has no digits → low-conf default.
    test('no digits in portions text → low-conf default', () async {
      final p = await portionsFor('Serves family');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.low);
    });
  });

  // ----- time --------------------------------------------------------------

  group('time extraction', () {
    Future<Duration?> timeFor(String timeText) async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith(time: timeText));
      final result = await tier.parse(ctx);
      return result.recipe?.totalTime.value;
    }

    /// Plain "45 min" — most common form.
    test('parses "45 min" as 45 minutes', () async {
      expect(await timeFor('45 min'), const Duration(minutes: 45));
    });

    /// Swedish "tim" hour abbreviation.
    test('parses Swedish "1 tim 30 min" as 90 minutes', () async {
      expect(await timeFor('1 tim 30 min'), const Duration(minutes: 90));
    });

    /// English "1 hour 30 min" combined form.
    test('parses "1 hour 30 min" as 90 minutes', () async {
      expect(await timeFor('1 hour 30 min'), const Duration(minutes: 90));
    });

    /// Bare integer (no unit) → assumed to be minutes. Without this
    /// fallback, sites that publish "45" lose totalTime entirely.
    test('bare integer assumed to be minutes', () async {
      expect(await timeFor('45'), const Duration(minutes: 45));
    });

    /// "h" hour abbreviation with word boundary so it doesn't match
    /// "hello". Regex precision regression would lose this.
    test('parses "2h" as 2 hours', () async {
      expect(await timeFor('2h'), const Duration(hours: 2));
    });

    /// Empty time text → field failed (NOT zero-minute recipe).
    test('empty time text → failed field', () async {
      // Empty span text still satisfies selector match but text is "".
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(timeSelector: '.nope'),
      );
      final ctx = urlContextFor(htmlWith());
      final result = await tier.parse(ctx);

      expect(result.recipe!.totalTime.confidence, ParseConfidence.failed);
      expect(result.recipe!.totalTime.value, isNull);
    });
  });

  // ----- instructions ------------------------------------------------------

  group('instruction extraction', () {
    /// "1. " / "2) " prefixes duplicate the visual numbering the UI
    /// already provides — must be stripped or the user sees "1. 1. Mix".
    test('strips numbered prefixes from instructions', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith(instructions: [
        '1. First step',
        '2) Second step',
        '3. Third step',
      ]));

      final result = await tier.parse(ctx);

      expect(result.recipe!.instructions.value, [
        'First step',
        'Second step',
        'Third step',
      ]);
    });

    /// Whitespace normalised (tabs/newlines collapsed to single space).
    /// Otherwise multi-line li elements render with raw whitespace.
    test('normalises internal whitespace in instructions', () async {
      final html = '''
<html><body>
  <h1 class="recipe-title">T</h1>
  <ul><li class="ingredient">1 dl x</li></ul>
  <ol>
    <li class="instruction">Mix\n\n  the\t\t flour</li>
  </ol>
</body></html>
''';
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(html);

      final result = await tier.parse(ctx);

      expect(result.recipe!.instructions.value!.first, 'Mix the flour');
    });

    /// Missing instructions → instructions field failed, BUT recipe still
    /// surfaces (ingredients gate is the only hard requirement).
    test('missing instructions → field failed, recipe still surfaces',
        () async {
      final config = fullConfig(instructionsSelector: '.no-match');
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: config,
      );
      final ctx = urlContextFor(htmlWith());

      final result = await tier.parse(ctx);

      expect(result.success, isTrue,
          reason: 'title + ingredients sufficient for tier-level success');
      expect(result.recipe!.instructions.confidence, ParseConfidence.failed);
    });
  });

  // ----- document caching --------------------------------------------------

  group('document caching', () {
    /// First parse populates `context.parsedDocument`. Downstream tiers
    /// (rule-based, LLM) read this to skip re-parsing the same HTML.
    /// Pinning this proves the cross-tier optimization actually works.
    test('parsed document is cached on context for downstream tiers', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith());
      expect(ctx.parsedDocument, isNull,
          reason: 'fresh context must not have a cached document');

      await tier.parse(ctx);

      expect(ctx.parsedDocument, isNotNull,
          reason: 'tier MUST cache parsed Document for downstream reuse');
    });

    /// If the document is already cached, the tier MUST reuse it instead
    /// of re-parsing — saves CPU on cascaded tiers. We pre-populate the
    /// cache with a DIFFERENT document and verify the tier extracts from
    /// the cached one (not the raw html).
    test('uses cached document when present', () async {
      final tier = SiteConfigTier(
        ingredientStrategy: strategy,
        preloadedConfig: fullConfig(),
      );
      final ctx = urlContextFor(htmlWith(title: 'IgnoredTitle'));
      // Pre-populate cache with a different document.
      ctx.parsedDocument = html_parser.parse(htmlWith(title: 'CachedTitle'));

      final result = await tier.parse(ctx);

      expect(result.recipe!.title.value, 'CachedTitle',
          reason: 'tier must read from cached document, not re-parse raw HTML');
    });
  });

  // ----- tier identity -----------------------------------------------------

  group('tier identity', () {
    /// Priority 2 = runs after SchemaOrg (1), before RuleBased (3). The
    /// orchestrator order depends on this ordering — BUT-1064 tier
    /// injection seam.
    test('priority is 2 (runs after SchemaOrg, before RuleBased)', () {
      final tier = SiteConfigTier();
      expect(tier.priority, 2);
    });

    test('tierName is "SiteConfig" (matches tierIdentifier)', () {
      final tier = SiteConfigTier();
      expect(tier.tierName, 'SiteConfig');
      expect(tier.tierName, SiteConfigTier.tierIdentifier);
    });

    /// 10s timeout is generous — CSS selector lookup is sub-millisecond
    /// but the Firestore config load can be slow on cold cache. Changing
    /// without notice would silently regress slow-network parses.
    test('defaultTimeout is 10 seconds', () {
      final tier = SiteConfigTier();
      expect(tier.defaultTimeout, const Duration(seconds: 10));
    });

    /// Pinned so a refactor that flips the threshold doesn't silently
    /// admit weaker tier results.
    test('minQualityScore is 0.3', () {
      final tier = SiteConfigTier();
      expect(tier.minQualityScore, 0.3);
    });
  });

  // ----- metadata timestamp -----------------------------------------------

  group('metadata', () {
    /// `clock.now()` is used so `withClock(...)` can pin timestamps in
    /// tests. If the tier reverted to `DateTime.now()`, this assertion
    /// would fail — a real regression for log/event correlation.
    test('metadata.timestamp respects withClock override', () async {
      final fixedTime = DateTime.utc(2026, 1, 1, 12);
      late DateTime captured;

      await withClock(Clock.fixed(fixedTime), () async {
        final tier = SiteConfigTier(
          ingredientStrategy: strategy,
          preloadedConfig: fullConfig(),
        );
        final ctx = urlContextFor(htmlWith());

        final result = await tier.parse(ctx);
        captured = result.recipe!.metadata.timestamp;
      });

      expect(captured, fixedTime,
          reason: 'tier must use injectable clock for testability');
    });
  });
}
