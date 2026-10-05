# Plan — designmigreringen i mål

Skriven 2026-10-03 efter att PR #357 slagits ihop. Källor: `docs/design-migration/census.md`
(genererad samma dag), Linear (team Butlery) och designrepot `C:\Butlery design system`
(`NULAGE.md`, `blockerande.md`, `testmatris.md` § 4). Målet är det som Q8-01 = A sätter:
migreringen är klar när listorna över kända brister är tomma och restlistorna är tomma.

## Läget som planen utgår från (mätt 2026-10-03)

- Kända brister: 66 (a11y 12, kontrast 5, interaktionskontroller 12, interaktioner 6,
  övergångar 31). Varje brist har en biljett.
- Flödesövergångar: 50 av 81 testade; 17 byggda men onåbara, 9 halvfärdiga, 5 saknas.
- Interaktionstillstånd: 27 av 33 testade; 5 halvfärdiga, 1 saknas.
- Raderna ovan och nedan kommer från `dart run tools/design_migration_census.dart` (körd 2026-10-03).
- Vytillstånd: 53 av 53 klara i ljust och mörkt. Tokenparitet: 46 av 46.
- Restlistor: `icon_census_test _residue` 393 användningar av 178 ikoner;
  `_rawFontSizeAllowlist` 1.
- Designrepot: tre beslutscommits (B83-2a–2e, 1 okt) ligger opushade lokalt; `NULAGE.md`
  är daterad 2026-09-28 och säger 362 brister.
- `blockerande.md`: fem releaseblockerare saknade biljett → BUT-2222, 2223, 2224, 2225
  (filade i dag); § 4-protokollet på fysisk telefon är inte gjort.

De 12 a11y-posterna är godtagna av Malin (BUT-2196, avvikelsepost 2026-10-03) och ligger kvar
med avsikt. Census räknar dem som kända brister; "klar" betyder därför 12 kända brister, inte
0, om inte Malin väljer att flytta dem till en egen godtagen lista (beslut D5 nedan).

## Fas 0 — beslut som bara Malin kan ta

| # | Fråga | Alternativ | Rekommendation |
|---|---|---|---|
| D1 | BUT-2191: fem `dataScale`-kontrastpar har ingen genererad app-medlem. | A: ny generatorsort i designrepot (D1-kedjan) som levererar `dataScale.*`. B: stryk paren ur kontrastkontraktet tills en vy använder dem. | Mät först om någon vy i appen ritar en dataskala. Ingen → B. |
| D2 | SK-04: `isStaple` på skafferivaran går inte att sätta någonstans sedan PQ-11 = A. | A: ta bort fältet ur modellen (gamla dokument behåller nyckeln oläst). B: behåll vilande. | A. |
| D3 | Ordning för det som är byggt men dolt. | Se fas 3. | Offlinekön (BUT-2162) → veckoplanens rev-kontroll (BUT-2215) → tvåstegsverifiering (BUT-2142) → ändringsmodell (BUT-2140). |
| D4 | BUT-2193: matrisen undantar ALLA rullgardinsposter från ellipskontrollen vid 1.0, inte bara inköpslistans. | A: behåll. B: snäva till inköpslistans. | A. |
| D5 | De 12 godtagna kontrastposterna räknas som kända brister i census för alltid. | A: låt stå (census säger aldrig "klar"). B: egen lista `acceptedA11yFindings` som census räknar separat; "klar" = 0 kända + N godtagna. | B. |
| D6 | BUT-2141: valbart om egna varor behålls när veckans inköpslista ersätts. | A: bygg. B: stäng (PQ-10 = A behåller alltid). | B. |

**Beslutat 2026-10-04 (Malin: "kör som du rekommenderar"):** D1 = mät först, ingen vy → B; D2 = A (verkställs i fas 5 med egen plan, rör Firestore-modellen); D3 = ordningen ovan; D4 = A; D5 = B; D6 = B (BUT-2141 stängs). R7-4 utvidgad samma dag: matlagningskortets PulseDot går också på 1,2 s.

