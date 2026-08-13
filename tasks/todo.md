# IN EXECUTION 2026-08-12 — the rules/model drift sprint

Malin: "planera och fixa alla fyra i en sprint" (2026-08-12). Fem stycken, inte
fyra — granskningen hittade en latent till efter att hon sa det.

## Context

`f3db9261e` fixade en produktionsincident: att spara ett recept hade nekats av
databasens säkerhetsregler i tre veckor, för att ett nytt fält lagts i modellen
utan att läggas i reglernas lista över tillåtna fältnamn. Ingen märkte det, för
ingen sparade ett recept under de veckorna.

Granskningen av den fixen ställde följdfrågan: **finns samma glapp någon
annanstans?** Den jämförde varje `hasOnly`-lista i `firestore.rules` mot vad
koden faktiskt skickar. Fyra levande träffar till, plus en latent. Tre av dem
har jag själv bevisat mot emulatorn.

`hasOnly` är den farligaste formen i filen: den **failar stängt, tyst**, på
SKRIVNINGEN. Ingen kompilator, ingen analys, inget felmeddelande användaren
skulle rapportera — funktionen slutar bara fungera.

## De fem

| # | vad som är trasigt | status | vad användaren märker |
|---|---|---|---|
| **D1** | `users/{uid}/counters` — reglerna tillåter `shared_recipes`, koden skickar `unreadSharedRecipes`. Två olika ordförråd för samma sak | **bevisad DENIED** | märket "nytt delat recept" räknas aldrig upp |
| **D2** | `conversation_memberships` — modellen skickar 9 fält, reglerna tillåter 7 (`isMuted`, `isPinned` saknas). OCH `conversations/{id}/participants` saknar `match`-block helt | **bevisad DENIED, båda** | att skapa en konversation kastar |
| **D3** | `notification_history` — skribenten stämplar `expireAt` (90-dagars TTL), listan saknar det | granskarens nyckeljämförelse | notishistorik sparas aldrig |
| **D4** | `deep_links/{id}/clicks` — reglerna vill ha `clickedAt` + `referrer`, koden skickar `timestamp` | granskarens nyckeljämförelse | klickstatistik för delningslänkar saknas |
| **D5** | `TagResult.decisions` skrevs av `toFirestore(includeDecisions: true)` och stod inte i listan | **latent, nu åtgärdad** — parametern borttagen | slog någon på flaggan var receptsparningen nere igen |

**D2 är värst och tas först.** De andra fyra sväljs av en `catch` och loggar en
varning; D2 gör det inte — `addParticipants` har ingen lokal catch, så
`batch.commit()` kastar uppåt genom `createDirectConversation` /
`createGroupConversation`, som kastar vidare. Och den är gatad på
`enable_subcollection_participants`, som **defaultar till true**.

## Bygget

Ordningen är vald så att varje steg går att verifiera för sig.

### ⓪ Skyddet först, inte sist

Ett test som jämför VARJE `hasOnly`-lista i `firestore.rules` mot de nycklar
skribenten faktiskt skickar. Det är det enda steget som gör att en sjätte inte
uppstår, och det ska skrivas FÖRE fixarna så att det rödnar på alla fem och
sedan grönar en i taget. Utan den ordningen bevisar det ingenting.

形: en emulatorsvit som för varje samling skickar den VERKLIGA nyttolasten
(hämtad från modellens `toFirestore()` eller repositoryts literal, aldrig
handskriven) och hävdar ALLOWED. Handskrivna nyttolaster är precis
mekanismen som lät alla fem glida — granskaren påpekade att även min egen nya
`R4b` är handskriven.

### ① D2 — meddelanden

Två fel i en: lägg `isMuted` + `isPinned` i listan, och **skriv ett
`match`-block för `conversations/{id}/participants/{uid}`** som i dag saknas
helt och därför faller på default-deny. Det senare är en ny regel för en väg
som redan används, så den behöver egen genomgång av vem som får läsa och
skriva — inte bara "tillåt deltagaren".

