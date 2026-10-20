# Plan: ny, ren produktionsmiljö i EU som ersätter `butlery-app-1`

> Plan, godkänd av Malin 2026-10-20 (uppföljning av BUT-451, brief i `tasks/new-prod-project-brief.md`).
> Ingen appkod, inga regler, inga Firebase-/GCP-inställningar ändras och inget driftsätts av den.

## Context

Produktionens Storage-bucket ligger i **US-CENTRAL1** och kan inte flyttas. Resten av prod
(Firestore europe-west3, funktioner europe-west1) är redan i EU. Prod håller bara testdata
(4 konton, 119 MB), så ett nytt projekt byggt rätt från början kostar ingen datamigrering.
Staging (`butlery-app-staging`, BUT-451) byggdes 2026-10-20 och är receptet för bygget;
det här är samma recept körd en gång till, med EU-bucket, Malins grind på deployen, och
WIF i stället för nyckel.

### Mätt 2026-10-20 i den här sessionen (bara läsning; allt via gcloud/firebase/REST)

- **Prod `butlery-app-1`** (projektnummer …692): Firestore europe-west3, PITR på,
  delete-protection på, två backup-scheman (dagligt 7 d, veckovis 14 v); bucket
  `butlery-app-1.firebasestorage.app` i US-CENTRAL1 med versionering + lifecycle, 119 MB,
  två toppmappar `feedback/` och `models/`; **107** funktioner, 17 schemajobb, 28 TTL;
  **5** secrets i Secret Manager varav koden bara läser 3 (`GEMINI_API_KEY`,
  `MISTRAL_API_KEY` saknar läsare i `functions/src`); Realtime Database: **ingen instans**
  (trots `database.rules.json` i `firebase.json`); inga Extensions; Remote Config version 6
  (2026-08-27); 27 toppsamlingar i Firestore, varav seedade/konfig: `ingredients`,
  `tagConfigs`, `tag_configs`, `site_configs`, `admins`, `_internal`, `butlery_archive`,
  `system` (ej listad separat, `system/config` läses av 6 funktioner).
- **Auth i prod:** e-post/lösenord, Google, **Apple** (Services-id satt), TOTP-MFA på,
  e-postuppräkningsskydd på, inga blocking functions registrerade i Auth-konfigen,
  authorized domains = `localhost` + projektets två egna; **bara lösenordsmallen är
  anpassad** (replyTo `info@butlery.se`), standardspråk `en`, standardavsändare (ingen SMTP).
- **App Check:** Unenforced på Firestore, Storage och Auth i både prod och staging;
  callables med `enforceAppCheck: true` kräver token i koden; 24 `cors:`-listor tillåter
  bara `https://butlery.app` och `https://www.butlery.app`.
- **Hosting:** tre sajter (`butlery-app-1`, `butlery-admin`, `butlery-legal`) och **ingen
  custom domain på någon av dem**. `butlery.app` har DNS hos **OVH** (ns14/dns14.ovh.net)
  och pekar på 213.186.33.5 (OVH), inte på Firebase. Briefens "Hosting serverar
  butlery.app" stämmer alltså inte i dag — och därmed kan webbappen inte anropa
  callables från någon adress Firebase serverar (CORS).
- **Budgetar på billingkontot:** "Firebase Project butlery-app-1" 50 kr, "Butlery sms MFA
  200 kr" (SMS-MFA är ersatt av authenticator-app, BUT-2340), staging 50 kr.
- **Artifact Registry** `gcf-artifacts` (europe-west1): städpolicy `firebase-functions-cleanup`,
  raderar bilder äldre än 1 dygn.
- **Repo:** secret-scan-hooken (`tools/check_secret_scan.sh`) **undantar**
  `firebase_options.dart` och `firebase_options_staging.dart` per filnamn — briefens "Malin
  committar options-filen för hand" gäller inte längre för det filnamnet.
  Deploy-workflown har 90 min timeout och driftsätter funktioner en i taget (~90 s/st enligt
  huvudkommentaren) → 107 funktioner får inte plats i en körning; första deployen går i
  omgångar via `functions_only`, som i staging. Smoke-gaten blir röd tills omgången med de
  12 krävda funktionerna är inne.
- **Kopplingar till `butlery-app-1` utanför options-filen** (måste redigeras):
  `lib/core/bootstrap/firebase_env.dart`, `android/app/build.gradle.kts`,
  `ios/Runner/Runner.entitlements`, `ios/Runner/Info.plist` (Googles iOS-klient-id),
  `lib/main.dart` (reCAPTCHA-nyckel), `web/.well-known/security.txt`, `.firebaserc`,
  `firebase.json` (flutterfire-blocket inkl. det inaktuella app-id:t `4a2e41f5…`),
  `functions/src/admin/require-project.ts`, `functions/src/shared/ocr-url-validator.ts`
  (fallback till prod-id i **körande** kod), `tools/ci/check_model_versions.py`,
  `scripts/line_classifier/deploy_model.py`, `scripts/crf/retrain_with_corrections.sh`,
  `infrastructure/{alerting,security,storage}/*.sh` (defaults), vakttestet
  `deploy-project-guard.test.ts` (kräver exakt `production=butlery-app-1`), testfiler och
  docs. `google-services.json` (prod) + `GoogleService-Info.plist` är lokala och
  gitignorerade; CI avkodar prod-JSON ur repo-hemligheten `GOOGLE_SERVICES_JSON_BASE64`.
- **Tillgänglighetsstöd i sessionen:** gcloud och firebase CLI är inloggade som Malin;
  REST-läsningar fungerar. Firebase-konsolen kan köras i den inbyggda webbläsaren.

### Stakeholder-panel

`tools/stakeholder_router.py --plan --json <27 vägar>` → **full-panel** (high-stakes:
`firestore.rules`, `storage.rules`; routern seatar 18 roller). Seatade (egen insats i
blast-radius): **DevOps/SRE, Security Architect, Privacy/DPO, FinOps, Release/App-Store
Compliance** + Codebase Archaeologist. Släppta: QA (bevislistan F ärver stagingpanelens
QA-villkor; workflows ändrar bara inloggningssätt), DBA (region/TTL/index ligger redan som
villkor från BUT-451), Legal (DPO täcker datalokalisering), PM (ingen produktändring),
Support, T&S, Performance, Vendor (inga nya biträden — samma Vertex EU, Algolia, Resend,
OCR), Software Architect, Monetization, Agent-Ops, Data/ML (modellkopian är ett villkor,
se D), Release Manager (DevOps täcker).

**Utfall (blind, parallell, en runda, 2026-10-20):** alla sex → *approve-with-conditions*;
inget block, ingen olöst konflikt. Villkoren är invävda i B/D/E/F och samlade i H.
Två nära-konflikter löstes av synteser (jag) utan eskalering:
- *Gamla deploy-nyckeln:* Security ville spärra nyckeln hos Google samma dag som
  GitHub-hemligheten raderas; DevOps ville behålla hemligheten till ⑧ som återställningsväg.
  Lösning: **inget raderas före ⑧**; vid ⑧ spärras nyckeln hos Google och hemligheten
  raderas samma dag. Båda villkoren uppfyllda (ADR-0033).
