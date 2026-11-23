import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/import/prose_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Rows from the potato cookbook page where each recipe is a heading plus
  // running text, with no ingredient list and no yield line.
  const proseRecipes = '''
Stekt potatis passar bra till sylta, stekt eller grillat kött och till stekta ägg.
Rissolée-potatis
Koka 750 g små potatisar med skal, skala
dem sedan. Hetta upp 50 g smör i en stor
stekpanna, lägg i potatisen, salta försiktigt.
Stek potatisen i ca 10 minuter, skaka om den
i pannan kraftigt då och då.
Passar bra till: Späda grönsaker och grillat kött
Potatis Maitre 'Hôtel
Koka 750 g jämnstor potatis med skal, skala sedan och skär dem i måttligt tjocka skivor.
Lägg skivorna i en värmd skål. Smält 50 g smör i en liten panna och fräs en finhackad schalottenlök guldgul. Rör i 2 msk hackad persilja och 1-2 tsk citronsaft.
Passar bra till: Ugnsstekt skinka, kasseler
Potatis à la Pückler
Skär 750 g kokt skalpotatis i skivor. Smält 3 msk smör i en panna och fräs 1 finhackad lök glasig, tillsätt potatisen och strö över 2 msk hackad persilja. Stek potatisen i ca 10 minuter, vänd den ofta.
Passar bra till: Kokt eller stekt fisk''';

  group('a heading with an ingredient word opens a recipe by its method', () {
    test('three short prose recipes become three blocks', () {
      final blocks = MultiRecipeSplitter().split(proseRecipes);
      expect(blocks, hasLength(3));
      expect(blocks[0], startsWith('Rissolée-potatis'));
      expect(blocks[1], startsWith("Potatis Maitre 'Hôtel"));
      expect(blocks[2], startsWith('Potatis à la Pückler'));
    });

    test('a bare ingredient line above an ingredient list is not a title', () {
      final lines = ['Potatis', 'Smör', '2 msk olja', '500 g potatis'];
      expect(ProseLayout.opensRecipe(lines, 0), isFalse);
    });

    test('a heading without quantities in its method does not open', () {
      final lines = [
        'Rissolée-potatis',
        'Koka potatisen mjuk och skala den.',
        'Stek den i smör.',
      ];
      expect(ProseLayout.opensRecipe(lines, 0), isFalse);
    });

    test('the start of a long sentence is not a heading', () {
      final lines = [
        'Som tillbehör kan man laga till potatis i',
        'Koka 750 g potatis och skala den. Smält 50 g smör i en panna.',
      ];
      expect(ProseLayout.opensRecipe(lines, 0), isFalse);
    });
  });

  group('the foot of a recipe never opens the next one', () {
    test('"Passar bra till:" and "Lämpliga tillbehör:" are tail labels', () {
      expect(ProseLayout.isTailLabel('Passar bra till: Kokt fisk'), isTrue);
      expect(ProseLayout.isTailLabel('Lämpliga tillbehör: Sallad'), isTrue);
      expect(ProseLayout.isTailLabel('Mitt tips Koka potatisen'), isTrue);
      expect(ProseLayout.isTailLabel('Variant: Fin potatisring'), isFalse);
    });
  });

  test('a tip line without a colon does not open a recipe of its own', () {
    const page = '''
Rissolée-potatis
Koka 750 g små potatisar med skal, skala
dem sedan. Hetta upp 50 g smör i en stor
stekpanna, lägg i potatisen, salta försiktigt.
Mitt tips
Koka 2 kg potatis med skal. Lägg 3 msk salt i vattnet.
Potatis Maitre 'Hôtel
Koka 750 g jämnstor potatis med skal, skala sedan och skär dem i skivor.
Lägg skivorna i en skål. Smält 50 g smör i en panna och rör i 2 msk persilja.''';
    final blocks = MultiRecipeSplitter().split(page);
    expect(blocks, hasLength(2));
    expect(blocks[0], contains('Mitt tips'));
  });

  group('a recipe whose method sits elsewhere is kept', () {
    test('two yield-line recipes with ingredients but one method', () {
      const page = '''
Fransk potatissoppa
Till 4 portioner behövs:
500 g potatis • 2 vitlöksklyftor
1 l köttbuljong • 150 g djupfryst ärtor
Ca 690 kJ/165 kcal per portion
Italiensk potatissoppa
Till 4 portioner behövs:
3 purjolökar • 500 g potatis • 75 g smör
1 l köttbuljong • 3 msk grädde
Ca 1575 kJ/375 kcal per portion
Gör så här: Skala och skär potatisen i små tärningar. • Koka upp
köttbuljongen i en gryta och lägg i potatisen. • Låt koka i 10 minuter.''';
      expect(MultiRecipeSplitter().split(page), hasLength(2));
    });
  });

  group('a recipe whose title is on the previous page', () {
    test('the foot above the first title becomes its own block', () {
      const page = '''
Skala och skär potatisen i tunna skivor. Torka av den med 2 msk mjöl.
Värm ugnen till 225°. Lägg potatisen i en form och häll över 3 dl grädde.
Ställ formen i ugnen och grädda i 40 minuter.
Servera genast med smör.
Rissolée-potatis
Koka 750 g små potatisar med skal, skala
dem sedan. Hetta upp 50 g smör i en stor
stekpanna, lägg i potatisen, salta försiktigt.
Potatis Maitre 'Hôtel
Koka 750 g jämnstor potatis med skal, skala sedan och skär dem i skivor.
Lägg skivorna i en skål. Smält 50 g smör i en panna och rör i 2 msk persilja.''';
      expect(MultiRecipeSplitter().split(page), hasLength(3));
    });

    test('a page of furniture above the first title adds no block', () {
      const page = '''
Fina soppor och mustiga
33
Rissolée-potatis
Koka 750 g små potatisar med skal, skala
dem sedan. Hetta upp 50 g smör i en stor
stekpanna, lägg i potatisen, salta försiktigt.
Potatis Maitre 'Hôtel
Koka 750 g jämnstor potatis med skal, skala sedan och skär dem i skivor.
Lägg skivorna i en skål. Smält 50 g smör i en panna och rör i 2 msk persilja.''';
      expect(MultiRecipeSplitter().split(page), hasLength(2));
    });
  });
}
