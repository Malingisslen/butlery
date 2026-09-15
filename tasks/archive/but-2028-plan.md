# BUT-2028 — städskriptets täckning, kapplöpningen, och en artikel 17-lucka bredvid

## Två öppna omdömesfrågor, först

Allt annat i planen är avgjort. Dessa två ändrar utfallet och står här för att inte hamna
under det mekaniska:

1. **Pausas Cloud Scheduler inför en skarp körning?** Veckojobben (`reconcileBlockMirrors`,
   `cleanup-old-notifications`, `purge-dormant-family-data` m.fl.) raderar och skriver i samma
   samlingar, omedvetna om att en nollställning pågår — samma kapplöpning som triggern, bara
   mindre synlig. *Alternativ:* pausa dem för körningen, eller acceptera och skriva ned det.
   Behöver inte avgöras för att bygga; behöver avgöras före en skarp körning.
2. **Steg 7:s omfattning är obestämd med flit.** `ingredient_suggestions` mäts först. Noll
   rader → en kommentar i regelfilen. Rader → ett riktigt kaskadsteg med sond. Det är det enda
   steget vars storlek inte är känd innan bygget börjar.

## Context

`admin/reset-user-data.ts` var tyst brutet i fem och en halv månad (BUT-2010): `tag_configs`
stod i både raderas- och behålls-listan, så skriptets egen vakt avbröt före fas 1 vid varje
körning. Att laga det i går (`d6610037f`) gjorde tre vilande problem levande — och tog
samtidigt bort det enda som hindrade en produktionsradering. Den akuta halvan är stängd:
skriptet vägrar skarpa körningar tills det här är löst.

**Varför det inte kan vänta:** kaskaden namnger skriptet som återställningen när
kontoraderingen VÄGRAR radera över sitt tak och rapporterar `gdprCompliant: false`. Så länge
skriptet vägrar sig självt finns ingen sådan återställning alls.

**Malins beslut 2026-09-05, bindande:** bygg avstängningen med självläkning; ta med artikel
17-luckan; härled täckningen ur TVÅ källor; allt i ett bygge. Hon valde största alternativet
på varje axel. Gårdagens niofilscommit behövde elva granskningsrundor; den här är större.

## Panelen

Routern gav **full panel**. Fem säten plus arkeologen; ingen blockering, inga konflikter, alla
på *approve-with-conditions*. **Ingen ADR** — panelen konvergerade. Släppta: Legal Counsel
(DPO täcker artikel 17), FinOps (kostnaden är prissatt), Product Manager (ingen användarnära
yta), Vendor/Procurement (ingen leverantörsfråga). **Panelen ändrade designen på tre punkter**;
de står nedan som besluten, inte som utkastets.

## Mätt, inte antaget

Inga siffror förs vidare till kommentarer i koden; testet härleder dem.

- **`onUserDeleted` har INGEN `retry`** — gen1, `setGlobalOptions` är v2 och når den inte. Ett
  kastat fel loggas och **droppas**. `throw error; // Retry` backas av ingenting. Ingen
  `maxInstances` heller; fas 1 raderar upp till 1000 konton per sida.
- **Fyra osopade ytor:** `shoppingPresence`, `recipe_cook_events`, tre notisköer, och
  lagringsprefixet `feedback/` (Firestore-raden sopas, prefixet inte).
- **`ingredient_suggestions`** — platt toppnivåsamling med `userId`, raderas av ingen väg.
- **`system` är osynlig för BÅDA härledningskällorna** och står i ingen lista.

**"Ingen skrivare" betyder tre ytor, inte två.** Frånvaro i `functions/src` och `lib/` räcker
inte — `firestore.rules` avgör. `ingredient_suggestions` har en öppen `allow create` för
klienter trots att ingen appkod skriver den; `notification_metrics` och `audit` är
`if false`. Det är därför steg 7 mäter rader i stället för att lita på en grep.

---

## Vad som byggs

### 1. Listorna till en importerbar modul

Bryt ut de tre listorna till `functions/src/admin/reset-collection-lists.ts` — bieffektsfri,
importerbar. `reset-user-data.ts` kör `main()` på modulnivå, vilket är varför alla tre
befintliga tester läser den som TEXT och två bär en medgiven ankarfälla.

