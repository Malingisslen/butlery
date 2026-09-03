# Sprint 2026-09-03 — BUT-1917 som huvudnummer, plus tre exportrester

## Context

`/delivery:sprint-execute` kördes utan argument. Backloggen har 110+ öppna ärenden. Efter
mätning mot koden på `main` (inte mot ticketexterna) valdes fyra att bygga, ett att stänga
utan bygge, och ett att skriva om.

**Malins beslut i den här sessionen:** BUT-1917 byggs som sprintens huvudnummer.
Sprintmotorns egna fel (BUT-1932/1933/1935/1936/1886) lämnas utanför — de sitter i
`C:/claude-plugins`, inte i det här repot, och förtjänar en egen körning.

Sprinten är alltså **ett stort säkerhetsärende plus tre små, mätta rester** från gårdagens
GDPR-bygge (BUT-1992), inte en bred svep.

---

## Vad som byggs

| # | Ärende | Vad det är | Tier | Router |
|---|---|---|---|---|
| 1 | **BUT-1917** | Blockering slår inte igenom på röster (+ spegeln, + `blocks`-radering) | C | full-panel |
| 2 | **BUT-2003 + BUT-2004** | Tre exportsektioner klipper tyst och delar ett `try` | C | full-panel |
| 3 | **BUT-2002** | EXPORT ⊇ RADERING-vakten sover för Dart-diffar | A | single |

**Stängs utan bygge:** BUT-1716 (premissen finns inte).
**Skrivs om, byggs inte som beskrivet:** BUT-1996 (halva ticketen mäter fel).

---

## 1. BUT-1917 — blockering slår inte igenom på röster (huvudnummer)

### Problemet, på vanlig svenska
Blockerar du någon försvinner deras röst i en omröstning från **din** skärm, men raden
ligger kvar i databasen och alla andra ser och räknar den. Stänger någon annan
omröstningen kan den blockerade personens röst alltså avgöra vinnaren. Blockering betyder
i dag "jag slipper se dig", inte "du kan inte påverka mig" — och Apple och Google läser
sina regler som det senare.

### Vad som redan är avgjort (ingår som förutsättning, ska inte vägas om)
Malins beslut 2026-08-26: reglerna läser en **egen speglad kopia** av blocklistan i stället
för att slå upp originalet vid varje röst. Motivet är kostnadsprincipen — en extra
skrivning vid blockera/avblockera är engångskostnad, en uppslagning per röst är löpande.

### Mätt förutsättning (av mig, i den här sessionen)
`firestore.rules:2224-2322` är `poll_votes/{voterId}`-blocket. Varken `inPollConversation()`
(2242-2244), `pollIsOpen()` (2289-2292) eller `isValidVote()` (2296-2301) nämner blockering.
Hjälparen finns redan: `isNotBlockedBy(targetUserId)` på `firestore.rules:196-199`, som
läser `blocks/{blockerId}_{blockedId}` (2463-2485). Den används på andra skrivvägar
(rad 706, 1404, 2510, 2556) men inte här.

**Kostnadsgolv som designen måste förhålla sig till:** blocket gör redan två
regel-`get()` per röst — `pollMessage()` och konversationsuppslagningen — och
`pollIsOpen()` anropar `pollMessage()` igen. Varje ytterligare uppslagning läggs ovanpå det.

### Den avgörande begränsningen (mätt, står redan i reglerna)
`firestore.rules:214-215` säger rakt ut: **"Firestore rules cannot iterate a group
participant list."** Det är repots egen, redan betalda lärdom (BUT-674). Därför fungerar
inte den befintliga hjälparen här: **varje** existerande `isNotBlockedBy`-anrop (rad 706,
1404, 2510, 2556) riktar sig mot **en enda känd motpart** — `toUserId`, `recipeOwnerId`,
`userId`. En gruppomröstning har N motparter, och en regel kan inte loopa över dem.

