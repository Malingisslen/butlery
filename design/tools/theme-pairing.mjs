#!/usr/bin/env node
// F2-R04 · MASKINELLT PARNINGSFÖRSLAG för temadimensionen.
//
// Detta är ett UNDERLAG, inte ett beslut. Verktyget föreslår aldrig ett par från
// filnamn eller rubrik — ett filnamn är ingen beslutad egenskap. Evidensen är
// två maskinobservationer från renderingen:
//
//   1. STRUKTUR — kontrollernas roll- och namnföljd plus DOM-skelettet. Två
//      ritningar av samma skärm i olika tema har samma struktur.
//   2. LUMINANS — den största ogenomskinliga ytans uppmätta luminans. Den räcker
//      INTE ensam: mörka dialoger och lägestemat "laga" mäter också mörkt.
//
// Temadimensionen får inte öppnas som aktiv selektor förrän BÅDA sidor har
// uttryckliga beslut. En oselektiv ljus variant matchar annars både light och
// dark och överlappar den mörka varianten.

import { readFileSync, writeFileSync } from 'node:fs';
import { parning } from './theme-pairing-lib.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const RAW = arg('raw'), OUT = arg('out');
if (!RAW) { console.error('✖ ange --raw=<render-raw.json>'); process.exit(2); }

const D = JSON.parse(readFileSync(RAW, 'utf8'));
const A = JSON.parse(readFileSync('artifacts.json', 'utf8'));
const K = JSON.parse(readFileSync('layout-contract.json', 'utf8'));

/* ── Registret, nycklat på sourceElementId ───────────────────────────────── */
const reg = new Map();
for (const a of A.artifacts) {
  if (reg.has(a.sourceElementId)) reg.get(a.sourceElementId).push(a);
  else reg.set(a.sourceElementId, [a]);
}

/* ── Mätningen, en post per artefakt (första icke-probe-körfallet) ───────── */
const mätt = new Map();
for (const r of D.results) {
  if (r.probe) continue;
  for (const a of r.artifacts) if (!mätt.has(a.id)) mätt.set(a.id, { ...a, profil: r.profile.id });
}

/* ── Kandidatmängd: registrerade viewportartefakter ──────────────────────── */
const poster = [];
for (const [id, m] of mätt) {
  const rs = reg.get(id) || [];
  const r = rs.length === 1 ? rs[0] : rs.find(x => x.artifactKind === 'viewport') || rs[0];
  if (!r || r.artifactKind !== 'viewport') continue;
  poster.push({
    id, artifactId: r.artifactId, sourceFile: r.sourceFile,
    screenId: r.screenId, stateId: r.stateId, variantId: r.variantId,
    selectors: r.selectors || {}, viewportClass: r.viewportClass,
    layoutläge: (K.viewportClassMap[r.viewportClass] || {}).mode || null,
    buildTarget: (r.selectors || {}).buildTarget || (r.viewportClass === 'expanded' ? 'admin-web' : null),
    classificationState: r.classificationState, authorityState: r.authorityState,
    luminans: m.bg.luminans, luminansklass: m.bg.uppmätt,
    fRoller: m.fingeravtryck.roller, rollantal: m.fingeravtryck.rollantal,
    fSkelett: m.fingeravtryck.skelett, noder: m.fingeravtryck.noder
  });
}

/* ── Parning ─────────────────────────────────────────────────────────────── */
// En kandidat kräver SAMMA struktur och MOTSATT uppmätt luminans, samt samma
// viewportklass och samma build target. Selektorer utöver tema måste vara lika.
const R = parning(poster);
const entydiga = R.entydiga.map(p => byggPost(p.källa, p.kandidater, p.grund));
const utanMotpart = R.utanMotpart.map(p => byggPost(p.källa, p.kandidater, p.grund));
const flertydiga = R.flertydiga.map(p => byggPost(p.källa, p.kandidater, p.grund));
const ljusaUtanKandidat = R.ljusaUtanKandidat;

function byggPost(m, c, grund) {
  return {
    mörk: m.id, artifactId: m.artifactId, sourceFile: m.sourceFile,
    screenId: m.screenId, stateId: m.stateId, layoutläge: m.layoutläge,
    buildTarget: m.buildTarget, övrigaSelektorer: m.selectors,
    classificationState: m.classificationState,
    luminans: m.luminans, rollantal: m.rollantal, noder: m.noder,
    kandidater: c.map(l => ({ ljus: l.id, artifactId: l.artifactId, luminans: l.luminans,
      screenId: l.screenId, stateId: l.stateId, noder: l.noder })),
    evidens: c.length ? grund + '; motsatt uppmätt luminans (' + m.luminans + ' mot ' +
      c.map(l => l.luminans).join('/') + '); samma viewportklass, layoutläge och build target'
      : 'ingen ljus artefakt delar rollfingeravtryck inom samma viewportklass och build target'
  };
}