**Halvgör inte detta:** de två befintliga scenarierna skrivs faktiskt om till `require()`.
Annars lever textparsningen kvar bredvid modulen. Scopet är exakt de tre listorna.

### 2. Den tredje listan — och den måste ha tänder

`COLLECTIONS_DELIBERATELY_UNTOUCHED: Record<string, string>` efter `EXPORT_EXEMPT`-mönstret:
produktionskod, skäl per post, grupperade under rubrikkommentarer.

**Panelens rättelse (DBA):** hinken har inga tänder av sig själv — bara `COLLECTIONS_TO_KEEP`
konsulteras av överlappsvakten. `menu_lexicon` och `admins` är i dag säkra enbart genom att
vara *utelämnade*, precis det tillstånd ärendet ska avsluta. Allt som ska bevaras går in i den
riktiga behålls-listan; den tredje listan är för det medvetet orörda.

**En samling som redan har en avvikelsepost filas enligt den verdikten, med posten som
skäl-sträng.** `parse_events` (BUT-1570), `analytics/feature_retention` (BUT-1789) och
`audit_logs` (BUT-424) blir synliga för testet — de ska placeras, inte omprövas.

Assertera mot `Collections.*` där konstanten finns. Refaktorera **inte** de befintliga
strängliteralerna.

### 3. Täckningstestet, ur två källor

Nytt scenario i den befintliga `functions/src/__tests__/account-deletion-cascade.test.ts`
(redan registrerad som `test:account-deletion-cascade`) — inte en ny fil, vilket undviker
`check-test-registration`s sex krav helt.

**Källa A — regelfilen.** Avvisa vägsegment som börjar med `{` (täcker kollektionsgrupp-jokrar
och den avslutande catch-allen); ta FÖRSTA segmentet; behåll `match /audit/{document=**}`.
Strippa kommentarer FÖRE parsningen — regelfilens kommentarer innehåller map-literaler som
förstör varje parentesräknare.

**Källa B — serverkoden.** `db.collection(...)`, `collection(Collections.x)`,
`collectionGroup(...)` — **och `.doc("samling/id")`-literaler.** Utan den sista är båda
källorna blinda för `system`, samlingen som håller appens egna kill-switchar och som flaggan
ska bo i. **Ärendets egen bugg gömd inuti dess egen lösning.**

**Granularitetsskillnaden, med mekanism (F1).** Källa B ser inte kedjade anrop, så
`db.collection("users").doc(uid).collection("consent")` ger `consent` som om det vore
toppnivå. Namn som `settings`, `friends`, `items`, `consent`, `participants` används som båda.
Mekanismen: **extraktorn kollapsar en kedja till dess första `.collection(...)`-led** — matcha
`.collection(X)` som INTE föregås av `.doc(` på samma uttryck — och det som ändå blir kvar
filtreras mot en explicit `KNOWN_SUBCOLLECTION_NAMES`-mängd som lever bredvid listorna och
kommenteras med varför varje namn står där. Först därefter får oenighet mellan källorna rödna.

**Korsvalidera källa A på två sätt** (parentesdjup och indentering). **Positiva ankare i
stället för en siffra**, inklusive `!found.has("members")` — den enda assertion som bevisar att
kollektionsgrupp-avvisningen kör.

Fyra egenskaper: skäl ≥ 20 tecken; ingen lucka; ingen inaktuell post; **disjunkthet över alla
tre par**, inte bara det befintliga.

### 4. Avstängningen — till `system`, inte `site_configs`

**Panelens rättelse, tre säten oberoende.** `site_configs` är läsbar för varje inloggad
användare (`firestore.rules:2927`), live-skriven i drift av `log-parse-event.ts` med värdnamn
som dokument-id, och repot har redan en kill-switch-konvention i `system/config` (läst på fyra
ställen, med runbook, BUT-439).

**Flaggan går i `system`, och `system` läggs uttryckligen i `COLLECTIONS_TO_KEEP`** — annars
sopar en framtida ändring bort strömbrytaren. Dokument-id:t ska strukturellt inte kunna
kollidera med en domännyckel; pinnas med test.

**Läs OCACHAT (DBA).** Repot har tre flagg-läsare med fem minuters cache på modulnivå. Följer
den nya samma mönster fortsätter en varm instans skriva i upp till fem minuter efter att
flaggan satts — vilket tyst omintetgör mekanismen. En läsning per riktig kontoradering, för
alltid, och att cacha bort den är inte en godtagbar affär.

