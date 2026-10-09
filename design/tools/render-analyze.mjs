#!/usr/bin/env node
// F2-R05 · Kanonisk R-03-analys med fyra skilda fyndnivåer.
//
// Kör: node tools/render-analyze.mjs --raw=<render-raw.json> [--out=<fil>]
//
// TRE POPULATIONER, aldrig sammanblandade:
//   registrerade_produktartefakter_st   309  ← nämnare för ALLA produkttal
//   probeartefakter_st                    3  ← test- och probeytan
//   totalt_exekverade_artefakter_st     312  ← ren exekveringsdiagnostik
//
// FYRA FYNDNIVÅER, som aldrig summeras ihop:
//   råa detektioner · elementfynd · felinstanser · källrotorsaker

import { readFileSync, writeFileSync } from 'node:fs';
import { METODER, KLASSER, detektionerAv, elementfynd, felinstanser,
         källrotorsaker, validera } from './render-analyze-lib.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const RAW = arg('raw');
const OUT = arg('out');
if (!RAW) { console.error('✖ ange --raw=<render-raw.json>'); process.exit(2); }

const D = JSON.parse(readFileSync(RAW, 'utf8'));

/* ── Populationer ────────────────────────────────────────────────────────── */
const idProdukt = new Set(), idProbe = new Set();
for (const r of D.results) for (const a of r.artifacts) (r.probe ? idProbe : idProdukt).add(a.id);
const probeEndast = [...idProbe].filter(x => !idProdukt.has(x));
const populationer = {
  $regel: 'Produktens kontrollresultat och täckningsgrader använder ALLTID registrerade_produktartefakter_st som nämnare. Probeartefakterna ligger i en egen sektion och blandas aldrig in i produktens compliance-tal.',
  registrerade_produktartefakter_st: idProdukt.size,
  probeartefakter_st: probeEndast.length,
  probeartefakter: probeEndast,
  totalt_exekverade_artefakter_st: idProdukt.size + probeEndast.length
};

/* ── Nivå 1 · råa detektioner, uppdelat på population ────────────────────── */
const produktDet = [], probeDet = [];
let kapade = 0;
for (const r of D.results) {
  const ctx = { fall: r.probe ? 'PROB-' + r.probe.width : r.profile.id,
                viewport: r.probe ? 'prob-' + r.probe.width : r.profile.id,
                theme: 'obeslutad', textScale: '1.0' };
  for (const a of r.artifacts) {
    if (a.kapad) kapade++;
    const d = detektionerAv(a, ctx);
    (r.probe && probeEndast.includes(a.id) ? probeDet : produktDet).push(...d);
  }
}

const perMetod = det => {
  const ut = {};
  for (const m of METODER) {
    const d = det.filter(x => x.metod === m);
    ut[m] = { detektioner_st: d.length };
    for (const k of KLASSER) {
      const dk = d.filter(x => x.klass === k);
      ut[m][k + '_detektioner_st'] = dk.length;
      ut[m][k + '_produktartefakter_st'] = new Set(dk.map(x => x.artefakt)).size;
    }
  }
  return ut;
};

/* ── Nivå 2, 3 och 4 · endast produktpopulationen ────────────────────────── */
const verifieradeFynd = elementfynd(produktDet, 'verifierad');
const avsiktligaFynd = elementfynd(produktDet, 'avsiktlig');
const observationsfynd = elementfynd(produktDet, 'observation');
const verktygsfelFynd = elementfynd(produktDet, 'verktygsfel');

const instanser = felinstanser(verifieradeFynd);
const rotorsaker = källrotorsaker(instanser);

const metodkombinationer = {};
for (const f of verifieradeFynd) {
  const k = f.evidens.metoder.join('+');
  metodkombinationer[k] = (metodkombinationer[k] || 0) + 1;
}

