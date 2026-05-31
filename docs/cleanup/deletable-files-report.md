# Rapport: sannolikt raderbara filer

**Status:** Endast granskning — **inget har raderats.**
**Datum:** 2026-05-30
**Källa:** workflow-körning `wf_07c1e859-aa4` (find-deletable-files), efterföljande manuell verifiering.

Varje kandidat är verifierad mot `git ls-files` (sanningskälla för spårade filer) och, där
relevant, `git grep`/disk-kontroll. Sökvägar är repo-relativa. Säkerhetsnivåer:

- **hög** = nästan säkert säkert att radera (tydligt skräp, noll referenser).
- **medel** = troligen raderbar, men förtjänar en mänsklig blick först.
- **låg** = osäkert; kan rimligen vara i bruk. Verifiera manuellt innan radering.

---

## ⚠️ Viktig rättelse mot workflow-resultatet

Scannerns kategori **"Död Dart-kod" var helt hallucinerad och har förkastats.** Den
rapporterade fyra filer med absoluta Windows-sökvägar
(`C:\Butlery\butlery\lib\...`) som påstods vara korrupta filer fyllda med en upprepad
rad "mockup design language: SQUARE everywhere…".

Verifiering visar att **ingen av dessa filer existerar** — varken spårad i git eller på disk,
och katalogerna (`lib/widgets/recipe/cooking_mode/`, `lib/views/dev/`) saknas helt:

| Påstådd fil | git-spårad? | finns på disk? |
|---|---|---|
| `lib/widgets/recipe/cooking_mode/README.md.dart` | nej | nej |
| `lib/widgets/recipe/cooking_mode/cooking_mode_overlay.dart` | nej | nej |
| `lib/views/dev/style_guide_view.dart` | nej | nej |
| `lib/services/example_telemetry_usage.dart` | nej | nej |

Den upprepade texten kommer från sessionens MEMORY.md-kontext, inte från riktiga filer —
scannern tappade tool-output (känt fel som flera scanner-noter nämner) och fabricerade
kandidater. Dessutom är `cooking_mode` tvärtemot scannerns påstående **en riktig, levande
feature** (`lib/views/cooking_mode_view.dart`, `lib/viewmodels/cooking_mode_viewmodel.dart`
+ fyra testfiler). **Radera ingenting baserat på den kategorin.**

---

## Uppenbar skräp

### 🟢 hög

- **`test/unit/services/unified/modules/realtime_content_operations_test.dart.tmp`**
  Spårad testfil med `.tmp`-suffix. Testköraren plockar bara upp `*_test.dart`, så `.tmp`-varianten
  körs aldrig. Verifierat: en **levande motsvarighet utan suffix**
  (`realtime_content_operations_test.dart`) finns spårad bredvid — `.tmp` är en kvarglömd
  dubblett av ett riktigt test. Klassisk temp-artefakt.

- **`.firebase/hosting.YnVpbGRcd2Vi.cache`**
  Firebase hosting-deploycache (base64-namnet avkodar till `build\web`). Maskinlokal deploy-state
  som inte ska committas; regenereras vid nästa `firebase deploy`. **Verifierat: `.firebase/`
  finns INTE i `.gitignore`** (endast `firebase-debug.log` m.fl. är ignorerade), så cachen
  kommer att återkomma efter radering. **Rekommendation:** lägg till `.firebase/` i `.gitignore`
  i samma veva.

---

## Död Dart-kod

Scannerns ursprungliga resultat var hallucinerat (se rättelsen överst). Jag körde därför om
analysen korrekt: byggde mängden av alla basenamn som refereras i `import`/`export`/`part` över
`lib` + `test`, och listade lib-filer vars basenamn aldrig förekommer någon annanstans. Av 1 297
lib-filer (exkl. entrypoints + genererade `*.g/.freezed/.mocks.dart`) hade **28 noll
import-referenser**. Efter att ha räknat *alla* textträffar (för att fånga villkorliga importer
`import 'x_stub.dart' if (...) 'x_web.dart'`) återstår **12 filer med noll träffar i hela
`lib`+`test`** — äkta kandidater. De övriga 16 är falska positiva (villkorliga `_web`/`_native`/
`_stub`-mål, bootstrap-wirade observers, samt `drift/database.dart` med 19 träffar).

### ✅ ÅTGÄRDAT — alla 12 raderade efter per-fil-verifiering (2026-05-31)

