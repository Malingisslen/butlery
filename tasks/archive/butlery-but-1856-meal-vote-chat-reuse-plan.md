# BUT-1856 alternativ B — en omröstningschatt per social grupp

## Context

`SocialGroupDetailViewModel.startMealVotePoll` (`lib/viewmodels/social_group_detail_viewmodel.dart:442`)
anropar `MessagingService.createGroupConversation` vid **varje** omröstning. Sedan BUT-1838 går
det anropet genom `createChatGroup`-callablen, som i en transaktion skriver ett `chat_groups`-
dokument, en konversation, en rosterrad per medlem och ett systemmeddelande. Resultat: varje
"Vad ska vi äta?" skapar ett permanent gruppobjekt, och gruppchattar går inte att radera i
listan (`conversations_list_view.dart:424` döljer radera-valet när `groupId` finns). Efter några
månaders veckoomröstningar är chattlistan full av döda grupper.

Dessutom: en social grupp där du är ensam ger `invalid-argument` från servern
(`create-chat-group.ts:79-84`), vilket är en beteendeförändring mot den gamla vägen. Vyns
snabbkoll `group.friendUserIds.isEmpty` (`group_detail_view.dart:273`) fångar det **inte** —
ägaren ligger själv i `friendUserIds` (`friend_categories_operations.dart:100`), så listan är
aldrig tom och det tekniska felet når hela vägen fram.

Målet: **skapa chatten första gången, återanvänd den sedan.** Ett gruppobjekt per social grupp
i stället för ett per omröstning.

## Bedömningar som styr bygget (läs dessa först)

1. **Minderårighetsgrinden prövas mot ANROPAREN, inte mot kategoriägaren.** Att pröva mot ägaren
   vore en försvagning och ligger utanför BUT-1838:s beslut. Fälld av en blind Trust &
   Safety-granskning 2026-08-22; detaljer under "Vald lösning".
2. **Den som tas bort ur den sociala gruppen åker ur chatten** (Malins val 2026-08-22), men
   **den som själv lämnat chatten sätts aldrig tillbaka** av synken.
3. **Pekaren mellan social grupp och chatt lagras på chattgruppen**, inte på kategorin, och slås
   upp på ägare **och** kategori-id tillsammans — kategori-id:t är ett klientvalt UUID och duger
   inte ensamt som nyckel.
4. **En enmansgrupp nekas** med ett tydligt svenskt meddelande i stället för dagens tekniska fel.
   Att tillåta en ensamchatt skulle riva upp BUT-1830.

## Vald lösning

Kopplingen lagras **på chattgruppen**, inte på den sociala gruppen: två nya fält
`sourceCategoryId` och `sourceCategoryOwnerId` på `chat_groups/{groupId}`. En ny callable
`ensureCategoryChat` slår upp eller skapar chatten och returnerar dess id.

**Båda fälten behövs, och det är en säkerhetsspärr, inte redundans.** Kategori-id är ett UUID
som klienten själv väljer (`friend_categories_operations.dart:89`, `Uuid().v4()`, skrivet med
`.doc(category.id).set(...)`), och `firestore.rules:462` sätter inga villkor på dokument-id:t.
En nuvarande eller tidigare medlem känner till id:t (collection-group-läsningen på
`firestore.rules:2853` visar det). Med bara `sourceCategoryId` i uppslaget kunde de skapa en
kategori med **samma id under sitt eget uid**, passera ägarkontrollen legitimt, få tillbaka
offrets chattgrupp och sedan låta synken kasta ut alla riktiga medlemmar och sätta in sig själv.
Uppslaget filtrerar därför på båda fälten. Två likhetsfilter på olika fält behöver inget
composite-index i Firestore.

Varför inte ett fält på `FriendCategory`:
- `FriendCategory.toFirestore()` skriver **alla** fält och `saveCategory()` gör `.set(...)` utan
  merge — en klient med en äldre kopia av kategorin skulle radera pekaren tyst.
