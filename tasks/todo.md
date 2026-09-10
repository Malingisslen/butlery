# Sprint 2026-09-10 (kväll) — sju ärenden, fyra kluster

Vald av `/delivery:sprint-execute`. Föregående sprint är stängd (Slutstatus fylld, allt
committat) och ligger i arkivet nedan.

**Router, batchens filunion vid urval** (9 sökvägar) -> **`single`**, panel
`["Data Analyst / BI", "Performance Engineer", "Trust & Safety / Content Moderation",
"Vendor / Procurement Manager"]`, `high_stakes_hits: []`.
Utdelningen sker i den här sessionen, som kan sammankalla — så kritiken körs FÖRE bygget.
Om unionen ändras innan bygget körs routern om på den union som faktiskt delas ut.

Steg 0 mot HEAD är gjord för alla sju: varje premiss gäller fortfarande (greparna står
under respektive ärende).

---

## Kluster A — blockering (två ärenden, samma kod)

### [Tier A] BUT-2069 — `unblockUser` säger "kunde inte avblockera" fast det gick (Medium, Bug)

Disposition: **build-review** — bygget är en ren korrekthetsfix, men ärendets kommentar bär
en separat öppen fråga till Malin (återhämtningsväg för halvt blockerat läge) som INTE byggs.

Steg 0, mätt: `lib/services/unified/operations/friends_management_operations.dart:448`
har `await _analyticsService?.social.logUserUnblocked(` inuti `try`; `blockUser` på rad 428
har redan `unawaited(...)`. Premissen gäller.

Acceptanskriterier:
- [x] `{text: "logUserUnblocked ligger utanfor den vag som avgor unblockUser returvarde, med egen felhantering - samma form som blockUser rad 428", kind: diff}`
- [x] `{text: "Ett kastande analysanrop kan inte gora en lyckad avblockering till false; test som fejkar just det, mutationsprovat rott", kind: diff}`
- [x] `{text: "blockUsers/unblockUsers-slingorna kontrollerade for samma koppling - lagade eller namngivna som fria", kind: diff}`
- [x] `{text: "De tva metoderna behandlar telemetri likadant, eller sa star det skrivet varfor inte", kind: diff}`
- [x] `{text: "INTE gjort: ingen atervinningsvag for halvt blockerat lage - Malins fraga, star kvar pa arendet", kind: diff}`

### [Tier A] BUT-2070 — `block_enforcement_test` är skippad på ett skäl som kan vara inaktuellt (Medium, test-gap)

Disposition: **build**.

Steg 0, mätt: `test/unit/services/block_enforcement_test.dart:136-139` bär
`skip: 'Pending: fake_cloud_firestore + FieldValue.increment incompatibility'`.

Acceptanskriterier:
- [x] `{text: "skip: borttaget och sviten KORD - utfallet rapporterat, inte antaget", kind: diff}`
- [x] `{text: "Gront: raden borta. Rott: lagat, eller ett skal som ar MATT i dag och daterat", kind: diff}`
- [x] `{text: "Kontrollerat att testet fortfarande matter det det pastar efter BUT-2022:s omvanda ordning", kind: diff}`

---

## Kluster B — oändlig mängd och läckta prenumerationer

### [Tier A] BUT-2067 — fjärde producenten av oändlig mängd (Medium, Bug)

Disposition: **build**.

Steg 0, mätt: `shopping_list_generator.dart:313` `processed.quantity * scalingFactor` går
rakt in i `amount`; `grep isFinite lib/` ger sex träffar och ingen av dem ligger på den
här vägen. Premissen gäller.

Acceptanskriterier:
- [x] `{text: "scaledQuantity har finitetskontroll med LOGGAD 1.0-fallback - kontrollen ligger pa PRODUKTEN, inte pa indata", kind: diff}`
- [x] `{text: "De tva summorna (shopping_list_generator ackumulatorn, shopping_item_management_module dubblettsammanslagningen) har fatt ett MEDVETET beslut - lagade eller namngivna", kind: diff}`
- [x] `{text: "Test for en portionsskalning som spiller over, mutationsprovat rott", kind: diff}`
- [x] `{text: "Fyra producenter av samma beslut: delad hjalpare, eller ett skrivet skal till varfor inte", kind: diff}`

### [Tier A] BUT-2063 — `startMonitoring()` är inte idempotent (Medium, performance)

Disposition: **build**.

Steg 0, mätt — och det ÄNDRAR ärendets egen prissättning: `grep -rn "startMonitoring()" lib/`
ger EN anropare, `recipe_collaborative_manager.dart:370`, och den gjordes idempotent av
BUT-2052. Så batterikostnaden ärendet oroar sig för kan i dag inte uppstå från appens kod.
Defekten är verklig (publikt API som läcker vid andra anrop) men den är ett djupförsvar,
inte en skarp kostnad. Det skrivs i koden, inte som en fotnot här.

Acceptanskriterier:
- [x] `{text: "Tva startMonitoring()-anrop i rad ger EN prenumeration och EN timer", kind: diff}`
- [x] `{text: "stopMonitoring() foljt av startMonitoring() fungerar fortfarande - pinnat", kind: diff}`
- [x] `{text: "Test som pinnar bada, mutationsprovat rott", kind: diff}`
- [x] `{text: "Anroparrakningen star i koden: EN anropare i lib/, redan idempotent sedan BUT-2052 - alltsa djupforsvar, inte en matt batterikostnad", kind: diff}`

---

## Kluster C — artikel 15 (GDPR)

### [Tier C] BUT-2062 — kommentars- och betygsexporten returnerar rå `doc.data()` (Medium, security)

Disposition: **build-review** — projektionen byggs konservativt (samma mönster som repot
redan använt), men VAD som behålls är ett beslut. Parkeras In Review.
(Ursprungligen skrev den här raden att `sharedWithUserIds` är Malins fråga. Panelen
motbevisade det — se Fas 1.4.)

Steg 0, mätt: `firebase_comments_repository.dart:475-477` och
`firebase_ratings_repository.dart:532-534` returnerar båda
`{'id': doc.id, 'data': doc.data()}`. Premissen gäller.

Acceptanskriterier:
- [x] `{text: "Bada exportmetoderna projicerar genom en allowlist som failar CLOSED - ett odeklarerat falt aker inte med", kind: diff}`
- [x] `{text: "Sektionerna bar en data_minimisation-mening som sager vad som utelamnats", kind: diff}`
- [x] `{text: "Beslutet ar daterat i BADA .claude/rules/accepted-deviations.md och docs/architecture/ACCEPTED_DEVIATIONS.md, i samma redigering", kind: diff}`
- [x] `{text: "Beslutet ar argumenterat pa DE HAR TVA samlingarnas egna fakta - ingen harledning ur BUT-1732/1772/1450, vilket ar felslutet de posterna finns for att dokumentera", kind: diff}`
- [x] `{text: "Test som pinnar att ett odeklarerat falt INTE aker med, mutationsprovat rott", kind: diff}`
- [~] `{text: "sharedWithUserIds-fragan star i posten som OPPEN och gar till Malin - den avgors inte har", kind: diff}` — **UPPHÄVT under Fas 1.4.** PM-, Legal- och DPO-sätena mätte oberoende att fältet ska avgöras här, inte skickas vidare. Det är STRUKET och beslutat, och skälet står i båda avvikelseposterna. Kriteriet står kvar oikryssat i stället för raderat, eftersom det är protokollet över vad som ändrades och varför.

### [Tier A] BUT-2059 — inget kopplar reglernas fältlista till exportens (Medium, test-gap)

Disposition: **build**.

Steg 0, mätt: `test/unit/security/rules_allowlist_drift_test.dart:423` bär
`_knowinglyUncovered`-posten `'ingredient_suggestions — no Dart writer; pinned by its rules suite'`,
och rad 475 har `user_moderation`-likhetstestet som ärendet pekar ut som instrumentet.

Acceptanskriterier:
- [x] `{text: "Ett fall som drar BADA listorna ur kallkoden och asserterar rulesKeys delmangd av exportKeys union {userId} - DELMANGD, inte likhet", kind: diff}`
- [x] `{text: "Mutationsprovat: ett falt i reglernas lista utan motsvarighet i exportens gor testet rott", kind: diff}`
- [x] `{text: "_knowinglyUncovered-posten for ingredient_suggestions ar antingen borttagen eller sa star skalet till att den stannar", kind: diff}`
- [x] `{text: "Rakningsassertionen pa rad ~594 stammer efter andringen", kind: diff}`

---

## Kluster D — verktyg

### [Tier A] BUT-2065 — `test:rules:all` är en `&&`-kedja (Medium, test-gap)

Disposition: **build**. Rör bara `functions/package.json` (plus ev. ett litet skript).

Steg 0, mätt: `functions/package.json:70` kedjar ts-node-anropen med `&&`.

Acceptanskriterier:
- [x] `{text: "En rodnande svit tidigt hindrar inte senare sviter fran att koras", kind: diff}`
- [x] `{text: "Kedjan failar fortfarande om NAGON svit failar - exitkoden ar icke-noll", kind: diff}`
- [x] `{text: "Utdatan sager hur manga sviter som kordes och vilka som fol", kind: diff}`
- [x] `{text: "Sviterna delar en emulator och rensar inte mellan sig - parallellkorning valjs INTE utan att det ar matt", kind: diff}`

