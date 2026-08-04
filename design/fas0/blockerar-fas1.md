# Butlery · Fas 0 stängd · Fas 1 pågår

2026-08-02. **Inga körsiffror i den här filen** — de genereras av `bash fas0/run-verify.sh`.

## Fas 0 · STÄNGD

Verklig GitHub Actions-körning, commit `d34b9f82de0afd34595dea22f68fd1ee5c6a324f`, run `30764509765`:

| Mått | Utfall |
|---|---|
| Fas 0-grinden | **8/8 passed, exit 0** |
| Blockerare | 0 |
| Rapportintegritet | ok |
| Registertäckning | 38/38 |
| Artefaktfingeravtryck | 93/93 oförändrat |
| CHK-CI-01 | **passed** i levande CI |
| `overallResult` | failed — den förväntat röda innehållsbaslinjen, blockerar inte grinden |

Fas 0 återöppnas endast vid en faktisk regression.

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
