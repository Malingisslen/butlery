# BUT-2032 — låt kontoraderingen nå `system_events`

Status: **plan klar och beslutad, inte byggd.** `tools/stakeholder_router.py` returnerar
`full-panel` (11 roller); fem säten med verklig stake + arkeologen har kritiserat blint och
parallellt. Villkoren ligger i avsnitt 11. **Malins tre beslut är fattade 2026-09-08** — anmälarens
rad raderas (ADR-0016), kapplöpningen är en namngiven restrisk (avsnitt 8), och raderna förblir
utanför artikel 15-exporten (avsnitt 9). Inget blockerar bygget.

---

## 1. Vad som är mätt i koden i dag (inte hämtat ur ärendetexten)

### 1.1 Vilka rader i `system_events` som faktiskt bär ett uid

`functions/src/feedback/on-report-created.ts` skriver **två olika radformer**, inte en:

| Radform | Dokument-id | Uid i fälten |
|---|---|---|
| `moderation_threshold_reached` | `moderation_threshold_<contentOwnerId>` — **uid i själva id:t** | `details.userId` = den anmälda |
| `content_report` | `content_report_<reportId>` — **inget uid** | `details.reporterId` = anmälaren, `details.contentOwnerId` = den anmälda (eller `null`) |

Ärendetexten räknar upp id:t och de tre fälten i en följd, som om de satt på samma rad. De gör
inte det, och det avgör designen: **ett raderingssteg som bara går på dokument-id:t missar
`content_report`-raderna helt — och det är just de som namnger anmälaren.**

En tredje radform bär ett **pseudonymt** uid: `middleware/rate_limiter.ts` skriver
`type: "rate_limit_violation"` med `userIdHash: hashUid(userId)`. `hashUid` är osaltad sha256
trunkerad till 12 hex-tecken (`functions/src/shared/hash-uid.ts`). Indata är ett Firebase-uid med
hög entropi, så hashen är inte uppräkningsbar på det sätt en IP-adress är — men den är en stabil
pseudonym som kan bekräftas mot ett känt uid, alltså persondata i GDPR:s mening.
**Utanför det här ärendets omfång, namngivet här i stället för att upptäckas senare.**
(Hittat av arkeologsätet; den första versionen av det här stycket påstod att övriga skrivare
saknade uid helt.)

`feedback_email_failed_<feedbackId>` pekar på en `feedback`-rad som kaskaden raderar — en
dinglande pekare efter radering, inte persondata.

### 1.2 Ingen raderingsväg rör samlingen

Mätt med grep över hela `functions/src`: varken `account/account-deletion-cascade.ts` eller
`cleanup/on-user-deleted.ts` nämner `system_events`. Inget sondben heller. Det enda som rör
samlingen är `admin/reset-collection-lists.ts`, som tömmer HELA samlingen vid en full miljöreset
— inte en artikel 17-väg för ett enskilt konto. Kommentaren ovanför den raden kallar det själv
"its own ticket". Arkeologsätet bekräftar att det aldrig gjorts ett tidigare försök: inga
commits på `BUT-2032`, och inget som någonsin kopplat ett kaskadben till samlingen.

### 1.3 Varför täckningsvakten inte fångade det

`scenario_everyCollectionIsDecided` frågar om varje samling står i någon av reset-skriptets tre
listor. `system_events` gör det. Vakten frågar **aldrig** om en samling som bär uid har ett
kaskadben. Hål-klass, inte enskilt misstag — se avsnitt 6.

### 1.4 Ingen läsare i det här repot returnerar de här raderna

Båda läsarna av `system_events` — `lib/repositories/ops_log_repository.dart` och `runOpsSnapshot`
i `analytics/daily-snapshots.ts` — filtrerar respektive sorterar på `executedAt`. De två
modereringsradformerna skriver `timestamp`. Moderatorvyn läser samlingen `reports`.

**T&S-sätets invändning, som håller:** det beviset säger bara att ingen kod i repot kastar om
raderna försvinner. Att en admin läser dem i Firebase-konsolen är en verklig förmåga, och
runbooken kallar dem uttryckligen "audit trail". "Ingen läsare returnerar dem" är alltså inte
samma påstående som "det är ofarligt att radera dem".

### 1.5 Moderkollektionen `reports` har redan två motsatta beslut

- Anmälaren raderar → `deleteUserReports` (kaskaden, tier 1) **hårdraderar** `reports`-raden.
- Den anmälda raderar → `anonymizeReportsByContentOwner` (`on-user-deleted.ts`, BUT-781)
  **behåller raden**, nollar `contentOwnerId`, sätter `contentOwnerAnonymizedAt`.