### ② D1 — delningsräknarna

Reglerna får de fältnamn koden använder. **Byt inte i koden i stället:** fälten
läses av `UserCounters`-modellen och av vyer, och konstanterna i
`UserCounterIncrements` är sanningen. Kontrollera samtidigt om
`unreadMessages` och `pendingFriendRequests` skrivs till samma dokument — de
står i samma konstantklass men jag hittade ingen skribent, och en oskriven
konstant är inte samma sak som ett fält som inte finns.

### ③ D3 + D4 — ett fält var

`expireAt` till notishistorikens lista (dess två systersamlingar har det redan,
med TTL-kommentar). `deep_links`-klicken: reglerna får `timestamp`, och
`referrer` tas bort ur listan om ingen skriver det — men först kontrolleras
vilken sida som är rätt, för här kan koden vara den som har fel.

### ④ D5 — det latenta

Antingen tillåts `decisions` med en storleksgräns, eller så tas parametern
`includeDecisions` bort. **Det är ett val, inte en fix:** parametern finns för
felsökning, och att tillåta fältet innebär att spara beslutsloggar per recept i
databasen. Jag lutar åt att ta bort parametern — den har noll anropare och dess
enda effekt i dag är att vara en fälla.

## Verifiering

- ⓪ måste rödna på alla fem innan någon fix skrivs, och sedan gröna en per fix.
  Det är stegets enda existensberättigande.
- Varje fix får ett ALLOW-test som skiljer sig från ett redan passerande test
  med **exakt den nya nyckeln**. Ett deny-test kan inte pinna en utvidgning:
  med utvidgningen återställd är det fortfarande grönt, nekat av `hasOnly` i
  stället, och två Firestore-nekanden går inte att skilja på i texten.
- D2 får dessutom ett riktigt test av deltagarvägen, inte bara medlemskapet.
- `firebase deploy --only firestore:rules` efter varje steg, och **aldrig**
  `--force` på index — projektminnet har 13 levande TTL-regler som saknas i
  filen.
- Slutkontroll på riktig enhet: skapa en konversation, dela ett recept, och se
  att räknaren tickar upp.

## Filer

`firestore.rules` (fem ställen), `functions/src/__tests__/` (⓪ plus ett test
per fix), och för D5 antingen `firestore.rules` eller
`lib/models/tagging/tag_result.dart`.

## Öppna frågor — båda besvarade i den här committen

1. **D5: flaggan togs bort.** `includeDecisions` hade noll anropare och dess
   enda effekt var att vara en fälla, så parametern är borta ur
   `TagResult.toFirestore`. `decisions` finns kvar i minnet och i `toJson`.
2. **D4: reglerna hade fel.** Skribenten skickar `timestamp` och `userId`;
   reglerna ville ha `clickedAt` och `referrer`, som ingen skickar. Reglerna
   fick skribentens namn, och `referrer` togs bort — ingenting läser den
   samlingen, så skribenten är sanningen här.

## Kvar efter sprinten, medvetet inte gjort

- **KLART i den här committen: bootstrap-residualen står nu i beslutsloggen.**
  Den låg länge här som "medvetet inte gjort", eftersom båda
  `accepted-deviations.md`-filerna var ändrade av en parallell session (BUT-1693)
  och att staga dem hade svept in deras arbete i min commit. Deras ändring
  landade som `638c5cf9c`, filerna blev fria, och entryn ligger nu i båda —
  tillsammans med de två andra residualerna och nollmedlems-skalet. Tröskeln för
  att stänga hålet helt är fortfarande BUT-1795. Punkten står kvar som synligt
  avklarad hellre än raderad, för det var den som höll den öppen i ett dygn.