Det är precis därför Malins spegelbeslut är rätt form, och det pekar mot den billigaste
varianten: `inPollConversation()` **hämtar redan konversationsdokumentet**. Ligger spegeln
som ett fält på just det dokumentet kostar kontrollen **noll extra läsningar**. Det är
tesen agenterna ska bekräfta eller motbevisa.

### Spegeln måste skrivas av servern
`blocks` skrivs av **klienten** (`firestore.rules:2474-2478` tillåter blockeraren att
skapa raden; `FirebaseBlockRepository.blockUser/unblockUser`,
`lib/repositories/firebase/firebase_block_repository.dart:61,74`). En klientskriven spegel
vore alltså förfalskningsbar — den som blockeras skulle kunna skriva sig fri. Spegeln måste
komma från en Cloud Function-trigger, och reglerna måste vägra klientskrivningar till den.

Mätt: **ingen serverkod rör `blocks` i dag** — ingen träff på `blockerId`/`blockedId` i hela
`functions/src`. Triggern blir den första, och `functions/src/social/` är rätt hem (där finns
redan `onDocumentCreated`-triggers).

### Formen: en spegel per person, `users/{uid}/block_mirror/current`

Dokumentet listar `blockedByUserIds` — de som har blockerat *dig*. Regeln korsar den listan
mot konversationens `participantIds`.

**Min första gissning var ett fält på konversationsdokumentet (noll extra läsningar). Den
är förkastad**, och skälet är värt att skriva ner: samma faktum skulle skrivas in i varje
konversation två personer delar, utan någon enda plats att stämma av mot — alltså BUT-1798
igen, fast med högre kardinalitet. **En extra läsning per röst är priset för att ha exakt
en kopia**, och det priset ska betalas.

**Det starkaste argumentet är inte kostnad utan korrekthet.** Firestore tillåter högst **10
dokumentåtkomster per regelutvärdering, och att överskrida taket ger permission-denied** —
inte en långsam väg (verifierat mot Firebases dokumentation i dag). Att kolla varje motpart
för sig kostar N läsningar, och `poll_votes`-blocket lägger redan beslag på 2 av de 10. En
grupp med nio deltagare skulle alltså **sluta fungera helt**. Spegeln gör N till 1.

| form | regelläsningar per röst | vid N deltagare |
|---|---|---|
| `exists()` per motpart på `blocks` | N | **permission-denied över ~8 deltagare** |
| fält på konversationen | 0 extra | BUT-1798 återuppbyggt, N kopior |
| **spegel per person (vald)** | **+1**, värsta fall +2 | konstant, oavsett gruppstorlek |

**Varför en `users/{uid}`-undersamling och inte en toppnivåsamling:** raderingskaskadens två
driftvakter sträcker sig *bara* över `users/{uid}/X`-kedjor. En toppnivåsamling vore ett nytt
lager persondata **utan** mekanisk raderingsvakt och **utan** exportvakt. Lagd under
`users/{uid}` ärver spegeln båda gratis. Triggern måste därför skriva kedjan **bokstavligt**,
inte hopsatt ur en sträng, annars ser skannern den inte.

**Riktning:** bara inkommande (`blockedByUserIds`). Har A blockerat B listar B:s spegel A, så
B:s röst vägras i varje rum där A finns — medan A fortsätter rösta som vanligt. En symmetrisk
lista hade tystat *blockeraren* i varje grupp de delar, alltså ett straff för att ha använt
säkerhetsfunktionen.

**Skrivare:** en trigger på `blocks` (`functions/src/social/sync-block-mirror.ts`, ny) som
inte applicerar en delta utan **räknar om hela listan från källan** vid varje händelse.
Det är svaret på BUT-1798 och det är strukturellt, inte ett löfte om att vara noggrann: en
projektion som räknas om från källan kan inte driva isär varaktigt — dubbletter är
idempotenta, omkastad ordning läker vid nästa händelse. Plus en `sourceRev`-vakt så att en
långsam äldre körning inte skriver över en nyare, och en veckovis avstämning som **loggar
antalet** den lagade. Klientskrivningar vägras i reglerna (`allow write: if false`), så en
andra skrivare kan inte uppstå.