Två avgjorda beslut, inte drift. Planen härleder sin policy ur dem i stället för att uppfinna en
tredje policy för en härledd kopia av samma händelse.

---

## 2. Föreslagen policy

| Vem raderas | Radform | Åtgärd | Varför |
|---|---|---|---|
| Den **anmälda** | `moderation_threshold_<uid>` | **Radera dokumentet** | Uid:t *är* dokumentets identitet. Går inte att anonymisera. |
| Den **anmälda** | `content_report_*` med `details.contentOwnerId == uid` | `details.contentOwnerId → null` + `contentOwnerAnonymizedAt` | Exakt vad BUT-781 gör på moderraden. |
| **Anmälaren** | `content_report_*` med `details.reporterId == uid` | **Radera dokumentet.** Malins uttryckliga beslut 2026-09-08, mot T&S:s alternativ (ADR-0016). | Källraden i `reports` hårdraderas redan. En härledd kopia överlever inte sin källa. |

T&S:s villkor rider med på det beslutet: runbooken måste säga rakt ut att en anmälans spår
försvinner helt när anmälaren raderar sitt konto, så att en admin inte vilseleds av tystnaden.

Strike-räknaren (`user_moderation.totalReports`) påverkas inte. Efterlevnadstillståndet överlever;
det som försvinner är rader som **namnger** folk.

---

## 3. Var koden ska ligga — och varför inte i triggern

**I `account-deletion-cascade.ts`, tier 1. Inte i `on-user-deleted.ts`.**

`probeResidualData` körs **före** `auth.deleteUser(uid)`; triggern körs **efter**. Ett sondben
för något triggern städar gör varje sådan radering till `gdprCompliant: false` och
`success: false` — ett falskt misslyckande på en artikel 17-väg. Lärdomen från BUT-2044.

**Security-sätets skärpning, som ändrar planen:** BUT-781:s anonymisering ligger i triggern, där
den *får* en `stageCascadeAuditEntry`-rad. "Speglar BUT-781" gäller alltså åtgärden, inte
revisionsspåret — kaskaden har inga sådana anrop, triggern har dem på varje steg. Den första
versionen av det här stycket bar en siffra på hur många; den var fel och är struken.

**Följd:** planen accepterar inte längre den sänkningen. De nya stegen stagar sina egna
auditrader (villkor B, avsnitt 11).

---

## 4. Sonden — fällan som är lätt att gå i

`probeResidualData`:s `probes`-lista frågar `where("userId", "==", uid)` på **toppnivåfält**.
`system_events` har `details.userId`. Att lägga `"system_events"` i den listan ger **noll träffar
för alltid** — en frisksedel som är sann av misstag, `realtime_recipes`-fällan (BUT-1801).

Eget ben, fyra frågor:

1. `where("details.userId", "==", uid)`
2. `where("details.reporterId", "==", uid)`
3. `where("details.contentOwnerId", "==", uid)` — inte redundant: utan den mäter sonden aldrig att
   anonymiseringen körde.
4. `doc("moderation_threshold_" + uid).get()`

**Eget try/catch som räknar varje undantag som residual (fail closed)**, som `poll_votes`- och
`block_mirror`-benen. Ett svalt undantag här ger en falsk frisksedel på en artikel 17-väg.

Index: punktnotationslikhet på toppnivåsamling är etablerat i samma fil
(`metadata.subjectUserId`, `metadata.poll.creatorId`), och `firestore.indexes.json` har ingen
`system_events`-post. Ingen deklaration behövs — verifieras ändå mot emulatorn, inte antas.

---

## 5. Testning

Harnesset är hemsnickrat: varje `scenario_*` måste **också** anropas i `main()`:s linjära lista i
slutet av filen, annars körs det aldrig.

1. `scenario_moderationThresholdRowIsErased`
2. `scenario_reporterRowsFollowTheirSourceReport` (formen beror på Malins svar, konflikt 1)
3. `scenario_contentOwnerRowIsAnonymizedNotDeleted` — och att raden **står kvar**
4. `scenario_probeSeesLeftoverModerationEvents` — ren/smutsig, ett par per sondben
5. `scenario_contentReportWithNullOwnerIsUntouched`

Varje scenario får en **överlevande kontrollrad för en annan användare** i samma samling. Utan
den passerar ett ofiltrerat svep lika grönt som ett korrekt.

**Före allt annat:** `FakeRef` (test-filens stub, rad 96-111) har `delete`, `update`,
`collection`, `listCollections` — **ingen `get()`**. Sondben 4 kastar då `TypeError`, och
`main()` kör scenarierna sekventiellt med en enda `.catch()` längst ner, så kastet tar med sig
varje scenario efter det. `FakeRef.get()` läggs till först, i samma ändring. (QA-sätets fynd,
verifierat i koden.)

