# Sprint Backlog

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