**Sökvägen — de två designagenterna var oense, och jag löste det.** Kostnadslinsen ville ha
en undersamling (`users/{uid}/block_mirror/current`) för att ärva raderingskaskadens två
driftvakter, som bara sträcker sig över `users/{uid}`-kedjor. Säkerhetslinsen ville ha en
toppnivåsamling för att kunna köra `array-contains` när uid:t ska bort ur *andras* speglar.
**Undersamlingen vinner**, för invändningen är svarbar: samma fråga går att köra som en
`collectionGroup('block_mirror')`-sökning. Då fås båda. (Kontrollerat mot BUT-1996-lärdomen:
collectionGroup-id:t `block_mirror` krockar inte med någon TTL-policy.)

### Öppna designfrågor (panelen avgör; båda designagenterna har svarat)
1. **Fail open vid saknad spegel — avgjort, med ett villkor.** Saknad spegel går inte att
   skilja från "ingen har någonsin blockerat dig", vilket är sant för nästan alla konton. Att
   faila stängt hade vägrat varje röst från varje användare tills en backfill skrivit ett
   dokument åt alla. Det som gör det *säkert* i stället för slarvigt är att frånvaron är
   **enkelriktad**: första blockeringen skapar dokumentet och **inget raderar det någonsin**
   (avblockering tömmer listan, tar inte bort raden). Annars kunde den som blockeras radera
   sig tillbaka till undantaget. En spegel som *finns* men är trasig failar däremot **stängt**.
2. **Synken — löst strukturellt.** Triggern applicerar ingen delta utan **räknar om hela
   listan från `blocks`** vid varje händelse, så en projektion som räknas om från källan kan
   inte driva isär varaktigt. Plus `retry: true`, en `sourceRev`-vakt mot omkastad ordning,
   och en schemalagd avstämning som **loggar antalet den lagade** — en avstämning som lagar
   tyst är hur man aldrig får veta om ett tre månader långt avbrott.
3. **Enkelriktningen — avgjord åt två håll.** Regellagret förblir enkelriktat: att vägra
   *blockerarens* röst hade straffat den som använde säkerhetsfunktionen. Men *tallyn* på
   klienten görs symmetrisk, för i dag räknas rösten från någon som blockerat dig på din egen
   skärm. Läsningen finns redan tillåten i reglerna, så det kräver ingen ny rättighet.
   Meddelande*visning* görs uttryckligen **inte** symmetrisk — det läcker att du blivit
   blockerad, och är ett eget beslut.
4. **GDPR — två steg, ovanpå en befintlig lucka.** Spegeln in i `subs` (då täcker
   driftvakterna den automatiskt) plus ett kaskadsteg som tar uid:t ur *andras* speglar.
   **Och:** båda agenterna hittade oberoende samma sak som jag — `blocks` raderas aldrig vid
   kontoradering. Säkerhetslinsen tillade att `deleteAllBlocksForUser`
   (`firebase_block_repository.dart:140-170`) är **död kod som dessutom skulle kasta** om den
   anropades, eftersom regeln bara tillåter blockeraren att radera. Att skeppa spegelns
   radering medan det den speglar aldrig raderas är inte försvarbart, så `deleteBlocks`
   byggs i samma ändring.
5. **Omfattning — Malins beslut i den här sessionen: spegel + röster nu.** Meddelanden, nya
   DM:ar och menyomröstningen filas som tre uppföljare mot samma färdiga spegel. Uttryckligen
   accepterat: blockering är inte helt tätt när sprinten är slut, och det står i rapporten.

### Det obekväma fyndet: blockering är i dag mest en visningsfunktion

