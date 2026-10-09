// BL-01 ankarrekonciliering: en kanonisk vokabulär.
//  - alla pf-a-ankare tas bort ur källan
//  - de 361 kanoniska Block-287-ankaren placeras på sina semantiska objekt
//  - nya kanoniska ankare myntas för de semantiska objekt som kräver persistent identitet
//    och bara hade ett pf-a-ankare
// Skriver bara i det temporära BL-01-trädet.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { startTags } from './bl01-kallskanner.mjs';
const SC = process.argv[2], REPO = process.argv[3];
const T = SC + '/bl01/tree/';
const IDX = JSON.parse(readFileSync(SC + '/bl01/idx-pfa.json', 'utf8'));
const CANON = JSON.parse(readFileSync(SC + '/bl01/canon-map.json', 'utf8'));
const PFA = JSON.parse(readFileSync(SC + '/bl01/pfa-anchors.json', 'utf8'));
const existing = new Set([...CANON.map(c => c.anchor), ...PFA.map(p => p.occ)]);

const LETTERS = 'abcdefghijklmnopqrstuvwxyz';
function mint(key) {
  for (let n = 0; n < 50; n++) {
    const h = createHash('sha256').update('BL01-ANCHOR|' + key + '|' + n).digest();
    let s = 'occ-'; for (let i = 0; i < 12; i++) s += LETTERS[h[i] % 26];
    if (!existing.has(s)) { existing.add(s); return s; }
  }
  throw new Error('kan inte mynta unikt ankare for ' + key);
}

// semantiska objekt som kräver persistent identitet och bara bär ett pf-a-ankare
const needed = PFA.filter(p => (p.refs || []).some(f => /^block287-/.test(f)));
const minted = needed.map(p => ({
  OLD_PF_A_ANCHOR: p.occ,
  SEMANTIC_OBJECT: p.art + '#' + p.ordProd + ' <' + p.tag + '> "' + (p.text || '').slice(0, 60) + '"',
  fil: p.fil, art: p.art, ordProd: p.ordProd,
  CANONICAL_BL01_ANCHOR: mint(p.fil + '|' + p.art + '|' + p.tag + '|' + (p.text || '').slice(0, 60)),
  REASON: 'semantiskt objekt som Block 287 använder som persistent ägaridentitet; pf-a-värdet får inte bli kanoniskt'
}));

const tplOf = new Map(IDX.map(e => [e.fil + '|' + e.art + '#' + e.ordProd, Number(e.tpl)]));
const plan = {};
const add = (fil, tpl, anchor, kind) => { (plan[fil] = plan[fil] || []).push({ tpl, anchor, kind }); };
for (const c of CANON) add(c.fil, tplOf.get(c.fil + '|' + c.art + '#' + c.ordProd), c.anchor, 'CANONICAL_REUSED');
for (const m of minted) add(m.fil, tplOf.get(m.fil + '|' + m.art + '#' + m.ordProd), m.CANONICAL_BL01_ANCHOR, 'NEW_CANONICAL');

let removed = 0, inserted = 0;
for (const [fil, items] of Object.entries(plan)) {
  const src = readFileSync(T + fil, 'utf8');
  const tags = startTags(src);
  const edits = [];
  for (const m of src.matchAll(/ data-occurrence="[^"]*"/g)) { edits.push({ at: m.index, len: m[0].length, ins: '' }); removed++; }
  for (const it of items) {
    if (!Number.isInteger(it.tpl)) throw new Error('FAIL CLOSED: saknar tpl for ' + it.anchor);
    const t = tags[it.tpl];
    if (!t) throw new Error('FAIL CLOSED: ingen starttagg med index ' + it.tpl + ' i ' + fil);
    edits.push({ at: t.nameEnd, len: 0, ins: ' data-occurrence="' + it.anchor + '"' }); inserted++;
  }
  edits.sort((a, b) => b.at - a.at || b.len - a.len);
  let out = src;
  for (const e of edits) out = out.slice(0, e.at) + e.ins + out.slice(e.at + e.len);
  writeFileSync(T + fil, out);
}
writeFileSync(SC + '/bl01/anchor-reconciliation.json', JSON.stringify({
  HEAD_CANONICAL_ANCHOR_COUNT: CANON.length,
  PF_A_LEGACY_ANCHOR_COUNT: PFA.length,
  CANONICAL_ANCHORS_REUSED: CANON.length,
  NEW_CANONICAL_ANCHORS_REQUIRED: minted.length,
  PF_A_ANCHORS_RETIRED: PFA.length,
  AMBIGUOUS_ANCHOR_MAPPINGS: CANON.filter(c => !c.tagOk || !c.textOk).length,
  minted
}, null, 1));
console.log('borttagna pf-a-attribut:', removed, '| insatta kanoniska:', inserted, '| nymyntade:', minted.length);
