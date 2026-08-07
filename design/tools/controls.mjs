// Butlery · kanoniskt kontrollregister.
//
// MASKIN-ID (Fas 0.10): varje kontroll bär ett DISJUNKT id med prefixet CHK-.
// Sjutton id kolliderade tidigare med krav-id — T-01 betydde både schemakoll och
// träffyta, K-01 både dart analyze och kontrastkrav, R-01 både renderad kontrast
// och 320-dp-layout. Kravsidan använder REQ-* (se evidensmatris.md).
// legacyId bevaras för läsbarhet i prosa och för äldre referenser.
//
// FAS 0-GRINDEN (Fas 0.10) omfattar ENDAST kontroller som bevisar att kedjan
// mäter rätt — manifestets integritet (MF-01), verifierarens egna prov (ST-01),
// rapportlogikens beteendeprov (MT-01), tabellintegritet (T-19) och att kedjan
// körts i CI (CI-01). Styrdokumentet säger att en röd baslinjekörning får passera
// Fas 0; därför bär INNEHÅLLSFYND (T-02, T-08, T-14, A11Y-*, LC-01 …)
// requiredForGate utan fasen och redovisas som baslinje med en resolutionPhase.
// De fäller totalen, men inte fasgrinden.
//
// FAS 1-GRINDEN (Fas 1, andra vändan) är EN KÄLLA-grinden. Den omfattar
//   · hela Fas 0-grinden — verktygsintegriteten får inte regressera, därför bär
//     de åtta Fas 0-kontrollerna requiredForGate: [0, 1],
//   · att källorna validerar: T-01 (tokens + brand-colors + app-theme-map mot
//     sina scheman),
//   · att ikonkontraktet och ikonräkningen håller: T-05, T-06a, T-06b,
//   · att versionstabellen mäter varje rad och att indexet stämmer med
//     generatorernas headrar: T-10, T-15,
//   · att den genererade koden svarar mot källan: TG-01, och att den incheckade
//     versionen varken var stale (GEN-02) eller ändrades av körningen (GEN-01).
// Innehållsbaslinjen (kontrast, träffytor, geometri, tillgänglighetsmetadata) står
// UTANFÖR också Fas 1-grinden och får fortfarande vara röd.
// Körs som: BUTLERY_PHASE=1 bash fas0/run-verify.sh && node tools/gate.mjs --phase=1
// EN källa för både verify-report.json och kontrollstatus.md.
// 'runtime' = status sätts av körningen · annars är status statisk med motivering.
export const CONTROLS = [
  { id: 'CHK-T-01', legacyId: 'T-01', resolutionPhase: 0, requiredForGate: [1], name: 'Tokens och mappningskällor mot JSON Schema', owner: 'DS', source: 'spec-lint',
    scope: 'Validerar tokens.json mot butlery-tokens.schema.json, assets/brand-colors.json mot sitt schema och tools/app-theme-map.json mot tools/app-theme-map.schema.json — samma validator (walkSchema) för alla tre. Fas 1: de två senare validerades inte av kedjan alls.' },
  { id: 'CHK-T-02', legacyId: 'T-02', resolutionPhase: 1, requiredForGate: [], name: 'Kontrastlint över deklarerade par', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-03', legacyId: 'T-03', resolutionPhase: 0, requiredForGate: [], name: 'Råfärgslint i spec-HTML (varning)', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-04', legacyId: 'T-04', resolutionPhase: 0, requiredForGate: [], name: 'Opacitetslint', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-05', legacyId: 'T-05', resolutionPhase: 1, requiredForGate: [1], name: 'Ikonlint — namn och masterfil', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-06a', legacyId: 'T-06a', resolutionPhase: 1, requiredForGate: [1], name: 'icons.json usages stämmer med källan', owner: 'DS', source: 'spec-lint',
    scope: 'Beroende av gen-icons: blockeras om generatorn faller.' },
  { id: 'CHK-T-06b', legacyId: 'T-06b', resolutionPhase: 1, requiredForGate: [1], name: 'assets-manifestets filreferenser finns på disk', owner: 'DS', source: 'spec-lint',
    scope: 'Oberoende av generatorerna — mäts alltid, även när gen-icons faller.' },
  { id: 'CHK-T-07', legacyId: 'T-07', resolutionPhase: 1, requiredForGate: [], name: 'Föråldrade versionsreferenser i dokument (varning)', owner: 'DS', source: 'spec-lint',
    scope: 'Söker "manual v1–v5", "0.620–0.624" och "Skarmar v10/v11" i skärmdokumenten. Rapporterar VARNINGAR, inte fel. Fas 0.12: registret sa tidigare att kontrollen täcker genererade filer — det gör den inte, det är GEN-02 och T-15.' },
  { id: 'CHK-T-08', legacyId: 'T-08', resolutionPhase: 3, requiredForGate: [], name: 'Träffyte- och rollint', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-09', legacyId: 'T-09', resolutionPhase: 0, requiredForGate: [], name: 'Syntaxlint per fil', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-10', legacyId: 'T-10', resolutionPhase: 0, requiredForGate: [1], name: 'Indexlint — versionstabellen', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-11', legacyId: 'T-11', resolutionPhase: 0, requiredForGate: [], name: 'Räkningslint', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-12', legacyId: 'T-12', resolutionPhase: 0, requiredForGate: [], name: 'Ankarlint — citerade ankare i prosa', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-13', legacyId: 'T-13', resolutionPhase: 2, requiredForGate: [], name: 'Avstängd text mot eget golv 3:1', owner: 'DS', source: 'rendered',
    status: 'not run', why: 'kräver renderad mätning i DOM (Fas 2). Textuell lint kan inte avgöra vilken yta tonen står på.' },
  { id: 'CHK-T-14', legacyId: 'T-14', resolutionPhase: 0, requiredForGate: [], name: 'Skärmbevis-kolumnen valideras', owner: 'DS', source: 'spec-lint',
    scope: 'Skilt från T-12: T-12 läser citerade ankare i prosa, T-14 läser evidensmatrisens Skärmbevis-kolumn.' },
  { id: 'CHK-T-15', legacyId: 'T-15', resolutionPhase: 0, requiredForGate: [1], name: 'Indexlint mäter HELA versionstabellen', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-16', legacyId: 'T-16', resolutionPhase: 0, requiredForGate: [], name: 'Ram-id kan inte kollidera — globalt', owner: 'DS', source: 'spec-lint',
    scope: 'Implementerad i Fas 0 under arbetsnamnet T-09b; id:t är T-16 enligt evidensmatrisen.' },
  { id: 'CHK-T-17', legacyId: 'T-17', resolutionPhase: 0, requiredForGate: [], name: 'Interna #-länkar pekar i samma fil', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-T-20', legacyId: 'T-20', resolutionPhase: 1, requiredForGate: [1], name: 'Källauktoriteten är maskinläsbar och konsistent', owner: 'DS', source: 'spec-lint',
    scope: 'Validerar source-authority.json mot sitt schema och kräver exakt EN aktiv auktoritet per domän, att varje deklarerad fil finns, att statusarna hör till ordboken, att kontrollstatusordboken är exakt de fem värdena och att supersededBy bildar ingen cykel. Registret i fas0/kallauktoritetsregister.md genereras ur filen. Fas 1: styrdokumentet krävde den maskinläsbara motsvarigheten, och till dess drev det handskrivna registret.' },
  // FAS 2-GRINDEN börjar här. T-21 bär requiredForGate: [2] — den fäller inte
  // Fas 1, som är stängd, men den är det första kriteriet Fas 2 måste uppfylla.
  { id: 'CHK-T-21', legacyId: 'T-21', resolutionPhase: 2, requiredForGate: [2], name: 'Artefaktklassificering (§ 5.1)', owner: 'DS', source: 'spec-lint', mustReport: true,
    scope: 'Jämför de artefakter som OBSERVERAS i skärmfilerna mot beslutsregistret artifacts.json och redovisar tre skilda felklasser: registerfel (saknad, extra, dubblerad post), datafel (ogiltigt värde mot vokabulären, eller ett beslut som motsäger observationen) och obeslutat (giltig post utan klassificeringsbeslut). Unikheten prövas på HELA variantnyckeln screenId · stateId · viewportClass · variantId — flera aktiva responsiva varianter av samma vy är legitima. En enhetsram är stark evidens för en viewport men aldrig ett auktoritetsbeslut: observationen ägs av maskinen, klassificeringen av en människa, och seed-verktyget skriver aldrig ett beslutat fält.' },
  { id: 'CHK-LC-01', legacyId: 'LC-01', resolutionPhase: 4, requiredForGate: [], name: 'Kontrollgeometri (lint-controls)', owner: 'DS', source: 'lint-controls' },
  { id: 'CHK-TG-01', legacyId: 'TG-01', resolutionPhase: 1, requiredForGate: [1], name: 'Genererad kod (test-generated)', owner: 'DEV', source: 'test-generated',
    scope: 'Prövar tokens.css och butlery_tokens.dart OCH — sedan Fas 1 — app_colors.dart och app_text_styles.dart mot tools/app-theme-map.json: varje mappad medlem, varje varumärkesfärg, varje alias INKLUSIVE dess högersida, varje typroll, varje typalias, varje semantisk variant och den publika ytan mot det frysta legacy-api-contract.json. En ändring i mappningsfilen som inte regenererats fäller kontrollen.' },
  { id: 'CHK-A11Y-01', legacyId: 'A11Y-01', resolutionPhase: 3, requiredForGate: [], name: 'Roll och namn på märkta kontroller', owner: 'DS', source: 'spec-lint' },
  { id: 'CHK-A11Y-02', legacyId: 'A11Y-02', resolutionPhase: 3, requiredForGate: [], name: 'Tillståndsmetadata på stateful kontroller', owner: 'DS', source: 'spec-lint',
    scope: 'Räknar dynamiskt i lint-core. Statusen kommer ur körningen — inga tal i registret. Kontrakten i Fas 3 gör fältet obligatoriskt.' },
  { id: 'CHK-R-01', legacyId: 'R-01', resolutionPhase: 2, requiredForGate: [], name: 'Renderad kontrast per fil', owner: 'DS', source: 'rendered', status: 'not run', why: 'Fas 2 — kräver DOM-rendering i CI.' },
  { id: 'CHK-R-02', legacyId: 'R-02', resolutionPhase: 2, requiredForGate: [], name: 'Renderad träffyta', owner: 'DS', source: 'rendered', status: 'not run', why: 'Fas 2 — kräver DOM-mätning; källdeklarationen är inte bevis.' },
  { id: 'CHK-R-03', legacyId: 'R-03', resolutionPhase: 2, requiredForGate: [], name: 'Overflow och klippning renderat', owner: 'DS', source: 'rendered', status: 'not run', why: 'Fas 2.' },
  { id: 'CHK-R-04', legacyId: 'R-04', resolutionPhase: 2, requiredForGate: [], name: 'Mörkt läge per vy', owner: 'DS', source: 'rendered', status: 'not run', why: 'Fas 2.' },
  { id: 'CHK-R-05', legacyId: 'R-05', resolutionPhase: 2, requiredForGate: [], name: 'Kanonisk R-03-analys med findingId och enhetsvalidering', owner: 'DS', source: 'rendered', status: 'not run',
    scope: 'Deduplicerar R-03a…d till ett fel per element och artefakt, klassar varje detektion som verifierad, avsiktlig, observation eller verktygsfel, och fäller på fel totalsumma eller tal utan enhetssuffix.',
    why: 'Fas 2 — kräver en genomförd renderingskörning.' },
  { id: 'CHK-R-06', legacyId: 'R-06', resolutionPhase: 2, requiredForGate: [], name: 'Beständiga negativa prov för renderingskedjan', owner: 'DS', source: 'rendered', status: 'not run',
    scope: 'Tio prov: N-01 observation utan klippning, N-02 faktisk klippning, N-03 saknad och dubblerad mörk motpart, N-04 flertydig motpart, N-05 viewportartefakt utan profil, N-06 gridavvikelse vid 1920, N-07 avsiktligt scrollområde, N-08 line-clamp utan trunkering, N-09 deduplicering över metoder, N-10 fel enhet eller totalsumma.',
    why: 'Fas 2 — kräver Chrome och en katalog utanför manifestytan.' },
  { id: 'CHK-R-07', legacyId: 'R-07', resolutionPhase: 2, requiredForGate: [], name: 'Gridmätning mot levande konsumenter', owner: 'DEV', source: 'external', status: 'not run',
    scope: 'flutter test test/gridmatning_test.dart mäter kolumnantal, kortbredd, gap, oanvänd bredd, overflow och maxbredd vid 1180, 1919, 1920 och 2048, samt hela trappan vid varje kategorigräns.',
    why: 'kräver app-repot; ingår inte i specpaketets kedja.' },
  { id: 'CHK-R-08', legacyId: 'R-08', resolutionPhase: 2, requiredForGate: [], name: 'Reproducerbarhet för mätbaslinjen', owner: 'DS', source: 'rendered', status: 'not run',
    scope: 'Två fullständiga rena körningar utan produktändringar måste ge identisk produktpopulation, probepopulation, detektioner, elementfynd, felinstanser, källrotorsaker, findingId:n och kontrollstatusar. Endast tids- och körnings-id-fält normaliseras.',
    why: 'Fas 2 — kräver två genomförda renderingskörningar.' },
  { id: 'CHK-I-01', legacyId: 'I-01', resolutionPhase: 2, requiredForGate: [], name: 'Ikongeometri mot viewBox', owner: 'DS', source: 'rendered', status: 'not run',
    scope: 'Mäter varje inline-glyfs getBBox() i användarkoordinater mot dess egen viewBox och klassar utfallet som ok, utanfor, klippt, tom, ej-renderad eller verktygsfel. Fyra beständiga fixturer: 160-rutnätets geometri i en 24-viewBox ska fällas som utanfor, samma geometri med rättat fönster ska passera, geometri som skärs av fönstret ska fällas som klippt, och en glyf utan renderad geometri ska fällas som tom.',
    why: 'Fas 2 — kräver Chrome och riktig SVG-geometri; en textmatchning över bandata kan inte ge korrekta gränser.' },
  { id: 'CHK-R-ID-01', legacyId: 'R-ID-01', resolutionPhase: 2, requiredForGate: [], name: 'Entydig elementidentitet i R-03', owner: 'DS', source: 'rendered', status: 'not run',
    scope: 'Redovisar legacy_collisions_st, stable_resolved_by_v2_st, candidate_only_st, ambiguous_st, verified_ambiguous_st och observation_ambiguous_st. Kontrollen ar RÖD sa lange verklig identitetsambiguitet finns, men verified_ambiguous_st ar sakerhetssignalen: sa lange den ar 0 ar R-03-fyndintegriteten opaverkad. Granskar om samma kanoniska elementKey betecknar flera olika DOM-noder inom samma artefakt, viewport, tema och textskala. Rapporterar unika_elementKeys_st, kolliderande_elementKeys_st, berorda_domnoder_st, verifierade_kollisioner_st, observationskollisioner_st och avsiktliga_kollisioner_st. Skiljer nyckelkollision fran samma nod sedd av flera metoder och fran forfader-barn-slaktskap — de tva senare ar inga kollisioner. Andrar aldrig hur findingId genereras.',
    why: 'Fas 2 — kraver en genomford renderingskorning.' },
  { id: 'CHK-K-01', legacyId: 'K-01', resolutionPhase: 6, requiredForGate: [], name: 'dart analyze', owner: 'DEV', source: 'external', status: 'not run', why: 'kräver app-repot; ingår inte i specpaketets kedja.' },
  { id: 'CHK-K-02', legacyId: 'K-02', resolutionPhase: 6, requiredForGate: [], name: 'Enhetsprotokoll (B-43)', owner: 'DEV', source: 'external', status: 'not run', why: 'kan inte köras före första implementerade etappen. Det är not run, inte not applicable — regeln säger att not applicable aldrig får användas för något som bara ännu inte körts.' },
  { id: 'CHK-ST-01', legacyId: 'ST-01', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Mutationsprov mot verifieraren (selftest)', owner: 'DS', source: 'selftest',
    scope: 'Varje prov muterar källan i minnet och kräver att rätt kontroll fäller. En kontroll som inte kan fällas mäter ingenting.' },
  { id: 'CHK-MT-01', legacyId: 'MT-01', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Metatester för verktygskedjan', owner: 'DS', source: 'metatest',
    scope: 'Prövar rapportlogiken själv: statusreducering, exitkod, GEN-01 i totalen, manifestets fällning, kaskadblockering, täckningsfel, wrapperns viktning och att inget runtimekontroll bär hårdkodad status.' },
  { id: 'CHK-T-19', legacyId: 'T-19', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Markdown-tabelllint', owner: 'DS', source: 'spec-lint',
    scope: 'Fäller två tabellrader på samma källrad (\'||\'), varnar för ojämnt kolumnantal.' },
  { id: 'CHK-GEN-02', legacyId: 'GEN-02', resolutionPhase: 1, requiredForGate: [1], name: 'Incheckad genererad kod är aktuell (preflight)', owner: 'DEV', source: 'preflight',
    scope: 'Körs FÖRE generatorerna och läser headerns tokenversion. T-15 mäter genererad output; GEN-01 mäter om körningen ändrade en incheckad fil; GEN-02 mäter om den incheckade filen var stale från början. Löses i Fas 1.' },
  { id: 'CHK-T-18a', legacyId: 'T-18a', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Evidensmatrisens STRUKTUR (grindande)', owner: 'DS', source: 'spec-lint',
    scope: 'Tabellhuvud, kolumnantal och historikmarkörens placering. Strukturfel gör att kravrader inte parsas och alltså försvinner ur baslinjen — därför grindar den.' },
  { id: 'CHK-T-18b', legacyId: 'T-18b', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Kravbaslinjens integritet (grindande)', owner: 'DS', source: 'spec-lint',
    scope: 'Okänd status och dubblerat krav-id gör kravbaslinjen tvetydig eller felräknad — det är integritetsfel, inte designskuld, och grindar därför tillsammans med T-18a. Fas 0.12.' },
  { id: 'CHK-GEN-01', legacyId: 'GEN-01', resolutionPhase: 0, requiredForGate: [1], name: 'Genererade filer är incheckade (ingen drift)', owner: 'DEV', source: 'wrapper',
    scope: 'Jämför hash före och efter kedjan. Ändras en genererad fil av körningen var den incheckade versionen stale.' },
  { id: 'CHK-SC-01', legacyId: 'SC-01', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Rapportschemat (butlery-verify-report/2)', owner: 'DS', source: 'schema',
    scope: 'Rapporten valideras mot REPORT_SCHEMA vid varje körning; schemafilen genereras ur samma källa med tools/gen-schema.mjs. gate.mjs kör samma validering.' },
  { id: 'CHK-MF-01', legacyId: 'MF-01', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Manifestkontroll (fas0/check-manifest.mjs)', owner: 'DEV', source: 'wrapper',
    scope: 'Körs av run-verify.sh FÖRE de muterande stegen. Status och antal kontrollerade filer skrivs in i rapporten av wrappern.' },
  { id: 'CHK-CI-01', legacyId: 'CI-01', resolutionPhase: 0, requiredForGate: [0, 1], name: 'Verifieringskedjan körs i CI', owner: 'DEV', source: 'ci-evidence',
    scope: 'Blockerar Fas 0-grinden enligt styrdokumentet. Status kommer ur fas0/ci-evidence.json, som CI-jobbet skriver — den är inte hårdkodad och kan bli passed av en verklig körning.' },
];
