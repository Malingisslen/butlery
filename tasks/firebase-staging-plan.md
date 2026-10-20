# Plan: BUT-451 — separat Firebase-testprojekt (staging)

## Context

Butlery körs mot Firebase-projektet `butlery-app-1`. Varje regelbyte, funktionsdriftsättning
och test mot riktiga tjänster träffar den databas som den slutna testgruppen (Android först)
kommer att använda. Målet är ett andra projekt, `butlery-app-staging`, där vi provar allt
först — så att testgruppen aldrig drabbas av våra misstag.

Det här är **bara en plan** (BUT-451). Ingen appkod, inga regler, inga Firebase-/GCP-inställningar
ändras och inget driftsätts av den. Genomförandet sker i egna sessioner, fas för fas, efter Malins ja i fas 0.

### Vad kartläggningen visade (mätt mot `origin/main` 210fea435, 2026-10-20)

- `.firebaserc` har ett tomt `projects`-block; bara hosting-mål under nyckeln `butlery-app-1`. Inget alias.
- `butlery-app-1` är hårdkodat i 34 filer utanför `docs/`, `tasks/` och `.claude/` (`git grep -c`, 81 träffar). Tyngst: `lib/firebase_options.dart`, `deploy-firebase.yml` (10 träffar), `firebase.json`, `deploy-hosting.yml`, `AndroidManifest.xml:125` (auth-länkvärd `butlery-app-1.firebaseapp.com`), `lib/models/auth/password_reset_link.dart`, tre admin-skript i `functions/src/admin/`.
- Appen läser miljö via `--dart-define-from-file=.env` (CI skapar `.env` från secrets; filen finns inte i repot). Enda miljöväxeln är `USE_FIREBASE_EMULATOR` (webb, `demo-butlery`, `lib/core/bootstrap/emulator_bootstrap.dart`). Ett `lib/main.dart`, inga flavors. Historik: 1f72b4507 → 0fc3a2491 (mars 2026) gick **från** dart-define **till** hårdkodade FlutterFire-options för att `flutter run` ska fungera utan flaggor — en ny växel måste därför ha prod som flagglöst default.
- Android: `applicationId = se.butlery.app`, inga productFlavors, `google-services.json` gitignorerad och avkodad från `GOOGLE_SERVICES_JSON_BASE64` i `build-validation.yml:242` **och** `emulator-lane.yml:100`. Upload-nyckeln lokalt + i secrets (`KEYSTORE_*`).
- freeRASP pinnar upload-nyckelns SHA-256 i `lib/services/device_integrity_service.dart:32`. App Check "Unenforced" (BUT-1445); webb-reCAPTCHA-nyckel hårdkodad i `main.dart:127`. Google-inloggning tar `serverClientId` från `google-services.json`/`GOOGLE_SERVER_CLIENT_ID`. Apple-inloggning behövs inte för Android.
- Cloud Functions: 105 funktioner i prod (europe-west1, `gcloud functions list`), 17 schemalagda jobb, tre secrets (`FEEDBACK_EMAIL_API_KEY`, `IDENTITY_TOOLKIT_API_KEY`, `MFA_RECOVERY_PEPPER`), LLM via Vertex AI (`location eu`, `gemini-2.5-flash-lite`) utan nyckel. Funktionernas env-variabler läses ur `functions/.env.butlery-app-1` (lokal, ignorerad av `*.env.*` i root-`.gitignore`; **skapas inte i CI**). `IDENTITY_TOOLKIT_API_KEY` kommer från en repo-**variabel** (56cb68cb3).
- Firestore: data i **europe-west3**, compute i **europe-west1** (`docs/ops/backups.md`); `firestore.indexes.json` 119 poster (65 composite + 54 field overrides), 28 TTL-poster; `firestore.rules` 4624 rader; regeltester mot emulatorn (`demo-test`), aldrig mot riktigt projekt.
- CI: `deploy-firebase.yml` (dispatch eller tagg `v*`), auth med den långlivade nyckeln `FIREBASE_SERVICE_ACCOUNT` som är **repo-hemlighet** (synlig för varje jobb), `environment: production`. **GitHub-miljön `production` har inga skyddsregler och ingen grenpolicy** (`gh api …/environments/production` → `protection_rules: []`, `deployment_branch_policy: null`), inga miljöhemligheter (`gh secret list --env production` tom), trots att workflow-huvudet antar en manuell grind. Alla 15 senaste deployer är manuella dispatcher; ingen `v*`-tagg finns; GitHub-egna actions tagg-pinnade enligt BUT-790:s policy.
- E2E: `tier: [mock, emulator]`; "staging" är en kommentar (`e2e_tests.yml:54`); `scripts/run_e2e_tests.sh` kan bara de två.
- Repot är **publikt** → Actions-minuter gratis; projekt-id:n är inte hemliga; men en APK-artefakt kan laddas ner av vem som helst som är inloggad på GitHub.
- Malins konto äger billingkontot `018435-3E1A9A-121048`; `butlery-app-1` ligger **utan organisation** (ingen org-policy mot SA-nycklar). Inget staging-projekt finns.
- Firestore-regionen motsägs i `ROLE_RESPONSIBILITY_MAP.md` (europe-west1 på ett ställe, europe-west3 på två) mot `backups.md` (europe-west3, mätt mot GCP) — planen följer backups.md.

