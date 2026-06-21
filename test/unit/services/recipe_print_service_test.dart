/// BUT-1347 (ENG-26): RecipePrintService — HTML generation contract and
/// no-op stub safety on non-web platforms.
///
/// ## What's testable here vs what's web-only
///
/// The production conditional export resolves to the stub (`printRecipeHtml`
/// in `recipe_print_service_stub.dart`) on non-web targets.  The web
/// implementation in `recipe_print_service_web.dart` imports `dart:js_interop`
/// and `package:web` for the `window.open()` call — those only compile under
/// a browser target.
///
/// The HTML builder (`_buildRecipeHtml`) and XSS-escape helper (`_esc`) are
/// pure Dart and contain no web APIs, but they are private top-level functions
/// inside the web file.  Without a `@visibleForTesting` or an extracted
/// platform-agnostic module, they cannot be imported here.
///
/// Tests in this file cover:
/// 1. The non-web stub completes without throwing for any recipe shape.
/// 2. Edge-case recipe shapes that should not crash the stub (empty lists,
///    null optional fields, special characters in title).
///
/// The HTML structure/content invariants (title in <h1>, ingredients in <ul>,
/// XSS escaping of <>&" in recipe fields, portions/time in meta line, source
/// URL conditional rendering) cannot be tested without either:
///   a) Running under a web compilation target, or
///   b) Extracting `_buildRecipeHtml` and `_esc` into a separate
///      platform-agnostic file (deferred production refactor, BUT-1347).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/recipe_print_service.dart';

import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('RecipePrintService stub (non-web, BUT-1347 ENG-26)', () {
    // Intent: proves printRecipeHtml() is a safe no-op on non-web so that
    // any UI code that calls it cross-platform never crashes on iOS/Android.
    test('printRecipeHtml() completes without throwing for a standard recipe',
        () async {
      final recipe = RecipeFactory.build(
        title: 'Köttbullar',
        ingredients: ['500 g nötfärs', '1 lök', '1 ägg'],
        instructions: ['Blanda färsen.', 'Forma bullar.', 'Stek i smör.'],
        portions: 4,
        timeMinutes: 30,
        sourceUrl: 'https://example.com/kottbullar',
      );

      await expectLater(printRecipeHtml(recipe), completes);
    });

    // Intent: proves printRecipeHtml() handles a recipe with empty ingredient
    // and instruction lists without crashing — edge case that could panic in
    // a loop that expects non-empty collections.
    test('printRecipeHtml() completes for a recipe with empty lists', () async {
      final recipe = RecipeFactory.build(
        ingredients: [],
        instructions: [],
      );

      await expectLater(printRecipeHtml(recipe), completes);
    });

    // Intent: proves printRecipeHtml() handles null optional fields (portions,
    // timeMinutes, sourceUrl) without crashing — the web builder conditionally
    // renders these; the stub must be equally forgiving.
    test(
        'printRecipeHtml() completes for a recipe with all optional fields null',
        () async {
      final recipe = RecipeFactory.build(
        portions: null,
        timeMinutes: null,
        sourceUrl: null,
      );

      await expectLater(printRecipeHtml(recipe), completes);
    });

    // Intent: proves printRecipeHtml() tolerates HTML-special characters in
    // the title — XSS-escaping in the web builder must not be the only thing
    // preventing a crash; the stub must not throw either.
    test('printRecipeHtml() completes for a recipe with special chars in title',
        () async {
      final recipe = RecipeFactory.build(
        title: 'Pasta & "Tomat" <Grädde>',
      );

      await expectLater(printRecipeHtml(recipe), completes);
    });
  });
}
