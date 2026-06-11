# Sprint Backlog

## Sprint: GDPR-export + CF-integrationstester + fail-close + multi-dag-meny — 2026-06-11 (iter-140)

### Agent A: cook-events follow-ups (BUT-1235 + BUT-1236) — RISK-GATED (1235: security)
- [x] **A1. Exportera recipe_cook_events i GDPR-dataexporten** `[Tier A]` — DONE (3/3 kriterier, fbs clean; orderBy-determinism + _requireSelf-extraktion ur review) — `CookEventRepository.exportCookEventsByUser(userId, {limit})` (validateOwnership-guard, raw `{id,data}`-maps per etablerat kontrakt) + wiring i `content_export_manager.dart` bredvid cook_snaps (ExportPaginationHelper-limit). (BUT-1235)
  - Acceptance: ägarens export innehåller seedade cook events i `{id,data}`-form · främmande användares export nekas/tom (testpinnat) · cascade-beteendet oförändrat (befintliga 7 GDPR-tester gröna)
- [x] **A2. Ta bort död incrementCookCount + uppdatera academy** `[Tier A]` — DONE (3/3 kriterier; signed-out-branch testpinnad ur review) — bort från interface + impl (addIncrementCookCountToBatch kvarstår som enda väg); gaps-testgruppen tas bort/omriktas; academy-passagen (html + dossier) skrivs om kring logCookEvent. (BUT-1236)
  - Acceptance: grep visar noll incrementCookCount-referenser i lib/ · analyze + tester gröna · academy beskriver batch-vägen, inte den döda metoden

### Agent B: CF-integrationstester (BUT-839) `[Tier A]`
- [x] **B1. moderateUpload + syncConversationLastMessage end-to-end på emulator** — DONE (4/4 kriterier; CloudFunction.run(event) mot riktiga handlers, 6/6+4/4 lokalt; delad integration-gate.ts ur review) — följ `request-account-deletion.integration.test.ts`-mönstret; `test:integration:*`-scripts; Storage+Firestore-emulator (lanen i firestore-rules.yml startar redan båda). Fixa den missvisande headerkommentaren i sync-conversation-last-message.test.ts:4-5. (BUT-839)
  - Acceptance: JPEG behålls + ingen audit-rad; SVG-som-jpeg raderas + audit_logs-rad `storage_upload_rejected` · write→lastMessage uppdateras; edit→preview refresh (>=-precedens); delete senaste→recompute · wired i package.json + CI-lanen · headerkommentaren rättad

### Agent C: modellintegritet fail-close (BUT-877) — RISK-GATED (security)
- [x] **C1. Flippa unverified-branchen till fail-close** `[Tier A]` — DONE (4/4 kriterier; fallback-kedjan verifierad: NER→CRF+LLM, classifier→rule-based; CI-check re-scopad → BUT-1239, CRF-gap → BUT-1238) — `remote_model_loader.dart` unverified → `return false`; soft-allow-testerna skrivs om till fail-close-kontrakt; `_expected_model_hashes.dart`-doc uppdateras. Deferral-skälet (koordinerad klientrelease) är borta — appen är osläppt. CI-check mot Storage latest_version.txt: re-scopea om creds saknas (follow-up i så fall). (BUT-877)
  - Acceptance: unverified-branch returnerar false (testpinnat) · mismatch fortsatt false · verifierad fallback-väg: fail-close strandar inte parsern (bundlad modell/graceful degradation — verifieras i Step 0) · doc-kommentaren beskriver nya kontraktet

### Agent D: multi-dag-tillägg (BUT-999) `[Tier B]`
- [x] **D1. Lägg recept på flera dagar/slots i EN action** — DONE (4/4 kriterier; preview-HTML sparad, screenshot nekad i Chrome → In-Review refererar HTML-sökvägen) — multi-select dag/slot-picker på receptdetalj; ny servicemetod (ett recept → List<(day,slot)>) som speglar bulkAssignRecipes med EN batchad save. (BUT-999)
  - Acceptance: flera dag/slot-kombinationer kan väljas och bekräftas i en action · en (1) batchad save (inte N) · singel-dag-flödet oförändrat (regression) · HTML-preview + screenshot → In Review

### Needs you (Tier D — flagged, not worked)
- BUT-1229 — backfill→rules-deploy-ordning väntar (oförändrat)

### Post-Sprint Steps
- [x] dart analyze rent · alla sviter gröna (Flutter 72+ berörda, TS 10/10 integration, tsc clean) · Tier-2: 6 reviewers + 4 graders + /code-review high 7-vinklar (inga blockers; konsolideringar applicerade: _requireSelf, SlotTarget→modell, integration-gate.ts, döda guards) · Phase 2.7: 18/18 kriterier PASS · follow-ups FÖRE commit: BUT-1238 + BUT-1239 · commits per ticket · push · Linear: 1235/1236/839/877→Done, 999→In Review + notify

---
## ARCHIVED — iter-139 (BUT-838/694/1234 Done, BUT-1149 ärligt ej höjd, follow-ups BUT-1235/1236)

## Sprint: cook-events + PII-NER + 956-robusthet + coverage-golv — 2026-06-11 (iter-139)