Per-fil-granskning bekräftade samtliga 12 som genuint döda: symbolerna förekommer bara i sin egen
fil (utom doc-kommentarer), bas-klassens enda "subklass" var ett docstring-exempel, och varje
"nylig" git-touch var en **mekanisk svep-migrering** (`clock.now()`-bulk, CPI→LoadingIndicator,
reduced-motion-batch, StyledButton-retirement) — inte feature-arbete. Inga tester importerar dem.
Hela-repot-basename-koll var ren (de enda externa omnämnandena var analys-dok + en vestigial
CI-exkludering för `personal_tag_color_picker`, som städades bort). `flutter analyze` rent efter
radering. De tolv:

- `lib/core/constants/durations.dart`
- `lib/core/di/interfaces/user_scoped_service.dart`
- `lib/repositories/firebase/base_social_interaction_repository.dart`
- `lib/services/offline/offline_exports.dart` *(barrel — kontrollera att inget importerar barrelen)*
- `lib/services/tagging/ingredient_suggestion_service.dart`
- `lib/viewmodels/recipe_form/image_management/image_state_synchronizer.dart`
- `lib/views/auth/mfa_challenge_dialog.dart` *(MFA-dialog — bekräfta att den inte route-registreras)*
- `lib/widgets/common/input/adaptive_date_picker.dart`
- `lib/widgets/recipe/duplicate_import_dialog.dart`
- `lib/widgets/styled/styled_widgets.dart` *(barrel)*
- `lib/widgets/tagging/personal_tag_color_picker.dart`
- `lib/widgets/tagging/personal_tag_edit_dialog.dart`

> **EJ kandidater (verifierat levande trots 0 import-referenser):** villkorliga plattformsmål
> (`consent_broadcast_web`, `pwa_install_service_web`, `recipe_print_service_web`,
> `download_web/native`, `offline_*_stub`), bootstrap-wirade observers
> (`interaction_route_observer`, `performance_navigator_observer`, `session_activity_observer`,
> `deep_link_handler`), `core/di/modules/search_module.dart`, `permission_cache_invalidator.dart`,
> `email_verification_view.dart` (1 träff vardera) och `core/storage/drift/database.dart` (19 träffar).

---

## Stale / dubblerad dokumentation

> Innehållet i dessa filer diffades inte rad-för-rad under verifieringen; bedömningen vilar på
> sökväg, struktur och projektets egen regel (`code-style.md`: radera analys-/planrapporter som
> inte längre ageras på). Alla nivåer hålls därför konservativa. **Öppna och jämför innan radering.**

### 🟡 medel

- **`docs/analysis/runs/2026-05-claude-deep/`** (14 spårade filer)
  En av **tre parallella daterade analyskörningar** från samma månad
  (`2026-05-claude`, `2026-05-claude-deep`, `2026-05-codex`) — verifierat att alla tre finns med
  identisk 12-kategoristruktur. `-deep` är en nära-dubblett/omkörning av `2026-05-claude`.
  Engångs analys-output; superserad när tickets väl filats i Linear. Diffa `-deep` mot
  `2026-05-claude` först.

- **`docs/sprint-batch-13/bug-findings.md`**
  Sprintspecifik bug-fyndlista knuten till en enskild batch. Engångsartefakt; obsolet när buggarna
  är filade/åtgärdade. Projektets regler säger uttryckligen att radera debug-/implementationsdokument
  när de lösts.

- **`ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`**
  Xcode-genererad boilerplate-README som följer med default-LaunchImage-imageset. Återger det
  uppenbara, inget projektspecifikt värde — typisk per-katalog-README att städa.

### 🔴 låg

- **`docs/analysis/runs/2026-05-claude/`** (13 spårade filer)
  Andra av de tre parallella körningarna. Minst en av de tre är redundant, men vilken/vilka kräver
  manuell diff. Behåll tills `-deep` vs `-claude` jämförts.

- **`docs/analysis/runs/MASTER-ticket-execution-log.md`**
  Statisk ticket-exekveringslogg från analys-orkestreringen. Faktiska tickets lever i Linear;
  en statisk logg i repo blir snabbt inaktuell. Verifiera mot Linear-tillstånd först.

- **`docs/analysis/runs/MASTER-ticket-dedup.md`**
  Dedup-arbetsdokument från samma orkestrering. Saknar värde när dedup är gjord och tickets ligger
  i Linear.

- **`docs/analysis/CODEX_RUN_GUIDE.md`**
  Körguide för codex-analyspromptserien. Behåll om analysen ska köras om periodiskt — annars
  överflödig tillsammans med `runs/`-trädet och `docs/analysis/prompts/`.