- **Tre av de fem fixarna saknar ett ALLOW-test mot emulatorn, tvärtemot
  planens acceptanskriterium.** `counters`, `notification_history` och
  `deep_links/{id}/clicks` skyddas bara av textjämförelsen i det nya Dart-testet
  — och det testet säger själv i sin rubrik att det inte kan bevisa att regeln
  UTVÄRDERAS, bara att listan innehåller rätt fält. För räknarna är det extra
  tunt: samma regel bär också `isServerTimestamp('lastUpdated')` och
  `rateLimitWrite`, som ingen textjämförelse ser. Planen krävde ett ALLOW-test
  per fix som skiljer sig från ett redan passerande test med exakt den nya
  nyckeln. Det är inte gjort, och det står här i stället för att jag låtsas att
  textguarden räcker. Ligger i BUT-1823.
- **Omröstningar i chatten: bara den som skapade omröstningen kan rösta.**
  `votePoll` uppdaterar meddelandets `metadata`, och meddelanderegeln tillåter
  bara en uppdatering från den som skickade meddelandet. Alla andra nekas, och
  `votePoll` har ingen catch — felet går hela vägen upp i vyn. Samma sjukdom som
  D1-D5: skribent och regel är oense, och ingen märker det. **BUT-1832**, och
  **Malin har beslutat att den ska lagas** (2026-08-13). Läskvitton
  (`markMessageAsRead`, `batchMarkAsDelivered`) nekas av samma regel och tas i
  samma ändring om formen är densamma.
- **Två döda hjälpfunktioner i reglerna, varav en är en fälla.**
  `isDocumentOwner` har noll anropare och läser `resource.data`, som inte finns
  vid en nyskapning — den som i god tro anropar den på en `allow create` får ett
  blankt nej. Utrullningen varnar för båda; varningarna om "ogiltigt
  variabelnamn" är brus och det är nu bevisat. **BUT-1833.**
- **Två levande buggar av samma sjukdom hittades under granskningen, ingen av
  dem fixad här.** BUT-1826: den delade receptcachen har aldrig accepterat en
  klientskrivning — reglerna kräver fyra fält skribenten inte skickar, felet
  sväljs två gånger, och utåt ser det ut som låg träffkvot. Det är spegelbilden
  av hela sprinten (ett fält som SAKNAS i stället för ett för mycket) och den
  första konkreta instansen av luckan i BUT-1823. BUT-1827: om raderingen av
  konversationen misslyckas permanent i utkastningsfunktionens kollapsgren
  landar aldrig utkastningen av de minderåriga. Djupt hörn, ingen trolig orsak,
  men fixen är en extra skrivning på en barnsäkerhetsväg och förtjänar ett eget
  beslut.
- **Två kommentarnyanser medvetet inte lagade, för att inte köra om grindarna
  en gång till.** I skyddet står "var och en namnger sin skribents fil OCH
  RAD" — sant för två av tre, eftersom den tredje just bytte till metodnamn
  (raderna var fel med ett). Och regelfilens motsvarande pekare
  (`base_shared_content_repository.dart:59-63`) är fel på samma sätt och nämner
  bara en av tre skribentmetoder. Båda är en mening var, båda i filer som öppnas
  igen inom timmar för BUT-1831, och att laga dem hade ogiltigförklarat tre
  granskningar. Görs där.
- **Skyddet ser bara ena riktningen — spegelfamiljen är otäckt.** Reglerna
  kräver också att vissa fält FINNS (`keys().hasAll`, `hasRequiredFields`), och
  en modell som SLUTAR skicka ett obligatoriskt fält nekas precis lika tyst som
  en som lägger till ett okänt. Det nya skyddet jämför bara "allt som skickas är
  tillåtet" och kan strukturellt inte se det. Fixturen finns redan i huvudet:
  jämför andra hållet. Ska bli ett EGET test, inte ett andra påstående i det
  befintliga — en röd lampa ska betyda en sak. BUT-1823.