---

## Needs you (Tier D) — inget den här sprinten

## Ej valda, med skäl
- **BUT-2057** — utplockad av gårdagens sprint efter mätning; åtgärden kräver Malins beslut.
- **BUT-2045** — Tier D, kräver skarp projektåtkomst.
- **BUT-2017**, **BUT-1996**, **BUT-1730**, **BUT-2020** — för stora för en delad batch.
- **BUT-2027** (getUserProfiles) — tio anropare, egen sprint.
- `need-malin`-märkta ärenden — beslutskön, inte bygget.

## Fas 1.4 — panelens bindande villkor

**Två routningar, och den andra ändrade tiern.** Urvalets union (9 sökvägar) gav `single`,
panel om fyra roller, som kördes blint och svarade: fyra `approve-with-conditions`, noll
invändningar. När bygget visade att `data_minimisation`-meningen måste skrivas i
`activity_export_manager.dart` gav samma routning på den FAKTISKA unionen (11 sökvägar)
**`full-panel`**, `high_stakes_hits: ["lib/services/account/export/activity_export_manager.dart"]`,
tio roller. Utdelaren är den här sessionen, som kan sammankalla — så de sex återstående
sätena kördes blint på BUT-2062 innan något byggdes där. Det är precis den VIDGNING
regeln finns för.

Utfall, tio säten: nio `approve-with-conditions`, **en `object`** (Software Architect, om
lagerplacering). Ingen invändning gällde om ändringen ska göras.

**Invändningen, och hur den avgjordes.** Security Architect ville lägga projektionen i de två
REPOSITORIERNA; Software Architect invände och ville ha den i MANAGERN. Avgjort på mätning,
inte omröstning: bägge gränssnittens dokumentation säger redan att rå `{id, data}` returneras
just för att exportkedjan ska forma det, och `firebase_comments_repository.dart` är 479 rader
utan rad i `ACCEPTED_LARGE_FILES.md` (en projektion där spränger 500-radersvakten) medan
`firebase_ratings_repository.dart` redan är 536 mot en rad som säger 507. Risken som
motiverade repositoriet — en framtida andra anropare — täcks i stället av skyldigheten som nu
står i båda gränssnitten och av det skrivardrivna drifttestet. Skrivet i avvikelseposten.

**Villkor som ÄNDRADE bygget** (alltså inte bara bekräftade det):
- T&S mätte ett FJÄRDE läckfält på kommentaren, `reactions` — en karta emoji -> andras uid:n,
  som planen inte kände till. Med i strykbeslutet, och restposten namngiven.
- T&S mätte att det TREDJE testet i `block_enforcement_test.dart` är VAKUÖST: det byggde en
  `SocialCommentsManager`, anropade den aldrig, och asserterade på ett `where(...)` det
  skrivit om själv. Omskrivet till att driva den riktiga managern via `refreshComments`,
  med en kontrollarm. Mutationsprovat.
- Data Analyst mätte att `AppLogger.warning` INTE når Crashlytics eller något analysaggregat,
  bara utvecklarkonsolen. Så meningen "makes a spike visible in observability" i
  `quantity_parser.dart` var falsk och ströks; ingen ny kommentar påstår observerbarhet.
- PM, Legal och DPO landade oberoende på att `sharedWithUserIds` INTE ska gå till Malin som
  öppen fråga utan avgöras här. Gjort: struket, med eget skäl.
- Legal och DPO mätte att `authorAvatarUrl` saknades i BÅDA listorna, alltså skulle ha
  fallit bort tyst — och det är begärandens EGEN avatar. Nu uttryckligen BEHÅLLEN.
- Security Architect krävde `recipeOwnerId` som uttryckt strykning på BETYG. Hans radnummer
  var fel (rad 116 är `validateUpdatePermission`), men sakfrågan höll: `RecipeRating.toFirestore`
  emitterar fältet när det är satt. Struket som beslut, inte som frånvaro.
- Security + DPO krävde ett SKRIVARDRIVET drifttest utöver fail-closed-testet. Byggt.
- Legal, DPO och Security krävde att `data_minimisation`-meningen ligger på FELGRENEN också,
  byte-identisk. Byggt och pinnat.
- Vendor mätte att `functions/scripts/run-all-tests.js` redan löser BUT-2065:s form utan
  beroenden. Följt: noll nya npm-beroenden.
- Performance krävde att testet asserterar EN prenumeration och EN timer, inte "kraschar
  inte". Gjort via anropsräkning på repositoriet.

## Slutstatus

| Ärende | Utfall | Vad som gjordes |
| -- | -- | -- |
| BUT-2069 | klart | telemetrianropet av utfallsvägen, som `blockUser` |
| BUT-2070 | klart | skip borttaget, verklig orsak lagad, vakuöst tredje test omskrivet |
| BUT-2067 | klart | producenterna delar EN finitetskontroll |
| BUT-2063 | klart | `startMonitoring()` idempotent, `stopMonitoring()` nollar |
| BUT-2062 | klart | fail-closed projektion + beslut daterat i båda filerna |
| BUT-2059 | klart | delmängdstest reglerna -> exporten, skrivet ur källan |
| BUT-2065 | klart | `&&`-kedjan ersatt av en insamlande körare |

## Deviation log
- [discovery] BUT-2063: ärendet bad om att anroparna RÄKNAS. En enda i `lib/`, och den gjordes idempotent av BUT-2052 -> defekten är verklig men djupförsvar, inte en mätt batterikostnad. Står i koden, inte som fotnot.
- [deviation] BUT-2062: routern gav `single` vid urval och `full-panel` när `activity_export_manager.dart` kom med i unionen -> sex säten till sammankallades innan något byggdes där.
- [deviation] BUT-2062: Software Architect INVÄNDE mot lagerplaceringen -> avgjort på 500-radersvakten och gränssnittens egen dokumentation, inte på röstetal. Skrivet i avvikelseposten.
- [discovery] BUT-2070: skip-skälet var mycket riktigt inaktuellt, men testet föll ändå. Orsaken var fixturens halvt inloggade auth-attrapp (`currentUserId` svarar, `currentUser` är null), så tillståndshanteraren aldrig prenumererade på `watchBlockedUserIds()`. Produktionen var korrekt.
- [discovery] BUT-2070: min egen kommentar påstod att testet pinnar BUT-2022:s skrivordning. Det gör det inte — block-först och städning-först ger samma sluttillstånd på lyckliga vägen. Meningen omskriven till vad testet mäter, med pekare till gruppen som faktiskt pinnar ordningen.
- [discovery] BUT-2059: `_knowinglyUncovered`-posten går INTE att ta bort. Folkräkningen är ett antal över varje `keys().hasOnly`-block plus listans ankare, så en borttagen rad rödnar folkräkningen. Posten står kvar med omskriven text som säger vad den nu jämförs mot.
- [deviation] BUT-2065: autoupptäckt av `test:rules:*`-skript hade tappat NIO sviter (åtta integrationstester plus `analyze-corrections-alias`) — mätt, inte antaget. Listan ligger kvar i `package.json`, också för att `check-test-registration.js` läser filerna ur just den strängen.
- [discovery] BUT-2065: min egen körare räknade `suites.length - failed.length`, vilket rapporterar "2/3 passed" när två aldrig startade. Mutationssonden fångade det. Räknas nu per körning.
- [deviation] Två redigeringar genom Python-heredoc tappade Dart-escapes (`'` blev `'`) och gav kompileringsfel — samma fälla lärdomsfilen redan beskriver, två gånger på en kväll.

---

# ARKIV — tidigare sprintar

# Sprint 2026-09-10 — fem ärenden, tre kluster

Vald av `/delivery:sprint-execute`.

**Router, batchens filunion vid urval** (11 sökvägar) -> **`full-panel`**, 14 roller.
**Router, filunionen SOM DELAS UT** (10 sökvägar, BUT-2057 utplockat) -> **`single`**,
panel `["Data / Integrations Engineer", "Data / ML Engineer", "Financial Controller / FinOps",
"Monetization / Subscriptions Lead"]`, `high_stakes_hits: []`.
Unionen KRYMPTE mellan urval och utdelning, precis den riktning regeln finns för. Panelen om
14 roller hann köras på den STÖRRE unionen och gäller alltså med marginal.

Panelutfall: 14 säten, 11 agenter, **noll invändningar** — 3 `approve`, 11 `approve-with-conditions`.
Villkoren är infällda som acceptanskriterier nedan, märkta med rollen som ställde dem.

## BUT-2057 UTPLOCKAT vid steg 0 — den föreslagna fixen går inte att bygga

Defekten är verklig; åtgärden ärendet föreskriver (`hasRequiredFields`) är det inte. Mätt mot HEAD:

- `FirebaseRatingsRepository.rateRecipe` (`lib/repositories/firebase/firebase_ratings_repository.dart:135-180`)
  skriver **aldrig** `recipeOwnerId`. Ingen Cloud Function heller. Ett obligatoriskt fält på
  `recipe_ratings` nekar **varje betygsättning i appen**.
