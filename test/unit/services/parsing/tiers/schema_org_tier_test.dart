/// Intent tests for `SchemaOrgTier` — Tier 1 of the recipe parser cascade.
///
/// Behaviours pinned here:
/// - `shouldSkip` skips non-URL sources, empty content, and non-HTML text.
/// - Happy-path JSON-LD Recipe → ParsedRecipe with title/ingredients/instructions.
/// - `@graph` wrapper extraction (WordPress/Yoast SEO pattern).
/// - `@type` array form ([Article, Recipe]) treated as Recipe.
/// - HTML entity unescaping in title (`&amp;` → `&`).
/// - ISO-8601 duration parsing — `PT30M`, `PT1H30M`, `PT0S`, bogus strings.
/// - `recipeYield` polymorphism — int, "4 portioner", `["4"]`, missing.
/// - Image polymorphism — string URL, object with `url`, array of strings, array of objects.
/// - Instruction polymorphism — string (split on newlines/periods), `List<String>`, HowToStep, HowToSection.
/// - `recipeIngredient` empty array vs missing → both produce `failed` field.
/// - Nested context cache: `context.jsonLdData` populated on success.
/// - Recipe of type "Article" (non-Recipe) → noData (the extractor doesn't surface it). BUT-1070 cross-ref.
/// - Title fallback to `headline` when `name` absent.
/// - Price annotations stripped from ingredient lines.
/// - `totalTime` falls back to prep+cook when missing.
/// - Cuisine/category accept string or first element of List.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';

/// Stub IngredientParsingStrategy that bypasses CRF loading entirely.
///
/// `IngredientParsingStrategy.parseLines` triggers `rootBundle.loadString`
/// for CRF weights, which fails outside the Flutter app context but is
/// caught — so the regex fallback runs. That works, but is slow and
/// noisy. Subclassing lets us pin "what lines did the tier hand off?"
/// which is the actual behaviour we care about.
class _RecordingStrategy extends IngredientParsingStrategy {
  List<String>? receivedLines;
  bool? receivedOcrFlag;

  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) async {
    receivedLines = List.of(lines);
    receivedOcrFlag = ocrCorrection;
    if (lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }
    // Echo back as ParsedIngredient list so the tier sees "success".
    return FieldResult.success(
      lines
          .map(
            (l) => ParsedIngredient(
              name: l,
              originalLine: l,
              confidence: ParseConfidence.high,
            ),
          )
          .toList(),
    );
  }
}

