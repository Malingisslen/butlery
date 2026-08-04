# tools/ — verifieringskedjan

**Det kanoniska kommandot är `bash fas0/run-verify.sh`**, kört från reporoten (katalogen som bär `tools/`). Det gör två saker i ordning: manifestkontroll först, därefter hela kedjan — och returnerar exit 1 om **någon** del faller.

`node tools/verify.mjs` kör bara kedjan. Då står manifestet som `not run`, och `overallResult` kan därför aldrig bli `passed`.

**Kedjan bryter inte vid första fel** — alla steg körs, så att en röd körning ger hela bilden.

| Steg | Skript |
|---|---|
| Rapportschema ur källan (SC-01) | `gen-schema.mjs` |
| Preflight: är incheckad genererad kod aktuell? (GEN-02) | `preflight.mjs` |
| Ikonräkning | `gen-icons.mjs` |
| Ram- och kontrollräkning | `gen-counts.mjs` |
| CSS ur tokens | `gen-css.mjs` |
| Flutter-tema ur tokens | `gen-flutter.mjs` |
| Genererad kod | `test-generated.mjs` |
| Kontrollgeometri | `lint-controls.mjs` |
| Spec-lint (T-01…T-19, A11Y-01, A11Y-02) | `spec-lint.mjs` → `lint-core.mjs` |
| Verifierarens egna mutationsprov (ST-01) | `selftest.mjs` |
| Metatester för rapportlogiken (MT-01) | `metatest.mjs` |

**Finalisering.** `node tools/finalize.mjs` läser den färdiga rapporten plus ett komplett `fas0/ci-evidence.json`, reducerar om CI-kontrollen och totalerna, och skriver atomiskt om båda rapportfilerna. Den kör **inga** generatorer — de får bara köras en gång per CI-körning.

**Leveranskontroll.** `bash fas0/verify-delivery.sh` kör manifestet med `--mode=delivery`, där varje `zip:/`-post är obligatorisk. Auto-läget kan inte skilja ett legitimt repo från en leverans där både markören och alla externa filer försvunnit — därför måste en leveranskontroll alltid vara explicit.

**Grinden är ett eget kommando.** `node tools/gate.mjs --phase=0` läser `fas0/verify-report.json` och returnerar **grindens** exitkod. Den kör inte kedjan. Totalen (`overallResult`) rapporteras separat och får vara röd — innehållsfynd blockerar ingen grind.

**En grind per fas, en körning per grind.** Grinden vägrar bedöma en rapport som räknats för en annan fas (`currentPhase`). Fas 1 körs därför som `BUTLERY_PHASE=1 bash fas0/run-verify.sh` följt av `node tools/finalize.mjs` och `node tools/gate.mjs --phase=1`. CI har ett jobb per grind.

## Kanoniska källor

| Fil | Roll |
|---|---|
| `screen-files.mjs` | `SCREEN_FILES` (ramar, a11y, skärmbevis) · `ICON_SOURCE_FILES` (ikonräkning) |
| `controls.mjs` | kontrollregistret: id, namn, ägare, källa, motiveringar |
| `gen-report.mjs` | renderar `fas0/kontrollstatus.md` ur `fas0/verify-report.json` |
| `../fas0/check-manifest.mjs` | hash + set-likhet mot reporotens artefakter |
| `selftest.mjs` | muterar källan i minnet och kräver att rätt kontroll fäller · fixturprov · täckningsmatris |
| `report-logic.mjs` | **rena funktioner**: `classifyStep`, `reduceControls`, `computeTotals`, `parseEvidence`, `validateRegistry`, `manifestIntegrity` — testbara utan filsystem |
| `metatest.mjs` | matar konstruerade rapporter genom rapportlogiken och kräver rätt slutsats |
| `preflight.mjs` | läser headerns tokenversion i incheckad genererad kod |

## Regler

