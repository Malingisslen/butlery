#!/usr/bin/env node
// F2-E01 · NEGATIVA PROV för adjudiceringslagret.
//
// Kör: node tools/effect-fixtures.mjs [--out=<fil>]
//
// Proven matar den RIKTIGA adjudicera() med konstruerade triagefall. En regel
// som prövas mot en kopia av sig själv bevisar ingenting.

import { writeFileSync } from 'node:fs';
import { adjudicera, affordansbevis } from './effect-adjudication.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];

const KARTA = { sourceRootCauses: [{ id: 'SRC-X' }, { id: 'SRC-Y' }], runtimejamforelse: [] };
const bas = {
  population: { raa_verifierade_detektioner_st: 0, elementfynd_st: 0,
    felinstanser_fore_analys_st: 0, kanoniska_legacy_kallrotorsaker_st: 0, berorda_produktartefakter_st: 0 }
};
const inst = (o) => ({
  artifactId: 'A', instansId: 'INST · A · sel:div>div[0] · klippning',
  findingIds: ['F1'], element: 'div', symptomGroup: 'div · klippning',
  faktisk_overflow: { axel: 'y', scroll_minus_client_px: 20, barn_utanfor_brakdel: [] },
  sourceRootCause: 'SRC-X', intentionality: 'unintended', intentionality_skal: 'prov',
  identityV2_status: 'stable', ...o
});
const kör = (instanser, reg = null) => adjudicera({ ...bas, instanser }, KARTA, reg);

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* E-01 · två symptom, samma element, SAMMA effekt → ett effectId */
{
  const r = kör([
    inst({ symptomGroup: 'div · klippning', findingIds: ['F1'] }),
    inst({ instansId: 'INST · A · sel:div>div[0] · textrunkering',
           symptomGroup: 'div · textrunkering', findingIds: ['F2'] })
  ]);
  prov('E-01', 'två symptom på samma element med samma konsekvens ger ETT effectId',
    r.adjudicatedEffects_st === 1 && r.effects[0].legacyInstansIds.length === 2 &&
    r.effects[0].sammanslagen === true && r.effects[0].findingIds.length === 2,
    'effekter: ' + r.adjudicatedEffects_st + ' · legacy per effekt: ' +
    r.effects.map(e => e.legacyInstansIds.length).join(',') +
    ' · grund: ' + (r.effects[0].sammanslagningsgrund || '—').slice(0, 60));
}

/* E-02 · två symptom, samma element, SJÄLVSTÄNDIGA effekter → två effectId */
{
  // Boxen klipps 40 px vertikalt; texten trunkeras 19 px horisontellt. Samma
  // element, men två skilda konsekvenser — olika axel och olika storlek.
  const r = kör([
    inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 40, barn_utanfor_brakdel: [] } }),
    inst({ instansId: 'INST · A · sel:div>div[0] · textrunkering',
           symptomGroup: 'div · textrunkering', findingIds: ['F2'],
           faktisk_overflow: { axel: 'x', scroll_minus_client_px: 19, barn_utanfor_brakdel: [] } })
  ]);
  prov('E-02', 'två självständiga konsekvenser på samma element ger TVÅ effectId',
    r.adjudicatedEffects_st === 2 && r.effects.every(e => e.legacyInstansIds.length === 1),
    'effekter: ' + r.adjudicatedEffects_st + ' · axlar: ' +
    r.effects.map(e => e.matt.axel + '/' + e.matt.scroll_minus_client_px).join(', '));
}

/* E-03 · samma symptom i två artefakter med gemensam källa → två effectId */
{
  const r = kör([
    inst({ artifactId: 'A' }),
    inst({ artifactId: 'B', instansId: 'INST · B · sel:div>div[0] · klippning', findingIds: ['F2'] })
  ]);
  prov('E-03', 'samma symptom och samma källa i två artefakter ger TVÅ effectId',
    r.adjudicatedEffects_st === 2 &&
    new Set(r.effects.map(e => e.sourceRootCauseId)).size === 1 &&
    new Set(r.effects.map(e => e.artifactId)).size === 2,
    'effekter: ' + r.adjudicatedEffects_st + ' · artefakter: ' +
    r.effects.map(e => e.artifactId).join(',') + ' · delad källa: ' +
    [...new Set(r.effects.map(e => e.sourceRootCauseId))].join(','));
}

