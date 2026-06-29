# Integritetspolicy

**Status:** Utkast. Ska granskas av juridiskt ombud och publiceras på en stabil URL (planerad: `butlery.se/integritet` när BUT-680 levereras).
**Senast uppdaterad:** 2026-05-21
**Träder i kraft:** TBD vid publicering.

## 1. Vilka vi är

Butlery är en receptapp som drivs av Malin Gisslén ("vi", "oss"). Denna policy förklarar hur vi samlar in, använder, lagrar och delar dina personuppgifter, samt vilka rättigheter du har enligt EU:s allmänna dataskyddsförordning (GDPR).

Vid frågor, kontakta: malin.kallen1@gmail.com.

## 2. Vilka uppgifter vi samlar in

| Kategori | Exempel | Källa |
|----------|---------|-------|
| Kontouppgifter | E-post, visningsnamn, lösenordshash, MFA | Du |
| Profil | Avatarbild, bio, språkpreferens | Du |
| Allergier & kostpreferenser | Laktosintolerans, vegetarisk osv. | Du |
| Recept | Recept du skapar, importerar eller fotograferar | Du |
| Sociala kopplingar | Vänner, gruppmedlemskap, delat innehåll, meddelanden | Du |
| Användningsanalys | Funktionshändelser, sessionsmetadata, anonym enhetsidentifierare | Appen |
| Kraschdiagnostik | Stack-spår, enhetsmodell, OS-version | Appen |
| Lagningsaktivitet | Lagade recept, tidsstämplar (visar "senast lagat" i UI) | Appen |

Vi samlar INTE in: exakt geolokalisering, betalningsuppgifter (ingen monetisering ännu), mikrofon, kontakter eller fotobibliotek utöver det du explicit importerar.

## 3. Allergier och kostpreferenser

Allergi- och kostpreferensdata kan klassas som hälsorelaterad data enligt Apples iOS Privacy Manifest-ramverk (deklarerat som `NSPrivacyCollectedDataTypeHealthAndFitness`). Vi använder dessa uppgifter enbart för att (a) filtrera recept du bör undvika och (b) anpassa menyförslag. Vi delar inte allergidata med tredje part utöver underleverantörerna i avsnitt 7.

## 4. Rättslig grund (GDPR Artikel 6)

| Behandling | Rättslig grund |
|-----------|----------------|
| Kontoskapande + autentisering | Avtal (Art. 6.1(b)) |
| Recept- och social datalagring | Avtal |
| Kraschrapportering | Berättigat intresse (Art. 6.1(f)) — tjänstestabilitet |
| Analys (anonymiserad) | Berättigat intresse |
| Allergifiltrering | Samtycke (Art. 9.2(a)) givet vid första onboarding |

## 5. AI-bearbetning på enheten

Vi använder ONNX-maskininlärningsmodeller direkt på din enhet för:

- **Ingrediensigenkänning (NER):** identifiera ingrediensnamn i fritextrecept.
- **Receptradsklassificering:** skilja ingrediensrader från instruktionsrader vid import.

Dessa modeller körs lokalt på din enhet. Texten och bilderna som bearbetas av dessa modeller **skickas inte till våra servrar** som del av modellberäkning. Modellerna själva laddas ner från vårt CDN (Firebase Storage) en gång per version och verifieras med SHA-256-hash innan användning.

Molnbaserad AI-bearbetning (Mistral via Vertex AI) används för receptanalys från URL, OCR-förbättring och menygenerering. När du aktiverar dessa funktioner skickas indata till Google Clouds Vertex AI i regionen `europe-west1`. Vi behåller inte modellinmatningarna efter anropet.

## 6. Lagring

- **Aktiv kontoinformation:** lagras så länge ditt konto finns.
- **Raderad kontoinformation:** bearbetas inom **30 dagar** efter din raderingsbegäran, med undantag av:
  - **Granskningsloggar:** lagras i **365 dagar** enligt GDPR Artikel 17.3(b)-undantaget (rättslig efterlevnad av våra kaskad-raderingsloggningskrav).
  - **Säkerhetskopior:** som innehåller raderad data upphör inom **30 dagar** efter raderingsbegäran.
- **Kraschrapporter:** 90 dagar.
- **Analyshändelser:** 14 månader (Firebase Analytics-standard).

## 7. Underleverantörer

Vi delar nödvändiga uppgifter med följande underleverantörer. Samtliga är GDPR-kompatibla och bundna av databehandlingsavtal.