- *Bucket-region:* DevOps flaggade att `moderateUpload` (west1) mot en west3-bucket är
  oprövat; doku-avläsning avgjorde det → ④ ändrad till europe-west1.
Två frågor är Malins (kort): App Check-enforcement-läge i nya projektet (Security:
"billigaste stunden någonsin att slå på") och Play Console-statusen (Release).
Arkeologen hittade ingen tidigare återrullning i området; lärdomarna sitter i
ee7b96cc8/d3f9437dd/3edd3ecd6/c6d0091d6 (första gen2-deployer är kvot- och
ordningssköra, och smoke-gaten har själv producerat falska röda som utlöst rollback).

---

## Planen

### A — Vägval (där Malins omdöme spelar roll)

① **Projekt-id.** Permanent, syns i auth-länkar (`<id>.firebaseapp.com`) och i
`<id>.web.app`. *Rekommendation:* `butlery-prod` — kort, säger vad det är, skiljer sig
tydligt från `butlery-app-staging`. *Alternativ:* `butlery-app` (snyggast men kan vara
upptaget globalt; ledigheten syns först i skapandeflödet) eller `butlery-se`. Id:t kan
döljas för användarna med en egen auth-domän (②).
**Beslut (Malin 2026-10-20): `butlery-app`.** Är det upptaget när projektet skapas
faller vi tillbaka på `butlery-prod` utan ny fråga. `<id>` nedan = det som blev ledigt.

② **`butlery.app` kopplas till nya projektet redan vid bygget.** Mätt: domänen pekar i
dag på OVH, inte Firebase, och callables tillåter bara den domänen. *Rekommendation:*
koppla `butlery.app` + `www` som custom domain på nya projektets app-sajt (Malin ändrar
A/AAAA + TXT hos OVH; Firebase ger värdena), lägg `butlery.app` i Auth authorized domains,
och **ingen kodändring i cors-listorna**. Auth-länkar (lösenordsåterställning, app-länkar)
fortsätter gå via `<id>.firebaseapp.com`; en egen auth-domän (`auth.butlery.app`) är ett
eget ärende senare — Googles doku stödjer det, men vad som händer med Android-app-länkarnas
värd (`/__/auth/links`) är **inte verifierat**. *Alternativ:* vänta med domänen → webbappen
på `<id>.web.app` kan inte anropa funktioner förrän 24 cors-listor ändras (bör ändå bli en
delad konstant, eget ärende). **Beslut (Malin 2026-10-20): koppla nu.**

③ **App Check på Android = Play Console.** Play Integrity godkänner bara appar som Play
känner till. Nya projektet måste länkas från Play Console → App integrity ("Link Cloud
project"); en Play-app kan bara vara länkad till ett projekt i taget, så länkningen är
cut-over-steget för telefonen. *Fråga till Malin (fakta jag inte kan mäta):* finns
`se.butlery.app` i Play Console i dag? Om nej blir "skapa appen + intern testspår" ett steg,
och tills dess fungerar callables på telefonen bara via ett debug-token (som Malin avböjde
för staging; erbjuds inte igen). Webb: ny reCAPTCHA v3-nyckel registrerad i nya projektets
App Check, bytt i `lib/main.dart`. iOS: App Attest-registrering.
**Beslut (Malin 2026-10-20):** appen finns **inte** i Play Console → fas 4 börjar med
"skapa `se.butlery.app` i Play Console, **Play App Signing** (Googles nyckel signerar,
CI:s upload-nyckel laddar upp → `assetlinks.json` bär Googles signeringscert, läst ur
Play Console → App integrity), internt testspår, länka `<id>` under App integrity".
Enforcement: **Unenforced under bygget, slås på efter F8** (telefon + webb bevisade) och
före gamla projektet raderas — det stänger BUT-1445. Play Console-länken är ett
ägarklick (projektets Owner måste vara Malin själv, inte via grupp — avläst i Firebase-doku).

④ **Regioner.** Firestore **europe-west3** (som i dag; index, TTL, backup-skript och
staging matchar), funktioner **europe-west1** (koden pinnar regionen;
Cloud Run-kvoten mättes OK där i staging; Vertex `eu`), och **Storage-bucket
europe-west1** — inte west3. Skäl (avläst 2026-10-20, Firebase-doku "Cloud Storage
triggers" + Googles Terraform-exempel): en Storage-trigger (`moderateUpload`,
`onObjectFinalized`, pinnad till europe-west1 i `moderate-upload.ts`) måste ligga i
samma region som bucketen, annars kan deployen misslyckas. Bucket i west1 = ingen
kodändring, ingen ny kvotmätning. Bevis F2 innan någon fil laddas upp. *Alternativ:*
bucket i west3 + flytta `moderateUpload` (kod + kvot i west3), eller multi-region `europe`
(dyrare, listpris ej avläst). Firestore-triggers går redan i dag cross-region (west3-databas,
west1-funktioner), så Firestore stannar i west3.

⑤ **Deploy till prod via WIF från dag ett, aldrig en nyckel.** Nya projektet får egen
pool + leverantör + servicekonto med samma minsta rättigheter som staging, GitHub-miljön
`production` byter från hemligheten `FIREBASE_SERVICE_ACCOUNT` till variablerna
`GCP_WORKLOAD_IDENTITY_PROVIDER`/`GCP_DEPLOY_SERVICE_ACCOUNT`, och de sex prod-workflows
(`deploy-firebase`, `deploy-hosting`, `deploy-app-link-files`, `backfill-age-claim`,
`migrate-meal-type`, `repair-feature-retention`) tappar nyckelgrenen. Vaktsteget behåller
"ingen miljö får se `FIREBASE_SERVICE_ACCOUNT`" tills hemligheten är raderad. Det stänger
BUT-2421. *Alternativ:* ny nyckel som i dag — en dag snabbare, en till långlivad hemlighet.

⑥ **Vad "tomt" betyder — vad som ändå ska över.** Inga användare, ingen Auth-export, inget
`feedback/`. Men appen går inte utan: `ingredients` (synkas från repots filer via
`sync-ingredients --project`), `tagConfigs`/`tag_configs` (`seed-tag-configs`),
`site_configs` (`seed-site-configs`), `system/config` (6 nycklar: `aiEnabled`,
`llmParserEnabled`, `llmSampleCaptureEnabled`, `guestDailyImportLimit`,
`globalHourlyLimit`, `globalDailyLimit` — värden avläses i gamla prod och sätts för hand),
Remote Config-mallen (exporteras med `remoteconfig:get`, publiceras med `deploy --only
remoteconfig`), `models/` i bucketen (ML-modeller, inga personuppgifter; `gsutil cp`
bucket→bucket — undantaget från "inget flyttas mellan projekt", motiverat i D),
`admins/{Malins nya uid}` (triggern sätter claimen). `_internal` och `butlery_archive`:
innehåll kontrolleras (läsning) innan beslut — **inte verifierat vad de håller**.