Jag grep:ade varje `isNotBlockedBy`-anrop i reglerna. Resultatet ändrar hur man ska läsa
ticketen.

**Ytor som *har* en blockeringsspärr:** vänförfrågningar (rad 706) och notiser (2556) fullt
ut; receptkommentarer (1404) och betyg (2510) **delvis** — spärren sitter bakom
`!('recipeOwnerId' in request.resource.data) ||`, så en klient som helt enkelt utelämnar
fältet hoppar över den.

**Ytor som saknar den helt:**

| Yta | Vad en blockerad person fortfarande kan göra |
|---|---|
| `messages` create | **Skriva meddelanden till dig** i en befintlig DM eller delad grupp |
| `conversations` create | **Öppna en helt ny DM** med någon som blockerat dem |
| `realtime_menus/{id}/votes` | Rösta i hushållets menyomröstning — **en andra, identisk röstningsyta** |
| `poll_votes` | ticketen |
| kommentarslikes, cook_snaps | mindre |

Det betyder att om en granskare på Apple eller Google frågar "fungerar blockering", är det
ärliga svaret i dag nej — och röster är den *smalaste* instansen av problemet.
Chattmeddelanden är den yta en användare möter först.

### Tre angränsande fynd som filas som egna ärenden före commit
1. **`blocks` raderas aldrig vid kontoradering** (jag och båda agenterna hittade det
   oberoende). Ingen serverkod rör samlingen, och driftvakten ser den inte — den sträcker sig
   bara över `users/{uid}`-underssamlingar. Dessutom är `deleteAllBlocksForUser` död kod som
   skulle kasta om den anropades. **Detta byggs i den här ändringen**, se punkt 4 ovan.
2. **Exporten talar om vem som har blockerat dig.** `exportIncomingBlocks`
   (`firebase_data_export_repository.dart:673-691`) ger `blockerId` oredigerat. Ett artikel
   15(4)-avvägande, och jag hittar **ingen** post om det i `ACCEPTED_DEVIATIONS.md` — alltså
   obeslutat, inte beslutat. Filas åt dig.
3. **De två `||`-hattade halvspärrarna** på kommentarer och betyg.

### Restrisker som skrivs ner, inte döljs
- **Några sekunder** mellan att en blockering landar och spegeln uppdateras, då en röst
  fortfarande kan gå igenom. Stängs av retry och avstämningen.
- **Gamla röster ligger kvar.** En regeländring är inte retroaktiv; rader skrivna innan den
  landar tas inte bort av den. Täcks av den symmetriska klientfiltreringen, som är en
  visningskontroll — inte en serverkontroll.
- **Griefing-inversen:** vem som helst kan nu tysta en annans röst i varje delad omröstning
  genom att blockera dem, tyst. Det *är* den avsedda innebörden av ditt beslut — en
  säkerhetsfunktion ska falla ut till förmån för den som bad om skydd — men det är en
  produktsynlig förändring och den skrivs som en medveten post, inte som en bieffekt.
- **Felmeddelandet måste vara neutralt.** "Din röst kunde inte registreras" — aldrig "någon
  här har blockerat dig", som hade förvandlat en tyst blockering till en notis.

### Ordning (avvikelse här skadar användare)
1. Trigger + avstämning + tester — **spegeln måste finnas och stämma innan någon regel
   litar på den**.
2. Backfill av befintliga blockeringar. Utan den är regeln verkningslös för precis de
   användare som redan bett om skydd.
3. Kaskaden: `block_mirror` i `subs`, `deleteBlocks` + `deleteBlockMirrors`, exportbeslut.
4. Reglerna + tio regeltester, **mutationsprovade**.
5. Klienten: symmetrisk tally, neutral feltext.

Att deploya steg 4 före 1-2 är den enda ordning som aktivt skadar: fail-open är tyst.

**Fas 1.4 (full panel) körs före någon Edit.** Panelens villkor blir acceptanskriterier.