### Stakeholder-panel (körd 2026-10-20, Malins val)

`tools/stakeholder_router.py --json` → **full-panel** (high-stakes: `firestore.rules`, `storage.rules`). Seatade: DevOps/SRE, Security Architect, Privacy/DPO, FinOps, QA, plus Codebase Archaeologist. Släppta (ingen egen insats i blast-radius): Legal (DPO täcker biträdesfrågan), Product Manager (testgruppsvalet är Malins, se ①), Support, Trust & Safety, Performance, Vendor (Algolia-nyckeln är ett FinOps-villkor), Release Manager och App-Store Compliance (deploy-grinden hamnar hos DevOps; staging-bygget går inte till butiken), DBA (region/TTL ligger redan som villkor), Software Architect (inget i dossiern).

**Utfall: 5 × godkänn-med-villkor, 0 block.** Villkoren är invävda nedan (markerade *[panel]*). En rollkonflikt (FinOps vill pausa schemajobben i staging; Privacy/QA vill ha paritet med prod) löstes med prioritetsordningen privacy > kostnad: **alla 17 jobb speglas**, kostnaden uppskattas till ~17 kr/mån (omätt, se E). En tolkningsfråga (Malins riktiga Google-konto i staging) eskalerades till Malin — **beslut: riktiga kontot**, staging skrivs in i Art. 30-registret. Båda skrivs som ADR i `docs/org/adr/` i genomförandesessionen (fas 2), eftersom detta PR enligt uppdraget bara får innehålla planfilen.

---

## Planen

### A — Vägval (där Malins omdöme spelar roll)

① **Vem använder staging? — Beslutat (Malin 2026-10-20):** testgruppen kör mot **produktion**; staging är vårt labb där regler och funktioner provas innan de når testarna. *Alternativ som valdes bort:* testarna på staging — skyddar dem inte.

② **Egen app-identitet för staging.** *Rekommendation:* Android-flavor `staging` med paket-id `se.butlery.app.staging`, så prod- och staging-appen ligger **sida vid sida** på Malins telefon, med en synlig banderoll "STAGING". *Kostnad:* ny OAuth-klient, SHA-registrering, och auth-länkvärden i manifestet samt `password_reset_link.dart` måste parametriseras per flavor; app-länkar (`assetlinks.json`) fungerar inte för `.staging` — accepterat, staging-appen öppnar inga delningslänkar. *Alternativ:* samma paket-id → bara en app får plats på telefonen; sparar ingenting i konsolen. Säg "samma paket-id" för att byta.