⑦ **Cut-over = en pushad commit-sekvens på `main` + Malins variabelbyte, ingen mellanmiljö.**
Eftersom gamla prod saknar riktiga användare behövs ingen period där båda är "prod".
Ordningen: moln-bring-up (B1) körs med `--project <id>` från CLI/konsol; sedan landar
**en** pushad commit-sekvens (ett commit per grind-familj) som byter alla literaler (C) och WIF-workflows (⑤); samtidigt byter Malin
miljövariablerna i `production`. Vaktstegen gör bytet säkert: om variabeln och
`.firebaserc` inte stämmer överens vägrar deployen. Fönstret där `main` pekar på ett
halvbyggt projekt stängs av att ingen användare finns där. *Alternativ:* en tillfällig
GitHub-miljö `production-next` + alias — mer att städa, skyddar ingen.

⑧ **Avveckling av `butlery-app-1`:** när bevisen F1–F14 är gröna och Malins telefon +
webb går mot nya: ta bort delete-protection på Firestore, `gcloud projects delete
butlery-app-1` (30 dagars ånger hos Google = fristen), radera dess två budgetar, GA-egendomen
avkopplas (Malin i GA-admin, **inte verifierat** om projektraderingen gör det själv), och
ett uppföljande commit tar bort gamla id:t ur `require-project.ts`-listan och testerna.
*Alternativ:* behåll 30 dagar till → dubbla vilande kostnader, inget vunnet eftersom
Google ändå håller 30 dagar. **Beslut (Malin 2026-10-20): radera när bevisen är gröna
och 7–14 dagars soak visar noll anrop från andra än Malin.**

⑨ **Staging-bucketen** ligger också i US-CENTRAL1 och håller sedan ADR-0032 Malins egna
testbilder. Bucketlokation kan inte ändras. *Rekommendation:* lämna den (dokumenterad i
`docs/ops/staging.md`, bara Malins egna data, hon har samtyckt), och när nya prod står är
samma recept körbart på staging om hon vill (eget ärende, ~½ dag). *Alternativ:* bygga om
staging nu → fördröjer prod.
**Beslut (Malin 2026-10-20): bygg om staging FÖRST**, som generalrepetition. Det ändrar
byggordningen: fas 0.5 nedan kör hela receptet (EU-bucket i west1, `moderateUpload`-
triggern mot den, låst läge + tidiga regler, seedordning, rollback-undantag,
omgångsordning, `.env`-skrivning) på staging, där ett fel kostar ingenting. Varje
villkor i H som kan bevisas på staging bevisas där först. Hur bucketen byts är **inte
verifierat**: alternativ A = radera stagings US-bucket (bara Malins testbilder; staging
har inga backuper med avsikt) och skapa en ny default-bucket i europe-west1 i samma
projekt, om Firebase-konsolen tillåter att default-bucketen återskapas; alternativ B =
nytt stagingprojekt (`butlery-staging`) och gamla raderas — samma literalbyten i
`firebase_options_staging.dart`, `build.gradle.kts`, `firebase_env.dart`,
`build-staging-apk.yml`, `seed-staging.js`, miljön `staging`. A prövas först;
B är fallback utan ny fråga. Privacy-villkoren i D om staging-US faller bort när
bucketen är i EU.

⑩ **Budget:** 50 kr/mån per projekt med larm 50 %, 100 % + prognos, som staging och
gamla prod (SMS-MFA-budgeten på 200 kr återskapas inte — SMS-MFA finns inte längre),
**plus en budget på billingkonto-nivå, 150 kr/mån**, under överlappet — larmet
som ser summan av tre projekt (FinOps). Säg andra summor för att byta.

⑪ **Play Console och freeRASP.** Appen finns inte i Play (③). Ett Google Play-
utvecklarkonto krävs (engångsavgift + identitetsverifiering som kan ta dagar) — **inte
verifierat** om Malin har ett; kontot och identitetsverifieringen startas i fas 0, parallellt med bygget, så att väntan inte hamnar på den kritiska vägen; länkningen görs i fas 4. Med Play App Signing signeras
testspårsbygget med Googles nyckel, men `lib/services/device_integrity_service.dart`
pinnar freeRASP till **upload-nyckelns** SHA-256 → Googles signeringscert-hash läggs till
(`FREE_RASP_ANDROID_CERT_HASH`/hashlistan) i bytescommiten, annars flaggar
integritetskontrollen det Play-installerade bygget (bevis i F8 och F12).

**Svagaste punkten:** ③ (Play Console-länkningen är ett konsolsteg hos Google som bara
Malin kan göra och som inte går att prova i förväg) och ⑦:s samtidighet (commit + två
miljövariabler i samma stund). Vaktstegen gör ⑦ ofarligt — fel ordning ger ett stopp, aldrig
en deploy till fel projekt.

### B — Byggordning

**Fas 0 — Beslut (Malin).** Korten ①②③⑧⑨ är besvarade 2026-10-20 (se A). Kvar:
"ja" i chatten till billingkoppling av varje nytt projekt till `018435-3E1A9A-121048`
(Blaze) i det ögonblick det skapas. Inget skapas före det. Samtidigt startar Malin
Google Play-utvecklarkontot och dess identitetsverifiering (⑪), som kan ta dagar.

**Fas 0.5 — Generalrepetition på staging (⑨).** Samma steg som fas 1 punkt 3 (bucket
i europe-west1, låst läge, tidiga regler), fas 2:s workflow-ändringar (rollback-undantag,
retire-loop-gate, `.env.<id>`-skrivning, Capture/rollback WIF-rena — de landar på `main`
i egna commits före prod-bytet och gäller båda miljöerna), fas 3:s ordning (verify-dispatch
→ regler/index/storage → seedning med `aiEnabled: false` → funktioner i dokumenterad
omgångsordning), och bevisen F2, F6, F7, F13, F14, F15 (e)(f)(g)(m)(o). Bucketbytet
enligt A/B i ⑨. Utfall: en körd checklista som fas 1–3 följer rad för rad, och
`docs/ops/staging.md` uppdaterad (Storage-raden till EU). Privacy-villkoren för staging-US
stryks då ur D. Uppskattning ~1 dag; BUT-2425 (staging-testningen) väntar fortfarande
till nya prod står.

**Fas 1 — Molnet (Claude via CLI + Firebase-konsolen i webbläsaren med Malins inloggning;
Malin själv bara där det står).**
1. `firebase projects:create <id>` med Google Analytics på (ny GA-egendom; konto/region
   väljs i konsolen); `gcloud billing projects link` (**Malin säger ja i chatten först**).
2. API:er: Firestore, Functions/Run/Build, Artifact Registry, Secret Manager, Scheduler,
   Eventarc, Pub/Sub, Vertex AI, Identity Toolkit, App Check, Hosting. Vänta in
   service-agenterna; kör de fem IAM-handgranterna från briefen (Pub/Sub-agent:
   tokenCreator + pubsub.serviceAgent; compute-SA: run.invoker, eventarc.eventReceiver,
   secretAccessor per secret; Storage-agent: pubsub.publisher; Eventarc-agent:
   eventarc.serviceAgent). Mät Cloud Run-kvoten i europe-west1 (bevis F3).
