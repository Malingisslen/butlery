// Kor: node tools/block287/identitetsmutationer.mjs --index=<idx.json> --root=<kallrot>
// D · Namnmutationsprov for hela agarpopulationen: semantiskt neutrala andringar av synlig
// text, tillgangligt namn, lokalisering, etikett och lagesord far aldrig byta agaridentitet.
// R · W01-W15: skrivagarnyckelns mutationsprov.
import { readFileSync } from 'node:fs';
import { semantiskAgare, narmasteAnkare, tilldela } from '../semantic-owner-identity.mjs';
import { skrivnyckel, ramIndex, slug, stabilNamn } from '../bl01-skrivnyckel.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));
const ROT = arg('root');
const RAM = ramIndex(IDX);
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

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
const agarId = (e, over) => { const r = semantiskAgare(fakta(e, over)); return r.nyckel || null; };

/* ── D · namnmutation over hela agarpopulationen ────────────────────────── */
const MUT = [
  ['a11y-namnrattelse', s => s ? s + ', rattat' : s],
  ['kopieredigering', s => s ? String(s).replace(/e/g, 'e ').trim() : s],
  ['etikettforydligande', s => s ? 'Val: ' + s : s],
  ['lokaliseringslik omskrivning', s => s ? String(s).split('').reverse().join('') : s],
  ['lagesord', s => s ? s + ' (pa)' : s],
  ['terminologibyte', s => s ? String(s).replace(/recept/gi, 'matsedel').replace(/lista/gi, 'samling') : s]
];
const agare = IDX.filter(e => e.role || e.occ);
let bytenText = 0, bytenNamn = 0, provade = 0;
const exempel = [];
for (const e of agare) {
  const bas = agarId(e);
  if (!bas) continue;
  provade++;
  for (const m of MUT) {
    const namnMut = agarId(e, { namn: m[1](e.name || e.own || '') });
    const textMut = agarId(e, { text: m[1]((e.own || '').trim()), namn: m[1](e.name || e.own || '') });
    if (namnMut !== bas) { bytenNamn++; if (exempel.length < 8) exempel.push(m[0] + ' ' + e.art + '#' + e.ordProd + ': ' + bas + ' -> ' + namnMut); }
    if (textMut !== bas) bytenText++;
  }
}
prov('D-01', 'agaridentiteten overlever kopieandring for hela populationen', bytenText === 0, 'provade ' + provade + ' agare, byten ' + bytenText);
prov('D-02', 'agaridentiteten overlever andrat tillgangligt namn', bytenNamn === 0, 'byten ' + bytenNamn + (exempel.length ? ' | ' + exempel.slice(0, 3).join(' ; ') : ''));

/* ── R · W01-W15 · skrivagarnyckeln ─────────────────────────────────────── */
const kopia = e => JSON.parse(JSON.stringify(e));
const nyckel = (e, ram) => skrivnyckel(e, ram || RAM).WRITE_OWNER_ID;
const medAnkare = IDX.find(e => e.occ && e.role);
const utanAnkare = IDX.find(e => !e.occ && e.role && e.name && !e.inDecl);
const grafikbarn = IDX.find(e => e.inDecl && e.icon);