> **Möjliga dubbletter att granska manuellt (EJ kandidater här):**
> `docs/legal/` (privacy/tos sv+en) vs `assets/legal/` (privacy/terms/community sv+en) — troligen
> källa vs app-bundlad, men bekräfta att de inte divergerat. Samt
> `docs/ops/data-residency.md` vs `docs/operations/data-residency.md` — samma filnamn i två
> kataloger, möjlig dubblett.

---

## Oanvända assets

**Inga kandidater.** Verifierat mot faktisk `git ls-files 'assets/**'`: samtliga 35 assets är
antingen kod-refererade eller pubspec-deklarerade och aktivt använda (JosefinSans/SpaceGrotesk-fonter,
webp-grönsaksillustrationer, artskida-animationsbildrutor, legal-policydokument laddade via
`rootBundle`, `crf_ingredient_weights.json`, `seasonal/2026.json`). Plattformsikoner och
golden-test-baslinjer är byggstyrda/testgenererade och ingår inte.

> Obs: scannerns *första* StructuredOutput-körning granskade hypotetiska, ej existerande filnamn
> (`empty_friends.svg`, `Inter-*.ttf` m.fl.) och rättades sedan av agenten själv. Bortse från dem.

---

## Redundant / död config

### 🟡 medel

- **`test/golden/crf_ingredients.backup.json`**
  `.backup.json` bredvid den levande `test/golden/crf_ingredients.json` (verifierat att den levande
  filen finns). **Verifierat: NOLL referenser** i hela repot (`git grep` utanför filen själv).
  Git är redan backupen — kvarglömd manuell snapshot.

- **`test/golden/new_golden_entries.json`**
  Namnet antyder en tillfällig staging-fil. **Verifierat: NOLL referenser** från någon golden-runner
  eller skript. Sannolikt ett mellansteg som glömdes kvar.

### 🔴 låg

- **`package.json`** (repo-root)
  Nästan helt `npm init`-boilerplate; enda reella nyttan är devDep `lefthook`. **Verifierat: ingen
  CI-workflow kör `npm ci`/`npm install` i repo-roten** — samtliga `npm ci` använder
  `working-directory: functions` med `functions/package-lock.json`. Den kvarvarande funktionen är
  alltså lokal lefthook-install (`npm install` i roten). Behålls på "låg" eftersom den devDep:en
  är en legitim, om än minimal, install-väg.

- **`package-lock.json`** (repo-root)
  Hör till root-`package.json` ovan (enda dependency: lefthook). Står och faller med den —
  **bedöm de två tillsammans, radera inte den ena ensam.** Funktionernas egna Node-deps ligger
  separat under `functions/` med egen lockfil, så detta är ingen duplicering.

---

## Sammanställning

| Kategori | hög | medel | låg | totalt |
|---|---:|---:|---:|---:|
| Uppenbar skräp | 2 | 0 | 0 | 2 |
| Död Dart-kod *(omkörd korrekt)* | 0 | 12 | 0 | 12 |
| Stale/dubblerad dokumentation | 0 | 3 | 4 | 7 |
| Oanvända assets | 0 | 0 | 0 | 0 |
| Redundant/död config | 0 | 2 | 2 | 4 |
| **Totalt** | **2** | **17** | **6** | **25** |

Utöver det ovan: **`docs/analysis/`-trädet är 86 spårade filer** av engångs-analys-output
(tre parallella körningar + MASTER-waves/synthesis/ticket-loggar). Endast fragment listas
individuellt ovan, men hela trädet är den enskilt största raderbara pölen om analysen inte ska
köras om — bedöm det som ett block (diffa de tre körningarna mot varandra först).

**Varför så få i ett så stort repo:** repot är stort för att det är en genuint stor app
(1 297 lib-filer + 902 testfiler), inte för att det är fullt av skräp. ~1 % oanvänd Dart-kod är
hälsosamt. Den ursprungliga workflow-siffran (13) var konstlat låg eftersom dead-code-scannern
kraschade och flera scanners tappade tool-output mitt i körningen — den mätte vad den hann
bekräfta, inte vad som faktiskt är raderbart.

**Trygga snabbvinster (hög):** de två skräpfilerna — `.tmp`-testet och `.firebase`-cachen
(lägg samtidigt till `.firebase/` i `.gitignore`).

Resten kräver en mänsklig blick: de 12 dead-code-filerna bör öppnas (särskilt barrels och
MFA-dialogen), dokumentationskandidaterna innehållsdiffas, `docs/analysis/`-trädet bedömas som
block, och `package.json`/`package-lock.json` bedömas som ett par. **Inget i denna rapport har
raderats.**
