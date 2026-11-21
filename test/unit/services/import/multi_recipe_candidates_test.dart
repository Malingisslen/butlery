/// Counting the recipes a page seems to hold, so the import can notice when
/// the phone returned fewer.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/missed_recipe_check.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';

const _first = '''
Citronkaka

Ingredienser
3 dl vetemjöl
2 dl socker
100 g smör

Gör så här
Sätt ugnen på 175 grader. Blanda mjöl och socker.
Grädda kakan i 35 minuter.
''';

const _second = '''
Havrekex

Ingredienser
2 dl havregryn
1 dl mjöl
50 g smör

Gör så här
Rör ihop smeten. Grädda kexen i 12 minuter.
''';

void main() {
  group('MultiRecipeSplitter.countCandidates', () {
    test('two recipes on a page count as two', () {
      expect(MultiRecipeSplitter.countCandidates('$_first\n$_second'), 2);
    });

    test('one recipe counts as one', () {
      expect(MultiRecipeSplitter.countCandidates(_first), 1);
    });

    test('empty text counts as none', () {
      expect(MultiRecipeSplitter.countCandidates(''), 0);
      expect(MultiRecipeSplitter.countCandidates('  \n \n'), 0);
    });

    test('sub-sections after the method do not open recipes', () {
      const text = '''
Kycklinggryta

Ingredienser
4 st kycklingfiléer
2 dl grädde
1 msk smör

Gör så här
Stek kycklingen i smör. Häll på grädden och koka i 10 minuter.

Sås
2 dl grädde
1 msk mjöl

Till servering
4 dl ris
2 st tomater

Garnering
1 dl persilja
2 msk riven ost
''';

      expect(MultiRecipeSplitter.countCandidates(text), 1);
    });

    test('a colon-terminated label does not open a recipe', () {
      const text = '''
Pannkakor

Ingredienser
3 dl mjöl
6 dl mjölk
3 st ägg

Gör så här
Vispa ihop smeten. Stek pannkakorna i smör.

För toppingen:
2 dl grädde
1 dl sylt
''';

      expect(MultiRecipeSplitter.countCandidates(text), 1);
    });

    test('an introduction above the ingredients is not the method', () {
      // Prose before the first ingredient introduces the dish; counting it as
      // the method made the next component heading look like a new recipe.
      const text = '''
Äppelpaj

Blanda gärna olika sorters äpplen i pajen.
4 portioner

Havretäcke
2 dl havregryn
1 dl mjöl
100 g smör

Äppelröra
4 st äpplen
1 msk socker
1 tsk kanel

Gör så här
Sätt ugnen på 200 grader. Grädda pajen i 30 minuter.
''';

      expect(MultiRecipeSplitter.countCandidates(text), 1);
    });

    test('a sentence ending in a full stop does not open a recipe', () {
      const text = '''
$_first
Passar bra till kaffet.
2 dl grädde
1 msk socker
''';

      expect(MultiRecipeSplitter.countCandidates(text), 1);
    });

    test('counts a page the splitter itself declines', () {
      // The second recipe has no instructions, so split() hands the page back
      // whole while the count still sees both titles.
      const text = '$_first\nHavrekex\n2 dl havregryn\n1 dl mjöl\n50 g smör\n';

      expect(MultiRecipeSplitter().split(text), [text]);
      expect(MultiRecipeSplitter.countCandidates(text), 2);
    });
  });

  group('missed recipe check', () {
    test('the larger signal wins and the two are never added', () {
      expect(candidateRecipeCount(textCandidates: 2, blocksTried: 1), 2);
      expect(candidateRecipeCount(textCandidates: 1, blocksTried: 3), 3);
      expect(candidateRecipeCount(textCandidates: 2, blocksTried: 2), 2);
    });

    test('asks only when candidates exceed the recipes found', () {
      expect(mayHaveMissedRecipes(candidates: 2, found: 1), isTrue);
      expect(mayHaveMissedRecipes(candidates: 1, found: 1), isFalse);
      expect(mayHaveMissedRecipes(candidates: 3, found: 0), isFalse);
    });
  });
}
