import 'package:butlery/services/import/layout/line_reflow.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/import/yield_layout.dart';
import 'package:flutter_test/flutter_test.dart';

// OCR text of three cookbook pages that print two recipes each, a bare piece
// count ("4 stycken") as the yield and a blurb between yield and ingredients.
const _pageGrapes = '''
Inga-Lisas
druvsmörgås
4 stycken
Inte alls så konstigt som det kan-
ske låter. Kommer man bara över
den första häpenheten finner man
att en sådan här smörgås kan bli
en riktigt raffinerad avslutning på
en middag. Ost och frukt i ett, så
att säga.
20-25 vindruvor, gröna eller blå
4 skivor ost, t ex Emmentaler
paprikapulver
4 vita skivor vitt bröd, kantskurna
smor
Gör så här:
Rosta brödet lätt och bred på smör.
Dofta över paprika. Halvera och
kärna ur druvorna och lägg dem i
rader på brödet. Täck med ostski-
vorna och gratinera i 225-250°
6-8 minuter eller tills osten smält.
50
Mångfärgad smörgås
4 stycken
En festlig och vacker smörgås som
trots det inte är förkrossande dyr.
Passar både ensam och som förrätt.
3-4 tomater
salt och vitpeppar
klippt gräslök
1 burk svart kaviar à 60 g
1 pocherade ägg (recept på
sidan 87)
1 paket fryst hollandaise à 200 g
4 skivor vitt bröd, kantskurna
smör
Gör så här:
1. Rosta brödet lätt och bred på li-
te smör. Skiva tomaterna och
lägg skivorna på brödet. Salta
och peppra, strö över gräslök
och lägg på kaviaren.
2. Tina hollandaisen. Pochera äg-
gen (recept på sidan 87) och
lägg ett ägg på varje smörgås.
Bred över hollandaise och grati-
nera i 225-250° 6-8 minuter.
4B D000Ck88
1
2''';

const _pageHerring = '''
de
七
a
≤-
na
da
Henriks sillsmörgås
4 stycken
En salt liten bit, öl och kanske en
snaps är det traditionella mönstret
för vickning. Den här sillsmörgå-
sen passar utmärkt och kan förbe-
redas till en del, även om den får
sin finish precis före serveringen.
1-2 burkar sill i dill à 100 g
1 liten purjolök
1 dl lättmajonnäs
1 stort ägg
4 skivor vitt bröd
smör
Gör sả här:
1. Låt sillen rinna av väl och lägg
den i en plastburk tills vidare.
Strimla purjolöken och lägg
också den i en burk.
2. Rosta sedan brödet och bred på
lite smör. Lägg ett lager purjo
på varje smörgås och fördela
sillbitarna över. Skilj äggula
och vita och rör ner gulan i ma-
jonnäsen. Vispa vitan till hårt
skum och vänd ner den. Bred
smeten över smörgåsarna och
gratinera i 225-250° ugn 6-8
minuter.
Fredriks
böcklingsmörgås
4 stycken
En blandning allt-i-ett. Smörgåsen
gratineras med riven ost och utan
speciell gratängsmet. Den kan för-
beredas fram till sista momentet.
4-6 böcklingar
2 hårdkokta ägg
2 msk vispgrädde
salt och paprikapulver
1-2 tomater i skivor
1-1½ dl grovrwven ost
4 skivor vitt bröd
smör (kan uteslutas)
Gör så här:
1. Rensa böcklingen och hacka
den. Hacka äggen. Blanda böck-
ling och ägg och bind med gräd-
den. Smaka av med salt och
paprika. Lägg blandningen i en
plastburk fram till serveringen.
2. Rosta brödet lätt och bred ev på
lite smör. Fördela böcklingrö-
ran på brödskivorna, lägg på en
tomatskiva och strö på ost. Gra-
tinera i 225-250° 6-8 minuter.''';

