# Butlery · Fas 0 historiskt stängd · Fas 1 pågår

2026-08-04. **Inga körsiffror i den här filen** — de genereras av `bash fas0/run-verify.sh` och läses i `fas0/verify-report.json` och `fas0/kontrollstatus.md`.

## Fas 0 · HISTORISKT STÄNGD PÅ `d34b9f8`

Fas 0-grinden passerade i en verklig GitHub Actions-körning på commit
`d34b9f82de0afd34595dea22f68fd1ee5c6a324f`, run `30764509765` (2026-08-02).
Utfallet står i den körningens rapport — **inte här**.

**Vad den körningen inte bevisar.** Den kördes på den dåvarande verktygskedjan.
v25 ändrar `check-manifest.mjs`, `lint-core.mjs`, `metatest.mjs`, `selftest.mjs`
och `gen-authority.mjs`, och F1-H01–H13 ändrar dem igen. En grön grind på
`d34b9f8` säger ingenting om den kedja som körs nu.

**Följden.** Samtliga ärvda Fas 0-kontroller (`requiredForGate: [0, 1]`) måste
passera på nytt inom den verkliga Fas 1-körningen. De ingår därför i
Fas 1-grinden — det är hela poängen med att de bär båda faserna. Fas 0
återöppnas inte formellt, men dess kontroller får inte regressera.

## Fas 1 · femte vändan · genomförd i källan

Granskningen av v24 körde den orörda ZIP:en två gånger i delivery-läge: hängningen var borta, manifestet verifierade, generatorutdata var byteidentiska. Tre blockerare återstod. Allt nedan är gjort i källan; **körsiffror står inte här** — de genereras av `bash fas0/run-verify.sh` och läses i `fas0/verify-report.json`.

| # | Fynd i v24 | Åtgärd |
|---|---|---|
| 1 | M-24 läste fel returformat: `runFinalize()` returnerade `p.status` och delivery-fallet läste `g1.status/stdout/stderr` ur ett `runProc`-resultat som bara bär `{code, timedOut, out}` — "exit undefined" | Alla anrop läser `code` och `out`. `gateEnv()` och `gateEnvM24()` returnerar bara CI-kontexten; `runProc()` sanerar resten |
| 2 | ZIP-ytan var fortfarande fail-open: `zip:/surprise.png` och `zip:/uploads/scraps/undeclared.json` gav exit 0 | Filtypsallowlisten och de breda katalogundantagen är borta. Leveransytan räknar **varje vanlig fil**; bara **exakta sökvägar** undantas. Symlänkar avvisas med `lstatSync()`, och varje post måste ligga innanför leveransrotens **realpath**. **M-22** provar sju odeklarerade namn, inklusive era två |
| 3 | Det maskinläsbara källauktoritetsmanifestet saknades, och det handskrivna registret hade drivit (icons 1.6, genererade filer "1.3/1.4 ur 1.9", `blocked`/`not run` ihopslagna) | **`source-authority.json`** med eget schema är källan. **T-20** (i Fas 1-grinden) kräver exakt en aktiv auktoritet per domän, filnärvaro, giltiga statusar, de fem kontrollstatusarna var för sig och `supersededBy` utan cykler — plus att en deklarerad JSON-version stämmer med filens egen. `fas0/kallauktoritetsregister.md` **genereras** av `tools/gen-authority.mjs` och vaktas av GEN-01. Fyra negativa prov |
| 4 | Paritetspåståendet ("de 50 vyerna kompilerar oförändrade") stod kvar i kontraktsfilen, mappningen, generatorn och genererad Dart | Omskrivet överallt: **ytan bevaras mot det frysta leveranskontraktet och är overifierad mot app-repot till Fas 2** |
| 5 | `$schemeNote` pekade på borttagna `overlay.ink10`; TG-01:s text nämnde "härledd stil"; styrdokumentet sa tre M-22-namn; dokumenten bar handskrivna körsummeringar | Alla rättade. Körsummeringar är borta ur dokumenten — regeln är styrdokumentets egen |
| 6 | `cleanEnv()` kunde återinföra `BUTLERY_*` via `opts.env` | Bara uttryckligen tillåtna CI- och fasvärden släpps in. **M-32** förgiftar moderprocessen och kräver att både hjälparen och ett verkligt barn ser en sanerad miljö |
| 7 | Legacy-kontraktet saknade schema, och sviten provade bara borttagningsriktningen | `legacy-api-contract.schema.json` med slutna objekt, typade listor och unika namn (T-01). **M-29** provar nu båda riktningarna för både medlemmar och getters |
| 8 | Överläggens namn är styrkenivåer, inte syften | Märkt **preliminärt** i varje tokennot: `inkMedium` bär i dag både bildtvätt och modal bakgrund, och rollerna delas när Fas 2 inventerat appens anrop. Tokens **1.13** |