Beslut nedtecknas i designrepots `fas2/produktbeslut-<datum>.json` som tidigare.

## Fas 1 — kontrast- och tokenrester (mekaniskt, Q1 = A, ingen egen plan per del)

- BUT-2220: ~30 ställen med `cs.outline` som textfärg → `onSurfaceVariant`; `hintStyle` i <!-- claim-lint:ok an estimate copied from the ticket BUT-2220 -->
  `input_themes.dart` först (bredast). Matrisen fångar bara de vyer den kör, så varje fil
  probas med kontrastmätning i enhetstest.
- BUT-2207: `cs.primary` som text på raised i mörkt läge (1,19:1).
- BUT-2155, BUT-2149, BUT-2159: vald chip, saffran som text, `text.bodyMuted`.
- BUT-2147, BUT-2198, BUT-2165: tokens som saknas → D1-kedjan i designrepot, därefter
  vendra om `test/fixtures/design/*`.
- BUT-2205 (B83-1 rest), BUT-2211 (motion-tokens), BUT-2167, BUT-2146, BUT-2209, BUT-2208.
- BUT-2219 (HeroButton/squareButton-ellips), BUT-2218 (tre tryckytor), BUT-2216/2217
  (samarbetsmenyns laddning och döda väg).
- `_rawFontSizeAllowlist` 1 → 0 (`step_timer_widget.dart`, timerns textroll är BUT-2165).

Klart när: census `contrast 0` (efter D1), tokenparitet 46/46 behålls, restlista font 0.

## Fas 2 — interaktionstillstånd (12 kontroller, 6 tillstånd)

- BUT-2148 (hög): en fokusring på appnivå, saffransfyllningen tas bort. Löser radio/switch
  FOCUSED och är förutsättning för länkfokus.
- BUT-2177: länkar med 48 dp träffyta och fokusring (`link::DEFAULT`, `link::FOCUSED`).
- BUT-2176: kombinationsrutan annonserar EXPANDED.
- BUT-2178: sökfältets avstängda text 3:1 (efter fas 1:s hintStyle).

Klart när: 33 av 33 interaktionstillstånd TESTED, `interaction_checks 0`. <!-- claim-lint:ok a target, not a measurement -->

## Fas 3 — slå på det som är byggt men dolt (17 övergångar)

Varje punkt rör Firestore-regler, auth eller Cloud Functions och får en egen plan som Malin
godkänner. Ordning enligt D3.

1. BUT-2162 offlinekön (8 övergångar): koppla skrivningarna till synk- och
   uppladdningskön, köindikatorn i toppfältet, utloggningsspärren.
2. BUT-2215 veckoplanens versionskontroll → konfliktsnackbaren (1, BUT-2151-resten).
   BUT-2213 (recept) och BUT-2212 följer efter.
3. BUT-2142 tvåstegsverifiering (5): reservkoder och inloggningssteg, sedan knappen tillbaka
   (`offersEnrollment`). Det stänger även AU-10/AU-12/KI-19 i `blockerande.md`.
4. BUT-2168 import (3): skilj trasig länk, betalvägg och sida utan recept.
5. BUT-2140 ändringsmodell på servern (1): störst, sist.

Klart när: 0 BUILT_NOT_REACHABLE.

## Fas 4 — halvfärdiga och saknade flöden (14 övergångar)

- Kvitton och tid: BUT-2173 (7 s), BUT-2172 (Skicka igen efter 60 s), BUT-2174 (tidsstämpel
  på cachad data).
- Konto: BUT-2170 (sätt nytt lösenord i appen), BUT-2171 (bekräfta båda adresserna).
- Import och utkast: BUT-2158, BUT-2160, BUT-2175, BUT-2161, BUT-2157.
- Socialt: BUT-2169 (blockering åt båda hållen), BUT-2153 (flerval och konfliktens tredje
  utgång), BUT-2156, BUT-2143.