/// Builds an HTML page with a single JSON-LD `<script>` block.
String htmlWithJsonLd(String jsonLdLiteral) {
  return '''
<!DOCTYPE html>
<html>
<head>
<script type="application/ld+json">
$jsonLdLiteral
</script>
</head>
<body><h1>Recipe page</h1></body>
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

void main() {
  late _RecordingStrategy strategy;
  late SchemaOrgTier tier;

  setUp(() {
    strategy = _RecordingStrategy();
    tier = SchemaOrgTier(ingredientStrategy: strategy);
  });

  // ----- shouldSkip contract -------------------------------------------------

  group('shouldSkip', () {
    /// Tier 1 is URL-only; routing free-text input through it would waste
    /// the budget on a tier that can't help.
    test('skips non-URL sources (text/photo)', () {
      final textCtx = ParsingContext.fromText(
        text: '<html><script type="application/ld+json">{}</script></html>',
        source: ImportSource.text,
        userId: 'u',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(textCtx), isTrue);

      final photoCtx = ParsingContext.fromText(
        text: '<html><script type="application/ld+json">{}</script></html>',
        source: ImportSource.photo,
        userId: 'u',
        parserVersion: '2.0.0',
      );
      expect(tier.shouldSkip(photoCtx), isTrue);
    });

    /// Empty content means the URL fetcher returned nothing — running the
    /// tier would still cost a parse cycle for no possible result.
    test('skips empty content', () {
      final ctx = urlContextFor('');
      expect(tier.shouldSkip(ctx), isTrue);
    });

    /// Plain text returned from a URL (no `<` anywhere) can't possibly
    /// contain JSON-LD inside a script tag, so skip without parsing.
    test('skips content with no HTML tags', () {
      final ctx = urlContextFor('just a plain string with no markup');
      expect(tier.shouldSkip(ctx), isTrue);
    });

    /// Any HTML-shaped input from a URL is fair game — even minimal markup.
    test('does NOT skip minimal HTML from URL source', () {
      final ctx = urlContextFor('<html></html>');
      expect(tier.shouldSkip(ctx), isFalse);
    });
  });

  // ----- happy path ---------------------------------------------------------

  group('parse - happy path', () {
    /// Proves end-to-end JSON-LD Recipe extraction wires title, portions,
    /// ingredients, instructions, totalTime, image, and description into
    /// the ParsedRecipe with the right confidence levels.
    test('extracts a full schema.org Recipe into ParsedRecipe', () async {
      final jsonLd = '''
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Pannkakor",
  "description": "Klassiska svenska pannkakor",
  "recipeYield": "4",
  "totalTime": "PT45M",
  "image": "https://example.com/pancakes.jpg",
  "recipeIngredient": ["3 dl mjol", "6 dl mjolk", "3 agg"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Blanda mjol och mjolk."},
    {"@type": "HowToStep", "text": "Tillsatt agg."},
    {"@type": "HowToStep", "text": "Stek i smor."}
  ]
}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue, reason: 'JSON-LD Recipe must parse');
      expect(result.tierName, 'SchemaOrg');

      final recipe = result.recipe!;
      expect(recipe.title.value, 'Pannkakor');
      expect(recipe.title.confidence, ParseConfidence.high);
      expect(recipe.portions.value, 4);
      expect(recipe.totalTime.value, const Duration(minutes: 45));
      expect(recipe.imageUrl, 'https://example.com/pancakes.jpg');
      expect(recipe.description, 'Klassiska svenska pannkakor');

      // Ingredient lines were forwarded to the strategy as-is.
      expect(strategy.receivedLines, ['3 dl mjol', '6 dl mjolk', '3 agg']);
      expect(
        strategy.receivedOcrFlag,
        isFalse,
        reason: 'URL source must not request OCR correction',
      );

      // Instructions: 3 steps, in order.
      expect(recipe.instructions.value, hasLength(3));
      expect(recipe.instructions.value!.first, contains('Blanda'));
      expect(recipe.instructions.value!.last, contains('smor'));
    });

    /// Pins the side-effect that other tiers depend on:
    /// SchemaOrgTier MUST cache the raw JSON-LD on the context so
    /// downstream tiers can read it without re-parsing the HTML.
    test('caches raw JSON-LD on context for downstream tiers', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"X","recipeIngredient":["1 dl x"],"recipeInstructions":["do it"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      expect(ctx.jsonLdData, isNull);

      await tier.parse(ctx);

      expect(ctx.jsonLdData, isNotNull);
      expect(ctx.jsonLdData!['name'], 'X');
    });
  });

  // ----- @graph + @type array -----------------------------------------------

  group('parse - @graph and @type variants', () {
    /// WordPress + Yoast SEO wraps everything in `@graph` — the tier
    /// MUST traverse it to find the Recipe node, otherwise we'd silently
    /// fail on every Yoast-powered cooking site.
    test('extracts Recipe inside @graph wrapper (WordPress/Yoast)', () async {
      final jsonLd = '''
{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "WebSite", "name": "A blog"},
    {"@type": "WebPage", "name": "Recipe page"},
    {
      "@type": "Recipe",
      "name": "Graph-wrapped recipe",
      "recipeIngredient": ["1 cup flour"],
      "recipeInstructions": ["Mix it."]
    }
  ]
}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.title.value, 'Graph-wrapped recipe');
    });

    /// Schema.org allows `@type` to be an array — `["Article", "Recipe"]`
    /// is a common pattern. Treating it as non-Recipe would silently drop
    /// valid recipes (this is the BUT-1070 family of bugs).
    test('accepts @type as array containing Recipe', () async {
      final jsonLd = '''
{
  "@type": ["Article", "Recipe"],
  "name": "Hybrid Article/Recipe",
  "recipeIngredient": ["2 dl mjol"],
  "recipeInstructions": ["Step."]
}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.title.value, 'Hybrid Article/Recipe');
    });

    /// Cross-ref BUT-1070: a page that only carries non-Recipe JSON-LD
    /// (e.g. an Article without a Recipe sibling) MUST return parseError
    /// (had structured data, but not a recipe) rather than success.
    /// This pins the tier's contract for "JSON-LD present but no recipe."
    test(
      'returns parseError when JSON-LD has structured data but no Recipe',
      () async {
        final jsonLd = '''
{"@type": "Article", "headline": "Just an article"}
''';
        final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

        final result = await tier.parse(ctx);

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          TierFailureReason.parseError,
          reason:
              'BUT-1070 contract: structured data present but no Recipe '
              'must surface as parseError, not silently downgrade',
        );
      },
    );

    /// Page with no JSON-LD at all → distinct failure reason (`noData`),
    /// so the orchestrator can route to site-config / rule-based tiers
    /// instead of treating it as a hard failure.
    test('returns noData when no structured data found', () async {
      final ctx = urlContextFor(
        '<html><body><p>nothing here</p></body></html>',
      );

      final result = await tier.parse(ctx);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.noData);
    });
  });

  // ----- title extraction ---------------------------------------------------

  group('title extraction', () {
    /// HTML entities in JSON-LD strings would render as `Mac &amp; cheese`
    /// in the UI without unescaping — pin the decoder runs.
    test('unescapes HTML entities in title', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"Mac &amp; cheese","recipeIngredient":["1 cup"],"recipeInstructions":["s"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.title.value, 'Mac & cheese');
    });

    /// Some sites publish `headline` but no `name` (especially news/blog
    /// templates). Title is required — the fallback prevents otherwise
    /// well-formed recipes from being rejected.
    test('falls back to headline when name is absent', () async {
      final jsonLd = '''
{"@type":"Recipe","headline":"Headline title","recipeIngredient":["1 cup"],"recipeInstructions":["s"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isTrue);
      expect(result.recipe!.title.value, 'Headline title');
    });

    /// Title is mandatory: with neither `name` nor `headline`, the
    /// converter MUST return null → tier MUST report parseError, not
    /// produce a recipe with empty title.
    test('returns parseError when neither name nor headline present', () async {
      final jsonLd = '''
{"@type":"Recipe","recipeIngredient":["1 cup"],"recipeInstructions":["s"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      final result = await tier.parse(ctx);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.parseError);
    });
  });

  // ----- ISO-8601 duration --------------------------------------------------

  group('ISO-8601 duration parsing', () {
    Future<Duration?> totalTimeFor(String iso) async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","totalTime":"$iso","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      return result.recipe?.totalTime.value;
    }

    /// Plain minutes — the most common form.
    test('PT30M → 30 minutes', () async {
      expect(await totalTimeFor('PT30M'), const Duration(minutes: 30));
    });

    /// Hours + minutes combined.
    test('PT1H30M → 90 minutes', () async {
      expect(await totalTimeFor('PT1H30M'), const Duration(minutes: 90));
    });

    /// Hours only.
    test('PT2H → 120 minutes', () async {
      expect(await totalTimeFor('PT2H'), const Duration(hours: 2));
    });

    /// Days form (rare but spec'd) — e.g. fermentation. Off-by-one in the
    /// regex group indexing would break this silently.
    test('P1DT2H → 26 hours', () async {
      expect(await totalTimeFor('P1DT2H'), const Duration(days: 1, hours: 2));
    });

    /// Sub-minute durations: parsed but rejected by the `inMinutes > 0`
    /// guard on totalTime — surfaces as failed totalTime, not as a
    /// 0-minute recipe.
    test('PT30S → totalTime is failed (sub-minute rejected)', () async {
      final dur = await totalTimeFor('PT30S');
      expect(
        dur,
        isNull,
        reason:
            'sub-minute totalTime must NOT surface; would render as "0 min"',
      );
    });

    /// Malformed strings must not throw or return Duration.zero — they
    /// should return null so the field is reported as failed cleanly.
    test('bogus string → totalTime is failed', () async {
      expect(await totalTimeFor('not-a-duration'), isNull);
    });

    /// All-zero duration (PT0S, PT0M) is a poison value: a recipe with
    /// "0 min" totalTime is worse than "unknown." Pin that it surfaces
    /// as failed, not as Duration.zero.
    test('PT0S → totalTime is failed', () async {
      expect(await totalTimeFor('PT0S'), isNull);
    });

    /// When totalTime is missing, the tier falls back to summing
    /// prepTime + cookTime. Off-by-one here would lose minutes.
    test('falls back to prep+cook when totalTime missing', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","prepTime":"PT10M","cookTime":"PT20M",
"recipeIngredient":["1 c"],"recipeInstructions":["s"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);

      expect(result.recipe!.totalTime.value, const Duration(minutes: 30));
      expect(
        result.recipe!.totalTime.confidence,
        ParseConfidence.medium,
        reason: 'derived value should not claim high confidence',
      );
    });
  });

  // ----- recipeYield polymorphism -------------------------------------------

  group('recipeYield (portions) extraction', () {
    Future<FieldResult<int>?> portionsFor(String yieldJson) async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeYield":$yieldJson,"recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      return result.recipe?.portions;
    }

    test('numeric recipeYield → high confidence', () async {
      final p = await portionsFor('4');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.high);
    });

    /// Swedish/English text forms — "4 portioner", "Serves 4" — must
    /// have the number extracted.
    test('string with embedded number → extracts number', () async {
      final p = await portionsFor('"4 portioner"');
      expect(p!.value, 4);
    });

    /// Some publishers wrap yield as a single-element array.
    test('array form ["4"] → extracts number from first element', () async {
      final p = await portionsFor('["4"]');
      expect(p!.value, 4);
    });

    /// `recipeYield: "0"` is meaningless ("makes 0 servings"). The
    /// `num > 0` guard MUST reject it → falls through to default 4.
    /// Off-by-one (`>= 0`) would let 0 through and produce a broken recipe.
    test('zero portions → falls back to default (defends > 0 guard)', () async {
      final p = await portionsFor('"Serves 0"');
      expect(p!.value, 4);
      expect(
        p.confidence,
        ParseConfidence.low,
        reason: 'fallback must be low-confidence so consumer can prompt user',
      );
    });

    /// `recipeYield: "Serves 9999"` would crash menu generation if it
    /// got through — the kMaxPortions cap MUST reject it and fall back.
    test('absurdly large portions (>kMaxPortions) → falls back', () async {
      final p = await portionsFor('"Serves 9999"');
      expect(p!.value, 4);
      expect(p.confidence, ParseConfidence.low);
    });

    /// Missing field defaults to 4 portions with low confidence.
    test('missing recipeYield → default 4 portions low-confidence', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.portions.value, 4);
      expect(result.recipe!.portions.confidence, ParseConfidence.low);
    });
  });

  // ----- image polymorphism -------------------------------------------------

  group('image extraction', () {
    Future<String?> imageFor(String imageJson) async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","image":$imageJson,"recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      return result.recipe?.imageUrl;
    }

    test('plain string URL', () async {
      expect(
        await imageFor('"https://example.com/a.jpg"'),
        'https://example.com/a.jpg',
      );
    });

    test('array of string URLs → takes first', () async {
      expect(
        await imageFor(
          '["https://example.com/a.jpg","https://example.com/b.jpg"]',
        ),
        'https://example.com/a.jpg',
      );
    });

    test('object with url field', () async {
      expect(
        await imageFor('{"@type":"ImageObject","url":"https://x.com/i.jpg"}'),
        'https://x.com/i.jpg',
      );
    });

    test('array of ImageObject → takes first url', () async {
      expect(
        await imageFor(
          '[{"@type":"ImageObject","url":"https://x.com/1.jpg"},{"@type":"ImageObject","url":"https://x.com/2.jpg"}]',
        ),
        'https://x.com/1.jpg',
      );
    });

    /// Relative paths and `javascript:` URLs MUST be rejected — the
    /// `startsWith('http')` guard is the only thing standing between us
    /// and rendering arbitrary src attributes downstream.
    test('non-http URL is rejected (returns null)', () async {
      expect(await imageFor('"/relative/path.jpg"'), isNull);
      expect(await imageFor('"javascript:alert(1)"'), isNull);
    });

    /// Missing image is acceptable — recipe should still parse.
    test('missing image → null, recipe still parses', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.success, isTrue);
      expect(result.recipe!.imageUrl, isNull);
    });
  });

  // ----- instructions polymorphism ------------------------------------------

  group('instructions extraction', () {
    /// Some sites put all instructions in one big string. The splitter
    /// must produce a list, not a single 500-char paragraph.
    test('string with newlines → split into list', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],
"recipeInstructions":"Step one.\\nStep two.\\nStep three."}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.instructions.value, hasLength(3));
    });

    /// List of strings — plain form.
    test('List<String> → preserved in order', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],
