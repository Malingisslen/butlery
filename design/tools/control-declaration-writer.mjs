// F2 · SKRIVER KONTROLLDEKLARATIONER I PRODUKTKALLAN.
//
// Skriver ENDAST de attribut som anges och en enda stilegenskap. Ingen farg,
// ingen token, ingen text, inget temastod, ingen ytmetadata, ingen layout
// utover den utpekade egenskapen.
//
// ANKARET ar elementets ordinal i artefaktens dokumentordning — samma ordning
// som querySelectorAll('*') ger i DOM och samma ordning som oppningstaggarna
// star i kallan. Saknas ankaret skrivs ingenting.
//
// FAIL CLOSED GENOMGAENDE
//   · attribut som redan finns med ANNAT varde  -> KONFLIKT, ingen skrivning
//   · attribut som redan finns med SAMMA varde  -> OFORANDRAD, ingen skrivning
//   · stilegenskap som redan finns med annat varde -> KONFLIKT
//   · forvantad starttagg som inte stammer      -> KONFLIKT
//
// Skrivningarna sker BAKIFRAN i filen sa att tidigare offsets haller.

import { readFileSync, writeFileSync } from 'node:fs';
import { artefaktBlock, elementIArtefakt } from './scope-migrator.mjs';

export const TILLATNA_ATTRIBUT = Object.freeze([
  'data-a11y-role', 'data-a11y-name', 'data-a11y-state', 'data-hit', 'data-hit-target']);
/* Stilegenskaper som far skrivas. Listan ar avsiktligt liten: varje post ar en
 * egenskap som ett godkant beslut har pekat ut. 'border', 'box-sizing' och
 * 'padding-left'/'padding-right' tillkom for den obligatoriska kontrollgransen
 * pa primarknappen. Kortformen 'padding' star INTE med — en kortform skulle
 * kunna radera sidor som beslutet inte namnt. */
export const TILLATNA_STILEGENSKAPER = Object.freeze([
  'min-height', 'border', 'box-sizing',
  'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
  /* 'border-color' tillkom for de 15 gransfynden. Den skrivs som en EGEN
   * deklaration efter den befintliga border-kortformen, sa att bredd och stil
   * aldrig ror sig: en senare deklaration i samma style-attribut vinner bara
   * over fargkomponenten. Kortformen 'border' star kvar i listan for de fall
   * dar ingen kant finns alls, men de tva far aldrig anvandas pa samma
   * element i samma jobb. */
  'border-color']);

const esc = s => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** Satt ETT attribut i en oppningstagg. */
export function skrivAttribut(taggtext, namn, varde) {
  if (!TILLATNA_ATTRIBUT.includes(namn))
    return { ok: false, skal: 'attributet ' + namn + ' ar inte tillatet' };
  if (typeof varde !== 'string' || varde.length === 0)
    return { ok: false, skal: 'tomt varde' };
  const v = esc(varde);
  const m = taggtext.match(new RegExp('\\s' + namn + '="([^"]*)"'));
  if (m) return m[1] === v
    ? { ok: true, ny: false, text: taggtext, skal: 'redan satt till samma varde' }
    : { ok: false, skal: namn + ' finns redan med vardet ' + JSON.stringify(m[1]) };
  const i = taggtext.length - (taggtext.trimEnd().endsWith('/>') ? 2 : 1);
  return { ok: true, ny: true,
    text: taggtext.slice(0, i).trimEnd() + ' ' + namn + '="' + v + '"' + taggtext.slice(i) };
}

/** Satt ETT stilvarde i style-attributet. Skapar style om det saknas. */
export function skrivStil(taggtext, egenskap, varde) {
  if (!TILLATNA_STILEGENSKAPER.includes(egenskap))
    return { ok: false, skal: 'stilegenskapen ' + egenskap + ' ar inte tillaten' };
  const m = taggtext.match(/\sstyle="([^"]*)"/);
  if (!m) { const i = taggtext.length - (taggtext.trimEnd().endsWith('/>') ? 2 : 1);
    return { ok: true, ny: true,
      text: taggtext.slice(0, i).trimEnd() + ' style="' + egenskap + ':' + varde + '"' +
        taggtext.slice(i) }; }
  const stil = m[1];
  const finns = stil.match(new RegExp('(^|;)\\s*' + egenskap + '\\s*:\\s*([^;]*)'));
  if (finns) { const nuvarande = finns[2].trim();
    return nuvarande === varde
      ? { ok: true, ny: false, text: taggtext, skal: egenskap + ' ar redan ' + varde }
      : { ok: false, skal: egenskap + ' finns redan med vardet ' + JSON.stringify(nuvarande) }; }
  const ny = stil.trimEnd().replace(/;$/, '') + ';' + egenskap + ':' + varde;
  return { ok: true, ny: true,
    text: taggtext.slice(0, m.index) + ' style="' + ny + '"' +
      taggtext.slice(m.index + m[0].length) };
}

/**
 * Ankarkontroll. Webblasarens outerHTML normaliserar style-attributet — hex
 * blir rgb(), mellanslag och avslutande semikolon laggs till — sa en
 * byte-jamforelse av hela starttaggen ar omojlig. Kontrollen jamfor darfor
 * TAGGNAMNET och samtliga ICKE-STYLE-attribut exakt. Style rors aldrig av
 * jamforelsen, bara av skrivStil.
 */
