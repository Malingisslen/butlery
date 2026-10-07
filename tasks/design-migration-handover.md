# Överlämning — designmigreringen (2026-10-05)

Designmigreringen flyttas till ett Claude-projekt. Den här filen visar var arbetet står när
kodsessionen avslutas. Hela planen finns i `tasks/design-migration-completion-plan.md`
(faserna 0–8 och vad "klar" betyder). Arbetssättet framåt är en PR per biljett, automerge på
grön CI och aldrig merge på rött.

## Läget 2026-10-07

Mätt med `tools/design_migration_census.dart` samma dag:

- Kvar: 16 flödesövergångar och 390 ikonanvändningar utan ritad glyf (BUT-2166).
- De 12 godtagna kontrastposterna (BUT-2196) räknas nu för sig enligt beslut D5 = B.
  Census visar dem som "accepted", inte som kända brister.
- Kontrast 0, interaktionstillstånd 33 av 33, vytillstånd 53 av 53.
- Mergat sedan 2026-10-05: BUT-2146 (#407, #418), BUT-2248 (#411), BUT-2191 (#424),
  BUT-2211 (#460), BUT-2250 (#471), fas 2 BUT-2148/2176/2177 (#470, #476, #477),
  BUT-2168 (#472), BUT-2249 (#482), BUT-2162 del 1–3 (#484, #488, #489) och
  BUT-2173/2174/2175 (#485).

Kön framåt, i ordning:

1. BUT-2235: startvyn kraschar i webbversionen. Det är en bugg och rättas direkt.
2. BUT-2160 och BUT-2158 (fotoflödena) är UI och behöver ingen egen plan.
3. Det som rör Firestore, auth eller servern får en egen plan som Malin säger ja till:
   BUT-2215 (veckomenyns konfliktvarning), BUT-2213, BUT-2216/2217, BUT-2142, BUT-2169,
   BUT-2170, BUT-2171 och BUT-2140.
4. BUT-2163 (lagring nästan full) byggs sist.
5. BUT-2166 (ikonerna) väntar på glyfer från designrepot.

Avsnitten nedan är läget 2026-10-05 och står kvar som historik.

## Klart

- **BUT-2205, tryckt och hovrat utseende:** PR #370–#380 är mergade och biljetten är Done.
  En rad på sidbakgrunden blir raised när man trycker eller hovrar. En rad som redan är raised
  tar ett mörkare steg, och mörkgröna ytor får steget på ink. Ytorna i BUT-2232 behåller det
  gamla utseendet (`PressUnchanged`), och vakterna står i
  `test/architecture/press_fill_inkwell_test.dart`.
- **BUT-2209, svarsförhandsvisningen och bildtexten:** PR #384, Done.
- **BUT-2208, en receptrad i delningsdialogerna:** PR #387, Done.
- **BUT-2146, del 1 (PR:en som den här filen ligger i):**
  - Väntetiden vid e-postverifiering visas under knappen, inte i knappens namn.
  - Knappen kommer tillbaka efter 60 s (BUT-2172).
  - Pilen i chatten säger "Tillbaka till Meddelanden" när chatten öppnas från inkorgen.
  - Sidan för en okänd adress visar svensk text från appens texter.
  - Census: 62 kända brister, mätt 2026-10-04 med `tools/design_migration_census.dart`.

## Kön, i ordning

1. **BUT-2146: kategorirubrikerna i inköpslistan.** Inte påbörjat.
2. **BUT-2146: goldens för Mina recept och för 200 % text.** Inte påbörjat.
3. **BUT-2248: tillgängliga namn med personens namn på knapparna Acceptera och Avböj för
   vänförfrågningar.** Bröts ut ur BUT-2146 och är inte påbörjat.
4. **BUT-2216 och BUT-2217: samarbetsmenyns laddning och dess döda väg.** De rör Firestore och
   behöver därför en egen plan.
5. **BUT-2167: dokumentationsresterna.**
6. **BUT-2235: startvyn kraschar i webbversionen** (`flutter run -d web-server
   --dart-define-from-file=.env`). Det stoppar webbkontrollen av vyerna.
7. **Fas 2–8 enligt `tasks/design-migration-completion-plan.md`.**

## Väntar på designrepot

- **BUT-2191:** strykningen av `dataScale` (beslut D1 = B, eftersom ingen vy ritar en dataskala).
- **BUT-2198:** tokens `surface.selected` och `border.onInk`.
- **BUT-2211:** generatorn för motion-tokens har en bugg. Den behöver också Malins beslut om
  avrundning (se nedan).

## Öppna frågor till Malin

1. **"+ Lägg till vän" på den publika profilen.** Designen visar knappen, men appen har ingen
   sådan handling i dag. Ska den byggas, eller ska den strykas ur designen?
2. **Delningsarkets handtag.** Designen ritar ett handtag, men delningsytan är en dialog enligt
   Komponentark v1:99, och en dialog har inget handtag. Ska delningen bli ett ark med handtag,
   eller ska handtaget strykas ur designen?
3. **BUT-2211, avrundning.** Hur ska varaktigheter på 500 ms eller mer avrundas när de blir
   motion-tokens?