- Genererade filer redigeras aldrig för hand. **GEN-01** fäller om en körning ändrar en incheckad genererad fil.
- Inga körsiffror skrivs i dokument — de genereras.
- **Maskin-id:** kontroller heter `CHK-*` (`CHK-T-14`), krav heter `REQ-*`. Namnrymderna är disjunkta; `legacyId` finns kvar för prosa.
- **Fas 0-grinden** omfattar bara verktygsintegritet: `CHK-MF-01`, `CHK-SC-01`, `CHK-ST-01`, `CHK-MT-01`, `CHK-T-19`, `CHK-T-18a`, `CHK-T-18b`, `CHK-CI-01`.
- **Fas 1-grinden** är de åtta ovan (de bär `requiredForGate: [0, 1]`, så verktygsintegriteten inte kan regressera) **plus** `CHK-T-01`, `CHK-T-05`, `CHK-T-06a`, `CHK-T-06b`, `CHK-T-10`, `CHK-T-15`, `CHK-TG-01`, `CHK-GEN-01` och `CHK-GEN-02` — sammanlagt 17. Innehållsbaslinjen ligger utanför också denna grind.
- **Processprov** (M-07, M-11, M-22, M-23, M-24, M-26, M-30, M-31) körs med **sanerad miljö** (ingen `BUTLERY_*`-variabel ärvs), uttryckligt manifestläge och en **ändlig timeout** som räknas som testfel. Ett prov som hänger är ett prov som inte finns.
- **Delivery-läget kräver en validerad leveransrot:** exakt tre nivåer över reporoten, aldrig filsystemets rot, och `zip:/fas0/DELIVERY` måste finnas. Annars exit 2. Set-likheten gäller **båda** ytorna; undantagen är en exakt lista, aldrig ett namnmönster.
- **Mappningen får bara bära token-id.** `semantic`, `palette`, `member` i `colors`, `scheme.slots` OCH `scheme.darkOverrides`; `typeSemantic.color` är `null` eller `AppColors.<medlem som finns>`. Prövas av T-01, av generatorn och av M-31 (källmutation + regenerering).
- **Legacy-API:t** ligger fryst i `legacy-api-contract.json` och mäts med exakt mängdlikhet i båda riktningarna av TG-01.
- **Generatorer och skrivmål** har EN källa: `tools/gen-targets.mjs`. `verify.mjs` importerar `GENERATED_OUTPUTS`, preflight läser `GENERATED_INPUTS`, och M-18 jämför registret mot generatorernas faktiska skrivanrop. Grinden är **fail-closed**: ogiltig fas, trasigt schema, stale rapport eller en grindmängd som inte stämmer med `controls.mjs` ger exit ≠ 0. Innehållsfynd bär `requiredForGate: []` och blockerar inte grinden även när de är röda.
- **Mätvärden** läses bara ur stegspecifika maskinsummeringar (`COUNT-SUMMARY`, `LC-SUMMARY`, `SELFTEST-SUMMARY`, `METATEST-SUMMARY`, `PREFLIGHT-SUMMARY`, `MANIFEST-SUMMARY`) och bär `source`.
- **Fem statusvärden:** `passed` · `failed` · `blocked` · `not run` · `not applicable`. Endast `passed` och `not applicable` uppfyller ett kriterium.
- **Tre resultatnivåer:** `pipelineResult` (stegen) · `controlsResult` (registret) · `phaseGateResult` (kontroller med `requiredForGate` som innehåller den aktuella fasen). `overallResult` kräver alla tre plus manifest och GEN-01.
- **Rollfördelning för genererad kod:** GEN-02 (preflight) = var den incheckade filen stale? · T-15 = stämmer genererad output med indexet? · GEN-01 = ändrade körningen en incheckad fil?
- **Rapporten** skrivs som **två atomiska filbyten** (tmp i samma katalog → JSON läses tillbaka → `rename`), bundna av samma `runId`. Paret är inte transaktionellt atomiskt — processen kan dö mellan bytena — men ingen fil kan vara halvskriven, och `runId` avgör om de hör ihop. Schemat `butlery-verify-report/2` valideras av en **schemadriven** validator som traverserar `REPORT_SCHEMA`; `fas0/verify-report.schema.json` genereras ur samma objekt av `gen-schema.mjs`.
- **Manifestläge:** `--mode=repo` (leveransytan får saknas) eller `--mode=delivery` (varje `zip:/`-post krävs). Auto väljer delivery om någon leveransfil finns.
- `not run` uppfyller aldrig ett kriterium. `not applicable` kräver motivering och får aldrig användas för något som bara ännu inte körts.
- Faller ett generatorsteg märks de beroende kontrollerna `blocked`: deras utfall är en följd, inte ett självständigt fynd.

---

## Historik (Fas 0.5 · 2026-08-01)

Tidigare sa den här filen att `node tools/verify.mjs` var det enda kanoniska kommandot och att kedjan stannade vid första fel. Båda stämmer inte längre. Nedan står den äldre beskrivningen bevarad för spårbarhet.

<details>
<summary>Äldre beskrivning</summary>

