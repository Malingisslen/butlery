#!/usr/bin/env node
// F2-E01 · NEGATIVA PROV för adjudiceringslagret.
//
// Kör: node tools/effect-fixtures.mjs [--out=<fil>]
//
// Proven matar den RIKTIGA adjudicera() med konstruerade triagefall. En regel
// som prövas mot en kopia av sig själv bevisar ingenting.

import { writeFileSync } from 'node:fs';
import { adjudicera } from './effect-adjudication.mjs';

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
const kör = instanser => adjudicera({ ...bas, instanser }, KARTA);

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

for (const r of resultat) console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const gröna = resultat.filter(r => r.ok).length;
console.log('EFFEKTPROV-SUMMARY status=' + (gröna === resultat.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + gröna + ' av ' + resultat.length);
const OUT = arg('out');
if (OUT) writeFileSync(OUT, JSON.stringify({ prov: resultat, gröna, av: resultat.length }, null, 1));
process.exit(gröna === resultat.length ? 0 : 1);
