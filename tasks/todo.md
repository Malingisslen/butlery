# Plan — anmälarens kontoradering tömmer inte längre ett öppet modereringsärende

Bakgrund och alternativanalys: `tasks/reporter-erasure-hold-plan.md`.

## Beslut (Malins, 2026-09-18)

1. **Behåll ANMÄLAN, ta bort ANMÄLARENS identitet** vid anmälarens radering om ärendet är öppet
   ("bygg som du rekommenderar").
2. **Fritexten (`description`) SPARAS** — Trust & Safety: den är ofta det enda utöver kategorin
   som gör ärendet avgörbart. (Panelen, AskUserQuestion.)
3. **Ja: den anmälde kan inte längre få veta vem som anmälde** om anmälaren raderat kontot.
   Juristens separata fråga, ställd i de orden.
4. **Räkna med att det som finns kvar kan peka ut anmälaren** (liten vängrupp + tidpunkt +
   fritext). Följd: det är en kvarhållen personuppgift → art. 12.4-besked till anmälaren.
5. **Radera vid stängning, senast 180 dagar** efter anmälarens radering. Ställd på nytt eftersom
   svar 2+4 föll premissen för den tidigare rekommendationen "behåll anonymt efter stängning".
6. ADR-0016 superseras för ÖPPNA ärenden; stängda raderas som förut.

Hon fick INTE se: någon mätning av hur ofta en anmälare raderar kontot med öppna ärenden (inga
användare); och rättslig grund för anmälarsidan är satt till GDPR art. 17(3)(b) (DSA art. 16(6),
plikten att handlägga anmälningar) utan att det ställts till henne — namngivet residual.

## Mätt 2026-09-18

- `reason` är en enum i `firestore.rules` — inte fritext.
- `description` är valfri fritext skriven av anmälaren.
- Moderatorns statusändring är `.update({'status': …})`; `cannotModify(['reporterId'])` och
  läsregeln `reporterId == auth.uid || isAdmin()` är null-säkra (Säkerhetsarkitekten bekräftade).
- `ContentReport.fromFirestore` läser `reporterId` med `safeString` → `""`; UI ska testa
  `isEmpty`, aldrig `== null`.
- Testfejkarna saknar toppnivå-`getAll` → uppslag görs med `doc(id).get()` i bitar.
- Orkestreringstestets fixtur är nycklad på "två kedjade `where` på `reports`" → `deleteUserReports`
  behåller EN `where` och delar på status i koden.
- `docs/ops/moderation-runbook.md` rad ~129–142 beskriver ADR-0016-beteendet.

## Byggsteg

Server (`functions/src`):
1. `moderation/report-status.ts` (ny): `OPEN_REPORT_STATUSES`, `isClosedReportStatus` (bara exakt
   `closed` är stängt — okänt/saknat räknas som öppet), `REPORTER_RETENTION_DAYS = 180`,
   `REPORTER_RETENTION_BASIS`. `erasure-hold.ts` importerar statuslistan därifrån.
2. `deleteUserReports` → returnerar `{ ok, keptOpen, retainUntil }`. Stängd → radera (+ audit
   `cascade_delete`). Annars → `reporterId: null`, `reporterErasedAt`, `reporterRetainUntil`
   (+ audit `cascade_anonymize`). `description` behålls. `strict: true`.
3. Orkestreraren: `keptOpen > 0` → `RetainedRecord { resourceType: "reports", … }` i `retained`.
   `held` förblir nycklat på `user_moderation`.
4. `deleteModerationSystemEvents`, reporter-benet: slå upp `reports/{details.reportId}`. Öppen →
   nolla `details.reporterId` (+ audit). Stängd/saknad → radera. Läsfel → nolla och rapportera
   steget ofullständigt. `deletedIds` innehåller bara raderade.
5. `deleteReportHistoryByReporter`: samma delning via `reports/{doc.id}`.
6. `probeResidualData`: ny sond `["reports", "reporterId", "=="]`, ovillkorlig.
7. `moderation/reporter-retention.ts` (ny) + dagliga kedjan direkt efter `sweepErasureHolds`:
   läser anmälningar med `reporterRetainUntil`, och för dem som stängts eller passerat taket:
   raderar `system_events/content_report_<id>`, `report_history`-raden (utom om den anmälde står
   under håll — då äger hållet raden), och sist anmälan. Radtak + tidsbudget + isolering per rad.

Klient (`lib/`):
8. `RetainedRecord`: skilj anmälarsidan (`reports`) från den anmäldes sida.
9. Beskedet: tre nya texter (egen anmälan; båda; båda men osäkert). `retained.first` ersätts av en
   sammanställning över alla poster; enhetslagringen sparar också om egen anmälan sparats.
10. Moderatorvyn: tom `reporterId` → "Anmälarens konto är raderat".

Dokument: dated post i båda beslutsloggarna, supersedering-rad i ADR-0016, runbooken, och
`erasure-hold.ts` huvudkommentar (strykning).

## Verifiering

- Functions: öppen/stängd/saknad/okänd status × tre ben; läsfel; audit; probe; samtidig
  anonymisering från båda håll lämnar båda fälten nollade; svepet (stängd, tak, öppen kvar,
  håll-skydd, radtak, budget).
- Dart: modell, beskedets textval, lagringen, moderatorvyn.
- `npm test` (berörda), `flutter analyze`, `flutter test` på ändrade filer; commit-grindar.

## Sammanfattning för Malin

När någon som anmält något raderar sitt konto finns anmälan kvar tills du stängt ärendet, men
utan namnet på den som anmälde. Det de skrev finns kvar så att du kan avgöra ärendet. De får ett
kort besked när raderingen är klar om att anmälan finns kvar, varför och till när. När du stänger
ärendet, eller senast efter 180 dagar, raderas anmälan helt. I moderatorvyn står "Anmälarens konto
är raderat" där namnet brukade stå.
