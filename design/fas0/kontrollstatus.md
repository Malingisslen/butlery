# Kontrollstatus

**Genererad av `tools/verify.mjs` ur `tools/controls.mjs` + körningen. Redigera inte för hand.**

| | |
|---|---|
| Kommando | `node tools/verify.mjs` |
| Körd | 2026-08-08T13:49:18.977Z · Node v22.16.0 |
| Kedjan (steg) | **failed** |
| Kontrollerna | **failed** · failed: CHK-T-02, CHK-T-08, CHK-T-14, CHK-T-21, CHK-LC-01, CHK-A11Y-01, CHK-A11Y-02 · blocked: — |
| Fas 0-grinden | **failed** — CHK-MF-01(not run), CHK-CI-01(not run) · eget kommando: `node tools/gate.mjs --phase=0` |
| Rapportschema | `butlery-verify-report/2` · runId `d3d6fafd3c94eeca` · 2026-08-08T13:50:04.136Z |
| Paket | manifest `36851fbcf4269d1e…` · 321 poster · node v22.16.0 |
| Namnrymder | **disjunkta** · 48 CHK-* · 429 REQ-* |
| Självtestets täckning | runtime 24 · proven_negative 19 · exempt 5 · uncovered 0 · sum 24 |
| **Totalt** | **failed** (exit 1) — steg: Kontrollgeometri · steg: Spec-lint · manifest: not run — manifestet kördes inte · Fas 0-grinden: CHK-MF-01(not run), CHK-CI-01(not run) · kontroller: CHK-T-02(failed), CHK-T-08(failed), CHK-T-13(not run), CHK-T-14(failed), CHK-T-21(failed), CHK-LC-01(failed), CHK-A11Y-01(failed), CHK-A11Y-02(failed), CHK-R-01(not run), CHK-R-02(not run), CHK-R-03(not run), CHK-R-04(not run), CHK-R-05(not run), CHK-R-06(not run), CHK-R-07(not run), CHK-R-08(not run), CHK-I-01(not run), CHK-R-ID-01(not run), CHK-R-T-01(not run), CHK-R-E-01(not run), CHK-K-01(not run), CHK-K-02(not run), CHK-MF-01(not run), CHK-CI-01(not run) |
| Spec-fel | **719** |
| Spec-varningar | **3** |
| Geometriavvikelser | **307** |
| Täckningsfel (LC) | **1** |
| Manifest | **not run** · parsed 0 · verified 0 · bad 0 · missing 0 · duplicates 0 · unlisted 0 · outsideAbsent 0 · exit null |
| Kanoniskt kommando | `bash fas0/run-verify.sh` · **slutlig exit 1** |

De tre mätklasserna summeras aldrig till ett tal — de mäter olika saker.

## Källor

| Fil | Version | inputSha256 | outputSha256 |
|---|---|---|---|
| `tokens.json` | 1.13 | `444b332bda5241a5…` | `444b332bda5241a5…` |
| `icons.json` | 1.8 | `fa46237fdc7ef51b…` | `fa46237fdc7ef51b…` |
| `assets-manifest.json` | 1.4 | `df7201da509c2359…` | `df7201da509c2359…` |

inputSha256 är filen före kedjan, outputSha256 efter. Skiljer de sig har en generator skrivit i filen, vilket betyder att den incheckade versionen var stale — GEN-01 fäller på det. Drift är alltså förväntad som mätning, aldrig godtagbar som tillstånd.

## Steg

| Steg | Skript | Status | Exit | Spec-fel | Spec-varn | Geometri |
|---|---|---|---|---|---|---|
| Rapportschema ur källan | `tools/gen-schema.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Preflight: incheckad genererad kod | `tools/preflight.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Ikonräkning | `tools/gen-icons.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Ram- och kontrollräkning | `tools/gen-counts.mjs` | **passed** | 0 | 0 | 0 | 0 |
| CSS ur tokens | `tools/gen-css.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Flutter-tema ur tokens | `tools/gen-flutter.mjs` | **passed** | 0 | 0 | 0 | 0 |
| App-tema ur tokens | `tools/gen-app-theme.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Källauktoritetsregister ur source-authority.json | `tools/gen-authority.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Artefaktförslag ur registret | `tools/gen-artifact-proposal.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Manifestet mot enumeratorn | `tools/gen-manifest.mjs --check` | **passed** | 0 | 0 | 0 | 0 |
| Genererad kod | `tools/test-generated.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Kontrollgeometri | `tools/lint-controls.mjs` | **failed** | 1 | 0 | 0 | 307 |
| Spec-lint | `tools/spec-lint.mjs` | **failed** | 1 | 719 | 3 | 0 |
| Verifierarens egna mutationsprov | `tools/selftest.mjs` | **passed** | 0 | 0 | 0 | 0 |
| Metatester för verktygskedjan | `tools/metatest.mjs` | **passed** | 0 | 0 | 0 | 0 |

