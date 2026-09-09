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