**Kopplingen:** en engångs-mutationssond bevisar att kopplingen finns i dag men lämnar ingen
stående vakt. Steget läggs till i den permanenta "varje kaskadstegsnamn syns i resultatkuvertet"-
assertionen i `request-account-deletion.test.ts`. Att definiera funktionen räcker inte — tupeln
måste in i `tier1`-arrayen i `request-account-deletion.ts`, annars körs den aldrig.

Mutationssonder körs **före** granskningsgrindarna dispatchas (BUT-1951).

---

## 6. Klassen bakom buggen (eget ärende)

Ingen vakt frågar *"bär den här samlingen ett uid, och finns det i så fall ett kaskadben?"*
`system_events` var "beslutad" och ändå oraderad. Bygg vakten — som eget ärende, inte insmuget.

---

## 7. `user_moderation` — hålls UTANFÖR, efter panelen

`user_moderation/{contentOwnerId}`: dokument-id är den anmäldas uid, `reportHistory` är en array
som bär `reporterId` för varje anmälan. Ingen kaskad, ingen sond, ingen export.

**Planens första version rekommenderade att vika in den. Det är ändrat efter T&S-sätets
invändning.** `reportHistory` är den enda datan som överlever *anmälarens egen* radering och som
kan svara på om ett konto anmäler samma person upprepat (`reports` bär också `reporterId`, men de
raderna hårdraderas när anmälaren försvinner — mätt). Att stryka `reporterId` där vore att förlora
Butlerys enda signal mot samordnad eller okynnesanmälan, DSA artikel 23-territorium, som en
sidoeffekt av att städa två samlingar med samma trigger.

**Beslut: eget ärende, med egen T&S-granskning.** Filas innan BUT-2032 stängs.
Om det byggs: arrayomskrivningen måste ske **inuti en transaktion som läser `reportHistory` i
samma transaktion**, med omförsök vid konkurrens — skrivaren använder `arrayUnion` i sin egen
transaktion, och en `get()` följd av en senare `update()` tappar tyst en anmälan som landar
emellan.

`report_processing_markers` bär bara `reportId` och tidsstämplar. Ren.

---

## 8. Kapplöpningen ingen tänkt på — arkeologsätets fynd

`onReportCreated` är en `onDocumentCreated`-trigger på `reports/{reportId}`. Den har **ingen
ordningsrelation alls till kontoraderingen** — till skillnad från `onUserDeleted`, som garanterat
körs efter `auth.deleteUser`. Handlern kastar om vidare för omförsök.

Konkret: någon anmäler och raderar sitt konto sekunder senare, eller ett omförsök landar efter att
kaskaden kört. Triggern skriver då en **ny** `content_report_<reportId>`-rad som namnger ett redan
raderat uid, och inget städar den.

Det är en tredje kategori som filen inte har ett begrepp för: varken kaskad-ägd eller trigger-ägd,
utan *oberoende utlöst skrivare utan ordningsrelation till raderingen*. Repot har precedens för
båda utvägarna — block-spegelns motsvarande kapplöpning stängs av en veckovis avstämning
(`runReconcileBlockMirrors`).

**Malins uttryckliga beslut 2026-09-08: namngiven accepterad restrisk, ingen avstämning.** Hon
fick se alternativet (en veckovis avstämning, som block-spegeln redan har för samma sorts
kapplöpning) och dess pris i form av en schemalagd uppgift till. Fönstret kräver en anmälan i
samma sekundintervall som en radering. Ingen har mätt hur ofta det inträffar — appen är inte
live. Skrivs in i `accepted-deviations.md` i samma edit som koden.

---

## 9. Följdändringar i text (bara strykningar, per code-style)

- `admin/reset-collection-lists.ts` — "NAMED RESIDUAL, not closed here … it is its own ticket"
  blir osant den dag det här landar. Stryks. Ersätts inte med en berättelse om vad som ströks.
- `docs/ops/moderation-runbook.md` — "Audit trail"-stycket måste ange vad som **faktiskt**
  överlever en radering per radform, inte bara tystna. En admin som konsolläser förlitar sig på
  det.
- **Artikel 15: raderna förblir undantagna.** Malins uttryckliga beslut 2026-09-08, mot
  alternativet att bygga en exportsektion — `firestore.rules` ger användaren ingen läsning av
  `system_events` alls (`allow read: if isAdmin()`), så en export hade krävt en ny läsyta på en
  adminsamling. **Inte i `EXPORT_EXEMPT`:** den kartan är scopad till `USER_SUBCOLLECTIONS`
  (tier 2), och vaktens `stale`-check (`Object.keys(exempt).filter(n => !subs.includes(n))`)
  blir röd av en toppnivåsamling. Beslutet skrivs i `accepted-deviations.md` + en kommentar vid
  raderaren.