- **Meddelande-reservvägen stämplar om `createdAt`, så dess skrivning nekas mot
  varje konversation som redan finns.** `ConversationDto` skickar `createdAt`
  ovillkorligt, skrivningen är en merge-set, och uppdateringsregeln nekar varje
  diff som rör det fältet. Vägen är inte sällsynt: `readConversation` läser den
  användarskopade kopian, medan `createDirectConversation` bara skriver den
  översta — så för ett DM finns aldrig den användarskopade kopian och grenen
  körs vid varje sändning. Regeltestet kan inte se det: C11/C11B håller
  `createdAt` konstant, alltså skickar inget test det produktion skickar.
  **BUT-1831.** Omfattningen är FASTSTÄLLD 2026-08-13, mätt mot
  emulatorn med den verkliga nyttolasten: det är varje sändning, och det finns
  TRE oberoende orsaker (null-metadata, omstämplat `createdAt`, och omvänd
  deltagarordning när mottagaren svarar). Enda kombinationen som går igenom är
  den koden aldrig skickar. Kvar att bekräfta: vad användaren faktiskt ser på
  riktig telefon. Riktig fix är att läsa den ÖVRE konversationen i stället, vilket
  tar bort alla tre på en gång.
- **Anpassningen som gör den övre konversationen ockuperbar är egen och akut:
  BUT-1830.** Vem som helst som känner till ett grupp-id kan skriva den översta
  konversationen med sig själv som enda deltagare, och då körs utkastningen av
  minderåriga aldrig för den gruppen. Inte orsakad av den här sprinten; reglerna
  för att skapa konversationer är oförändrade. Står i båda beslutsloggarna.
- **Att lägga till en medlem i en gruppchatt man redan skrivit i fungerar inte,
  och kan inte fungera från appen.** Deltagarraden kräver att den översta
  konversationen redan namnger personen, och ingen klient får någonsin skriva i
  den listan — det är själva regeln som gör gruppmedlemskap oföränderligt från
  klienten. Så knappen i gruppvyn kastar. **Inte orsakad av den här sprinten**:
  vägen var stängd av default-deny förut också. Kräver en molnfunktion som äger
  "lägg till medlem", eller BUT-1795. **BUT-1828.**
- **Kontoradering städar INTE bort deltagarraden — ny GDPR-lucka, och den blev
  levande i dag.** `account-deletion-cascade.ts:1911-1926` raderar
  `users/{uid}/conversation_memberships` men ingenting någonstans raderar
  `conversations/{id}/participants/{uid}`, som bär den raderade användarens
  visningsnamn och avatar. Det var ofarligt så länge sökvägen var stängd i
  reglerna — då fanns inga rader — men den här sprinten öppnade den, så rader
  börjar skapas nu. Samma sjukdom som allt annat i sprinten: ett tvåvägsindex
  där bara ena halvan städas. Fixen är ett `collectionGroup("participants")`-ben
  i kaskaden plus ett i residualsonden, och ett `fieldOverride` för
  collection-group-index. Kunskapen fanns redan i koden —
  `admin/reset-user-data.ts:92` räknar upp `participants` som en
  konversationsunder­samling. **BUT-1822, hög prioritet**, och den ska
  granskas av `firebase-backend-security`.
- **Kollapsgrenens felväg är prövad, men inte mot emulatorn.** Grenen KASTAR
  inte — en tidig version gjorde det, och den här raden beskrev den versionen i
  flera timmar efter att den ersattes. Den RAPPORTERAR: `tryClearRoster`
  returnerar `false` och anroparen går över till uppdateringsgrenen i stället,
  så konversationen står kvar i stället för att raderas ovanpå rader som
  överlevde. Att bevisa det kräver att man får en radering att misslyckas mot
  emulatorn — Admin-SDK:n går förbi reglerna och en radering av något som inte
  finns lyckas. Löst i enhetslagret i stället, med en fejkad databas där en
  radering vägrar. **Uppräkningen** är mutationsbevisad. **Ordningen** (rader
  före förälder) är det INTE och kan inte bli det mot emulatorn: barnstädningen
  fungerar likadant efter att föräldern är borta, så att byta plats på de två
  raderna ger ett bit-identiskt slutläge och sviten förblir grön. Den första
  versionen av den här raden påstod att ordningen var bevisad. Det var fel.