/* E-04 · intentional räknas inte som productError */
{
  const r = kör([inst({ intentionality: 'intentional', intentionality_skal: 'dokumenterad i evidensmatris.md' })]);
  prov('E-04', 'en intentional effekt räknas ALDRIG som produktfel',
    r.adjudicatedEffects_st === 1 && r.productErrors_st === 0 && r.intentionalEffects_st === 1 &&
    typeof r.effects[0].intentionalityEvidence === 'string',
    'productErrors: ' + r.productErrors_st + ' · intentional: ' + r.intentionalEffects_st +
    ' · evidens bärs: ' + (typeof r.effects[0].intentionalityEvidence === 'string'));
}

/* E-05 · undecided räknas inte som productError */
{
  const r = kör([inst({ intentionality: 'undecided', intentionality_skal: 'signalerna motsäger varandra' })]);
  prov('E-05', 'en undecided effekt räknas ALDRIG som produktfel',
    r.adjudicatedEffects_st === 1 && r.productErrors_st === 0 && r.undecidedEffects_st === 1,
    'productErrors: ' + r.productErrors_st + ' · undecided: ' + r.undecidedEffects_st);
}

/* E-06 · legacy-instans utan adjudicering → fail closed */
{
  const r = kör([inst({}), inst({ instansId: 'INST · A · sel:div>div[9] · klippning',
    findingIds: ['F9'], intentionality: null })]);
  prov('E-06', 'en oadjudicerad legacy-instans fäller effektrapporten',
    r.failClosed.status === 'FÄLLD' && r.failClosed.fel.some(f => /ADJUDICERING SAKNAS/.test(f)) &&
    r.adjudicatedEffects_st === 1,
    'status: ' + r.failClosed.status + ' · effekter skapade: ' + r.adjudicatedEffects_st +
    ' · ' + (r.failClosed.fel[0] || '').slice(0, 70));
}

/* E-07 · saknad sourceRootCause → ingen påhittad grupp */
{
  const r = kör([inst({ sourceRootCause: 'SRC-FINNS-INTE' }),
                 inst({ instansId: 'INST · A · sel:div>div[7] · klippning', findingIds: ['F7'], sourceRootCause: null })]);
  prov('E-07', 'saknad eller okänd sourceRootCause ger INGEN effekt och ingen påhittad grupp',
    r.adjudicatedEffects_st === 0 && r.failClosed.status === 'FÄLLD' &&
    r.failClosed.fel.filter(f => /KÄLLA SAKNAS/.test(f)).length === 2,
    'effekter: ' + r.adjudicatedEffects_st + ' · fel: ' +
    r.failClosed.fel.filter(f => /KÄLLA SAKNAS/.test(f)).length);
}

/* E-08 · runtimeavvikelse gör inte en effekt unintended */
{
  const karta = { sourceRootCauses: [{ id: 'SRC-X' }],
    runtimejamforelse: [{ source: 'SRC-X', designArtifactResult: 'd', runtimeImplementationResult: 'r',
      slutsats: 'RITNINGEN OCH IMPLEMENTATIONEN SKILJER SIG.' }] };
  const r = adjudicera({ ...bas, instanser: [inst({ intentionality: 'undecided' })] }, karta);
  prov('E-08', 'en skillnad mot runtime sätter aldrig automatiskt unintended',
    r.effects[0].designRuntimeDeviation === true &&
    r.effects[0].adjudicationStatus === 'undecided' && r.productErrors_st === 0,
    'designRuntimeDeviation: ' + r.effects[0].designRuntimeDeviation +
    ' · status: ' + r.effects[0].adjudicationStatus + ' · productErrors: ' + r.productErrors_st);
}