- Medlemmar (icke-ägare) får bara skriva `friendUserIds` + `updatedAt`
  (`firestore.rules:486`), så en medlem som startar första omröstningen kunde inte spara pekaren
  → varje medlemsomröstning skulle fortsätta skapa nya chattar. Det hade krävt en regeländring.
- `chat_groups` uppdateras av klienter **bara** via en `hasOnly(['name','updatedAt'])`-allowlist
  (`firestore.rules:1937-1944`) och skapas/raderas enbart av Admin SDK. Fältet är därmed
  omöjligt att manipulera från en klient **och kräver ingen regeländring alls.**
- Blir chattgruppen raderad försvinner pekaren med den — uppslaget hittar inget och skapar en ny.
  Ingen "trasig pekare"-hantering behövs.

Chatten skapas alltid med **kategoriägaren** som creator/admin, även när en annan medlem startar
omröstningen — det garanterar att chatten alltid har en admin som finns kvar. Men
**minderårighetsgrinden prövas mot ANROPAREN, inte mot ägaren**, och detsamma gäller
`assertAgeCompliant`, `assertAccountMatured` och rate-limiten. Creator och grindens subjekt
behöver inte vara samma person, och att pröva grinden mot ägaren vore en försvagning: en
utomstående i gruppen kunde då sätta ett barn i chatt med sig själv på ägarens vänskap, utan att
ägaren gjort något. Det är precis det BUT-1838 stängde ("per PERSON per INVITE"), och den
accepterade avvikelsen från 2026-08-13 gäller den som *bjuder in* — inte någon annan.
Genomgången av Trust & Safety-perspektivet 2026-08-22 fällde den första varianten av den här
punkten; det här är den rättade.

### Medlemsförändringar (Malins beslut 2026-08-22)

Vid varje omröstning synkas chattens roster mot kategorin:
- **Nya medlemmar läggs till.** De ser bara omröstningar från och med att de kom med
  (`memberSince`-avgränsningen från BUT-1838) — gammal historik förblir stängd.
- **Borttagna medlemmar tas ut ur chatten.** Malins val: att ta bort någon ur gruppen ska också
  stoppa deras tillgång till gruppens nya omröstningar. Ägaren tas aldrig bort av synken.
  `stageMemberRemoval` raderar även deras rosterrad och `memberSince`, så en person som tas bort
  och senare läggs till igen får en ny avgränsning — de ser inte omröstningarna från sin första
  period. Det är avsiktligt.
- **Den som själv lämnat chatten sätts ALDRIG tillbaka av synken.** Utan detta blir "lämna
  chatten" verkningslöst — nästa omröstning drar in personen igen, och för en minderårig är att
  lämna gruppen just den utväg som måste hålla. Därför får `chat_groups` ett
  `departedUserIds`-fält: `stageMemberRemoval` lägger till uid:t där, `stageMemberAdditions` tar
  bort det (en uttrycklig inbjudan är en mänsklig handling och ska gå igenom), och synken hoppar
  över alla uid:n som ligger i listan.
- **Ingen skillnad = noll skrivningar.** Inget systemmeddelande, ingen notis. Samma tidiga
  återvändo som `add-chat-group-members.ts:132-137`. Annars blir omröstningsknappen en knapp som
  spammar hela gruppen med "X har lagts till".

## Steg

### 1. `functions/src/groups/chat-group-writes.ts`
- `stageGroupCreation` får valfria `sourceCategoryId`, `sourceCategoryOwnerId` och `adminUids` i
  sin `params`. De två pekarfälten skrivs bara tillsammans och bara när de finns; `adminUids`
  faller tillbaka på `[creatorUid]`, vilket är exakt dagens beteende för alla befintliga
  anropare.
