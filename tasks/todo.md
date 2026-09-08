# Modereringen: exportera antalet, och håll kvar underlaget vid öppet ärende

Malins två beslut 2026-09-08, båda fattade efter att mina egna skäl visat sig inte hålla.
Uppföljning på BUT-2032/BUT-2046. **Del A är BYGGD 2026-09-08. Del B är planerad och
granskad, inte byggd** — panelen mätte den som större än planen beskrev, och en halvbyggd
raderingsväg är sämre än en namngiven lucka.

---

## 0. Varför det här alls är uppe igen

Jag lämnade två poster som "juridik utan svar". Malin frågade varför vi lämnar saker. Båda
gick att besvara på tio minuter:

- **DSA artikel 23** ("åtgärder mot missbruk", som T&S-sätet åberopade för brigading-signalen)
  **gäller inte mikro- och småföretag** — artikel 19 undantar artiklarna 20-23. Beslutet att
  inte bygga signalen var alltså aldrig i konflikt med en skyldighet. ADR-0015 citerar den som
  om den band oss.
- **DSA artikel 17** (motivering vid moderering) ligger i avsnitt 2 och **gäller även
  småföretag**. Tillsammans med GDPR artikel 17.3 b (rättslig skyldighet) ger den en rimlig
  grund att behålla modereringsunderlag trots en raderingsbegäran. Min mening "artikel 17 har
  inget undantag den här ändringen kunde luta sig mot" var alltså fel.
- **Att undanhålla personens eget anmälningsantal** är en artikel 23-begränsning (GDPR), och
  den kräver stöd i lag. Ingen sådan hittad. Artikel 15(4) räcker till anmälarnas identiteter
  och inte längre.

Sökningar, inte juridisk rådgivning — men de gör två öppna poster till två beslut.

---

## 1. Del A — antalet in i artikel 15-exporten

### 1.1 Vad som exporteras

`user_moderation/{uid}` innehåller efter BUT-2046 **bara** `totalReports` och
`lastReportedAt`. Anmälarna ligger i `report_history`-subsamlingen. Det är precis vad som gör
den här delen enkel: föräldern kan läsas av sitt eget subjekt utan att röja någon annan.

Sektionen exporterar de två fälten. Ingenting annat.

### 1.2 Rules — och varför sektionen är död utan dem

Exporten körs på **klient-SDK:n**, och `firestore.rules` har i dag **ingen** post för
`user_moderation` — alltså nekas varje läsning. En exportsektion utan regelblock returnerar
sitt felkuvert för varje användare vid varje export, medan dokumentationen påstår att raden
exporteras. Det är BUT-1957 ordagrant.

Nytt block:

```
match /user_moderation/{userId} {
  allow read: if isOwner(userId)
              && (resource == null
                  || resource.data.keys()
                      .hasOnly(['totalReports', 'lastReportedAt']));
}
```

Ingen skrivning (servern äger dem), och **ingen regel för `report_history`** — en subsamling
ärver ingenting, default är neka, och det är det som håller anmälarna borta.

Konjunkten kom till under granskningen: utan den lämnar en ägarläsning ut anmälarnas uid ur
ett dokument migreringen inte flyttat, och `resource == null`-armen behövs för att dokumentet
bara finns om någon anmält dig.

### 1.3 Regelprov

En `firestore.rules`-ändring triggar `firestore-rules-tester`. Prov som krävs:

1. Ägaren läser sitt eget `user_moderation`-dokument → ALLOW.
2. Någon annan läser det → DENY.
3. Ägaren läser sin egen `report_history`-subsamling → **DENY**. Det är hela poängen.
4. Utloggad → DENY.

Prov 3 är det som dör ensamt om någon senare "förenklar" med en wildcard-regel.

---

## 2. Del B — legal hold vid öppet modereringsärende

### 2.1 Vad "öppet ärende" betyder

Hållet gäller när den raderade är `contentOwnerId` på minst en rad i icke-terminal status.
Predikatet är `status != 'closed'` — mätt av panelen, se villkor F i avsnitt 6.

### 2.2 Konflikten med BUT-781, som måste lösas först

