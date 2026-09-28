// Kor: node tools/bl01-skrivnyckel.mjs <elementindex.json> <utfil.json>
// O/P/Q · Stabil skrivagarnyckel. data-dc-tpl ar FORBJUDET som identitet och foljer bara med
// som DEBUG_LOCATOR. Nyckelordningen ar den starkaste tillgangliga kallgrunden:
//   0 grafikbarn i en deklarerad kontroll - kontrollen ar skrivagaren, inte barnet
//   1 kanoniskt data-occurrence pa elementet sjalvt
//   2 kallforfattat id / traffyta / bindning, eller deklarerad roll och namn i ramen
//   3 ankrat objekt + stabil lokal delnyckel (roll+namn, komponent eller glyf)
//   4 fail closed - kraver kallforfattat ankare
// Modulen ar ren: den laser inga filer vid import.
import { readFileSync, writeFileSync } from 'node:fs';

export const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
export const stabilNamn = s => slug(String(s == null ? '' : s).replace(/\d+(?:[.,:]\d+)*/g, ' '));
export const kortFil = f => String(f).replace(/^Butlery Skarmar v12 /, '').replace(/\.dc\.html$/, '');

/** Indexuppslag (ram#ordProd -> element) for forfaderkedjan. */
export const ramIndex = idx => new Map(idx.map(e => [e.art + '#' + e.ordProd, e]));

/** Narmaste kallforfattade ankare i forfaderkedjan, eller null. */
export function ankratObjekt(e, ram) {
  for (const o of e.anc || []) { const p = ram.get(e.art + '#' + o); if (p && p.occ) return p.occ; }
  return null;
}

/**
 * Starkaste stabila skrivagarnyckeln for ett element.
 * @param e   element ur tools/bl01-elementindex.mjs
 * @param ram Map fran ramIndex(idx)
 */
export function skrivnyckel(e, ram) {
  const fil = kortFil(e.fil);
  if (e.inDecl) return { NIVA: 0, WRITE_OWNER_ID: null, GRUND: 'grafikbarn i en deklarerad kontroll; skrivagaren ar kontrollen' };
  if (e.occ) return { NIVA: 1, WRITE_OWNER_ID: 'EL::' + fil + '::occ::' + e.occ, GRUND: 'kanoniskt data-occurrence pa elementet' };
  if (e.elId) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::id::' + slug(e.elId), GRUND: 'kallforfattat id' };
  if (e.hit && /^target:/.test(e.hit)) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::hit::' + slug(e.hit.slice(7)), GRUND: 'kallforfattad traffyta' };
  const ank = ram ? ankratObjekt(e, ram) : null;
  if (ank) {
    let del = null, grund = null;
    // Betygsvardet ar en tillaten slot inom en ankrad betygsgrupp (handoff H26, varde 1-5).
    const v = /^(\d)\s+av\s+5\b/.exec(String(e.name || ''));
    if (e.role && e.name) { del = slug(e.role) + '-' + stabilNamn(e.name) + (v ? '-varde-' + v[1] : ''); grund = 'deklarerad roll och namn' + (v ? ' plus betygsvardet (handoff H26, tillaten slot 1-5)' : ''); }
    else if (e.comp) { del = 'komponent-' + slug(e.comp); grund = 'komponenttoken'; }
    else if (e.icon) { del = 'glyf-' + slug(e.icon); grund = 'kallforfattad glyf'; }
    else if (stabilNamn(e.own)) { del = 'etikett-' + stabilNamn(e.own); grund = 'elementets egen stabila etikett'; }
    if (del) return { NIVA: 3, WRITE_OWNER_ID: 'EL::' + fil + '::objekt::' + ank + '::del::' + del, GRUND: 'ankrat objekt plus ' + grund };
  }
  if (e.role && e.name) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::' + e.art + '::roll::' + slug(e.role) + '::' + stabilNamn(e.name), GRUND: 'kallforfattad roll och namn i ramen' };
  return { NIVA: 4, WRITE_OWNER_ID: null, GRUND: 'ingen stabil kallgrund - kraver kallforfattat ankare' };
}

/** Hela korpusen: nycklar, nivaer och fail closed-kollisioner. */
export function nyckelrapport(idx) {
  const ram = ramIndex(idx);
  const rader = idx.map(e => Object.assign({ RAM: e.art, ordProd: e.ordProd, TAGG: e.tag, DEBUG_DC_TPL: e.tpl, TEXT: (e.own || e.text || '').slice(0, 40) }, skrivnyckel(e, ram)));
  const per = {}; for (const r of rader) per['NIVA_' + r.NIVA] = (per['NIVA_' + r.NIVA] || 0) + 1;
  const antal = {}; for (const r of rader) if (r.WRITE_OWNER_ID) antal[r.WRITE_OWNER_ID] = (antal[r.WRITE_OWNER_ID] || 0) + 1;
  const kollisioner = Object.entries(antal).filter(p => p[1] > 1).map(p => ({ WRITE_OWNER_ID: p[0], ANTAL: p[1] }));
  const ids = rader.filter(r => r.WRITE_OWNER_ID).map(r => r.WRITE_OWNER_ID);
  return { NIVAER: per, ELEMENT: rader.length, NYCKLAR: ids.length, UNIKA: new Set(ids).size,
    WRITE_KEY_COLLISIONS: kollisioner.length, POSITIONAL_WRITE_OWNER_IDS: ids.filter(i => /#tpl|::ord::|::index::/.test(i)).length,
    kollisioner, rader };
}

if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('bl01-skrivnyckel.mjs')) {
  const idx = JSON.parse(readFileSync(process.argv[2], 'utf8'));
  const r = nyckelrapport(idx);
  const { rader, ...kort } = r;
  console.log(JSON.stringify(kort, null, 1));
  if (process.argv[3]) writeFileSync(process.argv[3], JSON.stringify(r, null, 1) + '\n');
}