- `FirebaseCommentsRepository:220` skriver fältet bara när `FirebaseRecipeOwnershipResolver.resolve()`
  svarar, och den returnerar `null` med flit på tre vägar (recept saknas / ingen upplösbar ägare /
  uppslaget kastar) — filens egen text kallar det "degrade to author-only read".

Bekräftat oberoende av Security Architect och DBA, som inte såg varandras svar. Åtgärden kräver
dels en mekanisk del (stämpla fältet i `rateRecipe`), dels ett beslut om vad en användare ser när
ägaren inte går att lösa upp — Malins, inte mitt. Kommenterat på ärendet, står kvar i Backlog.

---

## Kluster A — saneraren (ETT bygge, två ärenden)

### [Tier C] BUT-2037 — teckenkodat `+` raderas av saneraren (Medium, Bug)
### [Tier C] BUT-2034 — undantaget luras av mellanslag/snedstreck i annat attributs värde (High, security, Bug)

Disposition: **build** (korrekthetsfix, inget produktval — bekräftat av PM-sätet).

**Vald ansats, MÄTT och inte antagen.** Software Architect-sätet prissatte parser-vägen som dyr
(andra helparsning + spanmappning). Den prissättningen gäller en annan konstruktion än den här:
`preserveWhen` tar emot **öppningstaggen ensam**, inte dokumentet. En `parseFragment` på just den
strängen kostar ingen spanmappning och ingen dokumentparsning.

Kört mot 12 fall (`html_parser.parseFragment(openingTag).querySelector('script')?.attributes['type']`):

    <script type="application/ld+json">                ==> application/ld+json
    <script type="application/ld&#x2b;json">           ==> application/ld+json
    <script type="application/ld&plus;json">           ==> application/ld+json
    <script type="application/ld&#x2bjson">            ==> application/ld+json
    <script type="application/ld&#043json">            ==> application/ld+json
    <script type="application/ld+json; charset=utf-8"> ==> application/ld+json; charset=utf-8
    <script data-cfg=" type=application/ld+json">      ==> null
    <script data-cfg="text/type=application/ld+json">  ==> null
    <script data-type="application/ld+json">           ==> null
    <script type="application/ld&plusjson">            ==> application/ld&plusjson
    <script>                                           ==> null
    <script type=application/ld+json>                  ==> application/ld+json

Alla fem BUT-2037-förlustfallen bevaras, båda BUT-2034-kringgåendena faller, `; charset=utf-8`
och `&plusjson`-gränsen är oförändrade. Så `jsonLdScriptOpeningTagPattern` UTGÅR och ersätts av
EN delad funktion över `isJsonLdMediaType` — vilket också upplöser BUT-2034:s punkt 2 (två kopior
av ett regex som kan driva isär), eftersom det inte längre finns något regex att kopiera.

Acceptanskriterier:
- [ ] `{text: "En delad funktion i recipe_scraper.dart avgor JSON-LD-het pa den PARSADE oppningstaggen via isJsonLdMediaType, och jsonLdScriptOpeningTagPattern finns inte kvar", kind: diff}`
- [x] `{text: "Alla tre konsumenterna avgor JSON-LD-het genom isJsonLdMediaType: de tva sanitizer-halvorna via isJsonLdScriptOpeningTag, och url_import_strategy.hasOnlyNonRecipeJsonLd direkt pa den parsade DOM:en (Data/ML + Integrations + SW Architect: den tredje var oraknad i forsta planen)", kind: diff}`
- [ ] `{text: "Bada BUT-2034-kringgaendena STRYKS av sanitize() OCH check() ger samma svar", kind: diff}`
- [ ] `{text: "Alla fem BUT-2037-forlustfallen BEVARAS av sanitize() OCH check() tiger om dem", kind: diff}`
- [ ] `{text: "Bada DEFECT-testerna RADERAS och ersatts av assertioner pa ratt beteende - testantalet minskar inte (QA)", kind: diff}`
- [ ] `{text: "isJsonLdMediaType-premissassertionen ur BUT-2037-testet overlever som fristaende test - dess egen reason-strang sager att sviten saknar annan pinne (QA)", kind: diff}`
- [ ] `{text: "De fyra decoys som bara ar pinnade pa sanitize-halvan far sin check()-motsvarighet, sa parheten ar 7 av 7 (Integrations)", kind: diff}`
- [ ] `{text: "_hasOnlyNonRecipeJsonLd far ett eget test over BUT-2037- och BUT-2034-fallen (Data/ML risk 3, SW Architect risk 2)", kind: diff}`
- [ ] `{text: "Bada OPEN-kommentarerna i recipe_scraper.dart tas bort; url_import_strategy.dart iff STRYKS, inte omformuleras", kind: diff}`
- [ ] `{text: "Omfangssatsen aterstalls explicit: ingen konsument renderar sanitize()-utdata som HTML, sa detta ar djupforsvar - inte en live-XSS (Security Architect, mot lessons.md)", kind: diff}`
- [ ] `{text: "De tva escalation-gates i _tryHtmlTextParse ar byte-identiska fore och efter (FinOps)", kind: diff}`
- [ ] `{text: "INTE gjort: web_scraper.dart och recipe_site_content_extractor.dart - eget arende", kind: diff}`

---

## Kluster B — blockering

### [Tier B] BUT-2022 — blockeringen är inte atomär, och vakterna failar öppet (High, Bug)
Disposition: **build-review**. Malin avgjorde formen 2026-09-05 (båda halvorna i ett bygge).
PM-sätet flaggar att copyn för ett DELVIS utfall inte omfattas av det beslutet — den detaljen är
hennes, så ärendet parkeras i In Review oavsett vad grindarna säger.

Acceptanskriterier:
- [ ] `{text: "blocks-raden skrivs FORST i blockUser; vanskap och forfragningar stadas efterat", kind: diff}`
- [ ] `{text: "blockUser returvarde harleds ur BLOCKS-skrivningens utfall, inte ur det sista steget (Legal must-have 2, T&S must-have 1)", kind: diff}`
- [ ] `{text: "FirebaseBlockRepository.blockUser ar OMFORSOKSSAKER: set() mot ett befintligt dokument gar pa update-limben, som ar allow update: if false - en redan skriven blockering ska rakna som lyckad, inte som permission-denied (DBA must-have 3, matt i firestore.rules:2578)", kind: diff}`
- [ ] `{text: "removeFriend returvarde kastas inte bort", kind: diff}`
- [ ] `{text: "FriendsViewModel far EN ny publik isBlocked-yta, och FYRA anropsstallen gar genom den: chat_action_handler.dart, block_group_member_dialog.dart, search_result_card.dart, friend_profile_view.dart. Noll direkta _friendsService-anrop fran widget- eller view-filer (SW Architect must-have 2; T&S hittade det fjarde stallet, som saknades i forsta planen)", kind: diff}`
- [ ] `{text: "En kommentar pa BADA sidor namnger att getFriendshipStatus prioritetsordning och den direkta blockeringskontrollen med FLIT ger olika svar (SW Architect risk 3)", kind: diff}`
- [ ] `{text: "Ingen anvandarsynlig text pastar att blockeringen ar klar pa en vag dar blocks-raden inte skrevs (Legal must-have 1)", kind: diff}`
- [ ] `{text: "Test som fejkar fel i vart och ett av de tre stegen, med ordningskansliga assertioner (verifyInOrder), inte bara anropsrakning - och mutationsprovat genom att aterstalla ordningen (QA must-have 3)", kind: diff}`
- [ ] `{text: "blockUsers-bulkslingans rakning speglar fortfarande blocks-raden, inte allt-lyckades (T&S risk 3)", kind: diff}`
- [ ] `{text: "INTE gjort: getFriendshipStatus egen ordning andras inte - den har fler anropare", kind: diff}`

---

## Kluster C — Dart, låg risk

### [Tier A] BUT-2053 — `personal_shopping_operations` skriver Infinity i mängdfältet (Medium, Bug)
- [ ] `{text: "Bada tryParse-stallena i personal_shopping_operations har en finitetskontroll med samma 1.0-fallback som resten av metoden", kind: diff}`
- [ ] `{text: "Test for 309 siffror (Infinity -> 1.0) och 308 (andligt, oforandrat)", kind: diff}`
- [ ] `{text: "Mutationsprovat rott", kind: diff}`

### [Tier A] BUT-2052 — connectivity-lyssnaren registreras flera gånger, avregistreras en (Medium, Bug)
- [ ] `{text: "addListener forekommer pa EXAKT ett stalle i objektets livstid - inte inuti metoden som kors om vid varje reconnect (SW Architect must-have 3)", kind: diff}`
- [ ] `{text: "Kontrollerat och skrivet: startMonitoring() ar idempotent och billig, eller sa flyttas den inte med (SW Architect risk 1) - matt, inte antaget", kind: diff}`
- [ ] `{text: "Ett test som pinnar enable -> reconnect -> reconnect -> dispose med verify(...).called(n) i bada riktningarna", kind: diff}`
- [ ] `{text: "Mutationsprovat rott", kind: diff}`
- [ ] `{text: "INTE gjort: DisposalGuardMixin-vakten fran BUT-2015 tas inte bort", kind: diff}`

