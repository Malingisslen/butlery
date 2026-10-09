#!/usr/bin/env node
// F2-R01 · R-01:s MÄTBASLINJE.
//
// Kör: node tools/contrast-baseline.mjs --raw=<render-raw.json> [--out=<fil>]
//
// TRE POPULATIONER, aldrig sammanblandade — samma regel som R-03:
//   registrerade_produktartefakter_st   310  ← nämnare för ALLA produkttal
//   probeartefakter_st                    3  ← test- och probeytan
//   totalt_exekverade_artefakter_st     313  ← ren exekveringsdiagnostik
//
// TRE NIVÅER, som aldrig summeras ihop:
//   text-runs        det som faktiskt målas, evidensnivån
//   kontrollmätning  en kontroll i en viewport, mätenheten
//   fynd             en kontroll som faller sin tröskel, felnivån
//
// FINDING-IDENTITETEN är kontrollens, aldrig text-runens. Ett fragment som
// byter plats i DOM:en får inte byta fyndidentitet.
//
//   CHK-R-01 · artefakt · kontrollnyckel · applicability · viewport · theme · textScale
//
// Tröskeln avgörs per text-run av den typografi som målar fragmentet, och
// kontrollen faller på den sämsta TILLÄMPLIGA körningen — mätt som avstånd
// till sin egen tröskel, inte som råkvot.

