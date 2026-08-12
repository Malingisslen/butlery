#!/usr/bin/env node
// F2-R04 · METODPROV.  GC-01 … GC-08  agarskap for currentColor
//                      BT-01 … BT-07  behorighet for P-TEXT-BRAND
//
// Felklassen GC finns for: en malad svg-del med currentColor sags kunna bli en
// egen beslutsenhet. Den ager ingen farg — men den kan ogiltigforklara agarens
// kandidat, och det maste propagera.
//
// Felklassen BT finns for: varumarkestext skulle arva brodtextens mappning bara
// for att markupen anvander samma generiska textklass.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { losAgare, agarbivillkor, provaAgarkandidat, laggerIckeTextkrav,
  BARARKLASS } from './currentcolor-ownership.mjs';
import { byggRegister, behorighet, kandidatuniversum, kvot, rgbAv } from './palette-registry.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* ── Byggare for uppmatta agarposter ────────────────────────────────*/
const barn = (o = {}) => ({ art: o.art || 'a', ordinal: o.ordinal ?? 5, tagg: o.tagg || 'circle',
  egenskap: o.egenskap || 'fill', malatVarde: o.varde || 'rgb(36, 56, 44)',
  color: o.varde || 'rgb(36, 56, 44)',
  agareOrdinal: o.agare === undefined ? 2 : o.agare,
  agareUtanforProduktbasen: !!o.utanfor,
  rotOrdinal: o.rot ?? 4, grafikroll: o.grafikroll ?? null, ikon: o.ikon || 'message-square' });
const kvotMot = (kandidat, bakgrund) => kvot(rgbAv(kandidat), rgbAv(bakgrund));

/* ── GC-01 · barnet skapar ingen egen beslutsenhet ──────────────────*/
{ const p = [barn({ ordinal: 5 }), barn({ ordinal: 6 }), barn({ ordinal: 7 })];
  const r = agarbivillkor(p, () => BARARKLASS.INFORMATION_BEARING_GRAPHIC, () => '#17251d');
  prov('GC-01', 'ett currentColor-barn skapar ingen egen beslutsenhet',
    r.nyaBeslutsenheter === 0 && r.nyaSkrivbaraKallor === 0 && r.agare.length === 1,
    '3 barn -> ' + r.agare.length + ' agare · 0 nya enheter · 0 nya kallposter'); }

/* ── GC-02 · agaren loses till exakt identitet ──────────────────────*/
{ const a = losAgare(barn({ art: 'hem', ordinal: 8, agare: 2 }));
  prov('GC-02', 'currentColor-barnet loses till exakt agande fargkalla',
    a.ok && a.agare === 'hem|2|color',
    'agare = ' + a.agare); }

/* ── GC-03 · informationsbarande barn lagger krav pa agaren ─────────*/
{ const r = agarbivillkor([barn({})], () => BARARKLASS.INFORMATION_BEARING_GRAPHIC, () => '#17251d');
  const k = r.agare[0].krav;
  prov('GC-03', 'ett informationsbarande barn lagger ett icke-textkrav pa agaren',
    k.length === 1 && k[0].typ === 'ICKE_TEXT' && k[0].troskel === 3,
    'krav: ' + k.length + ' · typ ' + k[0].typ + ' · troskel ' + k[0].troskel); }

/* ── GC-04 · redundant barn lagger inget krav ───────────────────────*/
{ const r = agarbivillkor([barn({})], () => BARARKLASS.REDUNDANT_GRAPHIC, () => '#17251d');
  prov('GC-04', 'ett redundant barn lagger inget informationsbarande krav',
    r.agare[0].krav.length === 0 && !laggerIckeTextkrav(BARARKLASS.REDUNDANT_GRAPHIC),
    'krav: 0 · barnet ar redundant och etiketten bar samma information'); }

/* ── GC-05 · dekorativt barn lagger inget krav ──────────────────────*/
{ const r = agarbivillkor([barn({})], () => BARARKLASS.DECORATIVE_GRAPHIC, () => '#17251d');
  prov('GC-05', 'ett dekorativt barn lagger inget informationsbarande krav',
    r.agare[0].krav.length === 0 && !laggerIckeTextkrav(BARARKLASS.DECORATIVE_GRAPHIC),
    'krav: 0'); }

/* ── GC-06 · en agare med flera barn maste klara alla ───────────────*/
{ const p = [barn({ ordinal: 5 }), barn({ ordinal: 6 }), barn({ ordinal: 7 })];
  const bak = { 'a|5|fill': '#17251d', 'a|6|fill': '#f5f4ed', 'a|7|fill': '#24382c' };
  const r = agarbivillkor(p, () => BARARKLASS.INFORMATION_BEARING_GRAPHIC,
    q => bak[q.art + '|' + q.ordinal + '|' + q.egenskap]);
  const res = provaAgarkandidat('#93a48d', r.agare[0].krav, kvotMot);
  prov('GC-06', 'en agare som anvands av flera informationsbarande barn maste klara alla relationer',
    r.agare[0].krav.length === 3 && res.prov.length === 3,
    '3 barn, 3 bakgrunder, 3 prov · utfall ' + res.prov.map(x => x.kvot).join(' / ')); }

/* ── GC-07 · kandidat som faller pa ETT barn avvisas ────────────────*/
{ const p = [barn({ ordinal: 5 }), barn({ ordinal: 6 })];
  const bak = { 'a|5|fill': '#17251d', 'a|6|fill': '#f5f4ed' };
  const r = agarbivillkor(p, () => BARARKLASS.INFORMATION_BEARING_GRAPHIC,
    q => bak[q.art + '|' + q.ordinal + '|' + q.egenskap]);
  const res = provaAgarkandidat('#c9d3c4', r.agare[0].krav, kvotMot);
  prov('GC-07', 'en agarkandidat som faller pa ett enda beroende barn avvisas',
    !res.ok && res.prov.filter(x => !x.ok).length >= 1,
    '#c9d3c4 mot #17251d = ' + res.prov[0].kvot + ' ok · mot #f5f4ed = ' + res.prov[1].kvot +
    ' faller -> kandidaten avvisas'); }