③ **Vad driftsätts automatiskt?** *Rekommendation:* vid varje push till `main` går **regler, index, storage- och database-regler** till staging, **beroende av att `firestore-rules.yml` är grön** (`workflow_run`), egen concurrency-grupp utan `cancel-in-progress` *[panel: QA, DevOps]*. **Funktioner** driftsätts med samma knapp som prod men med miljöval (`staging`/`production`). Produktion förblir manuell **och** får en riktig godkännandegrind (krävd granskare = Malin, grenpolicy = bara `main`). *Alternativ:* allt manuellt → staging driver iväg från `main`. Säg "funktioner automatiskt" om varje push även ska driftsätta ändrade funktioner (~90 s/funktion enligt `deploy-firebase.yml`:s huvudkommentar, inte nymätt).

④ **Hur CI loggar in i staging. — Ändrat efter panelen:** **Workload Identity Federation** (kortlivade tokens, ingen lagrad nyckel) med en **egen pool i staging-projektet** och ett servicekonto med **minsta rättigheter** (rules/indexes/functions/storage **+ `secretmanager.viewer`**, luckan prod-kontot hade — metadata, aldrig innehåll; ingen roll i `butlery-app-1`) *[panel: Security, DevOps]*. Produktionens befintliga nyckel byts till WIF i eget ärende (BUT-2421). *Alternativ:* SA-nyckel som miljöhemlighet, samma form som prod — en dag snabbare, men en andra långlivad nyckel. Säg "nyckel som i prod" för att byta.

⑤ **Produktion härdas först** *[panel: unanimt]*. Innan en enda staging-resurs skapas: (a) `FIREBASE_SERVICE_ACCOUNT`, `KEYSTORE_*` och variabeln `IDENTITY_TOOLKIT_API_KEY` flyttas från repo-nivå till miljön `production`; (b) krävd granskare (Malin) + grenpolicy `main` på `production`; (c) prod-nyckeln **roteras** (den har legat som repo-hemlighet i ett publikt repo); (d) `cancel-in-progress: false` i `deploy-firebase.yml`. Bevisas med `gh api` + en riktig prod-dispatch med `target=rules` (ofarlig, samma regler) som Malin godkänner i grinden. *Alternativ:* hoppa över → "staging kan inte nå prod" är då **falskt**, repo-hemligheter syns för alla jobb.

⑥ **Region och spegling.** Staging speglar prod: Firestore europe-west3, compute europe-west1, samma regler/index/TTL, **alla 17 schemajobb** (paritet för raderingskaskad och gallring; ~17 kr/mån, uppskattning enligt E). **Ingen** PITR, **inga** backuper.

⑦ **Kostnadstak** *[panel: FinOps, Security]*. Budgetlarm vid 50/100/200 % av 300 kr (larmet stoppar inget — det sägs rakt ut), LLM-tak i stagings `system/config` **och** kontroll i koden att callables faktiskt vägrar när taket är nått (bevis F6), Vertex-kvot per projekt, API-nyckel begränsad till paket `se.butlery.app.staging` + SHA, Artifact Registry-städpolicy (behåll 2 versioner), tear-down-regel: > 100 kr/mån två månader i rad → skala ner eller radera.

⑧ **Malins konto i staging — Beslutat (Malin 2026-10-20): riktiga Google-kontot.** Konsekvens: staging håller en verklig persons uppgifter och skrivs in i Art. 30-registret med gallring (samma TTL som prod) och radering (kaskaden körs i staging, bevis F11). Analytics/Crashlytics stängs av i staging-flavorn så inga enhets-id:n hamnar utanför policyns räckvidd. Övriga konton är syntetiska `test+N@butlery.se`.

**Svagaste punkten:** ② — flavor, `google-services.json` per flavor i **två** CI-workflows, manifestvärd, Google-inloggning, freeRASP och App Check på ett nytt paket-id. Bevisen F3/F12 täcker varje del. Stagingbyggen signeras med **upload-nyckeln** i CI (freeRASP-hashen oförändrad; nedtecknat beslut, med exponeringen: artefakten bär prod-signaturen → kort retention, dispatch-only, bara från `main`).

### B — Byggordning