### Regenererade filer

Alla fyra ur tokens **1.13**, plus `fas0/kallauktoritetsregister.md` ur `source-authority.json`. Manifestet är genererat **allra sist**.

### Vad som är kontrollräknat här

De fyra filerna renderade ur källan · `test-generated` grön mot dem · tolv mutationer av utdata och källa fällda av `check-app-theme` · T-01 och T-20 gröna med nio negativa prov fällda · T-15 mäter varje filreferens · manifestet omräknat och kontrolläst mot filerna. **Antal och utfall står i den genererade rapporten, inte här.**

**Inte kört:** kedjan, selftest, metatest, manifestkontroll, båda grindarna, dubbelkörningen.

## Fas 1 · sjätte vändan · F1-H01…H13

Rättningarna gäller källauktoritet, versionering, manifestintegritet,
generatorer, grindar och beviskedja. Innehållsbaslinjen (kontrast, geometri,
träffytor, komponentimplementering) rörs **inte**.

| # | Fynd | Åtgärd |
|---|---|---|
| F1-H01 | `source-authority.json` deklarerade sig själv som 1.0 medan filen sa 1.1 | Filversion och självpost är samma värde. Registret är **2.0**. Negativt prov i `selftest` |
| F1-H02 | Endimensionell status blandade normativitet med ändringspolicy | `authorityState` (`active` · `planned` · `superseded` · `historical` · `concept`) och `changePolicy` (`maintained` · `frozen`) är oberoende. Stabila `domainId`/`sourceId`. Maskinvärden engelska, svenska etiketter enbart i presentationslagret |
| F1-H03 | `00-spec-index.md` underhöll domän, version och status parallellt med registret | Rader med `auth:`-markör är generatorägda. Indexet kallar sig inte längre ensam källa |
| F1-H04 | T-20 kontrollerade bara de domäner som råkade finnas i registret | Den obligatoriska mängden bor i `tools/authority-contract.mjs`, utanför den fil som valideras. T-20 kräver exakt mängdlikhet. Mutationsprov: hela domänen `design-values` struken |
| F1-H05 | Versionskontrollen läste bara JSON — Markdown och HTML var omätta | Gemensam läsare i `tools/version-read.mjs`, delad av T-15 och T-20. Prov: `content-style-guide.md` deklarerad som 9.9 |
| F1-H06 | Ingen definierad koppling mellan `generatedArtifacts` och generatorernas skrivmål | `FULLY_GENERATED` i `tools/gen-targets.mjs`, mängdlikhet i båda riktningarna. Prov för både borttagen och extra rad |
| F1-H07 | Intern konsistens ersatte kontroll av verklig filnärvaro | Poster i reporoten mäts mot filytan, `outsideRepoRoot` mot manifestets faktiska `zip:/`-poster. Prov: konsekvent omdöpning av en extern auktoritet |
| F1-H08 | Två walkers med olika säkerhetsegenskaper; repo-walkern matchade undantag mot Windows-sökvägar och undantog därför ingenting | EN enumerator i `tools/manifest-contract.mjs`. `lstatSync()` överallt, symlänkar avvisas först, sökvägar normaliseras före undantagen |
| F1-H09 | Filtypsallowlist och katalogundantag gjorde `assets/`, `exports/` och lockup-katalogen osynliga | Varje vanlig fil räknas. Endast sju exakt namngivna körartefakter undantas. Bygg-, dependency- och VCS-kataloger **avvisas**. M-22 utökad till tio odeklarerade filer i båda ytorna plus två symlänkar |
| F1-H10 | M-24 läste `gateIn().status` ur ett `runProc`-resultat som bara bär `{code, timedOut, out}` — villkoret var alltid sant | Läser `code`. Provet bevisar att mutationen skedde, att grinden kördes, att den var grön före, och att den nya diagnostiken kom ur fingeravtrycket |
| F1-H11 | Vakuösa prov | Delta mot baslinjen krävs i `selftest`; M-33 låser sju felklasser i källan, inklusive varje jämförelse mot `.status` |
| F1-H12 | Motsägelser i de aktiva dokumenten | 17→**18** grindkontroller (M-34 räknar om talet), tokens 1.13, styrdokument 2.5, trasiga rader för Formskala, Ikoner och Kravstatus, oavslutad `<b>`, och datumet 2026-08-05 → **2026-08-04** |
| F1-H13 | — | Generatorer, manifest sist, ren leverans, kedjan två gånger, byteidentitet, båda grindarna |

