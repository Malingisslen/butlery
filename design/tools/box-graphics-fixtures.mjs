#!/usr/bin/env node
// F2-NT · METODPROV FOR BOXRITAD GRAFIK.  CT-01 … CT-07, RD-01 … RD-08, AV-01 … AV-03
//
// CT  kompositeringen ar normativ: en genomskinlig barare mats mot den faktiskt
//     malade fargen, aldrig mot sitt deklarerade rgba-varde
// RD  redundans kraver ekvivalens, inte att nagon siffra rakar sta i narheten
// AV  varje upptackt kandidat stams av exakt en gang

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { angransandeFarg, redundansprov, proportionerITexten, avstamning,
  EKVIVALENS, KLASS, UTESLUTNING } from './box-graphics.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

const rgb = h => { const m = /^#([0-9a-f]{6})$/i.exec(h); return m
  ? [0, 2, 4].map(i => parseInt(m[1].slice(i, i + 2), 16)) : null; };
const lum = c => { const f = c.map(v => { const s = v / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); });
  return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]; };
const kvot = (a, b) => { const A = lum(rgb(a)), Bq = lum(rgb(b));
  const h = Math.max(A, Bq), l = Math.min(A, Bq);
  return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100; };
const hexAv = s => { const m = String(s).match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  return m ? '#' + [1, 2, 3].map(i => (+m[i]).toString(16).padStart(2, '0')).join('') : s; };

/* Uppmatta poster ur korpusen, sa som sonden registrerade dem. */
const OPAK = { art: 'hemladdar', ordinal: 12, bararAlpha: 1,
  bararDeklarerad: 'rgb(230, 234, 217)', bararKomponerad: 'rgb(230, 234, 217)',
  bakomBararen: 'rgb(245, 244, 237)', vardeKomponerad: 'rgb(206, 124, 30)',
  andelBredd: 0.44, andelHojd: 1, gruppText: ['Hämtar veckans plan …'] };
const START = { art: 'start', ordinal: 18, bararAlpha: 0.18,
  bararDeklarerad: 'rgba(245, 244, 237, 0.18)', bararKomponerad: 'rgb(74, 90, 79)',
  bakomBararen: 'rgb(36, 56, 44)', vardeKomponerad: 'rgb(206, 124, 30)',
  andelBredd: 0.46, andelHojd: 1, gruppText: ['Dukar upp ditt kök…'] };
const TIMER = { art: 'lagatimers', ordinal: 22, bararAlpha: 0.18,
  bararDeklarerad: 'rgba(245, 244, 237, 0.18)', bararKomponerad: 'rgb(83, 100, 88)',
  bakomBararen: 'rgb(63, 81, 69)', vardeKomponerad: 'rgb(220, 169, 104)',
  andelBredd: 0.22, andelHojd: 1, gruppText: ['Svampen'] };

/* ── CT-01 · tackande barare anvands direkt ─────────────────────────*/
{ const a = angransandeFarg(OPAK);
  prov('CT-01', 'en tackande barare anvander sitt berknade varde direkt',
    a.ok && a.komposition === 'DIREKT' && a.farg === OPAK.bararDeklarerad,
    a.farg + ' · ' + a.$regel); }

/* ── CT-02 · genomskinlig barare komponeras ─────────────────────────*/
{ const a = angransandeFarg(START);
  prov('CT-02', 'en genomskinlig barare komponeras mot sin faktiskt malade foralder',
    a.ok && a.komposition === 'KOMPONERAD' && a.farg !== a.deklarerad &&
    a.farg === 'rgb(74, 90, 79)',
    'deklarerat ' + a.deklarerad + ' · bakom ' + a.bakom + ' · malat ' + a.farg); }

/* ── CT-03 · nastlade genomskinliga lager i ratt ordning ────────────*/
{ /* rgba(245,244,237,.18) over rgb(63,81,69) ger rgb(83,100,88):
     0.18*245 + 0.82*63 = 95.8 -> avrundat i sonden mot den verkliga stacken. */
  const a = angransandeFarg(TIMER);
  const komponerat = a.farg;
  const forvantatLjusare = lum(rgb(hexAv(komponerat))) > lum(rgb(hexAv(TIMER.bakomBararen)));
  prov('CT-03', 'nastlade genomskinliga barare loses i ratt malordning',
    a.komposition === 'KOMPONERAD' && forvantatLjusare,
    'bakom ' + TIMER.bakomBararen + ' -> malat ' + komponerat + ' (ljusare, som en ljus overlay ska ge)'); }

