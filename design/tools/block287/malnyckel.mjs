// TARGET_KEY_CONTRACT_VERSION = 1
// D/E/F · Fysisk maltidentitet, skild fran semantisk agaridentitet.
//
//   WRITE_OWNER_ID     vem ager kravet (stabil semantisk agare)
//   TARGET_SOURCE_KEY  var deklarationen star (agare + stabil lokal delnyckel)
//
// Delnyckeln beskriver delens STRUKTURELLA ROLL i agaren. Den far aldrig vara
// synlig text, tillgangligt namn, fargvarde, geometrivarde, DOM-index,
// dokumentordning, radnummer, tillstand eller dagens verdikt.
// Tva delar i samma agare med samma starkaste delnyckel faller stangt.
import { skrivnyckel, ramIndex, slug, stabilNamn, kortFil } from '../bl01-skrivnyckel.mjs';

export const TARGET_KEY_CONTRACT_VERSION = 1;

/** Narmaste forfader som ar en semantisk agare (deklarerad kontroll eller ankrat objekt). */
export function agandeElement(e, ram) {
  if (e.role || e.occ) return e;
  for (const o of e.anc || []) { const p = ram.get(e.art + '#' + o); if (p && (p.role || p.occ)) return p; }
  return null;
}

const malad = e => { const b = /rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?/.exec(e.bgC || ''); return !!(b && (b[4] === undefined || Number(b[4]) > 0)); };
const kant = e => ['bT', 'bR', 'bB', 'bL'].map(k => parseFloat(e[k]) || 0);
const arAvatar = e => { const st = String(e.style || ''); return /border-radius:\s*(999px|50%)/.test(st) && malad(e) && /font-size/.test(st); };

/** Stabil strukturell delnyckel, eller null nar ingen kan harledas. */
export function delnyckel(e, agare, ram, syskonGlyfar) {
  if (e.partOcc) return { del: slug(e.partOcc), grund: 'kallforfattad data-part-occurrence' };
  if (agare && e.ordProd === agare.ordProd && e.art === agare.art) return { del: 'self', grund: 'elementet ar agaren' };
  if (e.comp) return { del: 'komponent-' + slug(e.comp), grund: 'komponenttoken' };
  if (e.icon && syskonGlyfar && syskonGlyfar.filter(g => g === e.icon).length === 1)
    return { del: 'ikon-' + slug(e.icon), grund: 'kallforfattad glyf, unik i agaren' };
  if (agare && agare.name && stabilNamn(e.own) && stabilNamn(e.own) === stabilNamn(agare.name))
    return { del: 'etikett', grund: 'delen bar agarens etikett' };
  if (arAvatar(e)) return { del: 'avatar', grund: 'rund malad yta med initial' };
  const [t, r, b, l] = kant(e);
  const nagon = t + r + b + l > 0;
  if (nagon && !malad(e) && !stabilNamn(e.own)) {
    if (t > 0 && r === 0 && b === 0 && l === 0) return { del: 'kant-topp', grund: 'enbart overkant malad' };
    if (b > 0 && t === 0 && r === 0 && l === 0) return { del: 'kant-botten', grund: 'enbart underkant malad' };
    if (l > 0 && t === 0 && r === 0 && b === 0) return { del: 'kant-vanster', grund: 'enbart vansterkant malad' };
    if (r > 0 && t === 0 && b === 0 && l === 0) return { del: 'kant-hoger', grund: 'enbart hogerkant malad' };
    if (t > 0 && r > 0 && b > 0 && l > 0) return { del: 'kant-runtom', grund: 'hel ram malad' };
  }
  if (stabilNamn(e.own)) return { del: 'text', grund: 'delens egen textnod' };
  if (malad(e) || nagon) return { del: 'yta', grund: 'malad yta utan egen text' };
  return null;
}

/**
 * Fullstandig maltidentitet for ett element.
 * @returns { WRITE_OWNER_ID, TARGET_SOURCE_KEY, DEL, GRUND, AGARE } eller { PART_METADATA_REQUIRED }
 */
export function malnyckel(e, ram) {
  const agare = agandeElement(e, ram);
  if (!agare) {
    // Dekorativ del utan semantisk agare: ramen ar strukturell agare (kallforfattat id).
    // Delnyckeln MASTE da vara kallforfattad - vi gissar aldrig en del i en hel ram.
    if (!e.partOcc) return { PART_METADATA_REQUIRED: true, SKAL: 'ingen semantisk agare i forfaderkedjan och ingen kallforfattad delnyckel' };
    const ramNyckel = 'EL::' + kortFil(e.fil) + '::ram::' + e.art;
    const syskon = ramIterera(ram, e.art).filter(x => x.partOcc === e.partOcc && !agandeElement(x, ram));
    if (syskon.length > 1) return { PART_METADATA_REQUIRED: true, WRITE_OWNER_ID: ramNyckel,
      SKAL: syskon.length + ' delar i ramen delar delnyckeln "' + e.partOcc + '" - faller stangt' };
    return { WRITE_OWNER_ID: ramNyckel, TARGET_SOURCE_KEY: ramNyckel + '::del::' + slug(e.partOcc),
      DEL: slug(e.partOcc), GRUND: 'ramen som strukturell agare plus kallforfattad data-part-occurrence', AGARE: null };
  }
  const ok = skrivnyckel(agare, ram);
  if (!ok.WRITE_OWNER_ID) return { PART_METADATA_REQUIRED: true, SKAL: 'agaren saknar stabil nyckel: ' + ok.GRUND };
  // syskondelar under samma agare, for unikhetsprovet
  const delar = [];
  for (const x of ramIterera(ram, e.art)) { const a = agandeElement(x, ram); if (a && a.art === agare.art && a.ordProd === agare.ordProd) delar.push(x); }
  const glyfar = delar.map(x => x.icon).filter(Boolean);
  const d = delnyckel(e, agare, ram, glyfar);
  if (!d) return { PART_METADATA_REQUIRED: true, SKAL: 'ingen strukturell delnyckel kan harledas', WRITE_OWNER_ID: ok.WRITE_OWNER_ID };
  const konkurrenter = delar.filter(x => { const y = delnyckel(x, agare, ram, glyfar); return y && y.del === d.del; });
  if (konkurrenter.length > 1) return { PART_METADATA_REQUIRED: true, WRITE_OWNER_ID: ok.WRITE_OWNER_ID,
    SKAL: konkurrenter.length + ' delar i agaren delar delnyckeln "' + d.del + '" - faller stangt, ingen ordinal reserv' };
  return { WRITE_OWNER_ID: ok.WRITE_OWNER_ID, TARGET_SOURCE_KEY: ok.WRITE_OWNER_ID + '::del::' + d.del,
    DEL: d.del, GRUND: d.grund, AGARE: agare };
}

const perRam = new Map();
function ramIterera(ram, art) {
  if (!perRam.has(art)) perRam.set(art, [...ram.values()].filter(x => x.art === art));
  return perRam.get(art);
}
export function nollstall() { perRam.clear(); }
