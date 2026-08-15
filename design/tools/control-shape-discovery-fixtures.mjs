#!/usr/bin/env node
// F2 · BESTANDIGA PROV FOR UPPTACKTEN AV ODEKLARERADE KONTROLLER.
//
// Kör: node tools/control-shape-discovery-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// Den gamla upptackten var bunden till authored data-component och en enda
// hardkodad form. Korpusen anvander data-component bara for toggle, checkbox
// och chip, sa knappar och textfalt kunde aldrig bli kandidater. I
// dialogsparameny fanns kryssrutan i listan medan Avbryt och Spara inte gjorde
// det — trots att deras kropp ar identisk med 349 deklarerade kontroller.
//
// Den nya regeln ar harledd ur den deklarerade populationen. Da uppstar tva
// nya risker som maste lasas: att upptackt smyger over i verdikt, och att en
// redan adjudicerad grannes semantik smittar av sig pa objekt bredvid.
//
//   UDC-01  ett verkligt odeklarerat knappobjekt upptacks
//   UDC-02  ett visuellt likande men icke-interaktivt objekt blir inte kontroll
//   UDC-03  upptackt ger kandidat, aldrig verdikt
//   UDC-04  ett redan deklarerat objekt ligger inte kvar i listan
//   UDC-05  radagare och visuellt barn dedupliceras
//   UDC-06  tvetydigt agarskap ger fail closed, ingen kandidat
//   UDC-07  befintliga stabila identiteter bevaras
//   UDC-08  dialogsparaменy-kryssrutan forblir samma objekt, ingen dublett
//   UDC-09  en kand kryssruta i en dialog gor inte syskonen interaktiva
//   UDC-10  skarmkontext far utlosa granskning men aldrig verdikt

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { upptack, harKontrollkropp, arDeklarerad, TRAFFYTA_MIN } from './control-shape-discovery.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });
const rot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/* Byggstenar. KROPP ar korpusens kontrollkropp; varje prov tar bort exakt en
 * egenskap, sa att det som provas ar just den saknade biten.               */
const KROPP = { harFyllning: true, helRam: false, harEgenText: true, inreMalande: 0,
  svgAntal: 0, display: 'flex', align: 'center', justify: 'center', w: 155, h: 48,
  tagg: 'div', roll: null, forfaderRoll: null, fil: 'prov.html', egenText: 'Spara' };
const o = (art, ordinal, extra = {}) => ({ art, ordinal, ...KROPP, ...extra });

/* ── UDC-01 · ett verkligt odeklarerat knappobjekt upptacks ─────────*/
{ const r = upptack([ o('D', 11, { egenText: 'Avbryt', harFyllning: false, helRam: true }),
    o('D', 12, { egenText: 'Spara' }) ]);
  prov('UDC-01', 'ett verkligt odeklarerat knappobjekt med korpusens kontrollkropp upptacks',
    r.nya_st === 2 && r.nya.every(x => x.w >= TRAFFYTA_MIN && x.h >= TRAFFYTA_MIN),
    r.nya_st + ' kandidater: ' + r.nya.map(x => x.identitet + ' "' + x.egenText + '"').join(', ')); }

/* ── UDC-02 · visuellt likande men icke-interaktivt ─────────────────*/
{ // En informationspanel: samma fyllning och egen text, men den centrerar inte
  // sitt innehall och den ar en blockbehallare. Den har alltsa inte kroppen.
  const panel = o('P', 5, { display: 'block', align: 'normal', w: 372, h: 96,
    egenText: 'Det som forsvinner ar inte det den handlade om.' });
  const k = harKontrollkropp(panel);
  const r = upptack([panel]);
  prov('UDC-02', 'ett visuellt likande men icke-interaktivt objekt blir inte kontroll',
    !k.ja && r.nya_st === 0 && k.brist.includes('CENTRERAT_INNEHALL'),
    'panelen ' + k.skal + ' → ' + r.nya_st + ' kandidater'); }

/* ── UDC-03 · upptackt ar inte verdikt ──────────────────────────────*/
{ const r = upptack([ o('D', 12) ]);
  const k = r.nya[0];
  prov('UDC-03', 'upptackt ger kandidat, aldrig verdikt eller roll',
    r.nya_st === 1 && k.verdikt === null && k.roll === null &&
    !Object.prototype.hasOwnProperty.call(r, 'kontroller_st'),
    'kandidaten har verdikt ' + k.verdikt + ' och roll ' + k.roll); }

/* ── UDC-04 · redan deklarerat ligger inte kvar ─────────────────────*/
{ const r = upptack([ o('D', 12, { roll: 'button' }),
    o('D', 13, { forfaderRoll: 'button' }), o('D', 14) ]);
  prov('UDC-04', 'ett redan deklarerat objekt ligger inte kvar i den odeklarerade listan',
    r.nya_st === 1 && r.nya[0].identitet === 'D|14' &&
    // Bada de deklarerade raknas som deklarerade med kontrollkropp — det ar de
    // som utgor beviset for att formen ar korpusens egen.
    r.deklareradeMedKontrollkropp_st === 2 && arDeklarerad({ roll: 'button' }) &&
    arDeklarerad({ forfaderRoll: 'button' }),
    'egen roll och forfaderroll bada uteslutna → kvar: ' +
      r.nya.map(x => x.identitet).join(',') + '; deklarerade med kroppen: ' +
      r.deklareradeMedKontrollkropp_st); }

