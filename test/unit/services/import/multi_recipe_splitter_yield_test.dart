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

  test('a heading over its yield line opens a recipe whose ingredient row OCR '
      'damaged', () {
    // Corpus page potatisratter/PXL_20260602_192920502, as photographed.
    const page =
        'Grön sås\n'
        'Till 4 portioner behövs:\n'
        '5 hårdkokta ägg • 1 1/4 dl olja • 1-2 tsk cit-\n'
        'ronsaft • 1/2 | gräddfil - ca 150 g färska\n'
        'kryddörter (gurkört, dill, körvel, libbsticka,\n'
        'persilja, pimpinella, ängssyra, gräslök, cit-\n'
        'ronmeliss) - 1 nypa socker • salt• vitpeppar\n'
        'Ca 2350 kJ/560 kcal per portion\n'
        '• Tillagningstid: 25 minuter\n'
        'Gör så här: Ta gulorna ur de hårdkokta äg-\n'
        'gen och mosa dem med en gaffel i en skäl.\n'
        'Rör i lite i taget av oljan, citronsaften och\n'
        'gräddfilen. • Skölj kryddörterna, skaka av\n'
        'vattnet väl och ta bort grova stjälkar. Fin-\n'
        'hacka örterna och rör ner dem i såsen.\n'
        'Smaka av såsen med socker, salt och peppar.\n'
        'Mitt tips Ta vara på den hård-\n'
        'kokta äggvitan och använd den till nå-\n'
        'got annat eller finhacka den och\n'
        'blanda den i såsen. Använd libbsticka\n'
        'sparsamt annars slår den lätt ihjäl\n'
        'smaken av de andra örterna.\n'
        'Kumminpotatis\n'
        'Till 4 portioner behövs:\n'
        '• 75 g smör\n'
        't kgsmu jarska poratsar • kummin: grovsal\n'
        'Till bakpläten: smör\n'
        'Ca 1530 k.J/365 kcal per portion\n'
        '• Tillagningstid: 50 minuter\n'
        'Gör sả hãr: Tvätta, torka och skär potati-\n'
        'sara mitt itu. • Värm ugnen till 200°.\n'
        'en bakplåt med smör. • Tryck potatisarnas\n'
        'snittyta i kummin och salt och ställ potati-\n'
        'sara med den kryddade sidan neråt på bak-\n'
        'plâten. Smält smöret och pensla potatisarnas\n'
        'ovansida. Baka i ugnen i 30-40 minuter.\n'
        'Lämpliga tillbehör: Kesosåser eller blandad\n'
        'sallad\n';
    final blocks = MultiRecipeSplitter().split(page);
    expect(blocks, hasLength(2));
    expect(blocks[1], startsWith('Kumminpotatis'));
  });
}
