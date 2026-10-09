#!/usr/bin/env node
// F2-R04 · METODPROV FOR FORALDERUPPLOSNING.  PR-01 … PR-10
//
// Felklassen proven finns for: beroenden harleddes ur rafarg. "Min bakgrund ar
// #f5f4ed, alltsa beror jag pa varje enhet som malar #f5f4ed." Det gav 1704
// kanter, 36 enheter i skenbara cykler och en pastadd forutsattningsslutning pa
// 67 enheter — inget av det fanns.
//
// Proven kraver att relationen kommer ur det faktiskt uppmatta elementets
// identitet, att tva olika foraldrar med samma farg forblir tva, att de bada
// beroendebegreppen aldrig kollapsar till ett, och att den frysta korpusen
// fortsatt rekonstrueras exakt.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { BEROENDETYP, BOTTEN, byggIndex, egetLager, foralderkedja, beroenden,
  rekonstruera, rekonstruktionsgrind, kantmangd, uppmattBakgrund,
  elementid, postid, hexAv, tolkaFarg } from './parent-resolution.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* Byggare for syntetiska matposter. Samma faltnamn som sonden skriver. */
const yta = (art, ordinal, varde, foralder, o = {}) => ({ art, elementOrdinal: ordinal,
  egenskap: 'background-color', varde, arAppytan: !!o.appyta,
  underliggandeYta: foralder === null ? null : { ordinal: foralder.ordinal, farg: foralder.farg },
  plattBakgrund: o.platt || null });
const forgrund = (art, ordinal, varde, foralder, o = {}) => ({ art, elementOrdinal: ordinal,
  egenskap: o.egenskap || 'color', varde, arAppytan: false,
  underliggandeYta: foralder === null ? null : { ordinal: foralder.ordinal, farg: foralder.farg },
  plattBakgrund: o.platt || null, ...(o.textbakgrund ? { text: { bakgrund: o.textbakgrund } } : {}) });

