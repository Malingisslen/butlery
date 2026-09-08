# BUT-2040 + BUT-2039 — camelCase-luckan i kontoraderingen, och de osanna meningarna

## Vad som är mätt (i dag, i koden — inte hämtat ur ärendetexten)

**BUT-2040.** Under `users/{uid}` finns två stavningar av samma sak:

- `rate_limits` — nuvarande. `FirestoreCollections.userRateLimits = 'rate_limits'`,
  och sex filer i `lib/` skriver dit via konstanten (fyra repositories och två
  tjänster). Commit `b9a95bd02`, 2026-03-19, är namnändringen.
- `rateLimits` — camelCase. **Ingen skrivare i `lib/` eller `functions/src`.** Fem rader
  i produktion, mätta av BUT-2028:s torrkörning mot butlery-app-1.

`deleteUserSubcollections` (`functions/src/account/account-deletion-cascade.ts`) går på
en handskriven `subs`-lista. Den innehåller `rate_limits`, inte `rateLimits`.
`probeResidualData` **uppräknar** i stället via `listCollections()`, med bara två
uteslutningar (`notificationCounters`, `recentContentHashes`) — så sonden ser
camelCase-raderna, räknar 5 > 0 och sätter `residual_data_detected`.

Nettot: varje radering av ett konto med sådana rader rapporterar `gdprCompliant: false`
om sig själv, korrekt, och **ingen kodväg kan någonsin rensa det**. Det är exakt den
riktning filen själv kallar oåterkallelig: superset-regeln DELETER ⊇ PROBE, skriven i
`subs`-listans egen kommentar.

Dessutom, samma fil-familj: `import_rate_limiter.dart` sade i sin klasskommentar
`/users/{userId}/rateLimits/imports`. Koden i samma fil skriver via konstanten, alltså
`rate_limits`. Kommentaren är kvar från före namnändringen.

**BUT-2039.** `functions/src/admin/reset-collection-lists.ts` säger, i posten
`system_ip_audit_caps`, att den inte är personuppgifter (`so it is not user data`). Nyckeln
byggs som `hashUid(ip)_hour`, och `hashUid` är osaltad sha256 trunkerad till 48 bitar.
IPv4-rymden är ~4,3 miljarder adresser, alltså genomräkningsbar av vem som helst som har
dokumentet. Påståendet är falskt. **Beslutet står** — postens andra skäl ("wiping it
hands a fresh quota to whoever just tripped the cap") är oberoende tillräckligt.

## Ändringar

- [x] **1. `rateLimits` in i `subs`** (`account-deletion-cascade.ts`), i legacy-blocket
      bredvid `category_memberships`/`fcm_tokens`, med samma skäl som de fem står där av:
      ingen levande skrivare, men konton som föregår namnändringen håller rader, och utan
      posten är raden permanent restdata. Kommentaren säger att `rate_limits` är den
      levande stavningen och att de två är samma data under olika namn — inte två
      samlingar.
- [x] **2. `rateLimits` in i `EXPORT_EXEMPT`** (samma fil). **Detta är inte valfritt:**
      BUT-1992-vakten (`scenario_...ExportSupersetOfDeletion`) rödnar på varje `subs`-post
      som varken exporteras eller är undantagen med ett skäl. Formuleringen följer
      `NO LIVE WRITER`-konventionen ordagrant, eftersom en systervakt använder just den
      inledningen som ankare för att upptäcka om en skrivare senare dyker upp.
- [x] **3. `rateLimits` in i `NO_OWN_STEP`**
      (`scenario_steplessSubcollectionsAreErasedNotJustReported` i
      `functions/src/__tests__/account-deletion-cascade.test.ts`). Den kör raderaren och
      sonden mot samma fejkade databas och pinnar DELETER ⊇ PROBE per namn. Utan den är
      punkt 1 en listrad ingenting utövar.
- [x] **4. Stryk den falska doc-kommentaren** i `import_rate_limiter.dart:18`. **Strykning,
      inte omskrivning** — code-style säger att en falsk mening tas bort snarare än
      formuleras om, och sökvägen är ändå läsbar ur konstanten två rader från skrivningen.
- [x] **5. Nämn båda stavningarna i nollställningsskriptets `users`-inventering**
      (`reset-collection-lists.ts`). Listan driver inte raderingen —
      `deleteDocRecursive` uppräknar — men den är vad en läsare griper efter för att lära
      sig formen, och i dag saknas **båda** stavningarna i den.
- [x] **6. BUT-2039: stryk den osanna meningen — EN, inte två.** Endast klausulen `so it is not user data,`. **Ingen ersättande juridisk mening skrivs** — en sannare
      variant är ett nytt omätt påstående, och det är kedjan BUT-2028 betalade sju
      granskningsrundor för. Vill vi ha en juridisk slutsats hör den hemma i ett ADR.
      **Rubriken på rad 310 lämnas orörd.** BUT-2039 säger åt att stryka även den, och
      den instruktionen vilar på en felräkning: rubriken "Operational records that carry
      no personal data" styr **bara `metrics`** (mätt — `_internal`, `audit`/
      `notification_metrics` och `system_ip_audit_caps` ligger under tre egna rubriker på
      rad 322, 330 och 347). `metrics` är aggregat utan uid, så rubriken är sann om den
      enda post den styr; att stryka den vore att ta bort ett riktigt påstående för att
      laga ett annat. Ticketen får en kommentar om felräkningen.

