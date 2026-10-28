/// The title of a pasted page, and what the dedup may merge (BUT-2455): page
/// furniture above the recipe ("Hoppa till recept", a breadcrumb, an issue
/// number) must not become the title, and one ingredient whose name sits
/// inside another's ("mjölk" in "kokosmjölk") must not be dropped.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('HeadingWordLists.isPageFurniture', () {
    test('page lines around a recipe', () {
      for (final line in [
        'Hoppa till recept',
        'Skriv ut',
        'Spara recept',
        'Dela',
        'Annons',
        'Följ',
        'Dela   Spara   Skriv ut',
        'Dela på Facebook',
        'Startsida > Recept > Vegetariskt',
        '4,5 av 5 (23 röster)',
        '★★★★☆ (8)',
        '(23 röster)',
        'Publicerad 2023-11-02 · Uppdaterad 2024-01-15',
        'Nummer 4 2024',
        'Vi använder cookies för att ge dig en bättre upplevelse.',
      ]) {
        expect(HeadingWordLists.isPageFurniture(line), isTrue, reason: line);
        expect(RecipeSectionDetector.isGarbage(line), isTrue, reason: line);
      }
    });

    test('recipe lines that open with the same words', () {
      for (final line in [
        'Dela degen i 12 bitar',
        'Följ anvisningen på paketet',
        'Spara lite av pastavattnet',
        'Skriv ut-vänlig version finns inte',
        'Annonsera inte för gästerna att det är vegetariskt',
        '1,5 dl mjölk',
        'Värm ugnen till 200 grader > låt stå',
        'Laxpasta med citron',
        'Vi använder kakor till botten',
      ]) {
        expect(HeadingWordLists.isPageFurniture(line), isFalse, reason: line);
      }
    });
  });

  group('RecipeSectionDetector page text', () {
    test('a rating is not a comma-separated ingredient list', () {
      expect(RecipeSectionDetector.looksLikeIngredient('4,5 av 5'), isFalse);
    });

    test('a yield label is page text', () {
      for (final line in ['4 port', '4 port.', '6 portioner']) {
        expect(RecipeSectionDetector.isGarbage(line), isTrue, reason: line);
      }
      expect(RecipeSectionDetector.isGarbage('2 portvin'), isFalse);
    });
  });

  group('TextImportStrategy title and dedup', () {
    late TextImportStrategy strategy;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      strategy = TextImportStrategy();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<Recipe> parse(String text) async {
      final result = await strategy.import(text);
      expect(result.isSuccess, isTrue, reason: result.errorMessage);
      return result.recipe!;
    }

    // Exact row match, so "mjölk" is not found inside "kokosmjölk".
    bool hasRow(Recipe r, String row) =>
        r.ingredients.any((i) => i.toLowerCase().trim() == row);

    const body = '''
Ingredienser
400 g pasta
2 dl grädde
Gör så här
Koka pastan enligt anvisningen på paketet.
Rör ner grädden och låt det bli varmt.''';

    for (final (name, furniture) in [
      ('a skip link and buttons', 'Hoppa till recept\nDela   Spara   Skriv ut'),
      (
        'a breadcrumb and a date',
        'Startsida > Recept > Pasta\nPublicerad 2024-01-15',
      ),
      ('a magazine section and issue', 'MAT & DRYCK\nNummer 4 2024'),
      ('an account name and a follow button', 'mat_med_mia\nFölj'),
      ('a rating', '4,5 av 5 (23 röster)'),
    ]) {
      test('the title skips $name', () async {
        final recipe = await parse('$furniture\nKrämig pasta\n$body');
        expect(recipe.title, 'Krämig pasta');
      });
    }

    test('a title holding an ingredient word is still the title', () async {
      final recipe = await parse('''
MAT & DRYCK
Laxpasta med citron
400 g pasta
300 g laxfilé
Koka pastan enligt anvisningen på paketet.''');

      expect(recipe.title, 'Laxpasta med citron');
    });

    test('a shared-compound hyphen does not cut the title', () async {
      final recipe = await parse('Potatis- och purjolökssoppa\n$body');
      expect(recipe.title, 'Potatis- och purjolökssoppa');
    });

    test('a title dash still cuts off a tagline', () async {
      final recipe = await parse('Krämig pasta - snabb vardagsmiddag\n$body');
      expect(recipe.title, 'Krämig pasta');
    });

    test('a group heading under furniture still groups its rows', () async {
      final recipe = await parse('''
SOPPOR
Deg:
3 dl vetemjöl
1 dl mjölk
Blanda allt till en deg och låt den vila.''');

      // BUT-1754: "Deg" may be the title when nothing else qualifies, but it
      // still groups its rows.
      expect(recipe.title, 'Deg');
      expect(
        recipe.structuredIngredients
            .firstWhere((i) => i.name.contains('vetemjöl'))
            .section,
        'Deg',
      );
    });

    test('a compound name does not swallow the simple one', () async {
      final recipe = await parse('''
Gryta
Ingredienser
1 dl mjölk
1 burk kokosmjölk
50 g smör
2 msk jordnötssmör
200 g pasta
1 dl röd currypasta
Gör så här
Koka allt i en gryta i tjugo minuter under omrörning.''');

      for (final row in [
        '1 dl mjölk',
        '1 burk kokosmjölk',
        '50 g smör',
        '2 msk jordnötssmör',
        '200 g pasta',
      ]) {
        expect(hasRow(recipe, row), isTrue, reason: row);
      }
    });

    test('a headerless caption keeps bare rows after a quantity row', () async {
      final recipe = await parse('''
Krämig pasta
400 g pasta
2 dl grädde
salt
peppar
Koka pastan enligt anvisningen på paketet och rör ner grädden.''');

      expect(hasRow(recipe, 'salt'), isTrue);
      expect(hasRow(recipe, 'peppar'), isTrue);
    });

    test('a line no rule claims ends the ingredient list', () async {
      final recipe = await parse('''
Pastasallad
En enkel sallad till lunchlådan och picknicken.
200 g pasta
Den blir godare dagen efter om den får stå.
riktigt gott
Koka pastan enligt anvisningen på paketet och låt den svalna.''');

      expect(hasRow(recipe, '200 g pasta'), isTrue);
      expect(hasRow(recipe, 'riktigt gott'), isFalse);
    });

    test('a short word opening a block keeps the bare rows under it', () async {
      final recipe = await parse('''
Omelett
400 g pasta

Ostsås
dill
Koka pastan enligt anvisningen på paketet och rör ner smöret.''');

      expect(hasRow(recipe, 'dill'), isTrue);
    });

    test('a rating and a yield are not ingredients', () async {
      final recipe = await parse('''
Pannkakor
4,5 av 5 (23 röster)
4 port
1,5 dl mjölk
2 ägg
Vispa ihop allt och stek tunna pannkakor i smör.''');

      expect(hasRow(recipe, '1,5 dl mjölk'), isTrue);
      expect(
        recipe.ingredients.where(
          (i) => i.contains('av 5') || i.contains('röster') || i == '4 port',
        ),
        isEmpty,
      );
    });

    test('a labelled time is not a step', () async {
      final recipe = await parse('''
Laxpasta
Tid: 25 min
Förberedelse: ca 10 min
400 g pasta
300 g laxfilé
Koka pastan enligt anvisningen på förpackningen.
Stek laxen i en het panna ca 3 minuter.''');

      expect(
        recipe.instructions.where(
          (s) => s.startsWith('Tid') || s.startsWith('Förberedelse'),
        ),
        isEmpty,
      );
      expect(recipe.instructions, hasLength(2));
    });

    test('a name cut at é is still one ingredient', () async {
      final recipe = await parse('''
Ugnslax
Ingredienser
400 g laxfilé
2 dl crème fraiche
Gör så här
Lägg laxen i en form och baka den i ugnen i tjugo minuter.''');

      expect(
        recipe.ingredients.where((i) => i.toLowerCase().contains('laxfil')),
        hasLength(1),
      );
      expect(
        recipe.ingredients.where((i) => i.toLowerCase().contains('cr')),
        hasLength(1),
      );
    });
  });
}