**Vilka triggrar den gatar, uttryckligen.** Den gatar `onUserDeleted`. `syncBlockMirror` gatas
**inte**, och skälet skrivs i koden: den är säker i dag för att `rebuildMirrorFor` frågar Auth
om kontot finns, och fas 1 väntar in innan fas 2 börjar. **Den säkerheten följer av
Auth-kontrollens tajmning, inte av kill-switchen** — påståendet "kill-switchen stoppar
triggerskrivningar" är falskt som skrivet.

**Självläkning:** rensas i ett `finally`, bär en TTL, och verifieringen kontrollerar att den
faktiskt rensades — icke-rensad flagga ger icke-rent verdikt.

**Spår över varje avstängning (DPO + Security).** När flaggan sätts och varje gång
`onUserDeleted` returnerar tidigt: en ERROR-rad till **Cloud Logging**, inte bara Firestore.
En TTL är en utgång, inte en notis. Skriptets körning loggas out-of-band **före fas 1** —
Firestores revisionssamlingar raderas av just den körning som annars bokfört den.

**Namngiven restrisk (DPO):** konton som raderas MEDAN flaggan är på förlorar sin städning
mellan användare, och ingenting kör om den. Att flaggan rensades bevisar att den är av igen —
inte att de som hann raderas fick sitt. Upptäcks eller skrivs som rest; får inte tigas ihjäl av
ett trevärt verdikt som antyder att det kontrollerats.

### 5. Verifieringsfasen

**Räkna före radering, och rapportera antalet.** Nuvarande `deleteCollection` blandar ihop de
två; en pass som tyst raderar om är den tremånadersform `reconcileMirrors` finns för att undvika.

**Trevärt verdikt:** `rent` / `INTE rent` / `OBESTÄMT`, eftersom `reconcileMirrors` kommer
undan med binärt genom att köra varje vecka — **skriptet kör en gång.** Verdiktet bär
exitkoden; `CLEANUP COMPLETE` blir villkorat. Exitkodskonventionen är ny i repot (alla
`admin/`-skript är binära) — skriv den som en konvention nästa skript kan återanvända.

**Passet går igenom HELA den nya mängden** — de fyra ytorna och `ingredient_suggestions` — inte
bara den ursprungliga raderingslistan.

**Ärligheten som ska stå i koden:** en gen1-trigger har ingen begränsad leveranstid, och utan
`retry` kan en händelse droppas helt. **Ingen stoppregel baserad på tid eller antal pass är
korrekt.** En andra sopning kan bevisa att skräp finns — aldrig att det är slut.

### 6. De fyra osopade ytorna

`shoppingPresence`, `recipe_cook_events` (`{userId}/events/{eventId}`), de tre notisköerna,
lagringsprefixet `feedback/`. Notisköernas namn liknar de som redan står i listan.

### 7. Artikel 17-luckan i `ingredient_suggestions`

**Mät radantalet först.** Formen är känd: platt toppnivåsamling med `userId`. Kopiera
`deleteCookSnaps` verbatim — `where('userId','==',uid)` + `batchDeleteAll`, plus sond.
Enkelfältslikhet behöver **inget** index.

### 8. Två meningar som ska bort

Kaskadens docstring får inte läsa som att en helprojekts-nollställning botar **en** användares
ofullständiga radering. Och `throw error; // Retry` är osant — korrigera kommentaren, gör den
**inte** sann med `failurePolicy` (det skulle förlänga kapplöpande skrivningar över upp till
sju dygn). **Filas som eget ärende:** en verklig brist i vanlig kontoradering.

---

## Verifiering

- `npx tsc --noEmit` rent; `npm run test:account-deletion-cascade` grönt.
- **Varje ny kontroll muteringsprövad VID NAMN.**
- Mutanter som måste döda något namngivet: ta bort en samling ur alla tre listorna; peka om
  flaggan till en samling som raderas; låt `finally` inte rensa; **avbryt hårt mitt i**
  (`process.exit`, inte bara ett kastat undantag); byt `count()` mot radering utan räkning;
  gör verdiktet binärt; **cacha flaggläsningen**.
- `firestore.rules` orörd.

