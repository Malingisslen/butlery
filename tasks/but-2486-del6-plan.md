# BUT-2486 del 6 – veckoförslaget lägger in matlådor som lunch

Status 2026-11-25: Malins val via kort (dagar väljs i önskemålen, kyl och frys, kylens lådor
högst 5 dagar gamla). Mockup godkänd 23:17: https://claude.ai/artifact/VTUDqLS6VmmRjR7HUXQh5Y.
Koordinatorn gav klartecken samma kväll. Byggs från origin/main d4a3b1f. Opus-område
(allergisäkerhet). Router: tier single (Product Manager + Security Architect).

**Produktprincip:** användaren ber varje vecka om en veckomeny. Lådorna hemma är stöd för det:
när förslaget görs används de som luncher innan något nytt föreslås.

## Sammanfattning för Malin

I veckomenyns tomläge väljer du under "Matlåda till lunch" vilka dagar som behöver låda (telefonen
minns förra veckans val). När du trycker på Generera lägger appen lådor ur kylen (äldst först, högst
5 dagar gamla på lunchdagen) och sedan frysen på de dagarna. Luncher som redan finns rörs inte.
Räcker inte lådorna blir dagen tom. En låda vars allergier inte kan kollas läggs aldrig in av appen.
Antalet i kyl och frys räknas om av sig själv.

## Läget i koden (mätt 2026-11-25)

- `applyGeneratedMenu` (`weekly_menu_plan_viewmodel.dart`) bygger veckan med
  `distributeFromGeneratedMenu`; vid `replaceExisting` töms bara rätterna, lunchlådorna ligger
  kvar, och fördelningen hoppar över lunchrutor med låda (`weekly_menu_plan_service.dart`).
- Den sparar med `saveRevision(next)` UTAN `previous` (rad 894), så `MealBoxTake.between` körs inte.
- `MealBoxService.list()` läser högst 200 lådor, utan cache, och städar (kan skriva).
- `Lunchbox.fromStock` ger formen som inköpslistan aldrig köper för.
- Manuellt lådval (`lunchbox_flow.dart`) frågar bara när receptet går att slå upp. En låda
  vars recept saknas får kalendermärket "Ej bedömd för allergier" (`weekly_allergen_marks.dart`,
  `lunchboxUnjudgedMark`), och ett manuellt tillägg frågar inte om "ej kontrollerat" (beslutad
  design i `ManualAddFinding`). Ingen egen säkerhetsfix behövs; automatiken nedan är strängare.
- Ingen sparväg tappar lunchlådor utan `previous`: `clearWeek`, mallar, `copyWeek` och manuell
  placering (`startFromEmptyWeek`) tömmer bara rätterna (mätt 2026-11-25). "Ändra" i toasten går
  till manuell placering och behåller lådorna.
- Kalenderns lådbedömning (`MealAllergenScope.safeForLunchbox`) täcker allergener, inte kost;
  generatorn filtrerar båda.

## Beslut och design

**D1. Dagväljaren.** Rad "Matlåda till lunch" i tomläget (`veckomeny_body.dart`, under Färdiga
önskemål), sju `BütleryFilterChip` Mån–Sön och en hjälprad. Visas bara när flaggan
`enable_meal_boxes` är på. Valet ligger i `MenuWishesViewModel` och sparas på enheten i en liten
butik (`SharedPreferences`, nyckel per användar-id, mönster som `weekly_menu_draft_store.dart`).
Ingen ny molndata, ingen ny policytext. Ingen läsning av lådor när menyn öppnas.

**D2. Planeraren** – ren funktion `StockLunchPlanner.plan(...)` i
`lib/services/menu/stock_lunch_planner.dart`. In: veckan (basen fördelningen bygger på), lådorna,
valda dagar, `today`, och `isSafe(MealBox)`. Ut: `Map<DayOfWeek, Lunchbox>`.
- Bara valda dagar som inte redan har en lunchlåda och som inte ligger före `today`.
- En låda (1 portion, tagare tomma = hela hushållet) per dag, dagarna i ordning mån→sön.
- Kandidater: kyl före frys, äldst `storedOn` först inom varje; kvar = `remaining` (räknar redan
  in veckans befintliga uttag), minskas med 1 per placering i samma körning.
- Kyllåda hoppas över för en dag där lunchdagen − `storedOn` > 5 dagar (kalenderdagar).
- `isSafe` falskt → lådan används inte alls.

**D3. Säkerhet (`isSafe`).** Tagarna är tomma, så lådan bedöms mot hushållet, som kalendern gör
för en låda utan tagare (`MealAllergenScope.householdFromLocator()`, golvet vid läsfel). En låda är
säker bara om: receptet finns i de laddade recepten; `filterByPrefs` släpper igenom den för
allergener OCH kost (som generatorn); och `ManualAddCheck.findingAt(..., slot: lunch)` är tomt
(ingen allergen innehåller eller är okontrollerad, ingen ogillar rätten). Fel i läsningen av
hushållet → inga lådor (fail closed). Avsiktligt strängare än det manuella valet, eftersom appen
väljer utan att fråga. Acceptans: en automatiskt lagd låda får aldrig ett allergenmärke.

