# Receptkortet efter skissen (2026-10-11)

Malin valde "Som skissen" (beslutskort i tråden "Receptkort: skiss mot app"): kortet och
listraden byggs om efter Komponentark v1 "Receptkort · receptlistrad" och Skärmar v12
#hemrecept. Router: tier single (Creative Director); skissen är redan Malins godkända ritning.

## Mål

- **Rutnätskort:** papper med kant (`StyledCard.decorationOf`, Malins val 2026-10-11), foto <!-- claim-lint:ok designmått ur skissen, inget antal i repot -->
  16:9 kant i kant överst, titel `titleMedium` högst två rader, metarad "45 min · 4 port." <!-- claim-lint:ok designmått ur skissen -->
  Utan foto utgår bildytan; en 36 dp initialplatta står ovanför titeln.
- **Listrad (detailed):** ingen kortyta. Rad minst 64 dp, 48 dp miniatyr (36 dp platta utan
  foto), titel, metarad, radchevron (`ButleryChevron`), hårlinje under.
- **Metaraden** bär ett betyg som "★ 4,5" i text.accent (saffranshierarkin punkt 4), inte en
  bricka. Ett tal: hushållets, annars det egna, annars Butlery-betyget över golvet, annars alla.
- **Bort från kortet:** grön vänsterkant, saffransfärgad underkant, hjärta, lås/glob, beskrivning,
  "% komplett", "Ej taggat", taggar och personliga taggar. Favorit sätts i receptvyn och
  filtreras med "Favoriter".
- **Kvar av säkerhetsskäl:** allergenvarningarna och "Allergener ej bedömda" när användaren
  slagit på "Visa på receptkort" (skissen Familj: "Visas som varningar på receptkort").
- Tester för det som tas bort från kortet tas bort tillsammans med funktionen.
- Skafferimatchningen (filtret "Laga med vad jag har") blir text i metaraden.
- Valt läge: `surface.selected` med 1,5 px kant, som förut.

## Filer

`lib/widgets/recipe/recipe_card.dart`, `lib/views/mina_recept/recipe_card_widget.dart`,
`lib/widgets/common/content_card.dart`, `lib/views/mina_recept_view.dart` (listläget utan
mellanrum mellan rader), tester under `test/widget/recipe/`, `test/views/`, goldens.

## Verifiering

- `flutter analyze` på ändrade filer, receptkortets testsviter och Mina recept-sviterna gröna.
- Goldens (`recipe_card_*`, `mina_recept*`, `hem`) omgjorda på Linux och granskade mot skissen.
- Skärmbilder före/efter till Malin.

## Sammanfattning för Malin

Receptkorten ritas om så att de ser ut som i originalskissen: lugnt papperskort med bild,
titel och tid, och i listan enkla rader med en tunn linje emellan. Hjärtat, låset och de
extra brickorna försvinner från korten. Allergenvarningarna blir kvar om du har valt att
visa dem på korten, eftersom de skyddar mot fel mat.