/* E-09 · effectId får inte bygga på arrayordning ────────────────────────── */
{
  // Tre effekter, register som pinnar dem till 1, 2 och 3. Ta bort den första
  // och kräv att de kvarvarande behåller sina nummer.
  const mk = (a, px) => inst({ artifactId: a, instansId: 'INST · ' + a + ' · sel:div>div[0] · klippning',
    findingIds: [a], faktisk_overflow: { axel: 'y', scroll_minus_client_px: px, barn_utanfor_brakdel: [] } });
  const alla = [mk('A', 10), mk('B', 20), mk('C', 30)];
  const utanReg = kör(alla);
  const reg = { version: '1.0', nextOrdinal: 4, tilldelningar: {} };
  for (let i = 0; i < utanReg.effects.length; i++)
    reg.tilldelningar[utanReg.effects[i].effektnyckel || Object.keys(reg.tilldelningar).length] = {
      ordinal: i + 1, effectId: 'EFF-0' + (i + 1) + ' · ' + utanReg.effects[i].artifactId };
  const medReg = kör(alla, reg);
  const efterBort = kör(alla.slice(1), reg);
  const utanRegEfter = kör(alla.slice(1));
  prov('E-09', 'effectId hämtas ur registret och renumreras aldrig när populationen krymper',
    medReg.effects.map(e => e.effectId).join(',') === 'EFF-01 · A,EFF-02 · B,EFF-03 · C' &&
    efterBort.effects.map(e => e.effectId).join(',') === 'EFF-02 · B,EFF-03 · C' &&
    utanRegEfter.effects.map(e => e.effectId).join(',') === 'EFF-01 · B,EFF-02 · C',
    'med register efter borttagning: ' + efterBort.effects.map(e => e.effectId).join(', ') +
    ' · UTAN register (det gamla felet): ' + utanRegEfter.effects.map(e => e.effectId).join(', '));
}

/* E-10 · ett frigjort nummer återanvänds aldrig ──────────────────────────── */
{
  const mk = (a, px) => inst({ artifactId: a, instansId: 'INST · ' + a + ' · sel:div>div[0] · klippning',
    findingIds: [a], faktisk_overflow: { axel: 'y', scroll_minus_client_px: px, barn_utanfor_brakdel: [] } });
  const bas3 = [mk('A', 10), mk('B', 20)];
  const utanReg = kör(bas3);
  const reg = { version: '1.0', nextOrdinal: 3, tilldelningar: {} };
  utanReg.effects.forEach((e, i) => { reg.tilldelningar[e.effektnyckel] = { ordinal: i + 1, effectId: 'EFF-0' + (i + 1) + ' · ' + e.artifactId }; });
  // A rättas bort och en HELT NY effekt tillkommer. Den får 03, aldrig 01.
  const efter = kör([mk('B', 20), mk('D', 40)], reg);
  const ny = efter.effects.find(e => e.artifactId === 'D');
  prov('E-10', 'en ny effekt får nästa lediga nummer och aldrig ett frigjort',
    ny && ny.effectId === 'EFF-03 · D' &&
    efter.effects.find(e => e.artifactId === 'B').effectId === 'EFF-02 · B' &&
    efter.idTilldelning.nytilldelade.length === 1,
    'ny effekt: ' + (ny ? ny.effectId : '—') + ' · överlevare: ' +
    efter.effects.find(e => e.artifactId === 'B').effectId +
    ' · nytilldelade: ' + efter.idTilldelning.nytilldelade.length);
}

/* E-11…E-14 · magnitudoberoende identitet ─────────────────────────────────── */
const mkReg = (instanser) => {
  const u = kör(instanser);
  const r = { version: '2.0', nextOrdinal: u.effects.length + 1, tilldelningar: {} };
  u.effects.forEach((e, i) => { r.tilldelningar[e.effektnyckel] =
    { ordinal: i + 1, effectId: 'EFF-0' + (i + 1) + ' · ' + e.artifactId }; });
  return r;
};

{ // E-11 · samma effekt, olika uppmätt storlek → samma effectId
  const a = inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 2, barn_utanfor_brakdel: [] } });
  const b = inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 3, barn_utanfor_brakdel: [] } });
  const reg = mkReg([a]);
  const kA = kör([a], reg), kB = kör([b], reg);
  prov('E-11', 'samma effekt med 2 px i en körning och 3 px i en annan får SAMMA effectId',
    kA.effects[0].effectId === kB.effects[0].effectId &&
    kA.effects[0].effektnyckel === kB.effects[0].effektnyckel &&
    !kA.effects[0].effektnyckel.includes('px='),
    'A: ' + kA.effects[0].effectId + ' · B: ' + kB.effects[0].effectId +
    ' · nyckeln bär storlek: ' + kA.effects[0].effektnyckel.includes('px=')); }

