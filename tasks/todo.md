# Plan — BUT-1850: ta bort `conversation_memberships`

Malins beslut 2026-09-17: **alternativ 2, ta bort den.** Den här planen är HUR, inte OM.
Stänger BUT-2101 och BUT-1829 när den shippar.

**Router, körd på den faktiska filunionen:** `{"tier": "full-panel", "panel": [Customer
Support, Data Analyst/BI, DBA, FinOps, Legal Counsel, Performance Engineer, DPO, Product
Manager, Security Architect, Software Architect, Trust & Safety, Vendor]}` — tolv säten,
`high_stakes_hits: [firestore.rules, account-deletion-cascade.ts, data_export_service.dart]`.
Panelen konvenas FÖRE första redigeringen. **Tier C.**

---

## Steg 0 — vad som faktiskt finns (mätt 2026-09-17, inte hämtat ur biljetten)

Biljettens kropp säger "tre döda läsvägar" och nämner raderingskaskaden. Det är sant men
ofullständigt — kollektionen refereras på betydligt fler ställen. Uppdelat:

### Skrivare (klient, LEVANDE)
- `ConversationParticipantModule.addParticipant` / `addParticipants`
  (`conversation_participant_module.dart`, 20 referenser) — skriver BÅDA halvorna av
  tvåvägsindexet i EN `WriteBatch`, via `ConversationMutationModule:126`.
  Levande väg: `createDirectConversation` → två rader per ny direktkonversation.
- `updateLastRead`, `updateConversationActivity` — **noll anropare i `lib/`**, mätt.
- `removeParticipant` — raderar.

### Raderare (server, Admin SDK, TRE, alla levande)
1. `functions/src/messaging/enforce-group-minor-membership.ts:465` — barnsäkerhetsvräkningen.
2. `functions/src/groups/remove-chat-group-member.ts:241` — spegelstädning vid borttagning.
3. `functions/src/account/account-deletion-cascade.ts:4360` — per konversation, plus
   kollektionen står i `USER_SUBCOLLECTIONS:4077` som driver `subs`-svepet.

### Läsare (EN, och den är inte i appen)
Art. 15-exporten, i tre lager:
`firebase_data_export_repository.dart:675 exportConversationMemberships`
→ `social_export_manager.dart:643`
→ `data_export_service.dart:261` (`'conversation_memberships':`).
Plus `ExportResourceType.conversationMemberships` (`:26`).

Ingen vy, viewmodel eller widget. `getUserMemberships` / `watchUserMemberships` /
`getConversationIdsViaInverseIndex` har noll anropare utanför sina egna filer.

### Övriga kopplingar
- `firestore.rules:598-612` (regelblocket), `:10` (inventeringskommentaren i huvudet),
  och den långa kommentaren vid `:1876-2020` som beskriver tvåvägsindexet och CF-historiken.
- `test/unit/security/rules_allowlist_drift_test.dart:144-149` + `:280-286` — en
  `_Allowlist`-post ankrad på `match /conversation_memberships/{conversationId}`, med
  nyckelmängden härledd ur modellen. Försvinner blocket utan att posten tas bort rödnar den.
- `functions/src/admin/reset-collection-lists.ts:51` — nollställningsskriptets inventering.
- `lib/core/constants/firestore_collections.dart:131` — konstanten.
- `lib/models/messaging/conversation_membership.dart` (11) + dess prov (8).
- Regelprov: `conversations-rules.test.ts` (6), `remove-chat-group-member.test.ts` (4),
  `enforce-group-minor-membership.integration.test.ts` (3),
  `account-deletion-cascade.test.ts` (3), `chat-group-callables.test.ts` (1).
- **Dart-prov som kompilerar mot det som raderas** (missades i första utkastet, hittade av
  planrevisionen): `conversation_participant_module_test.dart` (5),
  `conversation_query_module_test.dart` (2), `social_export_manager_test.dart` (3).
- Beslutsposter som nämner den: `ACCEPTED_DEVIATIONS.md:1598` och `:1813`, samt **ADR-0006**.

### Inga index, ingen TTL
`firestore.indexes.json`: noll träffar. Ingen retention-policy pekar på den.

### Produktionsdata: NOLL rader
Mätt 2026-09-17 mot butlery-app-1: två konton
(`qYng6Rh7ycQy2a8VwG5uiTh0NBB3`, `t7pPjUXoLrUfcyXA2PPbUnNDTaA2`), båda med **tom**
`conversation_memberships`-underkollektion. Borttagningen strandar alltså ingen data.

**Den siffran är tillskriven, inte reproducerbar ur repot** — en engångsläsning via
Firebase-MCP, committad ingenstans. Och skrivvägen är LEVANDE: en ny direktkonversation
skapar två rader. Därför måste den mätas om omedelbart före regelblocket tas bort (AC7).

---

## Faran som ordningen finns till för

Tas regelblocket bort medan rader finns, fångas de av den avslutande
`match /{document=**}` — ingen klient kan läsa eller radera dem, för alltid. Det är exakt
den föräldralösa skalform repot redan betalat för (`tryClearRoster`, BUT-1838/BUT-1822).

Med noll rader är faran tom. Men den är tom **idag**, inte nödvändigtvis på deploy-dagen.

**Vald ordning, konservativ:** allt tas bort i ett pass UTOM de två inventeringsposterna
(`USER_SUBCOLLECTIONS` och `reset-collection-lists.ts`). De står kvar en release till som
skyddsnät — så att om en rad ändå hann skapas städas den av kontoraderingen respektive
nollställningen. En uppföljningsbiljett tar bort dem efter en mätt nolla.
Att lämna ett namn i en raderingslista för en kollektion som inte finns är ofarligt (svepet
blir en no-op); att ta bort det för tidigt är det inte.

**Den ordningen kräver en `EXPORT_EXEMPT`-post, annars rödnar CI.** Mätt i
`account-deletion-cascade.test.ts:6265-6276`: vakten går igenom `USER_SUBCOLLECTIONS`,
hoppar över varje namn som hittas i exportfilens kedjeskanning eller i `EXPORT_EXEMPT`, och
faller på resten med "erased but never obtainable under Art. 15". Att behålla namnet i `subs`
medan exportsektionen raderas ur just den fil skanningen läser är precis den luckan — det är
BUT-1992-invarianten (Art. 15 ⊇ Art. 17) som vakten byggdes för.

Så: `EXPORT_EXEMPT.conversation_memberships` läggs till i samma ändring, med en skriven
motivering på minst 20 tecken (`:6194` underkänner en kortare eller saknad). **Inled den INTE
med `NO LIVE WRITER`** — den prefixen har egen betydelse på `:6290` och prövas mot en
skrivarskanning.

**Tvåstegskontraktet är maskinbundet, inte prosabundet:** syskonkontrollen på `:6301`
(`no exemption names a collection the cascade has stopped deleting`) faller om
uppföljningen tar bort namnet ur `subs` utan att ta bort `EXPORT_EXEMPT`-posten i samma
redigering. Vakten tvingar alltså fram parigheten åt båda hållen, vilket är skälet att den
här ordningen är säker att välja.

**Alternativet, och vad det kostar:** ta bort båda inventeringsposterna direkt i den här
ändringen. Då behövs ingen exemption alls och inget tvåstegskontrakt — men en rad som hinner
skapas mellan mätningen och deployen blir strandad för alltid, eftersom både regelblocket och
kaskadbenet är borta. Valt bort: exemption-posten är billig och vakten bevakar den.

**Planens svagaste punkt, sagt rakt ut:** nollmätningen är tillskriven och inte reproducerbar
ur repot, och skrivvägen är levande tills steg 2 shippar. AC7 finns just för det.

### Ordningen ändrad av panelen — FLAGGAN FÖRST

Security Architect-sätet hittade en fara jag inte prissatt: regler och apputgåva är **skilda
artefakter**. Tas regelblocket bort medan en äldre klientbuild är ute kastar
`createDirectConversation` hårt — `firestore.rules:602-605` säger uttryckligen att just den
här grenens avslag INTE sväljs (`addParticipants` saknar lokal catch, så `batch.commit()`
kastar upp genom `createDirectConversation`). Det är inte en degraderad lista utan att det
blir omöjligt att starta ett DM.

Mätt av mig efteråt: hela modulen grindas av `_isEnabled` →
`enable_subcollection_participants`, som är **Remote Config-styrd** med Dart-default `true`.
Det ger en ordning som stänger faran utan tvåsläppsdans:

1. **Slå av `enable_subcollection_participants` i Remote Config.** Skrivningarna upphör
   direkt på ALLA klienter, även gamla builds. Ingen ny rad kan skapas.
2. Mät om radantalet (AC7) — och **läs om flaggan**, inte bara antalet: nollan bounder bara
   risken om flaggan verkligen är av i live Remote Config (DBA-sätet).
3. Deploya regeländringen.
4. Ship kodborttagningen.

`enable_subcollection_participants` styr även `conversations/{id}/participants`-halvan, som
INTE tas bort här — att slå av flaggan stoppar alltså båda halvorna tillfälligt. Det är
acceptabelt eftersom den halvan också saknar levande läsare (Software Architect-sätet, mätt),
men det ska stå skrivet, inte upptäckas.

---

## Uppgifter

### [Tier C] 1. Konvena panelen (tolv säten, blint) — FÖRE första redigeringen
Bär med: att beslutet är fattat (det är HUR, inte OM), Steg 0 ovan, nollmätningen, och den
valda ordningen. Fråga uttryckligen efter: Art. 15-konsekvensen, ordningen, och om något
säte känner till en läsare Steg 0 missade.

**Briefen MÅSTE bära mätningen att `updateLastRead` och `updateConversationActivity` har noll
anropare i `lib/`.** Lärdomen från 2026-09-17 (BUT-2101) är att en blind panel avkorrelerar
resonemang men inte premisser: fyra av elva säten prissatte förra ändringen mot just de två
metoderna som om de vore levande, därför att biljetten kallade dem "the legitimate writers".
Utan mätningen i briefen gör de om det.

**Panelens bindande villkor fälls in som acceptanskriterier här i planen INNAN uppgift 2
påbörjas** (`.claude/rules/workflow-discipline.md`, "Cast stakeholders before planning").

### [Tier C] 2. Ta bort klientsidan — TRIMMA metoderna, radera dem inte

**Omskrivet efter Software Architect-sätet.** Första utkastet läste som att modulen skulle
tömmas. Det får den inte. `ConversationParticipantModule` gör TVÅ saker i samma `WriteBatch`:
den skriver medlemskapsspegeln (som dör här) OCH `conversations/{id}/participants/{uid}` —
en **separat** underkollektion med eget regelblock (`firestore.rules:1918`) och egen modell,
byggd för att skala grupper förbi 100 medlemmar. Att pensionera den är ett ANNAT, oavgjort
beslut (BUT-2110) och får inte rida med i den här diffen.

Per metod, avgjort på vad som blir kvar:
- `addParticipant`, `addParticipants`, `removeParticipant`, `updateLastRead`,
  `migrateToSubcollection` → **trimma** medlemskapshalvan. `participantRef`-anropen ska vara
  byte-identiska efteråt.
- `updateConversationActivity` → **radera HELT.** Den skriver bara medlemskapsrefs; trimmad
  committar den en TOM batch, alltså en tyst no-op som fortfarande går att anropa (DBA-sätet).
- Modulen finns kvar och konstrueras fortfarande i `firebase_messaging_repository.dart`.
- Anropet i `conversation_mutation_module.dart:126` står kvar (trimmat), raderas inte.

Sedan de rena medlemskapssakerna:
`conversation_participant_module.dart` (de döda läsarna),
`conversation_query_module.dart:getConversationIdsViaInverseIndex`,
`conversation_membership.dart` + dess prov, konstanten, och anropet i
`conversation_mutation_module.dart:126`.
`ConversationQueryModule`:s klassdok (`:10`) påstår "both legacy arrayContains queries and
new subcollection-based queries" — sant bara om den döda metoden; stryks i samma ändring.

### [Tier C] 3. Ta bort serverns spegelraderingar — per ställe, inte "raden bredvid"

**Rättelse: första utkastet sa "rosterraden bredvid dem". Det är MÄTT FALSKT** och två säten
fångade det oberoende. I `enforce-group-minor-membership.ts` ligger rosterklippet inuti
transaktionen (`stageBackstopRemovals` :412) och `cutGroupMenuPlanAccess` på :447, medan
spegelraderingen är det avslutande `Promise.all` på :465 — olika funktioner, inte grannar.
I `remove-chat-group-member.ts` är den ett fristående block efter transaktionen. Bara i
kaskaden (:4360) ligger de intill varandra. Instruktionen "ta bort raden bredvid rostern"
hade alltså vilselett den som gör jobbet.

**Den verkliga faran ligger i `remove-chat-group-member.ts:238-262`, och den är värre än
den jag skrev.** Spegelraderingen är det FÖRSTA `await`:et inuti
`if (outcome.removed && outcome.conversationId)`, omedelbart följt av
`writeGroupSystemMessage(memberLeft)` och `remaining === 0`-kollapsen. Den som raderar
BLOCKET i stället för SATSEN tappar `memberLeft`-raden medan `stageMemberRemoval` fortfarande
skriver `tombstone: true`. `chat-group-writes.ts` skriver ut varför det inte får hända
(verifierat ordagrant): tombstone-arrayen "may only ever hold departures that ALSO produce a
visible `memberLeft` system row — otherwise the difference between the two is a list of the
accounts the child-safety backstop evicted, i.e. a durable, queryable claim that someone is a
minor."

