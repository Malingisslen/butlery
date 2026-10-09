# BUT-1842 — en anmälan sparar en textkopia av det anmälda innehållet

Beslut (Malin, 2026-10-09, beslutskort "Spara kopia"): servern sparar kopian, bara text
(inga bilder), raderas när ärendet stängs eller senast efter 180 dagar. Källplan:
`/mnt/project-files/lansering/but-1842-plan.md`.

## Mätt läge (main f30199a, 2026-10-09)

- Rapporten bär `reporterId, contentType, contentId, contentOwnerId, reason, description,
  status, createdAt, guidelineVersion`. Ingen sökväg utöver det.
- Var innehållet ligger (`ReportService._resolveContentRef`):
  recipe `users/{owner}/recipes/{id}` (title, description, ingredients[], instructions[]);
  comment `recipe_comments/{id}` (text, authorId); message `messages/{id}` (content,
  senderId); cook_snap `cook_snaps/{id}` (caption, userId); group
  `users/{owner}/friend_categories/{id}` (name, description); profile `public_profiles/{uid}`
  (displayName, bio).
- `contentType` valideras inte på servern; `contentOwnerId` är klientskrivet.
- Ingen trigger körs när ett ärende stängs; `isClosedReportStatus` = `status == 'closed'`.
  Rapporter raderas av admin (rules `allow delete: if isAdmin()`), av
  `finishRetainedReport` och av kaskaden (`deleteUserReports`, stängda ärenden).
- Den anmäldas radering: `anonymizeReportsUnlessHeldWithDb` hoppar över om
  `erasure_holds/{uid}` finns, annars `anonymizeReportsByContentOwnerWithDb`, som också
  anropas direkt när en hold lyfts.
- Art. 15 exporterar bara `totalReports` och `lastReportedAt`; `report_history` (som bär
  contentId per anmälan) exporteras inte (BUT-2046).
- Integritetspolicyn (assets/legal/privacy_policy_sv.md §8) nämner varken anmälningar eller
  den befintliga hållningen för öppna ärenden.

## Bygge

1. **Samling** `report_evidence/{reportId}`, bara servern skriver. Fält: `reportId`,
   `contentType`, `contentId`, `contentOwnerId`, `capturedAt`, `expireAt` (+180 d),
   `outcome` (`captured | missing | owner_mismatch | unsupported_type`), `text` (karta
   fältnamn → sträng eller lista av strängar). Inget `reporterId`.
   Rules: `allow read: if isAdmin(); allow write: if false;`.
2. **Fångst** i ny modul `functions/src/moderation/report-evidence.ts`, anropas från
   `onReportCreated` efter `processReport`, i egen try/catch så att ett fel i fångsten inte
   kostar moderationslarmet eller strejkräknaren (felet loggas och kastas om, så triggern
   körs om; fångsten är idempotent). Idempotens: `create()` på reportId; ALREADY_EXISTS =
   redan fångat, den första kopian vinner (en omkörning efter att författaren redigerat ska
   inte skriva över).
   - Ägarkontroll: för comment/message/cook_snap jämförs dokumentets författarfält med
     `contentOwnerId`; vid avvikelse sparas ingen text (`owner_mismatch`) — annars kan en
     anmälare få servern att kopiera en tredje persons text under fel ägare. Recept och
     grupp ligger under ägarens sökväg, profil har id = ägare.
   - Okänd typ → `unsupported_type`, ingen läsning.
3. **Radering**
   - Ny trigger `onReportEvidenceLifecycle` = `onDocumentWritten("reports/{id}")`: om
     rapporten raderats eller status blivit `closed` raderas `report_evidence/{id}`. Täcker
     alla raderingsvägar (admin, retention-svepet, kaskaden) utan att röra dem.
   - TTL-policy på `report_evidence.expireAt` i firestore.indexes.json (golv på 180 dagar);
     `firestore-ttl-policies.test.ts` uppdateras.
   - Den anmäldas kontoradering: `anonymizeReportsByContentOwnerWithDb` raderar även
     `report_evidence` där `contentOwnerId == uid` (båda dess anropare täcks: ingen hold,
     och hold som lyfts). Under hold ligger kopian kvar — det är hela poängen.
   - Anmälarens kontoradering rör inte kopian (den bär inget om anmälaren).
4. **Inventering**: `report_evidence` läggs till i `Collections` (functions/src/shared/
   collections.ts), `FirestoreCollections` (Dart) och reset-collection-lists.ts.
5. **Art. 15**: kopian exporteras INTE. Följer av BUT-2046: vilket innehåll som anmäldes
   (contentId per anmälan, `report_history`) undanhålls redan för att skydda anmälaren, och
   en kopia är just det beskedet plus texten. Texten i sig är den anmäldas egen och finns i
   deras export så länge originalet finns.
6. **Moderatorvyn** (intern adminvy): `ReportEvidence`-modell, `ReportService.getReportEvidence`,
   VM slår upp kopian per ärende som `isMinorOwner` gör, kortet visar texten under
   anmälan och en rad när kopian saknas. Nya l10n-nycklar sv/en. Minsta ändring; inga andra
   vyer.
7. **Tester**: CF-test per typ, saknat dokument, ägaravvikelse, okänd typ, omkörning efter
   redigering (första kopian vinner); livscykeltest (stängt → raderad, raderad rapport →
   raderad, öppet → kvar); anonymiseringstest (kopian raderas); regeltest (admin läser,
   anmälare/ägare/annan nekas, ingen klient skriver); Dart-modelltest och VM-test.
