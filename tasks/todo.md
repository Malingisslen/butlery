# BUT-1922 — blockeringslistan får inte läsas ur offline-cachen på stängningsvägen

## Context

När någon stänger en omröstning skrivs vinnaren in i hushållets vecka. Det går inte att ta
tillbaka. Därför byggdes en spärr (BUT-1909): om blockeringslistan inte går att läsa vägrar
appen stänga omröstningen i stället för att gissa.

Spärren täcker fallet "listan gick inte att läsa". Den täcker inte fallet **"listan lästes,
men den var gammal"**. `getBlockedUserIds()` är en vanlig Firestore-läsning, och Firestore
svarar då *utan fel* ur den lokala cachen när enheten är offline. Spärren ser ett giltigt
svar och släpper igenom.

Luckan är smal men verklig: blockeringar du gjort på **den här** enheten ligger i den lokala
skrivkön och syns. Det som saknas är en blockering du gjort på en **annan** enhet medan den
här är offline — då kan den blockerades röst fortfarande avgöra veckans meny.

Utfall: stängningsvägen vägrar när listan inte är bevisat färsk. Visningsvägen ändras inte —
där är det rätt att hellre visa en tillfälligt ostädad chatt än en tom.

---

## Beslut som styr bygget

**1. Stängningsvägen får kosta en extra läsning.** Antaget, inte frågat. Stängning sker en
gång per måltidsomröstning, så kostnaden är försumbar mot kostnadsprincipen i CLAUDE.md.
Alternativet är provenienspårning (behåll cachen, men märk om den kom från cache) — mer kod,
samma utfall. Säg till om du hellre vill ha det.

**2. `Source.server` framför en `isFromCache`-kontroll.** Vald för att den är testbar:
`fake_cloud_firestore` sätter `isFromCache` bara när anroparen själv skickar `Source.cache`,
så den kan inte simulera "offline serverar cache åt en vanlig läsning". Med `Source.server`
går beteendet att pinna genom repository-mocken i stället för genom fejken.

**3. Egen feltext när enheten är offline.** *Malins beslut.* Efter den här ändringen blir
offline den vanligaste orsaken till att en stängning vägrar, och dagens text ber användaren
"Försök igen" — vilket misslyckas likadant utan nät. Ny sträng som säger vad man faktiskt ska
göra.

---

## Två saker som måste överleva ändringen

1. **Asymmetrin mellan de två ingångarna.** `currentBlockedIds()` (visning) sväljer fel och
   ger tom mängd. `requireBlockedIds()` (beslut) kastar. Kommentaren på rad 63 i
   `blocked_user_filter.dart` säger rakt ut att en vägransgren skriven mot `currentBlockedIds`
   är död kod. Cache-kontrollen får bara sitta på den senare.
2. **Lösningen får inte servera den senast kända listan som om den vore aktuell.** Det var
   precis felet som lagades en nivå upp i samma omgång (BUT-1909).

## Den dolda halvan: låset gör en ren repository-fix otillräcklig

`BlockedUserFilter` delar cache mellan båda ingångarna. `_initialized` är ett fält som läses
av båda (`blocked_user_filter.dart:44` och `:66`) och sätts bara i `_fetchAndWatch` (`:117`),
som båda vägarna når. Öppnar användaren en chatt offline latchar visningsvägen en
cache-serverad mängd — och `requireBlockedIds()` returnerar sedan den **utan att läsa
någonting alls**. En kontroll som bara sitter i repositoryt skulle aldrig köra på den väg den
finns för.

Därför måste stängningsvägen läsa om, inte läsa cachen.

---

## Vad som byggs

**1. `lib/repositories/firebase/firebase_block_repository.dart`** — ny läsning bredvid den
befintliga som kräver servern. Samma query som `getBlockedUserIds()` (rad 110), men med
`GetOptions(source: Source.server)`. Offline kastar den `unavailable` i stället för att svara
ur cachen. Mönstret finns redan i repot på de här raderna, alla verifierade:
`firebase_user_repository.dart:282`, `tag_config_service.dart:282`,
`firebase_connectivity_repository.dart:119`. Equality-filter på ett fält, så inget composite
index är skyldigt.