const _pageChanterelle = '''
örgås
srätt är
också bli
en "öp-
smet.
mjuk-
en lite
och
sgrill,
c ste-
erar
r -
1 72.
Skaldjurssmörgås
à la Maj
4 stycken
Bild sidan 39
Både vacker och god. Skaldjursin-
slaget kan vara burkhummer (ty-
vårr så dyr numera), upprensad
fryst hummer eller burkkrabba.
Svart kaviar fyller ut och ger fin
färgkontrast. Gratängsmeten är
helt enkelt majonnäs med äggula
och vispad vita.
1 djupfryst hummer eller 1 burk
krabba à 170 g
1 burk svart kaviar à 100 g
2 hårdkokta ägg
1 dl lättmajonnäs
1 stort ägg
4 skivor vitt bröd, kantskurna
Gör så här:
1. Ta ur köttet ur den tinade hum-
mern och dela det i bitar. Eller
känn igenom krabbköttet så att
inget brosk finns med. Dela de
hårdkokta äggen i tunna klyf-
tor på längden.
2. Rosta brödet lätt. Bred på ett la-
ger kaviar, lägg på äggklyftor
och hummer eller krabba.
3. Skilj äggula och vita. Rör ner
äggulan i majonnäsen, vispa vi-
tan hårt och vänd försiktigt ner
den. Fördela smeten på smörgå-
sarna och gratinera i 225-250°
6-8 minuter eller tills gra-
tängsmeten fått fin färg.
Majs
kantarellsmörgås
4 stycken
Bild sidan 39
Den som har bra kantarellställen
passar förstås på när det är säsong.
Andra tider på året får det bli
burkkantareller. Smörgåsen grati-
neras inte, utan den brynta svamp-
röran läggs på nystekt bröd.
2 burkar kantareller à 200 g
1 medelstor gul lök
smör
1 liten röd paprika
salt och vitpeppar
4 skivor vitt bröd
smör
Gör så här:
1. Dela lök och paprika mitt itu,
skär löken i tunna skivor och
paprikan i strimlor. Låt svam-
pen rinna av och dela ev större
svampar i bitar.
2. Fräs lök och svamp i smör tills
det är lätt brynt. Låt paprikan
fräsa med några minuter. Salta
och peppra.
3. Stek brödskivorna guldbruna
och frasiga i smör. Lägg kanta-
rellfräset på smörgåsarna och
servera genast.
43''';

List<String> _blocksOf(String page) =>
    MultiRecipeSplitter().split(reflowWrappedLines(page));

void main() {
  group('pages with two recipes and a "N stycken" yield', () {
    test(
      'the blurb between yield and ingredients does not hide the recipe',
      () {
        final blocks = _blocksOf(_pageGrapes);
        expect(blocks, hasLength(2));
        expect(blocks[0], startsWith('Inga-Lisas'));
        expect(blocks[1], startsWith('Mångfärgad smörgås'));
      },
    );

    test('a two-line title right after a numbered method opens its recipe', () {
      final blocks = _blocksOf(_pageHerring);
      expect(blocks, hasLength(2));
      expect(blocks[0], startsWith('Henriks sillsmörgås'));
      expect(blocks[1], startsWith('Fredriks'));
      expect(blocks[1], contains('böcklingsmörgås'));
      expect(blocks[0], isNot(contains('Fredriks')));
    });

    test(
      'a long blurb and a cut-off neighbour page still give two recipes',
      () {
        final blocks = _blocksOf(_pageChanterelle);
        expect(blocks, hasLength(2));
        expect(blocks[0], startsWith('Skaldjurssmörgås'));
        expect(blocks[1], startsWith('Majs'));
      },
    );
  });

  test('a yield under a title reaches past a long blurb to the rows', () {
    final blurb = [
      for (var i = 0; i < 10; i++) 'En lång ingress som fortsätter här och nu',
    ].join('\n');
    final page =
        'Första smörgåsen\n4 stycken\n$blurb\n'
        '2 dl mjölk\n1 msk smör\nGör så här:\n1. Rosta brödet lätt.\n'
        'Andra smörgåsen\n4 stycken\n$blurb\n'
        '3 dl grädde\n2 msk smör\nGör så här:\n1. Rosta brödet lätt.';
    final blocks = MultiRecipeSplitter().split(page);
    expect(blocks, hasLength(2));
    expect(blocks[1], startsWith('Andra smörgåsen'));
  });

  group('YieldLayout.isYieldLine with a piece count', () {
    test('reads a line that is only a piece count', () {
      expect(YieldLayout.isYieldLine('4 stycken'), isTrue);
      expect(YieldLayout.isYieldLine('2-3 st'), isTrue);
    });

    test('never reads an ingredient row', () {
      expect(YieldLayout.isYieldLine('4 st ägg'), isFalse);
      expect(YieldLayout.isYieldLine('2 stycken morötter'), isFalse);
    });
  });
}
