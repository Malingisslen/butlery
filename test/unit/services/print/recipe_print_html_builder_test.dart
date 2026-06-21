/// BUT-1347 (ENG-26): recipe print HTML builder — real structure tests.
///
/// After extracting `buildRecipePrintHtml` / `escapeHtml` into a
/// platform-agnostic module (no `package:web` / `dart:js_interop`), the actual
/// print markup is importable on the VM. These tests assert the generated HTML
/// contract directly, complementing the non-web no-op stub safety tests in
/// `test/unit/services/recipe_print_service_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/print/recipe_print_html_builder.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('buildRecipePrintHtml — structure (BUT-1347 ENG-26)', () {
    // Intent: proves the recipe title is rendered inside the <h1> heading
    // exactly as stored (production does NOT lowercase it).
    test('renders the recipe title in an <h1>', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(title: 'Köttbullar'),
      );

      expect(html, contains('<h1>Köttbullar</h1>'));
    });

    // Intent: proves every ingredient is rendered as an <li> inside the <ul>
    // ingredients block, in the order supplied.
    test('renders ingredients as <li> items inside <ul>', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          ingredients: ['500 g nötfärs', '1 lök', '1 ägg'],
        ),
      );

      expect(html, contains('<ul>'));
      expect(html, contains('<li>500 g nötfärs</li>'));
      expect(html, contains('<li>1 lök</li>'));
      expect(html, contains('<li>1 ägg</li>'));

      // Order preserved within the ingredient list.
      final firstIdx = html.indexOf('<li>500 g nötfärs</li>');
      final lastIdx = html.indexOf('<li>1 ägg</li>');
      expect(firstIdx, lessThan(lastIdx));
    });

    // Intent: proves instructions render in the supplied order inside the <ol>.
    test('renders instructions in order inside <ol>', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          instructions: ['Blanda färsen.', 'Forma bullar.', 'Stek i smör.'],
        ),
      );

      final olStart = html.indexOf('<ol>');
      expect(olStart, greaterThanOrEqualTo(0));

      final step1 = html.indexOf('<li>Blanda färsen.</li>');
      final step2 = html.indexOf('<li>Forma bullar.</li>');
      final step3 = html.indexOf('<li>Stek i smör.</li>');

      expect(step1, greaterThan(olStart));
      expect(step1, lessThan(step2));
      expect(step2, lessThan(step3));
    });

    // Intent: proves portions and cook time appear in the meta line when set.
    test('renders portions and time in the meta line when present', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(portions: 4, timeMinutes: 30),
      );

      expect(html, contains('<p class="meta">4 portioner · 30 min</p>'));
    });

    // Intent: proves the source URL line renders only when a sourceUrl is set.
    test('renders the source line when sourceUrl is present', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(sourceUrl: 'https://example.com/recept'),
      );

      expect(
        html,
        contains('<p class="source">Källa: https://example.com/recept</p>'),
      );
    });
  });

  group('buildRecipePrintHtml — XSS escaping (BUT-1347 ENG-26)', () {
    // Intent: proves HTML-special characters in the title are escaped so a
    // malicious title cannot inject raw markup into the print document.
    test('escapes & < > " in the title — no raw <script> survives', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          title: 'Pasta <script>alert("x")</script> & "co"',
        ),
      );

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&amp;'));
      expect(html, contains('&quot;'));
    });

    // Intent: proves the source URL is escaped too (it is user-controllable on
    // imported recipes).
    test('escapes special characters in the source URL', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          sourceUrl: 'https://e.com/?a=1&b="<x>"',
        ),
      );

      expect(html, contains('&amp;'));
      expect(html, contains('&lt;x&gt;'));
      expect(html, isNot(contains('<x>')));
    });

    // Intent: proves escapeHtml replaces all four entities deterministically.
    test('escapeHtml escapes &, <, >, and "', () {
      expect(escapeHtml('a & b'), 'a &amp; b');
      expect(escapeHtml('<tag>'), '&lt;tag&gt;');
      expect(escapeHtml('say "hi"'), 'say &quot;hi&quot;');
      // & is escaped before < / > so no double-escaping of the entities.
      expect(escapeHtml('<&>'), '&lt;&amp;&gt;');
    });
  });

  group('buildRecipePrintHtml — graceful omission (BUT-1347 ENG-26)', () {
    // Intent: proves null optional fields (portions/time/sourceUrl) produce no
    // crash and the corresponding markup is simply omitted.
    test('omits meta line and source line when optional fields are null', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          portions: null,
          timeMinutes: null,
          sourceUrl: null,
        ),
      );

      expect(html, isNot(contains('class="meta"')));
      expect(html, isNot(contains('Källa:')));
      // The static Butlery footer always renders.
      expect(html, contains('Utskrivet från Butlery'));
    });

    // Intent: proves empty ingredient and instruction lists do not crash and
    // still emit empty <ul>/<ol> containers.
    test('handles empty ingredient and instruction lists', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(ingredients: [], instructions: []),
      );

      expect(html, contains('<ul></ul>'));
      expect(html, contains('<ol></ol>'));
    });

    // Intent: smoke test that a fully-populated recipe yields a complete,
    // well-formed HTML document.
    test('produces a complete HTML document for a full recipe', () {
      final html = buildRecipePrintHtml(
        RecipeFactory.build(
          title: 'Pannkakor',
          ingredients: ['3 dl mjöl', '6 dl mjölk', '3 ägg'],
          instructions: ['Vispa smeten.', 'Stek tunt.'],
          portions: 4,
          timeMinutes: 20,
          sourceUrl: 'https://example.com/pannkakor',
        ),
      );

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<html lang="sv">'));
      expect(html, contains('<h2>Ingredienser</h2>'));
      expect(html, contains('<h2>Instruktioner</h2>'));
      expect(html.trimRight(), endsWith('</html>'));
    });
  });
}