**2. `lib/services/social/blocking/blocked_user_filter.dart`** — dela de två vägarna:

* `requireBlockedIds()` läser alltid färskt från servern och går aldrig via `_initialized`.
  Misslyckas den kastar den, och `closePoll` vägrar som förut. Den delade cachen lämnas orörd — den hålls färsk av visningsvägens watch, och en mängd skriven härifrån skulle sakna något som uppdaterar den.
* Visningens kallstart flyttas till en intern seed-metod som behåller dagens beteende
  (`serverAndCache`, cachen duger, fel → tom mängd via `currentBlockedIds`).
* **Generationsvakten följer med till den nya vägen.** Den nya server-läsningen fångar
  `_generation` före sin `await` och kontrollerar om efteråt, och kastar
  `_disposedDuringFetch` vid avvikelse — precis som `_fetchAndWatch` gör.
  Utan den kan ett `dispose()` mitt i läsningen låta `closePoll` fortsätta på föregående
  användares blockeringslista. Den vakten är alltså inte oförändrad-och-orelevant, den är
  en del av bygget.

**3. Feltexten (beslut 3).** En ny vägransorsak skiljer "offline" från "gick inte att läsa":

* `lib/models/messaging/poll.dart:284` — nytt värde i `PollCloseRefusal` bredvid
  `blockListUnknown`.
* `lib/services/messaging_service.dart:876-891` — klassificera i catch-grenen: en
  `FirebaseException` med `code == 'unavailable'` är offline, allt annat är den befintliga
  orsaken. Vägran sker i båda fallen — bara texten skiljer.
* `lib/viewmodels/chat_viewmodel.dart:514-515` — mappa det nya värdet till den nya nyckeln.
* **Båda ARB-filerna** (`lib/l10n/app_sv.arb`, `app_en.arb`) **plus `flutter gen-l10n`**.
  Utan generatorkörningen behåller den genererade filen den gamla strängen och
  `dart analyze` förblir grön — den fällan står i `lessons-digest.md`.

**4. Testet som fattas kring DI.** BUT-1922 noterade att spärren var opt-in via DI. Den halvan
är redan stängd i koden — BUT-1926 gjorde `closePoll` vägrande även när filtret saknas
(`messaging_service.dart:867-874`). Men inget test hävdar att social-modulen faktiskt
registrerar `BlockedUserFilter`, så en flytt i DI skulle stänga av grinden med varje svit
grön.

Ny fil: `test/unit/core/di/modules/social_module_registration_test.dart` (`test/unit/core/di/`
har i dag bara `locale_provider_singleton_test.dart`, orelaterad). Registreringen sker på
`social_module.dart:328` och kräver `AuthRepository`, så en riktig container-uppbyggnad drar
in Firebase. **Regel för bygget:** gå först på den riktiga registreringen med stubbade
beroenden; går den inte att bygga utan Firebase, fall tillbaka på en påståendetest mot
`providedTypes`-listan (`social_module.dart:119`) **plus** modulens källtext — precis den form
`message_query_module_test.dart:795` redan använder i det här repot. Skriv i testet vilken av
de två det blev och varför.

## Filer

| Fil | Vad |
|---|---|
| `lib/repositories/firebase/firebase_block_repository.dart` | ny server-läsning |
| `lib/services/social/blocking/blocked_user_filter.dart` | dela seed- och beslutsvägen + generationsvakt |
| `lib/models/messaging/poll.dart` | ny vägransorsak |
| `lib/services/messaging_service.dart` | klassificera offline i catch-grenen |
| `lib/viewmodels/chat_viewmodel.dart` | mappa till ny sträng |
| `lib/l10n/app_sv.arb` + `app_en.arb` | ny nyckel, båda filerna, sedan `gen-l10n` |
| `test/unit/services/social/blocking/blocked_user_filter_test.dart` | nya fall |
| `test/unit/core/di/modules/social_module_registration_test.dart` | ny, pinnar registreringen |