### Agent A: recipe_cook_events (BUT-838) `[Tier A]` — RISK-GATED (multi-modul; design i ticketen)
- [x] **A1. Riktig cook-event-logg ersätter distinct-recipe-proxyn** `[Tier A]` — DONE via flutter-developer: recipe_cook_events/{uid}/events/{id} (ticketens path ej Firestore-giltig, dokumenterad deviation), atomär batch via addIncrementCookCountToBatch, .count()-aggregat (auto-index räcker — ingen composite), append-only rules; marquee-testet pinnat (3 cook → habitual); 44+28 tester. Cascade-formen matchar cf-agentens listCollections-discovery. — subcollection `recipe_cook_events/{userId}/{eventId}` {recipeId, cookedAt}; event skrivs i SAMMA atomära batch som incrementCookCount (RecipeCookingService.markAsCooked); CookEventRepository.countSince (index-backad); composite index (userId ASC, cookedAt DESC); rules self-only R/W; GDPR-cascade i on-user-deleted; recipe_detail_viewmodel byter proxy→countSince. (BUT-838)
  - Acceptance: 3 cook av SAMMA recept inom 14d → cooksLast14Days == 3 → habitual (testpinnat) · eventskrivningen ligger i samma atomära batch som incrementCookCount · countSince är index-backad (ingen klientfiltrering) · rules: endast ägaren läser/skriver; GDPR-cascade raderar subcollectionen (rules-tester sign-off)

### Agent B: PII-heuristik (BUT-694) `[Tier A]` — RISK-GATED (security; alternativ (c) ur ticketen)
- [x] **B1. Svenska namn+gatuadress-heuristik i BÅDA scrubbers** `[Tier A]` — DONE: TS (53/53) + Dart-spegel (60 tester) från samma 27-vektorsfixture (byte-identisk kopia, hasLength-pin); kontraktsblock i TS-filen är källan; ASCII--diakritfällan speglad. — functions/src/llm/pii-scrubber.ts + lib/services/llm/pii_scrubber.dart: gatusuffix (gatan/vägen/torget/gränd...) med husnummer + namnheuristik (titel/"mormor X"-mönster); identiska testfall i TS och Dart (spegel-kontraktet); redaktions-telemetri oförändrad. (BUT-694)
  - Acceptance: "Storgatan 14" och "mormor Astrid" redigeras i BÅDA scrubbers (samma testfall TS+Dart) · recepttext utan PII passerar oförändrad (ingredienser/instruktioner over-redigeras inte — negativtest) · deterministisk, ingen extra LLM-call (alternativ a förkastat)

### Agent C: 956-robusthet (BUT-1234) `[Tier A]`
- [x] **C1. VM-delegation + generatedForWeek-marker + l10n-listnamn** `[Tier A]` — DONE via flutter-developer: markör-baserad lookup (omdöpt lista regenereras; namnkollision utan markör orörd), executeAsync-VM, AppLocale-namn; 97 tester gröna. — generate-actionen flyttar till WeeklyMenuPlanViewModel (executeAsync ersätter handrullad guard); UnifiedShoppingList får generatedForWeek-metadatafält (regen hittar listan via fältet, inte namnet); listnamn via AppLocale. (BUT-1234)
  - Acceptance: omdöpt genererad lista regenereras fortfarande (ingen dubblett) · användarlista som råkar heta "Inköpslista v.NN" utan markören klobbas INTE · vyn anropar VM:en (ingen ServiceLocator-service-resolvning för actionen) · befintliga 16 aggregator/generator-tester gröna

### Agent D: coverage-golv (BUT-1149) `[Tier A]` — huvudloop
- [x] **D1. Mät aktuell coverage via CI-loggen; höj golvet till 60.0 om klarat** `[Tier A]` — MÄTT: 55.4% på grön fd502ee70 → golvet HÖJS INTE (ärligt utfall); mätvärde + gap-analys postad på ticketen, BUT-1149 åter till Todo som restaureringsåtagande. Inget golv-diff committas. — läs coverage-procenten ur senaste gröna Run Tests-körningen; ≥60 → höj OVERALL_FLOOR; <60 → rapportera ärligt gapet + lämna öppen med mätvärdet. (BUT-1149)
  - Acceptance: golvbeslutet baseras på en FÄRSK mätning (inte antagande) · om höjt: workflow-filen läser OVERALL_FLOOR=60.0 och HEAD-mätningen klarar det · om inte: ticketen får mätvärdet + gap-analys som kommentar

### Needs you (Tier D — flagged, not worked)
- (inget nytt; BUT-1229 backfill→deploy väntar)

### Post-Sprint Steps
- [x] dart analyze + tester (177 grön) · Tier-2 reviews (10 agenter + /code-review high 7-vinklar) · Phase 2.7 grading (alla acceptanskriterier ✓) · review-fixar: PII bounded quantifier {1,60} (4s→18ms) + \b-lookahead-fix ("Storgatan 14 lägenhet" läckte; vektor 28 tillagd) + byte-identitetspin + verifyInOrder-pin + wrong-week-negativtest + alreadyRunning-sentinel (dubbeltapp ≠ felsnackbar) + CookEvent→SerializationUtils + list.name-källa · follow-ups FÖRE commit: BUT-1235 (GDPR-export cook events, High) + BUT-1236 (död incrementCookCount) · commits per ticket · push · Linear-transitioner

---
## ARCHIVED — iter-138 (BUT-956→In Review, BUT-1232/1226/1233 Done, BUT-1227 obsolete) · iter-137 (BUT-444→In Review, 4 Done, red main fixad) · iter-136 (BUT-1214/1216→In Review, 3 Done) · äldre i git-historiken
