# Plan — Art. 15-exportens fyra öppna frågor: Malins beslut 2026-09-17

## Context

Fyra poster i `docs/architecture/ACCEPTED_DEVIATIONS.md` och `.claude/rules/accepted-deviations.md`
sade att något hålls tillbaka ur Art. 15-bunten, att valet gjordes konservativt **utan att fråga
Malin**, och att motsatsen är hennes beslut. Två hade ticket (BUT-2006, BUT-2094), två levde bara i
regelfilen och var osynliga i backloggen. Alla fyra strypningarna verifierades i källan 2026-09-17
innan frågorna ställdes — koden gjorde exakt vad posterna påstod.

Utfallet efter en full panel och en eskalering: **ingen beteendeändring i exporten.** Alla fyra
strypningarna står kvar, men som BESLUT i stället för som ärvda konservativa val. Kvar att bygga är
en ärlighetsmening om en lucka bunten redan har, två strukna kommentarssatser som blivit falska, och
beslutsposterna.

| # | Sak | Beslut |
|---|---|---|
| 1 | Andra medlemmars `memberSince`, konversationsexporten | **Fortsätt stryp** |
| 2 | `contributorUserIds`, gruppens veckomenyexport | **Fortsätt stryp** (omvänt svar) |
| 3 | `reviewedBy` / `reviewNotes`, ingrediensförslag | **Fortsätt stryp** |
| 4 | Ny sektion för delade listors varurader | **Bordlägg till BUT-1747** |

---

# A — Kvar att avgöra

Alla fyra huvudbesluten är dina och redan tagna. Det här är vad som återstår, och där en rimlig
person kan tycka annat.

### ① Den befintliga meningen som blir falsk — kvalificera eller stryka?

`social_export_manager.dart:554-555` säger i dag `'Everything else these shares held is kept as it
was stored.'` Den blir falsk i samma stund luckan deklareras bredvid den. Tre säten fann det
oberoende.

- **Kvalificera** (mitt förslag): meningen får ett undantag för varuraderna. Läsaren behåller den
  sanna försäkran om resten av delningen.
- **Stryk den helt**: kortare och kan inte bli falsk igen, men bunten tappar en sann mening om att
  inget annat rörts. Kostnad: läsaren får mindre, inte mer.

*Vill du ha strykningen i stället, säg "stryk den".*

### ② Ska grannfilens falska rad med i samma commit?

`preferences_export_manager.dart:298` bär `/// Chosen conservatively without asking Malin;
STRIPPING it is hers to decide.` om `delivered_notifications`. Den har varit **falsk sedan
2026-09-10**, då du beslutade att behålla namnet — posten superseddades i båda avvikelsefilerna,
kommentaren följde aldrig med.

- **Ta med den** (mitt förslag): en rad, samma klass, och precis den syskonkopia lektionerna säger
  blir kvarlämnad.
- **Egen commit**: håller diffen smalare, men en falsk kommentar ligger kvar längre.

*Vill du ha den i en egen commit, säg "egen commit".*

### Svagaste punkten

Den exakta ordalydelsen på rad 4:s nya mening är inte skriven än. UX-sätet ställde två krav som drar
i olika riktningar: den måste vara smal nog att inte läsas på systersektionen (som *har* sina
varurader med), och ändå läsas som en obyggd lucka snarare än en integritetsstrykning. Jag skriver
den vid redigeringen och pinnar den; om den blir klumpig är det där det syns.

---

# B — Bygget

### Rad 4 — den enda produktionsändringen

`lib/services/account/export/social_export_manager.dart`, `exportSharedContent`s
`data_minimisation` (rad 549-555):

- Den blanka meningen kvalificeras (eller stryks, per ①).
- En mening säger att varuraderna i en lista *en vän skickat dig en kopia av* inte ingår, formulerad
  som obyggd lucka och scopad lika tätt som `provenance`-strängen bredvid, så den inte kan läsas på
  systersektionen som läser `unified_shared_shopping_lists` och skickar sina varurader.
- Engelsk prosa i samma register som resten av blocket — konventionen i båda exportfilerna, oavsett
  att appens UI är svenskt.

**Avvisat, med mätning:** UX-sätet föreslog en `data_completeness`-nyckel i stället. Den är ingen
sektionsnyckel — den ligger i `export_metadata` och byggs i `data_export_service.dart:397-419` ur
trunkering och sektionsfel. En obyggd lucka där vore ett påstående om ett fel som inte hänt.