/* ── GC-08 · olost agare faller stangt ──────────────────────────────*/
{ const utan = losAgare(barn({ agare: null }));
  const utanfor = losAgare(barn({ agare: -1, utanfor: true }));
  const r = agarbivillkor([barn({ agare: null })], () => BARARKLASS.INFORMATION_BEARING_GRAPHIC, () => '#17251d');
  prov('GC-08', 'en olost currentColor-agare faller stangt',
    !utan.ok && !utanfor.ok && r.olosta.length === 1 && r.agare.length === 0,
    'ingen deklarerande forfader -> ' + utan.skal + ' · utanfor produktbasen -> ' + utanfor.skal); }

/* ── PALETT FOR BT ──────────────────────────────────────────────────*/
const PAL = byggRegister([
  { varde: '#93a48d', egenskap: 'color', roll: 'text-innehall' },
  { varde: '#c9d3c4', egenskap: 'color', roll: 'text-innehall' },
  { varde: '#8fb89a', egenskap: 'color', roll: 'text-innehall' },
  { varde: '#dca968', egenskap: 'color', roll: 'text-status' },
  { varde: '#de9078', egenskap: 'color', roll: 'text-status' },
  { varde: '#17251d', egenskap: 'background-color', roll: 'yta-app' }]);
const BRAND = { brandroll: true };
const BRAND_ACC = { brandroll: true, brandaccentMotiverad: true };

/* ── BT-01 · brandtext anvander inte P-TEXT-CONTENT per automatik ───*/
{ const u = kandidatuniversum('P-TEXT-CONTENT', PAL);
  const b = PAL.map(p => behorighet('P-TEXT-BRAND', p, BRAND_ACC));
  const acc = PAL.find(p => p.varde === '#dca968');
  prov('BT-01', 'varumarkestext anvander inte P-TEXT-CONTENT per automatik',
    u.rader.find(r => r.varde === '#dca968').behorig === false &&
    behorighet('P-TEXT-BRAND', acc, BRAND_ACC).behorig === true,
    '#dca968 ar obehorig under P-TEXT-CONTENT men behorig under P-TEXT-BRAND med brandmotivering'); }

/* ── BT-02 · samma raa ljusfarg ger ingen automatisk mork mappning ───*/
{ const r = behorighet('P-TEXT-BRAND', PAL.find(p => p.varde === '#93a48d'), BRAND);
  prov('BT-02', 'samma raa ljusfarg i brodtext och varumarkestext ger ingen mappningsekvivalens',
    r.behorig === true && !('rekommendation' in r) && !('mork' in r) && !('mappning' in r),
    'kontraktet returnerar bara behorighet och skal — aldrig ett morkervarde eller en mappning'); }

/* ── BT-03 · kandidat som faller pa textkontrast avvisas ────────────*/
{ const kv = kvot(rgbAv('#37453a'), rgbAv('#17251d'));
  prov('BT-03', 'en kandidat som faller pa textkontrast avvisas',
    kv < 4.5,
    '#37453a mot #17251d = ' + kv + ' — under kravet 4.5, avvisas oavsett semantisk behorighet'); }

/* ── BT-04 · orelaterad accent avvisas som kontrastworkaround ───────*/
{ const r = behorighet('P-TEXT-BRAND', PAL.find(p => p.varde === '#de9078'), BRAND);
  prov('BT-04', 'en orelaterad semantisk accent avvisas som kontrastworkaround',
    !r.behorig && /utan explicit brandmotivering/.test(r.skal),
    '#de9078 utan brandmotivering -> ' + r.klass + ' · ' + r.skal); }

/* ── BT-05 · motiverad brandaccent forblir behorig ──────────────────*/
{ const r = behorighet('P-TEXT-BRAND', PAL.find(p => p.varde === '#dca968'), BRAND_ACC);
  prov('BT-05', 'en accent som semantiken faktiskt stodjer forblir behorig',
    r.behorig && r.klass === 'ELIGIBLE_AND_TESTED',
    '#dca968 med explicit brandmotivering -> ' + r.klass); }

/* ── BT-06 · alla slutliga bakgrunder maste klara sig ───────────────*/
{ const bakgrunder = ['#17251d', '#24382c', '#4a5c43'];
  const kandidat = '#93a48d';
  const kvoter = bakgrunder.map(b => kvot(rgbAv(kandidat), rgbAv(b)));
  const allaOk = kvoter.every(k => k >= 4.5);
  prov('BT-06', 'en kandidat maste klara SAMTLIGA slutliga bakgrunder, inte bara en',
    !allaOk && kvoter[0] >= 4.5,
    '#93a48d ger ' + kvoter.join(' / ') + ' mot ' + bakgrunder.join(' / ') +
    ' — godkand mot den forsta, faller mot den sista, alltsa inte hallbar som gemensam'); }

/* ── BT-07 · saknad brandrollkontext faller stangt ──────────────────*/
{ const r = behorighet('P-TEXT-BRAND', PAL.find(p => p.varde === '#93a48d'), {});
  prov('BT-07', 'saknad brandrollkontext faller stangt',
    !r.behorig && /brandrollkontext saknas/.test(r.skal),
    'utan brandroll -> ' + r.klass + ' · ' + r.skal); }

const ANTAL = 15;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('AGAR- OCH BRANDPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'agarbrandprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