/* ── Rapport ─────────────────────────────────────────────────────────────── */
const rapport = {
  $regel: 'Förslag, inte beslut. Ingen post här ändrar artifacts.json. Filnamn och rubrik används inte som evidens.',
  $luminansregel: 'luminansklass är en OBSERVATION av den största ogenomskinliga ytans luminans (mörk om L < 0.18). Den är inte ett tema. Mörka dialoger och lägestemat laga mäter också mörkt.',
  underlag: { renderkälla: RAW, artefaktregister: 'artifacts.json v' + A.version,
              layoutkontrakt: 'layout-contract.json v' + K.version },
  universum: {
    viewportartefakter_st: poster.length,
    luminansmörka_kandidater_st: poster.filter(p => p.luminansklass === 'mörk').length,
    luminansljusa_st: poster.filter(p => p.luminansklass === 'ljus').length
  },
  entydiga_kandidatpar_st: entydiga.length,
  luminansmörka_utan_ljus_motpart_st: utanMotpart.length,
  luminansmörka_med_flera_motparter_st: flertydiga.length,
  ljusa_utan_luminansmörk_kandidat_st: ljusaUtanKandidat.length,
  kandidatparningstäckning: {
    $benämning: 'kandidatparningstäckning — INTE mörklägestäckning och INTE R-04-täckning. Ett kandidatpar är ett förslag byggt på struktur och luminans, inte ett verifierat temapar.',
    enhet: 'andel registrerade produktartefakter som ingår i ett entydigt kandidatpar',
    entydiga_par_st: entydiga.length,
    parade_artefakter_st: entydiga.length * 2,
    nämnare_produktartefakter_st: poster.length,
    parade_artefakter_andel_procent: +(entydiga.length * 2 / poster.length * 100).toFixed(1)
  },
  R04_status: {
    status: 'blocked',
    failClosed: true,
    skäl: 'Ingen artefakt bär explicit theme-metadata. Den normativa temadimensionen kan därför inte verifieras. Kandidatparningen är ett UNDERLAG, aldrig ett godkänt R-04-resultat.',
    blockerare: [
      'explicit selectors.theme saknas på samtliga ' + poster.length + ' produktartefakter',
      'temadimensionen är inte öppnad som aktiv selektor',
      ljusaUtanKandidat.length + ' ljusa produktartefakter saknar mörk kandidat'
    ],
    upplåses_av: 'uttryckliga temabeslut på BÅDA sidor, därefter verifiering av att exakt en aktiv variant matchar varje obligatorisk temakontext.',
    får_inte: 'redovisas som passerad kontroll, och luckan får inte fyllas med antagna registerposter. De mörka ritningar som finns är inte bevis för de ljusa som saknar motpart.'
  },
  entydiga_kandidatpar: entydiga,
  mörka_utan_ljus_motpart: utanMotpart,
  mörka_med_flera_motparter: flertydiga,
  ljusa_utan_mörk_kandidat: ljusaUtanKandidat.map(l => ({ ljus: l.id, artifactId: l.artifactId,
    viewportClass: l.viewportClass, layoutläge: l.layoutläge, luminans: l.luminans })),
  selektorspärr: {
    theme_får_aktiveras: false,
    skäl: 'En ljus artefakt utan uttryckligt selectors.theme är OSELEKTIV och matchar både light och dark. Den skulle överlappa varje mörk variant i samma bassplats. Dimensionen får öppnas först när båda sidor bär ett uttryckligt beslut.',
    artefakter_med_beslutat_theme_st: poster.filter(p => p.selectors.theme).length
  }
};

if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1));
console.log('PARNING entydiga=' + entydiga.length +
  ' mörka_utan_motpart=' + utanMotpart.length +
  ' flertydiga=' + flertydiga.length +
  ' ljusa_utan_kandidat=' + ljusaUtanKandidat.length +
  ' kandidatparningstäckning=' + rapport.kandidatparningstäckning.parade_artefakter_andel_procent + '%' +
  ' R04=blocked');
