import 'package:butlery/services/import/recipe_title_picker.dart';
import 'package:flutter_test/flutter_test.dart';

// Intent: a photographed page names its recipe by the heading above the first
// ingredient, not by whatever line the camera caught first. Lines are from the
// stored corpus pages.
String? photo(List<String> lines) =>
    RecipeTitlePicker.pick(lines, photoPage: true);

void main() {
  test('the foot of the previous recipe above the title is skipped', () {
    expect(
      photo([
        'att avocadon inte mörknat). Krydda med tsk salt',
        'dl gräddfil eller naturell yoghutt och rör såsen slät.',
        'Kryddgårdssås',
        'Det här är kanske ingen vardagssås eftersom den är så pass fet.',
        'För 4 kan man ta:',
        '2 dl gräddfil',
      ]),
      'Kryddgårdssås',
    );
  });

  test('a title set on two lines reads as one', () {
    expect(
      photo([
        'Lämpliga tillbehör: Stekta ägg, saltgurka',
        'Nordtysk',
        'lapskojs',
        'Till 4 portioner behövs:',
        '1 kg potatis • 750 g fast fiskfilé',
      ]),
      'Nordtysk lapskojs',
    );
  });

  test('the heading under a page header is the title', () {
    expect(
      photo([
        'Potatis på flera sätt',
        'Buljongpotatis',
        'Till 4 portioner behövs:',
        '1 1/2 l vatten • 500 g oxbringa',
      ]),
      'Buljongpotatis',
    );
  });

  test('a part of the recipe does not beat the title above the intro', () {
    expect(
      photo([
        'Veganvänlig rödvinbärspaj',
        'I den här pajen har jag bytt ut smöret mot rapsolja för att blidka en vän.',
        'Smuldeg',
        '3 dl vetemjöl',
        '2 krm salt',
      ]),
      'Veganvänlig rödvinbärspaj',
    );
  });

  test(
    'a page that opens on its ingredients is named by the method heading',
    () {
      expect(
        photo([
          '4 PORTIONER',
          '1 gul lök',
          '1 vitlöksklyfta',
          'Puré och stomp',
          'Pumpapuré med chili',
          'Pumpapurén blir härligt sötsyrlig. Utmärkt till viltkött.',
          'Halvera och kärna ur pumpan.',
        ]),
        'Pumpapuré med chili',
      );
    },
  );

  test('pasted text keeps its first line as the title', () {
    expect(
      RecipeTitlePicker.pick([
        'Kaka',
        'Smör',
        '2 dl mjölk',
        'Gör så här',
      ], photoPage: false),
      isNull,
    );
  });

  test('a page with no heading above its ingredients gives no title', () {
    expect(
      photo(['löken i lite smör,', '2 dl mjölk', 'Blanda och grädda.']),
      isNull,
    );
  });
}