Alltså: **ta bort SATSEN, aldrig blocket**, på alla tre ställena, och bevisa det per ställe.

### [Tier C] 4. Ta bort regelblocket och dess prov
`firestore.rules:598-612`, inventeringsraden `:10`, och `_Allowlist`-posten +
nyckelmängden i `rules_allowlist_drift_test.dart`. Regelproven som seedar rader uppdateras.

### [Tier C] 5. Art. 15 — ta bort exportsektionen, med skrivet beslut
Sektionen `conversation_memberships` försvinner ur databundlen i alla tre lagren, OCH
`EXPORT_EXEMPT.conversation_memberships` läggs till i `account-deletion-cascade.ts` i samma
ändring (se ordningsavsnittet ovan — utan den rödnar
`scenario_exportCoversEveryDeletedSubcollection` i CI).
Motiveringen ska säga att kollektionen tas bort och att raderna därför inte längre finns —
inte att vi väljer att undanhålla dem. Minst 20 tecken, och inte prefixet `NO LIVE WRITER`.
Även `social_export_manager_test.dart` uppdateras, som pinnar sektionen.
**Skälet är att uppgifterna inte längre finns, inte att vi väljer att undanhålla dem** —
det är skillnaden som ska stå i posten. Dateras i BÅDA speglarna
(`.claude/rules/accepted-deviations.md` och `docs/architecture/ACCEPTED_DEVIATIONS.md`),
i samma redigering, var och en med sin egen ordagranna citering.

### [Tier A] 6. Beslutsposter — omskopat av DPO- och Legal-sätena

**Ingen av de två posterna superseras nu.** Första utkastet ville supersera båda; båda sätena
vägrade, var för sig:
- `ACCEPTED_DEVIATIONS.md:1598` berättar om BUT-1822:s Art. 17-defekt som stängdes
  2026-08-13. Historiskt sant oavsett om kollektionen finns. Rörs inte.
- `:1813` ("erasure already happens in `deleteUserSubcollections`") är **sant den här
  releasen** och blir falskt först när uppföljningen tar bort `subs`-posten. Superseras
  DÄR, med meningen citerad ordagrant — inte nu, annars motsäger posten koden i en release.
- **ADR-0006 rörs inte.** Den beskriver en borttagen GREN. Performance-sätet bekräftar:
  dess kärna (gränsen stannar, debitering sker per returnerat dokument) hänger inte på
  kollektionens existens.

### [Tier C] 7. Art. 30-registret — missat helt i Steg 0, hittat av tre säten

`docs/security/account-subcollections-retention.md` är vårt Art. 30-register för
`users/{uid}`-underkollektioner, och dess eget huvud säger att varje kollektion har en rad
"whether or not it is exported". `conversation_memberships` finns i **ingen** av dess två
tabeller idag — registret är alltså redan ofullständigt, och att lägga till en
`EXPORT_EXEMPT`-post utan en registerrad gör det materiellt inaktuellt.

Ingenting maskinbinder den filen (enda referensen i repot är `docs/org/role-paths.json:98`),
så den rödnar inte i CI. Den måste redigeras för hand i samma commit.

**Motiveringens form, bindande från Legal- och DPO-sätena:**
- Den är ett påstående om KODEN, inte om produktionen: skrivaren, modellen och regelblocket
  är borta, så ingen ny rad kan skapas.
- Den får INTE formuleras som ett undanhållande och får inte luta sig mot Art. 15(4) — det
  är inte ett undanhållandebeslut, och kartans första hälft har rubriken "Withheld on
  purpose, with a live writer". Motiveringstexten är det enda som skiljer familjerna åt.
- Den är SKOPAD: för ett konto som ännu bär gamla rader är de raderbara men var aldrig
  exporterbara. Ingen universell formulering ("fanns aldrig").
- Den namnger uppföljningsbiljetten och parigheten i samma redigering.
- Ingen `data_minimisation`-mening läggs till i bundlen som namnger kollektionen — per
  Malins 2026-09-09-beslut om `block_mirror` är det en upplysning ingen bett om. Att den
  familjen medvetet saknar upplysningssite ska stå skrivet, inte antydas.

---

## Acceptanskriterier

- [x] `{text: "En grep over hela repot visar noll referenser kvar - lib, functions/src, firestore.rules, test - utom de TRE medvetet kvarlamnade: USER_SUBCOLLECTIONS, reset-collection-lists.ts och EXPORT_EXEMPT.conversation_memberships", kind: diff}`
- [x] `{text: "De tre CF-spegelraderingarna ar borta och rosterraderingen bredvid var och en ar ORORD, visat rad for rad", kind: diff}`
- [x] `{text: "Art. 15-sektionen ar borta i alla tre lagren, med daterad post i BADA speglarna i samma redigering, som sager att uppgifterna inte langre finns", kind: diff}`
- [x] `{text: "rules_allowlist_drift_test.dart passerar - posten borttagen, inte ankaret lamnat att rodna", kind: diff}`
- [x] `{text: "npm run test:rules:all rodnar inte NYA fall jamfort med baslinjen 41/47 (BUT-2105 ager de sex befintliga)", kind: run}`
- [x] `{text: "flutter test pa de berorda sviterna gront, och kontoraderingens prov uppdaterade sa att de inte pinnar en spegel som inte finns", kind: run}`
- [x] `{text: "Radantalet i produktion ommatt OMEDELBART fore regelblocket tas bort. Ar det INTE noll stoppas andringen och gar tillbaka till Malin - inget osperificerat produktionssvep pa eget bevag", kind: run}`
- [x] `{text: "USER_SUBCOLLECTIONS och reset-collection-lists.ts ar MEDVETET ororda, och en uppfoljningsbiljett finns for att ta bort dem efter en matt nolla", kind: diff}`
- [x] `{text: "EXPORT_EXEMPT.conversation_memberships tillagd med en motivering pa minst 20 tecken som INTE inleds med NO LIVE WRITER, och scenario_exportCoversEveryDeletedSubcollection kors gront", kind: run}`
- [x] `{text: "Uppfoljningsbiljetten sager uttryckligen att den maste ta bort subs-posten OCH EXPORT_EXEMPT-posten i SAMMA redigering, annars faller stale-kontrollen", kind: diff}`
- [x] `{text: "De tre Dart-proven (conversation_participant_module_test, conversation_query_module_test, social_export_manager_test) ar uppdaterade sa att de kompilerar och inte pinnar borttagen yta", kind: diff}`
- [x] `{text: "flutter analyze --fatal-infos rent pa varje andrad fil", kind: run}`
- [x] `{text: "ADR-0006 lasts och andras bara om den ar falsk - den beskriver en borttagen gren, inte kollektionens existens", kind: diff}`
- [x] `{text: "ADR-0020:s strukna spargrindslista namner conversation_membership i bada speglarna - avgjort medvetet (historisk post over vad som STROKS, ror inte kollektionens existens) i stallet for att upptackas senare", kind: diff}`
- [ ] `{text: "BUT-2101 och BUT-1829 stangs med hanvisning till commiten", kind: diff}`

## Panelens bindande villkor (tolv säten, blint, 2026-09-17)

- [ ] `{text: "FLAGGAN FORST: enable_subcollection_participants slas av i Remote Config fore regeldeployen, och AC7 laser om BADE radantalet och flaggans live-varde", kind: run}`
- [x] `{text: "Steg 3 tar bort SATSEN pa alla tre stallena, aldrig blocket. remove-chat-group-member.ts: writeGroupSystemMessage(memberLeft) och remaining===0-kollapsen ar byte-identiska efter andringen", kind: diff}`
- [x] `{text: "enforce-group-minor-membership.integration.test.ts rosterassertioner (rosterraden raderad, vuxnas rad intakt) ar byte-identiska mot git show HEAD:, och mutationsprovas efter steg 3 - avaktivera rosterraderingen, de MASTE rodna", kind: run}`
- [x] `{text: "Kaskadprov: sa en conversation_memberships-rad, kor kaskaden, assertera residual==0 och gdprCompliant:true. Mutationsprovas genom att ta bort subs-posten - det MASTE rodna", kind: run}`
- [x] `{text: "conversations/{id}/participants-halvan ar ORORD: varje trimmad metods participantRef-anrop byte-identiskt, firestore.rules participants-blocket och conversation_participant.dart visar noll diff, och ConversationParticipantModule finns kvar och konstrueras fortfarande", kind: diff}`
- [x] `{text: "updateConversationActivity raderas HELT (den skriver bara medlemskapsrefs - strippad committar den en TOM batch, en tyst no-op); updateLastRead trimmas eftersom den behaller en participant-skrivning", kind: diff}`
- [x] `{text: "Art. 30-registret docs/security/account-subcollections-retention.md far en rad for conversation_memberships i SAMMA commit", kind: diff}`
- [x] `{text: "EXPORT_EXEMPT-motiveringen ar ett pastaende om KODEN, skopad, inte formulerad som ett undanhallande, utan Art. 15(4), och utan universell fanns-aldrig-formulering", kind: diff}`
- [x] `{text: "AC1 undantar uttryckligen firestore.rules:1876-2020 och rate_limiter.ts:110 - historiskt sanna kommentarer som INTE far strykas", kind: diff}`
- [x] `{text: "Regelprov pa den nya createDirectConversation-batchen: tva participants-rader, en for den ANDRA anvandaren, TILLATS", kind: run}`
- [x] `{text: "firestore.indexes.json-diffen ar tom och inget indexdeploy-steg tillkommer", kind: diff}`
- [ ] `{text: "AC7:s matresultat (siffran, noll eller inte) skrivs in i commit-meddelandet OCH som Linear-kommentar pa BUT-1850", kind: run}`
- [ ] `{text: "Commit-kroppen sager att Admin SDK kringgar firestore.rules - det ar mekanismen som gor skyddsnatet effektivt, och far inte lamnas underforstatt", kind: diff}`
- [x] `{text: "Beslutsposten sager att borttagningen adderar NOLL nya lasningar till limit(500)-fragan, och namner den numeriska omprovningstriggern (~p95 konversationer per anvandare mot 100)", kind: diff}`

**Löst konflikt mellan två säten, dokumenterad hellre än begravd:** DBA-sätet ville radera
`migrateToSubcollection` helt; Software Architect-sätet vägrade varje diff som raderar den i
sin helhet, eftersom den även skriver `participants`-halvan och att pensionera den
skalningsvägen är ett ANNAT, oavgjort beslut. Löst till det smalare alternativet: metoden
trimmas, inte raderas, och frågan om `participants`-underkollektionen och dess döda
skalningsrattar (`shouldMigrate`, `max_inline_participants`) får en egen biljett.

---

## Deviation log

- [discovery] AC292: planen ville ett NYTT regelprov på createDirectConversation-batchen.
  P25 i `conversations-rules.test.ts` gör redan exakt det (två participants-rader, en för
  FRIEND_UID, `assertSucceeds`) sedan medlemskapsskrivningarna togs bort ur den. Inget nytt
  prov skrevs — ett duplikat hade varit vakuöst.
- [deviation] AC286: kaskadprovet lades i `NO_OWN_STEP` i
  `scenario_steplessSubcollectionsAreErasedNotJustReported` i stället för ett eget scenario.
  Den listan sår raden, kör hela kaskaden och asserterar att den uppräknande sonden inte
  rapporterar något — vilket är precis påståendet om att `subs`-posten är bärande — och
  mutationsprovet är att ta bort posten. Mätt: 451/453 med posten borta, och det namngivna
  fallet rödnar.
- [discovery] `rules_allowlist_drift_test.dart`: census-literalen gick 41 -> 40. Rätt siffra
  verifierades genom att räkna `hasOnly(` i den kommentarsstrippade filen, inte genom att
  lita på deltat — rå grep ger 42/43, eftersom två träffar sitter i kommentarer.
- [discovery] Tre kommentarer mätte falska EFTER borttagningen och är STRUKNA, inte
  omformulerade: `firestore.rules` (båda halvorna skrivs i EN WriteBatch),
  `conversation_participant_module.dart` (BUT-1850-stycket, som påstod att indexet lästes av
  ingenting och därmed motsade systerfilen), och `conversation_query_module.dart`:s
  historikblock (det namngav `updateConversationActivity`, som den här ändringen raderar).
- [discovery] Art. 30-registerraden påstod att indexet lästes av ingenting i appen. Mätt
  falskt: Art. 15-exporten LÄSTE kollektionen live
  (`firebase_data_export_repository.dart` -> `data_export_service.dart`), och den sektionen
  är halva den här ändringen. Satsen struken. `getConversationIdsViaInverseIndex` hade
  däremot ingen produktionsanropare — bara sitt eget prov.
- [discovery] Båda spegelposterna citerade rubriken "Withheld on purpose, with a live
  writer" från planen. Filens verkliga rubrik är "Collections with a live writer". Citatet
  struket ur båda — en ärvd parafras som aldrig öppnades mot filen.
- [discovery] Mutationsprov 2 var först OGILTIGT, inte rött: baslinjen föll också, på 0s,
  därför att `node scripts/run-rules-tests.js` utan `node_modules/.bin` på PATH inte hittar
  `ts-node`. Med PATH satt: baslinje 1/1 grön, mutant 0/1 med rosterassertionerna namngivna.