/* ── UDC-05 · radagare och visuellt barn dedupliceras ───────────────*/
{ // Raden ar redan kandidat i den ra listan. Det visuella barnet har samma
  // renderade box. Det far INTE bli en andra kandidat for samma objekt.
  const rad = o('R', 20, { w: 364, h: 48 });
  const barn = o('R', 21, { w: 364, h: 48 });
  const r = upptack([rad, barn], new Set(['R|20']));
  prov('UDC-05', 'radagare och visuellt barn med samma box ger inte tva kandidater',
    r.nya_st === 0 && r.redanKanda_st === 1 && r.tvetydigaAgare_st === 1 &&
    r.tvetydigaAgare[0].identitet === 'R|21' && r.invariant_ok,
    'raden ar redan kand, barnet hamnar i tvetydigaAgare: ' +
      JSON.stringify(r.tvetydigaAgare.map(x => x.identitet))); }

/* ── UDC-06 · tvetydigt agarskap ar fail closed ─────────────────────*/
{ const r = upptack([ o('A', 30, { w: 200, h: 60 }), o('A', 31, { w: 200, h: 60 }) ],
    new Set(['A|30']));
  prov('UDC-06', 'tvetydigt agarskap ger fail closed — ingen kandidat, en redovisad post',
    r.nya_st === 0 && r.tvetydigaAgare_st === 1 &&
    /gar inte att avgora/.test(r.tvetydigaAgare[0].skal) && r.invariant_ok,
    'skal: ' + r.tvetydigaAgare[0].skal); }

/* ── UDC-07 · befintliga stabila identiteter bevaras ────────────────*/
{ const bef = new Set(['X|1', 'X|2', 'X|3']);
  const r = upptack([ o('X', 1), o('X', 2, { w: 300, h: 70 }), o('X', 9, { w: 120, h: 90 }) ], bef);
  const bevarade = [...bef].every(id => !r.nya.some(x => x.identitet === id));
  prov('UDC-07', 'befintliga stabila identiteter bevaras och aterupptacks aldrig som nya',
    bevarade && r.redanKanda_st === 2 && r.nya_st === 1 && r.nya[0].identitet === 'X|9',
    'redan kanda ' + JSON.stringify(r.redanKanda) + ', nya ' +
      JSON.stringify(r.nya.map(x => x.identitet))); }

/* ── UDC-08 · kryssrutan forblir samma objekt ───────────────────────*/
{ // dialogsparameny|8 ar en 24x24 ruta utan egen text. Den har inte
  // kontrollkroppen och kan darfor aldrig bli en dublett via den har regeln.
  const kryss = { art: 'dialogsparameny', ordinal: 8, harFyllning: false, helRam: true,
    harEgenText: false, inreMalande: 0, svgAntal: 0, display: 'block', align: 'normal',
    w: 24, h: 24, tagg: 'div', roll: null, forfaderRoll: null, egenText: '' };
  const k = harKontrollkropp(kryss);
  const r = upptack([kryss, o('dialogsparameny', 11, { egenText: 'Avbryt' })],
    new Set(['dialogsparameny|8']));
  prov('UDC-08', 'dialogsparameny-kryssrutan forblir samma objekt, ingen dublett',
    !k.ja && r.nya_st === 1 && r.nya[0].identitet === 'dialogsparameny|11' &&
    !r.nya.some(x => x.identitet === 'dialogsparameny|8'),
    'kryssrutan ' + k.skal + '; nya: ' + r.nya.map(x => x.identitet).join(',')); }

/* ── UDC-09 · ingen semantisk smitta fran en kand granne ────────────*/
{ // Exakt samma tva objekt, en gang med och en gang utan en KAND interaktiv
  // kryssruta i samma artefakt. Utfallet maste vara identiskt.
  const utan = upptack([ o('S', 11, { egenText: 'Avbryt' }), o('S', 12) ]);
  const med = upptack([ { art: 'S', ordinal: 8, harFyllning: false, helRam: true,
      harEgenText: false, inreMalande: 0, svgAntal: 0, display: 'block', align: 'normal',
      w: 24, h: 24, tagg: 'div', roll: 'checkbox', forfaderRoll: null, egenText: '' },
    o('S', 11, { egenText: 'Avbryt' }), o('S', 12) ]);
  const lika = JSON.stringify(utan.nya.map(x => [x.identitet, x.verdikt, x.roll])) ===
    JSON.stringify(med.nya.map(x => [x.identitet, x.verdikt, x.roll]));
  prov('UDC-09', 'en kand interaktiv kryssruta gor inte syskonen interaktiva',
    lika && med.nya.every(x => x.verdikt === null && x.roll === null),
    'med och utan deklarerad granne ger identiskt utfall: ' + lika +
      '; syskonens verdikt ' + JSON.stringify(med.nya.map(x => x.verdikt))); }

/* ── UDC-10 · skarmkontext utloser granskning, aldrig verdikt ───────*/
{ // Samma objekt i tva artefakter med olika namn. Upptackten far inte skilja
  // pa dem, och far inte satta verdikt i nagon av dem.
  const a = upptack([ o('dialogsparameny', 12) ]);
  const b = upptack([ o('nagonannanskarm', 12) ]);
  const MOD = readFileSync(join(rot, 'tools', 'control-shape-discovery.mjs'), 'utf8');
  const ingenSkarmreferens = !/dialogsparameny|inkopmerge|kontovantan|delatlista/.test(
    MOD.replace(/^\/\/.*$/gm, ''));
  prov('UDC-10', 'skarmkontext far utlosa granskning men aldrig verdikt',
    a.nya_st === b.nya_st && a.nya[0].verdikt === null && b.nya[0].verdikt === null &&
    ingenSkarmreferens,
    'samma utfall i bada artefakterna; ingen skarm-id i regelkoden: ' + ingenSkarmreferens); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('UPPTACKTSPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'udcprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