{ // E-12 · självständiga konsekvenser på olika axlar → två effectId
  const r = kör([
    inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 40, barn_utanfor_brakdel: [] } }),
    inst({ instansId: 'INST · A · sel:div>div[0] · textrunkering', findingIds: ['F2'],
           faktisk_overflow: { axel: 'x', scroll_minus_client_px: 19, barn_utanfor_brakdel: [] } })
  ]);
  prov('E-12', 'samma artefakt, element och källa men olika axlar ger TVÅ effectId',
    r.adjudicatedEffects_st === 2 &&
    new Set(r.effects.map(e => e.matt.axel)).size === 2,
    'effekter: ' + r.adjudicatedEffects_st + ' · axlar: ' + r.effects.map(e => e.matt.axel).join(',')); }

{ // E-13 · ändrad text och geometri, oförändrad semantisk identitet → samma id
  const a = inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 20, barn_utanfor_brakdel: [] } });
  const b = inst({ text: 'en helt annan text', faktisk_overflow: { axel: 'y', scroll_minus_client_px: 47.5, barn_utanfor_brakdel: [{ tag: 'div', underKant_px: 47.5 }] } });
  const reg = mkReg([a]);
  const kA = kör([a], reg), kB = kör([b], reg);
  prov('E-13', 'ändrad text och geometri men oförändrad effektidentitet ger SAMMA effectId',
    kA.effects[0].effectId === kB.effects[0].effectId &&
    kA.effects[0].matt.scroll_minus_client_px !== kB.effects[0].matt.scroll_minus_client_px,
    'id: ' + kB.effects[0].effectId + ' · storlek ' + kA.effects[0].matt.scroll_minus_client_px +
    ' → ' + kB.effects[0].matt.scroll_minus_client_px + ' px'); }

{ // E-14 · verkligt ny effekt på samma element → nytt nummer, aldrig återanvänt
  const gammal = inst({ faktisk_overflow: { axel: 'y', scroll_minus_client_px: 20, barn_utanfor_brakdel: [] } });
  const reg = mkReg([gammal]);
  reg.nextOrdinal = 2;
  const ny = inst({ instansId: 'INST · A · sel:div>div[0] · textrunkering', findingIds: ['F9'],
    sourceRootCause: 'SRC-Y',
    faktisk_overflow: { axel: 'x', scroll_minus_client_px: 12, barn_utanfor_brakdel: [] } });
  const r = kör([ny], reg);   // den gamla effekten är borta, en ny har tillkommit
  prov('E-14', 'en verkligt ny effekt på samma element får nytt nummer, aldrig ett återanvänt',
    r.effects.length === 1 && r.effects[0].effectId === 'EFF-02 · A' &&
    r.idTilldelning.nytilldelade.length === 1,
    'ny effekt: ' + r.effects[0].effectId + ' · nytilldelade: ' + r.idTilldelning.nytilldelade.length +
    ' (det frigjorda 01 återanvänds inte)'); }


/* E-15…E-20 · preview med affordans skild från dold text utan affordans ──── */
const AFF = {
  collapsedState: true, avsiktligPreview: true, expandControl: true,
  controlRollNamnState: true, controlNabar: true, expandedArtifact: true,
  sammaLogiskaInnehall: true, fulltextNabar: true
};
const mkPrev = (o = {}) => inst({ sourceRootCause: 'SRC-02',
  instansId: 'INST · A · sel:div>div[0] · klippning',
  faktisk_overflow: { axel: 'y', scroll_minus_client_px: 52, barn_utanfor_brakdel: [] }, ...o });
const KARTA_P = { sourceRootCauses: [{ id: 'SRC-02' }], runtimejamforelse: [] };
const körP = (i, reg = null) => adjudicera({ ...bas, instanser: i }, KARTA_P, reg);

{ // E-15 · klippt element UTAN affordans
  const r = körP([mkPrev()]);
  prov('E-15', 'klippt preview utan affordans behåller innehall-dolt-utan-affordans',
    r.effects.length === 1 && /innehall-dolt-utan-affordans/.test(r.effects[0].effektnyckel),
    'nyckel: ' + (r.effects[0] || {}).effektnyckel); }

