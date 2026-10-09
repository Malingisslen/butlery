// F2-R04 · METADATAMIGRATOR FOR data-conformance-scope.
//
// Skriver ETT attribut och ingenting annat. Ingen stil, ingen farg, ingen
// token, ingen layout, ingen text, inget temastod, ingen ytmetadata.
//
// Ankaret ar elementets ordinal i artefaktens dokumentordning — samma ordning
// som querySelectorAll('*') ger i DOM, och samma ordning som oppningstaggarna
// star i kallan. Saknas ankaret skrivs ingenting. Fail closed genomgaende.

import { readFileSync, writeFileSync } from 'node:fs';

export const ATTRIBUT = 'data-conformance-scope';
export const GILTIGA = ['product', 'annotation', 'harness'];

/** Kommentarernas intervall i kallan. En tagg inuti en kommentar finns inte. */
export function kommentarer(src) {
  const ut = []; let i = 0;
  for (;;) { const a = src.indexOf('<!--', i); if (a < 0) break;
    const b = src.indexOf('-->', a); if (b < 0) { ut.push([a, src.length]); break; }
    ut.push([a, b + 3]); i = b + 3; }
  return ut;
}

/** Artefaktblocket for ett sc-item-id, inklusive dess egen oppningstagg. */
export function artefaktBlock(src, id) {
  const m = src.match(new RegExp('<div[^>]*class="sc-item"[^>]*id="' + id + '"[^>]*>|<div[^>]*id="' + id + '"[^>]*class="sc-item"[^>]*>'));
  if (!m) return null;
  const start = m.index;
  const komm = kommentarer(src);
  const iKomm = p => komm.some(([a, b]) => p >= a && p < b);
  const VOID = new Set(['br', 'img', 'input', 'hr', 'meta', 'link', 'source']);
  const re = /<\/?([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>/g;
  re.lastIndex = start;
  let djup = 0, slut = -1, x;
  while ((x = re.exec(src))) {
    if (iKomm(x.index)) continue;
    const namn = x[1].toLowerCase(), stangande = x[0][1] === '/';
    const sjalv = x[2].trimEnd().endsWith('/') || VOID.has(namn);
    if (stangande) { djup--; if (djup <= 0) { slut = re.lastIndex; break; } }
    else if (!sjalv) djup++;
  }
  if (slut < 0) return null;
  return { start, slut, egenTagg: { start, slut: start + m[0].length, text: m[0] } };
}

/**
 * Artefaktens DESCENDANTER i dokumentordning — exakt det querySelectorAll('*')
 * raknar. Artefaktens egen tagg ar INTE med; ordinal 0 ar forsta barnet.
 */
export function elementIArtefakt(src, blk) {
  const komm = kommentarer(src);
  const iKomm = p => komm.some(([a, b]) => p >= a && p < b);
  const ut = [];
  const re = /<([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>/g;
  re.lastIndex = blk.egenTagg.slut;
  let x;
  while ((x = re.exec(src)) && x.index < blk.slut) {
    if (iKomm(x.index)) continue;
    ut.push({ ordinal: ut.length, start: x.index, slut: re.lastIndex,
      tagg: x[1].toLowerCase(), text: x[0] });
  }
  return ut;
}

/**
 * Satt attributet i en oppningstagg.
 *   ok:true  ny:true   attributet skrevs
 *   ok:true  ny:false  identiskt varde fanns redan — idempotent, ingen skrivning
 *   ok:false           annat varde fanns, eller vardet ar ogiltigt. Fail closed.
 */
export function skrivScopeITagg(taggtext, varde) {
  if (!GILTIGA.includes(varde))
    return { ok: false, skal: 'ogiltigt scopevarde ' + JSON.stringify(varde) };
  const m = taggtext.match(new RegExp(ATTRIBUT + '="([^"]*)"'));
  if (m) return m[1] === varde
    ? { ok: true, ny: false, text: taggtext, skal: 'redan satt till ' + varde }
    : { ok: false, skal: ATTRIBUT + ' finns redan med vardet ' + JSON.stringify(m[1]) };
  const i = taggtext.length - (taggtext.trimEnd().endsWith('/>') ? 2 : 1);
  return { ok: true, ny: true,
    text: taggtext.slice(0, i).trimEnd() + ' ' + ATTRIBUT + '="' + varde + '"' + taggtext.slice(i) };
}

/**
 * Kor en hel fil. mal = [{ art, ordinal, varde, grupp }].
 * Skrivningar sker BAKIFRAN sa att tidigare offsets haller.
 */
export function migreraFil(fil, mal, { torr = false } = {}) {
  let src = readFileSync(fil, 'utf8');
  const logg = [], perArt = new Map();
  for (const m of mal) { if (!perArt.has(m.art)) perArt.set(m.art, []); perArt.get(m.art).push(m); }
  const jobb = [];
  for (const [art, mina] of perArt) {
    const blk = artefaktBlock(src, art);
    if (!blk) { for (const m of mina) logg.push({ ...m, utfall: 'HOPPAD', skal: 'artefakten finns inte i filen' }); continue; }
    const el = elementIArtefakt(src, blk);
    for (const m of mina) {
      const e = el[m.ordinal];
      if (!e) { logg.push({ ...m, utfall: 'HOPPAD', skal: 'elementordinal ' + m.ordinal + ' finns inte i kallan (' + el.length + ' element)' }); continue; }
      const r = skrivScopeITagg(e.text, m.varde);
      if (!r.ok) { logg.push({ ...m, utfall: 'KONFLIKT', skal: r.skal, tagg: e.text.slice(0, 90) }); continue; }
      if (!r.ny) { logg.push({ ...m, utfall: 'OFORANDRAD', skal: r.skal }); continue; }
      jobb.push({ start: e.start, slut: e.slut, text: r.text });
      logg.push({ ...m, utfall: 'SKRIVEN', tagg: e.tagg, fore: e.text.slice(0, 70), efter: r.text.slice(0, 90) });
    }
  }
  jobb.sort((a, b) => b.start - a.start);
  for (const j of jobb) src = src.slice(0, j.start) + j.text + src.slice(j.slut);
  if (!torr && jobb.length) writeFileSync(fil, src);
  return { logg, skrivningar: jobb.length };
}