import { readFileSync, writeFileSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const RAW = arg('raw'), OUT = arg('out');
if (!RAW) { console.error('✖ ange --raw=<render-raw.json>'); process.exit(2); }
const D = JSON.parse(readFileSync(RAW, 'utf8'));

/* ── Populationer ────────────────────────────────────────────────────────── */
const idProdukt = new Set(), idProbe = new Set();
for (const r of D.results) for (const a of r.artifacts) (r.probe ? idProbe : idProdukt).add(a.id);
const probeEndast = [...idProbe].filter(x => !idProdukt.has(x));
const populationer = {
  $regel: 'Produktens kontrollresultat använder ALLTID registrerade_produktartefakter_st som nämnare. Probeartefakterna ligger i en egen sektion och blandas aldrig in i produktens tal.',
  registrerade_produktartefakter_st: idProdukt.size,
  probeartefakter_st: probeEndast.length,
  probeartefakter: probeEndast,
  totalt_exekverade_artefakter_st: idProdukt.size + probeEndast.length
};

/* ── Kontrollmätningar med stabil identitet ──────────────────────────────── */
// Kontrollnyckeln följer samma prioritetsordning som mätskriptets elementKey:
// roll plus tillgängligt namn, med löpnummer bara när samma par förekommer
// flera gånger i samma artefakt. Löpnumret är dokumenterad reserv, inte
// förstahandsidentitet.
const mätningar = [];
for (const r of D.results) {
  if (r.probe) continue;
  const viewport = r.profile.id;
  for (const a of r.artifacts) {
    const räknare = new Map();
    for (const c of a.controls || []) {
      const bas = 'roll:' + c.role + '|' + (c.name || '(namnlöst)');
      const n = räknare.get(bas) || 0;
      räknare.set(bas, n + 1);
      const kontrollnyckel = bas + (n > 0 ? '#' + n : '');
      mätningar.push({
        artifactId: a.id, viewport, kontrollnyckel,
        role: c.role, name: c.name, state: c.state,
        applicability: c.contrastApplicability,
        status: c.contrastStatus,
        why: c.contrastWhy,
        kvot: c.contrast,
        threshold: c.contrastThreshold,
        underThreshold: c.underThreshold,
        disabledVerifierad: c.disabled,
        disabledBasis: c.disabledBasis,
        textRuns_st: c.textRuns_st,
        textRuns: (c.textRuns || []).map(t => ({
          text: t.text, malare: t.tag, malareArKontrollen: t.malareArKontrollen,
          foreground: t.color, komposieradForeground: t.komposierad || null,
          background: t.bakgrund, fontSize: t.fontSize, fontWeight: t.fontWeight,
          large: t.large, threshold: t.threshold, ratio: t.ratio,
          status: t.status, underThreshold: t.underThreshold, why: t.why }))
      });
    }
  }
}

const räkna = f => mätningar.filter(f).length;
const perApplicability = {};
for (const m of mätningar) perApplicability[m.applicability] = (perApplicability[m.applicability] || 0) + 1;

/* ── Fynd ────────────────────────────────────────────────────────────────── */
// Bara en TILLÄMPLIG kontroll under sin tröskel är ett fynd. Undantagna och
// omätbara kontroller blir aldrig fynd — och räknas aldrig som godkända.
const fynd = mätningar.filter(m => m.applicability === 'applicable' && m.underThreshold === true)
  .map(m => ({
    findingId: ['CHK-R-01', m.artifactId, m.kontrollnyckel, 'applicability=' + m.applicability,
      'vp=' + m.viewport, 'theme=obeslutad', 'ts=1.0'].join(' · '),
    artifactId: m.artifactId, kontrollnyckel: m.kontrollnyckel,
    kvot: m.kvot, threshold: m.threshold,
    fallandeRuns: m.textRuns.filter(t => t.underThreshold === true),
    evidens_alla_runs: m.textRuns
  }));

// Omätbara kontroller är INGEN grön signal. De redovisas separat så att en
// läsare inte kan förväxla "inga fynd" med "allt prövat".
const omätbara = mätningar.filter(m => m.applicability === 'unknown');

const rapport = {
  $schema: 'butlery-r01-baslinje/1',
  kontroll: 'CHK-R-01',
  källa: RAW,
  $regel: 'Tre nivåer — text-runs, kontrollmätningar och fynd — summeras aldrig ihop.',
  populationer,
  nivåer: {
    text_runs_st: mätningar.reduce((s, m) => s + m.textRuns_st, 0),
    kontrollmatningar_st: mätningar.length,
    unika_kontroller_st: new Set(mätningar.map(m => m.artifactId + ' ‖ ' + m.kontrollnyckel)).size,
    fynd_st: fynd.length
  },
  applicability: perApplicability,
  applicabilityRegel: {
    applicable: 'synlig text finns och kvoten kunde mätas — kan bli fynd',
    'notApplicable:noVisibleText': 'kontrollen målar ingen synlig text; tillgängligt namn är inte synlig text',
    unknown: 'synlig text finns men kvoten kan inte reduceras — varken godkänd eller underkänd',
    'exempt:disabled': 'positivt verifierat inaktiv; kvoten mäts och redovisas men är inte produktfel'
  },
  summering: {
    measured_st: räkna(m => m.status === 'measured'),
    notApplicable_st: räkna(m => m.applicability === 'notApplicable:noVisibleText'),
    unknown_st: räkna(m => m.applicability === 'unknown'),
    exemptDisabled_st: räkna(m => m.applicability === 'exempt:disabled'),
    tillampliga_st: räkna(m => m.applicability === 'applicable'),
    under_troskel_st: fynd.length,
    berorda_produktartefakter_st: new Set(fynd.map(f => f.artifactId)).size
  },
  exemptDisabled: mätningar.filter(m => m.applicability === 'exempt:disabled')
    .map(m => ({ artifactId: m.artifactId, kontrollnyckel: m.kontrollnyckel,
      kvot: m.kvot, threshold: m.threshold, grund: m.disabledBasis })),
  omatbara_st: omätbara.length,
  omatbara: omätbara.map(m => ({ artifactId: m.artifactId, kontrollnyckel: m.kontrollnyckel, why: m.why })),
  smalaste_marginaler: mätningar.filter(m => m.applicability === 'applicable' && m.kvot !== null)
    .sort((a, b) => a.kvot / a.threshold - b.kvot / b.threshold).slice(0, 10)
    .map(m => ({ artifactId: m.artifactId, kontrollnyckel: m.kontrollnyckel,
      kvot: m.kvot, threshold: m.threshold, marginal: +(m.kvot / m.threshold).toFixed(3) })),
  fynd,
  matningar: mätningar
};

const fel = [];
// 319 sedan de nio komponentpanelerna fick viewportprofil. Fore det var
// namnaren 310 och de nio matt es inte av nagon motor alls.
// Morkt (authored-dark) mats bara dar morkt ar tillampligt: namnaren ar render-probens
// darkIds (ramar med data-theme-support ~ dark), inte hela produktpopulationen. En
// saknad tillamplig ram faller fortfarande; ej tillampliga redovisas explicit.
if (D.colorScheme === 'authored-dark') {
  const tillampliga = Array.isArray(D.darkIds) ? D.darkIds : null;
  populationer.morkt = { EXPECTED_DARK_FRAME_COUNT: tillampliga ? tillampliga.length : null,
    NOT_APPLICABLE_st: Array.isArray(D.notApplicable) ? D.notApplicable.length : null };
  if (!tillampliga) fel.push('mork rendering saknar darkIds — tillampligheten kan inte bevisas');
  else {
    const saknas = tillampliga.filter(id => !idProdukt.has(id)), extra = [...idProdukt].filter(id => !tillampliga.includes(id));
    if (saknas.length) fel.push('tillampliga morka ramar saknas: ' + saknas.join(', '));
    if (extra.length) fel.push('ramar utan morkt stod matta som morka: ' + extra.join(', '));
  }
} else if (populationer.registrerade_produktartefakter_st !== 319)
  fel.push('produktpopulationen är ' + populationer.registrerade_produktartefakter_st + ', förväntat 319');
if (mätningar.some(m => !m.applicability))
  fel.push('en kontrollmätning saknar applicability — fail closed');
if (mätningar.some(m => m.applicability === 'applicable' && m.kvot === null))
  fel.push('en tillämplig kontroll saknar kvot — fail closed');
if (mätningar.some(m => m.textRuns.some(t => t.ratio === 1 && t.malareArKontrollen === true)))
  fel.push('en text-run målas av kontrollen själv och ger kvot 1,00 — containerfelet är tillbaka');
rapport.failClosed = { fel, status: fel.length ? 'FÄLLD' : 'godkänd' };

if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1) + '\n');

console.log('R-01-BASLINJE population=' + populationer.registrerade_produktartefakter_st +
  ' text-runs=' + rapport.nivåer.text_runs_st +
  ' kontrollmätningar=' + rapport.nivåer.kontrollmatningar_st +
  ' fynd=' + rapport.nivåer.fynd_st +
  ' status=' + rapport.failClosed.status);
for (const [k, v] of Object.entries(perApplicability).sort((a, b) => b[1] - a[1]))
  console.log('  ' + k.padEnd(30) + v);
console.log('  smalaste marginal: ' + (rapport.smalaste_marginaler[0]
  ? rapport.smalaste_marginaler[0].kvot + ' mot ' + rapport.smalaste_marginaler[0].threshold +
    ' i ' + rapport.smalaste_marginaler[0].artifactId : 'ingen'));
for (const f of fel) console.log('  ✖ ' + f);
process.exit(fel.length ? 1 : 0);