---

## Needs you (Tier D) — inget den här sprinten

## Följdärenden att fila före commit
- BUT-2057 omplanerad (kommenterad, står kvar i Backlog).
- DPO: `exportCommentsByAuthor` / `exportRatingsByUser` returnerar rå `doc.data()` utan
  allowlist — eget ärende, oberoende av BUT-2057.
- Data/ML: korpus-evalen (`tools/corpus_eval.dart`) körs i ingen CI-lane, så ingen mätning
  fångar en importregression — eget ärende.
- QA: `test:rules:all` är en `&&`-kedja; en tidig svit som rödnar hoppar tyst över senare.

## Ej valda, med skäl
- **BUT-2045** — Tier D, kräver skarp projektåtkomst.
- **BUT-2027** (getUserProfiles) — Malin-beslutad men rör tio anropare; egen sprint.
- **BUT-2017**, **BUT-1996**, **BUT-1730** — för stora för en delad batch.
- `need-malin`-märkta ärenden — står i beslutskön, inte i bygget.

## Slutstatus

| Ärende | Utfall | Commit |
| -- | -- | -- |
| BUT-2037 + BUT-2034 | **Done** | `3b8bb2433` |
| BUT-2053 + BUT-2052 | **Done** | `95d74a727` |
| BUT-2022 | **In Review** — copyn är Malins | `3e49ae340` |
| BUT-2057 | Utplockat vid steg 0, kommenterat, inget byggt | — |

Filade följdärenden: BUT-2062 (rå `doc.data()` i kommentars-/betygsexporten),
BUT-2063 (`startMonitoring` inte idempotent), BUT-2064 (korpus-evalen i ingen CI-lane),
BUT-2065 (`test:rules:all` som `&&`-kedja), BUT-2066 (`check()` på fientlig storsida),
BUT-2067 (fjärde Infinity-producenten), BUT-2068 (auto mode mot granskningsliggaren),
BUT-2069 (`unblockUser` + återhämtningsfrågan), BUT-2070 (skippad blockeringskaskad).
Plus en mätning på BUT-2061 om skalfelet i commit-grinden.

## Deviation log
- [discovery] BUT-2057: planen sa `hasRequiredFields` -> mätt att två legitima skrivvägar utelämnar fältet (ratings alltid, comments på resolver-null) -> utplockat ur sprinten, kommenterat, inget byggt.
- [discovery] BUT-2022: planen namngav tre vakter -> T&S och Legal mätte en fjärde (`search_result_card.dart`) och en femte (`friend_profile_view.dart`) -> alla fyra call sites som gatar blockeringsbeteende tas med.
- [discovery] Kluster A: SW Architect prissatte parser-vägen som dyr -> mätt att `preserveWhen` får öppningstaggen ensam, så `parseFragment` på den räcker -> parser-vägen vald, regexet utgår.
- [discovery] Kluster A, granskningsrunda 1: jag skrev till granskarna att "alla tre konsumenterna anropar isJsonLdScriptOpeningTag". Falskt — den tredje anropar `isJsonLdMediaType` direkt. `code-reviewer` mätte det. Acceptanskriteriet ovan är omskrivet till vad koden gör.
- [deviation] Kluster A, granskningsrunda 1: `integration-reviewer` mätte att `preserveWhen` fick en GEMENAGJORD öppningstagg, och att HTML:s namngivna teckenreferenser är skiftlägeskänsliga — så `&PLUS;` (som inte löses upp) blev `&plus;` (som gör det) och ett skript med `alert(1)` BEVARADES. En regression jag införde i samma commit som stänger BUT-2034. Reproducerad, lagad (originalversalerna skickas nu), och pinnad som decoy 13.
- [discovery] Kluster A, mätt av `integration-reviewer`: `check()` kostar nu en fragmentparsning per `<script>` som bär `type`. På en fientlig 4MB-sida med `<script type="text/javascript">` tar loopen ~530 ms mot ~9 ms för det raderade regexet; med bara `src=` är den 18 ms, alltså gör snabbvägen sitt jobb. Verkliga sidor har tiotals skript, så det är submillisekund i praktiken. Det som binder det fientliga fallet är 5MB-spärren i `check()` — den ligger i en ANNAN fil än predikatet vars kostnad den bundit, och det är därför det står här.
- [discovery] Kluster A, granskningsrunda 3: min egen mutationssond muterade TYST INGENTING — ankarsträngen bar ett bakstreck-b som Python läste som ett backsteg, så `count(old)==1` föll och körningen jag fick tillbaka var av omuterad kod. Exakt samma fälla som `integration-reviewer` dokumenterade om sin egen sond en runda tidigare. Assertionen fångade det; utan den hade ett grönt "provet är opinnat"-svar sett identiskt ut.
- [deviation] Kluster B: två grindar HÄNGDE sig, båda på min överlastning (20 filer till en som behövde 1; 7 sonder till en annan). Statusen sa `running` båda gångerna. Mätt i stället: processminne, skrivningar under `.dart_tool`, och om `lib/` är muterad. Orsak bakom den ena filad som BUT-2068.
- [deviation] Kluster B: min egen sond siktade på fel lager (produktionens `isBlocked` under tester som ersätter just den metoden) och gav ett grönt svar som hade lästs som "redan täckt". Rätt mutant var vaktens anropsställe.
- [discovery] Kluster B: tre av fyra vakttest var gröna på en återställning till den trasiga läsningen — riggen satte båda läsvägarna till "blockerad". Hittat av test-grinden genom att läsa attrappens seeder.
- [discovery] Kluster B: push-grinden nekade första pushen — fem granskningsrundor men ingen ENSKILD helhetsgranskning över alla filer i slutgiltigt skick. Kördes och godkändes.

---

# ARKIV — tidigare sprintar

# Sprint 2026-09-09 — sex ärenden, två kluster

Vald av `/delivery:sprint-execute`. Router på batchens filunion:
`python tools/stakeholder_router.py --json <10 paths>` -> **`full-panel`**, panel om 10 roller,
high_stakes_hits: `firestore.rules`, `account-deletion-cascade.ts`, `chat_group_export.dart`.
`panelPolicy: park` — allt i kluster A och BUT-2014 landar i In Review, inte Done.

---

## Kluster A — backend / regler / Cloud Functions

### [Tier C] BUT-2005 — barnsäkerhetsvräkningen kapar inte menyåtkomsten (High, security)
Disposition: **build**. Premiss kontrollerad mot main: `cutGroupMenuPlanAccess` har exakt ETT
anropsställe (`groups/remove-chat-group-member.ts:267`) och är privat i den filen.

Acceptanskriterier:
- [ ] `{text: "cutGroupMenuPlanAccess ligger i en delad modul och anropas fran alla vagar som tar bort ett uid ur en gruppchatts medlemslista", kind: diff}`
- [ ] `{text: "Vagarna ar UPPRAKNADE genom grep, inte antagna: varje stalle som skriver bort en medlem ar listat i planen med fil och rad innan wiringen skrivs", kind: diff}`
- [ ] `{text: "Radera-sista-veckan och befordra-lagsta-uid foljer med till de nya anropsplatserna, och det ar medvetet - ett test per ny anropsplats", kind: diff}`
- [ ] `{text: "INTE gjort: ingen ny rules-yta, ingen andring av vad cutGroupMenuPlanAccess sjalv gor", kind: diff}`

### [Tier C] BUT-2038 — `ingredient_suggestions` create-limb är obegränsad (Medium, backend)
Disposition: **build**. Premiss kontrollerad: `firestore.rules:3310-3313` har varken `hasOnly`,
storleksgräns eller `rateLimitWrite`; `rateLimitWrite` finns som hjälpare på rad 203.

Acceptanskriterier:
- [ ] `{text: "create-limben har hasOnly over den deklarerade typens falt, rateLimitWrite, och ett tak pa dokumentets falt", kind: diff}`
- [ ] `{text: "De tva tillat-fixturerna i ingredient-suggestions-rules.test.ts som skickar status blir roda och skrivs om - de aterstalls INTE", kind: diff}`
- [ ] `{text: "allow create: if false aterupptas INTE (BUT-2028, avgjort)", kind: diff}`
- [ ] `{text: "deleteIngredientSuggestions obundna .get() far ett tak i samma form som MAX_BLOCK_SWEEP_ROWS", kind: diff}`

---

## Kluster B — Dart, låg risk (router matchade ingen roll på fyra av fem)

### [Tier A] BUT-2014 — exportens chattgruppsben skickar tom lista bredvid felkod (Medium)
Disposition: **build**. Premiss: `lib/services/account/export/chat_group_export.dart:59`.
- [ ] `{text: "Felgrenen returnerar felkoden UTAN chat_groups-nyckeln", kind: diff}`
- [ ] `{text: "social_export_manager_test.dart:s dubbelfelstest pinnar nyckelns FRANVARO - assertionen skrivs om, aterstalls inte", kind: diff}`
- [ ] `{text: "Mutationsprovad: aterinfor tomma listan, testet blir rott", kind: diff}`

