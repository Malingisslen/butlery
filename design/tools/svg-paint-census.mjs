// F2-R04 · MALNINGSCENSUS FOR SVG-BARN.
//
// FELKLASSEN MODULEN FINNS FOR
// semantic-units registrerar fill och stroke bara nar elementet SJALVT ar
// <svg>. En illustration som malar per <path> var darfor osynlig for hela
// matningen. I scenen start gomde det atta malade varden; i korpusen 2383.
//
// TVA BEGREPP SOM ALDRIG FAR BLANDAS IHOP
//
//   PAINT_CARRIER      ett element som faktiskt malar nagot pa skarmen.
//                      Alla 2383 ar paint carriers.
//   SOURCE_DECLARATION ett stalle i kallan dar vardet faktiskt bestams.
//                      Ett arvt barn har INGEN egen source declaration.
//
// Ett arvt barn far darfor aldrig bli en egen skrivbar post eller en egen
// beslutsenhet. Det foljer med sin rot. Bara sjalvstandigt satta varden ar
// nya kallor — och kan da, om semantiken kraver det, ge nya beslutsenheter.
//
// KALLKLASSER
//   ATTRIBUT      presentationsattribut pa elementet sjalvt
//   INLINE        inline style pa elementet sjalvt
//   CSS_REGEL     ingen egen deklaration, men berknat varde skiljer sig fran
//                 forfaderns — det maste komma ur en regel
//   ARVD          ingen egen deklaration och samma berknade varde som forfadern
//   OKAND         gar inte att avgora. Fail closed.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const MALADE_SVG_TAGGAR = Object.freeze(['path', 'rect', 'circle', 'ellipse',
  'line', 'polyline', 'polygon', 'text', 'tspan', 'use', 'g', 'polygon', 'image']);

export const KALLKLASS = Object.freeze({
  ATTRIBUT: 'ATTRIBUT', INLINE: 'INLINE', CSS_REGEL: 'CSS_REGEL',
  ARVD: 'ARVD', OKAND: 'OKAND' });

/** Ett arvt varde har ingen egen kalla och far aldrig skrivas separat. */
export const arEgenKalla = k => k === KALLKLASS.ATTRIBUT || k === KALLKLASS.INLINE ||
  k === KALLKLASS.CSS_REGEL;

/**
 * Census over malade SVG-barn. Kors i sidan.
 * Ordinalbasen ar produktelementen — samma som semantic-units och fargsonden.
 */
export const SVG_CENSUS = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  const tolka = v => { const m = String(v).match(/rgba?\\(\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*(?:,\\s*([\\d.]+)\\s*)?\\)/);
    return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; };
  const TAGGAR = ${JSON.stringify(MALADE_SVG_TAGGAR)};
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const alla = [...it.querySelectorAll('*')];
    const prod = alla.filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product');
    const ord = new Map(prod.map((e, i) => [e, i]));
    for (const el of prod) {
      const tag = el.tagName.toLowerCase();
      if (tag === 'svg') continue;                       // roten mats redan av semantic-units
      const rot = el.closest('svg'); if (!rot) continue;  // bara element inuti en svg
      if (!TAGGAR.includes(tag)) continue;
      const cs = getComputedStyle(el);
      for (const egenskap of ['fill', 'stroke']) {
        const varde = cs.getPropertyValue(egenskap);
        if (!varde || varde === 'none') continue;
        const c = tolka(varde); if (!c || c[3] === 0) continue;

        // Egen deklaration?
        const attr = el.getAttribute(egenskap);
        const inline = el.style.getPropertyValue(egenskap);
        const forfader = el.parentElement;
        const forfaderVarde = forfader ? getComputedStyle(forfader).getPropertyValue(egenskap) : null;
        const rotVarde = getComputedStyle(rot).getPropertyValue(egenskap);
        let kalla, kalltext = null;
        if (inline) { kalla = 'INLINE'; kalltext = inline; }
        else if (attr !== null && attr !== '') { kalla = 'ATTRIBUT'; kalltext = attr; }
        else if (forfaderVarde !== null && varde === forfaderVarde) kalla = 'ARVD';
        else if (forfaderVarde !== null) kalla = 'CSS_REGEL';
        else kalla = 'OKAND';

        // currentColor loses mot elementets egen color.
        const viaCurrentColor = String(kalltext || '').trim().toLowerCase() === 'currentcolor';

        ut.push({ art: it.id, ordinal: ord.get(el), tagg: tag, egenskap, varde,
          kalla, kalltext, viaCurrentColor,
          color: viaCurrentColor ? cs.color : null,
          rotOrdinal: ord.has(rot) ? ord.get(rot) : null,
          rotVarde, forfaderVarde,
          arvtFranRot: varde === rotVarde,
          grafikroll: rot.getAttribute('data-graphic-role'),
          ikon: rot.getAttribute('data-icon') }); } } }
  return JSON.stringify(ut); })()`;

/**
 * Avstamning. Varje malad post ar ANTINGEN en egen kalla ELLER arvd.
 * Summan maste ga ihop och ingen post far vara oforklarad.
 */
export function avstamning(rader) {
  const egen = rader.filter(r => arEgenKalla(r.kalla));
  const arvd = rader.filter(r => r.kalla === KALLKLASS.ARVD);
  const okand = rader.filter(r => r.kalla === KALLKLASS.OKAND);
  return { totalt: rader.length, egenKalla: egen.length, arvd: arvd.length, okand: okand.length,
    summerar: egen.length + arvd.length + okand.length === rader.length,
    godkand: okand.length === 0,
    perKalla: rader.reduce((m, r) => { m[r.kalla] = (m[r.kalla] || 0) + 1; return m; }, {}),
    artefakterMedEgenKalla: [...new Set(egen.map(r => r.art))],
    $regel: 'Arvda poster ar paint carriers utan egen source declaration. De far aldrig bli egna skrivbara poster eller egna beslutsenheter.' };
}

/** Nya beslutskandidater: bara sjalvstandigt satta varden. */
export function nyaKandidater(rader) {
  const egna = rader.filter(r => arEgenKalla(r.kalla));
  const per = new Map();
  for (const r of egna) {
    const k = r.egenskap + '|' + r.varde + '|' + (r.grafikroll || 'utan-grafikroll');
    if (!per.has(k)) per.set(k, { egenskap: r.egenskap, varde: r.varde,
      grafikroll: r.grafikroll, forekomster: 0, artefakter: new Set(), taggar: new Set() });
    const e = per.get(k); e.forekomster++; e.artefakter.add(r.art); e.taggar.add(r.tagg); }
  return [...per.values()].map(e => ({ ...e, artefakter: [...e.artefakter],
    taggar: [...e.taggar] })).sort((a, b) => b.forekomster - a.forekomster);
}
