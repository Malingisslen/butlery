// Pins the JSON-LD detection JS embedded in
// RecipeSiteContentExtractor._extractJsonLd() (BUT-2035).
//
// This JS runs inside `evaluateJavascript()` against a real WebView with no
// seam to inject a fake DOM, so it cannot be exercised end-to-end from a
// plain `flutter test`. What follows are structural/source pins instead:
// they assert the actual embedded JS source text rather than executing it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeSiteContentExtractor JSON-LD JS predicate (BUT-2035)', () {
    late String source;

    setUpAll(() {
      final raw = File(
        'lib/services/extraction/extractors/recipe_site_content_extractor.dart',
      ).readAsStringSync();

      // Blank out `//` comment bodies before asserting. Without this, moving
      // the live code into a comment and replacing it with something dead
      // leaves every assertion below green — demonstrated, not supposed.
      // Blanking preserves length (rather than deleting) because the
      // isolation test compares indexOf/lastIndexOf offsets, which a
      // length-changing strip would silently shift.
      source = raw
          .split('\n')
          .map((line) {
            final marker = line.indexOf('//');
            if (marker < 0) return line;
            return line.substring(0, marker) + ' ' * (line.length - marker);
          })
          .join('\n');
      expect(source.length, raw.length);
    });

    test('does not gather scripts by an exact type= attribute match', () {
      // The original bug: `querySelectorAll('script[type="application/ld+json"]')`
      // is an exact-value CSS attribute match, so it misses
      // `application/ld+json; charset=utf-8` — a legal media-type parameter.
      // Gathering every <script> and filtering with a
      // media-type-aware predicate (below) is what fixes it.
      expect(
        source,
        isNot(
          contains(
            'querySelectorAll(\'script[type="application/ld+json"]\')',
          ),
        ),
      );
      expect(source, contains("querySelectorAll('script')"));
    });

    test(
      'the predicate splits on the media-type parameter',
      () {
        // Second implementation of the same rule as Dart's
        // isJsonLdMediaType() (lib/utils/recipe_scraper.dart) — this JS runs
        // inside evaluateJavascript() and cannot call into Dart, so the two
        // must be kept in sync by hand.
        expect(
          source,
          contains(
            "typeAttr.split(';')[0].trim().toLowerCase() === 'application/ld+json'",
          ),
        );
      },
    );

    test(
      "each script's WHOLE body runs inside its own try/catch",
      () {
        final forLoopStart = source.indexOf('for (const script of scripts)');
        expect(forLoopStart, greaterThan(-1));

        final parseCallIndex = source.indexOf(
          'JSON.parse(script.textContent)',
          forLoopStart,
        );
        expect(parseCallIndex, greaterThan(forLoopStart));

        // A `try {` closer to the parse call than the for-loop's own opening
        // brace scopes the try to ONE script rather than to the whole loop.
        final tryBeforeParse = source.lastIndexOf('try {', parseCallIndex);
        expect(tryBeforeParse, greaterThan(forLoopStart));

        // The kill is HERE. Scoping the try to JSON.parse alone is not enough
        // and already passed the assertions above: a block that parses
        // but carries an unexpected shape (`null`, an object `@graph`, a
        // string `recipeIngredient`) throws in the walk BELOW the parse, past
        // the loop, and still aborts every later script on the page. So the
        // catch must sit after the item walk, not between it and the parse.
        final itemLoopStart = source.indexOf(
          'for (const item of recipes)',
          parseCallIndex,
        );
        expect(itemLoopStart, greaterThan(parseCallIndex));

        final catchAfterParse = source.indexOf('catch (e) {', parseCallIndex);
        expect(
          catchAfterParse,
          greaterThan(itemLoopStart),
          reason:
              'the catch must enclose the shape walk, or a well-formed JSON '
              'block with an unexpected shape still kills the whole page',
        );

        // Bounded: an unbounded search would be satisfied by any `continue;`
        // anywhere later in the file, including one outside this loop.
        final loopEnd = source.indexOf('return null;', catchAfterParse);
        expect(loopEnd, greaterThan(catchAfterParse));

        final continueAfterCatch = source.indexOf('continue;', catchAfterParse);
        expect(
          continueAfterCatch,
          inInclusiveRange(catchAfterParse, loopEnd),
          reason:
              'a caught error must move on to the NEXT script, not abort '
              'extraction of the rest of the page',
        );
      },
    );
  });
}
