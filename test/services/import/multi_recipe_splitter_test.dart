import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';

void main() {
  late MultiRecipeSplitter splitter;

  setUp(() => splitter = MultiRecipeSplitter());

  group('MultiRecipeSplitter', () {
    test('splits three recipes on one page into three blocks', () {
      const page = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.

Våfflor
Ingredienser:
4 dl vetemjöl
3 dl grädde
Gör så här:
Grädda i våffeljärn tills gyllene.

Plättar
Ingredienser:
2 dl vetemjöl
2 dl mjölk
Gör så här:
Stek små plättar i plättlagg.''';

      final blocks = splitter.split(page);
      expect(blocks, hasLength(3));
      expect(blocks[0], contains('Pannkakor'));
      expect(blocks[1], contains('Våfflor'));
      expect(blocks[2], contains('Plättar'));
      // Each block keeps its own ingredients.
      expect(blocks[1], contains('grädde'));
    });

    test('returns the input unchanged when only one recipe is present', () {
      const single = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop och stek.''';

      final blocks = splitter.split(single);
      expect(blocks, hasLength(1));
      expect(blocks.first, single);
    });

    test('does NOT split a single recipe that has sub-section headers', () {
      // "Gräddsås:" and "För såsen:" are sub-sections of ONE recipe — the
      // completeness gate must keep this as a single block (false-split guard).
      const withSubsections = '''
Köttbullar med gräddsås
Ingredienser:
500 g köttfärs
1 dl ströbröd
2 dl mjölk

Gräddsås:
2 msk smör
3 dl grädde

Gör så här:
Blanda köttfärs, ströbröd och mjölk.
Forma bollar och stek i smör.

För såsen:
Smält smör och vispa i mjöl.
Tillsätt grädde och koka upp.''';

      final blocks = splitter.split(withSubsections);
      expect(blocks, hasLength(1));
    });

    test('drops a trailing noise fragment that is not a recipe', () {
      const page = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop och stek.

Våfflor
Ingredienser:
4 dl vetemjöl
3 dl grädde
Gör så här:
Grädda i våffeljärn.

Läs mer om mjöl på sidan 42.''';

      final blocks = splitter.split(page);
      // Only the two real recipes — the page-reference line is not its own block.
      expect(blocks, hasLength(2));
      expect(blocks.every((b) => b.contains('Ingredienser')), isTrue);
    });

    test('returns single block for empty or sub-threshold input', () {
      expect(splitter.split(''), ['']);
      expect(splitter.split('Pannkakor\n3 dl mjöl'), ['Pannkakor\n3 dl mjöl']);
    });
  });
}
