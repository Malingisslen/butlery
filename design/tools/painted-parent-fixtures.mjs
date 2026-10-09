#!/usr/bin/env node
// F2-R04 · METODPROV FOR MALAD FORALDER.  PP-01 … PP-07
//
// Numreringen ar PP och inte PR darfor att PR-01 … PR-10 redan ar upptagna av
// tools/parent-resolution-fixtures.mjs och betyder nagot annat. Mappningen mot
// bestallningen ar ett till ett:
//   PP-01 = PR-01   text pa element med egen malad bakgrund
//   PP-02 = PR-02   text utan egen bakgrund vandrar till narmaste malade forfader
//   PP-03 = PR-03   genomskinlig egen bakgrund maskerar inte den verkliga foraldern
//   PP-04 = PR-04   andrad kontrollyta paverkar beroende text, inte syskon
//   PP-05 = PR-05   flera malade barare faller stangt i stallet for DOM-narhet
//   PP-06 = PR-06   globceremoni BUTTON_TEXT loses mot BUTTON_SURFACE
//   PP-07 = PR-07   vanlig text pa appytan loses fortfarande mot APP_BACKGROUND
//
// PP-06 och PP-07 kors mot vardena sa som MATNINGEN registrerade dem i
// globceremoni. De ar inte pahittade och inte avrundade.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { byggIndex, maladForalder, FORALDERKLASS, beroenden, BEROENDETYP }
  from './parent-resolution.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

const yta = (art, ordinal, varde, extra = {}) => ({ art, elementOrdinal: ordinal,
  egenskap: 'background-color', varde, ...extra });
const text = (art, ordinal, varde, uy) => ({ art, elementOrdinal: ordinal,
  egenskap: 'color', varde, underliggandeYta: uy });

/* ── PP-01 · egen malad bakgrund vinner ──────────────────────────────*/
{ const poster = [
    yta('T1', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('T1', 6, 'rgb(245, 244, 237)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('T1', 6, 'rgb(36, 56, 44)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[2], ix);
  prov('PP-01', 'text pa ett element med egen malad bakgrund loses mot den bakgrunden',
    r.ok && r.klass === FORALDERKLASS.EGEN_MALAD_BAKGRUND && r.foralder.ordinal === 6,
    'underliggandeYta pekar pa ordinal 0, men relationen loses mot ordinal 6 — elementets egen tackande yta'); }

/* ── PP-02 · utan egen bakgrund vandras kedjan ───────────────────────*/
{ const poster = [
    yta('T2', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('T2', 7, 'rgb(63, 81, 69)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('T2', 9, 'rgb(201, 211, 196)', { ordinal: 7, farg: 'rgb(63, 81, 69)' }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[2], ix);
  prov('PP-02', 'text utan egen bakgrund vandrar till narmaste faktiskt malade forfader',
    r.ok && r.klass === FORALDERKLASS.NARMASTE_MALADE_FORFADER && r.foralder.ordinal === 7,
    'loses mot ordinal 7, inte mot appytan pa ordinal 0'); }

/* ── PP-03 · helt genomskinlig egen bakgrund maskerar inte ───────────*/
{ const poster = [
    yta('T3', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('T3', 4, 'rgba(0, 0, 0, 0)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('T3', 4, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[2], ix);
  prov('PP-03', 'en helt genomskinlig egen bakgrund maskerar inte den verkliga malade foraldern',
    r.ok && r.klass === FORALDERKLASS.NARMASTE_MALADE_FORFADER && r.foralder.ordinal === 0,
    'rgba(0,0,0,0) ar ingen barare — relationen gar vidare till ordinal 0'); }

/* ── PP-04 · andrad kontrollyta paverkar beroende, inte syskon ───────*/
{ const bas = [
    yta('T4', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('T4', 6, 'rgb(245, 244, 237)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('T4', 6, 'rgb(36, 56, 44)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }),
    text('T4', 3, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }) ];
  const fore = byggIndex(bas);
  const foreKnapp = maladForalder(bas[2], fore), foreSyskon = maladForalder(bas[3], fore);
  const efterPoster = bas.map(p => (p.elementOrdinal === 6 && p.egenskap === 'background-color')
    ? { ...p, varde: 'rgb(74, 92, 67)' } : p);
  const efter = byggIndex(efterPoster);
  const efterKnapp = maladForalder(efterPoster[2], efter), efterSyskon = maladForalder(efterPoster[3], efter);
  prov('PP-04', 'en andrad kontrollyta andrar beroende texts relation men inte ett syskons',
    foreKnapp.foralder.varde !== efterKnapp.foralder.varde &&
    foreSyskon.foralder.varde === efterSyskon.foralder.varde &&
    efterSyskon.foralder.ordinal === 0,
    'knapptexten: ' + foreKnapp.foralder.varde + ' -> ' + efterKnapp.foralder.varde +
    ' · syskonet oforandrat pa ' + efterSyskon.foralder.varde); }

/* ── PP-05 · flera barare faller stangt ──────────────────────────────*/
{ const poster = [
    yta('T5', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('T5', 6, 'rgba(245, 244, 237, 0.18)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('T5', 6, 'rgb(201, 211, 196)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[2], ix);
  prov('PP-05', 'flera malade barare loses aldrig pa DOM-narhet utan faller stangt',
    !r.ok && r.klass === FORALDERKLASS.FLERA_BARARE && r.barare.length === 2,
    'barare ' + r.barare.join(' + ') + ' — ' + r.skal); }

/* ── PP-06 · globceremoni BUTTON_TEXT ────────────────────────────────
   Uppmatta varden ur globceremoni: ordinal 0 ar appytan rgb(36,56,44),
   ordinal 6 ar knappen med egen bakgrund rgb(245,244,237) och texten
   rgb(36,56,44). Matningens underliggandeYta for bada posterna pa ordinal 6
   pekar pa ordinal 0 — det var precis darfor felet uppstod. */
{ const poster = [
    yta('globceremoni', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    yta('globceremoni', 6, 'rgb(245, 244, 237)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }),
    text('globceremoni', 6, 'rgb(36, 56, 44)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }),
    yta('globceremoni', 7, 'rgb(63, 81, 69)', { underliggandeYta: { ordinal: 0, farg: 'rgb(36, 56, 44)' } }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[2], ix);
  prov('PP-06', 'globceremoni BUTTON_TEXT loses mot BUTTON_SURFACE, inte mot APP_BACKGROUND',
    r.ok && r.foralder.ordinal === 6 && r.foralder.varde === 'rgb(245, 244, 237)',
    'foralder ordinal 6 rgb(245, 244, 237) — inte ordinal 0 rgb(36, 56, 44) som matningens underliggandeYta pekade pa'); }

/* ── PP-07 · vanlig text pa appytan ar oforandrad ────────────────────*/
{ const poster = [
    yta('globceremoni', 0, 'rgb(36, 56, 44)', { arAppytan: true }),
    text('globceremoni', 3, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' }) ];
  const ix = byggIndex(poster);
  const r = maladForalder(poster[1], ix);
  const b = beroenden(poster[1], ix);
  prov('PP-07', 'vanlig text pa appytan loses fortfarande mot APP_BACKGROUND',
    r.ok && r.klass === FORALDERKLASS.NARMASTE_MALADE_FORFADER && r.foralder.ordinal === 0 &&
    r.arAppytan === true && b[BEROENDETYP.PREVIEW_CONTEXT].includes('globceremoni|0'),
    'rubriken pa ordinal 3 loses mot appytan — rattelsen flyttar bara det som verkligen har en egen barare'); }

const ANTAL = 7;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('MALAD-FORALDER-PROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'maladforalderprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