## Panelens villkor (full-panel, 2026-09-08 — 5 approve, 1 approve-with-conditions)

Säten: DPO, Security Architect, DBA, Legal Counsel, Software Architect + Codebase
Archaeologist. Bortvalda: FinOps, Monetization, Vendor, Data/Integrations (matchade bara
på `import_rate_limiter.dart`, som här bara får en falsk kommentar struken), T&S och PM
(ingen moderations- eller produktyta). Noll konflikter, alltså ingen ADR.

- [x] **V1.** `EXPORT_EXEMPT`-skälet börjar med exakt `NO LIVE WRITER` — en systervakt
      ankrar på `why.startsWith("NO LIVE WRITER")` för att rödna den dag en skrivare dyker
      upp. En omskrivning lämnar posten utanför vakten, tyst.
- [x] **V2.** Skälet citerar Malins beslut 2026-09-03 (ADR-0011) och säger att det är
      **samma data före namnändringen**, inte ett nytt undantag. Motsatt form mot
      `fcm_tokens`/`user_shared_menus`, som är samma NAMN på olika data — den skillnaden
      måste stå i koden, inte bara här, annars ärver nästa läsare fel prejudikat.
- [x] **V3.** Ingen artikel 15-sektion för `rateLimits`. Att lägga till en vore att riva
      upp beslutet från 2026-09-03 utan att fråga.
- [x] **V4.** Mutationsprovet körs och återställs FÖRE grindarna dispatchas.
- [x] **V5.** Kommentaren i `subs` skrivs som `//`-rader, aldrig `/* */` — vaktens
      källtextparser strippar bara radkommentarer, och ett citerat samlingsnamn i ett
      blockkommentar-parti smyger in ett falskt listnamn i vaktens bild av listan.
- [x] **V6.** Sökvägen skrivs som `users/{uid}/rateLimits`, ALDRIG som
      `.collection("users").doc(uid).collection("rateLimits")` — skrivarskanningen läser
      anropssyntax i prosa som en levande skrivare och skulle rödna på sin egen kommentar.
- [x] **V7.** De två siffrorna i kommentaren ovanför no-writer-blocket ("The first four…",
      "All five…") blir falska av den här ändringen. De **stryks** i stället för att räknas
      om — en siffra som beskriver en fil man själv redigerar går inte att skriva rätt, och
      den ena räknar dessutom rader i en ANNAN fil.