**Fas 0 — Beslut (Malin, ~10 min).** ②–⑦ (①, ⑧ beslutade). Godkänn att projektet kopplas till befintligt billingkonto (Blaze). Inget körs före det.

**Fas 1a — Härda produktion (⑤).** Claude kör `gh secret set --env production` m.m. med Malins `gh`-inloggning; Malin godkänner prod-dispatchen i grinden. Verifieras innan fas 1b.

**Fas 1b — Molnet (Claude via CLI med Malins inloggning; Malin bara där det står).**
1. `firebase projects:create butlery-app-staging` → billing (`gcloud billing projects link`, **Malin säger ja i chatten först**).
2. API:er: Firestore, Functions/Run/Build, Artifact Registry (+ städpolicy), Secret Manager, Scheduler, Eventarc, Pub/Sub, Vertex AI, Identity Toolkit. Vänta in service-agenternas IAM (första gen2-deployen misslyckas annars en gång) *[arkeolog]*.
3. Firestore i europe-west3; Storage-bucket; Realtime Database.
4. Auth: e-post/lösenord + Google. **Malin:** OAuth-samtyckesskärm (External/Testing; tokens går ut efter 7 dagar enligt Googles dokumentation, ej mätt — accepterat). Claude registrerar Android-appen `se.butlery.app.staging` + SHA för upload- och debug-nyckel (`firebase apps:android:sha:create`). Registrering stängd utom för seedade konton + Malins (blocking function eller allowlist) *[panel: Security]*.
5. App Check: egen app-registrering, debug-token (**Malin eller Claude i webbläsaren**). Läge "Unenforced" som prod; spåras per projekt i ADR.
6. Secret Manager: nytt slumpat `MFA_RECOVERY_PEPPER`, stagings egen webb-API-nyckel som `IDENTITY_TOOLKIT_API_KEY`, `FEEDBACK_EMAIL_API_KEY` **tom** → mejl hoppas över (kodens eget fallback; ingen mejl till riktiga adresser). `functions/.env.butlery-app-staging` skapas lokalt + i CI-steget *[arkeolog]*.
7. `system/config` med lågt LLM-tak, Remote Config (`ai_enabled`, `llm_parser_enabled`), budgetlarm (⑦) till Malins e-post, Vertex-kvot, verifierat att `gemini-2.5-flash-lite` finns i `eu` för projektet (ingen tyst fallback till dyrare modell) *[panel: FinOps]*.
8. WIF-pool + provider i staging-projektet, servicekonto med minsta rättigheter (inkl. `secretmanager.viewer`; innehållsläsning bara för funktionernas runtime-konto); GitHub-miljön `staging` (grenpolicy `main`) med `vars.FIREBASE_PROJECT_ID`, WIF-variabler, `GOOGLE_SERVICES_JSON_STAGING_BASE64`.

**Fas 2 — Repot (Claude; vanliga grindar; plan finns; ADR skrivs här).**
- `.firebaserc`: alias `production`/`staging`, **inget default**; `targets`-block även för staging-id:t så `firebase use staging` + `--only` fungerar; bara `--only`-deployer i workflows.
- Android: productFlavors `prod` (default) och `staging` (`applicationIdSuffix ".staging"`, `versionNameSuffix "-staging"`, `manifestPlaceholders` för auth-länkvärden); `google-services.json` flyttas till `src/prod/` + `src/staging/`; **båda** avkodningsstegen (`build-validation.yml:239-243`, `emulator-lane.yml:98-101`) och alla `flutter build`-anrop får `--flavor prod`; artefaktsökvägar uppdateras *[arkeolog]*.
- Dart: `lib/firebase_options_staging.dart` (`flutterfire configure --project=butlery-app-staging --out=…`); `lib/core/bootstrap/firebase_env.dart` som läser `--dart-define=ENV`: tomt → prod, `staging` → staging, annat → **kastar**; emulator vinner över staging (komponerar med `EmulatorBootstrap.options(base)`); `password_reset_link.dart` tar värden från samma källa; banderoll "STAGING" (byggetikett, inte l10n — ingen användare ser den; konstant i `firebase_env.dart`), Analytics/Crashlytics av i staging. Lefthooks secret-scan-undantag vidgas till `firebase_options*.dart`. Skiss:
  ```
  ┌──────────────────────────────┐
  │ ▌STAGING · butlery-app-staging│  ← 1 rad, varningsfärg från temat, ovanför AppBar
  ├──────────────────────────────┤
  │  (appen som vanligt)         │
  ```