/* ── Rapport ─────────────────────────────────────────────────────────────── */
const rapport = {
  $enhetsregel: 'Varje tal bär sin enhet i nyckelnamnet. _st = antal, _detektioner_st = metodträffar, _elementfynd_st = distinkta element med fel, _felinstanser_st = användarsynliga fel, _källrotorsaker_st = gemensamma källor, _produktartefakter_st = distinkta registrerade ritningar.',
  $nivåregel: 'De fyra nivåerna summeras aldrig ihop och byter aldrig namn. En rå detektion är en metodträff. Ett elementfynd är ett element med ett fel. En felinstans är ett användarsynligt fel i en ritning. En källrotorsak är en gemensam källa bakom felinstanser i flera ritningar.',
  chrome: D.chrome, dpr: D.dpr, kontrakt: D.contractVersion,
  fall: { planerade_st: D.plannedCases, körda_st: D.ranCases, misslyckade_st: D.failedCases },
  artefaktmätningar_st: D.measured,
  kapade_artefakter_st: kapade,
  populationer,

  produkt: {
    $nämnare: populationer.registrerade_produktartefakter_st,
    raa_detektioner_per_metod: perMetod(produktDet),
    nivåer: {
      raa_detektioner_st: produktDet.filter(d => d.klass === 'verifierad').length,
      elementfynd_st: verifieradeFynd.length,
      felinstanser_st: instanser.length,
      källrotorsaker_st: rotorsaker.length,
      berörda_produktartefakter_st: new Set(instanser.map(i => i.artefakt)).size,
      $not: 'Alla fyra avser klassen verifierad. Observationer, avsiktliga och verktygsfel redovisas separat och blandas aldrig in.'
    },
    övriga_klasser: {
      avsiktliga_elementfynd_st: avsiktligaFynd.length,
      observations_elementfynd_st: observationsfynd.length,
      observations_produktartefakter_st: new Set(observationsfynd.map(f => f.artefakt)).size,
      verktygsfel_elementfynd_st: verktygsfelFynd.length
    },
    bekräftande_metodkombinationer_elementfynd_st: metodkombinationer,
    elementnyckelgrund_st: verifieradeFynd.reduce((a, f) => {
      a[f.keyBasis] = (a[f.keyBasis] || 0) + 1; return a; }, {}),
    felinstanser: instanser,
    verifierade_elementfynd: verifieradeFynd.map(f => ({
      findingId: f.findingId, artefakt: f.artefakt, element: f.element,
      elementKey: f.elementKey, keyBasis: f.keyBasis, subtype: f.subtype, axis: f.axis,
      evidens: f.evidens, why: f.why })),
    källrotorsaker: rotorsaker,
    verktygsfel_detalj: verktygsfelFynd
  },

  probe: {
    $regel: 'Test- och probeytan. Ingår ALDRIG i produktens compliance-tal.',
    artefakter: probeEndast,
    raa_detektioner_per_metod: perMetod(probeDet)
  },

  exekveringsdiagnostik: {
    $regel: 'Diagnostik om körningen, inte produktresultat.',
    artefakter_med_minst_en_observation_st: new Set(
      [...produktDet, ...probeDet].filter(d => d.klass === 'observation').map(d => d.artefakt)).size,
    av_totalt_exekverade_st: populationer.totalt_exekverade_artefakter_st
  },

  $observationsnot: 'Observationer är deklarationer utan uppmätt effekt: overflow hidden/clip utan överskridande innehåll, ellips eller line-clamp där texten ryms, överskott i en axel med overflow visible. De är varken fynd eller risker.',
  $avsiktlignot: 'Avsiktliga är deklarerat scrollbara behållare (overflow auto/scroll), innehåll utanför en scrollande förfader, och allt med data-clip-intent.',
  $scopenot: 'Radbrytare (br, wbr) har ingen egen visuell yta och ingår inte i geometrisk klippningsanalys. Det är en dokumenterad scoperegel, inte ett verktygsfel. Texten omkring dem mäts av det innehållande blocket.'
};

/* ── Validering ──────────────────────────────────────────────────────────── */
const fel = validera({ raa_detektioner_per_metod: rapport.produkt.raa_detektioner_per_metod,
                       populationer, nivåer: rapport.produkt.nivåer });
if (verifieradeFynd.reduce((t, f) => t + f.evidens.detektioner_st, 0) !==
    METODER.reduce((t, m) => t + rapport.produkt.raa_detektioner_per_metod[m].verifierad_detektioner_st, 0))
  fel.push('SUMMA: dedupliceringen tappade eller skapade verifierade detektioner');
const instansSumma = instanser.reduce((t, i) => t + i.elementfynd_st, 0);
if (instansSumma !== verifieradeFynd.length)
  fel.push('NIVÅ: felinstanserna täcker ' + instansSumma + ' elementfynd, men det finns ' + verifieradeFynd.length);
rapport.validering = { status: fel.length ? 'FÄLLD' : 'godkänd', fel };

if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1));
const n = rapport.produkt.nivåer;
console.log('ANALYS status=' + rapport.validering.status +
  ' | produkt: raa=' + n.raa_detektioner_st +
  ' elementfynd=' + n.elementfynd_st +
  ' felinstanser=' + n.felinstanser_st +
  ' rotorsaker=' + n.källrotorsaker_st +
  ' i_ritningar=' + n.berörda_produktartefakter_st + '/' + populationer.registrerade_produktartefakter_st +
  ' | observationer=' + rapport.produkt.övriga_klasser.observations_elementfynd_st +
  ' verktygsfel=' + rapport.produkt.övriga_klasser.verktygsfel_elementfynd_st);
for (const f of fel) console.log('  ✖ ' + f);
process.exit(fel.length ? 1 : 0);