- `stageMemberRemoval` får en valfri `tombstone`-flagga (default `false` = dagens beteende) som
  lägger uid:t i `departedUserIds` (`arrayUnion`) i samma gruppuppdatering som redan tar bort dem
  ur `memberIds`/`adminIds`. **Bara `removeChatGroupMember` sätter den** — alltså när någon
  själv lämnar chatten eller kastas ut av en admin. Synken sätter den inte (då speglar den bara
  kategorin, och läggs personen tillbaka i kategorin ska de tillbaka i chatten), och
  raderingskaskaden sätter den inte (att skriva in ett raderat uid vore raka motsatsen till
  radering).
- `stageMemberAdditions` tar bort de tillagda uid:na ur `departedUserIds` (`arrayRemove`) — en
  uttrycklig inbjudan upphäver gravstenen, en automatisk synk gör det inte.

### 2. `functions/src/groups/create-chat-group.ts`
- `createChatGroupWithDeps` får ett valfritt options-objekt (`sourceCategoryId`, `adminUids`) som
  skickas vidare till `stageGroupCreation`.
- Lägg `memberIds.length < 2`-kontrollen (idag rad 79-84 i `onCall`-wrappern) **också** i
  `createChatGroupWithDeps`, så den är enhetstestbar och gäller för den nya callablen.
  Wrapperns egen kontroll blir kvar oförändrad — den ligger *före* `assertAgeCompliant`,
  `assertAccountMatured` och `checkRateLimit` (rad 93-99), och att bara flytta den skulle låta en
  enmansförfrågan bränna en rate-limit-token och få ett åldersfel i stället. Detta täpper också
  en befintlig testlucka: idag finns inget test alls för <2-medlemsvägran.

### 3. Ny fil `functions/src/groups/ensure-category-chat.ts`
Följer mönstret från `add-chat-group-members.ts` rakt av.

`ensureCategoryChat({ ownerId, categoryId })`, `onCall` med `enforceAppCheck: true`:
1. `request.auth` krävs; `isValidDocId` på båda argumenten; `assertAgeCompliant` +
   `assertAccountMatured` **på anroparen** (aldrig på ägaren — anroparens behörighet får inte
   lånas av någon annans konto); `checkRateLimit(callerUid, "ensureCategoryChat")`, också
   anroparnycklad, annars kan en medlem tömma ägarens budget och slå ut funktionen för hela
   gruppen.
2. Delegerar till `ensureCategoryChatWithDeps(db, callerUid, ownerId, categoryId)`.

`ensureCategoryChatWithDeps`:
1. Läs `users/{ownerId}/friend_categories/{categoryId}` **på servern, i samma transaktion som
   skrivningarna** — medlemskapet får aldrig komma från anropets payload och aldrig från en
   läsning utanför transaktionen. Saknas dokumentet, eller är anroparen varken `ownerId` eller
   med i `friendUserIds` → `permission-denied "Not allowed."` — samma no-oracle-formulering som
   `add-chat-group-members.ts:110`, så "finns inte" och "inte din" ser likadana ut.
   Finns chatten redan måste anroparen dessutom vara **ägaren eller nuvarande medlem i chatten**.
   Annars kan någon som en admin kastat ut ur chatten gå in igen via synken och kringgå
   `authorizeDeparture` (`remove-chat-group-member.ts:99`).
2. Önskad roster = `[...new Set([data.ownerId, ...friendUserIds].filter(isValidDocId))]`. Ägaren
   ligger normalt redan i `friendUserIds` och kan ligga där dubbelt (se antagande 1) —
   `new Set` är alltså inte kosmetik utan det som gör rostern riktig. Färre än 2 →
   `failed-precondition` med `details: { reason: "group-too-small" }` — en **strukturerad**
   detalj, inte en textsträng klienten får leta i. Fler än `MAX_CHAT_GROUP_MEMBERS` →
   `invalid-argument`.