- CI: `deploy-firebase.yml` får `environment`-input; **varje** förekomst av projekt-id (PROJECT=, `--project`, retire-loopen med `functions:delete --force`, smoke-gate, TTL-listning, rollback, summary) från `vars.FIREBASE_PROJECT_ID`; retire-loopen körs **bara** i production; vaktsteg **före första muterande steg**: `firebase use <alias>` == `vars.FIREBASE_PROJECT_ID` == projektet i WIF-token, annars stopp; steg "assert no production secret" (`FIREBASE_SERVICE_ACCOUNT` tom i staging-jobbet). Ny `deploy-staging-rules.yml` (push till `main` på regel-/indexfiler, `workflow_run` på grön `firestore-rules.yml`, egen concurrency, väntar tills index är READY före funktioner). Ny `build-staging-apk.yml` (dispatch-only, bara `main`, upload-signerad, artefakt-retention 3 dagar). `main-health-alert.yml` får de två nya workflowsna i sin lista. Tredjepartsactions i nya workflows SHA-pinnas (BUT-790:s policy; GitHub-egna tagg-pinnas).
- Vakttest i `functions/src/__tests__/deploy-manifest.test.ts` (den familjen; `functions/src/__tests__/ci/` finns inte): parsar workflow-YAML och vägrar varje `butlery-app-1`-literal och varje `--project` som inte är env-härledd; `.firebaserc` måste ha båda aliasen; emulator-workflows får inte nämna staging-id:t. Registreras i `check-test-registration.js`. `_dart-guard-triggers.ts` läses innan testet läggs till.
- Seed: `functions/scripts/seed-staging.js` — kräver `--project`, exakt match `butlery-app-staging`, vägrar tomt/`butlery-app-1`/`demo-*`/ADC-genomfall, kontrollen **före** `admin.initializeApp`; seedar ingredienser + tag-configs + 3 syntetiska konton med `ageCompliant`-claim via Auth Admin. Eget enhetstest. `seed-emulator.js` orörd.
- Admin-skript (`admin-init.ts`, `sync-ingredients.ts`, `seed-tag-configs.ts`, `reset-user-data.ts` + runbook) kräver explicit `--project` **innan staging tas i drift** (BUT-2419 blir förutsättning, inte uppföljning) *[panel: Security, Privacy]*.
- Export-förbud: inga Firestore-export/import/restore mellan projekten i någon riktning — regel i `docs/ops/staging.md` + vakttest som vägrar workflows/skript som nämner båda id:n i export-kontext *[panel: Privacy]*.
- Docs: `docs/ops/staging.md` (driftsinstruktion: ordningen staging → bevis → prod, checklista över konsolinställningar som måste hållas i synk, tear-down-regel, "deploy bara via CLI, verifiera på resursen"; pekas ut från `local-emulator.md`, `backups.md` ("staging avsiktligt utan backup"), `functions/RUNBOOK.md` och workflow-huvudet). ADR i `docs/org/adr/`: upload-nyckel + artefaktexponering, App Check-läge, öppen/stängd registrering, miljöbundna hemligheter, schemajobbs-paritet, Malins riktiga konto + Art. 30-rad. `workflow-map.stale` hanteras enligt CLAUDE.md.
- Tester: `test/unit/core/bootstrap/firebase_env_test.dart` (ingen ENV → prod-id; `staging` → staging-id; okänt → kastar; emulator + staging → emulator vinner), seed-guardens test, vakttestet. `flutter analyze --fatal-infos` + full unit/widget-svit gröna med `prod` som default-flavor; prod-APK:ns signatur oförändrad (bevis F12).

