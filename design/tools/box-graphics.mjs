// F2-NT · GRAFISKA BARARE RITADE MED VANLIGA BOXAR.
//
// FELKLASSEN DENNA MODUL FINNS FOR
// tools/graphic-objects.mjs deklarerar modellen som "grafik som INTE ligger i
// en kontroll och som kravs for att FORSTA innehallet", men enumererar den med
// querySelectorAll('svg, [data-icon], [data-illustration]'). Ett forloppsstreck
// ritat med tva div-element uppfyller definitionen men matchar inte urvalet.
// Hela klassen av boxritad grafik var darfor osynlig for matningen.
//
// DENNA MODUL ar den saknade halvan. Den slas ALDRIG ihop med svg-populationen
// — de ar tva olika enumerationer av samma normativa modell och redovisas var
// for sig.
//
// UPPTACKTEN AR STRUKTURELL, ALDRIG NAMNBASERAD
// Ingen klassnamnslista, inga heuristiker pa "progress" i attribut. En relation
// ar en MALAD BARARGRUND med en MALAD VARDEBARARE inuti sig, dar
//   · bararen ar den narmaste malade forfadern till vardebararen
//   · ingen av dem bar egen synlig text
//   · vardebararen ar strikt mindre i minst en riktning
// Allt annat redovisas som utesluten kandidat med skal. Inget faller bort tyst.
//
// KOMPOSITERING AR NORMATIV
// En genomskinlig barare mats mot den FAKTISKT MALADE fargen, aldrig mot sitt
// deklarerade rgba-varde som om det vore tackande.
//
// REDUNDANS KRAVER EKVIVALENS
// En relation ar undantagen som redundant bara nar synlig text samtidigt
// formedlar SAMMA information. Att nagon siffra rakar sta i narheten racker
// aldrig.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const KLASS = Object.freeze({
  REQUIRED_INFORMATION_BEARING: 'REQUIRED_INFORMATION_BEARING',
  REDUNDANT: 'REDUNDANT',
  DECORATIVE: 'DECORATIVE',
  NOT_APPLICABLE: 'NOT_APPLICABLE',
  UNKNOWN: 'UNKNOWN' });

export const UTESLUTNING = Object.freeze({
  INUTI_DEKLARERAD_KONTROLL: 'INUTI_DEKLARERAD_KONTROLL',
  BARAREN_BAR_TEXT: 'BARAREN_BAR_TEXT',
  VARDET_BAR_TEXT: 'VARDET_BAR_TEXT',
  INTE_MINDRE: 'INTE_MINDRE',
  NOLLYTA: 'NOLLYTA',
  INGEN_MALAD_FORALDER: 'INGEN_MALAD_FORALDER' });

