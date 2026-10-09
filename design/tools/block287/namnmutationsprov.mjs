// Kor: node tools/block287/namnmutationsprov.mjs <kallrot> <utfil> <elementindex.json>
// D · Exakt uppsattning agare vars identitet inte overlever en semantiskt neutral namnandring.
import { readFileSync, writeFileSync } from 'node:fs';
import { semantiskAgare, narmasteAnkare } from '../semantic-owner-identity.mjs';
import { ramIndex, slug, kortFil } from '../bl01-skrivnyckel.mjs';
const [, , ROT, UT] = process.argv;
const IDX = JSON.parse(readFileSync(process.argv[4], 'utf8'));
const RAM = ramIndex(IDX);
const etikett = {};
for (const f of [...new Set(IDX.map(e => e.fil))]) {
  const src = readFileSync(ROT + '/' + f, 'utf8');
  for (const m of src.matchAll(/class="sc-item" id="([^"]+)"[^>]*data-screen-label="([^"]*)"/g)) etikett[m[1]] = m[2];
}
const kedjaFor = e => {
  const led = [{ occ: e.occ, innehall: [] }];
  for (const o of e.anc || []) { const p = RAM.get(e.art + '#' + o); led.push({ occ: p ? p.occ : null, innehall: p ? [(p.own || '')].filter(Boolean) : [] }); }
  return led;
};
const fakta = (e, over) => {
  const k = Object.assign({ art: e.art, namn: e.name || e.own || '', roll: e.role || null, glyf: e.icon || null,
    text: (e.own || '').trim(), ramEtikett: etikett[e.art] || '', iLista: !!(e.anc || []).length, kedja: kedjaFor(e) }, over || {});
  return Object.assign(k, { objekt: narmasteAnkare(k.kedja) });
};
const idAv = (e, over) => { const r = semantiskAgare(fakta(e, over)); return r.nyckel || null; };
const MUT = [
  ['a11y-namnrattelse', s => s ? s + ', rattat' : s],
  ['kopieredigering', s => s ? String(s).replace(/e/g, 'e ').trim() : s],
  ['etikettforydligande', s => s ? 'Val: ' + s : s],
  ['lokaliseringslik omskrivning', s => s ? String(s).split('').reverse().join('') : s],
  ['lagesord', s => s ? s + ' (pa)' : s],
  ['terminologibyte', s => s ? String(s).replace(/recept/gi, 'matsedel').replace(/lista/gi, 'samling') : s]
];
const instabila = [];
for (const e of IDX) {
  if (!(e.role || e.occ)) continue;
  const bas = idAv(e); if (!bas) continue;
  const brott = [];
  for (const m of MUT) {
    const namnMut = idAv(e, { namn: m[1](e.name || e.own || '') });
    const textMut = idAv(e, { text: m[1]((e.own || '').trim()), namn: m[1](e.name || e.own || '') });
    if (namnMut !== bas || textMut !== bas) brott.push(m[0]);
  }
  if (brott.length) instabila.push({ RAM: e.art, ordProd: e.ordProd, FIL: kortFil(e.fil), TAGG: e.tag,
    ROLL: e.role || null, NAMN: e.name || null, TEXT: String(e.own || '').slice(0, 45),
    EGET_ANKARE: e.occ || null, BAS_NYCKEL: bas, REGEL: semantiskAgare(fakta(e)).regel, BROTT: brott, tpl: e.tpl });
}
const per = {}; for (const r of instabila) per[r.REGEL] = (per[r.REGEL] || 0) + 1;
const medAnkare = instabila.filter(r => r.EGET_ANKARE).length;
writeFileSync(UT, JSON.stringify({ TESTADE: IDX.filter(e => e.role || e.occ).length, INSTABILA: instabila.length,
  MED_EGET_ANKARE: medAnkare, PER_REGEL: per, rader: instabila }, null, 1) + '\n');
console.log('testade:', IDX.filter(e => e.role || e.occ).length, '| instabila:', instabila.length, '| varav med eget ankare:', medAnkare);
console.log('per regel:', JSON.stringify(per));