- BUT-2163 (lagring nästan full) kräver ett sätt att läsa ledigt utrymme; byggs sist.

Klart när: 81 av 81 övergångar TESTED, `transitions 0`, `interactions 0`. <!-- claim-lint:ok a target, not a measurement -->

## Fas 5 — releaseblockerare ur designrepot (`blockerande.md`)

- BUT-2222 (hög): Mina anmälningar med utfall i klartext och väg att överklaga (Google Play
  UGC). Tillsammans med BUT-2154.
- BUT-2152 (hög): dela flera recept på en gång kraschar.
- BUT-2223: utgången oavgjord menyröstning syns ingenstans.
- BUT-2224: tyst misslyckad autosparning av utkast.
- BUT-2225 + BUT-2145: Ångra på fem borttagningar/tillägg.
- D2 (isStaple) verkställs här.

Redan lösta och strukna: KI-02, SK-13, SK-03, KI-15, BH-08 (manifestet), P-06/P-07 (licensvyn).

## Fas 6 — ikonerna (BUT-2166, 393 användningar av 178 ikoner)

Designarbete först: glyferna ritas i designrepot (`icons.json`), levereras via D1 till
`ButleryIcons`, och appen byter en fil i taget med `icon_census_test` som spärr. Delas i
omgångar om högst 50 användningar per PR. Startar så snart de första glyferna finns, parallellt
med fas 3–5.

Klart när: `_residue` 0 och `Icons.<name>` 0 i lib.

## Fas 7 — designrepot

- Pusha B83-2a–2e (tre lokala commits) — bara designsessionen kan committa/pusha där.
- Uppdatera `NULAGE.md`: 66 brister, 50/81, 53/53, dagens datum; åter när varje fas stänger.
- D1-kedjan för BUT-2147/2198/2165/2191 (fas 1) och ikonerna (fas 6); `node tools/gen-manifest.mjs`
  efter varje ändring.
- BUT-2202 (flytta in designsystemet i appens repo) görs efter att allt ovan är klart.

## Fas 8 — på riktig telefon (går inte att göra med kod)

`testmatris.md` § 4 + BUT-1989 + BUT-1179: TalkBack, VoiceOver, 2,0× systemtext, rotation,
reducerad rörelse, timern på låst Android 13 (BH-08), tvåstegsverifiering och offlinekön efter
fas 3. Enhet och datum fylls i i testmatrisen. Malin eller den hon utser gör det; vi tar fram
checklistan per pass.

## Efter migreringen

BUT-2221 (namn och profillänk på delade rätter, opt-in), BUT-2202, BUT-907.

## Arbetssätt

- Mekaniska delar (fas 1, 2, 6) körs utan egen plan per del under Q1 = A; allt som rör
  regler, auth, GDPR eller Cloud Functions (fas 3, delar av 4 och 5) får egen plan och ja.
- Varje PR genom commit-grindarna; Linux-golden ritas om före varje synlig sammanslagning;
  census regenereras i varje PR som rör en lista.
- Inget slås ihop rött. Deferred arbete blir biljett, aldrig en rad i chatten.

## Verifiering av hela planen

- `dart run tools/design_migration_census.dart --format=md --out=docs/design-migration`
  visar: kända brister 0 (eller 0 + godtagna om D5 = B), 2 restlistor tomma, 81/81, 33/33.
- `NULAGE.md` säger samma siffror med samma datum.
- `testmatris.md` § 4 har enhet och datum på varje rad.

## Sammanfattning för Malin

Allt som går att rätta i appen inom designen är klart. Det som är kvar är tre saker:
funktioner som är byggda men avstängda (offline, konflikter, tvåstegsverifiering), flöden
som är halvfärdiga, och ikonerna som behöver ritas. Dessutom fem saker ur designrepots
releaselista som nu har biljetter. Sex beslut väntar på dig (D1–D6); utan D3 börjar jag med
offlinekön.
