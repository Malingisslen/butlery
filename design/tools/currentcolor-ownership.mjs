// F2-R04 · AGARSKAP FOR currentColor-MALNING.
//
// KONTRAKTET
// En malad SVG-del som anvander currentColor ar en PAINT_CARRIER men aldrig
// automatiskt en COLOR_DECISION_OWNER. Dess fargbeslut tillhor den upplosta
// agande fargkallan — det narmaste forfaderelement som faktiskt deklarerar
// color.
//
// Darfor:
//   · ingen extra beslutsenhet enbart for att ett barn malar
//   · ingen extra skrivbar kallpost
//   · ingen duplicerad fargmappning
//
// MEN: barnets semantiska bivillkor MASTE propagera till agarens beslut.
// Ett informationsbarande barn skapar inget nytt beslut, men det kan
// ogiltigforklara en kandidat for agarens beslut.
//
// Fail closed: gar agaren inte att losa far ingen kandidat godkannas.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const BARARKLASS = Object.freeze({
  INFORMATION_BEARING_GRAPHIC: 'INFORMATION_BEARING_GRAPHIC',
  REDUNDANT_GRAPHIC: 'REDUNDANT_GRAPHIC',
  DECORATIVE_GRAPHIC: 'DECORATIVE_GRAPHIC',
  GRAPHIC_ROLE_UNKNOWN: 'GRAPHIC_ROLE_UNKNOWN' });

/** Bara informationsbarande barn lagger ett icke-textkrav pa sin agare. */
export const laggerIckeTextkrav = klass => klass === BARARKLASS.INFORMATION_BEARING_GRAPHIC;

/**
 * Hittar den agande fargkallan for varje currentColor-malning.
 * Agaren ar narmaste forfader som SJALV deklarerar color.
 */
export const AGARSOND = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const prod = [...it.querySelectorAll('*')].filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product');
    const ord = new Map(prod.map((e, i) => [e, i]));
    for (const el of prod) {
      const tag = el.tagName.toLowerCase();
      if (tag === 'svg') continue;
      const rot = el.closest('svg'); if (!rot) continue;
      for (const egenskap of ['fill', 'stroke']) {
        const attr = el.getAttribute(egenskap);
        const inline = el.style.getPropertyValue(egenskap);
        const dekl = inline || attr;
        if (String(dekl || '').trim().toLowerCase() !== 'currentcolor') continue;
        // Agaren: narmaste forfader vars color skiljer sig fran SIN forfaders,
        // eller som deklarerar color explicit.
        let n = el, agare = null, steg = 0;
        while (n && n !== document.documentElement && steg++ < 60) {
          const egen = n.style && n.style.getPropertyValue('color');
          const f = n.parentElement;
          const minColor = getComputedStyle(n).color;
          const farColor = f ? getComputedStyle(f).color : null;
          if (egen || (farColor !== null && minColor !== farColor)) { agare = n; break; }
          n = f; }
        ut.push({ art: it.id, ordinal: ord.get(el), tagg: tag, egenskap,
          malatVarde: getComputedStyle(el).getPropertyValue(egenskap),
          color: getComputedStyle(el).color,
          agareOrdinal: agare ? (ord.has(agare) ? ord.get(agare) : -1) : null,
          agareUtanforProduktbasen: !!(agare && !ord.has(agare)),
          agareTagg: agare ? agare.tagName.toLowerCase() : null,
          agareKlass: agare ? (agare.getAttribute('class') || null) : null,
          agareColor: agare ? getComputedStyle(agare).color : null,
          rotOrdinal: ord.has(rot) ? ord.get(rot) : null,
          grafikroll: rot.getAttribute('data-graphic-role'),
          ikon: rot.getAttribute('data-icon') }); } } }
  return JSON.stringify(ut); })()`;

/**
 * Loser agarskap till en stabil identitet. Fail closed nar agaren inte
 * ligger i produktordinalbasen — da finns ingen skrivbar kalla att binda till.
 */
export function losAgare(post) {
  if (post.agareOrdinal === null || post.agareOrdinal === undefined)
    return { ok: false, agare: null, skal: 'ingen forfader deklarerar color' };
  if (post.agareOrdinal === -1 || post.agareUtanforProduktbasen)
    return { ok: false, agare: null, skal: 'agaren ligger utanfor produktordinalbasen' };
  return { ok: true, agare: post.art + '|' + post.agareOrdinal + '|color', skal: null };
}

/**
 * Bygger agarnas bivillkorstabell. Ett barn skapar ALDRIG en egen enhet.
 * Ett informationsbarande barn lagger ett icke-textkrav pa agaren.
 */
export function agarbivillkor(poster, klassAv, bakgrundAv) {
  const per = new Map(), olosta = [];
  for (const p of poster) {
    const a = losAgare(p);
    if (!a.ok) { olosta.push({ post: p.art + '|' + p.ordinal + '|' + p.egenskap, skal: a.skal }); continue; }
    if (!per.has(a.agare)) per.set(a.agare, { agare: a.agare, barn: [], krav: [] });
    const e = per.get(a.agare);
    const klass = klassAv(p);
    e.barn.push({ id: p.art + '|' + p.ordinal + '|' + p.egenskap, tagg: p.tagg, klass,
      ikon: p.ikon, bakgrund: bakgrundAv ? bakgrundAv(p) : null });
    if (laggerIckeTextkrav(klass)) e.krav.push({ fran: p.art + '|' + p.ordinal + '|' + p.egenskap,
      typ: 'ICKE_TEXT', troskel: 3, bakgrund: bakgrundAv ? bakgrundAv(p) : null,
      skal: 'ikonen ar ensam barare av sin kontrolls innebord' }); }
  return { agare: [...per.values()], olosta,
    nyaBeslutsenheter: 0, nyaSkrivbaraKallor: 0,
    $regel: 'Ett currentColor-barn ger aldrig en egen beslutsenhet eller kallpost. Det lagger bivillkor pa agaren.' };
}

/** En agarkandidat maste klara SAMTLIGA beroende barns relationer. */
export function provaAgarkandidat(kandidat, krav, kvotFn) {
  if (!krav.length) return { kandidat, ok: true, prov: [], skal: 'inga informationsbarande barn' };
  const prov = krav.map(k => { const kv = kvotFn(kandidat, k.bakgrund);
    return { fran: k.fran, bakgrund: k.bakgrund, kvot: kv, troskel: k.troskel,
      ok: kv !== null && kv >= k.troskel }; });
  const fel = prov.filter(p => !p.ok);
  return { kandidat, ok: fel.length === 0, prov,
    skal: fel.length ? fel.length + ' av ' + prov.length + ' beroende barn faller' : null };
}