| Underleverantör | Syfte | Datakategori | Region |
|----------------|-------|--------------|--------|
| Google Cloud — Firestore | Primärdatabas | All användardata | europe-west1 |
| Google Cloud — Authentication | Autentisering + MFA | E-post, lösenordshash, MFA-token | Global (EU-routad) |
| Google Cloud — Storage | Receptbilder, exporter | Användaruppladdade bilder | europe-west1 |
| Google Cloud — Cloud Functions | Serverlogik | Kontoborttagning, innehållsmoderering | europe-west1 |
| Google Cloud — Vertex AI (Mistral) | Receptanalys, OCR, menygenerering | Inmatning till AI-funktioner | europe-west1 |
| Google Cloud — Vision API | Bildmoderering (SafeSearch) | Uppladdade bilder | europe-west1 |
| Google Cloud — reCAPTCHA Enterprise | App Check (anti-bot) | Enhetsattestering | Global |
| Firebase Crashlytics | Kraschrapporter | Stack-spår, enhetsmetadata | Global |
| Firebase Analytics + GA4 | Anonym användarstatistik | Händelsenamn, sessions-ID | Global |

**Skjutet på framtiden (ej aktivt):**

| Underleverantör | Plan | Status |
|----------------|------|--------|
| Algolia | Receptsök | Inaktiverad bakom feature-flag; under utvärdering |
| RevenueCat | Prenumerationshantering | Inte än — monetisering ej implementerad |

Denna lista uppdateras när vi lägger till eller tar bort leverantörer.

## 8. Internationella överföringar

Primär data lagras inom EU (`europe-west1`, Belgien). Vissa Google-tjänster (Authentication, Crashlytics, Analytics) är globala av arkitekturskäl. När data lämnar EES använder Google EU-kommissionens standardavtalsklausuler (SCC) som överföringsmekanism.

## 9. Dina rättigheter (GDPR Artikel 15–22)

Du har rätt att:

- **Få tillgång till** dina uppgifter (Artikel 15) — dataexport i appen under Konto → Integritet & Data.
- **Rätta** felaktigheter (Artikel 16) — redigera vilket fält som helst i appen, eller kontakta oss.
- **Radera** dina uppgifter (Artikel 17) — kontoborttagning i appen under Kontosäkerhet.
- **Begränsa** behandling (Artikel 18) — kontakta oss.
- **Dataportabilitet** (Artikel 20) — JSON-export tillgänglig i appen.
- **Invända** mot behandling (Artikel 21) — kontakta oss.
- **Återkalla samtycke** (Artikel 7.3) — hantera allergiupplysningar i Profil-inställningar, eller radera ditt konto.
- **Lämna in klagomål** till Integritetsskyddsmyndigheten (IMY): https://www.imy.se

## 10. Barns integritet

Butlery-konton är till för användare som är 15 år eller äldre (se våra Användarvillkor). Vi tillåter inte medvetet att personer under 15 år skapar konton.

**Hanterade matgästprofiler (barn i ett hushåll).** En vuxen medlem i hushållet kan skapa en "matgästprofil" för ett barn som är för ungt för ett eget konto, så att hushållet kan planera måltider utifrån barnets behov. En matgästprofil innehåller barnets förnamn, en grov åldersgrupp, en avatarfärg och — endast med separat, uttryckligt samtycke — allergi- och kostuppgifter (hälsouppgifter, GDPR artikel 9). Profilerna skapas och hanteras av en vuxen som intygar att hen är vårdnadshavare; samtycket registreras, versionshanteras och tidsstämplas, och kan återkallas när som helst i skärmen "Min familj", vilket raderar tillhörande allergiuppgifter. En profil kan skapas helt utan allergiuppgifter.

Ett barns betyg på måltider (1–5 stjärnor) är privata för hushållet på individnivå — ingen utanför hushållet ser vem som satte vad — men bidrar anonymt och endast i aggregerad form till ett recepts allmänna snittbetyg. Allergi- och hälsouppgifter görs aldrig offentliga.

Ett barns uppgifter delas endast inom hushållet, ingår i hushållets dataexport och raderas (eller flyttas över till en kvarvarande medlem i hushållet) när ett konto raderas, enligt vår lagringspolicy. Om du tror att ett barns uppgifter har sparats utan vårdnadshavares samtycke, kontakta oss så tar vi bort dem.

## 11. Säkerhet

Vi använder Transport Layer Security (TLS 1.2+) för all nätverkstrafik, certifikatpinning på mobila klienter, App Check-attestering och Firestore-säkerhetsregler för per-användare-isolering. Lösenord lagras aldrig i klartext.

## 12. Ändringar i denna policy

Vi meddelar väsentliga ändringar via avisering i appen och uppdaterar datumet "Senast uppdaterad" ovan. Fortsatt användning efter ändringen utgör accept.

## 13. Kontakt

Personuppgiftsansvarig: Malin Gisslén
E-post: malin.kallen1@gmail.com