3. Slå upp befintlig chatt:
   `chat_groups.where("sourceCategoryId","==",categoryId).where("sourceCategoryOwnerId","==",ownerId).limit(1)`.
   Enbart likhet → inget composite-index behövs och inget i `firestore.indexes.json` ändras.
   En grupp som saknar fälten helt (allt som skapats före den här ändringen) matchar inte, vilket
   är rätt svar: den är ingen kategori-chatt.
4. **Hittad:** jämför `memberIds` mot önskad roster.
   - Saknade uid:n (minus `departedUserIds`) läggs till via `findInadmissibleMembers`
     (minderårighetsgrinden, prövad mot **anroparen**) + `stageMemberAdditions`, i en transaktion
     som läser om gruppen inuti sig — samma race-skydd som `add-chat-group-members.ts:168-197`.
     Ett blockerat uid fäller **hela** anropet med `permission-denied` och `blockedUserIds` i
     `details`; att tyst hoppa över barnet är uttryckligen förbjudet
     (`minor-membership-gate.ts:166-177`) och "omröstningen funkar men ungen saknas" är sämre än
     ett nej.
   - Överflödiga uid:n (i chatten men inte i kategorin) tas bort via `stageMemberRemoval`.
     `ownerId` undantas alltid.
   - **Varje faktisk förändring skriver sin systemrad**, `memberAdded` respektive `memberLeft`,
     precis som `add-chat-group-members.ts:199-214` och `remove-chat-group-member.ts:241-243`.
     Att folk dyker upp och försvinner tyst i en chatt är sämre än en rad för mycket.
   - Ingen skillnad → inga skrivningar alls, ingen systemrad, ingen notis.
   - Returnera `{ conversationId: groupDoc.id }`.
5. **Inte hittad:** `createChatGroupWithDeps(db, callerUid, category.name, roster, { sourceCategoryId: categoryId, adminUids: [callerUid, ownerId] })`
   och returnera dess id. Anroparen förblir creator och grindens subjekt; ägaren seatas som
   admin **vid sidan av** anroparen, så gruppen alltid har en admin som finns kvar när anroparen
   lämnar kategorin. Är anroparen ägaren — det vanliga fallet — är resultatet identiskt med
   dagens beteende. (`groupId === conversationId` per konstruktion, `create-chat-group.ts:126-128`.)

### 3b. `functions/src/account/account-deletion-cascade.ts` — Art. 17
`departedUserIds` är råa uid:n på ett dokument andra läser, precis som `memberIds`. Dagens
`deleteChatGroupMemberships` (rad 2553) hittar bara grupper via
`memberIds array-contains uid` — någon som redan lämnat en grupp ligger inte i `memberIds` och
skulle därmed bli kvar för alltid. Lägg till en andra, likadant kapad sökning på
`departedUserIds array-contains uid` som `arrayRemove`:ar uid:t, med samma
DECLINE-över-taket-beteende som resten av filen (`MAX_CHAT_GROUPS_PER_USER`). Ett fall i
`functions/src/__tests__/account-deletion-cascade.test.ts` som bevisar att ett uid som **bara**
finns i `departedUserIds` faktiskt raderas.
GDPR-exporten rörs inte: `lib/services/account/export/chat_group_export.dart` är en projektion
och ska inte börja exportera andras uid:n.

### 4. `functions/src/index.ts`
`export { ensureCategoryChat } from "./groups/ensure-category-chat";` bredvid rad 94-96.

### 5. `functions/src/middleware/rate_limiter.ts`
Ny post `ensureCategoryChat: { maxTokens: 5, refillRate: 5, refillIntervalMs: 60000, dailyLimit: 50 }`
— **samma tak som `createChatGroup`** (rad 123-128). Callablen kan skapa en grupp och går förbi
create-hinken helt, så en lösare hink här skulle i praktiken dubbla burst-taket för
gruppskapande.
Registrera också callablen i `USER_FACING` i `functions/src/__tests__/app-check-enforcement.test.ts` —
det testet blir rött på en oklassad `onCall` tills dess, och det är vakten som fungerar.
Exporten i `index.ts` måste ligga **under** `setGlobalOptions`, annars deployas funktionen till
us-central1 (`deploy-manifest.test.ts` kontrollerar region och maxInstances).
Kommentaren på rad 84-88 räknar antalet fastnaglade `dailyLimit` ("All FOUR are pinned") och
kräver uttryckligen att en femte naglas i samma edit → uppdatera meningen till FIVE och lägg till
ett fall i `functions/src/__tests__/rate-limiter-daily-cap.test.ts`.