### Acceptanskriterier
1. `diff` — en röst från någon som blockerats av **en deltagare som inte är omröstningens
   författare** vägras av reglerna. (Det är testet som dödar den billigare, felaktiga
   varianten som bara kollar författaren.)
2. `diff` — en blockerad röstare kan fortfarande **radera** sin egen rad och **läsa** tallyn.
   Artikel 17 respektive blockeringens tysthet.
3. `diff` — ingen klient kan skriva eller radera någons spegel, inklusive sin egen.
4. `diff` — en användare **utan** spegeldokument kan rösta som vanligt.
5. `diff` — varje ny regelkonjunkt är **mutationsprovad**: tas den bort ska ett namngivet
   test rödna. En deny som blir grön av fel skäl är det återkommande felet i det här repot.
6. `diff` — kontoradering tar bort `blocks`-rader åt **båda** hållen och uid:t ur andras
   speglar; driftvakten är grön utan att någon hand-skrivit en post.
7. `diff` — felmeddelandet vid vägrad röst avslöjar inte att en blockering finns.
8. `run` — *(kan inte bevisas i en obevakad körning)* triggern och backfillen körda mot
   riktig data innan reglerna deployas. Blir en "Behöver dig"-punkt, inte ett underkännande.

---

## 2. BUT-2003 + BUT-2004 — de tre nya exportsektionerna (ship together)

Gårdagens BUT-1992 byggde `exportUserIngredients`, `exportOnboardingProgress` och
`exportAcquisition` (`lib/repositories/firebase/firebase_data_export_repository.dart:760-812`).
Båda resterna sitter på exakt de tre.

**BUT-2003 — tyst klippning.** Alla tre går via `_queryList` (samma fil, 200-215), som gör
ett rakt `.limit(n).get()` utan N+1-probe och utan att rapportera att taket nåddes. Kartan
som `PreferencesExportManager.exportAccountSubcollections`
(`lib/services/account/export/preferences_export_manager.dart:101-140`) returnerar bär ingen
`*_truncated`-nyckel. Bundlen säger sig alltså komplett medan den klippt.

*Mönstret finns redan i repot* — `ExportPaginationHelper.fetchCapped`
(`export_pagination_helper.dart:245`) gör N+1-proben, och den används redan av
`exportConversationsAndMessages` (`messages_truncated`, repo-filen 413-459) och av
`social_export_manager.dart:56-64` och `:376-382`. Fixen är att låta de tre nya sektionerna
gå samma väg — inte att uppfinna något.

⚠ Ett befintligt test **pinnar buggen** som avsett beteende:
`test/unit/repositories/firebase/firebase_data_export_repository_account_subcollections_test.dart:150-158`
(`'every new read honours its cap'`) sår 5 dokument, kapar vid 3 och asserterar `hasLength(3)`
utan någon trunkeringsassertion. Det testet måste skrivas om i samma ändring, annars är det
grönt på fel sak.

**BUT-2004 — delat `try`.** Samma tre läsningar ligger under ett enda `try`
(`preferences_export_manager.dart:104-140`); en nekad läsning kastar bort de två andra som
redan hämtats. Kodkommentaren på 105-111 säger själv att per-läsnings-isolering byggdes och
revertades, och att den filades som BUT-2004 "så att varje sektion flyttar tillsammans eller
ingen gör det". Därför byggs de två ihop.

Andra förekomsten av samma form, som också ska åtgärdas:
`SocialExportManager.exportBlocks` (`social_export_manager.dart:463-476`) — `exportOutgoingBlocks`
och `exportIncomingBlocks` under ett `try`.

### Acceptanskriterier
1. `diff` — var och en av de tre sektionerna rapporterar en `*_truncated`-flagga som är
   `true` när fler rader finns än taket, via `fetchCapped`, inte via en egen probe.