- [needs-human] AC283 (flaggan av i Remote Config), AC279 (stäng BUT-2101/BUT-1829), AC294
  och AC295 står okryssade: de fullbordas vid commit/stängning eller på deploydagen, som är
  Malins sekvens.
- [deviation] Grindrundan drog in en fil planen aldrig namngav:
  `lib/repositories/firebase/firebase_messaging_repository.dart`. `code-reviewer` mätte att
  borttagningen av den omvända indexfrågan gjorde `participantModule` i
  `ConversationQueryModule` till en död söm — fältet och konstruktorparametern hade noll
  användningar (tre vid HEAD; den tredje var `getUserMemberships`) medan anropsstället
  fortfarande skickade in den. Fältet, parametern, argumentet och den därmed oanvända
  importen är borta. Mutationsmodulens eget `participantModule` är ORÖRT — det används.
  Detta är rundans enda KODdefekt.
- [discovery] Tre grindar rödnade, tillsammans 13 blockerande fynd, varav tolv var MENINGAR
  som borttagningen gjorde falska och en var koddefekten ovan. Alla tolv är rena
  strykningar; varje överlevande mening lästes om ensam efteråt. Två av dem var halva
  uppdateringar i min egen diff: P25:s testnamn hade uppdaterats till "2 rosters" medan
  syskonet P24 och P25:s egen kropp behöll "+ 3 memberships" respektive "2+2".
- [discovery] `firestore.rules:1993` låg inom det skyddade intervallet 1876-2020 men var
  ändå falsk: "the CF **now** deletes the roster row alongside the membership mirror" är ett
  påstående om NUVARANDE mekanism, inte historik. Struken. Den daterade meningen på :1892
  ("as of 2026-08-13 ... in the same batch as the memberships mirror") är DATERAD och därmed
  historiskt sann — den står kvar, och det är dateringen som räddar den.
- [discovery] BUT-2111 filad: den borttagna regelvägens nekande är obevisat av någon svit.
  `firestore-rules-tester` mätte nekandet med en engångssond (alla fem verb, attribuerade
  till catch-all-raden, med fail-closed-kontroll) men en mätning är inte en pinne.
  Icke-blockerande, så det byggs inte här — repots prejudikat (BUT-1716) säger att det bör
  byggas.

---

## På vanlig svenska — för Malin

Du bestämde att chattlistans hjälptabell ska bort. Den här planen är hur.

**Vad som visade sig när jag läste koden:** biljetten sa att tre läsställen är döda, vilket
stämmer. Men den nämnde inte att **tre olika serverfunktioner raderar rader** i tabellen,
att **Art. 15-exporten har en egen sektion** som läser den, eller att ett test binder ihop
reglerna med koden och rödnar om man tar bort regelblocket utan att städa testet. Den rörs
på betydligt fler ställen än biljetten sa.

**Den goda nyheten:** jag mätte produktionen — **noll rader** på båda kontona. Borttagningen
lämnar alltså ingen data strandad. Det var den verkliga risken, och den är tom.

**Det du ska veta:** en sektion försvinner ur GDPR-exporten. Det är korrekt — uppgifterna
finns inte längre att exportera — men det är en förändring av vad en användare får ut, så
det skrivs ner som ett daterat beslut på båda ställena vi för sådana.

**En sak jag gör försiktigt:** två listor som talar om för städrutinerna att tabellen finns
lämnas kvar en release till. Om någon hinner skapa en konversation mellan mätningen och
deployen städas raden ändå. De tas bort sedan, efter en ny mätt nolla.

**Vad som händer sen:** BUT-2101 (säkerhetshålet) och BUT-1829 stängs när det här shippar —
hålet försvinner med tabellen i stället för att lappas.

---

# ARKIV — sprint 2026-09-17 (stangd, allt levererat bockat)

# Sprint 2026-09-17 — åtta ärenden, tre kluster

Vald av `/delivery:sprint-execute`. Föregående sprint (2026-09-11 natt) är stängd och arkiverad
nedan. Steg 0 mot HEAD `3b54c46c3` är körd för alla åtta; greparna står under respektive ärende.
Inga kommentarer fanns på något av de åtta ärendena (kontrollerat).

**Utanför sprinten, med skäl:**
- BUT-1989 (`need-malin`) och BUT-1848 — **Tier D**: båda kräver en fysisk telefon. BUT-1848 säger
  det själv ("Det går inte att köra headless", ML Kit finns bara på enheten) och är dessutom
  blockerad bakom BUT-1847.
- BUT-1847 — kvarvarande arbete är dagar av manuell bildgradering av 189 poster, inte kod.
- BUT-2102 — klientens AI-kostnadsräknare. FinOps-formen (flytta skrivningen till Cloud Function,
  klienten läser en spegel) är en arkitekturändring, inte en reparation. Lämnas i backloggen.
- BUT-1826 — `needs-approval` sedan förra sprinten, oförändrat.

**BUT-1829 är en dubblett av BUT-2101** (samma regelbrist, samma kollektion). BUT-1829 bär den
bättre analysen och dess "Option 2" är exakt den fix BUT-2101 föreslår. Byggs under BUT-2101;
BUT-1829 stängs som dubblett vid ship.

---

## Kluster R — firestore.rules (fyra hål) — router: **full-panel**

Router körd på den faktiska filunionen (`firestore.rules` plus de tre regelsviterna):
`{"tier": "full-panel", "panel": [Customer Support, DBA, FinOps, Legal Counsel, DPO, Product
Manager, QA, Security Architect, Software Architect, Trust & Safety, Vendor]}`.
Panelen konvenas FÖRE bygget (Fas 1.4). `panelPolicy: park` → parkeras i In Review, aldrig Done.
Alla fyra är **Tier C** (säkerhetsregeländring).

### [Tier C] BUT-2101 — `conversation_memberships` saknar deltagarkontroll (High, Bug)

Disposition: **build**. Steg 0 mot HEAD, `firestore.rules:598-612`: `allow create, update` kräver
bara `isAuthenticated()`, en nyckelmängd och att `conversationId` matchar sökvägen. Ingen
deltagarkontroll. Premissen gäller.

Legitima skrivare, mätta i `conversation_participant_module.dart`: `addParticipant`/`addParticipants`
(skriver MOTPARTERS rader i en batch), `updateLastRead` och `updateConversationActivity` (uppdaterar
alla deltagares rader). Alla fyra sker från en klient som själv är deltagare.
`removeParticipant` raderar — och `allow delete` är redan `isOwner`, så den korsanvändarraderingen
nekas redan idag; noteras, ändras inte här.

- [ ] `{text: "create och update kraver att bade skrivaren och radens subjekt finns i conversations/{conversationId}.participantIds", kind: diff}`
- [ ] `{text: "conversationTitle bunden till strang med en langdgrans", kind: diff}`
- [ ] `{text: "Regelfall: framling NEKAS, deltagare TILLATS, raderad foralder NEKAS - mutationsprovade", kind: diff}`
- [ ] `{text: "De fyra legitima skrivvagarna tillats fortfarande, bevisat med modulens egen batchform", kind: diff}`

### [Tier C] BUT-2100 — vem som helst kan skriva vilket värde som helst i någons olästräknare (Medium, Bug)

Disposition: **build**. Steg 0, `firestore.rules:577-595`: nyckelmängden är bunden, VÄRDENA är det
inte. Skrivaren är `base_shared_content_repository.dart:58-72` (`FieldValue.increment(1)` på ett
fält plus `totalSharedContent`, best-effort, fel sväljs). Ingen regelsvit täcker kollektionen idag.

- [ ] `{text: "Andringen ar bunden (+1 per falt, som friendsCount) sa en frammande inte kan satta ett godtyckligt varde", kind: diff}`
- [ ] `{text: "Den riktiga skrivaren (increment(1) plus totalSharedContent plus lastUpdated) TILLATS fortfarande", kind: diff}`
- [ ] `{text: "En ny regelsvit for counters med allow- och deny-fall, mutationsprovad", kind: diff}`

### [Tier C] BUT-2092 — `metadata.poll.isClosed` är obunden i reglerna (Medium, security)

Disposition: **build**. Steg 0: `isClosed` förekommer i `firestore.rules` bara på rad 2379 (en
kommentar) och 2418 (`pollIsOpen()` i `poll_votes`-blocket). Avsändargrenen på `messages`
bär `cannotModify(['senderId','conversationId','sentAt'])` och dubblettvaktens villkor — inget
villkor på `metadata`. Premissen gäller.

- [ ] `{text: "isClosed kan inte ga fran true till false pa messages sandargren, ELLER ett skrivet beslut om varfor inte", kind: diff}`
- [ ] `{text: "De tre regelfallen ur biljetten finns: skapare+avsandare TILLATS, annan deltagare NEKAS, skapare som inte ar avsandare - mutationsprovade", kind: diff}`
- [ ] `{text: "Fall 3 har egen felmening eller ett skrivet beslut om att den generiska duger", kind: diff}`
- [ ] `{text: "INTE gjort: BUT-1832:s poll-narvarohal (metadata som map utan poll-nyckel) - det ar en beslutad avvikelse och ror inte denna gren", kind: diff}`

### [Tier C] BUT-2086 — flera betyg på samma recept (Medium, security)

Disposition: **build**. Steg 0, `firestore.rules:2721-2764`: create-grenen binder `userId`,
`rating`, nyckelmängd, `review`-längd och blockering — men `ratingId` används bara i
`rateLimitStamped`. Ingen dokument-id-form. Premissen gäller.

- [ ] `{text: "Ett regelfall visar halet fore fixen (andra betyget med annat id), och NEKAS efter", kind: diff}`
- [ ] `{text: "Create-grenen kraver att dokument-id ar recipeId plus understreck plus request.auth.uid", kind: diff}`
- [ ] `{text: "Appens riktiga skrivning TILLATS fortfarande; befintliga regeltesters icke-standardiserade id ar uppdaterade, inte borttagna", kind: diff}`

---

## Kluster S — tjänstelagret (Dart) — router: **single**

Router på unionen: `{"tier": "single", "panel": ["Software Architect", "Product Manager"]}`.
En blind kritik konvenas före bygget. Båda **Tier A**.

### [Tier A] BUT-2103 — `searchMessages` kör inte blockeringsfiltret (Low, Bug)

Disposition: **build**. Steg 0, `messaging_service.dart:688-721`: returnerar
`_withoutOthersBlockedRows(hits)`, inget `_filterBlocked`. Premissen gäller.

- [x] `{text: "searchMessages kor _filterBlocked i TJANSTEN, inte i repositoryt eller MessageQueryModule", kind: diff}`
- [x] `{text: "Motet mellan _filterBlocked fail-open och searchMessages egna catch-som-returnerar-tom-lista ar ett medvetet val, skrivet i koden", kind: diff}`
- [x] `{text: "Test i messaging_service_test.dart med riktiga Message-fixturer (inte Fake) som inte kan ga gront via tom lista", kind: diff}`
- [x] `{text: "INTE gjort: att binda type i firestore.rules - samma oppna post som BUT-1954 lamnade", kind: diff}`

### [Tier A] BUT-2087 — tre filer räknar ut receptägaren på det gamla sättet (Low, tech-debt)

Disposition: **build**. Steg 0: `rating_notifications.dart` (rad 27, 64, 145, 353),
`recipe_permission_helper.dart` (rad 28, 59, 121, 148, 170, 176, 197, 221),
`social_engagement_metrics.dart` (rad 371) skriver alla `socialData?.ownerId ?? createdBy`.
`Recipe.ownerUid` finns i `lib/models/recipe/recipe_ownership.dart:11`. Premissen gäller — men
`recipe_permission_helper.dart` har åtta ställen, inte ett; biljetten nämner bara `canRateRecipe`.

- [x] `{text: "Alla tre filerna anvander Recipe.ownerUid pa varje stalle dar de idag skriver socialData ownerId med createdBy som fallback", kind: diff}`
- [x] `{text: "Ett test per fil med tomt socialData.ownerId som rodnar om den gamla stavningen kommer tillbaka", kind: diff}`
- [x] `{text: "recipe_permission_helper.dart rad 88 (_legacyResolver.determineOwnership) ror inte - det ar en annan vag", kind: diff}`

---

## Kluster T — röda prov och en ops-kontroll

### [Tier A] BUT-2105 — röda regelsviter (Medium, Bug) — PREMISSEN OMSKRIVEN VID STEG 0

Disposition: **build**, men omskopad. Biljetten säger "45/47, båda röda i `audit-logs-rules.test.ts`".
**Mätt vid urvalet 2026-09-17 mot HEAD `3b54c46c3`, hela sviten i en körning (193 s):**

```
Rules suites: 41/47 passed, 47 ran
Failed suites:
  - src/__tests__/reports-rules.test.ts
  - src/__tests__/audit-logs-rules.test.ts
  - src/__tests__/menus-rules.test.ts
  - src/__tests__/realtime-menus-rules.test.ts
  - src/__tests__/comment-images-storage-rules.test.ts
  - src/__tests__/acquisition-rules.test.ts
```

Alltså **sex** röda sviter, inte en. Biljettens siffra är inte längre sann. Vad som INTE är mätt
ännu: hur många enskilda fall som är röda per svit, och om de sex har en gemensam orsak (den
uppenbara kandidaten är ADR-0020:s stämpelkrav, som landade 2026-09-14 och rör create-grenar brett)
eller sex olika. Diagnosen är första steget och ska mätas, inte gissas — det är biljettens egen
instruktion och den gäller fortfarande.