### Beslutsposter — fyra rader, två filer

En daterad supersederande post per rad i BÅDA filerna. Superseder, aldrig stryk: posterna är
beslutsregister och commit-grinden namnger regeln. Varje kopia citerar sin EGEN mening ordagrant, på
EN rad, matchad på **fullt citat plus ticketnummer** — aldrig på den delade frasen.

**Ingen siffra här, och det är avsiktligt.** Arkeologen sa att frasen återkommer tre gånger per fil;
jag skrev en egen rättelse med högre siffror, och planauditören mätte att MIN siffra var fel — mitt
sökmönster var bredare än frasen jag namngav, så det räknade in poster med varianter av ordalydelsen
(`Chosen without asking Malin` utan "conservatively" på docs 2829, BUT-1971:s tomma-roster-post;
`without asking her` i BUT-2044). Räkneordet stryks i stället för att räknas om en tredje gång.

Regeln, som inte rostar: **matcha på fullt citat plus ticketnummer.** Flera obesläktade poster bär
varianter av "chosen without asking", och minst två får inte röras — BUT-1957 (avgjord 2026-09-10)
och BUT-2044 (`social_requests`, öppen, annan fråga). En grep på frasen i någon form är därför inte
ett säkert urval; citatet och ticketen är det.

Verifierade citat, per fil:
- Rad 1 — regelfilen 357-358 / docs 2009-2010. Olika ordalydelse (docs börjar `**That redaction was
  chosen conservatively without asking Malin**`).
- Rad 2 — regelfilen 698-699 / docs 2908-2909. Identiska här.
- Rad 3 — regelfilen 894-895 (`the two fields` … `it is open.`) / docs 3199-3200
  (`reviewedBy`/`reviewNotes` … `it is OPEN.`), plus den bekräftande meningen i BUT-2038-posten,
  regelfilen 1628-1629.
- Rad 4 — regelfilen 2012-2013 / docs 4573. Olika ordalydelse: docs säger `Whether an export SECTION
  ships is Malin's decision and is asked on the ticket;`. Förra planversionen citerade regelfilens
  ordalydelse för båda — Technical Writer fann det, jag verifierade det.

Rad 2:s post måste bära det panelen mätte: att fältet är klient-skrivet och bara append-only-
begränsat (ingen kontroll av att ett uid någonsin var deltagare), att `public_profiles/{uid}` har
`allow read: if isAuthenticated()` så vilket inloggat konto som helst löser ett uid till profilen,
att ett minderårigt uid kan ligga där, och att BUT-2006 fråga 1 står kvar öppen. Och att beslutet
gäller DENNA samling — inte auktoritet för fältet med samma namn på
`unified_shared_shopping_lists`, vilket är det fel BUT-1732:s post finns till för att dokumentera.

Rad 4:s post: bordlagd till serverbygget, inte avvisad; BUT-1747 bär nu två luckor med samma
lösning; och den är en **förlanseringsgrind** — Art. 12(3)-fristen gäller från den dag riktiga rader
finns.

### ADR-0021

Eskaleringen får en ADR: panelen mätte tre fakta som inte låg i underlaget, och Malin vände sitt eget
beslut från behåll till stryp. Nästa lediga nummer är 0021. En rad i `docs/org/adr/README.md`.

### Linear

- **BUT-2006**: fråga 2 besvarad — strypningen står, nu som beslut. Fråga 1 stängs INTE med den.
- **BUT-2094**: bordlagd, med den korrigerade premissen i klartext och länk till BUT-1747.
- **BUT-1747**: bär nu två luckor med samma Admin-SDK-lösning; markeras som förlanseringsgrind.
- Rad 1 och 3 får inget nytt ticket — beslutet hör hemma i posten, och ett ticket som föds stängt är
  brus. Nämns i commit-meddelandet.
- Review-händelsen appendas till `docs/org/metrics/events.jsonl` (inget loggarskript finns):
  `tier: full-panel`, `panel: 6`, `outcome: escalated`, `conflicts: 1`, `escalations: 1`,
  `adrs: ["ADR-0021"]`, `rubber_stamp: false`, `via: "exit-plan"`.

---

# C — Mekaniskt, inga beslut

Två strukna kommentarssatser som blivit falska, och de två radantalen.