- Nya poster i `.claude/rules/accepted-deviations.md` **och** `docs/architecture/ACCEPTED_DEVIATIONS.md`,
  i samma edit, i samma commit som koden.

---

## 10. Vad det här betyder, i klartext

Butlery sparar en admin-logg över varje anmälan. Loggen namnger både den som anmälde och den som
blev anmäld. När någon raderar sitt konto städas anmälningarna själva — men den här loggen har
aldrig städats. Namnen ligger kvar för alltid.

Planen städar loggen på samma sätt som anmälningarna redan städas: den anmäldas namn suddas ur
raderna men raderna står kvar (så moderering fortfarande går att granska). Strike-räknaren som
avgör om någon ska granskas rörs inte.

---

## 11. Panelens utfall — villkor och konflikter

**Säten:** DPO (GDPR), Trust & Safety, Security Architect, DBA/datalager, QA, plus
Codebase Archaeologist. **Alla sex: `approve-with-conditions`. Ingen blockering.**

**Avförda:** Legal Counsel (den enda rättsligt tolkande frågan eskaleras till Malin ändå, och
DPO-sätet bär den), Product Manager och Software Architect (inget produktval, ingen lagerändring),
FinOps (fyra extra läsningar en gång per konto), Customer Support/Ops (T&S bär samma runbook-stake),
Vendor/Procurement (ingen leverantörsyta).

### Villkor som rider med (union, deduplicerad)

- **A. Tak-och-avböj på de två `content_report_*`-svepen.** Obegränsade frågor på fält en motpart
  kontrollerar. Filen har tre precedensmönster (`MAX_ROSTER_SWEEP_ROWS`, `MAX_BLOCK_SWEEP_ROWS`,
  `MAX_POLL_VOTE_SWEEP_ROWS`): `.limit(tak+1)`, **avböj** över taket i stället för att trunkera,
  bredvid en otakad `count()`-sond. *(DBA)*
- **B. De nya stegen stagar sina egna auditrader**, som `anonymizeReportsByContentOwner`. Sänkningen
  accepteras inte. *(DPO, Security)*
- **C. Sondbenet fail-closed i eget try/catch; indexbeteendet verifierat mot emulatorn.** *(Security, DBA)*
- **D. `FakeRef.get()` läggs till före scenario 4 skrivs;** verifierat att inget scenario efter det
  aborteras. *(QA)*
- **E. Varje nytt scenario anropas i `main()`; varje scenario får en överlevande kontrollrad för
  annan användare; eget rent/smutsigt par per sondben; ett scenario för `contentOwnerId == null`.** *(QA)*
- **F. Kopplingen blir en permanent assertion i `request-account-deletion.test.ts`,** inte en
  engångsmutation. *(QA)*
- **G. Ingen `EXPORT_EXEMPT`-post.** *(Arkeologen)*
- **H. Kapplöpningen i avsnitt 8 avgörs explicit** — namngiven restrisk eller avstämning. *(Arkeologen)*
- **I. `user_moderation` filas som eget ärende innan BUT-2032 stängs.** *(DPO, Security, T&S)*
- **J. Runbookens "Audit trail" anger faktiskt beteende per radform.** *(T&S)*
- **K. Textstrykningarna landar i samma commit som koden.** *(Security)*

### Konflikter

1. **Anmälarens rad: radera eller anonymisera?** T&S ville anonymisera (nolla `reporterId`,
   behålla raden) för symmetri med den anmälda-sidan och för att en admin annars inte ens ser att
   en anmälan funnits. Planen ville radera, för konsekvens med att källraden i `reports` redan
   hårdraderas. Hög insats (användarsäkerhet + integritet) → eskalerad. **Malin valde RADERA,
   2026-09-08**, med T&S:s runbook-villkor kvar. ADR-0016.
2. **`user_moderation` i samma ärende?** Planen ville vika in; T&S sa nej. **Löst av
   prioritetsordningen** (användarsäkerhet före att hålla en delad sanning): hålls utanför,
   filas separat. ADR-0015.
3. **Auditradsänkningen.** Planen accepterade den; DPO och Security krävde ett uttryckligt beslut,
   och Security visade att BUT-781-analogin inte bär den halvan. **Löst genom att inte sänka** —
   dataintegritet före kostnad, ~1 extra skrivning per raderad rad. ADR-0014.

Rådgivande. Malin avgör om bygget går vidare.
