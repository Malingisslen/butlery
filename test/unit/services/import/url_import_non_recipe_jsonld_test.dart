import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/url_import_strategy.dart';

/// The third consumer of the JSON-LD decision, beside `HtmlSanitizer`'s
/// `sanitize()` and `check()`. It had no test of its own while it carried a
/// copy of the raw-source pattern, so BUT-2034's bypass and BUT-2037's loss
/// reached this signal too and nothing here reddened.
///
/// What the signal does: `true` means "this page has structured data, and
/// none of it is a recipe" — which the text-fallback tier turns into
/// `warningUrlImportNotARecipe`. A wrong answer is a misleading message to
/// the user, so both directions matter.
void main() {
  late UrlImportStrategy strategy;

  setUp(() {
    strategy = UrlImportStrategy();
  });

  String article(String type) =>
      '<script type="$type">{"@type":"NewsArticle","headline":"H"}</script>';

  String recipe(String type) =>
      '<script type="$type">{"@type":"Recipe","name":"Kladdkaka"}</script>';

  group('hasOnlyNonRecipeJsonLd', () {
    test('a page with only an article says so', () {
      expect(
        strategy.hasOnlyNonRecipeJsonLd(article('application/ld+json')),
        isTrue,
      );
    });

    test('a page with no structured data at all says nothing', () {
      expect(strategy.hasOnlyNonRecipeJsonLd('<p>bara text</p>'), isFalse);
    });

    // BUT-2037: the parser resolves every one of these to `+`, so each block
    // IS a recipe. Under the raw-source pattern the semicolon-less and named
    // spellings went unseen, the recipe was invisible, and a page carrying
    // both an article and a recipe was reported as "no recipe here".
    test('an entity-encoded recipe is FOUND, in every spelling', () {
      for (final spelling in const [
        'application/ld+json',
        'application/ld&#x2B;json',
        'application/ld&plus;json',
        'application/ld&#x2Bjson',
        'application/ld&#43json',
        'application/ld&#x02Bjson',
        'application/ld&#043json',
        'application/ld+json; charset=utf-8',
      ]) {
        expect(
          strategy.hasOnlyNonRecipeJsonLd(
            article('application/ld+json') + recipe(spelling),
          ),
          isFalse,
          reason: 'the recipe written as $spelling was not seen',
        );
      }
    });

    // BUT-2034: a `type=` inside another attribute's value is not a `type`
    // attribute. Such a block must not be counted as structured data at all —
    // under the raw-source pattern it was, so a page with no real JSON-LD
    // could still be reported as "structured data, but no recipe".
    test('a value-embedded `type=` is not structured data', () {
      const body = '{"@type":"NewsArticle"}</script>';
      for (final open in const [
        '<script data-cfg=" type=application/ld+json">',
        '<script data-cfg="text/type=application/ld+json">',
        '<script data-type="application/ld+json">',
      ]) {
        final markup = '$open$body';
        expect(
          strategy.hasOnlyNonRecipeJsonLd(markup),
          isFalse,
          reason: 'counted as JSON-LD: $markup',
        );
      }
    });

    test('a genuine article beside a decoy still reads as article-only', () {
      // Control for the case above: the decoy contributes nothing, but the
      // real block still does — without this, a predicate that answered
      // `false` to everything would satisfy the decoy assertions.
      expect(
        strategy.hasOnlyNonRecipeJsonLd(
          '<script data-type="application/ld+json">{"@type":"Recipe"}</script>'
          '${article('application/ld+json')}',
        ),
        isTrue,
      );
    });
  });
}