### 6. Dart-klienten
- `lib/repositories/interfaces/chat_group_repository.dart`: `Future<String> ensureCategoryChat({required String ownerId, required String categoryId})`.
- `lib/repositories/firebase/firebase_chat_group_repository.dart`: implementation via befintliga
  `_call('ensureCategoryChat', {...})`, samma `groupId`-validering som `createGroup` (rad 96-114).
  `_call` låter `FirebaseFunctionsException` passera med sin `code` intakt.
- `lib/services/messaging_service.dart`: `ensureCategoryChat(...)` som delegerar till repot —
  samma lagerform som `createGroupConversation` (rad 165). `createGroupConversation` blir kvar,
  den används fortfarande av `conversations_viewmodel` och `create_group_conversation_viewmodel`.
- `lib/core/errors/chat_group_error_mapper.dart` **finns redan** och är den enda plats där
  callable-fel blir svensk text (`map(error, genericFallback:)`, rad 30). Lägg
  `failed-precondition` + `details['reason'] == 'group-too-small'` där, inte i vyn. Ett
  `failed-precondition` **utan** den detaljen ska falla igenom till det generiska felet, annars
  sväljer grenen framtida fel.
- `lib/viewmodels/social_group_detail_viewmodel.dart` — `startMealVotePoll`:
  ersätt `createGroupConversation`-blocket (rad 460-476) med
  `messagingService.ensureCategoryChat(ownerId: _group!.ownerId, categoryId: _group!.id)`.
  `participantIds`/`displayNames`/`avatarUrls` faller bort helt (de skickades ändå ingenstans —
  se kommentaren `messaging_service.dart:156-164`).
  **Metodens doc-kommentar ljuger idag:** `executeAsync` gör `setError(...); rethrow`
  (`lib/core/mixins/state_notifier_mixin.dart:168-171`), så metoden *kastar* i stället för att
  returnera `null`, och `if (conversationId == null)`-snackbaren i vyn (rad 334-340) är
  oåtkomlig vid just det fel biljetten handlar om. Lägg en `try/catch` runt `executeAsync` som
  sätter `ChatGroupErrorMapper.map(...)` och returnerar `null`. Utan den kan kravet "tydligt
  svenskt meddelande" inte uppfyllas.

### 7. Text
Två nya nyckelpar, placerade intill det befintliga `chatGroup*`-blocket. Mallfilen är **sv**
(`l10n.yaml`), så båda måste in i `app_sv.arb` och `app_en.arb`:
- `chatGroupNeedsAnotherMember` — "Gruppen behöver minst en medlem till innan ni kan rösta om mat."
- `mealVotePollFailed` — "Det gick inte att starta omröstningen. Försök igen."

Återanvänds i stället för nya nycklar: `groupNoMembersToShare` (vyns snabbkoll),
`chatGroupAddMembersBlocked` (minderårighetsgrindens nej), `errorRateLimitExceeded`,
`errorServiceUnavailable`. `chatGroupCreateFailed` passar **inte** som generiskt fall — chatten
finns ju redan när bara omröstningen misslyckas.

Kör `flutter gen-l10n` — den genererade filen behåller annars den gamla strängen och analyzern
klagar inte (lärdom BUT-1783/1693); grepa den genererade filen efter den nya texten.

