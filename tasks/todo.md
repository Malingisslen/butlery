# SPRINT 2026-08-13 — poll/GDPR rules gaps, wrong-collection recipe reads, allergen badges

Selection phase only (Phase 1 of sprint-execute). 8 tickets across 3 batches. Linear is up;
selected tickets transitioned to Todo. 8 tickets found already fixed on `main` under a
different commit than their own — filed here as obsolete, not re-built.

## Step-0 catch: obsolete tickets (fix already shipped, ticket never closed)

Confirmed by reading the current code, not just `git log`:

- **BUT-1779** (handwritten-recipe save → error screen) — fixed in `3e1c193dc`.
  `RecipeSaveNavigation.afterSuccessfulSave` passes `savedRecipe`, not a bare id.
- **BUT-1782** (notification-prefs local cache was a stub) — fixed in `3e1c193dc`.
  `NotificationPreferences.toJson`/`tryFromJson` are real now, with a BUT-1799 follow-up note.
- **BUT-1784** ("Listan skapad" shown on a failed create) — fixed in `3e1c193dc`.
  `showCreateListDialog` checks `createPersonalList`'s bool before the success snackbar.
- **BUT-1791** (retention job measured only the first 4.5h of its day) — fixed in `3e1c193dc`.
  `compute-feature-retention.ts` now bases everything on the previous full UTC day.
- **BUT-1789** (feature-retention per-user rows never erased) — fixed in `3e1c193dc`.
  `deleteFeatureRetentionFlags` in `account-deletion-cascade.ts` sweeps them.
- **BUT-1777** (shared-list permission dialog used the live, not opened, base) — fixed in
  `3e1c193dc`. `viewedBase` doc comment names the ticket directly.
- **BUT-1788** (leave group / remove member always denied) — the dedicated
  `leave-group-conversation.ts` Cloud Function (wired to the client at
  `conversation_mutation_module.dart:339`) now owns this server-side, reading/writing the
  canonical top-level `conversations` doc. Shipped across `3e1c193dc` / `cf5cfdc0b`.
- **BUT-1819** (sanitized title/description discarded when a new recipe needed ingredient
  normalization) — fixed in `cc45d5c83`. `FirebaseRecipeRepository.create` now rebuilds from
  `recipeToSave`, with a comment citing the ticket.

None of these were re-selected. Recommend closing all eight citing the commits above.

## Agent A — backend-security-gdpr (6 tickets, Tier C, full-panel router tier)

Area: firestore.rules + functions/src (account deletion cascade, TTL indexes) + the messages
repository module. All six share files, so they run as one batch/worktree, not six.
Router (`tools/stakeholder_router.py`) returns **full-panel** on `firestore.rules` +
`account-deletion-cascade.ts` — Security Architect, Privacy/DPO, Trust & Safety, Database
Admin, Software Architect, Legal, Product, FinOps. `requiresPlanMode: true` on every ticket
in this batch.