3. Firestore i europe-west3 (`firestore:databases:create --location europe-west3`), PITR
   på, delete-protection på. **Storage: "Get started" i konsolen med lokation
   europe-west1** → bevis F2 direkt (`gsutil ls -L -b`, och bucketnamnet måste vara exakt
   `<id>.firebasestorage.app` eftersom `reset-user-data.ts`, `ocr-url-validator.ts`
   härleder det). **Båda i låst läge** (production mode, inte test mode) och direkt
   därefter `firebase deploy --only firestore:rules,storage --project <id>` från CLI med
   repots regler, innan något app-konfig pekar på projektet; bevis: anonym läsning och
   skrivning nekas (Security). Ingen Realtime Database (finns inte i prod heller;
   `database`-blocket i `firebase.json` är dött — eget litet ärende).
4. **Identity Platform-uppgradering** (krävs för TOTP-MFA; nämndes inte i staging-doku,
   FinOps/DevOps). Auth: e-post/lösenord, Google, Apple (**Malin** matar in Services-id, Team-id,
   nyckel-id och .p8 — hemligheter, aldrig i chatten; Apple-portalens return-URL byts till
   `https://<id>.firebaseapp.com/__/auth/handler`), TOTP-MFA, e-postuppräkningsskydd,
   lösenordsmallen (replyTo `info@butlery.se`, samma text — läses ur gamla projektets
   Auth-konfig via admin-API:t och skrivs in i nya), authorized domains = `<id>.firebaseapp.com`,
   `<id>.web.app`, `butlery.app`, `www.butlery.app` — **inte `localhost`** (Security;
   lokal webbutveckling går mot staging). OAuth-samtyckesskärmen i nya GCP-projektet (**Malin**: External/In production,
   appnamn, supportmejl, policy-URL). Registrera Android-appen `se.butlery.app` + SHA-1/256
   för upload-nyckel och Malins debug-nyckel, iOS-appen `se.butlery.app`, webbappen,
   Windows-webbappen (samma fyra som i dag).
5. App Check (③): Android Play Integrity registreras här (Play Console-länken görs i
   fas 4, **Malin**), iOS App Attest, webb reCAPTCHA v3 (ny nyckel på `butlery.app` +
   `<id>.web.app`); enforcement enligt Malins kort (Unenforced vid bygget; slås på efter F8). iOS: APNs-nyckel (.p8) laddas upp till Cloud Messaging (**Malin**), annars dör
   push på iOS tyst (Release). API-nycklar: Android-nyckeln låst till paket + SHA;
   browser-nyckeln låst till referrers; den auto-skapade "Browser key (auto created by
   Firebase)" begränsas eller raderas; **separat** Identity Toolkit-servernyckel (bara
   identitytoolkit) → Secret Manager `IDENTITY_TOOLKIT_API_KEY`; bevis
   `gcloud services api-keys list` visar restriktioner på varje nyckel. IAM: ta bort
   Editor från default compute-/App Engine-kontona om projektet fått dem automatiskt
   (inget org-skydd på ett projekt utan organisation, Security).
6. Secret Manager: `MFA_RECOVERY_PEPPER` (nytt CSPRNG-värde, pipat via stdin — aldrig
   argv eller chatt), `IDENTITY_TOOLKIT_API_KEY`
   (ny), `FEEDBACK_EMAIL_API_KEY` (samma Resend-nyckel, **Malin** klistrar in i CLI-prompten).
   De två oanvända (`GEMINI_API_KEY`, `MISTRAL_API_KEY`) återskapas inte. Feedback-mejlens
   adresser (`FEEDBACK_EMAIL_TO/FROM`, `FEEDBACK_DASHBOARD_URL`, ev. `COST_CAP_USD`) läggs
   som miljöhemligheter i `production` och skrivs till `functions/.env.<id>` i deploy-jobbet
   — det stänger BUT-2420 (innehållet i dagens lokala fil fick jag **inte läsa**; Malin
   bekräftar värdena vid genomförandet).
7. Hosting: sajterna `<id>` (app), `<id>-admin`, `<id>-legal` (namnen `butlery-admin`/
   `butlery-legal` ägs av gamla projektet; om de blir lediga efter raderingen är
   **oklart** — planen räknar inte med dem); custom domain `butlery.app` + `www` (②,
   **Malin hos OVH**).
8. WIF-pool + leverantör i nya projektet med attributvillkor som pinnar
   `repository_id`, `environment == "production"` **och** `ref == "refs/heads/main"`
   (villkorssträngen i beviset; negativt test: en körning från annan gren/miljö nekas
   token). Servicekonto med stagings rollista + `secretmanager.viewer`. **Inga
   GitHub-variabler eller hemligheter byts i fas 1** (DevOps + Arkeologen: planens första
   utkast satte variablerna här, vilket motsade ⑦ — struket). Nya projektets
   google-services-JSON läggs under ett **nytt** hemlighetsnamn
   `GOOGLE_SERVICES_JSON_BASE64_EU` (`firebase apps:sdkconfig` → base64 → `gh secret set`;
   värdet passerar aldrig chatten); bytet av miljövariabler och läsning av det nya
   namnet sker i fas 2/⑦. `FIREBASE_SERVICE_ACCOUNT` behålls till ⑧.
9. **Före första funktionsdeployen** (FinOps): budget (⑩) + en budget på
   **billingkonto-nivå, 150 kr/mån**, som larm som ser summan av tre projekt under
   överlappet; Artifact Registry-städpolicy (samma 1-dygnsregel). Backup-scheman
   (dagligt 7 d, veckovis 14 v, kommandona i `backups.md`), bucket-versionering + lifecycle
   enligt `storage-lifecycle-runbook.md`. Larm via
   `infrastructure/alerting/setup-gcp-alerts.sh` med `GCP_PROJECT_ID=<id>` först **efter
   första rena dygnet** (annars larmar tomma databasen). Vertex: kontrollera att
   `gemini-2.5-flash-lite` finns i `eu` för projektet (F9).
10. **Kopiera `models/` före bytet** (Arkeologen: `model-version-guard.yml` kör
    varje natt mot bucketen i `tools/ci/check_model_versions.py`; byts literalen före
    kopian blir vakten röd samma natt). Privacy-villkor först: manifest per fil
    (namn, sha256, träningskälla); en modell tränad på användarkorrigeringar
    (`retrain_with_corrections.sh`) kopieras **inte** utan byggs om ur repots korpus.
    Manifestet går in i ADR:n.

**Fas 2 — Repot (Claude; vanliga grindar; ett commit per grind-familj, pushat som en
sekvens direkt efter varandra så `main` är konsekvent):**
- `flutterfire configure --project=<id>` (alla fem plattformar) → `lib/firebase_options.dart`
  + `firebase.json`-blocket (det inaktuella `4a2e41f5…` försvinner); lokala
  `google-services.json` och `GoogleService-Info.plist` byts; `Info.plist` får nytt
  `GIDClientID` + reverserat schema; `Runner.entitlements` nytt applinks-värd;
  `build.gradle.kts`; `firebase_env.dart`; `main.dart`; `security.txt`.
- `.firebaserc` (`production: <id>`, nytt `targets`-block), vakttestet och
  `require-project.ts` (nya id:t läggs till, gamla tas bort i ⑧-commiten),
  `ocr-url-validator.ts` (fallbacken tas bort — testerna sätter env själva; en körande
  funktion utan env är ett fel, inte prod), skript-defaults, docs (`backups.md`,
  `staging.md`, `RUNBOOK.md`, `.well-known/README.md`, tre runbooks, ACCEPTED_DEVIATIONS-
  omnämnanden), testfixturer.