8. **Dokumentation**: daterad post i docs/architecture/ACCEPTED_DEVIATIONS.md +
   .claude/rules/accepted-deviations.md. Integritetspolicyn: se öppen fråga.

Driftsättning: funktioner först (`functions_only`), sedan rules och indexes.

## Intressentgranskning (2026-10-09) — villkor som byggs

Router: full-panel. Satt: Integritet/DPO, Säkerhet, Moderering, Databas + arkeolog. Avstängda
(bara följdträff): Kundsupport, Data/ML, FinOps, Leverantör, Produkt, Arkitekt, Juridik
(juridikfrågan bärs av DPO och går till Malin). Alla fyra: godkänn med villkor.

Ändringar mot bygget ovan:
- **Läsbarhet**: texten sparas bara om anmälaren själv kunde läsa innehållet, speglat från
  rules: recept — anmälaren i `socialData.memberPermissions`; kommentar — anmälaren är
  `recipeOwnerId` eller i `sharedWithUserIds`; meddelande — anmälaren i konversationens
  `participantIds`; matbild — `users/{ägare}/friends/{anmälare}` finns och
  `visibility == 'sameAsRecipe'`; grupp — anmälaren i `friendUserIds`; profil — alla
  inloggade, men `contentId == contentOwnerId` krävs. Annars `not_visible_to_reporter`.
- **Id-validering** med `isValidDocId` på contentId och contentOwnerId före varje läsning →
  `invalid_ref`.
- **Storlek**: total budget 64 KB text, `truncated: true` vid kapning.
- **Ingen omkörning**: `onReportCreated` har ingen `retry`, så fångsten kastar aldrig;
  ett oväntat fel sparar `capture_failed` (best effort) och loggar bara felkod.
- **Ordning**: fångsten är en transaktion som läser om rapporten och hoppar över om den är
  borta, stängd eller har tappat sin ägare.
- **Radering i en mekanism**: livscykeltriggern raderar kopian när rapporten raderas, stängs
  ELLER `contentOwnerId` blir null/ändras. Då följer kopian rapportens egen anonymisering,
  och `liftErasureHold`s befintliga om-prov på `reports` täcker den — anonymize-reports.ts
  och erasure-hold.ts lämnas orörda. Tidig retur annars; delete utan föregående läsning.
- **TTL**: `expireAt` = fångst + 180 d, förlängs INTE under hold (Malins tak räknas från
  fångsten). TTL är ett tak med upp till ~1 dygns eftersläp, inte ett golv. Båda listorna i
  `firestore-ttl-policies.test.ts`. Indexdeploy utan `--force`; kontroll med
  `gcloud firestore fields ttls list`.
- **Inventering**: `COLLECTIONS_TO_DELETE` i reset-collection-lists.ts, Dart-konstant,
  TS-konstant där rapportsamlingarna faktiskt heter något (report-status.ts).
- **Loggning**: aldrig text, bara utfall, typ och uid-prefix.
- **Moderatorvyn**: fångsttid, "bara text, bilder sparas inte", olika rader för saknat /
  ej läsbart / fel ägare / okänd typ / ingen kopia (anmälan före funktionen). Ren `Text`.
- **Tester** registreras i package.json, och emulatorsviter i `test:rules:all` + båda
  `paths:` i firestore-rules.yml. Regeltestet läggs i reports-rules.test.ts.
- **Art. 15**: grunden är Art. 15(4) (anmält innehåll + anmälan pekar ut anmälaren, säkert
  för meddelanden och kommentarer), inte "följer av BUT-2046". Svagare del: redigerad eller
  raderad egen text undanhålls. → Malins beslut (kort). Fast mening i exportens
  `data_minimisation` för moderationsräknarna.

Uppföljningar (egna ärenden, inte i detta bygge): bevarandeflagga för allvarliga ärenden
(t.ex. CSAM) som skulle gå över 180-dagarstaket — ändrar Malins beslut; beslutspost som
överlever kopian (vilken åtgärd togs); serverstyrd anmälningsspärr.

## Öppna frågor

- Integritetspolicyn (kort till Malin): rad i §8 om anmälda ärenden och rätta "Vi raderar
  ALLA dina uppgifter permanent" / "omedelbar och oåterkallelig", som är fel sedan holden.
  Grund: Art. 6.1.f. Bygget fortsätter; funktionen driftsätts först när texten är godkänd.
- Art. 15-undantaget (kort till Malin), rekommendation: exportera inte.
- Inga andra arkitekturändrande okända. Antaganden: låg anmälningsvolym (kostnad: en extra
  trigger per rapportskrivning och 1–2 läsningar per anmälan).

## Sammanfattning för Malin

När någon anmäler något sparar servern en kopia av texten (inte bilder), så att du ser vad
som anmäldes även om författaren hunnit ändra eller radera. Bara du som admin kan läsa den.
Kopian raderas när du stänger ärendet, när den anmälda raderar sitt konto utan öppet ärende,
och alltid senast efter 180 dagar. Den anmälda får inte se kopian i sin dataexport, eftersom
det skulle avslöja vem som anmälde. Du ser kopian under ärendet i modereringsvyn.