`anonymizeReportsByContentOwner` nollar `contentOwnerId` när den anmälda raderar sig. Det är
ett **avgjort beslut**. Ett håll som bevarar underlaget men låter den kopplingen kapas bevarar
bevis ingen kan koppla till ett ärende — hållet blir teater.

Två vägar, och valet är Malins (se avsnitt 4):

- **(a) Undanta hållna ärenden från anonymiseringen.** `contentOwnerId` står kvar tills ärendet
  stängs. Snävast möjliga avsteg från BUT-781 — men det ÄR ett avsteg och skrivs som ett.
- **(b) Ersätt uid:t med en ärendelokal pseudonym** moderatorn kan följa men som inte är ett
  konto-id. Bevarar kopplingen utan att bevara uid:t; mer kod, och pseudonymen blir en ny
  identifierare med egen livslängd att besluta om.

### 2.3 Vad hållet gör

`deleteModerationRecord` och `anonymizeReportsByContentOwner` frågar först: finns ett öppet
ärende? I så fall bevaras det ärendet behöver, och **ingenting annat** — resten av kaskaden
körs oförändrad.

### 2.4 Beskedet till personen — inte valfritt

En radering som inte fullföljs helt måste kunna förklaras. Kaskadens `failedCollections` duger
inte: det här är inget fel. Behövs:

- ett eget fält i raderingskvittot som säger att något behållits, på vilken grund, och hur
  länge (till dess ärendet stängs),
- och en formulering i appen. Svensk UI-text, kort, utan juridikjargong.

Det är den här biten som gör Del B till mer än ett predikat.

### 2.5 Vad som händer när ärendet stängs

Underlaget måste raderas då — annars är hållet en permanent retention med en tillfällig
motivering, vilket är precis vad artikel 17.3 inte tillåter. Alternativ:

- en städning i moderatorns "stäng ärende"-väg (deterministisk, exakt utlösande händelse),
- eller en svepning (ny återkommande jobb-yta).

Rekommendation: den första. Fyrafältstestet för ny automation talar emot ett schemalagt jobb
för något som har en exakt händelse att hänga på.

---

## 3. Följdändringar i text

- **ADR-0015 superseders** med en daterad post: DSA artikel 23 gäller inte mikro-/småföretag,
  så T&S-argumentets rättsliga halva föll. Beslutet (bygg inte signalen) står — det vilar nu
  på produktavvägningen ensam, vilket är en ärligare grund än en felciterad artikel.
- **ADR-0017 superseders**: antalet exporteras, och skälet som höll inne det saknade stöd.
- **`ACCEPTED_DEVIATIONS.md`**: posten som säger att ingen legal hold finns skrivs om med den
  rättsliga grunden — min mening "artikel 17 har inget undantag" citeras och pensioneras.

---

## 4. Frågan i 2.2 är besvarad av panelen

Väg **(a)**: behåll uid:t. Se villkor G i avsnitt 6 — en pseudonym kapar precis det en
moderator kan göra med ett hållet ärende och köper ingen minimering, eftersom kontot är borta
ändå. DPO lutade åt pseudonymen men flaggade själv att slutsatsen vilar på ett antagande om
`audit_logs` som ingen mätt.

---

## 5. Vad det betyder, i klartext

**Del A:** den som begär ut sina uppgifter får veta hur många gånger hen anmälts. Aldrig av
vem — det skyddas fortfarande, och den delen har det starkaste stödet.

**Del B:** om någon anmälts och ärendet fortfarande granskas, försvinner inte underlaget bara
för att personen raderar sitt konto. Det är vad DSA räknar med att en plattform kan göra. Men
personen ska få veta att något behållits, och det måste raderas när ärendet stängs — annars
har vi bara hittat ett sätt att spara data längre.


---

## 6. Panelens utfall för Del B (fyra säten, alla approve-with-conditions)

**Säten:** Legal Counsel, DPO, Trust & Safety, Codebase Archaeologist. Avförda: Product
Manager och Software Architect (inget produktval, ingen lagerändring), FinOps, Performance,
Data Analyst, DBA, Security, Support, Vendor — ingen av dem har en stake den här ändringen rör.

### Villkor som måste rida med när Del B byggs

- **A. Ett håll får INTE uttryckas som `gdprCompliant: false`.** Det fältet betyder "något gick
  fel" genom hela kaskaden. En laglig, redovisad vägran är inte det, och att blanda dem gör en
  bugg omöjlig att skilja från efterlevnad. Eget fält på kvittot och i auditraden. *(DPO)*
