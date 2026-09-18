// F2 · IDENTITET FOR UPPTACKTSPOPULATIONEN. Tre skilda identiteter, aldrig utbytbara.
//
//   DISCOVERY_OCCURRENCE_ID      ett uppmatt objekt i EN skord. Far vara positionellt
//                                (fil, ram, ordinal) — det ar en mathandtag, inte en agare,
//                                och ar bara giltigt tillsammans med skordens fingeravtryck.
//   DISCOVERY_REVIEW_FAMILY_ID   grupperar strukturellt lika objekt for granskning. Far
//                                andras nar familjeregeln forfinas; det paverkar aldrig agaren.
//   PERSISTENT_SEMANTIC_OWNER_ID skapas ENDAST nar agarsemantiken ar kand. Prioritet:
//                                  1 kallforfattad binding/action-id
//                                  2 explicit kontroll-/komponent-id
//                                  3 stabil funktionell semantik (kand klass + egen text)
//                                  4 stabil namngiven behallare + semantisk barnroll
//                                  5 annat kallforfattat stabilt ankare
//                                Aldrig DOM-index, syskonposition, radnummer, geometri,
//                                farg, aktuellt verdikt eller aktuellt felvarde.
//
// FAIL CLOSED: UNKNOWN far aldrig ett agar-id. Kan tva forekomster inte sarskiljas
// semantiskt far ingen av dem ett agar-id (OWNER_IDENTITY_UNRESOLVED); forekomsterna
// raknas explicit.
import { createHash } from 'node:crypto';

const fold = s => String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '');
export const slug = s => fold(s).toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 12);

export const KANDA_KLASSER = ['KNOWN_CONTROL', 'KNOWN_NON_CONTROL', 'KNOWN_COMPONENT', 'DECORATIVE_OR_STRUCTURAL',
  'OUT_OF_SCOPE', 'DUPLICATE_OF_CANONICAL_OWNER'];
export const BINDNINGSATTRIBUT = ['data-action', 'data-bind', 'data-binding', 'data-action-id'];

/** Mathandtag. Positionell med flit — anvands aldrig som agare. */
export const forekomstId = o => 'OCC::' + slug(o.fil) + '::' + o.art + '::' + o.ordProd;

/** Granskningsfamilj: ren struktur. Ingen ram, ingen text, ingen geometri, ingen farg. */
export function familjesignatur(o, mekanismer) {
  return {
    mekanismer: [...mekanismer].sort().join('+'), tagg: o.tagg, komponent: o.komponent || '-',
    klass: o.klass || '-', rawRole: o.rawRole || '-', egenText: o.egenTextLangd > 0,
    ikoner: [...new Set(o.ikoner || [])].sort().join('+') || '-',
    grafikroller: [...new Set(o.svgRoller || [])].sort().join('+') || '-',
    malar: o.harFyllning ? 'fyll' : o.helRam ? 'ram' : o.malar ? 'outline' : 'omalad',
    display: /flex/.test(o.display) ? 'flex' : o.display, pillerKnopp: !!(o.piller && o.harKnopp),
    segment: o.segmentgrupp >= 3, barKontroller: o.barDeklareradeKontroller > 0,
    hitTarget: !!o.hitTarget, ankare: String(o.anker || 'ram').split(':')[0] };
}
export const familjeId = (o, mek) => 'FAM::' + h(familjesignatur(o, mek));

/** Agarkandidat enligt prioritetsordningen. Returnerar null om ingen stabil grund finns. */
export function agarGrund(o, klass) {
  if (!KANDA_KLASSER.includes(klass)) return null;                                  // D07
  const bind = BINDNINGSATTRIBUT.map(a => o.attr && o.attr[a]).find(Boolean);
  if (bind) return { niva: 1, id: o.art + '::bind::' + slug(bind) };
  if (o.attrId) return { niva: 2, id: o.art + '::id::' + slug(o.attrId) };
  if (o.occ) return { niva: 2, id: o.art + '::occ::' + slug(o.occ) };
  if (o.hitTarget) return { niva: 2, id: o.art + '::hit-target::' + slug(o.hitTarget) };
  if (o.egenTextLangd > 0 && slug(o.text)) return { niva: 3, id: o.art + '::' + klass.toLowerCase() + '::' + slug(o.text) };
  if (o.anker && /^namn:/.test(o.anker) && o.komponent) return { niva: 4, id: o.art + '::' + slug(o.anker) + '::' + o.komponent };
  return null;
}

/**
 * Tilldelar agar-id till en population. Varje objekt maste bara klass.
 * Kollision (tva forekomster, samma agar-id) ger INGET id till nagon av dem.  D08
 */
export function tilldelaAgare(poster) {
  const grund = poster.map(p => ({ p, g: agarGrund(p.objekt, p.klass) }));
  const antal = new Map();
  for (const { g } of grund) if (g) antal.set(g.id, (antal.get(g.id) || 0) + 1);
  return grund.map(({ p, g }) => {
    if (!KANDA_KLASSER.includes(p.klass)) return { ...p, agarId: null, agarStatus: 'UNKNOWN_NO_OWNER' };
    if (!g) return { ...p, agarId: null, agarStatus: 'OWNER_IDENTITY_UNRESOLVED', skal: 'ingen stabil kallforfattad agargrund' };
    if (antal.get(g.id) > 1) return { ...p, agarId: null, agarStatus: 'OWNER_IDENTITY_UNRESOLVED',
      skal: antal.get(g.id) + ' forekomster delar agargrunden ' + g.id + ' — kan inte sarskiljas' };
    return { ...p, agarId: 'OWNER::' + g.id, agarStatus: 'RESOLVED', agarNiva: g.niva };
  });
}