/* Sond. Returnerar BADE upptackta relationer och uteslutna kandidater. */
export const BOX_GRAPHICS = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  const tolka = v => { const m = String(v).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; };
  const over = (f, b) => [0,1,2].map(i => Math.round(f[i]*f[3] + b[i]*(1-f[3])));
  const synlig = el => { const cs = getComputedStyle(el);
    return cs.visibility === 'visible' && cs.display !== 'none' && parseFloat(cs.opacity) > 0; };
  const egenSynligText = el => {
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    let n; while ((n = w.nextNode())) { const s = (n.textContent || '').trim(); if (!s) continue;
      const p = n.parentElement; if (!p || !synlig(p)) continue;
      const r = document.createRange(); r.selectNodeContents(n);
      const b = r.getBoundingClientRect(); if (b.width > 0 && b.height > 0) return s; }
    return null; };
  /* Platt malad farg: stacken av malade lager, komponerad i ratt ordning. */
  const platt = el => { const stack = []; let n = el;
    while (n && n !== document.documentElement) {
      const c = tolka(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement; }
    let b = [255,255,255];
    for (let i = stack.length - 1; i >= 0; i--) b = over(stack[i], b);
    return b; };
  const rgbStr = a => 'rgb(' + a.join(', ') + ')';
  /* Narmaste MALADE forfader — samma begrepp som parent-resolution. */
  const maladForalder = el => { let n = el.parentElement;
    while (n) { const c = tolka(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0) return n; n = n.parentElement; }
    return null; };
  /* Synlig text i samma visuella grupp.
     Vi startar vid BARARENS foralder och gar uppat tills en forfader faktiskt
     innehaller synlig text utanfor relationen sjalv. Bararen ar per definition
     textlos, sa att stanna vid den ger alltid tomt — det var felet i den forsta
     korningen. Vandringen ar begransad till fyra steg sa att texten forblir
     visuellt narliggande. */
  const egnaTextnoder = n => [...n.childNodes].filter(x => x.nodeType === 3)
    .map(x => (x.textContent || '').trim()).filter(Boolean).join(' ');
  const gruppText = (varde, barare) => {
    let g = (barare || varde).parentElement, steg = 0;
    while (g && steg++ < 4) {
      const ut = [];
      for (const n of g.querySelectorAll('*')) {
        if (n === varde || n === barare || n.contains(varde)) continue;
        if (!synlig(n)) continue;
        const eg = egnaTextnoder(n);
        if (eg) ut.push(eg.slice(0, 120)); }
      if (ut.length) return ut.slice(0, 16);
      g = g.parentElement; }
    return []; };

  const relationer = [], uteslutna = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const prod = [...it.querySelectorAll('*')]
      .filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product');
    const ord = new Map(prod.map((e, i) => [e, i]));
    for (const el of prod) {
      const c = tolka(getComputedStyle(el).backgroundColor);
      if (!c || c[3] === 0) continue;                       // ingen malad vardebarare
      const r = el.getBoundingClientRect();
      const bas = { art: it.id, ordinal: ord.get(el),
        tagg: el.tagName.toLowerCase(), matt: { w: +r.width.toFixed(1), h: +r.height.toFixed(1) } };
      if (!(r.width > 0 && r.height > 0)) { uteslutna.push({ ...bas, skal: 'NOLLYTA' }); continue; }
      const far = maladForalder(el);
      if (!far) { uteslutna.push({ ...bas, skal: 'INGEN_MALAD_FORALDER' }); continue; }
      const fr = far.getBoundingClientRect();
      const kontroll = el.closest('[data-a11y-role]') || far.closest('[data-a11y-role]');
      const textVarde = egenSynligText(el), textBarare = egenSynligText(far);
      const mindre = r.width < fr.width - 0.5 || r.height < fr.height - 0.5;
      const post = { ...bas,
        bararOrdinal: ord.has(far) ? ord.get(far) : null,
        bararTagg: far.tagName.toLowerCase(),
        bararMatt: { w: +fr.width.toFixed(1), h: +fr.height.toFixed(1) },
        andelBredd: fr.width > 0 ? +(r.width / fr.width).toFixed(4) : null,
        andelHojd: fr.height > 0 ? +(r.height / fr.height).toFixed(4) : null,
        vardeDeklarerad: getComputedStyle(el).backgroundColor,
        bararDeklarerad: getComputedStyle(far).backgroundColor,
        vardeAlpha: c[3], bararAlpha: (tolka(getComputedStyle(far).backgroundColor) || [0,0,0,1])[3],
        vardeKomponerad: rgbStr(platt(el)), bararKomponerad: rgbStr(platt(far)),
        bakomBararen: rgbStr(platt(far.parentElement || far)),
        vardeInline: el.getAttribute('style'), bararInline: far.getAttribute('style'),
        vardeKlass: el.getAttribute('class'), bararKlass: far.getAttribute('class'),
        vardeKomponent: el.getAttribute('data-component'), bararKomponent: far.getAttribute('data-component'),
        grafikroll: el.getAttribute('data-graphic-role') || far.getAttribute('data-graphic-role'),
        state: el.getAttribute('data-a11y-state') || far.getAttribute('data-a11y-state'),
        stateGrupp: far.getAttribute('data-state-group'),
        iSvgPopulation: !!(el.closest('svg') || far.closest('svg') ||
          el.matches('[data-icon],[data-illustration]') || far.matches('[data-icon],[data-illustration]')),
        kontrollroll: kontroll ? kontroll.getAttribute('data-a11y-role') : null,
        gruppText: gruppText(el, far) };
      if (kontroll) { uteslutna.push({ ...post, skal: 'INUTI_DEKLARERAD_KONTROLL' }); continue; }
      if (textBarare) { uteslutna.push({ ...post, skal: 'BARAREN_BAR_TEXT', text: textBarare }); continue; }
      if (textVarde) { uteslutna.push({ ...post, skal: 'VARDET_BAR_TEXT', text: textVarde }); continue; }
      if (!mindre) { uteslutna.push({ ...post, skal: 'INTE_MINDRE' }); continue; }
      relationer.push(post); } }
  return JSON.stringify({ relationer, uteslutna }); })()`;

/* ── KOMPOSITERING ──────────────────────────────────────────────────*/

/** Den faktiskt malade angransande fargen. Aldrig det deklarerade rgba-vardet. */
export function angransandeFarg(rel) {
  if (rel.bararAlpha === undefined || rel.bararAlpha === null)
    return { ok: false, skal: 'alfa saknas — faller stangt' };
  return { ok: true, farg: rel.bararKomponerad,
    komposition: rel.bararAlpha < 1 ? 'KOMPONERAD' : 'DIREKT',
    deklarerad: rel.bararDeklarerad, bakom: rel.bakomBararen,
    $regel: rel.bararAlpha < 1
      ? 'genomskinlig barare — matt mot den faktiskt malade fargen, inte mot rgba-vardet'
      : 'tackande barare — det berknade vardet anvands direkt' }; }

/* ── REDUNDANSKONTRAKT ──────────────────────────────────────────────*/

export const EKVIVALENS = Object.freeze({
  PROPORTION: 'PROPORTION_MATCH', VARDEMANGD: 'VALUE_SET_MATCH', INGEN: 'INGEN' });

const ANDEL_TOLERANS = 0.05;

/** Plockar ut proportioner ur synlig text: "x av y", "x/y", "n %". */
export function proportionerITexten(texter) {
  const ut = [];
  for (const t of texter) {
    for (const m of String(t).matchAll(/(\d+)\s*(?:av|\/)\s*(\d+)/gi))
      if (+m[2] > 0) ut.push({ text: m[0], andel: +m[1] / +m[2], typ: 'kvot' });
    for (const m of String(t).matchAll(/(\d+(?:[.,]\d+)?)\s*%/g))
      ut.push({ text: m[0], andel: parseFloat(String(m[1]).replace(',', '.')) / 100, typ: 'procent' }); }
  return ut; }

/**
 * Ar relationen redundant? Kraver att synlig text formedlar SAMMA information.
 *
 * PROPORTION_MATCH  texten anger en proportion som stammer med den uppmatta
 * VALUE_SET_MATCH   texten anger absoluta varden vars inbordes forhallanden
 *                   stammer med syskonrelationernas proportioner
 * Allt annat -> inte redundant.
 */
export function redundansprov(rel, syskon = []) {
  const andel = rel.andelBredd !== null && rel.andelBredd < 1 ? rel.andelBredd : rel.andelHojd;
  const texter = rel.gruppText || [];
  if (!texter.length) return { redundant: false, ekvivalens: EKVIVALENS.INGEN,
    skal: 'ingen synlig text i gruppen' };
  const props = proportionerITexten(texter);
  const traff = props.find(p => Math.abs(p.andel - andel) <= ANDEL_TOLERANS);
  if (traff) return { redundant: true, ekvivalens: EKVIVALENS.PROPORTION,
    bevis: traff.text, uppmattAndel: andel, textAndel: +traff.andel.toFixed(4),
    skal: 'synlig text anger samma proportion' };
  if (props.length) return { redundant: false, ekvivalens: EKVIVALENS.INGEN,
    kandidater: props.map(p => p.text), uppmattAndel: andel,
    skal: 'texten anger en proportion som INTE stammer med den uppmatta — inte ekvivalent' };
  /* Vardemangd: absoluta tal i gruppen, jamforda mot syskonrelationernas andelar.
   *
   * TVA SPARRAR MOT SKENEKVIVALENS:
   *  1  talet maste sta ENSAMT i sin textnod — ett tal plockat ur en mening
   *     ("Recept · 30 min", en klockslagsrad) ar inget vardefalt
   *  2  syskonens andelar maste vara OLIKA. Tre identiska andelar uppfyller
   *     vilket konsekvensprov som helst och bevisar ingenting. */
  const ensamtTal = texter => { for (let i = texter.length - 1; i >= 0; i--) {
      const m = /^\s*(\d{1,4})\s*$/.exec(String(texter[i])); if (m) return +m[1]; }
    return null; };
  const egetTal = ensamtTal(texter);
  if (egetTal !== null && syskon.length >= 2) {
    const par = syskon.map(sy => ({ tal: ensamtTal(sy.gruppText || []),
      andel: sy.andelBredd !== null && sy.andelBredd < 1 ? sy.andelBredd : sy.andelHojd }))
      .filter(p => p.tal !== null && p.andel);
    const olikaAndelar = new Set([andel, ...par.map(p => p.andel)]).size;
    if (par.length >= 2 && olikaAndelar >= 3) {
      const kvoter = par.map(p => p.tal / p.andel);
      const medel = kvoter.reduce((a, b) => a + b, 0) / kvoter.length;
      const spridning = Math.max(...kvoter.map(k => Math.abs(k - medel) / medel));
      const egen = egetTal / andel;
      const passar = spridning <= 0.08 && Math.abs(egen - medel) / medel <= 0.08;
      if (passar) return { redundant: true, ekvivalens: EKVIVALENS.VARDEMANGD,
        bevis: 'absoluta varden ' + par.map(p => p.tal).join(', ') + ' motsvarar stapelandelarna ' +
          par.map(p => (p.andel * 100).toFixed(0) + '%').join(', '),
        skal: 'synliga tal och stapelandelar ar konsekventa mot samma total' }; }
    if (par.length >= 2 && olikaAndelar < 3)
      return { redundant: false, ekvivalens: EKVIVALENS.INGEN, uppmattAndel: andel,
        skal: 'syskonens andelar ar identiska — konsekvensprovet skulle vara innehallslost och bevisar ingen ekvivalens' }; }
  return { redundant: false, ekvivalens: EKVIVALENS.INGEN,
    ensamtTalIGruppen: egetTal, uppmattAndel: andel,
    skal: 'text finns men formedlar inte samma information' }; }

/* ── AVSTAMNING ─────────────────────────────────────────────────────*/

/** Varje upptackt kandidat ska forekomma exakt en gang. Inga tysta bortfall. */
export function avstamning(relationer, uteslutna) {
  const alla = [...relationer.map(r => ({ ...r, utfall: 'INKLUDERAD' })),
    ...uteslutna.map(r => ({ ...r, utfall: 'UTESLUTEN' }))];
  const nyckel = r => r.art + '|' + r.ordinal;
  const sedda = new Map();
  const dubbletter = [];
  for (const r of alla) { const k = nyckel(r);
    if (sedda.has(k)) dubbletter.push(k); sedda.set(k, r); }
  const perSkal = {};
  for (const r of uteslutna) perSkal[r.skal] = (perSkal[r.skal] || 0) + 1;
  return { kandidater: alla.length, inkluderade: relationer.length,
    uteslutna: uteslutna.length, perUteslutningsskal: perSkal,
    dubbletter, summerar: relationer.length + uteslutna.length === alla.length && !dubbletter.length,
    $regel: 'Varje upptackt kandidat redovisas exakt en gang, med utfall och skal.' }; }
