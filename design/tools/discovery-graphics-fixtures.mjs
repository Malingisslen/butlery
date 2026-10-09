#!/usr/bin/env node
// Prov for fristaende grafik i upptackten (Block 287 omgang 6).
// Kor: node tools/discovery-graphics-fixtures.mjs
import { grafikkandidater } from './discovery-population.mjs';
import { tilldelaAgare } from './discovery-identity.mjs';

const BAS = { fil: 'prov.dc.html', art: 'prov', tagg: 'svg', roll: null, forfaderRoll: null, iSvg: true, komponent: null,
  grafikroll: 'required', ikoner: ['paperclip'], attr: {}, hitTarget: null, egenTextLangd: 0, svgAntal: 0, text: '',
  anker: 'ram', foraldraProd: [1], ordProd: 5, w: 20, h: 20, x: 0, y: 0 };
const o = (x = {}) => ({ ...BAS, ...x });
const rad = { ...BAS, tagg: 'div', iSvg: false, grafikroll: null, ikoner: [], ordProd: 1, foraldraProd: [], egenTextLangd: 0, svgAntal: 2 };
const res = []; const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag) });
const kand = (xs, k = []) => grafikkandidater(xs, k);

{ const r = kand([rad, o()]); prov('SVG-01', 'fristaende required-glyf utan kontrollagare blir kandidat', r.length === 1 && r[0].ordinal === 5, r.length); }
{ const r = kand([rad, o({ grafikroll: 'decorative' })]); prov('SVG-02', 'dekorativ fristaende glyf blir inte kandidat', r.length === 0, r.length); }
{ const r = kand([rad, o({ forfaderRoll: 'button' })]); prov('SVG-03', 'glyf inuti deklarerad knapp blir grafikbarn, inte ny kandidat', r.length === 0, r.length);
  const omslag = { ...BAS, tagg: 'div', iSvg: false, grafikroll: null, ikoner: [], ordProd: 1, foraldraProd: [], egenTextLangd: 0, svgAntal: 1, ordinal: 1 };
  const r2 = kand([omslag, o()], [{ ...omslag, ordinal: 1 }]);
  prov('SVG-03b', 'glyf som ar enda innehallet i en kandidat ags av omslaget', r2.length === 0, r2.length); }
{ const g = kand([rad, o({ grafikroll: null, attr: { 'data-action': 'bifoga' } })]);
  const t = tilldelaAgare([{ objekt: g[0], klass: 'KNOWN_CONTROL' }]);
  prov('SVG-04', 'glyf med kallforfattad action blir kandidat och far agare ur bindningen', g.length === 1 && /bind::bifoga/.test(t[0].agarId), t[0].agarId); }
{ const a = tilldelaAgare([{ objekt: o({ ordProd: 5 }), klass: 'KNOWN_CONTROL' }, { objekt: o({ ordProd: 6, ikoner: ['camera'] }), klass: 'KNOWN_CONTROL' }]);
  const b = tilldelaAgare([{ objekt: o({ ordProd: 9, ikoner: ['camera'] }), klass: 'KNOWN_CONTROL' }, { objekt: o({ ordProd: 2 }), klass: 'KNOWN_CONTROL' }]);
  const id = xs => xs.find(x => x.objekt.ikoner[0] === 'paperclip').agarId;
  prov('SVG-05', 'filordning och syskonflytt andrar inte agaren', id(a) === id(b) && id(a) !== null, id(a)); }
{ const r = kand([{ ...rad, egenTextLangd: 12 }, o({ grafikroll: 'redundant' })]), r2 = kand([rad, o({ grafikroll: 'redundant' })]);
  prov('SVG-06', 'redundant glyf tas med bara nar redundansen inte kan provas (ingen text)', r.length === 0 && r2.length === 1, r.length + '/' + r2.length); }
{ const t = tilldelaAgare([{ objekt: o({ ordProd: 5 }), klass: 'UNKNOWN_SEMANTICS' }]);
  prov('SVG-07', 'okand grafik far aldrig agar-id', t[0].agarId === null, t[0].agarStatus); }

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