- Workflows (⑤): nyckelgrenen bort i alla sex; WIF-steget körs för båda miljöerna;
  vaktsteget jämför WIF-tokenets projekt i båda (vaktens prod-gren läser i dag
  `project_id` ur nyckeln och måste skrivas om); **Capture- och Auto-rollback-stegen** i
  `deploy-firebase.yml` kör `gcloud auth activate-service-account --key-file` och måste
  bli WIF-rena (DevOps); vakten delas som en composite action eller täcks av
  `deploy-project-guard.test.ts` per workflow; `build-validation.yml` **och**
  `emulator-lane.yml` läser det nya hemlighetsnamnet; `deploy-firebase.yml` skriver
  `functions/.env.<id>` ur miljöhemligheterna **före varje** funktionsdeploy-steg
  (annars tomma `FEEDBACK_EMAIL_*` utan fel).
- **Bring-up-skydd i `deploy-firebase.yml`** (Arkeologen): auto-rollback-steget är
  prod-only och fyrar på varje röd smoke-gate → den första omgångens körningar måste
  undanta det (t.ex. hoppa över när `functions_only` är satt) tills första helgröna
  gaten; retire-loopen (16 × `functions:delete`) är död kod i ett nytt projekt och gatas
  bort på samma villkor; `tags:`-triggern deployar alltid `all` till prod → **inga
  release-taggar** under fas 1–3.
- Versionskod: `versionCode` (och iOS-byggnummer) höjs i bytescommiten över allt som
  någonsin laddats upp till Play (samma paketnamn, nytt backend = samma app för Play,
  Release).
- Fler literalplatser än första listan (Arkeologen): `scripts/crf/export_corrections.dart`,
  `scripts/generate_known_ingredients.dart`, `functions/scripts/__tests__/seed-staging.test.js`,
  emulator-grenen i `firebase_env.dart`; acceptanskontroll = repo-vid grep på gamla
  id:t med `.dart_tool`, `__pycache__`, `functions/fnlist.tmp.json` och `.claude/state`
  undantagna. Utanför repot: `~/.claude/scheduled-tasks/synat-morgonkoll/SKILL.md`
  (läser prod-loggar med `--project=butlery-app-1`) och radio-/brief-rutinerna byts samma
  timme som commiten, annars rapporterar de tomma loggar som "friskt".
- `docs/onboarding/workflow-map.stale` hanteras enligt CLAUDE.md om markören dyker upp.
- Tester: `firebase_env_test.dart` (nytt id), `deploy-project-guard.test.ts`,
  `require-project.test.ts`, `ocr-validation.test.ts`, `repair-feature-retention.test.ts`;
  `flutter analyze --fatal-infos`; `functions` unit-svit; `flutter build apk --flavor prod`
  med oförändrad signatur (F12).

**Fas 3 — Första driftsättning (bara CLI/workflows, aldrig MCP `firebase_deploy`).**
Ordningen är styrd av två fällor: triggers som fyrar på seedning, och schemajobb mot en
tom databas (DevOps).
1. Första prod-dispatch = en **verifieringskörning** utan deploy (vakt + `gcloud projects
   describe`), så WIF-vägen bevisas (F5) innan något skrivs.
2. `target=rules` (Malin godkänner) → indexes (vänta READY; TTL-posterna följer med
   `firestore:indexes`; workflown skickar alltid `--force`, vilket på ett tomt projekt
   inte kan radera något levande — mätt i `reference_firestore_index_force_deploy.md`)
   → storage.
3. **Seedning före triggers:** `sync-ingredients`, `seed-tag-configs`, `seed-site-configs`
   med `--project <id>` (allowlistan i `require-project.ts` uppdaterad i fas 2),
   `system/config` för hand med `aiEnabled: false` tills taken är satta och avlästa
   (FinOps: kodens default 1000/10000 är fail-open), Remote Config-mallen.
   `onIngredientPropertiesChanged`/`onIngredientSoftDeleted` (retry: true) får inte
   finnas när ingrediensen synkas, annars triggerstorm.
4. Funktioner i omgångar via `functions_only` (≈107 × 90 s ≈ 2,7 h, uppskattning;
   dokumenterad omgångsordning: de 12 `REQUIRED_FUNCTIONS` i **sista** omgången så bara
   den läser gaten grönt; schemajobb-funktionerna sist, efter att `system/config` finns).
   Sedan `aiEnabled: true`.
5. Hosting (app, admin, legal; `deploy-app-link-files.yml` för `.well-known` —
   `assetlinks.json` ska bära **Play App Signing-certet**, inte upload-certet, om Play
   App Signing används; avgörs i kort ③; verifieras med Digital Asset Links-API:t).

**Fas 4 — Malins telefon och webb.** Avinstallera prod-appen — uppdatering på plats är
**inte** säker: köade foton/offline-skrivningar skulle spelas upp mot nya backend med
gammal uid (Release). Installera nytt bygge via **Play internt testspår**
(sidladdat bygge kan inte passera Play Integrity). Registrera konto,
`admins/{uid}` skrivs → claim; webben på `butlery.app` efter DNS. Bevis F6–F8. Samma
avinstallera-och-installera gäller alla TestFlight-/testspårsanvändare (i dag: ingen).
Ingen butiksinlämning under fönstret.

**Fas 5 — Avveckling (⑧).** Först: kör raderingskaskaden på de 4 testkontona i gamla
projektet (Privacy: avsiktlig radering i stället för utgång, och det bevisar kaskaden en
gång till), ta bort `feedback/{uid}`. Soak 7–14 dagar med noll anrop från andra än Malin
(Cloud Run-räknare, Firestore-läsningar, Auth-inloggningar). Sedan: pausa (inte radera)
gamla projektets schemajobb, spärra deploy-nyckeln hos Google + radera
`FIREBASE_SERVICE_ACCOUNT` samma dag, ta bort delete-protection, `gcloud projects delete`,
radera budgetarna, GA-egendom. Städcommit (gamla id:t ur allowlista/tester/docs) +
Art. 30-notering med raderingsdatum + minnes- och docs-uppdatering. Återställning efter
detta = Googles 30-dagarsfönster, som återställer projektskalet men **inte** lovar
fungerande tjänst, Play-länk, Apple-return-URL eller GA.

**Fas 6 — Återuppta BUT-2425.** Staging-testningen (BUT-2425) körs mot ombyggd staging
och nya prod; de nya ärendena är dess blockers och stängs i tur och ordning. Det är
planens sista steg, som briefen kräver.

### C — Mekaniskt (inga beslut)
Literalbyten i de 20-talet filerna ovan, testfixturer, docs-omnämnanden, gitignore-rader,
workflow-huvudkommentarer. Ingen UI-ändring → inga skisser.

### D — Dataseparation och personuppgifter
- Inga Auth-användare, ingen Firestore-export/-import, inget `feedback/` flyttas.
  Vakttestets export-förbud består. Kopian: `models/` (ML-modellfiler byggda ur repots
  korpus, inga personuppgifter) — motiveras så i ADR; Privacy-kritikern får frågan uttryckligen.