### 8. Vy — `lib/views/social/group_detail_view.dart`
Snackbaren på rad 334-340 visar idag alltid `errorServiceUnavailable`. Byt till
`_viewModel.errorMessage ?? context.l10n.errorServiceUnavailable` så det mappade meddelandet
faktiskt når fram. Snabbkollen på rad 273 (`friendUserIds.isEmpty` → `groupNoMembersToShare`)
behålls, med en kommentar om att den sparar en nätverksresa men **inte** är spärren — spärren
sitter på servern.

## Tester

**Cloud Functions** — ny `functions/src/__tests__/ensure-category-chat.test.ts` (testerna ligger
platt i `__tests__`, det finns ingen `groups/__tests__`-katalog), `FakeFirestore` +
`_unit-runner` precis som `chat-group-callables.test.ts`. Filen måste namnges av ett
`test:ensure-category-chat`-script i `functions/package.json` i **samma commit** — annars fäller
`functions/scripts/check-test-registration.js` commiten, och namnet måste ligga på unit-lanen
(inte `test:rules:*`, inte `test:integration:*`) för att `run-ci-unit-tests.js` ska hitta den:
1. Första anropet skapar en grupp och stämplar `sourceCategoryId`.
2. **Andra anropet returnerar samma id och skriver inget nytt** — assertion mot `fake.writes`,
   inte bara mot returvärdet. Detta är biljettens kärna.
3. En ny medlem i kategorin läggs till i den befintliga chatten.
4. **Minderårighetsgrinden prövas mot anroparen, inte ägaren:** en medlem som INTE är vän med
   den minderåriga i kategorin får hela anropet nekat med `permission-denied` och
   `blockedUserIds`, och ingen chatt skapas. Samma scenario med ägaren som anropare går igenom.
5. **Den som lämnat chatten sätts inte tillbaka:** medlem lämnar → en annan medlem startar en
   omröstning → personen är fortfarande utanför. Läggs de till uttryckligen via
   `addChatGroupMembers` kommer de med.
6. **Ingen rosterskillnad → noll skrivningar.** Tio omröstningar i rad ger ett enda
   systemmeddelande (det från skapandet).
7. En medlem som lämnat kategorin tas bort ur chatten; ägaren tas aldrig bort.
8. **Enmansgrupp ger `failed-precondition` med `details.reason == 'group-too-small'` och skriver
   ingenting.** Två fixturer: `friendUserIds: []` och `friendUserIds: [ownerId]` — den andra är
   det verkliga fallet, eftersom ägaren ligger i listan, och en naiv `length >= 1`-koll missar den.
9. Utomstående anropare ger `permission-denied`; icke-existerande kategori ger samma svar. Den
   som kastats ut ur chatten men fortfarande står i kategorin får också `permission-denied`.
10. Raderad chattgrupp (uppslaget tomt) → ny grupp skapas, pekaren stämplas om.
10b. **Kapningsförsöket:** en annan användare skapar en kategori med **samma id** under sitt eget
    uid och anropar callablen. Offrets chattgrupp får inte returneras, dess `memberIds` ska vara
    orörda, och angriparen får en egen ny chatt. Det här är testet som håller
    `sourceCategoryOwnerId` på plats när någon senare vill "förenkla" uppslaget.
10c. En grupp som saknar fälten helt (skapad före den här ändringen) matchar inte uppslaget.
11. I `chat-group-callables.test.ts`: det flyttade <2-villkoret i `createChatGroupWithDeps`, och
    att `adminUids` default fortfarande ger exakt `[creatorUid]` för befintliga anropare.
12. I `account-deletion-cascade.test.ts`: ett uid som bara ligger i `departedUserIds` raderas.

**Dart** — `test/unit/viewmodels/social_group_detail_viewmodel_test.dart` (idag noll täckning för
`startMealVotePoll`). VM:n hämtar `MessagingService` via `ServiceLocator.get<T>()` inuti metoden,
så suiten måste byta `setUpAll` till `BaseUnitTest.setupUnitWithProductionLocator()` och registrera
en `MockMessagingService` i GetIt — samma mönster som
`test/unit/viewmodels/cooking_mode_viewmodel_test.dart:34-68`.
1. Två omröstningar i rad → `ensureCategoryChat` anropas två gånger men returnerar samma id, och
   `sendPollMessage` anropas två gånger mot **samma** konversation.
