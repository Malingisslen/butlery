#!/usr/bin/env node
// F2-R07 · REPRODUCERBARHET för mätbaslinjen.
//
// Kör: node tools/render-repro.mjs --a=<körning1> --b=<körning2> [--out=<fil>]
//
// Två fullständiga rena körningar utan produktändringar måste ge IDENTISKT
// resultat på allt som är ett resultat. Bara legitima tids- och körnings-id-fält
// normaliseras bort — och de räknas upp uttryckligen här, så att listan inte
// tyst kan växa tills den döljer en verklig skillnad.

import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { detektionerAv, elementfynd, felinstanser, källrotorsaker, METODER, KLASSER }
  from './render-analyze-lib.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const A = arg('a'), B = arg('b'), OUT = arg('out');
if (!A || !B) { console.error('✖ ange --a=<render-raw.json> --b=<render-raw.json>'); process.exit(2); }

// De ENDA fält som får skilja mellan två körningar.
const NORMALISERAS = ['runId', 'startedAt', 'finishedAt', 'durationMs', 'timestamp', 'out', 'pid'];

const sha = v => createHash('sha256').update(JSON.stringify(v)).digest('hex').slice(0, 16);

function extrahera(fil) {
  const D = JSON.parse(readFileSync(fil, 'utf8'));
  const idProdukt = new Set(), idProbe = new Set();
  for (const r of D.results) for (const a of r.artifacts) (r.probe ? idProbe : idProdukt).add(a.id);
  const probeEndast = [...idProbe].filter(x => !idProdukt.has(x));

  const produktDet = [], probeDet = [];
  for (const r of D.results) {
    const ctx = { fall: r.probe ? 'PROB-' + r.probe.width : r.profile.id,
                  viewport: r.probe ? 'prob-' + r.probe.width : r.profile.id,
                  theme: 'obeslutad', textScale: '1.0' };
    for (const a of r.artifacts)
      (r.probe && probeEndast.includes(a.id) ? probeDet : produktDet).push(...detektionerAv(a, ctx));
  }
  const fynd = elementfynd(produktDet, 'verifierad');
  const inst = felinstanser(fynd);
  const rot = källrotorsaker(inst);

  const perMetod = {};
  for (const m of METODER) {
    const d = produktDet.filter(x => x.metod === m);
    perMetod[m] = { detektioner_st: d.length };
    for (const k of KLASSER) perMetod[m][k + '_st'] = d.filter(x => x.klass === k).length;
  }

  return {
    produktpopulation: [...idProdukt].sort(),
    probepopulation: probeEndast.sort(),
    detektioner: perMetod,
    probedetektioner_st: probeDet.length,
    findingIds: fynd.map(f => f.findingId).sort(),
    elementfynd_st: fynd.length,
    felinstanser: inst.map(i => i.instansId).sort(),
    felinstanser_st: inst.length,
    källrotorsaker: rot.map(g => g.signatur + ' ×' + g.felinstanser_st).sort(),
    källrotorsaker_st: rot.length,
    kontrollstatus: {
      fall_planerade_st: D.plannedCases, fall_körda_st: D.ranCases,
      fall_misslyckade_st: D.failedCases, verktygsfel_st: (D.toolErrors || []).length,
      artefaktmätningar_st: D.measured
    }
  };
}

const a = extrahera(A), b = extrahera(B);

const NYCKLAR = ['produktpopulation', 'probepopulation', 'detektioner', 'probedetektioner_st',
  'findingIds', 'elementfynd_st', 'felinstanser', 'felinstanser_st',
  'källrotorsaker', 'källrotorsaker_st', 'kontrollstatus'];

const skillnader = [];
for (const k of NYCKLAR) {
  const ha = sha(a[k]), hb = sha(b[k]);
  if (ha !== hb) {
    let detalj = '';
    if (Array.isArray(a[k])) {
      const bara_a = a[k].filter(x => !b[k].includes(x)).slice(0, 5);
      const bara_b = b[k].filter(x => !a[k].includes(x)).slice(0, 5);
      detalj = ' · bara i A: ' + JSON.stringify(bara_a) + ' · bara i B: ' + JSON.stringify(bara_b);
    } else {
      detalj = ' · A=' + JSON.stringify(a[k]).slice(0, 200) + ' · B=' + JSON.stringify(b[k]).slice(0, 200);
    }
    skillnader.push(k + ': ' + ha + ' ≠ ' + hb + detalj);
  }
}

const rapport = {
  $regel: 'Två rena körningar utan produktändringar. Allt som är ett resultat måste vara identiskt.',
  normaliserade_fält: NORMALISERAS,
  $normaliseringsnot: 'Endast tids- och körnings-id-fält normaliseras. Inget resultatfält står i listan.',
  körning_a: A, körning_b: B,
  jämförda_nycklar: NYCKLAR,
  hashar: Object.fromEntries(NYCKLAR.map(k => [k, { a: sha(a[k]), b: sha(b[k]), lika: sha(a[k]) === sha(b[k]) }])),
  sammanfattning: {
    produktartefakter_st: a.produktpopulation.length,
    probeartefakter_st: a.probepopulation.length,
    elementfynd_st: a.elementfynd_st,
    felinstanser_st: a.felinstanser_st,
    källrotorsaker_st: a.källrotorsaker_st
  },
  skillnader,
  status: skillnader.length ? 'EJ REPRODUCERBAR' : 'reproducerbar'
};

if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1));
console.log('REPRO status=' + rapport.status +
  ' nycklar=' + NYCKLAR.length + ' lika=' + (NYCKLAR.length - skillnader.length) +
  ' | produkt=' + a.produktpopulation.length + ' probe=' + a.probepopulation.length +
  ' elementfynd=' + a.elementfynd_st + ' felinstanser=' + a.felinstanser_st +
  ' rotorsaker=' + a.källrotorsaker_st);
for (const d of skillnader) console.log('  ✖ ' + d);
process.exit(skillnader.length ? 1 : 0);