## Kontrollregister

**24 passed · 7 failed · 0 blocked · 17 not run · 0 not applicable** — summa 48 av 48

| Id | Kontroll | Status | Löses i fas | Blockerar grind | Fel | Varn | Avvik | Ägare | Motivering / avgränsning |
|---|---|---|---|---|---|---|---|---|---|
| CHK-T-01 | Tokens och mappningskällor mot JSON Schema | **passed** | 0 | 1 | 0 | 0 | — | DS | Validerar tokens.json mot butlery-tokens.schema.json, assets/brand-colors.json mot sitt schema och tools/app-theme-map.json mot tools/app-theme-map.schema.json — samma validator (walkSchema) för alla tre. Fas 1: de två senare validerades inte av kedjan alls. |
| CHK-T-02 | Kontrastlint över deklarerade par | **failed** | 1 | — | 8 | 0 | — | DS |  |
| CHK-T-03 | Råfärgslint i spec-HTML (varning) | **passed** | 0 | — | 0 | 0 | — | DS |  |
| CHK-T-04 | Opacitetslint | **passed** | 0 | — | 0 | 2 | — | DS |  |
| CHK-T-05 | Ikonlint — namn och masterfil | **passed** | 1 | 1 | 0 | 0 | — | DS |  |
| CHK-T-06a | icons.json usages stämmer med källan | **passed** | 1 | 1 | 0 | 0 | — | DS | Beroende av gen-icons: blockeras om generatorn faller. |
| CHK-T-06b | assets-manifestets filreferenser finns på disk | **passed** | 1 | 1 | 0 | 0 | — | DS | Oberoende av generatorerna — mäts alltid, även när gen-icons faller. |
| CHK-T-07 | Föråldrade versionsreferenser i dokument (varning) | **passed** | 1 | — | 0 | 0 | — | DS | Söker "manual v1–v5", "0.620–0.624" och "Skarmar v10/v11" i skärmdokumenten. Rapporterar VARNINGAR, inte fel. Fas 0.12: registret sa tidigare att kontrollen täcker genererade filer — det gör den inte, det är GEN-02 och T-15. |
| CHK-T-08 | Träffyte- och rollint | **failed** | 3 | — | 685 | 0 | — | DS |  |
| CHK-T-09 | Syntaxlint per fil | **passed** | 0 | — | 0 | 0 | — | DS |  |
| CHK-T-10 | Indexlint — versionstabellen | **passed** | 0 | 1 | 0 | 0 | — | DS |  |
| CHK-T-11 | Räkningslint | **passed** | 0 | — | 0 | 1 | — | DS |  |
| CHK-T-12 | Ankarlint — citerade ankare i prosa | **passed** | 0 | — | 0 | 0 | — | DS |  |
| CHK-T-13 | Avstängd text mot eget golv 3:1 | **not run** | 2 | — | 0 | 0 | — | DS | kräver renderad mätning i DOM (Fas 2). Textuell lint kan inte avgöra vilken yta tonen står på. |
| CHK-T-14 | Skärmbevis-kolumnen valideras | **failed** | 0 | — | 23 | 0 | — | DS | Skilt från T-12: T-12 läser citerade ankare i prosa, T-14 läser evidensmatrisens Skärmbevis-kolumn. |
| CHK-T-15 | Indexlint mäter HELA versionstabellen | **passed** | 0 | 1 | 0 | 0 | — | DS |  |
| CHK-T-16 | Ram-id kan inte kollidera — globalt | **passed** | 0 | — | 0 | 0 | — | DS | Implementerad i Fas 0 under arbetsnamnet T-09b; id:t är T-16 enligt evidensmatrisen. |
| CHK-T-17 | Interna #-länkar pekar i samma fil | **passed** | 0 | — | 0 | 0 | — | DS |  |
| CHK-T-20 | Källauktoriteten är maskinläsbar och konsistent | **passed** | 1 | 1 | 0 | 0 | — | DS | Validerar source-authority.json mot sitt schema och kräver exakt EN aktiv auktoritet per domän, att varje deklarerad fil finns, att statusarna hör till ordboken, att kontrollstatusordboken är exakt de fem värdena och att supersededBy bildar ingen cykel. Registret i fas0/kallauktoritetsregister.md genereras ur filen. Fas 1: styrdokumentet krävde den maskinläsbara motsvarigheten, och till dess drev det handskrivna registret. |
| CHK-T-21 | Artefaktklassificering (§ 5.1) | **failed** | 2 | 2 | 1 | 0 | — | DS | Jämför de artefakter som OBSERVERAS i skärmfilerna mot beslutsregistret artifacts.json och redovisar tre skilda felklasser: registerfel (saknad, extra, dubblerad post), datafel (ogiltigt värde mot vokabulären, eller ett beslut som motsäger observationen) och obeslutat (giltig post utan klassificeringsbeslut). Unikheten prövas på HELA variantnyckeln screenId · stateId · viewportClass · variantId — flera aktiva responsiva varianter av samma vy är legitima. En enhetsram är stark evidens för en viewport men aldrig ett auktoritetsbeslut: observationen ägs av maskinen, klassificeringen av en människa, och seed-verktyget skriver aldrig ett beslutat fält. |
| CHK-LC-01 | Kontrollgeometri (lint-controls) | **failed** | 4 | — | 0 | 0 | 307 | DS | 1 täckningsfel — en regel som körts på noll komponenter får inte bli grön |
| CHK-TG-01 | Genererad kod (test-generated) | **passed** | 1 | 1 | 0 | 0 | — | DEV | Prövar tokens.css och butlery_tokens.dart OCH — sedan Fas 1 — app_colors.dart och app_text_styles.dart mot tools/app-theme-map.json: varje mappad medlem, varje varumärkesfärg, varje alias INKLUSIVE dess högersida, varje typroll, varje typalias, varje semantisk variant och den publika ytan mot det frysta legacy-api-contract.json. En ändring i mappningsfilen som inte regenererats fäller kontrollen. |
| CHK-A11Y-01 | Roll och namn på märkta kontroller | **failed** | 3 | — | 1 | 0 | — | DS |  |
| CHK-A11Y-02 | Tillståndsmetadata på stateful kontroller | **failed** | 3 | — | 1 | 0 | — | DS | Räknar dynamiskt i lint-core. Statusen kommer ur körningen — inga tal i registret. Kontrakten i Fas 3 gör fältet obligatoriskt. |
| CHK-R-01 | Renderad kontrast per fil | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver DOM-rendering i CI. |
| CHK-R-02 | Renderad träffyta | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver DOM-mätning; källdeklarationen är inte bevis. |
| CHK-R-03 | Overflow och klippning renderat | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2. |
| CHK-R-04 | Mörkt läge per vy | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2. |
| CHK-R-05 | Kanonisk R-03-analys med findingId och enhetsvalidering | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver en genomförd renderingskörning. · Deduplicerar R-03a…d till ett fel per element och artefakt, klassar varje detektion som verifierad, avsiktlig, observation eller verktygsfel, och fäller på fel totalsumma eller tal utan enhetssuffix. |
| CHK-R-06 | Beständiga negativa prov för renderingskedjan | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver Chrome och en katalog utanför manifestytan. · Tio prov: N-01 observation utan klippning, N-02 faktisk klippning, N-03 saknad och dubblerad mörk motpart, N-04 flertydig motpart, N-05 viewportartefakt utan profil, N-06 gridavvikelse vid 1920, N-07 avsiktligt scrollområde, N-08 line-clamp utan trunkering, N-09 deduplicering över metoder, N-10 fel enhet eller totalsumma. |
| CHK-R-07 | Gridmätning mot levande konsumenter | **not run** | 2 | — | 0 | 0 | — | DEV | kräver app-repot; ingår inte i specpaketets kedja. · flutter test test/gridmatning_test.dart mäter kolumnantal, kortbredd, gap, oanvänd bredd, overflow och maxbredd vid 1180, 1919, 1920 och 2048, samt hela trappan vid varje kategorigräns. |
| CHK-R-08 | Reproducerbarhet för mätbaslinjen | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver två genomförda renderingskörningar. · Två fullständiga rena körningar utan produktändringar måste ge identisk produktpopulation, probepopulation, detektioner, elementfynd, felinstanser, källrotorsaker, findingId:n och kontrollstatusar. Endast tids- och körnings-id-fält normaliseras. |
| CHK-I-01 | Ikongeometri mot viewBox | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kräver Chrome och riktig SVG-geometri; en textmatchning över bandata kan inte ge korrekta gränser. · Mäter varje inline-glyfs getBBox() i användarkoordinater mot dess egen viewBox och klassar utfallet som ok, utanfor, klippt, tom, ej-renderad eller verktygsfel. Fyra beständiga fixturer: 160-rutnätets geometri i en 24-viewBox ska fällas som utanfor, samma geometri med rättat fönster ska passera, geometri som skärs av fönstret ska fällas som klippt, och en glyf utan renderad geometri ska fällas som tom. |
| CHK-R-ID-01 | Entydig elementidentitet i R-03 | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kraver en genomford renderingskorning. · Redovisar legacy_collisions_st, stable_resolved_by_v2_st, candidate_only_st, ambiguous_st, verified_ambiguous_st och observation_ambiguous_st. Kontrollen ar RÖD sa lange verklig identitetsambiguitet finns, men verified_ambiguous_st ar sakerhetssignalen: sa lange den ar 0 ar R-03-fyndintegriteten opaverkad. Granskar om samma kanoniska elementKey betecknar flera olika DOM-noder inom samma artefakt, viewport, tema och textskala. Rapporterar unika_elementKeys_st, kolliderande_elementKeys_st, berorda_domnoder_st, verifierade_kollisioner_st, observationskollisioner_st och avsiktliga_kollisioner_st. Skiljer nyckelkollision fran samma nod sedd av flera metoder och fran forfader-barn-slaktskap — de tva senare ar inga kollisioner. Andrar aldrig hur findingId genereras. |
| CHK-R-T-01 | Triage av kvarvarande R-03-felinstanser | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kraver Chrome och en genomford renderingskorning. · Binder varje verifierad felinstans till faktisk kalla i markup och CSS, mater overskottet med tva oberoende signaler (scroll mot client, och barnens rektanglar i brakdelar), och skiljer symptomGroup fran sourceRootCause. En sourceRootCause far bara delas nar gemensam kod, komponent, token eller layoutregel ar belagd. Intentionalitet kraver positiv evidens; att CSS-raden anvander line-clamp, ellipsis eller overflow:hidden ar inget bevis. |
| CHK-R-E-01 | Adjudicerade anvandareffekter (R-03) | **not run** | 2 | — | 0 | 0 | — | DS | Fas 2 — kraver den committade triagen. · Parallellt lager ovanpa legacy-detektionen. Redovisar detectedLegacyInstances_st, adjudicatedEffects_st, productErrors_st, intentionalEffects_st och undecidedEffects_st. Tva legacy-instanser slas ihop till en effekt endast vid samma artefakt, samma element, samma sourceRootCause och samma uppmatta konsekvens i samma axel. Samma symptomsignatur racker aldrig. En oadjudicerad instans eller en saknad sourceRootCause faller rapporten; ingen grupp hittas pa. |
| CHK-K-01 | dart analyze | **not run** | 6 | — | 0 | 0 | — | DEV | kräver app-repot; ingår inte i specpaketets kedja. |
| CHK-K-02 | Enhetsprotokoll (B-43) | **not run** | 6 | — | 0 | 0 | — | DEV | kan inte köras före första implementerade etappen. Det är not run, inte not applicable — regeln säger att not applicable aldrig får användas för något som bara ännu inte körts. |
| CHK-ST-01 | Mutationsprov mot verifieraren (selftest) | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Varje prov muterar källan i minnet och kräver att rätt kontroll fäller. En kontroll som inte kan fällas mäter ingenting. |
| CHK-MT-01 | Metatester för verktygskedjan | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Prövar rapportlogiken själv: statusreducering, exitkod, GEN-01 i totalen, manifestets fällning, kaskadblockering, täckningsfel, wrapperns viktning och att inget runtimekontroll bär hårdkodad status. |
| CHK-T-19 | Markdown-tabelllint | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Fäller två tabellrader på samma källrad ('\|\|'), varnar för ojämnt kolumnantal. |
| CHK-GEN-02 | Incheckad genererad kod är aktuell (preflight) | **passed** | 1 | 1 | 0 | 0 | — | DEV | Körs FÖRE generatorerna och läser headerns tokenversion. T-15 mäter genererad output; GEN-01 mäter om körningen ändrade en incheckad fil; GEN-02 mäter om den incheckade filen var stale från början. Löses i Fas 1. |
| CHK-T-18a | Evidensmatrisens STRUKTUR (grindande) | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Tabellhuvud, kolumnantal och historikmarkörens placering. Strukturfel gör att kravrader inte parsas och alltså försvinner ur baslinjen — därför grindar den. |
| CHK-T-18b | Kravbaslinjens integritet (grindande) | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Okänd status och dubblerat krav-id gör kravbaslinjen tvetydig eller felräknad — det är integritetsfel, inte designskuld, och grindar därför tillsammans med T-18a. Fas 0.12. |
| CHK-GEN-01 | Genererade filer är incheckade (ingen drift) | **passed** | 0 | 1 | 0 | 0 | — | DEV | Jämför hash före och efter kedjan. Ändras en genererad fil av körningen var den incheckade versionen stale. |
| CHK-SC-01 | Rapportschemat (butlery-verify-report/2) | **passed** | 0 | 0,1 | 0 | 0 | — | DS | Rapporten valideras mot REPORT_SCHEMA vid varje körning; schemafilen genereras ur samma källa med tools/gen-schema.mjs. gate.mjs kör samma validering. |
| CHK-MF-01 | Manifestkontroll (fas0/check-manifest.mjs) | **not run** | 0 | 0,1 | 0 | 0 | — | DEV | kördes inte — verify.mjs anropades direkt i stället för via fas0/run-verify.sh · Körs av run-verify.sh FÖRE de muterande stegen. Status och antal kontrollerade filer skrivs in i rapporten av wrappern. |
| CHK-CI-01 | Verifieringskedjan körs i CI | **not run** | 0 | 0,1 | 0 | 0 | — | DEV | inget körbevis i fas0/ci-evidence.json — kedjan har inte körts i CI · Blockerar Fas 0-grinden enligt styrdokumentet. Status kommer ur fas0/ci-evidence.json, som CI-jobbet skriver — den är inte hårdkodad och kan bli passed av en verklig körning. |


## Kravstatus — räknad ur evidensmatrisens rader, aldrig skriven för hand

| Status | Antal |
|---|---|
| implementerad | **211** |
| verifierad | **85** |
| beslutad | **132** |
| ersatt | **1** |
| **totalt** | **429** |


## Mätvärden

| Nyckel | Värde |
|---|---|
| frames | [object Object] |
| items | [object Object] |
| controls | [object Object] |
| roles | [object Object] |
| hits | [object Object] |

## Statusordbok

**Statusordbok.** `passed` kördes och godkändes (varningar tillåtna, räknas separat) · `failed` kördes och fällde · `blocked` kördes, men mot en artefakt som en fallerad producent inte kunde skriva om — utfallet är en följd, inte ett självständigt fynd · `not run` kördes inte · `not applicable` kan inte gälla, med obligatorisk motivering och ägare. **Endast `passed` och `not applicable` uppfyller ett godkännandekriterium.**

**Tre resultatnivåer.** `pipelineResult` = verktygsstegen · `controlsResult` = kontrollregistret · `phaseGateResult` = kontroller i den aktuella fasens scope. `overallResult` kräver att alla tre är gröna, plus manifestet och GEN-01.