2. `diff` — en nekad läsning av en sektion tar inte de andra två med sig; varje sektion har
   sin egen felenvelopp.
3. `diff` — testet på rad 150-158 pinnar inte längre den tysta klippningen, utan
   trunkeringsflaggan.
4. `diff` — `exportBlocks` isoleras på samma sätt.

---

## 3. BUT-2002 — vakten sover för Dart-diffar

`scenario_exportCoversEveryDeletedSubcollection`
(`functions/src/__tests__/account-deletion-cascade.test.ts:3612`, körs på 3866) är den vakt
som håller **EXPORT ⊇ RADERING**. Den läser två *Dart*-filer:
`lib/core/constants/firestore_collections.dart` och
`lib/repositories/firebase/firebase_data_export_repository.dart` (repo-filen 3677-3704).

Men den bor i `cloud-functions-unit.yml`, som bara triggar på `functions/src/**` m.fl.
(rad 14-23). En Dart-only-diff — precis den ändring som mest sannolikt bryter invarianten,
t.ex. att en exportsektion tas bort — kör alltså aldrig vakten. Vaktens egen docstring
(3606-3611) säger detta rakt ut.

**Fix:** lägg `lib/repositories/firebase/**`, `lib/services/account/export/**` och
`lib/core/constants/firestore_collections.dart` till workflowens `paths:` (både `push` och
`pull_request`), och ta bort residualnoteringen i docstringen.

Repot har redan precedens för att skydda just en sådan lista mot att tyst tappa en post:
`cloud-functions-unit.yml:21-23` lägger till `firestore-rules.yml` med motiveringen att
test-registreringsvakten läser den filens triggers. Samma skydd ska gälla de nya raderna.

### Acceptanskriterier
1. `diff` — en Dart-only-ändring i exportfilerna triggar `cloud-functions-unit.yml`.
2. `diff` — något reddnar om en av de tre nya `paths:`-raderna tas bort.
3. `diff` — residualnoteringen i docstringen är struken, inte omskriven.

---

## Stängs utan bygge

**BUT-1716** — "Delade inköpslistors items-underväg: varje skrivning NEKAS av reglerna, och
koden som lagade det ligger i en stash." **Premissen finns inte.** Det finns ingen
`items`-undersamling under `unified_shared_shopping_lists`; items är ett inbäddat arrayfält
på förälderdokumentet, och skrivningarna går genom `allow update` på
`firestore.rules:2386-2392`. Skrivaren
(`lib/repositories/firebase/modules/shopping_offline_write_module.dart`) skickar exakt de
fält regeln tillåter och strippar medvetet `ownerId`/`memberPermissions`/`createdAt`.
Samlingen *var* en undersamling en gång (`609df34d6`) men revertades tillbaka just för att
lösa den friktionen. Ingen stash av 140 nämner listor eller items.

→ Stängs med hänvisning till regel- och skrivarraderna ovan.

---

## Skrivs om, byggs inte som beskrivet

**BUT-1996** — "TTL-policyer på `ingredients` och `rate_limits` täcker samma
collectionGroup-id som de nya users/{uid}-underssamlingarna."

**Halva ticketen mäter fel.** Mätt:

- `ingredients`: **kollisionen är verklig men latent.** TTL:n är deklarerad på
  `firestore.indexes.json:611`. Den översta `ingredients`-samlingen stämplar `expireAt` för
  en 30-dagars reap (`functions/src/admin/sync-ingredients-core.ts:301-342`), och
  `users/{uid}/ingredients` delar collectionGroup-id
  (`firebase_user_ingredient_repository.dart:44-48`). Men användarens egen skrivare stämplar
  **inget** `expireAt` i dag, så ingenting raderas. Risken armeras först den dag någon lägger
  till fältet.