export function jamforAnkare(taggtext, forvantat, kallText) {
  if (!forvantat) return { ok: true, skal: 'inget ankare angivet' };
  const m = taggtext.match(/^<([a-zA-Z][a-zA-Z0-9-]*)/);
  const tagg = m ? m[1].toLowerCase() : null;
  if (forvantat.tagg && tagg !== forvantat.tagg)
    return { ok: false, skal: 'taggnamnet ar ' + tagg + ', vantade ' + forvantat.tagg };
  /* Kallans attribut maste vara en DELMANGD av DOM-ognonblickets. Sidan lagger
   * till attribut vid korning — de far finnas i DOM utan att finnas i kallan,
   * men aldrig tvartom, och aldrig med annat varde. */
  const attr = {};
  for (const a of taggtext.matchAll(/\s([a-zA-Z_:][-a-zA-Z0-9_:.]*)="([^"]*)"/g))
    if (a[1] !== 'style') attr[a[1]] = a[2];
  const v = forvantat.attribut || {};
  for (const [k, varde] of Object.entries(attr)) {
    if (!(k in v)) return { ok: false, skal: 'kallan bar attributet ' + k + ' som ankaret inte kanner' };
    if (v[k] !== varde) return { ok: false,
      skal: k + ' ar ' + JSON.stringify(varde) + ' i kallan, ankaret har ' + JSON.stringify(v[k]) }; }
  /* Egen omedelbar text, nar den ar angiven. Ett ankare utan text vilar bara
   * pa ordinal, taggnamn och attributdelmangd. */
  if (forvantat.text !== undefined && forvantat.text !== null) {
    const t = String(kallText || '').replace(/\s+/g, ' ').trim();
    const f = String(forvantat.text).replace(/\s+/g, ' ').trim();
    if (t !== f) return { ok: false,
      skal: 'texten ar ' + JSON.stringify(t.slice(0, 40)) + ', vantade ' +
        JSON.stringify(f.slice(0, 40)) }; }
  return { ok: true, skal: 'taggnamn, attributdelmangd' +
    (forvantat.text !== undefined && forvantat.text !== null ? ' och egen text' : '') + ' stammer' };
}

/**
 * Kor en hel fil.
 * mal = [{ art, ordinal, attribut: {namn: varde}, stil: {egenskap: varde},
 *          ankare?: { tagg, attribut }, etikett?: string }]
 */
export function migreraFil(fil, mal, { torr = false } = {}) {
  let src = readFileSync(fil, 'utf8');
  const logg = [], jobb = [];
  const perArt = new Map();
  for (const m of mal) { if (!perArt.has(m.art)) perArt.set(m.art, []); perArt.get(m.art).push(m); }
  for (const [art, mina] of perArt) {
    const blk = artefaktBlock(src, art);
    if (!blk) { for (const m of mina)
      logg.push({ ...m, utfall: 'HOPPAD', skal: 'artefakten finns inte i filen' }); continue; }
    const el = elementIArtefakt(src, blk);
    for (const m of mina) {
      const e = el[m.ordinal];
      if (!e) { logg.push({ ...m, utfall: 'HOPPAD',
        skal: 'elementordinal ' + m.ordinal + ' finns inte (' + el.length + ' element)' }); continue; }
      const nastaTagg = src.indexOf('<', e.slut);
      const kallText = src.slice(e.slut, nastaTagg < 0 ? e.slut : nastaTagg);
      const ank = jamforAnkare(e.text, m.ankare, kallText);
      if (!ank.ok) { logg.push({ ...m, utfall: 'KONFLIKT',
        skal: 'ankaret stammer inte: ' + ank.skal,
        kalla: e.text.slice(0, 140) }); continue; }
      let text = e.text; const gjorda = []; let fel = null;
      for (const [namn, varde] of Object.entries(m.attribut || {})) {
        const r = skrivAttribut(text, namn, varde);
        if (!r.ok) { fel = namn + ': ' + r.skal; break; }
        if (r.ny) gjorda.push(namn); text = r.text; }
      if (!fel) for (const [eg, varde] of Object.entries(m.stil || {})) {
        const r = skrivStil(text, eg, varde);
        if (!r.ok) { fel = eg + ': ' + r.skal; break; }
        if (r.ny) gjorda.push('style:' + eg); text = r.text; }
      if (fel) { logg.push({ ...m, utfall: 'KONFLIKT', skal: fel, kalla: e.text.slice(0, 120) }); continue; }
      if (!gjorda.length) { logg.push({ ...m, utfall: 'OFORANDRAD', skal: 'allt fanns redan' }); continue; }
      jobb.push({ start: e.start, slut: e.slut, text });
      logg.push({ ...m, utfall: 'SKRIVEN', skrivna: gjorda,
        fore: e.text.slice(0, 110), efter: text.slice(0, 170) });
    }
  }
  jobb.sort((a, b) => b.start - a.start);
  /* Overlappande jobb far aldrig forekomma — samma element tva ganger. */
  for (let i = 1; i < jobb.length; i++)
    if (jobb[i].slut > jobb[i - 1].start)
      return { logg, skrivningar: 0, fel: 'overlappande skrivjobb — inget skrevs' };
  for (const j of jobb) src = src.slice(0, j.start) + j.text + src.slice(j.slut);
  if (!torr && jobb.length) writeFileSync(fil, src);
  return { logg, skrivningar: jobb.length };
}