> # Butlery · verktyg
> 
> **Ett kommando räcker:**
> 
> ```sh
> node tools/verify.mjs
> ```
> 
> Det kör hela kedjan i rätt ordning och fäller vid första fel:
> 
> 1. `gen-icons.mjs` — räknar om `icons.json` → `usages` ur dokumentens `data-icon`
> 2. `gen-counts.mjs` — räknar ramar och märkta kontroller ur skärmfilen och skriver in dem i dokumenten
> 3. `gen-css.mjs` — `tokens.json` → `assets/generated/tokens.css`
> 4. `gen-flutter.mjs` — `tokens.json` → `lib/theme/butlery_tokens.dart`
> 5. `test-generated.mjs` — parsar och strukturkontrollerar båda artefakterna
> 6. `spec-lint.mjs` — T-01…T-12 (logiken i `lint-core.mjs`)
> 
> Node ≥ 20, inga beroenden. `dart analyze` körs separat i CI — det är det enda steget den här kedjan inte kan göra själv.
> 
> ## Regler
> 
> **Genererade filer redigeras aldrig för hand.** Ändra `tokens.json` eller dokumenten och kör om.
> 
> **Fel fäller bygget, varningar gör det inte.** Skillnaden är avsiktlig:
> 
> | Klass | Innehåll |
> |---|---|
> | **Fel** | Schemabrott · kontrastgolv · okänd ikon · saknad fil · stale ikonräkning · hitbox under 48 utan `data-hit` · **rollvärde utanför de sex** · **kontroll utan roll** · **stale ram- eller kontrollräkning (T-11)** · dubblerade id · **citerat ankare utan motsvarande id (T-12)** · indexets versionstabell |
> | **Varning** | Råa hex och opaciteter i spec-HTML (beslut B-27: specen är en ritning, inte en runtime) · föråldrade versionsreferenser i prosa · handskrivna siffror utan `<!--n:-->`-ankare |
> 
> ## Vad testerna INTE kan se
> 
> Ärlighet om täckningen är en del av verktyget:
> 
> - **T-02** mäter deklarerade par i `tokens.json`. Färgpar som bara uppstår i renderad markup mäts i browsertestet — en färg har ingen kontrast förrän den har en bakgrund.
> - **T-08** läser källkod. Padding-satta höjder syns inte där; renderad geometri mäts i browsern (`testmatris.md` § 4). Det var precis den luckan som lät ett padding-satt chip slinka igenom.
> - **Ingen** prob som utgår från `.sc-phone` ser klippning. Den yttre ramen har fast höjd och rapporterar alltid noll överflöd; klippningen sitter i inre `overflow:hidden`-behållare, och flera ramar saknar klassen helt. Giltig prob står i `evidensmatris.md`.
> - **Ingen** av testerna kan se om en skärmläsare läser rätt. Det står i verifieringsprotokollet och ägs av utvecklingsteamet.
> 
> - `gen-app-theme.mjs` — `tokens.json` + `app-theme-map.json` → appens **befintliga** `lib/theme/app_colors.dart` och `app_text_styles.dart`. Behåller varje medlemsnamn (vyerna kompilerar oförändrade), byter bara värdenas källa. Skiljer sig från `gen-flutter.mjs`, som skriver det nya temat `butlery_tokens.dart`.
> 
> - `lint-controls.mjs` — mäter **låst kontrollgeometri** (`tokens.controls`) och typskalan i skärmfilerna: kryssruta, radio, toggle, chip, statuspill, badge, avatarskala, radier och textstorlekar. Finns för att grundgranskningen 2026-07-26 visade att måtten glider när de bara står i manualtexten. Ett element med `data-lint-exempt="skäl"` hoppas över och räknas i rapporten — en avvikelse får finnas, men den ska vara skriven. Fångar även **mallrester** i normativa attribut (`data-a11y-name="${typ===`), en felklass som ingen räkning ser: kontrollen har både roll och namn, men namnet är obrukbart och skärmläsaren läser upp skräpet.
> 
> - `sync-icon-paths.mjs` — skriver om varje **inline-glyf** i dokumenten ur masterfilen i `assets/icons/`. Finns för att granskningen 2026-07-27 hittade glyfer ritade **ur minnet**: `users` visade två personer där mastern har tre, `message-square` en kantig bubbla utan punkter. Namnet stämde — så `gen-icons` rapporterade noll okända — men ritningen visade en annan ikon än den normativa inventeringen. Öppningstaggen lämnas orörd (storlek och stroke; täta ytor får 2,2).
> 

</details>