2. `createGroupConversation` anropas **aldrig** längre från den här vägen.
3. `failed-precondition` med `details['reason'] == 'group-too-small'` → VM:n **kastar inte**,
   returnerar `null` och sätter `errorMessage == chatGroupNeedsAnotherMember`. Det här fallet är
   rött idag eftersom `executeAsync` gör `rethrow`.
4. Ett generiskt fel → `errorMessage == mealVotePollFailed`, returnerar `null`.
5. `getUserProfiles` stubbad till `[]` (profiler som inte går att läsa) → omröstningen lyckas
   ändå, eftersom rostern nu räknas ut på servern. Det pinnar precis det felläge biljetten nämner.
6. Ingen inloggad / ingen grupp laddad → `null`, som idag.

`test/unit/core/errors/chat_group_error_mapper_test.dart`: `failed-precondition` med rätt
`reason` ger den nya texten; `failed-precondition` **utan** den faller till det generiska, så
grenen inte sväljer framtida fel.

`test/unit/services/messaging_service_test.dart` får ett fall för den nya delegeringen; de
befintliga `createGroupConversation`-testerna är orörda.

## Gates och verifiering

Granskningsagenter som måste köra på diffen (per `.claude/shared-plugin.json → reviewGates`):
`cloud-functions-specialist` (functions/src), `firebase-backend-security` (lib/repositories),
`testing-specialist` (lib), `code-reviewer` och `integration-reviewer` (.dart).
**Ingen** `firestore-rules-tester` — `firestore.rules` ändras inte och inget
`*-rules.test.ts` rörs.
Diffen är ~10 filer, och agenter stannar över tre filer, så `code-reviewer` och
`integration-reviewer` körs i omgångar om tre; markören sätts först efter sista omgången.

Bokföring som annars glöms:
- `docs/architecture/ACCEPTED_LARGE_FILES.md:100` anger 1 028 rader för `messaging_service.dart`;
  filen är redan 1 031 och växer med den nya metoden. Uppdatera raden i samma commit — den
  senaste commiten i loggen finns just för att två sådana rader bar fel siffra.
  Kontrollera `social_group_detail_viewmodel.dart` (511 rader, allowlistad) på samma sätt.
- Redigeringar av mappad kod stämplar `docs/onboarding/workflow-map.stale`. Spåra om **bara** de
  flöden markören listar, uppdatera `<script id="data">`-JSON:en, kör
  `python tools/check_workflow_map.py`, ta bort markören, committa båda.
- Planfilen kopieras till `tasks/butlery-but-1856-meal-vote-chat-reuse-plan.md` när bygget
  startar — den globalt delade plans-katalogen kräver projektprefix.

Kör:
- `cd functions && npx ts-node src/__tests__/ensure-category-chat.test.ts`
- `cd functions && npm run test:chat-group-callables` + `npx ts-node src/__tests__/rate-limiter-daily-cap.test.ts`
- `flutter analyze`
- `flutter test test/unit/viewmodels/social_group_detail_viewmodel_test.dart test/unit/services/messaging_service_test.dart test/unit/models/friend_category_test.dart`
- Verifiering i appen: skapa en social grupp med en vän, kör "Vad ska vi äta?" två gånger, och
  bekräfta att chattlistan innehåller **en** grupp med två omröstningar i.

Deploy av en ny funktion: `firebase deploy --only functions:ensureCategoryChat`, och kontrollera
per-funktions `state` från `--json` efteråt (en deploy kan gå igenom rent och ändå lämna tjänsten
`FAILED`).

## Kostnad