{ // E-16 · samma element MED verifierad affordans
  const r = körP([mkPrev({ previewAffordance: AFF })]);
  prov('E-16', 'verifierad collapsed-preview med fungerande expanded ger begransad-preview-med-affordans',
    r.effects.length === 1 && /begransad-preview-med-affordans/.test(r.effects[0].effektnyckel),
    'nyckel: ' + (r.effects[0] || {}).effektnyckel); }

{ // E-17 · samma artefakt/element/källa/axel men olika klass → olika nyckel
  const utan = körP([mkPrev()]).effects[0].effektnyckel;
  const med = körP([mkPrev({ previewAffordance: AFF })]).effects[0].effektnyckel;
  const bara = (a, b) => a.split(' ‖ ').filter((x, i) => x !== b.split(' ‖ ')[i]);
  prov('E-17', 'klassbytet, inte listordningen, skapar den nya identiteten',
    utan !== med && bara(utan, med).length === 1 && /klass=/.test(bara(utan, med)[0]),
    'enda skillnaden i nyckeln: ' + JSON.stringify(bara(utan, med))); }

{ // E-18 · ändrat stateId utan ändrad effektsemantik
  const a = mkPrev({ stateId: 'kollapsad' });
  const b = mkPrev({ stateId: 'nagot-annat' });
  prov('E-18', 'ändrat stateId skapar varken ny effectClass eller ny effectId',
    körP([a]).effects[0].effektnyckel === körP([b]).effects[0].effektnyckel,
    'nyckel oförändrad: ' + (körP([a]).effects[0].effektnyckel === körP([b]).effects[0].effektnyckel)); }

{ // E-19 · etikett finns men expanded saknas → fail closed
  const halv = { ...AFF, expandedArtifact: false, fulltextNabar: false };
  const r = körP([mkPrev({ previewAffordance: halv })]);
  const b = affordansbevis({ previewAffordance: halv });
  prov('E-19', 'kontroll utan verifierat expanded-state ger INTE preview-med-affordans',
    /innehall-dolt-utan-affordans/.test(r.effects[0].effektnyckel) &&
    b.verifierad === false && b.saknade.length === 2,
    'klass: innehall-dolt-utan-affordans · saknade led: ' + JSON.stringify(b.saknade)); }

{ // E-20 · verifierat par kan adjudiceras intentional
  const r = körP([mkPrev({ previewAffordance: AFF, intentionality: 'intentional',
    intentionality_skal: 'normativt previewbeslut + verifierat state-par' })]);
  prov('E-20', 'verifierat collapsed/expanded-par kan adjudiceras intentional',
    r.intentionalEffects_st === 1 && r.productErrors_st === 0 &&
    /begransad-preview-med-affordans/.test(r.effects[0].effektnyckel),
    'intentional: ' + r.intentionalEffects_st + ' · produktfel: ' + r.productErrors_st); }

{ // E-21 · registret ger nästa aldrig använda ordinal, muterar aldrig det gamla
  const gammal = körP([mkPrev()]);
  const reg = { version: '2.0', nextOrdinal: 6, tilldelningar: {} };
  reg.tilldelningar[gammal.effects[0].effektnyckel] = { ordinal: 5, effectId: 'EFF-05 · A' };
  const ny = körP([mkPrev({ previewAffordance: AFF })], reg);
  prov('E-21', 'ny semantisk nyckel får nästa oanvända ordinal, gamla 05 muteras inte',
    ny.effects[0].effectId === 'EFF-06 · A' &&
    reg.tilldelningar[gammal.effects[0].effektnyckel].ordinal === 5 &&
    ny.idTilldelning.nytilldelade.length === 1,
    'ny effectId: ' + ny.effects[0].effectId + ' · gammal ordinal orörd: ' +
    (reg.tilldelningar[gammal.effects[0].effektnyckel].ordinal === 5)); }

for (const r of resultat) console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const gröna = resultat.filter(r => r.ok).length;
console.log('EFFEKTPROV-SUMMARY status=' + (gröna === resultat.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + gröna + ' av ' + resultat.length);
const OUT = arg('out');
if (OUT) writeFileSync(OUT, JSON.stringify({ prov: resultat, gröna, av: resultat.length }, null, 1));
process.exit(gröna === resultat.length ? 0 : 1);