- [x] **V8.** Rör inte rubriken på rad 310 (se punkt 6).
- [x] **V9.** BUT-2039-strykningen växer inte till ett nytt påstående om hashens
      lämplighet som nyckel — det är en egen omätt fråga, redan noterad på ärendet.
- [x] **V10.** En TREDJE kopia av samma falska sökväg finns i
      `docs/architecture/ROLE_RESPONSIBILITY_MAP.md:530`. Den stryks i samma ändring —
      annars fortsätter dossiern påstå fel sökväg för alltid, utanför commit-grindarna.
- [x] **V11.** Punkt 5 är dokumentation, inte beteende: `deleteDocRecursive` uppräknar och
      sopar båda stavningarna redan i dag. Får inte beskrivas som en beteendeändring.

## Namngiven restpost (Software Architect)

Ingen källskannande vakt kan någonsin fånga den här buggklassen. Både drift-vakten och
BUT-1992-vakten letar efter `.collection(users).doc().collection(X)`-kedjor i koden — en
död namnändring har inga skrivare och är osynlig för dem per konstruktion. De fångar att en
NY skrivare saknar listrad, aldrig att en GAMMAL rad blivit föräldralös. Det som hittade
den här var en torrkörning mot riktig data, och det är den enda mekanism som kan hitta
nästa. Ingen kadens är beslutad för att köra om den.

## Verifiering

- [x] `npm run test:account-deletion-cascade` — 297 gröna i dag; punkt 3 lägger till två
      per namn, och punkt 1+2 måste hålla BUT-1992-vakten och drift-vakten gröna.
- [x] **Mutationsprov på punkt 1**: ta bort `rateLimits` ur `subs` igen och bekräfta att
      det nya fallet rödnar. En listrad utan ett prov som dör med den är en oprövad
      utfästelse — det är precis den formen som lät `reset-user-data` stå trasig i fem och
      en halv månad.
- [x] Mutationsprovet körs **före** granskningsgrindarna dispatchas, aldrig samtidigt:
      provet skriver i `lib/`/`functions/src` och en läsande grind graderar då bytes som
      inte ska shippas.
- [x] `flutter analyze` på `import_rate_limiter.dart` (kommentarsändring, men gratis).
- [x] `dart format` rapporterar 0 ändrade innan grindarna dispatchas.

## Vad som INTE görs

- Ingen bakåtfyllning som städar de fem befintliga raderna. De raderas när respektive
  konto raderas; skriptet `reset-user-data` uppräknar redan och tar båda stavningarna i
  dag. Appen är inte lanserad, så populationen är två testkonton.
- `rateLimits` läggs **inte** till i någon exportsektion. Det vore en artikel 15-sektion
  för en form ingen levande kod skriver — DPO-sätet namngav den restposten redan under
  BUT-1957 och den är Malins, oställd.
- BUT-2038 rörs inte.

## Rättad premiss (var en öppen fråga i första utkastet)

Första utkastet av den här planen påstod att rubriken på rad 310 täcker fyra poster.
Falskt, mätt: den styr en. Påståendet kom från BUT-2039:s egen text och gick vidare
oprovat in i planen — samma klass som repots lärdom om att ett ärendes eller en
granskares mätning är ett påstående, inte en mätning. DPO-sätet fångade det; jag
räknade om själv innan jag trodde på det.

## På vanlig svenska

Kontoraderingen missar en gammal felstavad mapp under varje användare. Fem sådana rader
finns i produktionen. Följden är att appens egen kontroll säger "den här raderingen blev
inte komplett" — och har rätt — utan att något kan laga det. Fixen är en rad i
raderingslistan plus ett prov som dör om någon tar bort den igen.

Samtidigt rättas ett antal osanna meningar som granskningen hittade: påståenden om
vilken mapp importkoden skriver till, och ett påstående om att en IP-hash inte är
personuppgifter fast den går att räkna baklänges på kort tid. Inga beslut ändras av det —
bara meningar som inte stämde.