Per omröstning: ett funktionsanrop, en dokumentläsning av kategorin och en enfältsfråga mot
`chat_groups`. Omröstningar är sällsynta och användarstartade. I gengäld försvinner det som idag
är en hel grupptransaktion (gruppdokument + konversation + N rosterrader + systemmeddelande) vid
varje omröstning — nettot är färre skrivningar, inte fler.

## Open questions

Ställd och besvarad via AskUserQuestion (2026-08-22): borttagna medlemmar **ska** ut ur chatten
— infälld i "Medlemsförändringar" ovan.

En blind Trust & Safety-granskning av barnsäkerhetsdelen kördes 2026-08-22 och fällde den första
varianten (grinden prövad mot ägaren). Alla dess villkor är infällda ovan; ingen ny accepterad
avvikelse behövs, eftersom planen nu ligger inom BUT-1838:s beslut i stället för att töja det.

Inga arkitekturändrande okända kvar. Antaganden som styr bygget:
1. Kategoriägaren ligger normalt **i** `friendUserIds` — skapandet lägger in hen där
   (`friend_categories_operations.dart:100`) och `migrateOwnersAsMembers()` lägger in hen igen
   vid varje inloggning, så id:t kan förekomma dubbelt. Önskad roster är därför
   `unique([ownerId, ...friendUserIds])`, och dubbletten absorberas av `new Set`. Ett test pinnar
   både dubblett-fallet och det tomma fallet. (En tidigare version av den här planen påstod
   motsatsen; den var fel och rättades av regelgranskningen 2026-08-22.)
2. Ägarbyte flyttar fältet `ownerId` men **inte** dokumentets sökväg
   (`friend_category_repository.dart:321,338` uppdaterar under den gamla ägarens path). För en
   överlämnad grupp pekar `FriendCategory.ownerId` alltså inte på den path dokumentet ligger på,
   och callablen hittar då ingenting → samma no-oracle-nej som för en främling. Sådana grupper
   kan idag ändå inte redigeras av sin nya ägare (`isOwner(userId)` läser path-segmentet), så det
   är en befintlig defekt, inte en ny. Egen biljett; den ska inte lappas här och inte döljas.
3. `friendUserIds` valideras **inte** mot ägarens riktiga vänlista någonstans i
   `firestore.rules` — ägaren kan skriva in vem som helst. Planen lutar sig därför inte på att
   "gruppens medlemmar är ägarens vänner"; det är minderårighetsgrinden mot anroparen som bär
   säkerheten, inget annat.
4. `chat_groups` GDPR-exporten är en PROJEKTION med sju fält
   (`firebase_data_export_repository.dart:563-575`), så `sourceCategoryId`,
   `sourceCategoryOwnerId` och `departedUserIds` kan inte läcka in i ett Art. 15-paket. Ingen
   exportändring behövs; Art. 17-sidan hanteras av steg 3b.

## Vad det betyder i appen (för Malin)

- "Vad ska vi äta?" skapar en chatt **första** gången. Alla senare omröstningar i samma grupp
  hamnar i den chatten.
- Chattlistan får en rad per social grupp i stället för en rad per omröstning.
- Lägger du till någon i gruppen kommer de med i chatten och ser omröstningar från och med då —
  inte de gamla.
- Tar du bort någon ur gruppen åker de ur chatten vid nästa omröstning.
- Den som själv lämnar chatten dras aldrig in igen automatiskt. För en tonåring är det den enda
  utvägen som måste hålla, och en automatisk synk får inte upphäva den.
- Finns det en tonåring i gruppen kan bara någon som är vän med hen starta den första
  omröstningen. Det är samma spärr som gäller idag när man skapar en gruppchatt — den flyttar
  inte, den följer bara med.
- Är du ensam i gruppen får du ett tydligt meddelande om att du behöver minst en person till,
  i stället för ett tekniskt fel.
- Redan skapade omröstningschattar städas inte upp av det här — appen är inte live, så det finns
  inget att migrera.