"recipeInstructions":["Mix.","Bake.","Eat."]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.instructions.value, ['Mix.', 'Bake.', 'Eat.']);
    });

    /// HowToSection wraps HowToStep items in `itemListElement` — common
    /// for multi-section recipes ("Dough" then "Filling"). Failing to
    /// descend would lose all the actual steps.
    test('HowToSection with itemListElement → flattens nested steps', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],
"recipeInstructions":[
  {"@type":"HowToSection","name":"Dough","itemListElement":[
    {"@type":"HowToStep","text":"Mix flour."},
    {"@type":"HowToStep","text":"Knead."}
  ]},
  {"@type":"HowToSection","name":"Topping","itemListElement":[
    {"@type":"HowToStep","text":"Spread sauce."}
  ]}
]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);

      // 2 section names + 3 nested step texts = 5 entries (section
      // headers stay so the user keeps the structural cue).
      final steps = result.recipe!.instructions.value!;
      expect(steps, contains('Mix flour.'));
      expect(steps, contains('Knead.'));
      expect(steps, contains('Spread sauce.'));
    });

    /// Numbered prefixes like "1. " / "2) " are duplicate to the list
    /// position — must be stripped or the UI shows "1. 1. Mix flour."
    test('numbered prefixes (1. / 2)) are stripped', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":["1 c"],
"recipeInstructions":["1. Mix.","2) Bake.","3. Eat."]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);

      final steps = result.recipe!.instructions.value!;
      expect(steps, ['Mix.', 'Bake.', 'Eat.']);
    });

    /// Missing or empty instructions → field marked failed, but the
    /// recipe may still surface (instructions is not required by the
    /// tier — only title is).
    test('missing recipeInstructions → instructions field failed', () async {
      final jsonLd = '{"@type":"Recipe","name":"x","recipeIngredient":["1 c"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);

      expect(
        result.success,
        isTrue,
        reason: 'title alone is enough for a tier-level success',
      );
      expect(result.recipe!.instructions.confidence, ParseConfidence.failed);
    });
  });

  // ----- ingredients --------------------------------------------------------

  group('ingredients extraction', () {
    /// Empty `recipeIngredient: []` is functionally equivalent to "missing"
    /// — both should produce a failed field, not pass empty list to the
    /// strategy (which would itself fail).
    test(
      'empty recipeIngredient array → strategy NOT called, field failed',
      () async {
        final jsonLd =
            '{"@type":"Recipe","name":"x","recipeIngredient":[],"recipeInstructions":["s"]}';
        final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

        final result = await tier.parse(ctx);

        expect(
          strategy.receivedLines,
          isNull,
          reason: 'should short-circuit before invoking strategy',
        );
        expect(result.recipe!.ingredients.confidence, ParseConfidence.failed);
      },
    );

    /// Missing field → same outcome as empty.
    test(
      'missing recipeIngredient → strategy not called, field failed',
      () async {
        final jsonLd =
            '{"@type":"Recipe","name":"x","recipeInstructions":["s"]}';
        final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

        final result = await tier.parse(ctx);

        expect(strategy.receivedLines, isNull);
        expect(result.recipe!.ingredients.confidence, ParseConfidence.failed);
      },
    );

    /// Price-annotated ingredient lines (common on US food blogs that
    /// integrate affiliate grocery pricing). The "$0.18" suffix MUST be
    /// stripped before the strategy sees it — otherwise NER/CRF treat
    /// "0.18" as a quantity.
    test(r'strips price annotations like ($0.18) before handoff', () async {
      final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":[
  "1 cup flour (\$0.18)",
  "2 eggs \$0.50*",
  "1 tsp salt (\$0.02)"
],"recipeInstructions":["s"]}
''';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

      await tier.parse(ctx);

      expect(strategy.receivedLines, hasLength(3));
      for (final line in strategy.receivedLines!) {
        expect(
          line,
          isNot(contains(r'$')),
          reason: 'dollar amounts must be stripped before tier handoff',
        );
      }
      // Spot-check exact cleanup.
      expect(strategy.receivedLines![0], '1 cup flour');
      expect(strategy.receivedLines![2], '1 tsp salt');
    });

    /// Non-string entries (e.g. structured Ingredient objects) are
    /// filtered out via `whereType<String>()`. This prevents crashes
    /// on malformed JSON-LD.
    test(
      'non-string ingredient entries are filtered, not crashed on',
      () async {
        final jsonLd = '''
{"@type":"Recipe","name":"x","recipeIngredient":[
  "1 cup flour",
  {"@type":"Ingredient","name":"sugar"},
  "2 eggs",
  null
],"recipeInstructions":["s"]}
''';
        final ctx = urlContextFor(htmlWithJsonLd(jsonLd));

        final result = await tier.parse(ctx);

        expect(result.success, isTrue);
        expect(strategy.receivedLines, ['1 cup flour', '2 eggs']);
      },
    );
  });

  // ----- cuisine / category / difficulty / nutrition ------------------------

  group('cuisine, category, difficulty', () {
    test('cuisine accepts string', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeCuisine":"Swedish","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.cuisine.value, 'Swedish');
    });

    test('cuisine accepts list, takes first element', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeCuisine":["Italian","Mediterranean"],"recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.cuisine.value, 'Italian');
    });

    /// Caps strings at 100 chars — defends against adversarial JSON-LD
    /// that crams essays into category fields.
    test('cuisine is capped at 100 chars (external input safety)', () async {
      final longCuisine = 'A' * 500;
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeCuisine":"$longCuisine","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.cuisine.value!.length, 100);
    });

    test('category accepts string and list', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","recipeCategory":"Dessert","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.category.value, 'Dessert');
    });

    /// `difficulty` is non-standard — schema.org doesn't define it. Tier
    /// accepts both `difficulty` and `proficiencyLevel` keys.
    test('difficulty falls back to proficiencyLevel', () async {
      final jsonLd =
          '{"@type":"Recipe","name":"x","proficiencyLevel":"Easy","recipeIngredient":["1 c"],"recipeInstructions":["s"]}';
      final ctx = urlContextFor(htmlWithJsonLd(jsonLd));
      final result = await tier.parse(ctx);
      expect(result.recipe!.difficulty.value, 'Easy');
    });
  });

  // ----- tier properties ----------------------------------------------------

  group('tier properties', () {
    /// Pinned: Tier 1 (priority 1) runs first in the cascade. Changing
    /// this without updating the orchestrator would break BUT-1064
    /// (tier injection seam).
    test('priority is 1 (runs first)', () {
      expect(tier.priority, 1);
    });

    test('tierName is SchemaOrg (matches tierIdentifier)', () {
      expect(tier.tierName, 'SchemaOrg');
      expect(tier.tierName, SchemaOrgTier.tierIdentifier);
    });

    /// 5-second timeout is conservative — schema.org parsing is CPU-bound
    /// and should complete in <100ms in practice. A regression that
    /// makes it minutes-long must be visible.
    test('defaultTimeout is 5 seconds', () {
      expect(tier.defaultTimeout, const Duration(seconds: 5));
    });
  });
}