**D4. Läsning och fel.** `applyGeneratedMenu` får `Set<DayOfWeek> lunchboxDays` (tom = som i dag).
Lådorna läses EN gång, bara när flaggan är på, dagarna inte är tomma och minst en vald dag från
i dag saknar låda; före skrivningen, efter allergenguarden, med tidsgräns 3 s (då: utan lådor).
Byttes veckan under väntan räknas planen om på den nya basen (befintlig loop-princip). Läsfel →
förslaget görs utan lådor, och vyn säger det. Mäts i test: 0 läsningar utan dagar, 1 annars.

**D5. Sparning.** Rad 894 blir `saveRevision(next, previous: previousPlan)` så uttagen skrivs i
samma WriteBatch som veckan (`saveWithMealBoxTakes`, en commit; vägrad batch skriver inget).
Återställningen sätter tillbaka veckan som i dag.

**D6. Synligt resultat.** Kvittot efter förslaget: "N rätter och M matlådor placerade" när M > 0,
med samma "Ändra" som i dag (ingen Ångra finns för förslaget; skillnad mot mockupen, sagd till
Malin). Läsfel ger en egen rad "Kyl och frys kunde inte läsas, så inga matlådor lades in." En vald
dag utan låda ser ut som i dag. Dagar med automatiskt lagda lådor får NY-märket.

**D7. Avgränsning.** Bara personliga veckor (gruppens vy använder inte denna viewmodel). Manuell
placering (`MenuPlacementView`) och mallar lägger inte in lådor i v1. Ingen analyshändelse i v1.

## Byggsteg (en PR)
1. `StockLunchPlanner` + enhetstester (ordning, kyl 5 dagar, frys utan gräns, befintlig låda
   rörs inte, passerade dagar, osäker låda, slut på lådor, kvar minskar inom körningen).
2. Lådläsning + `isSafe` i en egen hjälpfil (`lib/viewmodels/menu/stock_lunch_fill.dart`) så
   viewmodeln växer minimalt; tester för läsfel, fail closed, 0/1 läsning.
3. `applyGeneratedMenu`: parameter, planeraren på basen, `previous` i sparningen, NY-dagar.
   Test: uttag skrivs (fake repo får `previous`), rollback.
4. Dagbutik + `MenuWishesViewModel` + raden i tomläget + toasttexter (sv/en). Widgettest.
5. `ACCEPTED_LARGE_FILES` uppdateras för filer som växer. Avvikelserader (båda filerna):
   automatiken är strängare än manuellt val; lunchdagarna ligger bara på enheten.
   Policy 1.44 ("När du väljer en låda som lunch ...") kontrolleras före merge; ändrad text går
   till Malin som kort.
5b. Emulatorbanan: generera med lådor → veckan och flera uttag i samma batch godtas av reglerna.
6. Verifiering: analyze, tester på ändrade filer, flödet provat i webbläsaren (ljust/mörkt).

## Villkor från granskningen (2026-11-25, rådgivare + kall plangranskare + panel PM/Säkerhet/Tillgänglighet/Text)
- Hushållets allergier läses med `MenuGenerator.resolveHouseholdPrefs` (kan kasta) — INTE
  `householdFromLocator`, som tyst faller tillbaka till egna allergier. Kast → inga lådor.
- `isSafe` = recept laddat ∧ `filterByPrefs(allergens: true)` ∧ `filterByPrefs(allergens: false)`
  ∧ `findingAt(slot: lunch).isEmpty`.
- Dagar med en lunchrätt hoppas över (`withLunchbox` skulle annars radera rätten); lådorna läggs
  på basen FÖRE fördelningen så generatorn håller lunchrätter borta från lådans dagar.
- "I dag" = `now ?? clock.now()`, bara datum, i dag inräknad.
- `previousPlan` fångas efter lådläsningen; `previous` skickas bara när veckan är densamma.
  Byttes veckan under läsningen planeras inga lådor.
- Kvittot: plural i sv/en, eget fall när bara lådor placerades; läsfel som info-rad, inte fel.
- Dagchipsen läses upp med hela veckodagen.
- Offline: lådlistan väntar upp till 2 s per vikning, så tidsgränsen 3 s ger ofta "inga lådor"
  med info-raden. Avsiktligt: förslaget ska aldrig vänta på lådorna.
- Policy 1.44 behålls (Malins kortval 2026-11-25 23:31): samma uppgifter sparas, ingen ny version.
