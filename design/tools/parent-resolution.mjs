// F2-R04 · FORALDERUPPLOSNING UR FAKTISK ELEMENTIDENTITET.
//
// FELKLASSEN DENNA MODUL FINNS FOR
// Beroendegrafen i r04-beroendegraf.json byggde kanter med en hexjoin: "min
// bakgrund ar #f5f4ed, alltsa beror jag pa VARJE beslutsenhet som malar
// #f5f4ed". Det gav 1704 kanter, 36 enheter i skenbara cykler och en pastadd
// forutsattningsslutning pa 67 enheter. Ingen av dem fanns.
//
// REGELN HAR
// En foralder loses upp ur DET FAKTISKT UPPMATTA ELEMENTETS identitet —
// artefakt plus elementordinal, sa som matningen registrerade den. Relationen
// far ALDRIG harledas ur
//     · rafarg              · semantisk roll
//     · kandidatfarg        · traff mot global palett
// Modulen slar darfor aldrig upp nagot pa farg. Fargvarden anvands bara for
// att komponera om en redan upplost kedja, och da som kontroll mot matningen.
//
// TVA SKILDA BEROENDEBEGREPP, SOM ALDRIG FAR BLI ETT
//
//   COMPOSITING_DEPENDENCY
//     Avgor om foralderns farg faktiskt paverkar computed output. En TACKANDE
//     yta doljer allt under sig och har darfor inget compositingberoende.
//
//   PREVIEW_CONTEXT_DEPENDENCY
//     Avgor om foralderns slutliga design maste vara kand for att previewn ska
//     vara designmassigt arlig. En upphojd yta mots alltid mot sin foralder,
//     aven nar den ar tackande — att ligga ovanpa nagot ar hela dess mening.
//
// Preview gating anvander PREVIEW_CONTEXT_DEPENDENCY. Modulen returnerar
// aldrig ett gemensamt "dependsOn", och det finns ett metodprov som haller
// den dorren stangd.

export const BEROENDETYP = Object.freeze({
  COMPOSITING: 'COMPOSITING_DEPENDENCY',
  PREVIEW_CONTEXT: 'PREVIEW_CONTEXT_DEPENDENCY' });

export const BOTTEN = Object.freeze({
  APPYTAN: 'APPYTAN', TACKANDE: 'TACKANDE', EGEN_TACKANDE: 'EGEN_TACKANDE',
  INGEN_FORALDER: 'INGEN_FORALDER', OKAND_FORALDER: 'OKAND_FORALDER',
  FOR_DJUP: 'FOR_DJUP' });

const MAXDJUP = 64;