- **B. `probeResidualData` skulle annars slå om `gdprCompliant` till false permanent** — sonden
  har två ben som räknar exakt det ett håll medvetet behåller, och flaggan beräknas en gång vid
  raderingen och skrivs till auditloggen. Ingen kodväg kan rätta den i efterhand. *(arkeologen,
  mätt i koden)*
- **C. En yttre tidsgräns oberoende av att ärendet stängs.** Malin är ensam moderator; ett
  ärende ingen triagerar stängs aldrig, och hållet blir då permanent retention med en
  tillfällig motivering. Återanvänd 180-dagarskonstanten. *(Legal, DPO, T&S — alla tre)*
- **D. Beskedet måste bära artikel 12.4:** rätten att klaga till IMY och till rättsligt
  prövning, utöver vad/varför/hur länge. *(Legal, DPO)*
- **E. Rättslig grund: 17.3(e) primärt** för fönstret innan beslut (rättsliga anspråk), 17.3(b)
  sekundärt när DSA-motiveringsplikten faktiskt är levande. Min plan vilade allt på (b), vilket
  är fel för det tidiga fönstret. *(Legal)*
- **F. Predikatet är `status != 'closed'`.** Enda terminala statusen — `watchOpenReports()`
  filtrerar på just det och "actioned" ligger kvar i kön. Behöver inte härledas i bygget: det
  står redan i `ReportStatus`, i `firestore.rules` och i `report_service.dart`. Ett håll blir
  en FJÄRDE plats där samma faktum måste hållas i takt. *(T&S, Legal, arkeologen)*
- **G. Behåll uid:t, inte en pseudonym.** Det moderatorn faktiskt kan göra med ett hållet ärende
  är att korsläsa strike-räknaren och andra öppna ärenden mot samma person; en pseudonym kapar
  precis det och köper ingenting, eftersom kontot är borta ändå. *(T&S)*
- **H. Hållet är ENKELRIKTAT som det är skissat.** `deleteUserReports`, anmälarbenet i
  `deleteModerationSystemEvents` (ADR-0016, beslutat samma dag) och
  `deleteReportHistoryByReporter` raderar alla samma bevis utan statuskoll — så en ANMÄLARES
  radering tömmer ett öppet ärende ändå. Antingen i scope eller uttryckligen utanför, men inte
  otänkt. *(arkeologen, T&S)*
- **I. Nytt sammansatt index** `(contentOwnerId, status)` på `reports` — det befintliga är
  `(status, createdAt)` och tjänar en annan fråga. Diffa mot levande index före deploy, aldrig
  blint `--force`. *(arkeologen)*
- **J. Städningen vid stängning kräver en NY server-trigger.** `closeReport()` är en ren
  klientskrivning; ingen Cloud Function ser den. Och predikatet måste räkna om över ALLA öppna
  ärenden mot samma person — att stänga ett ärende lyfter inte hållet om ett annat står öppet.
  *(arkeologen)*
- **K. Följdfiler planen missade:** `docs/ops/moderation-runbook.md` (som redan beskriver vad
  som överlever en radering, per radform) och `docs/legal/privacy_policy.md` § retention, som
  redan listar en 17.3(b)-grund i samma format. *(arkeologen)*
- **L. Hållet är ett uttryckligt undantag från husregeln** "raderaren är en äkta övermängd av
  sonden", som filen upprepar dussintals gånger. Det ska skrivas som ett undantag, inte smygas
  in i koden. *(arkeologen)*

### Vad Del A faktiskt blev

`user_moderation/{uid}` fick en läsregel för sitt eget subjekt, och exporten en sektion som
projicerar `totalReports` och `lastReportedAt` genom en allowlist. Subsamlingen `report_history`
är fortsatt nekad för alla, inklusive sitt eget subjekt — det är UM4 i regelprovet, och det är
det provet som dör ensamt om någon senare lägger en wildcard-regel.

Mätt mot emulatorn och i Dart-sviterna, med varje ben mutationsprovat — siffrorna står i
commit-meddelandet, som inte kan falsifieras av nästa ändring i den här filen.
