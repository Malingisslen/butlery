// F2-R04 · MIGRATOR SOM KONSUMERAR ROLLKARTAN.
//
// Migratorn har INGEN egen rollklassificerare. Rollkartan ar enda sanning:
//   rollkarta -> lost roll -> lost deklaration -> kallankare -> token -> write
//
// Ankaret ar elementets ordinal i produktytans dokumentordning, vilket ar
// samma ordning som oppningstaggarna i kallan. Saknas ankare skrivs
// ingenting — fail closed.

import { readFileSync, writeFileSync } from 'node:fs';

// Produktytans elementlista i kallan, i dokumentordning.
export function produktElementIKallan(blk) {
  const y = blk.indexOf('class="sc-phone"') >= 0
    ? blk.lastIndexOf('<', blk.indexOf('class="sc-phone"'))
    : blk.indexOf('class="sc-card"') >= 0
      ? blk.lastIndexOf('<', blk.indexOf('class="sc-card"'))
      : -1;
  if (y < 0) return null;
  // ENDAST akta void-element. svg-barn som path, circle och rect skrivs med
  // explicit sluttagg i den har sviten. Att behandla dem som void raknade ner
  // djupet utan att ha raknat upp det, och vandringen avslutades for tidigt.
  // Sjalvstangande form fangas anda av endsWith('/').
  const VOID = new Set(['br', 'img', 'input', 'hr', 'meta', 'link', 'source']);
  // Ytans egen subtrad, avgransad genom taggdjup.
  const re = /<\/?([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>/g;
  re.lastIndex = y;
  let djup = 0, slut = blk.length, m;
  while ((m = re.exec(blk))) {
    const namn = m[1].toLowerCase(), stangande = m[0][1] === '/';
    const sjalv = m[2].trimEnd().endsWith('/') || VOID.has(namn);
    if (stangande) { djup--; if (djup <= 0) { slut = re.lastIndex; break; } }
    else if (!sjalv) djup++;
  }
  // Ytans BARN i samma ordning som querySelectorAll('*') ger dem. VARJE
  // oppningstagg raknas, aven path, circle och rect — DOM raknar dem ocksa.
  // VOID anvands bara for djupberakningen ovan, aldrig for uppraknignen.
  const element = [];
  const re2 = /<([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>/g;
  re2.lastIndex = y;
  // Ytan SJALV ar med. Rollkartans iProdukt slapper igenom ytan (y === el),
  // sa listorna maste borja pa samma element.
  while ((m = re2.exec(blk)) && m.index < slut) {
    element.push({ start: m.index, slut: re2.lastIndex, tagg: m[1].toLowerCase(), text: m[0] });
  }
  return element;
}

// Skriv en enskild deklaration i en tagg.
export function skrivITagg(taggtext, post, token) {
  if (post.ankare.form === 'SVG_ATTRIBUTE') {
    const attr = post.egenskap;   // fill eller stroke
    const re = new RegExp(attr + '="(#[0-9a-fA-F]{6}|rgba?\\([^)]*\\))"');
    const m = taggtext.match(re);
    if (!m) return { ok: false, skal: 'svg-attributet ' + attr + ' finns inte i taggen' };
    return { ok: true, text: taggtext.replace(m[0], attr + '="var(' + token + ')"') };
  }
  const st = taggtext.match(/style="([^"]*)"/);
  if (!st) return { ok: false, skal: 'inget stilattribut i taggen' };
  // Egenskapen kan sta som langform eller inga i en kortform.
  const KORT = { 'background-color': ['background-color', 'background'],
    'border-top-color': ['border-top-color', 'border-top', 'border'],
    'border-right-color': ['border-right-color', 'border-right', 'border'],
    'border-bottom-color': ['border-bottom-color', 'border-bottom', 'border'],
    'border-left-color': ['border-left-color', 'border-left', 'border'],
    'color': ['color'] };
  const namn = KORT[post.egenskap] || [post.egenskap];
  const delar = st[1].split(';');
  for (let i = 0; i < delar.length; i++) {
    const kv = delar[i].trim().match(/^([a-z-]+)\s*:\s*(.+)$/);
    if (!kv || !namn.includes(kv[1])) continue;
    const farg = kv[2].match(/#[0-9a-fA-F]{6}|rgba?\([^)]*\)/);
    if (!farg) continue;
    delar[i] = delar[i].replace(farg[0], 'var(' + token + ')');
    return { ok: true, text: taggtext.replace(/style="[^"]*"/, 'style="' + delar.join(';') + '"') };
  }
  return { ok: false, skal: 'ingen deklaration for ' + post.egenskap + ' med fargvarde i taggen' };
}

// Full migration av en artefakts kallblock utifran rollkartans poster.
export function migreraBlock(blk, poster, tokenAv) {
  const element = produktElementIKallan(blk);
  if (!element) return { blk, skrivna: 0, hoppade: poster.map(p => ({ ...p, skal: 'ingen produktyta i kallan' })) };
  const skrivna = [], hoppade = [], tackta = [];
  // ETT element i taget. Flera egenskaper pa samma tagg maste skrivas mot
  // SAMMA arbetskopia — annars laser den andra skrivningen en foraldrad
  // taggtext och hittar varken stilattribut eller fargvarde.
  const perElement = new Map();
  for (const p of poster) { const o = p.ankare.elementOrdinal;
    if (!perElement.has(o)) perElement.set(o, []); perElement.get(o).push(p); }
  let ut = blk;
  // Bakifran sa att index halIer for lagre ordinaler.
  for (const o of [...perElement.keys()].sort((a, b) => b - a)) {
    const e = element[o], mina = perElement.get(o);
    if (!e) { for (const p of mina) hoppade.push({ ...p, skal: 'elementordinal ' + o + ' finns inte i kallan' }); continue; }
    if (e.tagg !== mina[0].ankare.tagg) {
      for (const p of mina) hoppade.push({ ...p, skal: 'taggen skiljer: kartan sager ' + p.ankare.tagg + ', kallan ' + e.tagg }); continue; }
    let taggtext = ut.slice(e.start, e.slut);
    for (const p of mina) {
      const token = tokenAv(p);
      if (!token) { hoppade.push({ ...p, skal: 'ingen token for rollen ' + p.roll + ' med vardet ' + p.beraknat }); continue; }
      const r = skrivITagg(taggtext, p, token);
      if (r.ok) { taggtext = r.text; skrivna.push({ ...p, token }); continue; }
      // En kortform kan redan ha ersatts av en annan sida av samma ram. Da ar
      // deklarationen TACKT, inte hoppad.
      if (taggtext.indexOf('var(' + token + ')') >= 0)
        tackta.push({ ...p, token, skal: 'tackt av samma deklaration som en annan sida av ramen' });
      else hoppade.push({ ...p, skal: r.skal });
    }
    ut = ut.slice(0, e.start) + taggtext + ut.slice(e.slut);
  }
  return { blk: ut, skrivna, hoppade, tackta };
}