- [ ] `{text: "Antalet roda FALL per svit ar matt for alla sex sviterna, inte bara antalet sviter", kind: diff}`
- [ ] `{text: "Orsaken per svit ar MATT, inte gissad; om flera delar orsak ar det visat och inte antaget", kind: diff}`
- [ ] `{text: "npm run test:rules:all ger 47 av 47, ELLER en skriven redovisning av vilka som inte gick att laga i denna sprint och varfor", kind: diff}`
- [ ] `{text: "Ett prov som slutat prova det det pastar lagas sa att det provar det igen - aldrig sa att det bara blir gront", kind: diff}`
- [ ] `{text: "Biljettens kropp ar uppdaterad med den matta siffran innan bygget borjar", kind: diff}`

### [Tier A] BUT-2098 — bekräfta att första veckovisa Firestore-backupen landade (Urgent)

Disposition: **build** (verifiering). Biljetten säger att kollen måste köras från Malins maskin med
`gcloud`. Firebase-MCP:n har en egen backup-läsare — den prövas först (CLAUDE.md regel 11).
Minnesnotering: `--location=eur3` döljer schemat, använd `europe-west3`.

- [x] `{text: "Backuplistan ar last och rapporterad: finns en backup daterad omkring 2026-09-13, eller inte", kind: run}`
- [x] `{text: "Om ingen backup finns: en biljett med vad som saknas, inte en tyst stangning", kind: diff}`
- [x] `{text: "Om den landade: prioriteten satts tillbaka till Medium vid stangning, som biljetten sjalv begar", kind: run}`

---

## Needs you (Tier D)

- **BUT-1989** — QA-svep på fysisk telefon (fyra pass). Kräver dig och en telefon.
- **BUT-1848** — kör kokbokskorpusen genom ML Kit på en riktig telefon. Blockerad bakom BUT-1847.

## Deviation log

- [discovery] BUT-2105: planen sa "45/47, två röda fall i en svit" → mätt 41/47 och sex röda
  sviter mot HEAD `3b54c46c3` → ärendet omskopat före bygget, biljettkroppen ska uppdateras.
- [discovery] BUT-2100: biljettens fix ("+1 per fält") är MÄTT FEL. Tre skrivarformer finns:
  `incrementUnreadCounter` (+1, `set(merge:true)` på ett dokument som kanske inte finns),
  `decrementUnreadCounter` (`increment(-1)`, utan `totalSharedContent`, tre levande anropare),
  `recalculateUnreadCount` (absolut `set`, noll anropare). En `friendsCount`-formad regel utan
  create-arm nekar första delningen för ALLA och varje badge-rensning — tyst, eftersom skrivaren
  sväljer sina fel. Fångat av Security, DPO, QA och DBA oberoende; verifierat i koden.
- [discovery] BUT-2101: biljettens fix saknar `!('groupId' in parentDoc().data)`. Syskonblocket
  `participants` bär den (`firestore.rules:1954`) just för att en klient inte ska kunna skriva
  gruppmedlemskap och gå runt barnsäkerhetsgrinden BUT-1838 stängde. Utan den LEGITIMERAR fixen
  den skrivningen. Fångat av Trust & Safety; verifierat.
- [deviation] BUT-2101: fyra säten prissatte fixen mot `updateConversationActivity` "vid varje
  skickat meddelande, en rad per deltagare, 100+ grupper". MÄTT FALSKT idag: varken
  `updateConversationActivity` eller `updateLastRead` har någon anropare i `lib/` — bara sina
  definitioner, en dokumentationskommentar och sina enhetstester. Enda levande skrivvägen är
  `createDirectConversation` (2 rader, föräldern committad först). Kostnaden är verklig till
  formen men når ingen levande väg. Prissättningen ärvs INTE.
- [needs-human] BUT-2101 krockar med **BUT-1850** (High, öppen sedan 2026-08-15), vars alternativ
  2 är att RADERA hela kollektionen. DBA-sätet vägrade härdningen med just det skälet. Att härda
  något ett öppnare ärende föreslår att ta bort är Malins avvägning, inte min.
- [discovery] BUT-2087: den gamla stavningen finns i ~15 filer, inte 3. Biljettens tre byggs;
  resten får en egen biljett hellre än att tyst vidga omfånget — en 3-av-15-migrering läser som
  klar medan samma bugg lever kvar överallt annars (Software Architect-sätet).

## Panelens bindande villkor (infällda i acceptanskriterierna)

- BUT-2100: separat **create-arm** (`resource` är null vid create) OCH **ägar-arm**; bunden
  `== gammalt ± 1` i BÅDA riktningarna, aldrig bara +1. Provet måste skicka den riktiga
  `FieldValue.increment`-sentineln via den verkliga skrivaren, inte ett heltal.
  Precedens: `firestore.rules:727-731` (`friendsCount`) — sentineln ÄR läsbar i
  `request.resource.data`, verifierat.
- BUT-2092: villkoret måste kedja `.get('metadata', {}).get('poll', {}).get('isClosed', false)`
  på BÅDA sidor och får INTE neka meddelanden utan `metadata` eller utan `poll`-nyckel
  (BUT-1832 beslutade att den formen förblir skrivbar). Fyra fall: metadata saknas / null /
  map utan `poll` / `poll` finns.
- BUT-2086: bindningen gäller **CREATE ONLY** — omgradering är `set(merge:true)`, alltså UPDATE.
- BUT-2101: mät åtkomsttaket med en riktig WriteBatch (N=11, N=21) INNAN regeln skrivs.
- Ingen ny användarsynlig sträng i något av de fyra (Product Manager-sätet); avslag faller
  igenom till befintlig generisk copy, aldrig en text som avslöjar mekanismen.
- Ingen `rateLimitStamped` på `counters` eller `conversation_memberships` — ADR-0020 STRÖK båda.


---

# ARKIV

# Sprint 2026-09-11 (natt) — sex ärenden, fyra kluster

Vald av `/delivery:sprint-execute`. Föregående sprint (2026-09-11 kväll) är stängd och ligger i
arkivet nedan. Steg 0 mot HEAD `ddae7776f` är gjord för alla; greparna står under respektive ärende.
Routern körs om på den filunion som faktiskt delas ut, per kluster.

**Utanför sprinten, med skäl:**
- BUT-2083 — **premissen borta**: `friends_profile_cache_manager.dart:78,84` maskerar redan båda
  id-mängderna (`maskedUserId`), landat i `23b4f8d97` (BUT-2027). Stängs.
- BUT-1826 — **needs-approval**: att få cache-skrivningen att fungera öppnar en skrivväg där vilken
  inloggad klient som helst lägger receptdata (ingredienser, alltså allergener) som ANDRA användare
  läser vid import av samma URL. Det är ett val mellan tre vägar (klientskrivning, serverskrivning,
  ta bort cachen), inte en reparation. Kommentar med rekommendation på ärendet.
- BUT-1716 — väntar redan på Malins val (radera vägen eller landa stashen); kommenterat i kväll.

---

## Kluster M — allergengolvet i närvaro-vägen

### [Tier B] BUT-2076 — oläsbar hushållsmedlem räknas som "inga allergier" (High, menu/Bug)

Disposition: **build**. Säkerhetsfix som följer ett mönster som redan är live (BUT-1663-golvet).
Tier B eftersom den befintliga "rostern är ofullständig"-raden visas i ett nytt läge — ingen ny text.

Steg 0, mätt mot HEAD:
- `menu_generator.dart:261-269` unionerar bara `if (prefs != null)`.
- `household_roster_service.dart:66-72` VET `unavailableIds` (BUT-2027) men returnerar en vanlig lista;
  `:79-80` lägger en oläsbar medlem som `allergenPreferences: null`.
- Totalfel: `getRoster` sväljer felet och returnerar `[]` (`:35`) — då matchar ingen närvarande
  medlem, unionen blir TOM och `_resolveActivePrefs` returnerar den som `present`. Ett ofiltrerat
  resultat, värre än delfallet. Samma fix måste täcka det.
- Hushållsvägens golv: `household_service.dart:81` `_allergenSafetyFloor`, `degraded`, `_floorOnly`.

Router (union `menu_generator.dart`, `household_roster_service.dart`): **`single`**, panel
`["Product Manager"]`, `high_stakes_hits: []`.

Acceptanskriterier:
- [ ] `{text: "En narvarande medlem vars profillasning FELADE (unavailable) breddar allergenunionen med golvet (ENBART allergener, aldrig trackedDietary) och stanger UNKNOWN-luckan; en medlem vars profil SAKNAS (missing) degraderar inte", kind: diff}`
- [ ] `{text: "Totalfel pa rosterlasningen ger inte langre en tom, ofiltrerad union - den faller till golvet eller till hushallsvagen, aldrig till ofiltrerat", kind: diff}`
- [ ] `{text: "Anvandaren ser den befintliga roster-ofullstandig-raden aven i narvarovagen; ingen ny ARB-strang", kind: diff}`
- [ ] `{text: "Test med tre armar (full traff, delvis fel, totalfel), mutationsprovade", kind: diff}`

---

## Kluster R — betyg: en ägaraccessor, en död metod, två regelgrenar

### [Tier A] BUT-2078 — fyra stavningar av "vem äger receptet" (Low, social/tech-debt)

Disposition: **build**. Steg 0: `recipe_rating_system.dart:343,366`, `recipe_social_stats.dart:61,97,234`
skriver `socialData?.ownerId ?? core.createdBy`; `??` fångar inte tom sträng. Premissen gäller (fem
ställen, inte fyra).

- [ ] `{text: "EN accessor pa Recipe dar tom strang raknas som saknad, anvand pa alla stallen i recipe_rating_system.dart och recipe_social_stats.dart (inklusive rateRecipe)", kind: diff}`
- [ ] `{text: "Ett test som rodnar om accessorn slutar behandla tom strang som saknad", kind: diff}`
- [ ] `{text: "Standardfixturen i recipe_rating_system_test.dart har skilda uid for agare och betygsattare", kind: diff}`
- [ ] `{text: "INTE gjort: en oloslig agare nekas inte - Malins beslut 2026-09-11 (BUT-2057) star; firebase_recipe_repository.dart:s egna stavningar ror inte", kind: diff}`

### [Tier A] BUT-2080 — `updateRating` går inte att nå (Low, tech-debt)

Disposition: **build** (radera). Steg 0: anropare i HELA repot är bara definitionerna
(`ratings_repository.dart:24`, `firebase_ratings_repository.dart:193`, `recipe_rating_system.dart:166,191`)
och deras egna tester.

- [ ] `{text: "updateRating borta pa bada lagren, grep over lib/ test/ functions/ tools/ visar noll traffar", kind: diff}`
- [ ] `{text: "Grannskapskommentarer som resonerar om metoden ar strukna", kind: diff}`

### [Tier C] BUT-2077 + BUT-2079 — `recipe_ratings`/`recipe_comments` regelgrenar (Medium, backend/security)

Disposition: **build**, parkeras In Review (full panel, `panelPolicy: park`).

Steg 0:
- UPDATE-grenen `firestore.rules:2622-2630` saknar `isAgeCompliant()` och `rateLimitWrite`.
- **`rateLimitWrite` är inert här**: ingen kod i `lib/` skriver `users/{uid}/rate_limits/recipe_ratings`
  (grep på `rate_limits`/`userRateLimits` ger bara konstanten), och hjälparen släpper igenom när hinken
  saknas (`firestore.rules:203-207`). Samma läge som BUT-2038, där Malin 2026-09-09 beslöt att INTE
  lägga till en inert spärr. BUT-2077 kriterium 1 tillåter "skrivet varför".
- Create-grenarna: `recipe_ratings` `:2599`, `recipe_comments` `:1418`, båda `hasRequiredFields` utan `hasOnly`.

Router: se Fas 1.4 nedan.

- [ ] `{text: "BUT-2077: UPDATE-grenen har isAgeCompliant(); regeltest bade allow och deny, mutationsprovat", kind: diff}`
- [ ] `{text: "BUT-2077: rateLimitWrite laggs INTE till pa update; regelkommentaren sager varfor (ingen skrivare stamplar hinken), och en foljdbiljett for en verklig broms pa update-recipe-rating-stats ar filad", kind: diff}`
- [ ] `{text: "BUT-2079: bada create-grenarna har keys().hasOnly, upprknat mot varje skrivvag med fil och rad (inkl. recipeOwnerId och kommentarernas resolver-null-vag)", kind: diff}`
- [ ] `{text: "BUT-2079: regeltest per samling - ett odeklarerat falt NEKAS, appens riktiga payload TILLATS, och en omsattning (merge) av en befintlig rad TILLATS", kind: diff}`
- [ ] `{text: "BUT-2079: data_minimisation-meningen om falt som kan saknas ar struken eller fortfarande sann", kind: diff}`

---

## Kluster P — stängning av omröstning

### [Tier A] BUT-1925 — en upprepad stängning kan lägga samma recept två gånger (Medium, social/Bug)

Disposition: **build-review** — detaljen som är Malins: vilket delfel appen väljer (stängd omröstning
utan rätt, eller öppen omröstning som kan köras om).

Steg 0: `message_mutation_module.dart:487` kontrollerar bara `creatorId`; `isClosed` sätts på `:492`
och läses aldrig i `lib/repositories/`. `messaging_service.dart:941-944` skriver planen FÖRE flaggan.