/* ── Fargprimitiver. Anvands bara for omkomposition, aldrig for uppslag. ──*/
export function tolkaFarg(v) {
  const m = String(v).match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (m) return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
  const h = String(v).trim().match(/^#([0-9a-f]{6})$/i);
  if (h) return [parseInt(h[1].slice(0, 2), 16), parseInt(h[1].slice(2, 4), 16),
    parseInt(h[1].slice(4, 6), 16), 1];
  return null; }
export const overLagg = (f, b) => [0, 1, 2].map(i => Math.round(f[i] * f[3] + b[i] * (1 - f[3])));
export function hexAv(v) { const c = tolkaFarg(v); if (!c) return String(v).toLowerCase();
  if (c[3] < 1) return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + c[3] + ')';
  return '#' + c.slice(0, 3).map(n => Math.round(n).toString(16).padStart(2, '0')).join(''); }

/** Elementidentitet. Den enda nyckel modulen slar upp pa. */
export const elementid = p => p.art + '|' + p.elementOrdinal;
export const postid = p => p.art + '|' + p.elementOrdinal + '|' + p.egenskap;

export const arForgrund = e => e === 'color' || e === 'fill' || e === 'stroke' ||
  String(e).startsWith('border-');

/**
 * Index over de uppmatta posterna. Bara elementidentitet som nyckel.
 * Fail closed: tva bakgrundsposter pa samma element ar en matningsdefekt.
 */
export function byggIndex(poster) {
  const bakgrundAv = new Map(), appytaOrdinal = new Map(), dubbletter = [];
  for (const p of poster) {
    if (p.arAppytan) { const f = appytaOrdinal.get(p.art);
      if (f !== undefined && f !== p.elementOrdinal)
        dubbletter.push('tva appytor i ' + p.art + ': ' + f + ' och ' + p.elementOrdinal);
      appytaOrdinal.set(p.art, p.elementOrdinal); }
    if (p.egenskap !== 'background-color') continue;
    const k = elementid(p);
    if (bakgrundAv.has(k) && bakgrundAv.get(k).varde !== p.varde)
      dubbletter.push('tva olika bakgrundsvarden pa ' + k);
    bakgrundAv.set(k, p); }
  if (dubbletter.length) throw new Error('FORALDERINDEX FAIL CLOSED: ' + dubbletter.join(' · '));
  return { bakgrundAv, appytaOrdinal, antalPoster: poster.length }; }

/** Elementets EGET malade lager, om det har nagot. */
export function egetLager(post, index) {
  const e = index.bakgrundAv.get(elementid(post)); if (!e) return null;
  const c = tolkaFarg(e.varde); if (!c || c[3] === 0) return null;
  return { art: e.art, ordinal: e.elementOrdinal, varde: e.varde, alpha: c[3],
    arInstansenSjalv: post.egenskap === 'background-color', arAppytan: !!e.arAppytan }; }

/**
 * Forfaderskedjan, fran narmaste malade forfader och nedat till och med
 * forsta TACKANDE. Uppslaget sker enbart pa underliggandeYta.ordinal.
 */
export function foralderkedja(post, index) {
  const lager = []; let nod = post, djup = 0;
  while (djup++ < MAXDJUP) {
    const uy = nod.underliggandeYta;
    if (!uy) return { lager, botten: BOTTEN.INGEN_FORALDER };
    if (uy.ordinal === undefined || uy.ordinal === null)
      throw new Error('FORALDERKEDJA FAIL CLOSED: ' + postid(nod) +
        ' saknar underliggandeYta.ordinal. Fargvardet far inte anvandas som ersattning.');
    const arApp = index.appytaOrdinal.get(nod.art) === uy.ordinal;
    const p = index.bakgrundAv.get(nod.art + '|' + uy.ordinal);
    if (!p) { lager.push({ art: nod.art, ordinal: uy.ordinal, varde: uy.farg,
      alpha: (tolkaFarg(uy.farg) || [0, 0, 0, 1])[3], arAppytan: arApp, oregistrerad: true });
      return { lager, botten: arApp ? BOTTEN.APPYTAN : BOTTEN.OKAND_FORALDER }; }
    const c = tolkaFarg(p.varde);
    lager.push({ art: p.art, ordinal: p.elementOrdinal, varde: p.varde, alpha: c ? c[3] : 1,
      arAppytan: arApp });
    if (c && c[3] === 1) return { lager, botten: arApp ? BOTTEN.APPYTAN : BOTTEN.TACKANDE };
    nod = p; }
  return { lager, botten: BOTTEN.FOR_DJUP }; }

/**
 * De tva beroendemangderna. identitetAv(lager) far namnge lagret hur den vill
 * — modulen sjalv namnger det pa elementidentitet.
 */
export function beroenden(post, index, identitetAv = l => l.art + '|' + l.ordinal) {
  const eget = egetLager(post, index);
  const { lager, botten } = foralderkedja(post, index);
  const komp = [], forh = [];
  const lagg = (arr, l) => { const id = identitetAv(l); if (!arr.includes(id)) arr.push(id); };

  if (arForgrund(post.egenskap)) {
    // En forgrund ser det narmaste tackande lagret bakom sig. Samma mangd
    // avgor bade rendering och designarlighet.
    if (eget) { lagg(komp, eget); lagg(forh, eget);
      if (eget.alpha < 1) for (const l of lager) { lagg(komp, l); lagg(forh, l); } }
    else for (const l of lager) { lagg(komp, l); lagg(forh, l); }
  } else {
    // En yta. Compositing bara nar den sjalv slapper igenom.
    const sjalv = tolkaFarg(post.varde);
    if (sjalv && sjalv[3] < 1) for (const l of lager) lagg(komp, l);
    // Previewkontext alltid: hierarkin ar sjalva beslutet.
    for (const l of lager) lagg(forh, l); }

  return { [BEROENDETYP.COMPOSITING]: komp, [BEROENDETYP.PREVIEW_CONTEXT]: forh,
    botten, egetLager: eget, kedja: lager }; }

/**
 * Rekonstruera den bakgrund matningen sag. Grinden: stammer inte
 * omkompositionen ar upplosningen fel och den anropande maste stoppa.
 */
export function rekonstruera(post, index) {
  const eget = egetLager(post, index);
  const { lager } = foralderkedja(post, index);
  const stack = [];
  if (eget) stack.push(tolkaFarg(eget.varde));
  if (!(eget && eget.alpha === 1)) for (const l of lager) stack.push(tolkaFarg(l.varde));
  let b = [255, 255, 255];
  for (let i = stack.length - 1; i >= 0; i--) if (stack[i]) b = overLagg(stack[i], b);
  return 'rgb(' + b.join(', ') + ')'; }

/** Vad matningen faktiskt registrerade som bakgrund for posten. */
export const uppmattBakgrund = post =>
  (post.egenskap === 'color' && post.text) ? post.text.bakgrund : post.plattBakgrund;

export function rekonstruktionsgrind(population, index) {
  const avvikelser = []; let stammer = 0, utanMatning = 0;
  for (const p of population) {
    const matt = uppmattBakgrund(p);
    if (!matt) { utanMatning++; continue; }
    const r = rekonstruera(p, index);
    if (hexAv(r) === hexAv(matt)) stammer++;
    else avvikelser.push({ post: postid(p), uppmatt: hexAv(matt), rekonstruerat: hexAv(r) }); }
  return { instanser: population.length, stammer, avviker: avvikelser.length,
    utanMatning, avvikelser, godkand: avvikelser.length === 0 && utanMatning === 0 }; }

/**
 * Kantmangd for previewgrindningen. En kant gar fran en enhet till den enhet
 * som ager ett lager i dess PREVIEW_CONTEXT. Lager som inte tillhor nagon
 * beslutsenhet redovisas separat som yttre, obeslutade ytor — de tystas inte.
 */
export function kantmangd(population, index, enhetAv) {
  const kanter = new Set(), yttre = new Map();
  for (const p of population) {
    const fran = enhetAv(p); if (!fran) continue;
    const b = beroenden(p, index);
    for (const id of b[BEROENDETYP.PREVIEW_CONTEXT]) {
      const [art, ordinal] = id.split('|');
      const lp = index.bakgrundAv.get(id);
      if (lp && index.appytaOrdinal.get(art) === +ordinal) continue;   // appytan ar lost
      const till = lp ? enhetAv(lp) : null;
      if (till && till !== fran) kanter.add(fran + ' ⇐ ' + till);
      else if (!till) { if (!yttre.has(id)) yttre.set(id, new Set()); yttre.get(id).add(fran); } } }
  return { kanter: [...kanter],
    yttre: [...yttre.entries()].map(([id, s]) => ({ element: id, blockerar: [...s] })) }; }