### [Tier A] BUT-1943 — `QuantityParser.parse` saknar finitetskontroll (Medium)
Premiss: ingen `isFinite` i `lib/utils/text/quantity_parser.dart`; `parsed < 0` fångar ej +Infinity.
- [ ] `{text: "isFinite-kontroll i QuantityParser.parse, faller tillbaka pa samma 1.0 som ovrig ogiltig indata", kind: diff}`
- [ ] `{text: "Test for 309 nior (Infinity) och 308 (andligt, oforandrat)", kind: diff}`

### [Tier A] BUT-2015 — två managers kan nå en avyttrad notifierare (Low)
Premiss: ingen `_isDisposed` i någon av de två filerna.
- [ ] `{text: "Bada managers har _isDisposed, isDisposed-getter och overskuggad notifyListeners som returnerar tidigt", kind: diff}`
- [ ] `{text: "Minst ett AKTA async-test: avyttra medan ett await ar i flykt via Completer", kind: diff}`
- [ ] `{text: "Mutationsprovat rott", kind: diff}`
- [ ] `{text: "Kommentaren sager vilken sats som nar - managerns egen finally eller foralderns fortsattning - mott, inte antaget", kind: diff}`

### [Tier A] BUT-2025 — två småfel från BUT-1917:s granskning (Low)
- [ ] `{text: "Blockeringsfixturerna skriver blockedAt (produktionens falt), inte createdAt", kind: diff}`
- [ ] `{text: "chat_action_handler._showErrorSnackBar gar genom SnackBarUtils", kind: diff}`

---


---

## Fas 1.4 — panelens bindande villkor (10 roller, alla blinda)

Loggas i `docs/org/metrics/events.jsonl`. Två fynd ANDRAR omfattningen:

### A. BUT-2038: `rateLimitWrite` byggs INTE, och det ar ett matt beslut
`Security Architect` och `DBA` fann oberoende att `rateLimitWrite('...', N)` bara LASER
`users/{uid}/rate_limits/{type}`. Ingen kod i `lib/` skapar ett `ingredient_suggestions`-forslag,
alltsa finns ingen skrivare som stamplar hinken — regeln skulle bli en INERT kontroll som laser
som en fix. Samma permanent tomma limiter som repot redan dokumenterar for
`rateLimitWrite('conversations', 10)`. Byggs: `hasOnly`, ett vardekrav pa `status`,
`originalName`-taket, och raderingstaket. Rate limit-halvan filas som eget arende.

### B. BUT-2014: `Legal Counsel` sa att premissen ar inaktuell. MATT, och den haller.
Legal: BUT-1862 lyfte redan ut felkoden till `chat_groups_error_code`, "no new fix needed".
Matt i `lib/services/account/data_export_service.dart:363` — varningsbyggaren laser ENBART
`value['error']` / `value['error_code']` i sektionens ROT. `chat_groups_error_code` ar en
kropps-nyckel och nas aldrig av den. Vid dubbelfel blir det alltsa exakt EN varning, som namner
konversationsfelet, medan `chat_groups: []` star kvar och laser som ett fullstandigt svar.
Premissen haller. En granskares matning ar lika falsifierbar som en kommentar.

### Bindande villkor, per arende

**BUT-2005** (T&S, DPO, Security, DBA, Legal, PM, Support — konvergerade)
- [ ] `{text: "Anropet sker UTANFOR varje db.runTransaction pa bada nya anropsstallen", kind: diff}`
- [ ] `{text: "Signaturen tar uids: string[] och gor EN skanning plus EN uppdatering per plandokument for alla avgaende uid tillsammans - inte ett anrop per uid i en fan-out-loop", kind: diff}`
- [ ] `{text: "Identifieraren som skickas ar conversationId, inte chat_groups-dokumentets id - group_weekly_menu_plans.groupId lagrar konversationens id. Pinnat av ett test, inte antaget", kind: diff}`
- [ ] `{text: "actorId ar uttryckligt beslutat per anropsstalle: kategorisynken skickar callerUid (den som faktiskt andrade rostern), barnsakerhetsvrakningen en systemsentinel - ingen manniska tillskrivs en automatisk atgard", kind: diff}`
- [ ] `{text: "Inget nytt falt, ingen systemrad och ingen tombstone som later en lasare harleda ATT nagon vrakts som minderarig (BUT-1856)", kind: diff}`
- [ ] `{text: "Avvikelseposten uppdateras till DELVIS stangning och namner vad som fortfarande ar oppet - den skrivs INTE om till att alla vagar ar fixade", kind: diff}`

**BUT-2038** (Security, DBA, DPO)
- [ ] `{text: "hasOnly listar exakt de fem klientskrivna falten: userId, ingredientName, originalName, status, createdAt - reviewedBy/reviewNotes ligger UTANFOR (Admin SDK forbigar regler)", kind: diff}`
- [ ] `{text: "status maste vara 'pending' vid create - hasOnly ensamt stoppar inte en forfalskad approved", kind: diff}`
- [ ] `{text: "originalName far samma <= 100-tak som ingredientName redan har", kind: diff}`
- [ ] `{text: "deleteIngredientSuggestions AVBOJER over taket (.limit(CAP+1), logga ERROR, return false) - aldrig en trunkerad radering", kind: diff}`
- [ ] `{text: "Sonden pa rad ~213 forblir OBEGRANSAD, sa ett over-taket-fall rapporterar gdprCompliant: false", kind: diff}`
- [ ] `{text: "En regelkommentar sager att en framtida skrivare sjalv maste stampla rate-limit-hinken - annars ar limitern inert (BUT-1482-precedenset)", kind: diff}`
- [ ] `{text: "Regeltest for varje ny konjunkt. De tva grona tillat-fixturerna som skickar status blir roda och skrivs om", kind: diff}`

**BUT-2014** (DPO)
- [ ] `{text: "chat_group_export_test.dart:262 skrivs om fran isEmpty till containsKey == false - inte bara manager-testet", kind: diff}`
- [ ] `{text: "social_export_manager.dart addAll av en karta UTAN nyckeln pinnas som en no-op", kind: diff}`

**BUT-1943** (PM)
- [ ] `{text: "Aven unicode-brakgrenen (rad 113-115) tacks - den har ett eget double.tryParse och en egen retur som ingen isFinite-kontroll pa rad 121 nar", kind: diff}`

**BUT-2015** (Software Architect - avvaktar)
**BUT-2025** (Support)
- [ ] `{text: "SnackBarUtils-stilen matchar ovriga felytor", kind: diff}`

### Skickas till Malin (Legal, punkt d) — beslutas INTE har
- Ska redan vrakta minderariga backfillas? (framatriktad fix, som repots ovriga kaskadfixar)
- Rate limit-halvan av BUT-2038 som eget arende: ja/nej.


## Needs you (Tier D)
Inga i denna batch.

## Deviation log

- [deviation] BUT-2038: planen sa `rateLimitWrite` -> tva grindar matte att den bara LASER en
  hink ingen skrivare stamplar (ingen kod i `lib/` skapar ett forslag) -> byggs INTE; en inert
  kontroll som laser som en fix ar samre an ingen. Ovriga tre skydd star kvar. Klustret hann
  inte byggas.
- [deviation] Fyra sma arenden committades i tre batchar i stallet for en, for att halla
  <=3 lib-dart-filer per grind (batchAdvisory).
- [discovery] BUT-2014: en panelgranskare sa att premissen var inaktuell (BUT-1862 skulle redan
  ha lagat den). Matt i `data_export_service.dart:363` -> varningsbyggaren laser bara sektionens
  ROT, sa kroppsnyckeln nadde ingen varning. Premissen holl. En granskares matning ar lika
  falsifierbar som en kommentar.
- [discovery] BUT-2015: omdirigeringen av felmeddelandet HALKADE ett befintligt test som anvande
  fargen som armdiskriminator. Bara helhetsgranskningen kunde se det. Ersatt med en raknare.
- [discovery] BUT-1943/BUT-2025: en STRYKNING gjorde tva meningar falska genom att ta bort den
  sats som avgransade dem. Lardom skriven, digest-rad i samma edit.
- [needs-human] BUT-2005 + BUT-2038 byggdes inte. Panelens 13 bindande villkor star i det har
  dokumentet och ar arbete som inte behover goras om.

## Post-sprint
- Fyll i utfallsbetyg per kriterium (Fas 2.7)
- Följdärenden i Linear före commit

---

# ARKIV — föregående plan

# Del B — legal hold vid öppet modereringsärende

Uppföljning på BUT-2032/BUT-2046. **Del A är byggd och deployad 2026-09-09** — antalet ingår i
artikel 15-exporten, regelblocket gatar på nyckeluppsättningen, migreringen körd skarpt. Se
`ACCEPTED_DEVIATIONS.md` för besluten; inget av det byggs om här.

Den här planen bygger hållet. Panelens tolv villkor (avsnitt 6) är specen, och avsnitt 3 säger
var varje villkor landar i kod.

---

## Öppna frågor

**En kvar, och den var Malins — nu besvarad.** Hållet kräver ett avsteg från BUT-781, som nollar
`contentOwnerId` på anmälningarna när den anmälda raderar sig.