- Nya prod blir den plats där testgruppens (och Malins) uppgifter hanteras. Samma dag som
  bytet landar (Privacy): `assets/legal/privacy_policy_en.md` + `_sv` i synk, versions-
  bump förbi 1.19.0 (repots version; 1.17.0 är den publicerade) med datum; tabellraden (rad 213) får "Cloud Storage: europe-west1"
  (i dag anges plats bara för Firestore och Functions — policyn utelämnar alltså redan
  US-bucketen); raden "Realtime Database" stryks (ingen instans finns); Art. 30-raden för
  prod får nytt projekt-id + bucketregion + daterad notering om avvecklingen av
  `butlery-app-1` och dess slutliga raderingsdatum. Play Data Safety och App Store-
  etiketterna ändras inte (samma biträden) — en enrads "ingen ändring"-kontroll mot
  `docs/ops/play-data-safety-runbook.md`.
- Samma biträden som i dag (Google Cloud EU, Vertex EU, Algolia, Resend, OCR.space); inga nya.
  Algolia är klientsidan (nycklar i `.env`, slås på av Remote Config-flaggan
  `enable_algolia_search`, `search_module.dart`) och är inte bunden till projektet;
  flaggan följer med Remote Config-mallen. Crashlytics-aktivering kontrolleras i F8.
- **Var data ligger, per tjänst** (det som "i EU" faktiskt täcker): Firestore europe-west3,
  Storage europe-west1, Functions europe-west1, Vertex `eu` — mätt/valt. Auth (Identity
  Platform), Analytics, Crashlytics, FCM, Remote Config och App Check är globala Google-
  tjänster utan regionsval — **inte verifierat** var de lagrar; policyn täcker dem redan
  i dag under "USA (DPF)" (rad 162–165) och den formuleringen behålls. Planen lovar
  alltså "alla databaser och filer i EU", inte "allt".