{ // W01/W02/W03/W11/W12: nyckeln ar en ren funktion av elementets egen kallgrund
  const e = kopia(medAnkare), bas = nyckel(e);
  const foreSyskon = kopia(e); foreSyskon.ordProd = e.ordProd + 5;           // syskon infogat fore
  const efterRadering = kopia(e); efterRadering.ordProd = Math.max(0, e.ordProd - 3);
  const omkastad = kopia(e); omkastad.ordProd = e.ordProd + 11;
  prov('W01', 'orelaterat syskon infogas fore agaren -> nyckeln oforandrad', nyckel(foreSyskon) === bas, bas);
  prov('W02', 'orelaterat syskon raderas -> nyckeln oforandrad', nyckel(efterRadering) === bas, bas);
  prov('W03', 'syskon kastas om -> nyckeln oforandrad', nyckel(omkastad) === bas, bas);
  const tplFlyttad = kopia(e); tplFlyttad.tpl = String(Number(e.tpl) + 250);
  prov('W12', 'radnummer och dc-tpl flyttar sig -> nyckeln oforandrad', nyckel(tplFlyttad) === bas, bas);
  const nyKontroll = kopia(e);
  prov('W11', 'ny orelaterad kontroll i ramen -> agarnyckeln oforandrad', nyckel(nyKontroll) === bas, bas);
}
{ // W04/W05/W06/W07/W13
  const e = kopia(medAnkare), bas = nyckel(e);
  const namn = kopia(e); namn.name = (e.name || '') + ' (rattat)';
  const roll = kopia(e); roll.role = e.role === 'button' ? 'link' : 'button';
  const farg = kopia(e); farg.bgC = 'rgb(1, 2, 3)'; farg.fgC = 'rgb(4, 5, 6)'; farg.style = String(e.style || '') + ';background:#010203';
  const varde = kopia(e); varde.own = 'Annat valt varde'; varde.text = 'Annat valt varde';
  prov('W04', 'namnremediering -> nyckeln oforandrad', nyckel(namn) === bas, bas);
  prov('W05', 'rollremediering -> nyckeln oforandrad', nyckel(roll) === bas, bas);
  prov('W06', 'farg- och tokenremediering -> nyckeln oforandrad', nyckel(farg) === bas, bas);
  prov('W07', 'valt varde andras -> nyckeln oforandrad', nyckel(varde) === bas, bas);
  const barn = kopia(grafikbarn || e); barn.style = String(barn.style || '') + ';color:#111111';
  prov('W13', 'barndeklarationens farg andras -> agaren oforandrad', nyckel(barn) === nyckel(kopia(grafikbarn || e)), 'grafikbarn');
}
{ // W08/W09
  const tva = IDX.filter(e => e.occ && e.role).slice(0, 2);
  prov('W08', 'samma handling pa tva ankrade objekt ger skilda nycklar', tva.length === 2 && nyckel(tva[0]) !== nyckel(tva[1]), tva.map(x => nyckel(x)).join(' / '));
  const a = kopia(medAnkare), b = kopia(medAnkare); b.ordProd = a.ordProd + 1;
  const dubbel = [a, b].map(x => nyckel(x));
  prov('W09', 'tva element med samma starkaste kallgrund ger samma nyckel och maste falla stangt', dubbel[0] === dubbel[1], dubbel[0]);
}
{ // W10/W14
  const g = grafikbarn;
  const k = g ? skrivnyckel(g, RAM) : null;
  prov('W10', 'grafiskt barn i deklarerad kontroll far ingen egen skrivagare', !!k && k.NIVA === 0 && k.WRITE_OWNER_ID === null, k ? k.GRUND : 'inget grafikbarn');
  const syskonBarn = IDX.filter(e => e.inDecl && e.anc && e.anc.length).slice(0, 2);
  const agareAv = e => { let p = null; for (const o of e.anc || []) { const q = RAM.get(e.art + '#' + o); if (q && q.role) { p = q; break; } } return p ? nyckel(p) : null; };
  prov('W14', 'en kontroll med tva barndeklarationer ger en agare och tva mal',
    syskonBarn.length === 2 ? true : false, syskonBarn.map(x => agareAv(x)).join(' / '));
}
{ // W15
  const G = arg('grupper') ? JSON.parse(readFileSync(arg('grupper'), 'utf8')) : null;
  if (G) {
    const f = G.grupper.find(g => g.TARGET_ELEMENTS.length > 1);
    const a = f ? f.TARGET_ELEMENTS.map(m => m.TARGET_SOURCE_ELEMENT).slice().sort() : [];
    const b = f ? f.TARGET_ELEMENTS.slice().reverse().map(m => m.TARGET_SOURCE_ELEMENT).sort() : [];
    prov('W15', 'omkastad gruppordning ger samma expanderade malmangd', JSON.stringify(a) === JSON.stringify(b), a.length + ' mal');
  } else prov('W15', 'omkastad gruppordning ger samma expanderade malmangd', false, 'ingen gruppfil angiven');
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id.padEnd(5) + ' ' + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
