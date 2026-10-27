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
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

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
  Map<String, dynamic>? extractWithCssSelectors(Document doc) => _recipe;
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
      expect(parser.enhanceRecipe(recipe, Document()), same(recipe));
    });

    test('extractWithCssSelectors returns null by default', () {
      expect(parser.extractWithCssSelectors(Document()), isNull);
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

  group('swedishTimeToIso8601', () {
    final parser = _NoopParser();

    test('minutes alone', () {
      expect(parser.swedishTimeToIso8601('30 minuter'), 'PT30M');
    });

    test('hours and minutes, any case', () {
      expect(parser.swedishTimeToIso8601('1 Timme 30 min'), 'PT1H30M');
    });

    test('a zero is matched but not written', () {
      expect(parser.swedishTimeToIso8601('0 min'), 'PT');
    });

    test('text without a number is null', () {
      expect(parser.swedishTimeToIso8601('en stund'), isNull);
    });
  });

  group('extractImage', () {
    final parser = _NoopParser();

    test('itemprop wins over every other selector', () {
      final doc = html_parser.parse(
        '<article><img src="https://x.se/article.jpg"></article>'
        '<div class="site-image"><img src="https://x.se/site.jpg"></div>'
        '<img itemprop="image" src="https://x.se/itemprop.jpg">',
      );
      expect(
        parser.extractImage(doc, siteImageSelector: '.site-image img'),
        'https://x.se/itemprop.jpg',
      );
    });

    test('the site selector is tried before the hero and article images', () {
      final doc = html_parser.parse(
        '<div class="recipe-hero"><img src="https://x.se/hero.jpg"></div>'
        '<div class="site-image"><img src="https://x.se/site.jpg"></div>',
      );
      expect(
        parser.extractImage(doc, siteImageSelector: '.site-image img'),
        'https://x.se/site.jpg',
      );
    });

    test('without a site selector the hero image is next', () {
      final doc = html_parser.parse(
        '<div class="site-image"><img src="https://x.se/site.jpg"></div>'
        '<div class="recipe-hero"><img src="https://x.se/hero.jpg"></div>',
      );
      expect(parser.extractImage(doc), 'https://x.se/hero.jpg');
    });

    test('data-src is used when src is missing', () {
      final doc = html_parser.parse(
        '<div class="recipe-image"><img data-src="https://x.se/lazy.jpg"></div>',
      );
      expect(parser.extractImage(doc), 'https://x.se/lazy.jpg');
    });

    test('a relative URL is skipped for the next selector', () {
      final doc = html_parser.parse(
        '<div class="recipe-image"><img src="/relative.jpg"></div>'
        '<article><img src="https://x.se/article.jpg"></article>',
      );
      expect(parser.extractImage(doc), 'https://x.se/article.jpg');
    });

    test('no image is null', () {
      expect(parser.extractImage(html_parser.parse('<p>inget</p>')), isNull);
    });
  });
}