**Behöver dig, som sista steg:** torrkörning mot riktig data. Panelen vill se tre saker, inte
bara en ren exitkod: att en riktig anmälans `contentOwnerId` anonymiseras (T&S), att en färsk
blockering inte återuppstår som spegel (T&S), och att flaggan respekterades (DPO). Får du
`invalid_grant` är det den cachade CLI-inloggningen — döp om referensfilen, autentisera inte om.

## Ordning

1. **Logga panelen** via `docs/org/metrics/log_event.py` — kunde inte göras i planläget, och en
   ologgad granskning är osynlig för /org-retro.
2. Bryt ut listorna; skriv om de två scenarierna till `require()`.
3. Täckningstestet ur två källor, inklusive kollaps-mekanismen — **före** den tredje listan, så
   den skrivs mot ett test som redan rödnar.
4. Tredje listan; `system` och behålls-hinken in i riktiga `COLLECTIONS_TO_KEEP`.
5. De fyra osopade ytorna.
6. Avstängningen och verifieringsfasen.
7. `ingredient_suggestions` — mät, bygg om det behövs.
8. **Granskningsgrindarna i batchar.** `cloud-functions-specialist` måste namnge varje stagead
   fil, och agenter stannar över tre filer. Ge varje granskare hela fillistan, instruera `Read`
   (huvudboken räknar bara det verktyget), och stagea om mellan rundor.
9. **Deploya `onUserDeleted`** innan spärren lyfts — gaten är inert tills funktionen är ute. På
   det här projektet: **en funktion per `firebase deploy`, `--force` krävs permanent**, och
   `--force` raderar tyst produktionsfunktioner som saknas i källan.
10. Lyft spärren i `main()`. Det är det enda steget som får skada.

Planen skrivs till `tasks/but-2028-plan.md`, **inte** `tasks/todo.md` — den filen bär en annan
sessions ocommittade plan.

## Open questions

**Fyra frågor ställdes till Malin 2026-09-05 och besvarades; svaren är bindande och inarbetade.**
Kvarstående omdömesfrågor står överst i planen. Antaganden bygget vilar på, var och en mätbar
och avsedd att mätas i steg 2–3 innan något beror på den: `audit` och `notification_metrics`
saknar skrivare på alla tre ytorna; `syncBlockMirror` är säker genom tajmning, inte garanti, så
antagandet faller om fasordningen ändras.

**Inte öppna frågor, trots att de kan se ut så:** var flaggan ligger (panelen avgjorde
`system`), om behålls-hinken behöver tänder (ja), om avstängningen gatar `syncBlockMirror` (nej,
och skälet skrivs ned).

## Sammanfattning för Malin

Städskriptet lovar att radera all användardata men hoppar över en rad samlingar, och när det
raderar inloggningskonton skriver appens egen städtrigger tillbaka rader bakom ryggen på det.
Efter bygget stämmer löftet: varje samling är antingen raderad, bevarad, eller uppskriven som
medvetet orörd med ett skäl — och ett test rödnar den dag någon lägger till en samling utan att
bestämma vilket.

Triggern stängs av under körningen, eftersom den bara har jobb att göra när det finns andra
användare kvar. **Det är byggets farligaste del:** fastnar avstängningen slutar anonymiseringen
av anmälningar och städningen mellan användare fungera tyst vid varje riktig kontoradering. Den
läker därför sig själv, kontrolleras efteråt, och varje användning loggas där loggen överlever.

**Om något går fel är detta inte ett `git revert`.** Två saker ligger utanför koden. Flaggan är
ett dokument i Firestore — fastnar den, och `finally` aldrig kört, raderas den för hand i
konsolen, och TTL:en tar den annars av sig själv. Och spärren sitter i en *deployad* funktion:
att ta bort avstängningen kräver en ny deploy, inte bara en återställd commit. Koden i övrigt
går att backa som vanligt.

**Panelen flyttade flaggan.** Utkastet hade den i en samling varje inloggad användare kan läsa
och vars grannar en användare kan skapa. Den går nu dit appens övriga kill-switchar bor.

**Och den hittade ärendets egen bugg i ärendets egen lösning:** täckningstestet, som ska hindra
att en samling glöms bort, hade varit blint för just den samling som håller strömbrytaren.

Vi lagar också något vi hittade bredvid: en samling med personuppgifter som ingen raderingsväg
rör i dag. Den drabbar riktiga användare — men den mäts innan den byggs, eftersom "ingen
skrivare hittad" inte är samma sak som "inga rader".