- `content_export_manager.dart:506-507`: satsen `Chosen conservatively without asking Malin, the way
  the` chat_groups `projection was; keeping it is hers to decide.` **stryks.** Resten av blocket står
  kvar — argumentet för strypningen är nu det beslutade skälet. Ingen ny prosa i samma redigering;
  läs den överlevande texten ensam efteråt.
- `preferences_export_manager.dart:298`: enradsstrykning per ②. **Mätt:**
  `_redactOtherParticipants` i `social_export_manager.dart` bär INGEN sådan sats — en grep över hela
  `lib/` ger exakt dessa två träffar.
- `ACCEPTED_LARGE_FILES.md`: båda raderna räknas fram med `wc -l` i samma anrop som stagar.
  `social_export_manager.dart`-raden säger 743 och filen mäter **722** — redan stale.

## Verifiering

1. `dart format` rapporterar 0 ändrade filer FÖRE grindarna dispatchas.
2. `flutter analyze --fatal-infos` rent.
3. `flutter test test/unit/services/account/export/social_export_manager_test.dart` — den nya
   meningen pinnas här (gruppen `exportSharedContent — shared shopping lists (BUT-1798)`, rad 2332),
   ankrad på en fras bara DEN meningen bär.
4. `flutter test test/unit/services/account/export/content_export_manager_test.dart` — grön UTAN
   ändring. Rad 2 blev stryp, så `'drops the erasure handle from the bundle'` och dess
   `data_minimisation`-assertion står kvar precis som de är. Rodnar något där är slutsatsen fel.
5. `flutter test test/unit/security/rules_allowlist_drift_test.dart` — grön utan ändring.
6. Mutationssond på den nya pinnade frasen, i EGEN körning (sonden skriver till `lib/`), följd av ett
   **läs-endast** pass över de slutliga bytesen innan commit.
7. `docs/onboarding/workflow-map.stale`: saknas nu, men båda exportfilerna matchar noden
   `svc-export-managers`. Kontrolleras efter redigeringen; finns den, körs CLAUDE.md:s protokoll i
   samma commit.
8. `/verify`.
9. Grindar: `code-reviewer` och `firebase-backend-security` (lib/ + GDPR-yta), samt
   `integration-reviewer` på hela diffen — det enda passet som ser en beslutspost och koden som gör
   den falsk i samma commit. Komplett fillista ur `git diff --cached --name-only`; varje grind
   instrueras att öppna varje fil med `Read`. Staged mot granskade bytes avgörs med
   `git rev-parse :<path>` mot `git hash-object <path>`, aldrig `git status`.

## Vad som INTE ingår

- Ingen sektion för `shared_content/{id}/items`. Ingen ny regelyta, ingen callable.
- Ingen ändring i `firestore.rules`, inga cap- eller append-only-konjunkt.
- BUT-2006 fråga 1 — din, obesvarad.
- Om `email` ligger läsbar i `public_profiles`-raderna: omätt, nämns i posten som omätt, egen biljett.
- Att exportbunten är engelsk medan användarna är svenska: UX-sätets världsmodellflagga, egen biljett.

## Open questions

**Inga arkitekturändrande okända.** De fyra besluten ställdes via AskUserQuestion 2026-09-17 och är
infoldade, inklusive rad 2 som ställdes en andra gång när panelen mätte att underlaget var
ofullständigt, och rad 4 som ställdes om när mätningen visade att klienten inte får läsa vägen alls.
Det som återstår i tier A (① ordalydelse, ② commit-granularitet) är formuleringsval med
förskrivna svarsstartare, inte okända — de ändrar ingen struktur och inget beteende.

**Antaganden som bygget vilar på**, var och en mätt i dag och inte hämtad ur en post:
- `_redactGroupPlan` behåller sin strypning, så `content_export_manager_test.dart` är grön utan
  ändring. Rodnar den är antagandet fel.
- `rules_allowlist_drift_test.dart` binder reglerna ⊆ exporten ∪ `{userId}`, och
  `reviewedBy`/`reviewNotes` står inte i regel-tillåtlistan — därför kräver rad 3 ingen kodändring.
- Den nya meningen kan pinnas i `social_export_manager_test.dart` gruppen på rad 2332; det är den
  enda sviten som anropar `exportSharedContent`.
- Exakt två kommentarssatser i `lib/` bär det nu falska "hers to decide"-påståendet.

**Namngivna, utanför den här ändringen, rangordnade efter blast radius:**
1. **BUT-2006 fråga 1** — ska `contributorUserIds` unionera passiva deltagare alls? Din, obesvarad.
   Störst räckvidd: den avgör om fältet skapar den enda noteringen om att någon som aldrig gjorde
   något fanns på en vecka. Rad 2:s stryp svarar inte på den.