Router (union `messaging_service.dart`, `message_mutation_module.dart`): **`single`**, panel
`["Data Analyst / BI", "Performance Engineer", "Trust & Safety / Content Moderation"]`. Ägande roll: T&S.

- [ ] `{text: "En omkorning efter en halvt misslyckad stangning lagger INTE till receptet en andra gang - bevisat av ett test som simulerar flaggfel efter lyckad planskrivning", kind: diff}`
- [ ] `{text: "Repositoryts closePoll kontrollerar isClosed i samma skrivning (transaktion) och en redan stangd omrostning ger ett urskiljbart svar", kind: diff}`
- [ ] `{text: "Doc-kommentaren ovanfor MessagingService.closePoll beskriver det nya beteendet och pekar inte langre pa BUT-1925 som oppen", kind: diff}`
- [ ] `{text: "Mutationsprovat", kind: diff}`

---

## Fas 1.4 — kritikens bindande villkor

**Kluster R** — router på unionen (7 sökvägar): `full-panel`, 13 säten, alla blinda, alla svarade.
**Kluster M** — `single`, Product Manager. **Kluster P** — `single`, Trust & Safety.

### M (BUT-2076) — PM
- PM mätte: närvaro-vägen kan ALDRIG läsa en annan vuxens allergier (`users/{uid}` ägarläsning
  `firestore.rules:333`, allergier bara i privata inställningar, `fetchProfiles` läser
  `public_profiles`). Andra vuxna kommer tillbaka som "found" utan allergier, INTE som `unavailable`.
  Planens kriterium 1 hade alltså aldrig slagit till för dem.
- M1. Närvaro-vägen använder SAMMA per-medlem-upplösning som hushållsvägen (`household_service.dart:283-372`:
  `lookupUserProfile`, delade listor BUT-1693, golv för `!settingsMerged && shared == null` utan
  degradering, degradering + stängd UNKNOWN för `unavailable`/`foundSettingsUnavailable`, `missing`
  degraderar inte). En kopia av den logiken är förbjuden — extrahera och återanvänd.
- M2. Beslut om golv/degradering tas på läsningens status, aldrig på `prefs == null`.
- M3. Totalfel / ingen närvarande matchar: aldrig `present` med tom union. Resultatet är hushållsunionen
  VIDGAD med golvet, UNKNOWN stängd, källa = ofullständig — inte ren hushållsväg, eftersom den inte
  innehåller barnprofiler (diners) och ett barns allergi då skulle falla bort.
- M4. Två-vuxen-test: den andra vuxna närvarande ger filtrerad pool; ta bort golvet -> testet rodnar.
- Beslutat här, inte Malins: delade listor gäller även närvaro-vägen (samma kod, flaggan styr);
  totalfel = vidgad union (strikt säkrare än båda alternativen PM ställde upp). Syns i In Review-kommentaren.

### R (BUT-2078/2080/2077/2079) — 13 säten
- R1 (Säk, DPO, DBA). UPDATE-grenen på `recipe_ratings` binder vilka nycklar en ändring får röra:
  `diff(resource.data).affectedKeys().hasOnly(['rating','review','updatedAt','recipeOwnerId'])`
  (affectedKeys, inte keys, så äldre rader kan betygsättas om). Test: en merge av ett odeklarerat
  fält in i en befintlig rad NEKAS.
- R2 (Säk, T&S, DBA, QA, PM). Create-listorna härleds ur skrivarens faktiska map, med fil:rad:
  betyg `firebase_ratings_repository.dart:168-181`, kommentarer `firebase_comments_repository.dart:205-227`
  (alla nycklar inkl. `authorDisplayName`, `isDeleted`, `likesCount`, `replyCount`, `parentCommentId`,
  villkorade `recipeOwnerId`, `imageUrls`). Modellens `toFirestore` är INTE källan.
- R3 (QA, PM, DBA). "Riktig payload TILLÅTS" som namngivna fall: betyg med `review: null`, med och utan
  `recipeOwnerId`; kommentar med `parentCommentId: null`, `authorDisplayName`, `updatedAt`, som den
  riktiga batchen (inkl. rate_limits-skrivningen).
- R4 (QA). Alla update-test i `recipe-ratings-rules.test.ts` loggar in med `ageCompliant:true`; ett nytt
  fall NEKAS enbart för saknat anspråk; varje befintlig nekning har en tillåten tvilling som skiljer i en sak.
- R5 (QA). Mutationsprov: ta bort varje `hasOnly` -> "okänt fält nekas" rodnar; ta bort `isAgeCompliant`
  på update -> ålderstestet rodnar.
- R6 (Legal, DPO). Samma `isAgeCompliant()`-hjälpare; DELETE- och READ-grenarna orörda.
- R7 (Säk, Vendor, DBA). Regelkommentaren om rateLimitWrite gäller BARA `recipe_ratings` (kommentarernas
  skrivare stämplar sin hink, `firebase_comments_repository.dart:233-246`) och ger sitt eget skäl utan
  att luta sig på BUT-2038. Följdbiljetten beskriver kostnaden så som koden gör den (utlösaren hoppar
  över oförändrade stjärnor och debouncas per recept; läsningen per körning är obegränsad i storlek)
  och att den är omätt (inte i `MONITORED_SERIES`).
- R8 (DPO, QA). `rules_allowlist_drift_test.dart` utökas: varje nyckel i de nya listorna finns i
  exportens exporterade eller undanhållna lista för samlingen (`activity_export_manager.dart`).
- R9 (Legal, DPO, DBA). Påståendet att create-grenarna saknar `hasOnly` superseras: daterad
  beslutspost i båda avvikelsefilerna (citerar den pensionerade meningen ordagrant) och kommentaren
  i `export_pagination_helper.dart:141-145`. `_dataMinimisation` byte-identisk.
- R10 (Arkitekt, DA). Accessorn ersätter även `recipe_rating_system.dart:77-81`, och
  `recipeRatingOwnerUnresolved` slår till exakt när den gör i dag (båda fälten saknas/tomma).
- R11 (Arkitekt). `ACCEPTED_LARGE_FILES.md`-raden för `firebase_ratings_repository.dart` räknas om ur
  `wc -l` i samma anrop som commit.
- Följdbiljetter: en person kan skapa flera betyg per recept (dok-id kontrolleras inte, Säk);
  review saknar typ/längdtak (Säk — längden N är Malins).

### P (BUT-1925) — T&S
- T&S mätte att planens kriterium 2 (transaktion i repositoryt) INTE stoppar dubbletten: den inaktuella
  förläsningen släpper igenom omkörningen och andra tillägget körs före transaktionen.
- Rätt fix kräver ett nytt fält på planens rätter (omröstningens meddelande-id) i både personlig och
  gruppvecka — modell, serialisering, export och en förfalskningsbar rad på gruppmenyn. Större än
  ärendet beskrev. **Lyfts ur sprinten**, stannar i Todo med den mätta specen som kommentar.

## Deviation log

- [deviation] BUT-1925: planen sa transaktion i repositoryt -> T&S mätte att den inte stoppar dubbletten; rätt fix kräver ett provenansfält på planens rätter -> lyft ur sprinten, spec som kommentar.
- [discovery] BUT-2076: planen antog att andra vuxnas profiler kan läsas -> de kan aldrig läsas; kopplar närvaro-vägen till hushållsvägens upplösning i stället för egen logik.
- [discovery] BUT-2076: närvaro-vägen har ingen anropare i appen (`presentMemberIds` sätts aldrig, BUT-1611 -> BUT-1625) -> fixen härdar en väg som inte är påslagen -> byggd ändå, sägs i In Review-kommentaren.
- [deviation] BUT-2076: planen lade resolvern under lib/viewmodels/menu -> granskningen: affärslogik hör hemma i tjänstelagret -> flyttad till lib/services/menu/.
- [discovery] BUT-2077: ärendets kostnadspremiss ("varje ombetygsättning utlöser en obegränsad läsning") mätt falsk -> utlösaren hoppar över oförändrade stjärnor och debouncas; det obegränsade är läsningen per körning -> BUT-2084.
- [deviation] BUT-2079: panelen krävde nyckelbindning även på UPDATE (affectedKeys) -> byggd, annars kringgås create-listan med en merge.
- [needs-human] BUT-2079: recensionens längdgräns är Malins -> fråga på ärendet.
- [discovery] Linear vägrade nya ärenden efter BUT-2084 -> tre följdpunkter som kommentarer på BUT-2071, BUT-1823 och BUT-2079; en fjärde på BUT-2078.

## Slutstatus (2026-09-11 natt)

- **Kluster R — `ac4eb8d6a`, pushad.** BUT-2078 och BUT-2080 **Done** (Tier A, alla kriterier pass).
  BUT-2077 och BUT-2079 **In Review** (regeländring, full panel, `panelPolicy: park`); 16/16 kriterier
  pass hos fristående kontrollant. Regelsviter 16/16 + 29/29, Dart 116/116.
- **Kluster M — se commit nedan.** BUT-2076 **In Review** (Tier B): 7/7 kriterier pass, 69/69 i
  kontrollantens körning. Närvaro-vägen har ingen anropare i appen än (BUT-1625), så fixen härdar en
  väg som inte är påslagen.
- **Utanför:** BUT-2083 stängd (redan fixad i `23b4f8d97`); BUT-1826 needs-approval med
  rekommendation; BUT-1925 lyft ur med mätt spec; BUT-1716 väntar på Malin.
- **Följdpunkter:** BUT-2084 (ny). Linear vägrade fler ärenden, så resten ligger som kommentarer:
  BUT-2071 (flera betyg per person), BUT-2079 (recensionens längd — Malins), BUT-1823 (kommentarernas
  skrivare ej knuten till listan), BUT-2078 (två grannfiler med gamla ägarstavningen), BUT-1694
  (möjligt levande fel: ny användare utan inställningar kan få en helt vegansk meny — omätt).
- **Grindar:** varje .dart-, regel- och testfil granskad av sin grind; alla slutverdikt pass.

---

# Sprint 2026-09-11 — sju ärenden, fyra kluster

Vald av `/delivery:sprint-execute`. Föregående sprint (2026-09-11) är stängd
(Slutstatus fylld, allt committat) och ligger i arkivet nedan.

**Routing körs PER KLUSTER**, eftersom utdelningen sker kluster för kluster. Rå utdata från
`python tools/stakeholder_router.py --json` står under varje kluster. Utdelningen sker i den
här sessionen, som KAN sammankalla — så varje kritik körs FÖRE bygget. Ändras ett klusters
filunion före bygget körs routern om på den union som faktiskt delas ut.

Steg 0 mot HEAD är gjord för alla sju; greparna står under respektive ärende.

Genomgående tema: **fyra av sju ärenden är samma klass** — ett skydd som kör men inte mäts,
eller en kontroll som rapporterar grönt fast den inte gjort sitt jobb. Repot har en lärdom om
precis den formen ("en otestad UTFÄSTELSE och en hållen utfästelse är samma artefakt").

---

## Kluster A — två säkerhetsspärrar som går live omätta

Router: **`single`**, panel `["Data Analyst / BI", "Growth Marketer / ASO",
"Monetization / Subscriptions Lead", "Performance Engineer", "Product Manager",
"Trust & Safety / Content Moderation", "Vendor / Procurement Manager"]`,
`high_stakes_hits: []`. Ägande roll för kritiken: **Data Analyst / BI**.

### [Tier A] BUT-2073 — blockeringsspärren på betyg går live omätt (Low, analytics/social)

Disposition: **build**. Ren mätbarhet, inget produktval — Malin har redan beslutat
BÅDA halvorna (2026-09-11): behåll skrivningen vid olöslig ägare, och mät den.

Steg 0, mätt mot HEAD:
- `firebase_ratings_repository.dart:140,165-178` skriver `recipeOwnerId` när ägaren går att lösa upp (utelämnar nyckeln annars). Stämplingen finns alltså.
- Ingen träff på `permission-denied` i betygsvägen — inget fångar det nekade anropet.
- `RecipeRatingSystem.rateRecipe` (`lib/services/unified/operations/modules/recipe_rating_system.dart:31`) är stället där ägaren löses upp.

Premissen gäller: två räknare saknas, båda.

Acceptanskriterier:
- [ ] `{text: "En nekad betygsskrivning (permission-denied fran rateRecipe) producerar en raknebar signal utan uid och utan fritext", kind: diff}`
- [ ] `{text: "En andra raknare: RecipeRatingSystem.rateRecipe naar skrivningen med OLOSLIG agare (bade socialData.ownerId och core.createdBy saknas/tomma). Raknas separat fran den forsta - de mater motsatta halvor (spaerren slaar till / spaerren kor aldrig) och faar inte slaas ihop", kind: diff}`
- [ ] `{text: "Test som visar att signalen skrivs paa ett nekat anrop och INTE paa ett lyckat, och ett som visar den andra raknaren paa ett recept utan bada agarfalten", kind: diff}`
- [ ] `{text: "Mutationsprovat: ta bort vardera emitteringen och se respektive test rodna", kind: diff}`
- [ ] `{text: "INTE gjort: ingen ny nekande felvag for oloslig agare - Malins beslut 2026-09-11 ar att skrivningen fortsatter", kind: diff}`

### [Tier A] BUT-1952 — spamspärren går live blind (Medium, social)