- **Policyns publiceringsadress:** policy 1.17.0 ligger på `butlery-legal.web.app`
  (ACCEPTED_DEVIATIONS, BUT-1997; `deploy-hosting.yml`), som försvinner med gamla
  projektet. Ny adress väljs vid genomförandet — rekommendation: en egen underdomän
  (t.ex. `legal.butlery.app`) som custom domain på den separata legal-sajten `<id>-legal`,
  så att adressen aldrig mer bär ett projekt-id och policyn behåller sitt eget
  hosting-mål utan Flutter-bygge (inte en sökväg i appens mål, se lärdomen "En statisk
  sida som läggs i appens hosting-mål publicerar APPEN", 2026-10-05) — och skrivs in i OAuth-samtyckesskärmen (B1.4), i apparnas länkar och i Art. 30.
  Repo-grepen i acceptansen söker också `butlery-legal` och `butlery-admin`.
- ADR-0032 avslutas (står fortfarande som "Escalated"); med staging ombyggd i EU (⑨)
  försvinner US-raden ur `staging.md` och Art. 30.
- Vakttestets export-förbud består; F8 exporterar Auth från **nya** och visar bara Malins konto.

### E — Kostnad (listpriser avlästa 2026-10-20 där det står; annars **uppskattning**)
- Cloud Scheduler: 17 jobb, frikvoten 3 jobb/månad gäller per **billingkonto** och är
  upptagen av gamla prod tills det raderas; $0,10/jobb/31 dagar (avläst,
  cloud.google.com/scheduler/pricing) → ≈ 18 kr/mån, ≈ 15 kr när gamla är borta.
- Firestore PITR/backup-lagring: Frankfurt-raden fick jag **inte fram** (US-pris $0,15
  resp. $0,03 per GiB-mån); på en nära tom databas ≈ 0–2 kr.
- Storage europe-west1: regionalt GCS-pris (ej avläst, ~$0,02/GB-mån) × 0,1 GB ≈ 0 kr;
  **inget** no-cost-utrymme utanför US-regionerna (avläst, Firebase FAQ sept 2024).
- Secret Manager ≈ 2 kr; Artifact Registry med 1-dygnsstädning ≈ 5–10 kr; Cloud Run/
  Functions vid 0 trafik ≈ 0; GA/Crashlytics 0.
- **Saknade rader (FinOps), alla uppskattningar tills mätta:** Cloud Build-minuter för
  107 byggen × antal omgångar + omkörningar (frikvoten är per billingkonto och delas med
  staging + gamla prod); Eventarc/Pub/Sub för de triggade funktionerna; Secret Manager-
  åtkomster (3 secrets × 107 funktioner per kallstart); Identity Platform (TOTP, ~0 vid
  4 användare); Firestore-operationer vid seedning + TTL + första backupen; engångs-egress
  US→EU för `models/` (cent). AI-kostnaden är bunden av `system/config`-taken — och
  `aiEnabled: false` tills de är avlästa.
- **Vilande ≈ 30–40 kr/mån** (golv, utan raderna ovan); under bytet ligger gamla + nya +
  staging parallellt i högst några veckor. Överlappet får en egen spärr: budget på
  billingkonto-nivå 150 kr/mån, och gamla projektets schemajobb pausas så snart nya
  projektets är verifierade (annars körs varje jobb dubbelt). Beloppen i Linear
  markeras "uppskattning".
- **Mäts före genomförande (inte före godkännande — läsning tar ½ h):** gen2-/event-
  triggade funktioner ur `functions list`; Cloud Build-minuter och Artifact-GiB senaste
  månaden i gamla prod + staging; Frankfurt-/Belgien-priser för PITR, backup, Storage;
  gamla projektets senaste hela månad per SKU. Ersätter varje "uppskattning" i E.

### F — Bevis (varje steg läses av på resursen, aldrig bara CLI:ns exitkod)
1. `gcloud projects describe <id>` + `gcloud billing projects describe <id>` → Blaze, rätt konto.
2. `gsutil ls -L -b gs://<id>.firebasestorage.app` → `Location constraint: EUROPE-WEST1`
   **innan** något laddas upp; `gcloud firestore databases describe` → europe-west3, PITR på.
3. `gcloud compute regions describe europe-west1` / Cloud Run-kvoten ≥ staging-värdet.
4. `firebase use production` → `<id>`; `firebase use` utan alias → fel; vakttestet grönt.
5. Prod-dispatch `target=rules`: loggen visar `FIREBASE_PROJECT_ID=<id>`, WIF-projekt =
   `<id>`, och jobbet läser aldrig `FIREBASE_SERVICE_ACCOUNT` (steget som läste den är
   borta ur workflown). Hemligheten raderas först i ⑧ (då: spärra nyckeln hos Google +
   radera hemligheten samma dag, och en prod-dispatch efteråt går ändå grönt).
6. `gcloud scheduler jobs list` och `gcloud firestore fields ttls list` i nya diffas mot
   gamla: 17 resp. 28, identiska namn; `gcloud functions list` = 107 ACTIVE;
   `firebase functions:list --json` visar `state: ACTIVE` för alla.
7. Firestore-regler lästa tillbaka (`firestore:rules` get / MCP `firestore_get_rules`) =
   repots fil; en avsiktlig testregeländring syns i nya och **inte** i gamla, backas.
8. Malins telefon: nytt bygge, inloggning, ett recept syns i nya projektets Firestore;
   `structureRecipe` anropas **utan** "AppCheck token was rejected" i loggen (③-beviset);
   `firebase auth:export` från nya = bara Malins konto; `admins/{uid}` → claim satt
   (`auth:export` visar `customClaims.admin`); ett testfel från prod-bygget syns i nya
   projektets Crashlytics.
9. Vertex: ett parsningsanrop i loggen visar `gemini-2.5-flash-lite` i `eu`, inget fallback.
10. Hosting: `curl -sI https://butlery.app` svarar från Firebase (headers), admin-sajten
    laddar inloggad; `/.well-known/assetlinks.json` serveras med rätt SHA-256.
11. App Check-API:t: tre tjänster UNENFORCED i nya under bygget; reCAPTCHA-nyckeln
    registrerad. Efter F8 och påslaget (③): samma API läser **ENFORCED** på alla tre, och
    telefon- + webbanropen i F8 körs om och går igenom.
12. `apksigner verify --print-certs` → samma upload-signatur som före; `flutter analyze
    --fatal-infos` + unit/widget-sviter gröna.
13. Budget, backup-scheman, Artifact-städpolicy, bucket-versionering + lifecycle lästa
    tillbaka med `gcloud billing budgets list`, `backups schedules list`, `artifacts
    repositories describe`, `gsutil versioning get` / `lifecycle get`.
14. Raderingskaskaden: ett syntetiskt konto raderas i nya; probe-legs rena (samma bevis
    som F11 i staging-planen).
15. **Tillagda av panelen:** (a) avkodad `GOOGLE_SERVICES_JSON_BASE64_EU` innehåller nya
    projekt-id:t; (b) de fem IAM-handgranterna + WIF-villkoret lästa tillbaka, negativt
    test att annan gren/miljö nekas token; (c) secret-versioner + accessor-bindningar, och
    **ett riktigt anrop** av var och en av de tre secret-läsande funktionerna; (d) Auth-
    konfigdiff gamla↔nya via Identity Toolkit-admin-API:t (providers, MFA, domäner,
    mallar, Apple); (e) Storage-regler lästa tillbaka; (f) composite-index-diff + READY;
    (g) Remote Config, `system/config`-värden och seedade dokumenträkningar diffade mot
    gamla; (h) `models/`-sha256 mot manifestet; (i) larmpolicyer + kanaler;
    (j) `deleteProtection` på Firestore; (k) hosting-cert + `www` + AASA-filen;
    (l) Cloud Run-kvotens **siffra** i west1 (inte "minst stagings"); (m) anonym läsning +
    skrivning nekas direkt efter steg 3; (n) `firestore.rules`-sviten körd mot nya
    projektets deployade regler, inte bara emulatorn; (o) en batch deployad med
    `functions/.env.<id>` ger icke-tomma `FEEDBACK_EMAIL_TO/FROM`.

### G — Risker och återställning
- *Bucket hamnar i fel region igen* → F2 körs före första uppladdningen; fel region = radera
  bucketen och börja om (går bara medan den är tom).
- *Deploy till fel projekt* → tre vaktkällor (variabel, alias, WIF-token) + inget default-alias.
- *Play Integrity säger nej på telefonen* (③) → beviset F8 avgör; fallback är inte
  debug-token utan att Malin länkar Play Console; tills dess fungerar webben.
- *Första gen2-deployen* → IAM-väntan, omgångar, smoke-gate röd mellan omgångarna (känt).
- *Apple-inloggningen bryts* → return-URL i Apple-portalen byts samma dag; testas i F8 på iOS
  om bygge finns, annars noteras som ej verifierat.
- *Återställning före ⑧:* gamla prod är orörd — `git revert` av hela commit-sekvensen
  (aldrig reset/force-push), miljövariablerna och hemlighetsnamnet tillbaka, Play Console
  länkas om (Malin-steg), nya projektet raderas (30 dagars ånger). `FIREBASE_SERVICE_ACCOUNT`
  finns kvar till ⑧ just för att den här vägen ska vara öppen.
  *Efter ⑧:* Googles 30-dagarsfönster; projektskalet kommer tillbaka, fungerande tjänst,
  Play-länk, Apple-return-URL och GA-egendom gör det inte med automatik.
- *Gamla installationer:* varje installerat prod-bygge är hårdbundet till gamla id:t och
  får fel (inte "uppdatera-meddelande") när projektet raderas. I dag bara Malins telefon;
  hanteras i fas 4.

### H — Acceptanskriterier (ärvda från BUT-451-panelen + nya efter körning)
Ärvda: egna `system/config`, Remote Config, App Check, LLM-tak per projekt; regioner
angivna; regler/index/funktioner från samma commit, en i taget; export/import-förbud
vaktat; TTL/scheduler-diff mot gamla; eget budgetlarm (inte cap); egna nycklar; App
Check-läge per projekt; kaskaden körs; admin-skript kräver `--project`; inga nya
biträden; ADR; minsta rättigheter; städpolicy.

Nya från panelen (alla invävda ovan, här som checklista):
- **Security:** låst läge + regler deployade före någon app-konfig (F15m); WIF-villkor
  pinnat på repo-id + miljö + gren med negativt test; `localhost` bort ur authorized
  domains; `ocr-url-validator` fail-closed (saknad env kastar, med test); Editor bort från
  default-kontona; alla API-nycklar begränsade inkl. den auto-skapade; pepper via stdin;
  App Check-enforcement **explicit beslutat** (kort), aldrig tyst nedärvt; `security.txt`
  med nytt Expires; regelsvit mot deployade regler.
- **Privacy:** `models/`-manifest med träningskälla, korrigeringstränade modeller byggs om;
  policy EN+SV + Art. 30 samma dag (Storage-region in, Realtime Database ut, ny
  policyadress); 4 testkonton raderas via kaskaden före projektraderingen, datum
  noteras; ADR-0032 avslutas.
- **DevOps:** inga variabel-/hemlighetsbyten i fas 1, nytt hemlighetsnamn, verify-dispatch
  först; Capture/rollback/vakt WIF-rena i alla sex workflows; seedning före
  onIngredient-triggers, schemafunktioner sist, larm efter första rena dygnet;
  F15 a–l; nyckel kvar till ⑧ + soak 7–14 d; rollback som `git revert`.
- **FinOps:** saknade kostnadsrader med; billingkonto-budget 150 kr; pausa gamla
  schemajobben vid verifierad ny; städpolicy + budgetar före första deployen;
  `aiEnabled: false` tills taken lästs; SMS-MFA-budgeten återskapas inte.
- **Release:** Play-länk som verifierat steg med Play-distribuerat bygge; versionCode-
  bump; assetlinks-cert (upload vs Play App Signing) avgjort och verifierat; iOS-listan
  (APNs .p8, Services-ID return-URL + domänverifiering, App Attest, dSYM, GIDClientID)
  uttryckligen "ej verifierat: inget iOS-bygge"; avinstallera + installera, aldrig
  uppdatering på plats; ingen butiksinlämning i fönstret.
- **Arkeologen:** rollback-steget undantaget under bring-up; retire-loopen gatad; inga
  taggar i fas 1–3; `models/` kopierad före bytet; literal-listan utökad + repo-vid grep
  som acceptans; morgonkoll-rutinen byts samma timme; `.env.<id>` före varje
  funktionsdeploy; bucketnamnet mätt innan kod rörs; prod-tvilling av
  `checkStagingTarget` för seed-skripten; vakttestet accepterar exakt ett prod-id.

### I — Det jag inte kunde kontrollera
- `functions/.env.butlery-app-1`:s innehåll (läsning nekad i sessionen); nyckelnamnen är
  tagna ur koden.
- Om `se.butlery.app` finns i Play Console (kort ③).
- Vad `_internal` och `butlery_archive` innehåller.
- Frankfurt-priser för PITR/backup/Storage; om hosting-sajtnamnen frigörs vid radering; om
  GA-egendomen följer med projektraderingen;
  hur en egen auth-domän påverkar Android-app-länkar.
- Om projekt-id:t är ledigt (syns först i skapandet).
- Om Malin har ett Google Play-utvecklarkonto (⑪); hur lång Googles identitetsverifiering
  tar.
- Var Auth, Analytics, Crashlytics, FCM, Remote Config och App Check lagrar data
  (globala tjänster; policyn säger redan "USA (DPF)").
- Om nyare Play Integrity-leverantören (doku-sidan säger numera "på eller utanför Play")
  skulle godkänna ett sidladdat bygge; stagingmätningen 2026-10-20 säger nej, och planen
  räknar med nej.
- `functions/.env.butlery-app-1` fick jag inte läsa; `models/`-filernas träningskälla är
  inte mätt (manifestet görs vid genomförandet).

## Linear (skapade 2026-10-20; alla blockerar BUT-2425)
- **BUT-2427** epic. Faser i ordning: **BUT-2428** fas 0.5 (staging), **BUT-2429** fas 1 (molnet),
  **BUT-2430** fas 2 (repot, stänger BUT-2421 och BUT-2420), **BUT-2431** fas 3 (första
  driftsättning), **BUT-2432** fas 4 (telefon + webb, App Check på, stänger BUT-1445),
  **BUT-2433** fas 5 (avveckling).
- Sidoärenden: **BUT-2434** Play Console + Play App Signing + freeRASP-hash; **BUT-2435**
  integritetspolicy + Art. 30 + policyadress; **BUT-2436** billingkonto-budget; **BUT-2437**
  `ocr-url-validator` fail-closed; **BUT-2438** cors-listorna till en delad konstant;
  **BUT-2439** egen auth-domän; **BUT-2440** dött `database`-block.
- Fas 6 = BUT-2425 själv. Inga befintliga ärenden ändrade; ingen `launch-gated`-etikett.

## Open questions
Sju kort ställda via AskUserQuestion 2026-10-20, alla besvarade och invävda i A:
projekt-id (`butlery-app`), domän nu (ja), Play Console (appen finns inte), App Check
(på efter F8), avveckling (bevis + 7–14 d soak), staging (bygg om först), signering
(Play App Signing). Inga arkitekturändrande okända kvar. Antaganden som genomförandet
avgör utan ny fråga: `butlery-prod` om `butlery-app` är taget; staging-bucketbyte
alternativ A före B (⑨); policyadress under `butlery.app` (D); varje "inte verifierat"
i I mäts i sin fas och skrivs in i Linear-ärendet.

---

## Vad det här betyder i vanligt språk
- Vi bygger en ny, tom "baksida" till Butlery (`butlery-app`, eller `butlery-prod` om
  namnet är taget) där alla databaser och filer — även bilderna — ligger i EU. Den
  gamla, där bilderna hamnade i USA, stängs när den nya står klar.
- Först görs samma sak på testmiljön som generalrepetition, så att varje fälla hittas
  där ett fel inte kostar något.
- Appen läggs upp hos Google Play som intern testversion, inte publikt — så passerar
  telefonen Googles äkthetskontroll. När din telefon och webben
  fungerar slås kontrollen på skarpt.
- Ingenting flyttas över utom sådant som inte är personuppgifter: ingredienslistan,
  taggregler, inställningar och appens egna modellfiler. Dina fyra testkonton raderas;
  du registrerar dig på nytt.
- På din telefon: avinstallera appen, installera nya versionen, logga in igen. På webben:
  butlery.app börjar peka på nya Butlery (du ändrar DNS-raderna hos domänleverantören).
- Risken: telefonen stoppas av äkthetskontrollen tills Google Play pekar på nya
  projektet — ditt klick, och vi mäter att det fungerar innan gamla stängs. Fel i
  driftsättningen stoppas av spärrarna. Allt kan ångras tills gamla raderas, och Google
  håller ett raderat projekt i 30 dagar.
- Kostnad: ungefär som i dag, ~30–40 kr i månaden när inget händer (uppskattning); några
  veckor med dubbel kostnad under bytet, med ett larm vid 150 kr.
- Du gör: säger ja till billingkopplingen, fyller i Googles samtyckesskärm och Apple-
  nycklarna, skapar Play-kontot och länkar det, ändrar två DNS-rader, godkänner
  driftsättningarna i GitHub. Resten kör jag.

---

## Genomförandesteg för DEN HÄR sessionen efter godkännande (briefens leverabler)
1. Skriv `tasks/new-prod-project-plan.md` = ovan, med panelens utfall och Malins kortsvar invävda.
2. Panelen är körd i planläget (läsning); logga review-eventet
   (`docs/org/metrics/log_event.py review …`) och skriv ADR för varje konflikt/villkorsbeslut
   i `docs/org/adr/ADR-0033-….md` + README-raden. **Committas av den här sessionen i ett
   eget commit direkt efter planfilens** (explicit pathspec: ADR-filen, README-raden och
   `events.jsonl` — den sistnämnda visar redan `M` i trädet från en annan session, så bara
   vår rad stagas med `git apply --cached` av en enradspatch, kontrollerad med
   `git diff --cached` före commit). Det andra commitet ligger inom uppdraget eftersom
   stakeholder-review-skillen kräver en ADR per konflikt och en loggad händelse.
3. `/review-plan tasks/new-prod-project-plan.md`; RÖDA åtgärdas, GULA till Malin.
4. Nya Linear-ärenden (inga befintliga ändras; länka BUT-451, BUT-2421, BUT-2420,
   BUT-1445, BUT-2425, och sätt varje nytt ärende som blocker av BUT-2425): epic "Ny
   produktionsmiljö i EU" + ett ärende per fas 0.5/1/2/3/4/5, plus: dött `database`-block
   i `firebase.json`; cors-listorna till en delad konstant; egen auth-domän;
   `ocr-url-validator` fail-closed; Play Console-app + Play App Signing + freeRASP-hash;
   privacy-policy + Art. 30 + ny policyadress; billingkonto-budget. Kostnadsbelopp märks
   "uppskattning". Play- och domänärendena får **inte** `launch-gated` (memory
   `feedback_no_store_submission_yet.md` ger den etiketten åt butiks-/domänärenden och
   håller dem ur sprintar; Malins beslut 2026-10-20 gör dem till blockers av BUT-2425).
5. Commit **enbart** planfilen till `main` (tasks/*.md är gitignorerat → `git add -f`
   bara den filen; explicit pathspec, samma Bash-anrop som commit; de två andra
   sessionerna i trädet meddelas).
6. Rapport till Malin: svar först, kort, korten som redan ställts sammanfattade.