### Nytt integritetsfynd · två byggen av `support.js`

Leveransen bär två olika byggen av dokumentruntimen:
`support.js` i reporoten (66 404 byte, 1 841 rader, 23 konsumenter) och
`zip:/support.js` i leveransroten (69 150 byte, 1 911 rader, 4 konsumenter).
Den yttre är ett **senare bygge** och en strikt superset — tillägget är
`isDeckMountTag`, `renderDeckKids` och `walkDeckChildren`. Ingenting är
borttaget, och inget dokument i leveransen använder deck-taggar.

Båda är manifestdeklarerade och förtecknade i `source-authority.json`
(`runtimeInstances`, domänen `document-runtime`). **Ingen av dem skrivs över
eller slås ihop** förrän relationen omprövas.

## Kvar · innehållsbaslinjen (Fas 1 och framåt)

| # | Uppgift | Ägare |
|---|---|---|
| 1 | **Kör kedjan två gånger** från den uppackade ZIP:en: `BUTLERY_PHASE=1 bash fas0/run-verify.sh` → `node tools/finalize.mjs` → `node tools/gate.mjs --phase=1`. | DEV |
| 2 | **CI-01** — aktivera workflowen i det riktiga repot; jobbet `fas1-gate` finns. | DEV |
| 3 | **Legacy-API:t mot app-repot.** Kontraktet är fryst ur levererad kod; parallelliteten bevisas först i Fas 2. | DEV + DS |
| 4 | **Lägesmedvetet färg-API.** `AppColors` är `static const` utan temakontext — en mörk variant kräver `ThemeData`/`ThemeExtension` först. | DEV |
| 5 | **Överläggens roller** delas upp efter appens faktiska anrop (bildtvätt mot modal bakgrund). | DS |
| 6 | **Märk resten av komponenterna** tills `LC-COVERAGE` visar noll omärkta kandidater. | DS |
| 7 | **Migrera Skärmbevis till typad grammatik** och stäng de rader T-14 rapporterar utan bevis. | DS |
| 8 | **Rollvokabulären** (T-08) och **träffytorna**. | DS |

## Baslinjefynd att föra vidare

Den senaste officiella körningens fynd är **baslinje, inte blockerare**: de ska föras vidare i evidensmatrisen och lösas i sin fas. Rött hindrar inte Fas 0 från att passera — falska gröna statusar gör det.