/* ── PR-01 · uppslag pa elementidentitet, aldrig pa rafarg ───────────────
   Lockbetet: ett element med EXAKT samma farg som den verkliga foraldern,
   men som inte ar forfader. En fargbaserad upplosning skulle plocka in det. */
{ const app = yta('a', 0, 'rgb(36, 56, 44)', null, { appyta: true });
  const verklig = yta('a', 2, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const lockbete = yta('a', 9, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const barn = yta('a', 5, 'rgb(206, 124, 30)', { ordinal: 2, farg: 'rgb(245, 244, 237)' });
  const ix = byggIndex([app, verklig, lockbete, barn]);
  const k = foralderkedja(barn, ix);
  const ids = k.lager.map(l => l.art + '|' + l.ordinal);
  prov('PR-01', 'foraldern loses ur faktisk elementidentitet, inte ur rafarg',
    ids.includes('a|2') && !ids.includes('a|9') && k.botten === BOTTEN.TACKANDE,
    'kedja [' + ids.join(' , ') + '] — lockbetet a|9 har samma farg som a|2 och kom inte med'); }

/* ── PR-02 · samma rafarg, olika foralderelement, olika beroende ────────*/
{ const app = yta('b', 0, 'rgb(36, 56, 44)', null, { appyta: true });
  const p1 = yta('b', 2, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const p2 = yta('b', 3, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const barn1 = yta('b', 6, 'rgb(206, 124, 30)', { ordinal: 2, farg: 'rgb(245, 244, 237)' });
  const barn2 = yta('b', 7, 'rgb(206, 124, 30)', { ordinal: 3, farg: 'rgb(245, 244, 237)' });
  const ix = byggIndex([app, p1, p2, barn1, barn2]);
  const d1 = beroenden(barn1, ix)[BEROENDETYP.PREVIEW_CONTEXT];
  const d2 = beroenden(barn2, ix)[BEROENDETYP.PREVIEW_CONTEXT];
  prov('PR-02', 'samma rafarg pa tva skilda foraldrar ger inte automatiskt samma beroende',
    JSON.stringify(d1) !== JSON.stringify(d2) && d1.includes('b|2') && d2.includes('b|3') &&
    hexAv(p1.varde) === hexAv(p2.varde),
    'identisk foralderfarg ' + hexAv(p1.varde) + ' — beroende [' + d1 + '] mot [' + d2 + ']'); }

/* ── PR-03 · tackande barn: inget compositingberoende, men previewkontext ─
   Har provas ocksa att modulen aldrig returnerar ett gemensamt "dependsOn". */
{ const app = yta('c', 0, 'rgb(36, 56, 44)', null, { appyta: true });
  const kort = yta('c', 2, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const tackande = yta('c', 5, 'rgb(206, 124, 30)', { ordinal: 2, farg: 'rgb(245, 244, 237)' });
  const ix = byggIndex([app, kort, tackande]);
  const b = beroenden(tackande, ix);
  const nycklar = Object.keys(b);
  prov('PR-03', 'en tackande yta saknar compositingberoende men behaller previewkontext',
    b[BEROENDETYP.COMPOSITING].length === 0 &&
    b[BEROENDETYP.PREVIEW_CONTEXT].join() === 'c|2' &&
    !nycklar.some(k => /^(dependsOn|beroende|beroenden|deps)$/i.test(k)),
    'compositing [] · previewkontext [c|2] · returnerade nycklar: ' + nycklar.join(', ')); }

/* ── PR-04 · genomskinligt barn far ratt compositingberoende ────────────*/
{ const app = yta('d', 0, 'rgb(36, 56, 44)', null, { appyta: true });
  const kort = yta('d', 2, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const genom = yta('d', 5, 'rgba(36, 56, 44, 0.4)', { ordinal: 2, farg: 'rgb(245, 244, 237)' },
    { platt: 'rgb(161, 169, 160)' });
  const ix = byggIndex([app, kort, genom]);
  const b = beroenden(genom, ix);
  const rek = rekonstruera(genom, ix);
  prov('PR-04', 'ett genomskinligt barn far compositingberoende mot sin FAKTISKA foralder',
    b[BEROENDETYP.COMPOSITING].join() === 'd|2' &&
    b[BEROENDETYP.PREVIEW_CONTEXT].join() === 'd|2' &&
    hexAv(rek) === hexAv(genom.plattBakgrund),
    'compositing [d|2] · omkomposition ' + hexAv(rek) + ' = uppmatt ' + hexAv(genom.plattBakgrund)); }

/* ── PR-05 · nastlad yta tar NARMASTE slutliga foralder ─────────────────
   Tva forfader har samma farg. Fel svar vore den yttre. */
{ const app = yta('e', 0, 'rgb(36, 56, 44)', null, { appyta: true });
  const yttre = yta('e', 2, 'rgb(245, 244, 237)', { ordinal: 0, farg: 'rgb(36, 56, 44)' });
  const inre = yta('e', 5, 'rgb(245, 244, 237)', { ordinal: 2, farg: 'rgb(245, 244, 237)' });
  const barn = yta('e', 8, 'rgb(204, 209, 194)', { ordinal: 5, farg: 'rgb(245, 244, 237)' });
  const ix = byggIndex([app, yttre, inre, barn]);
  const k = foralderkedja(barn, ix);
  prov('PR-05', 'nastlad upphojd yta loser narmaste slutliga foralder, inte valfri yta med samma farg',
    k.lager.length === 1 && k.lager[0].ordinal === 5 && k.botten === BOTTEN.TACKANDE,
    'valde e|5 (inre) och stannade dar — e|2 har identisk farg men ar ett led langre bort'); }

/* ── Fryst korpus for PR-06 … PR-10 ────────────────────────────────────*/
const KORPUS = JSON.parse(readFileSync(new URL('../fas2/r04-foralderkorpus.json', import.meta.url), 'utf8'));
const kIndex = byggIndex([...KORPUS.element, ...KORPUS.population]);
const enhetAv = post => { const t = KORPUS.population.find(q => q.art === post.art &&
  q.elementOrdinal === post.elementOrdinal && q.egenskap === post.egenskap);
  return t ? t.enhet : null; };
const kGraf = kantmangd(KORPUS.population, kIndex, enhetAv);

/* ── PR-06 · ingen rafargsfanout kan aterskapa 1704-kantsgrafen ─────────
   Referensimplementationen nedan ar den GAMLA regeln, medtagen enbart som
   kontrast. Den ligger i provet, aldrig i modulen.                        */
{ const enhetPerFarg = new Map();
  for (const p of KORPUS.population) { if (p.egenskap !== 'background-color') continue;
    const h = hexAv(p.varde); if (!enhetPerFarg.has(h)) enhetPerFarg.set(h, new Set());
    enhetPerFarg.get(h).add(p.enhet); }
  const hexkanter = new Set();
  for (const p of KORPUS.population) { const fran = p.enhet;
    const b = beroenden(p, kIndex);
    for (const id of b[BEROENDETYP.PREVIEW_CONTEXT]) {
      const lp = kIndex.bakgrundAv.get(id); if (!lp) continue;
      for (const till of (enhetPerFarg.get(hexAv(lp.varde)) || []))
        if (till !== fran) hexkanter.add(fran + ' ⇐ ' + till); } }
  // Och: ett lockbete med samma farg langre bort far inte andra kantmangden.
  const nagon = KORPUS.element.find(e => hexAv(e.varde) === '#f5f4ed' && !e.arAppytan);
  const lockbete = { ...nagon, elementOrdinal: 9999, arAppytan: false, underliggandeYta: null };
  const medLockbete = kantmangd(KORPUS.population, byggIndex([...KORPUS.element, lockbete,
    ...KORPUS.population]), enhetAv);
  prov('PR-06', 'ingen rafargsfanout kan aterskapa den gamla 1704-kantsgrafen',
    kGraf.kanter.length === 12 && hexkanter.size > kGraf.kanter.length * 10 &&
    medLockbete.kanter.length === kGraf.kanter.length,
    'elementupplost ' + kGraf.kanter.length + ' kanter · samma korpus med hexjoin ' + hexkanter.size +
    ' kanter · ett tillagt lockbete i samma farg andrar kantmangden med ' +
    (medLockbete.kanter.length - kGraf.kanter.length)); }

/* ── PR-07 · korpusen rekonstrueras exakt ──────────────────────────────*/
{ const g = rekonstruktionsgrind(KORPUS.population, kIndex);
  prov('PR-07', 'hela den frysta korpusen rekonstrueras exakt mot matningen',
    g.godkand && g.stammer === 665 && g.avviker === 0 && g.utanMatning === 0 &&
    g.stammer === KORPUS.$forvantat.rekonstruktion.stammer,
    g.stammer + '/' + g.instanser + ' uppmatta bakgrunder omkomponerade exakt · ' +
    g.avviker + ' avvikelser'); }

/* ── PR-08 · exakt forvantad relationsmangd, noll oforklarade ──────────*/
{ const f = KORPUS.$forvantat;
  const kanter = kGraf.kanter.slice().sort();
  const yttre = kGraf.yttre.map(y => y.element).sort();
  // Varje lager i varje previewkontext ska vara ETT av tre: appytan, en kant
  // till en enhet, eller en redovisad yttre yta. Ingen fjarde kategori.
  let oforklarade = 0;
  const yttreSet = new Set(yttre);
  for (const p of KORPUS.population) { const fran = p.enhet;
    for (const id of beroenden(p, kIndex)[BEROENDETYP.PREVIEW_CONTEXT]) {
      const [art, ord] = id.split('|');
      if (kIndex.appytaOrdinal.get(art) === +ord) continue;
      const lp = kIndex.bakgrundAv.get(id); const till = lp ? enhetAv(lp) : null;
      if (till && till !== fran) { if (kanter.includes(fran + ' ⇐ ' + till)) continue; }
      if (!till && yttreSet.has(id)) continue;
      if (till === fran) continue;
      oforklarade++; } }
  prov('PR-08', 'grafen har exakt den forvantade relationsmangden och noll oforklarade relationer',
    JSON.stringify(kanter) === JSON.stringify(f.kanter) &&
    JSON.stringify(yttre) === JSON.stringify(f.yttreYtor) && oforklarade === 0,
    kanter.length + ' kanter och ' + yttre.length + ' yttre ytor, identiska med det frysta forvantade · ' +
    oforklarade + ' oforklarade relationer'); }

/* ── PR-09 · obeslutad foralder blockerar previewberedskap ─────────────*/
const LOSTA_YTOR = post => kIndex.appytaOrdinal.get(post.art) === post.elementOrdinal;
function previewberedskap(enhet) {
  const instanser = KORPUS.population.filter(p => p.enhet === enhet);
  const kravda = new Set();
  for (const p of instanser) for (const id of beroenden(p, kIndex)[BEROENDETYP.PREVIEW_CONTEXT]) {
    const lp = kIndex.bakgrundAv.get(id);
    if (lp && LOSTA_YTOR(lp)) continue;
    kravda.add(id); }
  return { klar: kravda.size === 0, kravda: [...kravda] }; }
{ const blockerade = [...new Set(KORPUS.population.map(p => p.enhet))]
    .map(e => ({ e, b: previewberedskap(e) })).filter(x => !x.b.klar);
  const ex = blockerade[0];
  prov('PR-09', 'en obeslutad foralder blockerar previewberedskap',
    blockerade.length > 0 && ex.b.kravda.length > 0 &&
    ex.b.kravda.every(id => kIndex.bakgrundAv.has(id)),
    blockerade.length + ' enheter blockerade · exempel kraver ' + ex.b.kravda.length +
    ' obeslutad(e) foralderyta(or): ' + ex.b.kravda.slice(0, 2).join(', ')); }

/* ── PR-10 · lost foralder gor enheten previewbar utan orelaterade beslut */
{ const alla = [...new Set(KORPUS.population.map(p => p.enhet))];
  const fria = alla.filter(e => previewberedskap(e).klar);
  // Beredskapen far inte bero pa nagon annan enhets tillstand: samma svar
  // nar den raknas om med bara den egna enhetens instanser i populationen.
  const isolerat = fria.every(e => { const bara = KORPUS.population.filter(p => p.enhet === e);
    const ix2 = byggIndex([...KORPUS.element, ...bara]);
    return bara.every(p => beroenden(p, ix2)[BEROENDETYP.PREVIEW_CONTEXT]
      .every(id => { const lp = ix2.bakgrundAv.get(id); return lp && LOSTA_YTOR(lp); })); });
  prov('PR-10', 'en enhet med lost foralder ar previewbar utan orelaterade beslut',
    fria.length === 38 && isolerat,
    fria.length + ' av ' + alla.length + ' enheter previewbara · beredskapen oforandrad nar varje ' +
    'enhet rakans om isolerat fran ovriga'); }

const ANTAL = 10;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('FORALDERPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'foralderprov.json'),
  JSON.stringify({ resultat, BEROENDETYP, BOTTEN }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