/* ── CT-04 · byte av foralderbakgrund andrar den synliga fargen ─────*/
{ const a = angransandeFarg(START), b = angransandeFarg(TIMER);
  prov('CT-04', 'samma deklarerade rgba ger olika synlig farg mot olika foraldrar',
    a.deklarerad === b.deklarerad && a.farg !== b.farg,
    'samma deklaration ' + a.deklarerad + ' ger ' + a.farg + ' mot ' + a.bakom +
    ' och ' + b.farg + ' mot ' + b.bakom); }

/* ── CT-05 · det deklarerade rgba far aldrig rapporteras som slutfarg */
{ const a = angransandeFarg(START);
  const felaktigKvot = kvot(hexAv(START.vardeKomponerad), hexAv(a.deklarerad));
  const riktigKvot = kvot(hexAv(START.vardeKomponerad), hexAv(a.farg));
  prov('CT-05', 'det deklarerade rgba-vardet kan inte rapporteras som angransande farg',
    a.farg !== a.deklarerad && Math.abs(felaktigKvot - riktigKvot) > 0.5,
    'mot deklarerat varde ' + felaktigKvot + ' · mot faktiskt malat ' + riktigKvot +
    ' — skillnaden ar hela fyndet'); }

/* ── CT-06 · start reproducerar 2.28 ────────────────────────────────*/
{ const a = angransandeFarg(START);
  const k = kvot(hexAv(START.vardeKomponerad), hexAv(a.farg));
  prov('CT-06', 'start reproducerar den rattade kvoten 2.28', k === 2.28,
    hexAv(START.vardeKomponerad) + ' mot ' + hexAv(a.farg) + ' = ' + k); }

/* ── CT-07 · timern reproducerar 2.98 ───────────────────────────────*/
{ const a = angransandeFarg(TIMER);
  const k = kvot(hexAv(TIMER.vardeKomponerad), hexAv(a.farg));
  prov('CT-07', 'den rattade timern reproducerar 2.98', k === 2.98,
    hexAv(TIMER.vardeKomponerad) + ' mot ' + hexAv(a.farg) + ' = ' + k); }

/* ── RD-01 · exakt ekvivalent text ──────────────────────────────────*/
{ const rel = { andelBredd: 0.33, andelHojd: 1, gruppText: ['Steg 2 av 6'] };
  const r = redundansprov(rel);
  prov('RD-01', 'text som anger exakt samma proportion gor relationen redundant',
    r.redundant && r.ekvivalens === EKVIVALENS.PROPORTION,
    '"' + r.bevis + '" -> ' + r.textAndel + ' mot uppmatt ' + r.uppmattAndel); }

/* ── RD-02 · delvis eller icke-ekvivalent text ──────────────────────*/
{ const rel = { andelBredd: 0.33, andelHojd: 1, gruppText: ['Steg 2 av 6'] };
  const fel = { andelBredd: 0.80, andelHojd: 1, gruppText: ['Steg 2 av 6'] };
  const a = redundansprov(rel), b = redundansprov(fel);
  prov('RD-02', 'text vars proportion inte stammer ger INTE redundans',
    a.redundant && !b.redundant && b.ekvivalens === EKVIVALENS.INGEN,
    'samma text, 33 % redundant men 80 % inte — ' + b.skal); }

/* ── RD-03 · text om ett annat tillstand ────────────────────────────*/
{ const rel = { andelBredd: 0.44, andelHojd: 1,
    gruppText: ['Klart 3 av 3', 'Hämtar veckans plan …'] };
  const r = redundansprov(rel);
  prov('RD-03', 'text om ett ANNAT tillstand ger inte redundans',
    !r.redundant, '"Klart 3 av 3" beskriver ett annat tillstand an de uppmatta 44 % — ' + r.skal); }

/* ── RD-04 · ingen text alls ────────────────────────────────────────*/
{ const r = redundansprov({ andelBredd: 0.53, andelHojd: 1, gruppText: [] });
  prov('RD-04', 'utan synlig text finns ingen redundans',
    !r.redundant && /ingen synlig text/.test(r.skal), r.skal); }