**Malins beslut 2026-09-09: behåll uid:t medan hållet varar.** Hon fick se alternativen — nolla
ändå (då bevarar hållet bevis ingen kan koppla till en person, vilket T&S-sätet kallade teater)
och att inte bygga hållet alls (restrisken står namngiven, hon är ensam moderator och det finns
noll anmälningar i systemet). Uid:t nollas när hållet lyfts, genom samma funktion som i dag.

**Vad hon INTE fick se**, uttryckligen, eftersom en attribution är ett påstående om en person
som inget prov kan hålla: hon fick ingen mätning av hur länge ett verkligt ärende ligger öppet
(det finns noll anmälningar att mäta på), inte att hållet är enkelriktat (villkor H — en
ANMÄLARES radering tömmer ärendet ändå), och inte att `report_history`-radernas TTL var på väg
att äta beviset mitt i hållet. De två sista är byggets ansvar, inte hennes, och de är lösta
nedan.

Avsteget skrivs som en daterad post **i hennes namn** i båda avvikelsefilerna. Det var på väg att
skrivas som ett panelbeslut, vilket den fristående plangranskaren fällde: en avvikelsepost
skriven inuti den ändring den godkänner är inget fattat beslut.

**Inga arkitekturändrande okända kvar.** Antaganden bygget vilar på, uttryckligen:

- **Hålldokumentet bär OMFATTNINGEN; svepet räknar om ÖPPENHETEN.** Två meningar i planen sa
  emot varandra här (bullet 1 mot villkor J), och det är exakt den sortens tvetydighet som gör
  en mekanism obyggbar. Delningen: kaskaden avgör EN gång VILKA rader som hålls och skriver
  ner dem i `erasure_holds/{uid}` — det får aldrig härledas om, för underlaget ändras inte
  efter raderingen. Svepet frågar varje dygn om något ärende fortfarande är öppet, över ALLA
  ärenden mot personen (villkor J), och det MÅSTE räknas om, för det är just det som kan ha
  ändrats sedan i går.
- **Hållet ligger i en EGEN samling, `erasure_holds/{uid}` — inte som ett fält på
  `user_moderation/{uid}`.** Planen skrev först `erasureHold` dit, och det är exakt det
  scenario avvikelseposten från i går namnger som priset för `hasOnly(['totalReports',
  'lastReportedAt'])`: ett nytt fält gör hela dokumentet oläsbart för sin egen registrerade
  och får artikel 15-sektionen att falla stängt. Det är dessutom skarpt här och inte bara
  teoretiskt — hållet skrivs FÖRE `auth.deleteUser`, så en radering som avbryter efter det
  steget lämnar ett levande konto vars moderationssektion är trasig för alltid.
  `erasure_holds` får **inget block i `firestore.rules`**, vilket nekar varje klient (BUT-1957),
  och den enda läsaren är Admin SDK. Regelfilen, dart-projektionen och
  `rules_allowlist_drift_test.dart` är därmed helt utanför den här ändringen.
  Samlingen måste däremot in i raderingsregistren, annars larmar täckningsrapporten från
  BUT-2043 på den som obeslutad.
- **TTL:n på `report_history` går på ANMÄLNINGENS klocka, hållet på RADERINGENS.** Raderna
  bär `expireAt` = skrivtid + 180 dagar (mätt i `firestore.indexes.json`: `report_history` har
  en live TTL-policy), medan hållets yttre gräns är radering + 180 dagar. En anmälan som är en
  vecka gammal när kontot raderas åldras alltså ut mitt i hållet, och svepet skulle hitta ett
  håll som skyddar ingenting. Hållsteget skriver därför om `expireAt` till `holdUntil` på varje
  hållen rad, och svepet återställer den inte — raden dör då 180 dagar efter raderingen i
  stället för 180 dagar efter anmälan, vilket är hela poängen. Ingen annan hållen samling har
  TTL: `reports`, `system_events` och `user_moderation` saknar policy, mätt i samma fil.
- **Villkor C tvingar fram ett svep, så svepet gör också villkor J:s jobb.** J utgår från att
  städningen hänger på "stäng ärende"-händelsen och därför behöver en ny server-trigger. C
  kräver en tidsgräns oberoende av att någon stänger ärendet, alltså en tidsstyrd mekanism
  ändå. Svepet lyfter hållet både när sista ärendet stängts och när tiden gått ut, och J:s
  bindande halva är kvar: predikatet räknar om över ALLA öppna ärenden mot personen.
  **Priset är latens, och det är en GDPR-kostnad, inte bara en teknisk** — se avsnitt 7.

---

## 1. Fyrafältstestet för svepet (ny automation)

`.claude/rules/workflow-discipline.md` kräver det före bygget, med en namngiven utlösningsväg.

| Fråga | Svar |
|---|---|
| Upprepas ≥ veckovis? | Ja, dagligen. |
| Avvisar något dåligt utfall automatiskt? | Ja — svepet lyfter bara ett håll vars predikat är falskt (inget öppet ärende) eller vars tidsgräns passerats; annars rör det ingenting. |
| Går end-to-end utan människa mitt i? | Ja. |
| Är "klart" objektivt? | Ja — `erasure_holds/{uid}` raderat och det hållna underlaget borta. |

**Utlösningsväg:** `DAILY_ANALYTICS_TASKS` i
`functions/src/scheduled/maintenance-dispatchers.ts`, körd av `dailyAnalytics` (06:00 UTC).
**Först i listan**, inte sist — repot har redan betalat för att en tyst säkerhetskontroll hamnat
i svansen på en kedja som droppar tail-tasks under budgettryck.

**Namngivna svagheter, båda riktningarna:** kedjan kör `retryCount: 0`, så ett misslyckat svep
försöker inte igen förrän nästa dygn — acceptabelt mot en yttre gräns på 180 dagar. Och att lägga
svepet FÖRST har ett eget pris, som den tidigare versionen av det här stycket inte nämnde:
`runTaskChain` **avbryter kedjan** när en uppgift går över tiden (`maintenance-dispatchers.ts:135`
— `withTimeout` är ett `Promise.race` som inte avbryter det underliggande arbetet). Ett långsamt
svep tar alltså med sig alla tio analysjobben, varje dygn. Sist i kedjan var den andra risken
(tail-tasks droppas under budgettryck) och den är den som repot redan betalat för under en tyst
säkerhetskontroll.

Det som gör förstaplatsen försvarbar är **ett tak**: svepet läser högst
`MAX_ERASURE_HOLD_SWEEP_ROWS` håll per körning och **avböjer hellre än trunkerar** över det, precis
som `MAX_REPORT_HISTORY_SWEEP_ROWS`, `MAX_SYSTEM_EVENT_SWEEP_ROWS` och `MAX_ROSTER_SWEEP_ROWS` gör
i samma domän. Ett obundet svep i förstaposition är den kombination som skulle göra kedjeavbrottet
verkligt. Båda skrivs i avvikelseposten hellre än att upptäckas.

---

## 2. Vad hållet är

Hållet gäller när den raderade är `contentOwnerId` på minst en `reports`-rad med
`status != 'closed'` (villkor F). `ReportStatus` har fyra värden — `new`, `in_review`,
`actioned`, `closed` — och `actioned` läser som avslutat: moderatorn HAR agerat. Predikatet
räknar det ändå som öppet, och konsekvensen ska stå skriven i stället för underförstådd: ett
ärende där Malin agerat men inte tryckt "stäng" håller kvar underlaget tills hon stänger det
eller 180 dagar passerat. Det är den försiktiga riktningen och den är avsiktlig; alternativet
vore att ett halvstängt ärende tappar sitt underlag utan att någon beslutat det. Samma faktum
står nu på en **fjärde** plats (`ReportStatus`, `firestore.rules`, `report_service.dart`, hållet),
så predikatet ligger i EN funktion.

Under hållet bevaras:

- `user_moderation/{uid}` och dess `report_history`-rader (annars raderade), med `expireAt`
  framflyttad till `holdUntil` så TTL:n inte hinner före,
- `contentOwnerId` på anmälningarna om personen (annars nollat — **Malins avsteg från BUT-781**),
- `details.contentOwnerId` på de `system_events`-rader som hör till samma ärende. Kaskaden har en
  EGEN anonymisering av det fältet (`account-deletion-cascade.ts:3033`), skild från
  `anonymizeReportsByContentOwnerWithDb` som villkor G namnger, och planen missade den. Att hålla
  anmälan men nolla driftloggens motsvarighet vore ett halvhållet ärende: samma bevis, halva
  spåret. Båda hålls, båda nollas vid lyft.

Beslutet självt ligger i `erasure_holds/{uid}`, en egen samling utan regelblock. Se Öppna
frågor för varför det inte får bli ett fält på `user_moderation`.

Resten av kaskaden körs oförändrad. Hållet är det snävaste möjliga undantaget, inte en paus i
raderingen.

---

## 3. Bygget — villkor till kod