Ingen fil är i närheten av 500-radersgränsen (filtret 166, repot 146).

## Tester

Befintlig sele är mocktail mot `FirebaseBlockRepository` — den räcker, ingen ny infrastruktur.

* Stängningsvägen läser från **servern**, inte cachen.
* En cache-latchad visningsläsning **hindrar inte** stängningsvägen från att läsa om — testet
  som fångar den dolda halvan ovan.
* Server-läsning som kastar `unavailable` → `requireBlockedIds` kastar → `closePoll` vägrar.
* **Utloggning mitt i server-läsningen** → `StateError`, ingen cache-skrivning, `closePoll`
  vägrar. (Motsvarar de befintliga generationsfallen för `_fetchAndWatch`.)
* `unavailable` ger den nya offline-orsaken; andra fel ger den befintliga.
* Visningsvägen är oförändrad: offline ger fortfarande cachens lista, och fel ger tom mängd,
  inte en vägran.

Muteringsprov på den nya grenen: tas kontrollen bort ska minst ett test bli rött. **Obs:
muteringsprov i det här trädet måste aviseras först** — flera sessioner arbetar i samma
katalog.

## Granskning

`stakeholder_router.py` gav **tier: single** — Trust & Safety är den matchande rollen. Ingen
full panel. Commit-grinden kräver dessutom `firebase-backend-security` (repositories/services),
`code-reviewer` och `testing-specialist` för Dart-diffen.

## Ordning och koordinering

**Blockeringen är redan uppklarad.** butlery-69:s BUT-1917 steg 1 landade som `cfb8cefbd`, och
`firebase_block_repository.dart` är ren i arbetsträdet med tomt index. Arbetet kan börja
direkt.

Kvar av koordineringen: staga med explicit pathspec, aldrig `git add .`, och säg till
butlery-69 när BUT-1922 är inne — deras steg 5 lägger till läsning i motsatt riktning (vilka
som blockerat *mig*) och behöver samma uppdelning i fail-open och fail-closed. Formen här är
avsedd att kunna återanvändas rakt av.

## Open questions

Inga arkitekturändrande okända. Två frågor ställdes till Malin och är besvarade: filkonflikten
med butlery-69 (vänta — numera uppklarad) och offline-texten (egen sträng). Beslut 1 och 2
ovan är antaganden jag tagit själv och som går att vända utan att bygget ritas om.

BUT-1917:s spegel (steg 2–5) ligger utanför. Den här ändringen ska kunna återanvändas av den,
men bygger inget för den.

## Verifiering före klart

* `flutter analyze` rent.
* `flutter test test/unit/services/social/blocking/blocked_user_filter_test.dart`
* `flutter test test/unit/services/messaging/messaging_service_close_poll_test.dart` — den
  sviten pinnar spärren och får inte tappa något.
* `flutter test test/unit/core/di/modules/social_module_registration_test.dart`
* `flutter gen-l10n` körd, och den genererade filen grepad på den nya strängen.
* `verify`-skillen kör hela kontrollen innan arbetet kallas klart.

## För Malin, i klartext

Blockering fungerar när telefonen har nät. Men blockerar du någon på surfplattan medan mobilen
ligger offline, och sedan stänger en omröstning i mobilen, kan den blockerades röst fortfarande
avgöra vad som hamnar i veckans matsedel — appen läser då en gammal blockeringslista ur
telefonens minne och märker inte att den är gammal.

Efter det här vägrar appen stänga omröstningen i det läget i stället för att gissa, och säger
rakt ut att den är offline i stället för att be dig försöka igen förgäves. Chatten påverkas
inte: där fortsätter den visa det den kan även offline, för en tom chatt vore sämre än en som
är någon minut osorterad.

Det kostar en extra läsning varje gång en omröstning stängs, vilket är försumbart.