- `rate_limits`: **ingen kollision.** Det finns ingen översta `rate_limits`-samling alls —
  strängen namnger bara `users/{uid}/rate_limits`. Fyra Dart-skrivare stämplar `expireAt`
  där med riktiga retentionsfönster (90 dagar). TTL:n är byggd **för** undersamlingen, inte
  av misstag.

→ Ticketen skrivs om till att bara gälla `ingredients`, och åtgärden blir liten: ett
assertionstillägg i `functions/src/__tests__/firestore-ttl-policies.test.ts` som håller fast
att ingen skrivare stämplar `expireAt` på `users/{uid}/ingredients`, plus att den
"omätta"-flaggan i `docs/security/account-subcollections-retention.md:51` löses.
Ingen migration, och `firestore.indexes.json` rörs **inte** med `--force`.

Byggs den här sprinten bara om BUT-1917 lämnar utrymme; annars ligger den kvar omskriven.

---

## Ärenden jag mätte men som inte togs in

- **BUT-2001** (CI-shard tar time-out) — **premissen håller, mätt**, men jag tog den inte in.
  12 av de 30 senaste `test.yml`-körningarna är `cancelled`, noll är `failed`, och varje
  avbruten unit-shard låg på 20,1-20,3 min — alltså exakt `timeout-minutes: 20`
  (`.github/workflows/test.yml:77`). Lyckade shards tar i dag 15,8-20,0 min, medan filens
  egen kommentar (rad 58-66) påstår ~12,5 min; den siffran har rötat. **Ticketens andra
  halva är fel:** `fail-fast: false` (rad 71) gör att syskon-shards överlever — den 2026-09-02
  visar shard 0 grön medan 1 och 2 tog time-out. Åtgärden är att höja `timeout-minutes` och
  `BUDGET_MIN: 15` (rad 130, 194) och stryka den rötade kommentaren. Liten, men egen ändring.
- **BUT-1934** (Urgent) — mekanismen är hittad men fixen ligger i `C:/claude-plugins`, inte
  här: batchens filista kommer från en LLM-agent som *berättar* vad `git status` sa
  (`sprint-execute-parallel.js:2162-2189`) i stället för att harnesset parsar den, så ett
  påhittat filnamn flyter rakt in i grindens `unclaimed`. Samma klass av fel lagades för
  close-out-fasen i `9559c55` med `sprint-facts.mjs`, men aldrig för den här fasen. Hör till
  plugin-sprinten Malin la åt sidan.
- **BUT-1944** — premissen håller och har blivit värre: `testing-specialist.knowledge.md` är
  **183 593 byte / 2 102 rader**, inte de 155 kB ticketen säger; taket är 800 rader.
  `firebase-backend-security.knowledge.md` har också passerat taket (816 rader). Vakten
  (`knowledge-freshness.mjs`) varnar bara och kör bara vid Stop.

---

## ⚠ Plangranskningen kunde inte köras

Repots grind kräver att en fristående agent läser planen kallt mot reglerna innan bygget
får börja. **Fyra sådana agenter i rad hängde sig** — de två första fick hela uppdraget, de
två sista bara 2-3 filer var, och alla fyra hann skriva en enda mening innan de fastnade.
Designagenterna tidigare i samma session körde klart på sju minuter, så det är inte
uppgiftens storlek utan något som gick sönder i sessionen. En buggrapport är köad.

**Malins beslut: hon läser planen själv i stället.** Det är ett starkare besked än agentens
— grinden finns för att någon annan än den som skrev planen ska läsa den, och hon är den
någon. Men det som INTE har hänt ska stå skrivet: ingen kall genomläsning mot
`accepted-deviations.md` och `plan-review-checklist.md` har gjorts. Det jag själv har mätt
står med filhänvisning ovan; det jag inte har mätt är märkt som antagande.

Kvar att göra oavsett: **fas 1.4, den fulla stakeholder-panelen, körs före någon Edit.** Den
är en annan kontroll än plangranskningen och ersätter den inte.

## Open questions (öppna frågor)