2. **BUT-1747** — serverbygget som stänger både lämnade listor och delade listors varurader.
   Förlanseringsgrind enligt Legal.
3. **Ligger `email` läsbar i `public_profiles`-raderna?** Skrivregeln kräver fältet och läsregeln är
   `isAuthenticated()`. Omätt; jag påstår varken att den är exponerad eller inte. Egen biljett.
4. **Engelsk exportbunt för svenska användare** (Art. 12(1) "klart och tydligt språk") — UX-sätets
   världsmodellflagga, egen biljett.

## Panel och vad du inte fick se

Router på den faktiska filunionen: `tier: full-panel`, nio säten. Seatade fem med genuin insats plus
arkeologen: DPO, Legal Counsel, Security Architect, UX Writer, Technical Writer, Codebase
Archaeologist. Bortvalda: FinOps (noll nya Firestore-läsningar), Product Manager (produktbeslutet är
ditt och togs i dag), Software Architect (ingen lagerändring), Harness Owner (inget agentbeteende
ändras). Sex av sex `approve-with-conditions`, noll block. Arkeologen: ingen återkallad historik —
strypningen infördes en gång (`6039d86e1`, BUT-1971) och har aldrig rörts.

**Vad du inte fick se**, skrivet därför att en attribution är ett påstående om en person inget prov
kan hålla: ingen mätning av hur många uid en verklig veckas `contributorUserIds` innehåller, eller
hur många rader som bär `reviewedBy` — det finns inga användare. Och `shared_content` hade noll
dokument i butlery-app-1 när det mättes 2026-09-12, så rad 4:s sektion skulle inte exportera något i
dag oavsett väg.

---

## What this means in plain language

- **Ingenting ändras i vad du eller någon annan får ut ur sin dataexport.** Alla fyra sakerna du
  svarade om hålls tillbaka precis som i dag. Skillnaden är att det nu är bestämt, inte ärvt.
- **En sak blir ärligare.** Bunten får en mening som säger att varorna du lagt in i en lista en vän
  skickat dig en kopia av inte följer med. De städas när du raderar kontot, men de exporteras inte —
  och i dag står det ingenstans.
- **Du ändrade dig om en av dem, och det var rätt.** Du sa först ja till att ta med listan över alla
  som varit på en gruppvecka. Granskningen mätte tre saker som inte låg i mitt underlag: vem som
  helst som kan redigera veckan kan smyga in någon annans id i listan, vilket inloggat konto som helst
  kan slå upp ett id och få namnet, och ett barns id kan ligga där. Du vände till nej.
- **Två kommentarer i koden var osanna och stryks.** Den ena har varit fel i en vecka — den sa att en
  fråga väntade på dig, fast du redan svarat.
- **Risken är låg och lätt att ångra.** Inget beteende ändras utom en mening i en textfil som ingen
  funktion läser. Allt annat är anteckningar och biljetter. Går att backa med en commit.
- **En sak väntar fortfarande på dig**, men inte i dag: ska den interna listan över alla som varit på
  en gruppvecka ens innehålla folk som aldrig gjorde något? Den frågan står kvar öppen.

---

## Tillägg 2026-09-18 — rad 4:s mening shippar INTE (Malins beslut)

`code-reviewer` underkände meningen i `exportSharedContent`s `data_minimisation`: "item rows stored
with the share itself" beskriver också listkopians `listData.items`, som REDAN exporteras
(`shopping_social_share_module.dart` skriver hela listdokumentet på delningen, och
`social_export_manager_test.dart` visar att raderna når bunten). Det som saknas är en separat
undersamling som ingen kod skriver och som har noll rader. Meningen skulle ha sagt till den
registrerade att något saknas i en bunt som innehåller det.

Malin fick två vägar — ingen mening, eller en ny exakt mening som måste granskas om — och valde
**ingen mening**. Strängen återställs till sina bytes före ändringen och testet tas bort. Luckan står
kvar i avvikelseposterna och i BUT-1747, inte i bunten. Det avviker från planens klarspråkspunkt
"En sak blir ärligare"; den punkten är inte längre sann.

Kvar i `lib/` efter detta: de två strukna kommentarssatserna i `content_export_manager.dart` och
`preferences_export_manager.dart`. Inget exportbeteende ändras.