**Fas 3 — Första driftsättning + bevis (del F).** Bara via Firebase CLI, aldrig MCP-verktyget `firebase_deploy` (tyst no-op, se minnet), och varje deploy verifieras på resursen. Regler, index (vänta READY), storage, funktioner (en i taget, i omgångar; kvoten i nytt projekt mäts först — `NOT_ENOUGH_USAGE_HISTORY` kan hindra höjning). Bevisen F1–F12 körs; F1–F5, F10 paketeras som en `workflow_dispatch`-smokejobb så de kan köras om *[panel: QA]*.

**Fas 4 — Senare, egna ärenden.** E2E-lane mot staging; iOS-flavor + Apple-inloggning; WIF för prod.

### C — Mekaniskt (inga beslut)
Gitignore-rader, secret-/variabelnamn, workflow-huvudkommentarer, lint-fixar.

### D — Dataseparation
- Staging: syntetiska konton + Malins (⑧). Seed vägrar allt utom staging; admin-skript kräver `--project`; export/import mellan projekten förbjudet och vaktat.
- Inga prod-nycklar i staging: egna secrets, egen WIF-identitet utan roller i prod, egen `google-services.json`, tom Resend-nyckel, egna App Check-nycklar; prod-hemligheter bara i miljön `production`.
- Samma biträden (Vertex EU, OCR.space, Algolia EU-index med syntetisk input) — inga nya; Resend används inte i staging. Art. 30-rad för staging.

### E — Kostnad (uppskattning, **inte mätt** — listpriser ur minnet; läses av i GCP:s priskalkylator innan belopp skrivs i Linear)
- Vilande: Scheduler 17 jobb (frikvoten på 3 är **per billingkonto** och redan använd av prod) ≈ 17 kr; Artifact Registry ~20 GB bilder (uppskattning) ≈ 10–25 kr med städpolicy; Secret Manager ≈ 2 kr; Run/Functions vid 0 trafik ≈ 0; Firestore ≈ 0–5 kr → **≈ 30–50 kr/mån**.
- Aktiv testning: LLM några hundra parsningar ≈ 5–30 kr; Cloud Build inom frikvot → **≈ 50–100 kr/mån** realistiskt tak. Actions gratis (publikt repo).
- Mätt: 105 funktioner, 17 jobb, region, repo-synlighet, billingkonto.

### F — Bevis att det fungerar (konkreta kontroller)
1. `firebase use staging` → `butlery-app-staging`; `firebase use production` → `butlery-app-1`; `firebase use` utan alias → fel.
2. Vakttestet grönt; dispatch `environment=staging` loggar `FIREBASE_PROJECT_ID=butlery-app-staging`, WIF-tokenets projekt matchar, "assert no production secret" grönt, en funktion med `defineSecret` driftsätts utan IAM-fel; en dispatch från en annan gren än `main` vägras av grenpolicyn.
3. Staging-APK **bredvid** prod-appen på Malins telefon; banderollen syns; Google-inloggning lyckas; ett recept syns i stagings Firestore och **inte** i prod (dokumentantal före/efter i båda).
4. `firestore_get_rules` (Firebase MCP) på båda projekten efter en avsiktlig testregeländring: staging ny, prod gammal; ändringen backas.
5. `gcloud firestore fields ttls list` + `gcloud scheduler jobs list` i staging **diffas** mot prod — identiska.
6. `structureRecipe` i staging går via Vertex (`gemini-2.5-flash-lite`, `eu`); taket i `system/config` sätts till 1 och nästa anrop **vägras**.
7. `firebase auth:export` från staging innehåller bara `test+N@butlery.se` + Malins konto.
8. `gcloud billing budgets list` visar larmet; Artifact Registry-städpolicyn finns.
9. Produktion oförändrad: en prod-dispatch med `target=rules` (Malin godkänner) kör samma steg som senaste gröna prod-körning (diff av jobblogg).
10. `firestore-rules.yml` grön; `deploy-staging-rules.yml` väntar på den.
11. Raderingskaskaden: ett syntetiskt konto raderas i staging, probe-legs rena.
12. `flutter build appbundle --flavor prod` ger samma paket-id, samma signatur (`apksigner verify --print-certs`) som före; `flutter analyze --fatal-infos` och unit/widget-sviterna gröna.