| Villkor | Var det landar |
|---|---|
| **A** eget fält, inte `gdprCompliant` | `DeletionResult.retained: RetainedRecord[]` i `account-deletion-cascade.ts`; `writeDeletionAuditLog` skriver `retained` bredvid `gdprCompliant`, som fortsatt bara drivs av `failedCollections` |
| **B** sonden får inte slå om flaggan | `probeResidualData` hoppar över de ben `result.retained` namnger — och bara då. **Tre ben, namngivna med sina loggetiketter, inte med samlingsnamn:** `residual own moderation rows` (personens egna `report_history`-rader), `residual moderation record` (föräldradokumentet) och `[SYSTEM_EVENTS, "details.contentOwnerId", "=="]`, vars egen kommentar säger att det är "the only thing that measures whether the ANONYMIZE half ran". Utan det tredje slår sonden om `gdprCompliant` permanent på varje hållen radering — precis felet A och B finns för att förhindra. **`residual report rows as reporter` hoppas ALDRIG över:** det benet är andra sidan av villkor H, och att tysta det skulle dölja ett verkligt misslyckande i `deleteReportHistoryByReporter`. Att säga "report_history" utan etikett träffar båda |
| **C** yttre tidsgräns | `erasure_holds/{uid}.holdUntil` = nu + `ERASURE_HOLD_MAX_DAYS` (ny exporterad konstant i `erasure-hold.ts`, 180), svepet i avsnitt 1. INTE `AUDIT_LOG_RETENTION_DAYS` — den är modulprivat i `request-account-deletion.ts` och betyder något annat (hur länge en auditrad sparas); två syften bakom ett tal är hur talet ändras för fel skäl |
| **D** artikel 12.4 i beskedet | dialogen i avsnitt 4 |
| **E** rättslig grund | `RetainedRecord.legalBasis` = 17.3(e) primärt, 17.3(b) sekundärt; ordagrant i dialogtexten |
| **F** predikatet | `hasOpenModerationCase()` i `functions/src/moderation/erasure-hold.ts` — EN implementation |
| **G** behåll uid:t | TVÅ anonymiserare, inte en: `anonymizeReportsByContentOwnerWithDb` (`cleanup/on-user-deleted.ts:972`) och kaskadens egen `system_events`-anonymisering (`account-deletion-cascade.ts:3033`). Båda hoppar över ägare med aktivt håll; svepet kör båda vid lyft |
| **H** hållet är enkelriktat | namngivet i avvikelseposten: `deleteUserReports`, anmälarbenet i `deleteModerationSystemEvents` och `deleteReportHistoryByReporter` har ingen statuskoll, så en ANMÄLARES radering tömmer ett öppet ärende ändå. **Uttryckligen utanför scope**, inte otänkt |
| **I** nytt index | **INGET nytt index, och ingen `firestore.indexes.json`-ändring.** Predikatet skrivs `where('contentOwnerId','==',uid).where('status','in',['new','in_review','actioned']).limit(1)` — ren likhet plus `in`, som Firestore behandlar som likhet, utan `orderBy`. En sådan fråga betjänas av enkelfältsindexen; det är klassen `reference_firestore_equality_index.md` registrerar som ett falskt positivt, och `reports` har inga `fieldOverrides` som stänger av dem. Ett bokstavligt `!=` HADE krävt ett sammansatt index, och det är den formen villkor I antog. Panelens villkor faller alltså på en mätning, inte på en bantning — och deployen blir en `--force`-körning kortare |
| **J** städning vid stängning | svepet, se Öppna frågor |
| **K** följdfiler | `docs/ops/moderation-runbook.md` (vad Malin ser när hon stänger ett ärende mot ett raderat konto), `docs/legal/privacy_policy_sv.md` **§ 6 Lagring och § 9 Dina rättigheter** — en dokumenterad vägran att radera hör hemma i rättighetsavsnittet, inte bara i lagringsavsnittet — och den engelska `privacy_policy.md` med samma två avsnitt. Rubrikerna är lästa, inte antagna |
| **L** undantag från husregeln | "raderaren är en äkta övermängd av sonden" gäller inte under ett håll — skrivs som ett uttryckligt undantag i `probeResidualData`:s egen kommentar och i avvikelseposten |
| **M** TTL:n får inte hinna före *(inte panelens villkor — fristående plangranskning 2026-09-09)* | hållsteget skriver `expireAt: holdUntil` på varje hållen `report_history`-rad; svepet återställer den inte |
| **N** hållet ligger utanför `user_moderation` *(samma granskning)* | `erasure_holds/{uid}`, inget regelblock |
| **O** rätt lista i återställningsregistret *(samma granskning)* | `erasure_holds` in i **`COLLECTIONS_TO_DELETE`** i `reset-collection-lists.ts` — inte `COLLECTIONS_DELIBERATELY_UNTOUCHED`, som är ett register utan tänder (samma fälla som `metrics` i BUT-2028). En återställningskörning raderar underlaget hållet skyddar, så ett håll som står kvar pekar på ingenting; det ska gå med. Alla tre listorna läses av BUT-2043-rapporten, så namnet räknas som beslutat oavsett vilken det står i — valet handlar om vad en körning GÖR, inte om att tysta rapporten |
| **Q** kvittot måste ta sig UT ur funktionen *(fjärde granskningen)* | `request-account-deletion.ts:350` returnerar en handskriven nyckellista (`success`, `deletedCollections`, `failedCollections`, `errors`, `auditLogId`). `retained` når ingen klient förrän den listan och `AccountDeletionService.deleteUserAccount`:s resultatkarta får fältet — hela avsnitt 4 hänger på det hoppet, och kaskadprovet ser det inte, för det kör inte den anropbara funktionens retur. Pinnas i `request-account-deletion.test.ts` |
| **P** kvittots form i Dart *(samma granskning)* | `ProfileViewModel.deleteAccount` returnerar i dag `bool` (rad 76) och kan inte bära `retained`. Ny modell `RetainedRecord` i `lib/models/account/`, parsad genom `SerializationUtils` som varje annan modell — ingen rå `Map`-läsning i vyn — och returtypen blir ett litet resultatobjekt i stället för en flagga |

**Filer som ändras:** `functions/src/moderation/erasure-hold.ts` (ny),
`account-deletion-cascade.ts`, `request-account-deletion.ts`, `cleanup/on-user-deleted.ts`,
`scheduled/maintenance-dispatchers.ts`,
`lib/models/account/retained_record.dart` (ny, villkor P),
`lib/services/account/account_deletion_service.dart`,
`lib/viewmodels/profile/profile_viewmodel.dart`,
`lib/widgets/common/profile/handlers/auth_action_handler.dart`,
`lib/widgets/common/profile/dialogs/profile_dialogs.dart`, `lib/l10n/app_sv.arb` +
`app_en.arb`, `functions/src/admin/reset-collection-lists.ts`,
`docs/legal/privacy_policy_sv.md` + `privacy_policy.md`,
`docs/ops/moderation-runbook.md`, plus prov
(`functions/src/__tests__/account-deletion-cascade.test.ts`,
`request-account-deletion.test.ts`, **`maintenance-dispatchers.test.ts`**,
`test/unit/widgets/profile/auth_action_handler_retained_test.dart`) och de två
avvikelsefilerna.

`maintenance-dispatchers.test.ts:96` påstår i dag att `DAILY_ANALYTICS_TASKS` innehåller
"exactly the ten merged daily jobs" och jämför hela listan ordagrant. Att lägga svepet FÖRST
rödar det provet — avsiktligt, det är precis vad en ordnad lista ska göra — och provets
förväntade lista uppdateras i samma ändring. `firestore.rules`, `firebase_data_export_repository.dart`
och `rules_allowlist_drift_test.dart` står medvetet INTE i listan; se villkor N.

**ADR-0015 superseders** med en daterad post: DSA artikel 23 gäller inte mikro-/småföretag, så
T&S-argumentets rättsliga halva föll; beslutet står på produktavvägningen ensam. ADR-0017 och
retirementen av "artikel 17 har inget undantag" är redan gjorda i `73e5caf38` — en decision
record superseders, skrivs aldrig om.

---

## 4. Beskedet i appen

**Var:** `auth_action_handler.dart`. I dag navigerar den lyckade vägen till `/auth` FÖRST
(`pushNamedAndRemoveUntil`, rad 107) och visar snackbaren EFTERÅT — inte tvärtom, som den här
planen först påstod. Ordningen spelar roll för den som bygger: en dialog som ska hinna läsas måste
`await`:as FÖRE navigeringen, annars rivs den med rutten. Är `retained` icke-tom visas alltså en
**dialog**, inväntad, före `pushNamedAndRemoveUntil` — sista ögonblicket något kan visas, eftersom
kontot är borta och det inte finns någon inloggad yta efteråt.

En snackbar duger inte: artikel 12.4 kräver vad som behållits, på vilken grund, hur länge, **och**
att personen kan klaga till IMY och begära rättslig prövning. Planens tidigare "kort, utan
juridikjargong" drog mot villkor D; det löses genom att snackbaren behålls för den vanliga
raderingen och den långa texten bara visas när något faktiskt behållits.