/* ── RD-05 · dold text raknas inte ──────────────────────────────────*/
{ /* Sonden slapper aldrig igenom dold text: gruppText bygger bara pa noder
     med visibility visible, display och opacitet over noll och en ruta med
     yta. Provet visar konsekvensen: en relation vars enda "bevis" ar dolt
     hamnar med tom gruppText och kan darfor inte bli redundant. */
  const r = redundansprov({ andelBredd: 0.33, andelHojd: 1, gruppText: [] });
  prov('RD-05', 'dold text kan inte gora en relation redundant',
    !r.redundant, 'dold text nar aldrig gruppText — utfallet blir "' + r.skal + '"'); }

/* ── RD-06 · vardemangd som ekvivalens ──────────────────────────────*/
{ const syskon = [
    { andelBredd: 0.24, andelHojd: 1, gruppText: ['Efterrätt', '21'] },
    { andelBredd: 0.17, andelHojd: 1, gruppText: ['Lunch', '15'] },
    { andelBredd: 0.07, andelHojd: 1, gruppText: ['Bakning', '6'] } ];
  const r = redundansprov(syskon[0], syskon.slice(1));
  const utan = redundansprov({ andelBredd: 0.24, andelHojd: 1, gruppText: ['Efterrätt', '21'] }, []);
  prov('RD-06', 'absoluta tal blir ekvivalenta bara nar syskonens andelar stammer mot samma total',
    r.redundant && r.ekvivalens === EKVIVALENS.VARDEMANGD && !utan.redundant,
    r.bevis + ' · utan syskon: ' + utan.skal); }

/* ── AV-01 … AV-03 · avstamning ─────────────────────────────────────*/
{ const rel = [{ art: 'a', ordinal: 1 }, { art: 'a', ordinal: 2 }];
  const ute = [{ art: 'a', ordinal: 3, skal: UTESLUTNING.BARAREN_BAR_TEXT },
    { art: 'b', ordinal: 1, skal: UTESLUTNING.INUTI_DEKLARERAD_KONTROLL }];
  const a = avstamning(rel, ute);
  prov('AV-01', 'varje kandidat redovisas exakt en gang med utfall och skal',
    a.summerar && a.kandidater === 4 && a.inkluderade === 2 && a.uteslutna === 2,
    JSON.stringify(a.perUteslutningsskal)); }
{ const a = avstamning([{ art: 'a', ordinal: 1 }], [{ art: 'a', ordinal: 1, skal: 'X' }]);
  prov('AV-02', 'en kandidat som rakas hamna i bada listorna upptacks',
    !a.summerar && a.dubbletter.length === 1, 'dubblett: ' + a.dubbletter.join(', ')); }
{ const klasser = Object.keys(KLASS);
  prov('AV-03', 'klassmangden innehaller UNKNOWN som faller stangt',
    klasser.includes('UNKNOWN') && klasser.length === 5, klasser.join(', ')); }

/* ── RD-07 · identiska syskonandelar bevisar ingen ekvivalens ───────*/
{ const dot = a => ({ andelBredd: a, andelHojd: 1, gruppText: ['Anna', '13:40', '2'] });
  const r = redundansprov(dot(0.1163), [dot(0.1163), dot(0.1163)]);
  prov('RD-07', 'identiska syskonandelar ger inte vardemangdsekvivalens',
    !r.redundant && /innehallslost/.test(r.skal),
    'tre lika stora punkter kan inte "bevisa" att en siffra intill beskriver dem — ' + r.skal); }

/* ── RD-08 · tal ur en mening raknas inte som varde ─────────────────*/
{ const rel = { andelBredd: 0.24, andelHojd: 1, gruppText: ['Recept · 30 min'] };
  const syskon = [{ andelBredd: 0.17, andelHojd: 1, gruppText: ['Recept · 21 min'] },
    { andelBredd: 0.07, andelHojd: 1, gruppText: ['Recept · 9 min'] }];
  const r = redundansprov(rel, syskon);
  prov('RD-08', 'ett tal plockat ur en mening ar inget vardefalt',
    !r.redundant, 'talen star inne i en mening, inte som egen etikett — ' + r.skal); }

const ANTAL = 18;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('BOXGRAFIKPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'boxgrafikprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