Disposition: **build**. Villkor från Trust & Safety-panelen 2026-08-26, inte ett produktval.

Steg 0, mätt mot HEAD:
- `functions/src/social/duplicate-content-guard.ts:461` har EN `logger.info` vid märkning och inget annat. Ingen räknare, inget `system_event`, inget dagligt aggregat.

Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "En markning av ett dubblettmeddelande producerar en raknebar signal - raknare, system_event eller dagligt aggregat - utan uid och utan meddelandetext", kind: diff}`
- [ ] `{text: "Signalen gaar att lasa utan att oppna en anvandares data", kind: diff}`
- [ ] `{text: "Test som visar att signalen skrivs vid en markning och inte vid ett vanligt meddelande", kind: diff}`
- [ ] `{text: "Mutationsprovat", kind: diff}`
- [ ] `{text: "INTE gjort: ADR-0007:s lucka om admin-insyn och overklagandevag - egen biljett, roers inte har", kind: diff}`

---

## Kluster B — täckningsrapporten ser inte fyra (nu sex) regelsviter

Router vid urval, med probsömmen inne: **`full-panel`** (åtta säten), dragen in av EN fil —
`functions/src/__tests__/weekly-menu-plans-rules.test.ts`.

**Omfånget krympt vid utdelning, och routern körd om på den union som faktiskt delas ut**
(regeln säger uttryckligen att krympningen är den riktning som brukar missas):
`python tools/stakeholder_router.py --json functions/scripts/rules-coverage-report.js package.json functions/package.json`
→ **`single`**, panel `["Vendor / Procurement Manager"]`, `high_stakes_hits: []`.
Ägande roll: **Vendor / Procurement Manager**.

Probsömmen på veckoplanernas regeltest lyfts UR bygget och filas som egen uppföljning. Den
är BUT-1966:s "ta samtidigt"-bonus, inte defekten, och den ensam kostar en åttasätespanel.
Defekten — upptäckten i rapporten plus grinden som jämför två tal — är orörd av krympningen.

### [Tier C] BUT-2011 + BUT-1966 — samma defekt, två biljetter (båda Medium, test-gap)

Disposition: **build**. Byggs som ETT arbete; båda stängs mot samma commit.

Steg 0, mätt mot HEAD:
- `functions/scripts/rules-coverage-report.js:487,489` kräver strängliteral i båda sökuttrycken.
- `grep -rln PROBE_PROJECT_ID functions/src/__tests__/*.ts` ger sex filer.
- **Men FYRA av dem är osynliga för upptäckten, precis som båda biljetterna säger.** Mätt genom att köra upptäckten före och efter: 32 sviter före, 36 efter. De fyra är `chat-groups`, `conversations`, `cook-snaps-and-message-mod`, `poll-votes`. De andra två (`blocks`, `delivered-notifications`) håller konstanten som en BAR literal och lägger override:n på anropsstället — med en kommentar som förklarar varför, alltså en känd kringgång av just den här buggen.
- 36 `*-rules.test.ts` på disk; `test:rules:all` namnger 45 sviter.

Premissen gäller. **Rättelse av den här planens egen text:** ett tidigare utkast
påstod att omfånget var SEX och att siffran fyra i båda biljetterna var stale. Det
var fel, och mätningen ovan motbevisar det. Biljetterna hade rätt; inget ska rättas
i dem.

Acceptanskriterier:
- [x] `{text: "De fyra osynliga sviterna bidrar till tackningsunionen. Verifierat genom att kora UPPTACKTEN fore och efter: 32 sviter fore, 36 efter", kind: diff}` — MATT
- [ ] `{text: "Sommen fungerar fortfarande: PROBE_RULES_PATH/PROBE_PROJECT_ID pekar om projektet paa minst en av de fyra", kind: diff}`
- [ ] `{text: "Rapporten FALERAR (eller rodnar en grind) nar antalet upptackta sviter ar farre an antalet *-rules.test.ts paa disk - det ar jamforelsen av tvaa tal som gjorde hela klassen tyst", kind: diff}`
- [ ] `{text: "INTE gjort: probsommen paa weekly-menu-plans-rules.test.ts. Lyft ur omfanget vid utdelning for att en enda testfil drog in en attasatespanel; filad som egen uppfoljning innan commit", kind: diff}`
- [x] `{text: "INGEN rattelse behovs i biljetterna: de sager fyra, och fyra ar matt korrekt. Det var den har planens forsta utkast som sa sex, och den meningen ar struken", kind: diff}` — MATT
- [ ] `{text: "Rapporten kord fore och efter mot en emulator, med bada utdata inklistrade i sprintrapporten", kind: run}`

---

## Kluster C — en commit-grind rapporterar grönt fast skalet felade

Router: **`single`**, panel `["DevOps / SRE"]`, `high_stakes_hits: []`.
Ägande roll: **DevOps / SRE**.

### [Tier A] BUT-2061 + BUT-1921 — samma defekt, två sightings (Medium + Low, tech-debt/Bug)

Disposition: **build**. BUT-1921 ligger redan i Todo och säger att källan är ohittad;
BUT-2061 är samma symptom sett igen med mer utdata. De byggs som ett arbete.

Steg 0, mätt mot HEAD:
- `lefthook.yml:26` (`secret-scan`) slutar på `... && exit 1 || true`. Den `|| true` är där för att grep-rc=1 ("ingen träff") inte ska fälla steget — men den sväljer **också** ett äkta fel. Det är exakt punkt 3 i BUT-2061: egenskapen, inte symptomet.
- `lefthook.yml:143-147` (`null-filter-guard`) startas med `bash`, inte `sh` — meddelandet sade `sh: line 2`, så steget som äger utdatan är ännu inte identifierat.

Premissen gäller. **Viktigast är punkt 3**, inte att hitta det ena `[`-uttrycket.

Acceptanskriterier:
- [ ] `{text: "Det steg som ager sh: line 2-utdatan ar IDENTIFIERAT med namn, eller sa ar det skrivet rakt ut att det inte gick att reproducera - ingen gissad orsakssats", kind: diff}`
- [ ] `{text: "Roten: inget commit-grindsteg kan langre skriva till stderr, fela, och anda rapporteras groent. Konkret ska secret-scans avslutande || true inte langre svalja en icke-noll status som INTE ar grep-rc=1", kind: diff}`
- [ ] `{text: "Varje ovrigt steg i lefthook.yml ar genomgaanget for samma form (|| true, pipe utan pipefail, ociterad variabel i ett test-uttryck) - uppraknat med radnummer, inte bara det steg som raakade synas", kind: diff}`
- [ ] `{text: "Ett negativt prov: ett avsiktligt trasigt kommando i ett steg FALLER commiten i stallet for att rapporteras groent", kind: diff}`

---

## Kluster D — artikel 15-bunten motsäger sig själv om en sen medlems chatthistorik

Router: **`full-panel`**, panel `["Data Analyst / BI", "Financial Controller / FinOps",
"Legal Counsel", "Performance Engineer", "Privacy / Data Protection Officer (GDPR)",
"Product Manager", "Security Architect", "Software Architect",
"Trust & Safety / Content Moderation"]`,
`high_stakes_hits: ["lib/services/account/export/social_export_manager.dart"]`.

### [Tier C] BUT-1854 — exporten hedrar `memberSince` i ena halvan (High, account/social/security)

Disposition: **build — Malins uttryckliga val, 2026-09-11: alternativ A.**

Ärendet var på väg att parkeras som `needs-approval`, för att kommentarskontrollen på
kortlistan hittade en OBESVARAD fråga på biljetten från 2026-08-23: A eller B, ställd
direkt till Malin, aldrig besvarad. Att bygga A då hade varit att svara åt henne.
Hon är närvarande i den här sessionen (hon skrev kommandot), så frågan ställdes om i stället
för att parkeras en andra gång, och hon valde **A**.

Vad hon SÅGS: att appen redan vägrar visa meddelanden som skickades innan man gick med, att
exporten utelämnar dem i ena halvan men skickar med "senaste meddelande"-förhandsvisningen
i den andra, samt vad A och B kostar var för sig.
Vad hon INTE sågs, sagt rakt ut eftersom en attribution är ett påstående om en person som
inget test kan hålla: ingen har mätt hur ofta en gruppchatts senaste meddelande faktiskt
predaterar en medlems inträde, och T&S-sätets följdfråga (ska en bortsållad förhandsvisning
gå att skilja från en som aldrig funnits) ställdes till henne först efter bygget.

Steg 0 mäts i Fas 2 mot de två filerna biljetten namnger (rad 376-386 respektive 184-197).
**Om raderna flyttat sedan 2026-08-15 gäller premissen ändå bara om BÅDA halvorna
fortfarande finns — annars är ärendet obsolet och stängs.**

Acceptanskriterier:
- [ ] `{text: "En sen medlems bunt utelamnar conversations.lastMessage nar den predaterar personens egen memberSince-stampel, och behaller den nar den inte gor det", kind: diff}`
- [ ] `{text: "EN delad hjalpare for predikatet, inte en andra kopia - BUT-1798-posten finns for att tre sektioner som implementerar ett beslut var for sig ar hur de driver isar", kind: diff}`
- [ ] `{text: "Test paa bada fallen, mutationsprovat", kind: diff}`
- [ ] `{text: "INTE gjort: den tredje stavningen av avskarningen (raa kartlasning for Firestore-intervall) konsolideras INTE - koden sager varfor, och biljetten sager uttryckligen att den inte ska roeras", kind: diff}`
- [ ] `{text: "Parkeras In Review med valet A-mot-B skrivet paa vanlig svenska till Malin", kind: diff}`

---

## Fas 1.4 — kritikernas villkor, infällda som bindande

Alla kritiker körda FÖRE bygget. Metrikrader loggade (`docs/org/metrics/events.jsonl`).

### Kluster A — Data Analyst / BI
1. **BUT-2073 kan bara nå GA4, och det är en känd blind fläck.** Klienten har just fått en
   Firestore-skrivning nekad, så den kan inte också skriva en Firestore-räknare.
   `AnalyticsEvents` är enda nåbara ytan — men adminpanelen läser
   `analytics/{group}/daily/{date}`-aggregat, inte GA4. **Båda nya konstanterna ska bära
   samma varningskommentar som `messageSendDeniedClockAhead`** (`analytics_events.dart`),
   inklusive dess samtyckesförbehåll. Skriv INTE att siffran syns i panelen.
2. **Räknare (b) behöver en nämnare.** "Nära noll" kräver något att vara nära noll MOT.
   Läs den som kvot mot `recipeRated` ur SAMMA GA4-ström — en Firestore-hämtad nämnare
   snedvrider kvoten via olika samtyckesgrindar.
3. **BUT-1952 skriver ett `system_events`-dokument, inte en ny samling.** Då plockas den
   upp gratis av `runOpsSnapshot`s `byType`-hink (`functions/src/analytics/daily-snapshots.ts`).
4. **Två skilda `type`-värden för chatt och kommentar, aldrig hopslagna** — filen ägnar
   fyrtio rader åt att slå fast att de två ytorna är asymmetriska (ADR-0009). Om
   `guardDuplicateComment` lämnas oräknad ska det stå rakt ut, inte glida.
5. Namnge konstanterna smalt. Och: chattens räknare läser NOLL så länge
   `enable_chat_duplicate_guard` är av — det får inte gå att läsa som "inga dubbletter".

### Kluster B — Vendor / Procurement Manager
1. **Sluta regexa över källkod.** Härled sviterna ur `test:rules:all`-kedjan i
   `functions/package.json` — den strängen parsas redan av
   `functions/scripts/check-test-registration.js`. **Dela den parsern**; en fjärde
   parser av ett och samma faktum är defekten en nivå upp.
2. **Räkna INTE unika projekt-id mot antal filer på disk.** `discoverProjectIds()` ger en
   MÄNGD; två sviter får dela projekt-id, och då larmar grinden varje körning på ett
   friskt repo. Jämför mot samma auktoritativa population som `check-test-registration.js`
   redan beräknar.
3. "0 upptäckta" (totalt avbrott) och "N-1 av N" (en svit tappad) får inte skriva samma text.
4. `PROBE_PROJECT_ID` sätts ingenstans i något workflow eller skript i dag, så
   reservvärdet är alltid det som gäller. Att fånga reservvärdet är rätt NU och tyst fel
   den dag någon sätter variabeln — skriv det i kommentaren, låt det inte se stängt ut.

### Kluster C — DevOps / SRE
1. **`secret-scan` kan aldrig fälla en commit.** `A && B && exit 1 || true` är
   vänsterassociativt, så `|| true` sväljer det AVSIKTLIGA `exit 1` — inte bara grep:s
   ofarliga "ingen träff". Vakten som ska hitta läckta nycklar är inert. Det här är
   allvarligare än symptomet i biljetten.
2. **Attributionen är AVGJORD, mätt:** `secret-scan` är det ENDA `run:`-värdet i
   `lefthook.yml` som blir flerradigt efter YAML-tolkning, och dess `[` ligger på rad 2 —
   vilket är exakt vad `sh: line 2` pekar på. Orsaken till flerradigheten är att `run:`
   är en YAML-**dubbelciterad** skalär, så `'\n'` blir ett riktigt radbrott.
   **Men:** att köra den tolkade strängen under `sh` och `bash` med en tvåfilslista
   återskapar INTE `[`-felet (rc=0 båda). Alltså: platsen är mätt, den utlösande indatan
   är det inte. Ingen orsakssats skrivs om den senare.
3. Två fler av samma form, båda kastar rörledningens utgångsstatus och testar bara
   innehåll: `tools/check_null_filter.sh:133-136` och `tools/check_staged_arch_guards.sh:25-36`.
4. Fixens form: flytta det avsiktliga felet in i ett `if`, så att inget följer efter det
   som kan svälja det. Och bevisa den med en `--self-test` enligt `check_null_filter.sh`s
   mall, inkopplad i `script-guard-tests`.

### Kluster D — nio säten i två grupper. EN konflikt, avgjord genom MÄTNING.
Ingen konflikt inom respektive grupp. Mellan grupperna: `Security Architect` gjorde det
bindande att jämföra `lastMessage['sentAt']` som en rå `Timestamp`; `Software Architect`
mätte att exporthanteraren ser ISO-**strängar**. Jag mätte om:
`social_export_manager.dart:272-273` anropar `_redactOtherParticipants(sanitizeForJson(convo['data']))`
— alltså strängar. **Software Architect har rätt; Security Architects villkor bygger på en
felaktig premiss och är inte bindande i den formen.**
Vad som däremot står kvar av det villkoret, och är bindande: det ska finnas EN stavning av
jämförelsen i kodbasen. Lösningen som uppfyller båda säten: bryt ut själva jämförelsen ur
`Conversation.canReadMessageAt` till en fristående funktion som metoden själv anropar, och
låt exporthanteraren tolka sina två ISO-strängar och anropa SAMMA funktion.
Repositoryts Firestore-gräns förblir den avsiktliga tredje stavningen och rörs inte.

Övriga bindande villkor från kluster D:
1. **Ordningen är bärande.** Slingan på rad 161-183 kollapsar redan `copy['memberSince']`
   till `{userId: ownStamp}` — eller raderar fältet helt på sin fail-closed-gren — INNAN
   `lastMessage`-blocket körs. Predikatet måste läsa stämpeln före den reduktionen, annars
   testar det mot ingenting.
2. **Frånvaro avgörs per fall, aldrig med en förvald sida.** 1:1-chatt (`groupId == null`)
   → behåll alltid, `memberSince` gäller inte där. Gruppchatt med uid saknat i kartan →
   fail closed, alltså släng, precis som `canReadMessageAt` redan dokumenterar.
3. `redaction_fell_back: true` på en okänd form — men INTE som signal för ett
   policybeslut. T&S: en slängd förhandsvisning och en chatt som helt saknar en får inte
   bli oskiljbara genom att återanvända en flagga som betyder "form vi inte känner igen".
4. **`data_minimisation`-prosan behöver en ny mening.** Klassningen är avgjord av alla tre
   säten: det här är den sökandes EGET utfall, inte en tredje parts faktum, så BUT-2056:s
   byte-invarianskrav binder den INTE — den får variera. Om den blir villkorad ska
   villkoret pinnas av ett test, som BUT-2014:s `chatGroupsNote`-ternär.
5. `social_export_manager.dart` ligger på 677 rader mot en `ACCEPTED_LARGE_FILES`-rad som
   säger 677. Varje tillägg spräcker den — raden räknas om i SAMMA commit, ur `wc -l`.
   (`firebase_data_export_repository.dart` står på 1199 mot uppmätta 1205. Förbefintlig
   drift, rörs inte av den här ändringen, filas separat.)
6. **Fixturluckan är verklig och mätt** av QA-sätet: i
   `test/unit/services/account/export/social_export_manager_test.dart` stagar
   `memberSince`-testerna (1159-1235) inget `lastMessage`, och `lastMessage`-testerna
   (1035-1109) stagar varken `groupId`, `memberSince` eller `sentAt`. **Ingen befintlig
   fixtur kan nå den nya grenen.** En ny måste byggas; en återanvänd ger ett grönt test
   som pinnar ingenting.
7. Mutationsprovet måste vända BÅDE ett behåll- och ett släng-fall, inte bara ett.

### Öppen fråga till Malin, buren vidare (ej byggd)
T&S vill att en bortsållad förhandsvisning ska gå att SKILJA från en chatt som aldrig haft
någon. Det ligger utanför vad "släng `lastMessage` när den predaterar `memberSince`"
bokstavligen säger, och de två andra sätena hade det inte med. Byggs INTE här; ställs till
henne i slutrapporten.

## Slutstatus (2026-09-11)

Sprinten är stängd. Sju ärenden, sju kodcommits.

| Ärende | Commit | Läge |
|---|---|---|
| BUT-2061 + BUT-1921 | `9e5d401fc`, `fe929b219`, `cbcc16d85`, `ed39dca7e` | Done |
| BUT-2011 + BUT-1966 | `930a3b710` | **In Review** — kriterium 4 kräver en levande emulatorkörning |
| BUT-2073 | `d45769834` | Done |
| BUT-1952 | `d45769834`, `fe929b219` (kartan) | Done |
| BUT-1854 | `abeb79068` | **In Review** — GDPR, Malins val A i dag |

Utfallsverifieraren (färsk kontext, inte implementatören): BUT-2073 och BUT-1952 alla
kriterier godkända; BUT-2011/1966 1–3 godkända, 4 väntar på körning; BUT-2061/1921
underkänd två gånger — `check_swedish_boundary.sh` och sedan null-filter-vaktens
filtrerande grep — och godkänd på tredje körningen efter `fe929b219` och `cbcc16d85`.

Grindar: alla fem på kluster A, tre på BUT-1854, efter tre rundor vardera. Varje
blockerande fynd efter första rundan var en mening jag skrivit som rättelse.

Två beslut av Malin i sessionen: BUT-1854 alternativ A, och T&S-följdfrågan (ingen
markering per rad). Båda registrerade på biljetten.

Veckogränsen för Opus nåddes en gång; ingen grind nedgraderades för att komma förbi.

Lessons-post + digestrad skrivna i samma redigering (CLAUDE.md regel 9).

## Needs you (Tier D)

Inga i den här batchen.

## Behöver Malin (parkerade / ej valda)

- **BUT-2072** (`need-malin`) — receptägarens uid på andras betygsrader nås av ingen radering. Direkt syskon till BUT-2073. Inte valt: det är en ren fråga till Malin, inte ett bygge.
- **BUT-1854** parkerar i In Review med A-mot-B-valet, se ovan.

## Deviation log

- [deviation] Kluster B: planen sa att probsömmen på `weekly-menu-plans-rules.test.ts` skulle ingå → routern gav `full-panel` med åtta säten, draget in av den ENDA filen → lyfte ur den, körde om routern på den union som faktiskt delas ut (`single`), och filade resten som kommentar på BUT-1966.
- [discovery] Kluster B: mätningen motbevisade planens egen siffra. Planen sa SEX osynliga sviter; upptäckten före/efter ger 32 → 36, alltså FYRA, precis som båda biljetterna säger. Planens mening struken, biljetterna orörda.
- [discovery] Kluster B: en FEMTE svit var trasig på ett sätt ingen biljett beskriver. `blocks-rules.test.ts` bär en kommentar som ordagrant innehåller `PROJECT_ID = "..."`, och det gamla mönstret använde `exec` (första träffen) — så den bidrog med projekt-id:t `...` och aldrig sitt riktiga. Fetchen rapporterade det påhittade projektet som en vanlig "skip", alltså ett friskt utseende. Hittad av ett av de nya testerna, inte av läsning.
- [discovery] Kluster C: `secret-scan` kunde inte fälla en commit i något läge — `&& exit 1 || true` svalde sitt eget avsiktliga fel. Allvarligare än symptomet biljetten beskriver, och utanför vad den bad om. Byggt ändå: det är roten biljettens punkt 3 pekar på.
- [discovery] Kluster C: mutant 3 ÖVERLEVDE första omgången — inget fall nådde grenen där grepen själv felar. Luckan stängdes i stället för att beskrivas; den krävde en probsöm, eftersom ingen fixtur kan få grep att fela portabelt.
- [deviation] Kluster C: två syskondefekter av samma form lagades utöver biljetten (`check_null_filter.sh`, `check_staged_arch_guards.sh`). Sex vaktskript med samma `|| true`-form som INTE är inkopplade i pre-commit lämnades — utanför biljettens omfång, namngivna i commit-meddelandet.
- [deviation] Kluster A: ett unit-testfall skrevs som `chat !== comment` och gick inte att kompilera — `as const` gör att TypeScript bevisar att literalerna skiljer sig och avvisar jämförelsen (TS2367). Fallet slogs ihop med värdepinnarna i stället, och varför står i testets kommentar.
- [needs-human] Kluster D: T&S-sätet vill att en bortsållad `lastMessage` ska gå att SKILJA från en chatt som aldrig haft någon. Utanför vad alternativ A bokstavligen säger; de två andra sätena hade det inte med. Byggs inte; ställs till Malin i slutrapporten.
- [discovery] Kluster D: de två panelgrupperna motsade varandra om hjälparens form. `Security Architect` gjorde det bindande att jämföra `lastMessage['sentAt']` som en rå `Timestamp`; `Software Architect` sa ISO-strängar. Mätt: `social_export_manager.dart:272-273` anropar `_redactOtherParticipants(sanitizeForJson(convo['data']))`, och testfixturerna lagrar `memberSince` som `'2026-01-01T01:01:01.000Z'`. Software Architect har rätt. Det bindande som står kvar av det andra villkoret är EN stavning av jämförelsen, inte dess typ.
- [discovery] Linears ärendetak är nått igen, så uppföljningar filas som kommentarer på moderärendena i stället för som egna ärenden.
- [discovery] Veckogränsen för Opus nåddes mitt i kluster D: tre grindagenter dog på HTTP 429. Ingen grind nedgraderades till en billigare modell för att ta sig förbi — det hade varit att kringgå en grind. Ett nytt försök gick igenom när gränsen släppte för sessionen.
- [deviation] ALLA datum jag skrev i sprinten stod som 2026-09-12; det var 2026-09-11. Fångat av code-reviewer-grinden, mätt mot `date` och HEAD:s committid. Rättat i kod på main (`fe929b219`), i den stagade BUT-1854-mängden, i fyra Linear-kommentarer och här. Commit-meddelandena i `9e5d401fc`, `930a3b710` och `d45769834` bär samma fel och kan inte ändras.
- [discovery] Utfallsverifieraren underkände BUT-2061 två gånger, båda gångerna rätt: först `check_swedish_boundary.sh` (`if grep; then … fi; exit 0`, rc=2 i else-grenen), sedan `check_null_filter.sh`s FILTRERANDE grep, som slutade på `|| true` i kod jag själv skrev för biljetten — med en kommentar som bara ursäktade rc=1. Min uppräkning grepade efter strängar och missade formen. Mitt commit-meddelande i `9e5d401fc` påstod att de tre formerna var de enda; det var fel.
- [deviation] Första försöket att laga null-filter-vakten KORRUPTERADE skriptet: redigeringarna applicerades i fel ordning, en infogning ovanför gjorde filterradens index inaktuellt och ersättningen landade tolv rader för högt. Syntaxfel, fångat innan commit; filen återställd ur HEAD med byte-identitet kontrollerad. Andra försöket lokaliserar alla ankare först och applicerar strikt fallande.
- [discovery] Kodgranskaren och helhetsgranskaren underkände BUT-1854 på en mening jag hade "rättat på plats" i `conversation_test.dart` — omformuleringen bar med sig det falska påståendet med ett nytt verb. Samma klass som hela sprinten: rättelsen är där nästa fel hamnar.
- [needs-human] Malins svar på T&S-frågan (2026-09-11): ingen markering per chattrad när förhandsvisningen utelämnas. Registrerat på BUT-1854.

---

# ARKIV — tidigare sprintar

# Sprint 2026-09-11 — sju ärenden, fem kluster

Vald av `/delivery:sprint-execute`. Föregående sprint (2026-09-10 kväll) är stängd
(Slutstatus fylld, allt committat) och ligger i arkivet nedan.

**Routing körs PER KLUSTER**, eftersom utdelningen sker kluster för kluster och skillnaden
mot hela batchens union är stor (hela unionen ger `full-panel` med fjorton säten).
Rå utdata från `python tools/stakeholder_router.py --json` står under varje kluster.
Utdelningen sker i den här sessionen, som KAN sammankalla — så varje kritik körs FÖRE
bygget. Ändras ett klusters filunion före bygget körs routern om på den union som faktiskt
delas ut.

Steg 0 mot HEAD är gjord för alla sju; greparna står under respektive ärende.

---

## Kluster A — blockering på betyg (ett ärende)

Router: **`full-panel`**, panel `["Customer Support / Operations", "Data Analyst / BI",
"Database Administrator / Data-layer Engineer", "Financial Controller / FinOps",
"Legal Counsel", "Performance Engineer", "Privacy / Data Protection Officer (GDPR)",
"Product Manager", "QA / Test Engineer", "Security Architect", "Software Architect",
"Trust & Safety / Content Moderation", "Vendor / Procurement Manager"]`,
`high_stakes_hits: ["firestore.rules", "functions/src/__tests__/recipe-ratings-rules.test.ts"]`.

### [Tier C] BUT-2057 — blockeringsspärren på betyg körs aldrig (High, Bug/security)

Disposition: **build-review**. Den mekaniska halvan är en ren korrekthetsfix (spärren är
tänkt att köra och gör det inte). Ärendet bär dessutom EN fråga som är Malins och som
INTE byggs: vad som ska hända när receptägaren inte går att lösa upp.

Steg 0, mätt mot HEAD:
- `firestore.rules:2607-2608` bär `!('recipeOwnerId' in request.resource.data) || isNotBlockedBy(request.resource.data.recipeOwnerId)` på `recipe_ratings`.
- `firestore.rules:1439-1440` bär samma form på `recipe_comments`.
- `grep -n recipeOwnerId lib/repositories/firebase/firebase_ratings_repository.dart` ger noll träffar — fältet skrivs aldrig på betygsvägen, så vänsterledet är alltid sant.

Premissen gäller.

**Föreskriven fix som INTE ska byggas:** `hasRequiredFields` på `recipeOwnerId`. Ärendet
mäter att två legitima skrivvägar utelämnar fältet, så det skulle neka varje betygsättning
i appen. Regeln förblir villkorad.

Acceptanskriterier:
- [ ] `{text: "FirebaseRatingsRepository.rateRecipe skriver recipeOwnerId nar agaren gar att losa upp - och varje skrivvag till recipe_ratings ar uppraknad med fil och rad i arendet", kind: diff}`
- [ ] `{text: "Regeltest som visar att en blockerad person NEKAS pa recipe_ratings nar faltet finns, och ett som visar att appens egen payload nu bar faltet", kind: diff}`
- [ ] `{text: "Ingen legitim skrivvag borjar neka: regeln ar fortfarande VILLKORAD, inte hasRequiredFields, pinnat av ett test dar faltet saknas och skrivningen slapps igenom", kind: diff}`
- [ ] `{text: "Steg 1 matt i KOD och skrivet i arendet: nas betygs-UI:t av en blockerad person - grep efter BlockedUserFilter over receptytorna, svaret angivet med fil och rad", kind: diff}`
- [ ] `{text: "INTE gjort: ingen ny nekande felvag for oloslig agare - Malins fraga, star kvar oppen pa arendet", kind: diff}`
- [ ] `{text: "Bada regeltesterna mutationsprovade", kind: diff}`

---

## Kluster B — GDPR-exporten (två ärenden)

Router: **`full-panel`**, panel `["Financial Controller / FinOps", "Legal Counsel",
"Privacy / Data Protection Officer (GDPR)", "Product Manager", "Security Architect",
"Software Architect"]`, `high_stakes_hits`: alla fem exportfilerna.

### [Tier C] BUT-2000 — exportens tidsstämplar är lokal tid utan tidszon (Medium)

Disposition: **build**.

Steg 0, mätt: `grep -rn toUtc lib/services/account/` ger NOLL träffar, medan
`toIso8601String()` står på nio ställen (bl.a. `export_pagination_helper.dart:11-12`,
`preferences_export_manager.dart:366-367`, `compliance_export_manager.dart:229`).
Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "sanitizeForJson i export_pagination_helper.dart ger UTC med Z, och varje handskrivet anropsstalle foljer med i samma commit - uppraknat med fil och rad", kind: diff}`
- [ ] `{text: "Ett test som haller att varje tidsstampel i en bunt slutar pa Z", kind: diff}`
- [ ] `{text: "Varje befintligt test som byggde sin forvantan med lokal DateTime ar genomgatt och rattat - inte tyst lamnat, och inte rattat genom att forsvaga assertionen", kind: diff}`
- [ ] `{text: "Mutationsprovat: ta bort toUtc och se Z-testet rodna", kind: diff}`

### [Tier A] BUT-2055 — exportens felmening pekar på en opinnad nyckel (Low, test-gap)

Disposition: **build**. Ärendet erbjuder två vägar och lutar åt väg 2 (ta bort nyckelnamnet).
**Väg 1 väljs**: behåll nyckelnamnet och PINNA strängen. Den stänger defekten (drift rödnar)
utan att ta bort felsökningsvärdet supporten har av att buntens prosa namnger felkoden.

Steg 0, mätt: `social_export_manager.dart` skriver `chat_groups_error_code`; koden myntas i
`chat_group_export.dart`. Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "Testet asserterar att data_minimisation-prosan innehaller strangen chat_groups_error_code, sa ett namnbyte pa nyckeln rodnar prosan ocksa", kind: diff}`
- [ ] `{text: "Mutationsprovat: byt nyckelnamnet och se bada assertionerna rodna", kind: diff}`

---

## Kluster C — getUserProfiles (ett ärende)

Router: **`single`**, panel `["Software Architect", "Product Manager"]`, inga high-stakes-träffar.

### [Tier C] BUT-2027 — getUserProfiles sväljer sitt eget fel (Medium, Bug)

Disposition: **build**. Malin beslutade 2026-09-05: laga i TJÄNSTEN, inte per anropare.

Steg 0, mätt: `user_service.dart:435` fångar och loggar, returnerar `results`.
Tio anropare; `block_group_member_dialog.dart:80-94` bär en kommentar som namnger just den
här bristen. Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "getUserProfiles ger anroparen mojlighet att se ATT en lasning misslyckades och FOR VILKA id:n - formen ar oppen, men den gamla signaturen far inte tyst behalla sitt beteende for befintliga anropare", kind: diff}`
- [ ] `{text: "block_group_member_dialog.dart anvander signalen och ritar inte langre en tyst delmangd; kommentaren som namnger resten tas bort i samma andring", kind: diff}`
- [ ] `{text: "Var och en av de ovriga anroparna har fatt ett MEDVETET beslut, uppraknat med fil och rad - inte en tyst vidarekoppling", kind: diff}`
- [ ] `{text: "Test som fejkar totalt fel, delvis fel och full traff, och som visar vad blockeringsvaljaren gor i vart och ett av lagena", kind: diff}`

---

## Kluster D — JSON-LD och sanerarens kostnad (två ärenden)

Router: **`single`**, panel `["Data / Integrations Engineer",
"Data / ML Engineer (parsing & tagging integrity)"]`, inga high-stakes-träffar.

### [Tier A] BUT-2035 — tre svar på frågan om något är JSON-LD (Medium, tech-debt)

Disposition: **build**.

Steg 0, mätt: `web_scraper.dart:292` och
`extractors/recipe_site_content_extractor.dart:38` bär båda den exakta attributselektorn,
medan `url_import_strategy.dart:420` och `recipe_scraper.dart:152,164` går via
`isJsonLdMediaType`. Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "Bada DOM-vagarna avgor JSON-LD-het med isJsonLdMediaType, inte med en egen attributselektor", kind: diff}`
- [ ] `{text: "En arla-liknande sida med teckenreferens-stavat plustecken i type-attributet ger strukturerad data hela vagen till utvinningen - test pa DOM-vagen, inte bara pa saneraren", kind: diff}`
- [ ] `{text: "charset-varianten fungerar pa DOM-vagen, med eget testfall", kind: diff}`
- [ ] `{text: "Mutationsprovat: aterinfor den exakta selektorn och se bada nya fallen rodna", kind: diff}`

### [Tier A] BUT-2066 — check() kan stanna huvudisolatet ~1s (Low, performance)

Disposition: **build**. Ärendet bär `code-reviewer`-grindens rekommendation: **tak på hur
många skript-issues loopen rapporterar**, eftersom det binder ALLA former, till skillnad
från predikat-snabbvägen som bara binder de billiga.

Steg 0, mätt: `html_sanitizer.dart:77` och `:181` bär 5 MB-spärren; snabbvägen
`contains('type')` finns i samma fil. Premissen gäller.

Acceptanskriterier:
- [ ] `{text: "Loopen rapporterar hogst N skript-issues och lagger darefter EN samlad issue - taket bunder alla taggformer, inte bara de billiga", kind: diff}`
- [ ] `{text: "sanitize-vagens preserveWhen ar kontrollerad for samma kostnadsform - lagad eller namngiven som fri, med fil och rad", kind: diff}`
- [ ] `{text: "Test som pinnar taket, och ett som visar att en vanlig sida med tiotals skript beter sig ofrandrat", kind: diff}`
- [ ] `{text: "Mutationsprovat: hoj taket och se takfallet rodna", kind: diff}`

---

## Kluster E — bidragsgivartaket (ett ärende)

Router: **`single`**, panel `["QA / Test Engineer", "Security Architect",
"Vendor / Procurement Manager"]`, inga high-stakes-träffar.

### [Tier A] BUT-2058 — takets flerpersonsaritmetik är opinnad (Low, test-gap)

Disposition: **build**. Rent testarbete; ingen produktionskod ändras om aritmetiken visar
sig korrekt — och om den inte gör det är det en korrekthetsfix.

Steg 0: `functions/src/groups/group-menu-access.ts` bär villkoret
`unrecorded.length === 0 || known.length + unrecorded.length <= MAX_CONTRIBUTOR_UIDS`.
Premissen kontrolleras mot filen som första steg i bygget.

Acceptanskriterier:
- [ ] `{text: "Ett fall dar known ligger strax under taket och TVA eller fler avgaende skulle ta det over: unionen hoppas over HELT och ERROR-loggas, inte trunkeras", kind: diff}`
- [ ] `{text: "Ett fall exakt pa gransen som slapps igenom", kind: diff}`
- [ ] `{text: "Mutationsprovat med en mutant som KOMPILERAR: byt <= mot < och se gransfallet rodna", kind: diff}`

---

## Needs you (Tier D / behöver Malin)

Inget ärende i den här batchen är ops-blockerat. Följande valdes bort och är dina:

- **BUT-2057:s öppna fråga** — vad ska hända när receptägaren inte går att lösa upp? I dag
  skrivs raden utan spärr. Alternativen är att neka (ny synlig felväg, ingen copy skriven)
  eller behålla fallbacken och stänga luckan på annat sätt. Byggs inte här.
- **BUT-2045** — kör `reset-user-data --dry-run` skarpt före lansering. Kräver konsolåtkomst.
- **BUT-1989** — QA-svep på fysisk telefon (BUT-1179, 1361, 1368, 1649).
- Allt med `need-malin`: BUT-2033, BUT-2031, BUT-2013, BUT-2006, BUT-1731.

## Avvaldes, med skäl

- **BUT-2050** (flakig `blocks-rules.test.ts`) — ärendets klart-när är nästan helt
  `run`-kriterier (fånga FAIL-raden i loop, tjugo gröna körningar mot emulator). En
  obevakad sprint kan inte producera dem. Står kvar i Backlog.
- **BUT-2048** (sprintmotorns precondition litar på självrapporterad dirtyFiles) —
  **premissen borta**: `sprint-execute-parallel.js:198-202` läser numera `porcelain`
  ordagrant och jämför. Stängs som obsolet med hänvisning till commit b56454bd2.

## Deviation log

- [discovery] BUT-2048: premissen borta, stängd som obsolet mot commit b56454bd2. Ingen kod.
- [deviation] BUT-2057: ärendets föreskrivna fix (`hasRequiredFields`) byggdes INTE — mätt
  att den nekar varje betyg i appen. Villkorad spärr + klientstämpel i stället.
- [deviation] BUT-2057: `cannotModify(['recipeOwnerId'])` byggdes INTE — mätt att
  `affectedKeys()` rapporterar övergången frånvarande -> närvarande, så varje äldre rad hade
  blivit omöjlig att ombetygsätta. Förfalskningsbarheten filad som BUT-2071.
- [needs-human] BUT-2057:s öppna fråga (vad händer när ägaren inte går att lösa upp) är kvar
  hos Malin. Beteendet är oförändrat, men nu ett medvetet val i stället för en bieffekt.
- [discovery] Linears ärendegräns tog slut efter BUT-2075. Senare uppföljningar ligger som
  kommentarer på föräldrabiljetten.
- [discovery] Tre grindrundor på BUT-2057, och varje blockerande fynd efter det första låg i
  TEXT — inte i kod. Ett rött prov (fixturens användar-id), ett falskt påstående i min egen
  kommentar om null-riktningen i reglerna, och ett daterat påstående i en ORÖRD fil som den
  här ändringen gjorde falskt. Lessons-posten bär mönstret.
- [deviation] Arbetsflödeskartan: en regex-rundtur över `<script id="data">` raderade allt
  utanför blocket. Återställd från HEAD, gjord om som värdebyte i råtexten.

---

## Slutstatus (2026-09-11)

Sprinten är stängd. Fem commits, alla pushade till main.

| Ärende | Commit | Läge |
|---|---|---|
| BUT-2058 | `fe165cb0b` | Done |
| BUT-2035 + BUT-2066 | `4b2f15bbf` | Done |
| BUT-2000 + BUT-2055 | `6db7ae0a7` | Done |
| BUT-2027 | `23b4f8d97` | Done |
| BUT-2057 | `1a9d133e9` | **In Review** (build-review) |
| BUT-2048 | — | Stängd som obsolet (b56454bd2) |

Grindar på BUT-2057: `code-reviewer`, `firebase-backend-security`, `testing-specialist`,
`cloud-functions-specialist`, `integration-reviewer` — alla pass (0 blockerande) på de
bytes som faktiskt shippade, efter tre rundor.

Arbetsflödeskartan: tre steg omskrivna, markören borttagen, lintern grön
(371 noder, 54 flöden, täckning 143/137).

Lessons-post + digestrad skrivna i samma redigering (CLAUDE.md regel 9).

Kvar hos Malin: BUT-2057:s öppna fråga, plus det som redan stod under "Needs you".

# ARKIV — tidigare sprintar

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
