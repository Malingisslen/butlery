import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/import/yield_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oneRecipe = '''
Roquefort-
potatis
Till 4 portioner behövs:
800 g små färska potatisar • 100 g bacon i
tunna skivor • 60 g roquefortost
Ca 2310 kJ/550 kcal per portion
Gör så här: Koka potatisen med skal. • Stek
baconet knaprigt i het panna utan fett.''';

  test(
    'a title made of an ingredient word opens a recipe via its yield line',
    () {
      const page =
          '$oneRecipe\n'
          'Locarnopotatis\n'
          'Till 4 portioner behövs:\n'
          '1 kg färsk potatis • 2 lökar\n'
          '250 g rökt skinka • 4 msk smör\n'
          'Ca 2455 kJ/585 kcal per portion\n'
          'Gör så här: Borsta potatisen väl och skär den i skivor. • Hetta upp\n'
          'smöret i en stor panna och bryn potatisen väl.';
      final blocks = MultiRecipeSplitter().split(page);
      expect(blocks, hasLength(2));
      expect(blocks[1], startsWith('Locarnopotatis'));
    },
  );

  test('a title far above its yield line still opens a recipe', () {
    const page =
        '$oneRecipe\n'
        'Kejsarens\n'
        'potatissoppa\n'
        'Här är receptet till den siste tyske kejsarens\n'
        'livrätt: Man tager skalad potatis, kokar den\n'
        'halvfärdig i saltvatten och sedan mjuk.\n'
        'Fullända anrättningen med smör och grädde.\n'
        'Här är min mer borgerliga variant.\n'
        'Till 4 portioner behövs:\n'
        '2 stora morötter • 750 g potatis\n'
        '3 msk smör • 1 l buljong\n'
        'Ca 2770 kJ\n'
        'Gör så här: Ansa, skölj och skär rotsakerna i\n'
        'tärningar. • Smält smöret i en gryta och fräs.';
    expect(MultiRecipeSplitter().split(page), hasLength(2));
  });

  test('ingredient lists printed before both methods are paired up', () {
    const page = '''
Krämig potatissoppa
Till 4 portioner behövs:
500 g potatis • 2 lökar
1 l buljong • 2 msk smör
Ca 1100 kJ
Crème Vichyssoise
Till 4 portioner behövs:
3 purjolökar • 500 g potatis
75 g smör • 1 l buljong
Ca 1450 kJ
Gör så här: Skala och skär potatisen. • Koka upp
buljongen och lägg i potatisen.
Gör så här: Ansa purjolökarna och skär dem i ringar.
• Hetta upp smöret i en gryta och fräs purjon.''';
    final blocks = MultiRecipeSplitter().split(page);
    expect(blocks, hasLength(2));
    expect(blocks[0], contains('500 g potatis'));
    expect(blocks[0], contains('Koka upp'));
    expect(blocks[0], isNot(contains('purjon')));
    expect(blocks[1], contains('75 g smör'));
    expect(blocks[1], contains('fräs purjon'));
  });

  test('one recipe with a sub-heading and a single yield line stays whole', () {
    const page = '''
Köttfärssås
Till 4 portioner behövs:
500 g köttfärs • 2 lökar
1 burk krossade tomater
Till servering
2 dl pasta • 1 msk olja
Gör så här: Stek färsen och löken. • Tillsätt tomaterna
och låt koka i 20 minuter.''';
    expect(MultiRecipeSplitter().split(page), hasLength(1));
  });

  test('distributeMethods leaves a run alone when methods are too few', () {
    final blocks = ['A\n2 dl mjöl', 'B\n3 dl mjöl\nGör så här: Rör ihop.'];
    expect(YieldLayout.distributeMethods(blocks), blocks);
  });
}
