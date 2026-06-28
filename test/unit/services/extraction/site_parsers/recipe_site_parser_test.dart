/// Direct unit tests for [RecipeSiteParser] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Covers the parts of the abstract base class that hold real logic without
/// needing a live site: the Swedish difficulty detector, the text cleaner, and
/// the parseRecipe template method's control flow (JSON-LD miss → CSS fallback →
/// quality gate). Tiny concrete subclasses stand in for real site parsers so the
/// template method can be exercised in isolation. No mocks, no network.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';

/// A parser with no site-specific overrides — exercises the default no-op
/// enhanceRecipe / extractWithCssSelectors and the all-paths-fail branch.
class _NoopParser extends RecipeSiteParser {
  @override
  String get domain => 'example.test';
  @override
  String get siteName => 'Example';
}

/// A parser whose CSS fallback returns a recipe complete enough to pass the
/// minimum-quality gate (title + 3 ingredients + 2 instructions = 0.80).
class _CssFallbackParser extends RecipeSiteParser {
  _CssFallbackParser(this._recipe);
  final Map<String, dynamic>? _recipe;
  @override
  String get domain => 'example.test';
  @override
  String get siteName => 'Example';
  @override
  Map<String, dynamic>? extractWithCssSelectors(String html) => _recipe;
}

Map<String, dynamic> _completeRecipe() => {
  'name': 'Köttbullar',
  'recipeIngredient': ['500 g köttfärs', '1 ägg', '2 dl ströbröd'],
  'recipeInstructions': ['Blanda allt', 'Stek bullarna'],
};

void main() {
  group('extractDifficulty', () {
    final parser = _NoopParser();

    test('detects each Swedish difficulty level', () {
      expect(parser.extractDifficulty('Svårighetsgrad: Svår'), 'Svår');
      expect(parser.extractDifficulty('En avancerad rätt'), 'Avancerad');
      expect(parser.extractDifficulty('Medel'), 'Medel');
      expect(parser.extractDifficulty('Enkel vardagsmat'), 'Enkel');
      expect(parser.extractDifficulty('Lätt att laga'), 'Lätt');
    });

    test('is case-insensitive', () {
      expect(parser.extractDifficulty('SVÅR'), 'Svår');
    });

    test('returns null when no level is present', () {
      expect(parser.extractDifficulty('Köttbullar med potatismos'), isNull);
    });

    test('harder levels take precedence over easier ones', () {
      // "svår" is checked before "enkel", so the harder reading wins.
      expect(parser.extractDifficulty('inte enkel, snarare svår'), 'Svår');
    });
  });

  group('cleanSwedishText', () {
    final parser = _NoopParser();

    test('collapses whitespace and trims', () {
      expect(parser.cleanSwedishText('  hej   då  '), 'hej då');
    });

    test('normalizes smart quotes and em/en dashes', () {
      expect(parser.cleanSwedishText('“hoj”'), '"hoj"');
      expect(parser.cleanSwedishText('1–2'), '1-2');
      expect(parser.cleanSwedishText('a—b'), 'a-b');
    });

    test('preserves Swedish characters', () {
      expect(
        parser.cleanSwedishText('Köttbullar à la Åsa'),
        'Köttbullar à la Åsa',
      );
    });
  });

  group('default overrides', () {
    final parser = _NoopParser();

    test('enhanceRecipe returns the recipe unchanged', () {
      final recipe = {'name': 'x'};
      expect(parser.enhanceRecipe(recipe, '<html></html>'), same(recipe));
    });

    test('extractWithCssSelectors returns null by default', () {
      expect(parser.extractWithCssSelectors('<html></html>'), isNull);
    });
  });

  group('parseRecipe template method', () {
    test('returns null when no JSON-LD and no CSS fallback', () {
      // Plain text has no structured data; default CSS fallback is null too.
      expect(_NoopParser().parseRecipe('inget recept här'), isNull);
    });

    test('surfaces a CSS-fallback recipe that meets minimum quality', () {
      final parser = _CssFallbackParser(_completeRecipe());
      final result = parser.parseRecipe('inget recept här');
      expect(result, isNotNull);
      expect(result!['name'], 'Köttbullar');
    });

    test('rejects a CSS-fallback recipe below the quality bar', () {
      // Title only (0.20) is well below the 0.80 minimum.
      final parser = _CssFallbackParser({'name': 'Bara en titel'});
      expect(parser.parseRecipe('inget recept här'), isNull);
    });
  });
}