- **En raderad konversation lämnar sin deltagarlista föräldralös.** Reglerna kan
  inte skilja "föräldern finns inte än" från "föräldern är raderad", så den
  bootstrap-gren som gruppskapandet behöver öppnar sig igen för en konversation
  som HAR funnits. Två vägar dit: molnfunktionen som vräker minderåriga raderar
  hela konversationen när den kollapsar under två medlemmar — **den vägen är
  lagad i dag**, funktionen städar nu bort raderna, och
  integrationstestet pinnar det (ingen siffra här — de två föregående
  påståendena om antal var båda inaktuella inom ett dygn) — och användarens egen "radera konversation" i
  listvyn, som **inte** är lagad: raderingsregeln kaskaderar inte, och en medlem
  får bara radera sin EGEN rad, så klienten kan inte städa åt de andra. Vad det
  kostar i praktiken: en före detta gruppmedlem som kan sitt konversations-id
  kan sätta sig i den övergivna listan och läsa namn och avatarer på personer
  hen redan chattat med. Id:t är en UUIDv4, alltså inte gissningsbart för en
  utomstående. Stängs helt av BUT-1795, som tar bort grenen. BUT-1825.
- **Den döda `UserCounters.toFirestore` är samma fälla som D5.** Klassen har
  ingen produktionsanropare, men dess serialisering skickar sju nycklar varav
  två — `unreadMessages` och `pendingFriendRequests` — reglerna nekar. Kopplar
  någon in den slutar räknarna fungera tyst. Ta bort serialiseringen eller lägg
  till fälten medvetet. Skyddet ser den inte: det härleder från
  `UserCounterIncrements`, inte från den metoden. BUT-1824.
- **Uppdateringsgrenen för `lastReadAt` är oprövad.** Den ligger bredvid den
  bredare medlemsgrenen, så varje test vars aktör ÄR medlem godkänns av den
  andra grenen — tar man bort den självskopade grenen förblir hela sviten grön (ingen siffra — den har varit inaktuell tre gånger).
  Dess enda unika effekt är att en BORTTAGEN medlem stämplar sin föräldralösa
  rad (BUT-1823 samlar den). Fixturen som pinnar den: en konversation vars `participantIds` INTE
  nämner aktören men som ändå har en rad för hen. Det är samma sjukdom som hela
  sprinten handlar om, så det ska göras — men det är en Medium på en regel som
  redan är korrekt och utrullad, och det står här hellre än att jag låtsas att
  det är klart.
- **`conversation_memberships` låter vilken inloggad användare som helst skriva
  vilken annans medlemsrad som helst** (ingen `isOwner`). Modulen skriver
  faktiskt medparternas rader, så det ser avsiktligt ut — men det är
  odokumenterat, och en främling kan plantera en falsk konversationspost i
  någons inkorgsindex. BUT-1829.

## Vad det betyder på vanlig svenska

- **Fyra saker i appen har varit tysta trasiga**, av exakt samma skäl som att
  spara recept var det: ett fält bytte namn eller tillkom på ena sidan men inte
  på den andra, och databasen svarar med att bara vägra.
- **Den värsta är meddelanden** — att starta en konversation kastar ett fel i
  stället för att svälja det.
- **Den viktigaste delen av sprinten är inte de fyra fixarna**, utan testet som
  gör att en femte inte kan uppstå tyst. Det skrivs först.
- Du får två frågor under bygget, inte fler. Båda står ovan.
