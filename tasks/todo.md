# Plan — BUT-2006 fråga 1: smalna av `contributorUserIds` till dem som lämnat ett spår

## Context

`contributorUserIds` på gruppens veckomeny (`group_weekly_menu_plans`) finns för att göra en
avhoppare RADERBAR: när någon lämnar tas hen ur rostern, men id:t ligger kvar på rätter och i
redigeringsspåret, och listan är handtaget raderingskaskaden hittar dokumentet med. I dag unionerar
listan dock HELA rostern, så en passiv deltagare — som aldrig föreslog, röstade, redigerade eller
var föremål för en spårrad — får ett bestående id på dokumentet utan att det finns något av hen att
radera. Det är lagring utan syfte (art. 5.1 c), och sedan 2026-09-17 syns listan inte ens i
exporten. **Malins beslut 2026-09-18: smalna av.**

## Kvar att avgöra

**Inget.** Båda besluten är tagna: smalna av, och läs rätterna vid behov (valt framför "bara
appen", "acceptera luckan" och "låt vara"). Resten av planen är bygget och ändrar inget beteende
användaren ser.

**Svagaste punkten:** testfixturen för desynk-grenen. Grenen har inget test i dag, och en fixtur som
av misstag hamnar i radera-grenen i stället gör att testet passerar utan att pröva något. Den bär
därför en premissassertion.

## Mätt 2026-09-18 (inte hämtat ur poster)

- **Huvudkällan är appen, inte avhoppet.** `GroupWeeklyMenuPlan.contributorUserIdsForWrite`
  (`lib/models/menu/group_weekly_menu_plan.dart:281-303`) unionerar lagrat värde + varje
  `participants[].userId` + `entries[].proposedBy`/`votedInBy` + `editTrail[].actorId`/`subjectId` +
  `lastModifiedBy` (utom tombstonen `'deleted'`), på VARJE sparning (`toFirestore()` rad 371). En
  passiv medlem hamnar alltså i listan så fort någon sparar veckan.
- **Avhoppet unionerar villkorslöst.** `cutGroupMenuPlanAccess`
  (`functions/src/groups/group-menu-access.ts:218-240`) `arrayUnion(...departing)` utom när taket
  200 skulle passeras.
- **Id-bärande fält på dokumentet:** `participants[].userId`, `participantUserIds`,
  `memberPermissions`-nycklar, `lastModifiedBy`, `entries[].proposedBy`, `entries[].votedInBy`,
  `editTrail[].actorId`, `editTrail[].subjectId`, `contributorUserIds`. Inget persisterat
  `creatorId`.
- **Vad ett avhopp tar bort:** `participants`, `participantUserIds`, `memberPermissions` skrivs om ur
  kvarvarande. Kvar: rätter, spår, `lastModifiedBy`.
- **Undantaget:** i desynk-grenen (`group-menu-access.ts:323-354`) skrivs `participants` INTE om —
  avhopparens `userId` ligger kvar där, loggat på ERROR. Kaskadens fyra upptäcktshandtag
  (`account-deletion-cascade.ts:1693-1719`: `participantUserIds`, `lastModifiedBy`,
  `memberPermissions.<uid>`, `contributorUserIds`) läser INTE `participants`. Där är unionen alltså
  det enda som gör en passiv avhoppare raderbar, och den måste stå kvar.
- **Svar på den öppna frågan:** en passiv deltagare som lämnat har sitt id i INGET annat fält än
  `contributorUserIds` — utom i desynk-grenen. Rekommendationen håller med det undantaget.

## Vad som ändras

### 1. Appens modell — huvudändringen

`contributorUserIdsForWrite` slutar unionera `participants[].userId`. Kvar: lagrat värde (så
reglernas append-only `hasAll` aldrig bryts), rätternas föreslagare och röstare, spårets aktör och
föremål, och `lastModifiedBy` utom tombstonen. En medlem som LÄMNAT ett spår kommer därmed in i
listan i samma sparning som skapar spåret — före avhoppet, som i dag.

### 2. Servern — villkorad union vid avhopp, med riktad läsning (Malins val 2026-09-18)

**Varför det inte räcker att kontrollera det servern redan läser** (säkerhetsarkitekten, mätt):
`cutGroupMenuPlanAccess` läser med `.select("participants", "participantUserIds",
"memberPermissions", "editTrail", "contributorUserIds")` (`group-menu-access.ts:129-135`) och väljer
medvetet bort `entries`, som kan vara upp till 1 MB per vecka gånger upp till 500 veckor. Reglerna
har inget storlekstak på `entries`. Och `entries[].proposedBy`/`votedInBy` är förfalskningsbara av
vilken redaktör som helst, utanför modellen. Kontrollerar servern bara det den redan läser, kan ett
id som ett eget program lagt in bland rätterna inte raderas efter avhopp. Att lägga `entries` i
huvudläsningen riskerar i stället minnet, och ett avhopp som kraschar lämnar kvar åtkomsten.

**Design — normalgrenen, per vecka och per avgående uid `u`:**
1. `u` står redan i lagrat `contributorUserIds` → ingen åtgärd (unionen vore en no-op).
2. `u` är `actorId` eller `subjectId` i `editTrail` (redan läst) → unionera.
3. `lastModifiedBy === u` → unionera. `lastModifiedBy` läggs till i `.select()` — en sträng, ingen
   minnesrisk.
4. Annars: **riktad läsning av just den veckans `entries`**, ett dokument i taget (Admin SDK
   `getAll(ref, { fieldMask: ["entries"] })`), och unionera om `u` är `proposedBy` eller i
   `votedInBy`. **En läsning per vecka, inte per avgående:** alla avgående som fortfarande är
   oavgjorda för den veckan prövas mot samma läsning, så att flera som lämnar samtidigt inte ger
   flera läsningar av samma dokument. Minnet är begränsat till ett dokument. Kostnaden är en extra läsning per vecka där en
   avgående varken är registrerad eller står i spåret — i praktiken en passiv avhoppare, och avhopp
   är sällsynta.
5. **Misslyckas den riktade läsningen → unionera ändå** och logga. Kan vi inte avgöra om det finns
   ett spår, väljer vi raderbarhet framför minimering.

**Takaritmetiken räknas på den FILTRERADE mängden** — de avgående som faktiskt ska unioneras.
Skippa-i-stället-för-trunkera är oförändrat.

**Desynk-grenen: unionen står kvar villkorslöst**, av skälet ovan.

### 2b. Kommentarer som blir falska — stryks, skrivs inte om (arkeologen)

Tre kodkommentarer påstår den gamla villkorslösa unionen och blir falska av ändringen:
- `group-menu-access.ts` rad ~47-52: "…so `contributorUserIds` is unioned here in the same write" —
  gäller inte längre normalgrenen.
- `group_weekly_menu_plan.dart` fältets doc (~177-190): "every uid the document currently names" —
  falskt, en passiv rostermedlem nämns av dokumentet men unioneras inte.
- `group_weekly_menu_plan.dart` `contributorUserIdsForWrite`-doc (~272-280): "Any field that can hold
  a uid … must be unioned here" — falskt, `participants` unioneras inte längre.

Den falska satsen stryks. Ny text bara där koden annars saknar förklaring, och då bara vad koden
GÖR (villkorad union, undantaget i desynk-grenen) — aldrig varför det en gång var annorlunda.

### 3. Oförändrat, medvetet

- `firestore.rules`: taket och append-only påverkas inte — unionen blir mindre, aldrig större.
  Rules-sviten bygger sina payloads för hand (`groupPlanBody`), inte ur modellen, så den berörs
  inte. Ingen drift-test binder unionslogiken (`rules_numeric_bound_drift_test.dart` binder bara
  siffran 200), och kartan beskriver fältets SYFTE, som är oförändrat.
- Kaskaden och `probeResidualData`: `contributorUserIds` är fortfarande ett av fyra handtag.
- Exporten: fältet stryps redan (beslut 2026-09-17).
- **Framåtriktat:** passiva id som redan ligger i listan blir kvar tills kontot raderas — reglerna
  tillåter ingen klient att ta bort en post, och en rensning via Admin SDK är inte i scope. Appen har
  inga användare; antalet sådana rader i produktion är INTE mätt.

### 4. Beslutsposter och ärende

Daterad supersederande post i båda speglarna. Den retirerar posten "The union can create the only
surviving record that a PASSIVE participant was ever on a week … A minimisation question for Malin
rather than a defect, and unasked." — ordagrant, per fil, på en rad, matchad på fullt citat plus
ticket. Posten säger vad koden gör, desynk-undantaget och att ändringen är framåtriktad. BUT-2006:
fråga 1 besvarad; ärendet stängs.

## Test

- `test/unit/models/menu/group_weekly_menu_plan_test.dart`: `'unions every uid the document names'`
  förväntar sig inte längre `roster-uid`. Nytt fall: en rostermedlem utan spår unioneras INTE. Nytt
  fall: en rostermedlem som ÄR föreslagare unioneras. `'keeps a stored uid…'` står kvar oförändrat.
- `functions/src/__tests__/chat-group-callables.test.ts`: `'records every departing member as a
  contributor'` delas: en avgående MED spår registreras, en passiv registreras INTE.
- **Desynk-grenen har i dag NOLL tester** (arkeologen). Nytt test, ny fixtur: en medvetet
  inkonsistent seed där `participants` lämnar `remaining.length === 0` medan `memberPermissions` /
  `participantUserIds` fortfarande nämner en överlevare — så att klipp-per-nyckel-grenen nås och
  INTE radera-grenen. Testet bär en premissassertion att just den grenen nåddes (loggraden eller
  att `participants` är orörd), annars kan sond (c) passera vakuöst.
- **Spår bara bland rätterna** (säkerhetsarkitekten): en avgående vars id står i
  `entries[].proposedBy` men varken i `contributorUserIds` eller i `editTrail` — formen ett eget
  program kan skapa — ska registreras. Detta är testet som bevisar att den riktade läsningen körs.
- **Riktad läsning misslyckas** → den avgående registreras ändå.
- **Passiv avhoppare räknas inte mot taket:** en fixtur nära 200 där en passiv och en spårbärande
  lämnar samtidigt; den spårbärande registreras.
- **Båda** takfallen (`'over the cap with TWO departing…'`, `'exactly at the contributor cap…'`)
  får spår på sina avgående; utan det slutar de pröva takaritmetiken och prövar i stället
  villkoret.
- Mutationssonder, i egen körning före grindarna: (a) återinför roster-unionen i modellen → fallet
  "passiv unioneras inte" rodnar; (b) gör CF-unionen villkorslös → fallet "passiv registreras inte" rodnar; (c) gör
  desynk-unionen villkorad → desynk-fallet rodnar; (d) hoppa över den riktade läsningen → fallet
  "spår bara bland rätterna" rodnar; (e) låt ett läsfel resultera i ingen union → fallet "riktad
  läsning misslyckas" rodnar. Varje sond ska göra exakt ett fall rött.

## Verifiering

1. `dart format` 0 ändrade; `flutter analyze --fatal-infos` rent.
2. `flutter test test/unit/models/menu/group_weekly_menu_plan_test.dart` och sviterna som läser
   modellen (grep `contributorUserIdsForWrite` över `test/`, kör varje träff).
3. `functions`: `npx tsc --noEmit` och CF-sviten för `chat-group-callables`; rules-sviten
   `weekly-menu-plans-rules.test.ts` körs oförändrad och ska vara grön.
4. Sonderna ovan, sedan läs-endast-pass.
5. Grindar: `cloud-functions-specialist` (functions/src), `code-reviewer` + `testing-specialist`
   (Dart), `firebase-backend-security` (modell som når Firestore), `integration-reviewer` (post mot
   kod). Komplett fillista ur `git diff --cached --name-only`, varje fil med `Read`.

## Open questions

**Inga arkitekturändrande okända.** Besluten är Malins (2026-09-18): smalna av, och läs rätterna vid
behov när säkerhetsarkitekten visat att servern annars inte ser dem. Antaganden, mätta i dag: listan
över id-bärande fält ovan är komplett; kaskaden läser inte `participants`; desynk-grenen är den enda
väg där en passiv avhoppare lämnar sitt id kvar utanför listan.

**Verifieras först i bygget, inte antaget:** att Admin SDK:s `getAll` med `fieldMask` finns i den
version `functions/` använder och hämtar bara det fältet. Håller det inte, blir den riktade läsningen
en vanlig `get()` av ett dokument i taget — samma minnesgräns, fler bytes.

## What this means in plain language

- **Ingenting ändras för den som använder appen.** Menyn, rösterna och gruppen fungerar som förut.
- **Vi slutar spara en onödig anteckning.** Den som bara varit med i en gruppvecka utan att göra
  något hamnar inte längre på en intern lista som finns kvar efter att hen lämnat.
- **Den som gjort något går fortfarande att radera helt.** Listan fyller sin uppgift för dem.
- **Ett undantag finns:** om gruppens deltagarlista har hamnat i otakt sparas personen ändå, eftersom
  det annars inte skulle gå att radera hen.
- **Det gäller framåt.** Redan sparade anteckningar ligger kvar tills kontot raderas. Appen har inga
  användare, så i praktiken är det inget.
- **När någon lämnar läser servern ibland rätterna**, en vecka i taget, för att se om personen har
  föreslagit eller röstat på något. Det kostar lite mer arbete vid avhopp, som är sällsynta.
- **Om servern inte kan avgöra saken sparas personen ändå**, så att hen alltid går att radera.
- **Risk:** låg. Om listan skulle missa någon som faktiskt har spår på en vecka går den personen inte
  att radera fullt ut — det är därför testerna prövar just det, även för spår som lagts in utanför
  appen.