```
┌───────────────────────────────────────┐
│ Ditt konto är raderat                 │
├───────────────────────────────────────┤
│ En sak har sparats: en pågående       │
│ granskning av innehåll som anmälts.   │
│                                       │
│ Varför: vi måste kunna hantera        │
│ anmälningen färdigt.                  │
│                                       │
│ Hur länge: tills granskningen är klar,│
│ senast 180 dagar.                     │
│                                       │
│ Du kan klaga till IMY eller vända dig │
│ till domstol om du inte håller med.   │
├───────────────────────────────────────┤
│                            [ Stäng ]  │
└───────────────────────────────────────┘
```

Fyra strängar, **båda språkfilerna** (`app_sv.arb` och `app_en.arb`, matchande beskrivningar),
följt av `flutter gen-l10n`. ARB-hooken re-serialiserar hela filen, så `git diff` kan inte
attribuera ändringen — nyckelmängderna jämförs mot `git show HEAD:<fil>` före staging, och den
genererade filen grepas för den nya strängen efteråt (BUT-1783/1693).

Ingen ny vy, så preview-grinden är inte i spel — men det behövs en **ny metod** i
`profile_dialogs.dart` (146 rader, ingen storleksrisk). Filen används redan på felvägen i samma
metod, och den tidigare formuleringen "ingen ny widget behövs" vilade på det. Den enda
återanvändbara ingången där är `showErrorDialog`, som returnerar `void` — går inte att invänta,
och betyder dessutom "fel". Beskedet är varken ett fel eller något som får hoppas över, så det får
en egen `Future`-returnerande metod bredvid de tre som redan finns.

**Namngiven restrisk: beskedet är ETT tillfälle och går inte att få igen.** Kontot är borta när
dialogen visas, så det finns ingen inloggad yta kvar och ingen andra kanal — appen dödas,
läggs i bakgrunden eller tappar nätet i just det ögonblicket, och personen får aldrig sin
artikel 12.4-information. Ett mejl vore den enda återhämtningen, och e-postinfrastrukturen
finns inte (BUT-417). Skrivs i avvikelseposten hellre än att upptäckas.

---

## 5. Verifiering

**Cloud Functions** (`functions/src/__tests__/account-deletion-cascade.test.ts`, samma harness):

1. `scenario_openCaseHoldsTheModerationRecord` — öppet ärende ⇒ dokumentet och raderna står kvar,
   steget rapporterar sig KLART (inte failed), `retained` har en post.
2. `scenario_closedCaseDeletesAsBefore` — bara `closed`-ärenden ⇒ oförändrat beteende.
3. `scenario_heldRecordIsNotCountedAsResidual` — sonden slår inte om `gdprCompliant` (villkor B).
4. `scenario_holdKeepsContentOwnerIdOnReports` — anonymiseringen hoppar över hållna ägare (G).
5. `scenario_sweepLiftsWhenLastCaseCloses` och `scenario_sweepLiftsAtTheOuterCap` — svepet, båda
   vägarna, och att det räknar om över ALLA öppna ärenden (J). Båda assertar **tillståndet EFTER
   lyftet**, inte bara att lyftet skedde: `contentOwnerId` nollad på anmälningarna OCH på
   `system_events`-raderna, moderationsdokumentet och dess rader raderade, hålldokumentet borta.
   Det är den halva Malin faktiskt beslutade ("uid:t nollas när hållet lyfts"), och ett prov som
   bara ser lyftet lämnar den halvan opinnad.
6. `scenario_holdIsRecordedOnTheReceipt` — kvittot och auditraden bär `retained`, och
   `gdprCompliant` är fortsatt TRUE (A).
7. `scenario_holdPushesReportHistoryTtlForward` — varje hållen `report_history`-rad har
   `expireAt == holdUntil` efter kaskaden, och en rad som INTE hålls är orörd (M).
8. `scenario_holdDocumentLivesOutsideUserModeration` — hållet skrivs till `erasure_holds/{uid}`
   och kaskaden rör inte `user_moderation`-dokumentets nyckeluppsättning (N). Provet läser
   nycklarna, så det rödnar den dag någon flyttar tillbaka fältet.

**Orkestrering** (`request-account-deletion.test.ts`): den anropbara funktionens RETUR bär
`retained` (villkor Q) — det provet är det enda som ser hoppet ut ur funktionen. Dessutom heter
steget `applyErasureHold` och läggs till i stickprovslistan på rad ~319. Den listan är ett STICKPROV, inte ett fullständigt kuvert —
kommentaren ovanför säger det själv ("full list is in the source") — så ett nytt steg rödar
ingenting av sig självt, vilket är just därför det måste skrivas in för hand.

**Kedjan** (`maintenance-dispatchers.test.ts`): den ordagranna listjämförelsen på rad 96
uppdateras till elva jobb med svepet först. Provets NAMN säger "exactly the ten merged daily
jobs" och uppdateras i samma redigering — en siffra i en provrubrik ruttnar precis som en i en
kommentar. Samma redigering stryker siffran i `maintenance-dispatchers.ts:128` ("Nine of the ten
daily tasks write an idempotent, date-keyed doc"): ett elfte jobb gör den falsk, och svepet är
inte date-keyed, så meningen blir fel på två sätt samtidigt. Provet är den enda platsen som pinnar
ORDNINGEN, och ordningen är hela poängen med avsnitt 1.

**Index**: inget nytt prov, eftersom inget nytt index byggs (villkor I). Det befintliga
`scenario_reportHistoryIndexAndTtlAreDeclared` i samma fil pinnar redan TTL-policyn på
`report_history` och står kvar orört — villkor M ändrar radernas `expireAt`, aldrig policyn.

**Dart** (`test/unit/widgets/profile/auth_action_handler_retained_test.dart`, ny): dialogen visas
när `retained` är icke-tom och INTE annars (båda riktningarna, annars är provet en tautologi),
och de fyra strängarna finns i båda ARB-filerna.

**Allt mutationsprovas**, och sonderna körs FÖRE granskningsgrindarna dispatchas.

Kommandon: `npx tsc --noEmit`, `npm run test:account-deletion-cascade`,
`npm run test:request-account-deletion`, `npm run test:maintenance-dispatchers`, `dart analyze`,
`dart format --output=none --set-exit-if-changed`,
`flutter test test/unit/widgets/profile/auth_action_handler_retained_test.dart` plus de sviter
`grep -rl 'deleteAccount' test/` returnerar — returtypen ändras (villkor P), och en
signaturändring rödar stubbar i sviter man inte redigerat.

---

## 6. Panelens tolv villkor

*(oförändrade sedan 2026-09-08 — avsnitt 3 säger var var och en landar)*

- **A** Ett håll får inte uttryckas som `gdprCompliant: false`. *(DPO)*
- **B** `probeResidualData` skulle annars slå om flaggan permanent, utan kodväg som kan rätta den.
  *(arkeologen, mätt i koden)*
- **C** Yttre tidsgräns oberoende av att ärendet stängs. *(Legal, DPO, T&S)*
- **D** Beskedet bär artikel 12.4 — IMY och rättslig prövning. *(Legal, DPO)*
- **E** 17.3(e) primärt, 17.3(b) sekundärt. *(Legal)*
- **F** Predikatet är `status != 'closed'`. *(T&S, Legal, arkeologen)*
- **G** Behåll uid:t, inte en pseudonym. *(T&S)*
- **H** Hållet är enkelriktat. *(arkeologen, T&S)*
- **I** Nytt sammansatt index `(contentOwnerId, status)`. *(arkeologen)*
- **J** Städningen räknar om över alla öppna ärenden. *(arkeologen)*
- **K** Runbook och integritetspolicy. *(arkeologen)*
- **L** Uttryckligt undantag från "raderaren är en övermängd av sonden". *(arkeologen)*

---

## 7. Vad det betyder, i klartext

- Om någon anmälts och granskningen fortfarande pågår, försvinner inte underlaget bara för att
  personen raderar sitt konto. Resten av kontot raderas som vanligt — det här gäller bara
  anmälningen och räknaren som hör till den.
- Personen får veta det, i en ruta innan hen loggas ut: vad som sparats, varför, hur länge, och
  att hen kan klaga till IMY. Det är inget vi får göra tyst.
- Underlaget raderas när granskningen är klar — **i praktiken inom ett dygn efter att du stängt
  ärendet**, eftersom en daglig städning gör det, inte din knapptryckning. Och senast efter 180
  dagar oavsett, så ett ärende som blir liggande inte gör hållet permanent.
- **Ett ärende du "åtgärdat" men inte stängt räknas som öppet.** Underlaget ligger alltså kvar
  tills du trycker stäng. Försiktiga riktningen, men det betyder att stäng-knappen har en
  konsekvens den inte hade förut.
- Anmälningsraderna städas normalt bort 180 dagar efter att anmälan skrevs. Under ett håll
  flyttas den gränsen fram, annars hade städningen ätit upp beviset mitt i granskningen — en
  anmälan från förra månaden hade försvunnit långt före hållet gick ut.
- Beslutet om hållet lagras för sig, inte på moderationsdokumentet. Det låter tekniskt, men det
  är skillnaden mellan att artikel 15-exporten fungerar och att den slutar fungera för varje
  anmäld person.
- Två saker det här INTE gör: det hindrar inte en **anmälare** från att radera sig och ta
  anmälan med sig, och det hindrar dig inte från att stänga ett ärende och ångra dig.