- [ ] **BUT-1832** [build — Malin decided 2026-08-13, see her comment in-ticket: "fix it,
  not remove the button"] Poll voting denied for everyone but the poll's author
  (`firestore.rules` messages-update rule keys on `senderId`). Ship the read-receipt fields
  (`markMessageAsRead`, `batchMarkAsDelivered`) in the same change — same rule, same trap.
  Design already spec'd by `firebase-backend-security` + `firestore-rules-tester` in the
  ticket body: separate `allow update` statements per branch (never OR'd into one — a CEL
  error in one operand can sink the others), the `.get(k,{}) is map` null-safe ternary for
  `metadata`, and either the `poll_votes/{voterUid}` subcollection shape or a `hasOnly`
  branch pinning `poll.id/creatorId/question/isClosed/options.size()`. Files:
  `firestore.rules`, `lib/repositories/firebase/modules/message_mutation_module.dart`,
  `functions/src/__tests__/*-rules.test.ts`.
- [ ] **BUT-1835** [build] Same change as BUT-1832, not after it (ticket is explicit: the
  residual is bounded to the poll author ONLY because BUT-1832 is broken — fixing one without
  the other widens a live GDPR gap). Account-deletion cascade leg 1 must also rewrite
  `metadata.poll.creatorId` → `"deleted"` and strip the deleted uid from every option's
  `voterIds`. Files: `functions/src/account/account-deletion-cascade.ts`.
- [ ] **BUT-1833** [build] Delete two dead `firestore.rules` helpers — `isAddingSelfToList`
  (harmless) and `isDocumentOwner` (a trap: reads `resource.data` on `allow create`, which
  doesn't exist yet, so any future caller gets a silent blanket deny). Files: `firestore.rules`.
- [ ] **BUT-1822** [build] Account deletion never erases `conversations/{id}/participants/{uid}`
  (Art. 17). Add a `collectionGroup("participants").where("participantId","==",uid)` deletion
  leg, the matching leg in `probeResidualData`, and a `COLLECTION_GROUP` `fieldOverride` for
  `participantId` in `firestore.indexes.json` (never `--force` deploy — 13 live TTL policies
  are missing from the file). Also: when the cascade deletes a ≤2-participant conversation
  outright, delete its WHOLE participants subcollection too, not just the erased uid's row —
  otherwise the surviving partner's row orphans and stays listable forever. Files:
  `functions/src/account/account-deletion-cascade.ts`, `firestore.indexes.json`.
- [ ] **BUT-1801** [build] Six more sites read recipes from the empty top-level `recipes`
  collection instead of `users/{uid}/recipes` — including the GDPR export and the deletion
  cascade. Sites: `bulk-retag.ts:252,418`, `compute-feature-retention.ts:338`,
  `canonical-rating-aggregation.ts:157`, `account-deletion-cascade.ts:375`,
  `recipe_gdpr_export_operations.dart:66`. Check each against `firestore.rules` for a real
  `match` block, and whether the rewritten queries need a new collection-group index.
- [ ] **BUT-1792** [build] Three more collections stamp `expireAt` with no TTL policy
  (`notification_opened_events`, `report_processing_markers`, `system_ip_audit_caps`), plus
  presence (`activeUsers.expiresAt` — note the different field name, don't copy the others'
  command). Declare `fieldOverrides` with `"ttl": true` (never `false`, never bare — omit the
  key to leave an existing policy alone) in `firestore.indexes.json`, update
  `EXPECTED_TTL_GROUPS` in `firestore-ttl-policies.test.ts`, and replace the now-false "Manual
  setup required" heading in `record-notification-opened.ts`.

## Agent B — recipe-social-sharing (1 ticket)

Area: recipe sharing. Router: single (Software Architect, Product Manager).
`requiresPlanMode: true` (priority High).

- [ ] **BUT-1812** [build-review — genuine design choice, not mechanical] Re-sharing a
  recipe someone else already shared silently adds nobody: `shared_content` uses `recipeId`
  as the doc id, and the second sharer is denied both the read-probe and the write. Two
  candidate fixes in the ticket; **recommend Option 2** (stop reusing `recipeId` as the doc
  id — auto-id documents, matching `social_menu_operations` and
  `shopping_social_share_module`) over widening the rule, both because it's more consistent
  with the sibling writers AND because it avoids a `firestore.rules` edit that would conflict
  with Agent A's batch. Needs a migration story for existing rows before BUT-1809's backfill
  runs. Files: `lib/services/unified/operations/modules/recipe_sharing_manager.dart`.
  Signoff: which fix approach, and the backfill/migration shape for existing `shared_content`
  rows.

## Agent C — recipe-safety-ui (1 ticket)

Area: recipe cards / allergen safety. Router: single (Creative Director / Brand Lead).
`requiresPlanMode: true` (priority High).

- [ ] **BUT-1780** [build-review — UI/safety tradeoff, signoff named in the ticket itself]
  Allergen/dietary badges never render on any recipe card in any list or grid —
  `showAllergenBadges`/`showDietaryBadges` default `false` and nothing in the repo ever
  passes `true`, despite the user-facing setting (`showOnCards`) defaulting ON. Add the
  passthrough on `ContentCard` (or derive from `userAllergenPrefs`/`userDietaryPrefs != null`,
  which `recipe_card_widget.dart` already populates) and forward into the `RecipeCard(...)`
  call at `content_card.dart:246`. Files: `lib/widgets/common/content_card.dart`,
  `lib/widgets/recipe/recipe_card.dart`. Signoff: does turning badges on override the
  deliberate "clean list cards by default" redesign intent (comment at `recipe_card.dart:80`)?

## Not selected this sprint — real work, deferred for batch-conflict / capacity reasons

All confirmed still open (not obsolete), all worth building, all excluded only because they'd
collide with Agent A's `firestore.rules` / `account-deletion-cascade.ts` edits or because N
is capped at 8 this round: **BUT-1795** (the root two-storage-locations fix — High, Tier C,
needs its own dedicated session), **BUT-1830** (Urgent — conversation-id squatting, same
root cause as 1795), **BUT-1831** (Urgent — DM send fails on every attempt for 3 independent
reasons, root fix is reading the top-level conversation), **BUT-1796**/**BUT-1828** (add-member
to a group has never worked), **BUT-1825**, **BUT-1829**, **BUT-1823**, **BUT-1824**,
**BUT-1827**, **BUT-1834**, **BUT-1716** (second shared-shopping write path with no
attribution). Recommend a dedicated messaging/rules sprint next, seeded from BUT-1795.

## Needs Malin (not built)

- **BUT-1747** — GDPR export missing shopping lists the user LEFT. Real gap, but needs a new
  server-side Cloud Function and a deploy slot; her own prior comment recommends bundling the
  deploy with BUT-1731's. Not squeezed into this round.
- **BUT-1731** — deploy-day ops task (`backfillSharedListContributors` + delete the stale
  export). Needs production access this loop doesn't have.
- **BUT-1693** — Part 2 of household allergen sharing. Malin approved the DPIA/consent/policy
  2026-08-12 (data layer shipped), but the ticket's own "Sequence" section requires
  `/stakeholder-review` + `/interview` before any code, AND its next step (the `firestore.rules`
  match block) would collide with Agent A's rules edits this round regardless.

## Post-sprint (mandatory)

1. Full `dart analyze --fatal-infos`.
2. File follow-up tickets for anything deferred mid-batch before commit.
3. Commit through the review gates named in `shared-plugin.json → reviewGates` — Agent A's
   batch triggers `firebase-backend-security`, `firestore-rules-tester`, and
   `cloud-functions-specialist` at minimum given the full-panel router tier.
4. Push (push does not trigger deploy in this repo — `ship.pushTriggersDeploy: false`).
5. Transition: Tier A/build + all-pass → Done. build-review or any failed/unclear criterion →
   In Review + plain-language comment + PushNotification.
6. Close the 8 obsolete tickets above, citing their resolving commits.
7. Report written for Malin: plain-language paragraph per shipped ticket.

---

# ARCHIVE — IN EXECUTION 2026-08-12 — the rules/model drift sprint

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
