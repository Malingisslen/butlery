/// Pins what the parsers do with the REAL page structure of ica.se and
/// arla.se, captured 2026-09-05.
///
/// These fixtures exist because the hand-authored ones agree with the
/// parsers by construction: both were written from the same guess about what
/// the sites emit. Everything below is measured against the live markup.
///
/// Most of what follows is a contract. An expectation whose name begins
/// `DEFECT` is not: it records behaviour we have measured and not yet fixed,
/// names the ticket that owns it, and is meant to go RED the day that ticket
/// lands. Do not "harmonise" one away.
///
/// When BUT-2020 turned such cases green, they were replaced by positive
/// assertions in the same edit as the fix — a defect test that simply
/// disappears takes the only coverage of that path with it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_quality_scorer.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/utils/recipe_scraper.dart';

import '../../../../fixtures/swedish_sites/arla_test_data.dart';
import '../../../../fixtures/swedish_sites/ica_test_data.dart';

void main() {
  group('ICA.se real page structure', () {
    final parser = IcaRecipeParser();

    test('parses, and the JSON-LD wins over the DOM', () {
      final recipe = parser.parseRecipe(
        IcaTestFixtures.realStructureBananomelett,
      );

      expect(recipe, isNotNull);
      expect(recipe!['recipeIngredient'], hasLength(6));
      expect(recipe['recipeInstructions'], hasLength(4));

      // The lengths alone cannot tell the two sources apart — the DOM in the
      // same fixture also holds 6 ingredient cards and 4 steps. The spacing
      // can: the JSON-LD line has one space, the DOM card renders two,
      // because the quantity sits in its own span.
      expect(recipe['recipeIngredient'], contains('1 halvmogen banan'));
    });

    test('recipeYield carries no unit on the live page', () {
      final recipe = parser.parseRecipe(
        IcaTestFixtures.realStructureBananomelett,
      )!;

      // The hand-authored fixtures all say "4 portioner". ICA says "2".
      // Anything deriving a portion count by splitting on a space gets
      // nothing to split.
      expect(recipe['recipeYield'], equals('2'));
    });

    test('recipeCategory is one comma-joined string, not a list', () {
      final recipe = parser.parseRecipe(
        IcaTestFixtures.realStructureBananomelett,
      )!;

      expect(recipe['recipeCategory'], equals('Brunch,Mellanmål'));
    });

    test('prepTime and cookTime are absent; only totalTime is served', () {
      final recipe = parser.parseRecipe(
        IcaTestFixtures.realStructureBananomelett,
      )!;

      expect(recipe['totalTime'], equals('PT30M'));
      expect(recipe.containsKey('prepTime'), isFalse);
      expect(recipe.containsKey('cookTime'), isFalse);
    });

    test('nutrition is present but its measured values are empty strings', () {
      final recipe = parser.parseRecipe(
        IcaTestFixtures.realStructureBananomelett,
      )!;
      final nutrition = recipe['nutrition'] as Map;

      // A "nutrition exists" check that does not look inside reports
      // nutritional data this recipe does not have. `servingSize` is
      // populated, so a check that samples one key can also mislead.
      expect(nutrition['calories'], equals(''));
      expect(nutrition['proteinContent'], equals(''));
      expect(nutrition['servingSize'], equals('2 Servings'));
    });
  });

  group('Arla.se real page structure', () {
    final parser = ArlaRecipeParser();
    final real = ArlaTestFixtures.realStructureKassler;

    test('parses this page', () {
      // The contract BUT-2020 bought: before the fix this returned null.
      // `parseRecipe` runs extraction, enhancement and the quality gate, so
      // a regression in any of the three lands here first.
      final recipe = parser.parseRecipe(real);

      expect(recipe, isNotNull);
      expect(recipe!['recipeIngredient'], hasLength(8));
      expect(recipe['recipeInstructions'], hasLength(4));
    });

    test(
      'the entity-encoded script type IS the fixture — writing the `+` '
      'plainly would take the encoding out of what this file measures',
      () {
        // Its own test, not a line inside the parse test, so that
        // "simplifying" the markup fails something whose name says why the
        // encoding is the whole point. A comment is what such an edit reads
        // past; a red test is not.
        expect(real, contains('application/ld&#x2B;json'));
        expect(real, isNot(contains('application/ld+json')));
      },
    );

    test('the entity-encoded script type is read, not skipped', () {
      // Cause 1. `_extractJsonLd` reads the attribute off the parsed
      // document; a regex over the raw source cannot see through the
      // character reference. Decoding the fixture by hand must therefore
      // make no difference at all.
      final decoded = real.replaceAll(
        'application/ld&#x2B;json',
        'application/ld+json',
      );

      expect(extractRecipeFromHtml(real), isNotNull);
      expect(
        extractRecipeFromHtml(real),
        equals(extractRecipeFromHtml(decoded)),
      );
    });

    test('HowToSection is flattened, so its steps survive', () {
      // Cause 2. The steps sit in `itemListElement` under one section; the
      // filter downstream keeps only maps carrying a top-level `text`.
      final extracted = extractRecipeFromHtml(real)!;
      final raw = extracted['recipeInstructions'] as List;
      expect(raw, hasLength(1), reason: 'one section in the source');
      expect((raw.first as Map)['itemListElement'], hasLength(4));

      final enhanced = parser.enhanceRecipe(
        Map<String, dynamic>.from(extracted),
        real,
      );
      final steps = enhanced['recipeInstructions'] as List;
      expect(steps, hasLength(4));
      expect((steps.first as Map)['text'], equals('Platshållarsteg ett.'));

      // The section's own name is a heading, not a step. schema_org_tier
      // emits it as one; this path deliberately does not.
      expect(
        steps.map((s) => (s as Map)['text']),
        isNot(contains('Första instruktionen')),
      );
    });

    test('the flattened recipe clears the quality bar', () {
      // Cause 2 was sufficient on its own to fail the page: an unflattened
      // section scored 0.70 against a 0.80 threshold. Pinning the exact
      // figure rather than the threshold is what makes the instruction
      // weight visible — 0.30 of it — instead of only the verdict.
      final score = RecipeQualityScorer.score(extractRecipeFromHtml(real)!);

      expect(score.meetsMinimumQuality, isTrue);
      expect(score.completeness, equals(1.0));
    });

    test(
      'DEFECT cause 3: the CSS fallback cannot rescue the page either',
      () {
        // Arla puts ingredients in a table — name in a <th>, amount in a
        // <td> after it. Every selector the parser tries wants an <li>, so
        // extractWithCssSelectors finds no ingredients and gives up.
        expect(parser.extractWithCssSelectors(real), isNull);

        // The table really is there and really does hold the rows, so this
        // is the selectors missing them rather than an empty fixture.
        expect(real, contains('<table'));
        expect(
          '<th'.allMatches(real).length,
          equals(8),
          reason: 'one <th> per ingredient row',
        );
      },
    );

    test('survives the sanitiser, which is where cause 1 actually bit', () {
      // The tiered pipeline reads sanitised HTML, and `sanitize()` strips
      // <script> WITH its content. Its exemption was a bare substring test,
      // so this page arrived empty before any extractor ran — the one leg
      // where cause 1 was reachable in production. Nothing else in this file
      // sends the real page through that leg.
      final sanitised = HtmlSanitizer.instance.sanitize(real);

      expect(sanitised, contains('recipeIngredient'));
      expect(extractRecipeFromHtml(sanitised), isNotNull);
    });

    test('the ingredient lines themselves survive intact', () {
      final extracted = extractRecipeFromHtml(real)!;

      expect(extracted['recipeIngredient'], hasLength(8));
      expect(
        extracted['recipeIngredient'],
        contains('150 g Arla® Färskost Naturell'),
      );
    });

    test('every duration on the live page is PT00M', () {
      final extracted = extractRecipeFromHtml(real)!;

      // Arla serves zeroes rather than omitting the fields, so a
      // presence check reports a time of nothing.
      expect(extracted['totalTime'], equals('PT00M'));
      expect(extracted['prepTime'], equals('PT00M'));
      expect(extracted['cookTime'], equals('PT00M'));
    });
  });
}