Tre ställdes till Malin i planeringssessionen och är besvarade; svaren är infällda ovan.
Rangordnade efter hur mycket de ändrade arbetet:

1. **Omfattningen av blockeringsspärren** (störst blast radius — avgjorde om sprinten rör
   en regelyta eller sex). → *Spegel + röster nu; meddelanden, nya DM:ar och menyomröstningen
   filas som uppföljare.* Uttryckligen accepterad restrisk: blockering är inte tätt efteråt.
2. **BUT-1917:s plats i sprinten.** → *Byggs som huvudnummer* (mot alternativen "egen session"
   och "bara planen"). Det är därför sprinten är fyra ärenden och inte nio.
3. **Sprintmotorns fem ärenden.** → *Lämnas utanför*; de sitter i ett annat repo.

**Kvarstående antaganden som inte kräver ditt beslut men som kan falsifieras under bygget:**

- Att en regelfunktion får returnera ett `path`-värde som både `exists()` och `get()`
  konsumerar. Inte verifierat mot emulatorn — om det inte kompilerar skrivs sökvägen ut två
  gånger i stället. Ingen designkonsekvens.
- Att `List.hasAny(List)` accepterar resultatet av `.data.get('blockerIds', [])` utan ett
  explicit `is list`-skydd. Om inte läggs skyddet till, vilket flyttar det trasiga fallet
  från CEL-fel-deny till uttrycklig deny — samma svar, tydligare väg.
- Att `EXPORT_EXEMPT`-vägen är rätt för spegeln (den är en projektion av rader bundlen redan
  återger under `incoming_blocks`). **Villkorat:** om uppföljare 5 leder till att
  `incoming_blocks` tas bort dör undantagets premiss med den. Korsrefereras i båda
  kommentarerna.
- Att panelen inte lägger till villkor som ändrar formen. Gör den det går den ändringen till
  dig innan koden låses.

## Verifiering

- `dart analyze --fatal-infos` på ändrade filer, samt `flutter test` på berörda sviter
  (`verify`-skillen kör hela kontrollen).
- Regeländringar bevisas på emulatorn genom `firestore-rules-tester`-agenten, med
  **både allow- och deny-fall, mutationsprovade** — en deny som blir grön av fel skäl är
  det återkommande felet i det här repot.
- Exportändringarna: kör
  `test/unit/repositories/firebase/firebase_data_export_repository_account_subcollections_test.dart`
  och CF-sviten `account-deletion-cascade.test.ts`.
- BUT-2002 bevisas genom att ändra en Dart-exportfil och se att
  `cloud-functions-unit.yml` triggar.
- Commit-grindarna körs som vanligt; inget markörfilsskrivande för hand.

## Uppföljningsärenden som filas i Linear före commit
1. `messages` create saknar blockeringsspärr — den yta en användare möter först.
2. `conversations` create — en blockerad person kan öppna en ny DM.
3. `realtime_menus/{id}/votes` — den andra röstningsytan, samma skada.
4. De två `||`-hattade halvspärrarna på receptkommentarer och betyg.
5. Exporten avslöjar vem som blockerat dig — obeslutat artikel 15(4)-avvägande, åt dig.
6. BUT-2001 omskriven med mätningen (time-out, inte fail-fast-kaskad).
7. BUT-1996 omskriven till att bara gälla `ingredients`.
8. Gamla `poll_votes`-rader skrivna före regeländringen städas inte av den.

## Efter sprinten
BUT-1917 parkeras i **In Review** (`panelPolicy: park`), aldrig Done. Exportändringarna
likaså — de rör GDPR och routern ger full panel. BUT-2002 kan stängas Done om alla
kriterier går igenom.

Rapporten skrivs på vanlig svenska, ett stycke per ärende: vad som ändrades i appen och
varför. Den ska säga rakt ut att blockering fortfarande inte är helt tätt efter den här
sprinten, och vilka fyra ytor som återstår.
