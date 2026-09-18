#!/usr/bin/env node
// Prov for tools/discovery-identity.mjs. Kor: node tools/discovery-identity-fixtures.mjs
//   RP287-D01..D08 enligt Block 287 omgang 4, plus D09..D10 for familj/forekomst.
import { tilldelaAgare, agarGrund, familjeId, forekomstId } from './discovery-identity.mjs';

const BAS = { fil: 'Butlery Skarmar v12 prov.dc.html', art: 'prov', ordProd: 10, tagg: 'div', komponent: null, klass: null,
  rawRole: null, egenTextLangd: 0, text: '', ikoner: [], svgRoller: [], harFyllning: true, helRam: false, malar: true,
  display: 'block', piller: false, harKnopp: false, segmentgrupp: 0, barDeklareradeKontroller: 0, hitTarget: null,
  anker: 'ram', attrId: null, occ: null, attr: {}, w: 30, h: 30, x: 0, y: 0 };
const o = (x = {}) => ({ ...BAS, ...x });
const p = (objekt, klass = 'KNOWN_CONTROL') => ({ objekt, klass });
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag) });

{ const r = tilldelaAgare([p(o({ ordProd: 11 })), p(o({ ordProd: 12 }))]);
  prov('RP287-D01', 'tva identiska omarkta syskon blir inte samma agare', r.every(x => x.agarId === null && x.agarStatus === 'OWNER_IDENTITY_UNRESOLVED'), JSON.stringify(r.map(x => x.agarStatus))); }
{ const r = tilldelaAgare([p(o({ ordProd: 11, attr: { 'data-action': 'valj-rod' } })), p(o({ ordProd: 12, attr: { 'data-action': 'valj-bla' } }))]);
  prov('RP287-D02', 'olika binding skiljer visuellt identiska syskon', r[0].agarId && r[1].agarId && r[0].agarId !== r[1].agarId, r.map(x => x.agarId).join(' / ')); }
{ const a = tilldelaAgare([p(o({ ordProd: 11, occ: 'occ-aaa' })), p(o({ ordProd: 12, occ: 'occ-bbb' }))]);
  const b = tilldelaAgare([p(o({ ordProd: 40, occ: 'occ-bbb' })), p(o({ ordProd: 3, occ: 'occ-aaa' }))]);
  prov('RP287-D03', 'samma agare flyttad bland syskon behaller identiteten',
    a.find(x => x.objekt.occ === 'occ-aaa').agarId === b.find(x => x.objekt.occ === 'occ-aaa').agarId, a[0].agarId); }
{ const g1 = agarGrund(o({ attr: { 'data-bind': 'hushall.namn' }, egenTextLangd: 5, text: 'Anna' }), 'KNOWN_CONTROL');
  const g2 = agarGrund(o({ attr: { 'data-bind': 'hushall.namn' }, egenTextLangd: 6, text: 'Sigrid' }), 'KNOWN_CONTROL');
  prov('RP287-D04', 'synlig text andras men binding finns — identiteten bestar', g1.id === g2.id && g1.niva === 1, g1.id + ' / ' + g2.id); }
{ const g1 = agarGrund(o({ occ: 'occ-x', w: 30, h: 30, x: 5 }), 'KNOWN_CONTROL');
  const g2 = agarGrund(o({ occ: 'occ-x', w: 48, h: 48, x: 90, farg: '#000' }), 'KNOWN_CONTROL');
  prov('RP287-D05', 'geometri och farg andras — identiteten bestar', g1.id === g2.id, g1.id); }
{ const x = o({ occ: 'occ-y', text: 'Spara', egenTextLangd: 5 });
  const f1 = familjeId(x, ['PAINTED_TEXT_BODY']), f2 = familjeId(x, ['PAINTED_TEXT_BODY', 'CONTROL_SHELL']);
  const g = agarGrund(x, 'KNOWN_CONTROL');
  prov('RP287-D06', 'omgruppering av granskningsfamilj andrar inte agaren', f1 !== f2 && g.id === agarGrund(x, 'KNOWN_CONTROL').id, f1 + ' → ' + f2); }
{ const r = tilldelaAgare([p(o({ occ: 'occ-z', text: 'Spara', egenTextLangd: 5, attr: { 'data-action': 'spara' } }), 'UNKNOWN_SEMANTICS')]);
  prov('RP287-D07', 'UNKNOWN far aldrig ett agar-id, inte ens med starka ankare', r[0].agarId === null && r[0].agarStatus === 'UNKNOWN_NO_OWNER', r[0].agarStatus); }
{ const r = tilldelaAgare([p(o({ ordProd: 1, text: 'Spara', egenTextLangd: 5 })), p(o({ ordProd: 2, text: 'Spara', egenTextLangd: 5 }))]);
  prov('RP287-D08', 'kollision efter semantisk berikning faller stangt', r.every(x => x.agarId === null) && /kan inte sarskiljas/.test(r[0].skal), r[0].skal); }
{ const a = forekomstId(o({ ordProd: 11 })), b = forekomstId(o({ ordProd: 12 }));
  prov('RP287-D09', 'forekomst-id ar unikt per matobjekt men anvands aldrig som agare', a !== b && !/OWNER/.test(a), a); }
{ const g = agarGrund(o({ ordProd: 77, w: 1, h: 1 }), 'KNOWN_CONTROL');
  prov('RP287-D10', 'utan kallforfattat ankare ges ingen agare (inget index, ingen geometri)', g === null, String(g)); }

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
