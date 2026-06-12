# Sprint Backlog

## Sprint: modellintegritet-CRF + NER-CI + kvadratiska dialoger + OCR-konfidens + timer-chips + destruktiv-bekräftelse — 2026-06-11 (iter-141)

### Agent A: parser-säkerhet (BUT-1238) — RISK-GATED (security)
- [x] **A1. Integritetsverifiering av CRF-viktfiler** — DONE (Storage 404 → tomt register dokumenterat; 4 nya integritets-pins, 19/19 gröna) `[Tier A]` — spegla BUT-877-kontraktet i `remote_weight_loader.dart`: `kExpectedCrfWeightHashes`-register i `_expected_model_hashes.dart`, verify-before-commit, fail-close på saknad/mismatchad hash; tester speglar `model_manager_integrity_test.dart`. (BUT-1238)
  - Acceptance: viktfil utan registerpost vägrar laddas OCH rule-based fallback parser fortfarande (testpinnat) · hashmismatch vägrar (testpinnat) · registerpost för publicerade vikter committad — eller dokumenterat varför den inte kan fångas + fail-close håller ändå · befintliga CRF-tester gröna

### Agent B: NER-golden-CI (BUT-1005) `[Tier A]`
- [x] **B1. NER-signal i nightly golden-llm** — DONE (premise stale: plugin-runtime-blockerad, inte modellfil; väg 3 + skip-artefakt; ticket-body uppdaterad; follow-up BUT-1240) — Step 0 avgör väg 1 (stub-modell) / 3 (dokumenterad skip + lokalt script); väg 2 (CI-secrets) är D-blockerad. Runner finns i `test/golden/llm/ner_test.dart`, gated på NER_MODEL_PATH/NER_VOCAB_PATH. (BUT-1005)
  - Acceptance: nightly golden-llm.yml ger explicit NER PASS/FAIL-signal ELLER dokumenterad skip-rationale i workflowfilen · `goldens-ner.json`-artefakt laddas upp varje nightly även vid 0 körda cases · noll tillagd API-kostnad

### Agent C: kvadratiska dialoger (BUT-1237) `[Tier B]`
- [x] **C1. Squarea globala dialogTheme** — DONE (shape→square + bg→cs.surface/cream; 4 overrides borttagna; temat pinnat i dialog_theme_square_test; preview: docs/design/previews/square-dialogs-preview.html; 196 tester gröna) — `navigation_themes.dart:82` → `RoundedRectangleBorder()`; granska backgroundColor mot mockup-dialogspec (§4.17 cream); ta bort de 4 redundanta per-dialog-overrides (recipe_management_handler ×2, retag_progress_dialog, cook_snap_visibility_dialog). (BUT-1237)
  - Acceptance: global dialogTheme.shape är kvadratisk · grep visar noll redundanta `RoundedRectangleBorder()`-shape-overrides i AlertDialog-sites · bakgrundsbeslut (cream vs nuvarande) explicit dokumenterat i In-Review-kommentaren · HTML-preview av representativa dialoger → In Review

### Agent D: OCR-konfidens i assisted dialog (BUT-928) `[Tier B]`
- [x] **D1. OCR-konfidensbadge följer med handoffen** — DONE (premise stale: assisted dialog nås ej från foto-OCR; rescopad till foto→FranSocialaMedier-handoffen; ConfidenceIndicator → widgets/import; route-arg + router + badge; 11 tester gröna; preview: ocr-confidence-handoff-preview.html) — samma grön/orange/röd-skala som preview-steget (photo_import_viewmodel:370-374); INGA pipeline-ändringar (per-line-konfidens uttryckligen out of scope). (BUT-928)
  - Acceptance: assisted-dialogens header visar samma badge, matad från befintlig övergripande konfidens · ingen ny data från Cloud Function (diff rör bara klient-UI) · preview-stegets badge oförändrad (regression) · HTML-preview → In Review

### Agent E: inline timer-chips (BUT-604) `[Tier B]` — RISK-GATED (multi-modul)
- [x] **E1. Tappbara timer-chips inline i instruktionstext** — DONE narrowed (chips i båda vyerna + ordfraser + span-API; multi-timer + notis → BUT-1242; preview: inline-timer-chips-preview.html; parser 39 + chip 4 + journey 2 + detail 45 gröna) — delta över BUT-406: chips i `cooking_mode_view.dart` + `recipe_detail_view.dart` (ersätter long-press-only discovery); parser-utökning "en halvtimme"/"en kvart" i `duration_parser.dart`; StepTimerService → flera samtidiga namngivna timers; lokal notis vid utgång. (BUT-604)
  - Acceptance: parsade durationer renderas som tappbara chips i BÅDA vyerna (widgettest) · "en halvtimme" och "en kvart" parsas (testpinnat) · två samtidiga timers tickar oberoende med egna labels (testpinnat) · timerutgång triggar lokal notis · HTML-preview → In Review

### Agent F: destruktiv-bekräftelse-standard (BUT-954) `[Tier C]` — RISK-GATED (cross-modul, alltid för Tier C)
- [x] **F1. Kodifiera + tillämpa bekräftelseregeln** — DONE plan-stale (3/5 sajter redan kompatibla; regel → ui-conventions.md; pantry → klass 1: dialog bort + 7s undo via restoreItem; tag/comment-dialoger kvar per klass 2; 14 tester gröna) — regel: reversibel → snackbar-undo utan dialog; hård-destruktiv → confirm-dialog (+undo där möjligt); lätt åtgärd → ingen friktion. Tillämpa på de citerade sajterna (recipe_card_widget, pantry_item_card, personal_tag_dialogs, recipe_delete_manager, collaborative_shopping_items) och dokumentera regeln där design-konventioner bor. (BUT-954)
  - Acceptance: regeln dokumenterad (ui-conventions eller motsvarande) med de tre severity-klasserna · varje citerad sajt följer sin klass efter ändringen (mappning i In-Review-kommentaren) · befintliga tester gröna; ändrade flöden får uppdaterade widgettester · ingen ny dialog på lätta åtgärder (claim/markera klar)

### Needs you (Tier D — flagged, not worked)
- BUT-1229 — backfill→rules-deploy-ordning väntar (oförändrat)
- High-ops-klustret (BUT-451/486/492/813/814/880/889/1166) — kräver konsol/creds/enrollment; sedan tidigare flaggade

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Phase 2.7 outcome-grading per agentgrupp
- [ ] Follow-ups → Linear FÖRE commit
- [ ] Commit, push
- [ ] Linear: Tier A → Done; Tier B/C → In Review + notify

---
## ARCHIVED — iter-140 (BUT-1235/1236/839/877 Done, BUT-999 In Review; follow-ups BUT-1238/1239) · iter-139 (BUT-838/694/1234 Done, BUT-1149 ärligt ej höjd) · iter-138 (BUT-956 In Review, 3 Done, BUT-1227 obsolete) · äldre i git-historiken
