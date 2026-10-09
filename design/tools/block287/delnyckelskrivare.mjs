// Kor: node tools/block287/delnyckelskrivare.mjs --root=<kallrot> --index=<idx.json>
//      --mal=<ram#ord,ram#ord> --del=<delnyckel> --ut=<paket.json> [--torr] [--utkast=<kat>]
//
// Skriver fysiska malidentifierare, data-part-occurrence, pa exakt de element
// som anges. Detta ar MALidentitet, inte agaridentitet: den skapar eller
// ersatter aldrig en semantisk agare.
//
// Delnyckeln ska namnge delens STRUKTURELLA ROLL i agaren. Den far aldrig vara
// synlig text, valt varde, tillgangligt namn, DOM-index, barnnummer, radnummer,
// geometri, farg, tillstand eller dokumentordning.
//
// Verktyget vagrar skriva om elementet redan bar en delnyckel, och kontrollerar
// att filen blir byteidentisk igen om attributen tas bort.
import { readFileSync, writeFileSync } from 'node:fs';
import { startTags } from '../bl01-kallskanner.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), TORR = process.argv.includes('--torr');
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));
const DEL = arg('del');
if (!DEL) { console.error('✖ --del=<delnyckel> kravs'); process.exit(2); }

const FORBJUDET = [
  [/^\d+$/, 'rent tal'],
  [/(barn|child|element|index|pos|nr)-?\d+/i, 'index'],
  [/^(forsta|andra|tredje|first|second|third)/i, 'ordningsord'],
  [/^\d+px$/i, 'geometri'],
  [/^#[0-9a-f]{3,8}$/i, 'fargvarde']
];
for (const [re, vad] of FORBJUDET)
  if (re.test(DEL)) { console.error('✖ delnyckeln "' + DEL + '" ar ' + vad + ' - forbjudet som identitet'); process.exit(2); }

const mal = String(arg('mal')).split(',').map(s => s.trim()).filter(Boolean);
if (!mal.length) { console.error('✖ --mal=<ram#ord,...> kravs'); process.exit(2); }

const rader = [], perFil = {};
const kalla = {};
for (const m of mal) {
  const [art, ord] = m.split('#');
  const traff = IDX.filter(e => e.art === art && String(e.ordProd) === ord);
  if (traff.length !== 1) { console.error('✖ flertydigt eller saknat mal: ' + m + ' (' + traff.length + ' element)'); process.exit(2); }
  const e = traff[0];
  if (e.partOcc) { console.error('✖ STOPP: ' + m + ' bar redan delnyckeln "' + e.partOcc + '"'); process.exit(2); }
  if (!kalla[e.fil]) kalla[e.fil] = readFileSync(ROT + '/' + e.fil, 'utf8');
  rader.push({ TARGET: m, FRAME: e.art, ORD: e.ordProd, SOURCE_FILE: e.fil, DC_TPL: Number(e.tpl),
    ELEMENT: '<' + e.tag + '> "' + String(e.own || '').trim().slice(0, 40) + '"',
    SEMANTIC_ANCHOR_ON_ELEMENT: e.occ || null,
    DATA_PART_OCCURRENCE: DEL });
  (perFil[e.fil] = perFil[e.fil] || []).push({ tpl: Number(e.tpl), del: DEL });
}
if (rader.length !== new Set(rader.map(r => r.TARGET)).size) { console.error('✖ dubbletter i malmangden'); process.exit(2); }

let skrivna = 0;
for (const [f, lista] of Object.entries(perFil)) {
  const src = kalla[f];
  const tags = startTags(src);
  const punkter = lista.map(x => {
    const t = tags[x.tpl];
    if (!t) throw new Error('ingen starttagg for tpl ' + x.tpl + ' i ' + f);
    const huvud = src.slice(t.start, t.tagEnd);
    if (/data-part-occurrence=/.test(huvud)) throw new Error('elementet bar redan en delnyckel: ' + f + ' tpl ' + x.tpl);
    return { pos: t.nameEnd, text: ' data-part-occurrence="' + x.del + '"' };
  }).sort((a, b) => b.pos - a.pos);
  let ut = src;
  for (const p of punkter) ut = ut.slice(0, p.pos) + p.text + ut.slice(p.pos);
  let ater = ut;
  for (const x of lista) ater = ater.replace(' data-part-occurrence="' + x.del + '"', '');
  if (ater !== src) throw new Error('aterstallning ar inte byteidentisk for ' + f);
  if (TORR) { if (arg('utkast')) writeFileSync(arg('utkast') + '/' + f, ut); }
  else writeFileSync(ROT + '/' + f, ut);
  skrivna += punkter.length;
}

const ut = {
  $om: 'Fysiska malidentifierare · data-part-occurrence',
  TARGET_COUNT: rader.length,
  AMBIGUOUS_TARGETS: 0,
  DUPLICATE_TARGETS: 0,
  NEW_DATA_PART_OCCURRENCE: TORR ? 0 : skrivna,
  DRY_RUN: TORR,
  VOCABULARY: 'data-part-occurrence (fysisk delidentitet, aldrig semantisk agare)',
  rader
};
if (arg('ut')) writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
console.log(JSON.stringify(ut, null, 1));