### G — Risker och återställning
- *Fel projekt vid deploy:* miljöbundna hemligheter (efter ⑤) + WIF-identitet utan prod-roller + vaktsteg + vakttest + inget default-alias.
- *Ofullständig parametrisering av `deploy-firebase.yml`* (inkl. `--force`-retire-loop och rollback): vakttestet vägrar literaler; retire-loopen bara i prod.
- *Flavor bryter prod-bygget:* bevis F12 före merge; `--flavor prod` i alla bygg-anrop.
- *Första gen2-deployen i nytt projekt:* IAM-propagering, kvot — mäts före; körs i omgångar (105 × ~90 s ≈ 2,5 h, uppskattning).
- *Konsolinställningar driver isär:* checklista i `docs/ops/staging.md`; smokejobb F1–F5.
- *Prod-härdningen (⑤) görs fel → prod-deploy bryts:* varje steg bevisas med `gh api` + ofarlig rules-dispatch innan nästa.
- *Återställning:* ta bort GitHub-miljön `staging`, `gcloud projects delete butlery-app-staging` (30 dagars ånger), återställ commits. ⑤ behålls (ren förbättring).

### H — Acceptanskriterier från stakeholder-routern (full-panel, körd)
Ur dossierer + körd panel: egna `system/config`, Remote Config, App Check, LLM-tak per projekt (kodverifierat); regioner angivna; regler/index/funktioner från samma commit, en i taget; emulatorsviterna gatar staging-deployen; bara syntetisk data + Malins konto (Art. 30); export/import-förbud vaktat; egen TTL/scheduler-diff mot prod; eget budgetlarm (ej cap — sagt); larm inte till `info@butlery.se`; egna nycklar + nedtecknat upload-nyckelbeslut med artefaktexponering; App Check-läge per projekt; ③ beslutat av Malin; kaskaden körs i staging; inga flaggor med öppna juridiska grindar flippas; inga backuper ersätter prod-övningar; backfills körs inte av misstag; reset/admin-skript kräver `--project`; inga nya biträden; ADR; prod härdad först; minsta rättigheter; API-nyckel begränsad; städpolicy; tear-down-regel; repeterbart smokejobb; enhetstester för env-växel och seed-guard.

### I — Det jag inte kunde kontrollera
- `functions/.env.butlery-app-1` (läsning nekad). Prod-funktionen `onFeedbackCreated` **har** adresserna satta (`gcloud functions describe`, uppdaterad 2026-09-15) men CI skapar inte filen — mekanismen är oklar → BUT-2420.
- Om `production`-miljöns tomma skydd är avsiktligt (Malin).
- Prispunkterna i E (ej avlästa; FinOps-kritikern fick heller inga siffror ur prissidorna).
- Hur freeRASP reagerar på ett debug-signerat staging-bygge (undviks via upload-signering).
- Cloud Run-kvoten i ett nytt projekt (mäts i fas 1b).

### Open questions (Öppna frågor)
Frågor ställda via AskUserQuestion, i blast-radius-ordning, svaren invävda: (1) vem kör mot staging → ① testarna på prod; (2) Malins riktiga Google-konto i staging → ⑧ ja, Art. 30-rad; (3) stakeholder-panel nu eller senare → körd nu.
No architecture-changing unknowns — assumptions: prod-regionerna (europe-west3/west1) står; Blaze på samma billingkonto; Android först, iOS i fas 4.

### Vad det här betyder i vanligt språk
- Vi får en andra, tom kopia av Butlerys "baksida" där vi testar ändringar innan de når testgruppen. Testgruppen märker inget — utom färre buggar.
- På din telefon kan du ha två appar: den vanliga och en märkt "STAGING". Du loggar in i den med ditt vanliga Google-konto; därför bokförs testkopian som en plats där dina uppgifter finns, med samma gallring som i riktiga appen.
- Riktiga användares data kopieras aldrig in i testkopian, och vi bygger spärrar så det inte kan ske av misstag.
- Först städar vi riktiga appens driftsättning: lösenordet till den flyttas dit bara riktiga driftsättningar kommer åt det, byts ut, och varje driftsättning kräver ditt ja — i dag saknas den spärren fast vi trodde den fanns.
- Kostnad: ungefär en kaffe i månaden när testkopian står stilla, ett par när vi testar aktivt — siffrorna är en uppskattning tills jag läst av Googles prislista; larm om det sticker iväg, och en regel att vi stänger den om den kostar för mycket två månader i rad.
- Kan ångras: ta bort testprojektet och backa ändringen; städningen av riktiga appens driftsättning behåller vi.
- Det du gör: säger ja till vägvalen, godkänner faktureringskopplingen, godkänner en ofarlig driftsättning i GitHub-grinden, fyller i Googles samtyckesskärm. Resten kör jag.

---

## Nya Linear-ärenden (skapade 2026-10-20; dubblettsök gjord)

Sökningar: "staging", "required reviewers", "Workload Identity", "GitHub Environment", "service account JSON", "release tag deploy", "sync-ingredients", "hardcoded project", "cancel-in-progress", "main-health-alert", "freeRASP", "App Check enforce", ".env", "infrastructure report", "SHA-pin", "Art. 30", "LLM cap server-side". Relaterade, inte dubbletter: BUT-420, BUT-1445, BUT-731, BUT-1240, BUT-1655.

1. **BUT-2416** — **Produktionens driftsättning saknar grinden den antar: inga godkännare, ingen grenpolicy, och nyckeln ligger synlig för alla jobb** (High, backend, security). Orsak: `protection_rules: []`, `deployment_branch_policy: null`, `FIREBASE_SERVICE_ACCOUNT`/`KEYSTORE_*` är repo-hemligheter i ett publikt repo. Påverkan: vilket jobb som helst kan läsa prod-nyckeln; dispatch utan paus. Förslag: flytta till miljöhemligheter, krävd granskare, grenpolicy `main`, rotera nyckeln (= fas 1a).
2. **BUT-2417** — **Release-flödet taggar med `GITHUB_TOKEN`, så taggen startar troligen aldrig Firebase-deployen** (Medium, backend). Ingen `v*`-tagg finns; flödet har aldrig körts.
3. **BUT-2418** — **Deploy-flödet avbryter en pågående deploy när en ny startas** (Medium, backend). `cancel-in-progress: true` mot huvudets egen varning.
4. **BUT-2419** — **Admin- och reset-skript hårdkodar eller ärver produktionsprojektet** (`admin-init.ts`, `sync-ingredients.ts`, `seed-tag-configs.ts`, `reset-user-data.ts` + runbook) (High — förutsättning för staging, backend). Förslag: kräv `--project`, vägra utan.
5. **BUT-2420** — **Feedback-mejlens adresser finns bara i en lokal fil som CI-deployen inte har** (Medium, backend). Mät före/efter nästa CI-deploy av `onFeedbackCreated`.
6. **BUT-2421** — **Byt långlivad servicekontonyckel i CI mot Workload Identity Federation (prod)** (Medium, security). Poolmönstret finns i `golden-llm.yml`.
7. **BUT-2422** — **`main-health-alert` ser bara körningar på `main`** (Low, backend). Tagg-triggade och staging-deployer faller utanför.
8. **BUT-2423** — **Rollkartan motsäger sig själv om Firestore-regionen** (Low, tech-debt). Rad 186 vs 326/331 och `backups.md`.
9. **BUT-2424** — **E2E-tester mot staging-projektet** (Low, test-gap). Följdärende till BUT-451.
*Inte ärende:* SHA-pinning av `actions/checkout` m.fl. i deploy-workflows — BUT-790 avgränsade pinningen till fyra tredjepartsactions; GitHub-egna actions är tagg-pinnade enligt policy (`tools/check_action_pinning.sh:8-10`). Panelens villkor om SHA-pinning faller därmed bort.

---
