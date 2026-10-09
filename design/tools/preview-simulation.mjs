// F2-R04 · TRANSIENT KANDIDATSIMULERING.
//
// Previewn svarar pa EN fraga: hur ser exakt den har beslutsenheten ut om
// kandidat X valjs? Den simulerar aldrig "byt alla forekomster av rafargen".
//
// INJEKTIONSNYCKELN ar beslutsenhetens uppslosta instansidentiteter — artefakt,
// elementordinal i PRODUKTORDINALBASEN, och den malade egenskap beslutet ager.
// Rafargen ar aldrig selector. Syskonenheter med samma rafarg maste forbli
// oforandrade, och det bevisas efter varje injektion.
//
// ORDINALBASEN kommer fran den incheckade scopemotorn, seriealiserad via
// SCOPE_KOD/KEDJA_KOD. Ingen egen kopia av scopelogiken finns i den har filen —
// en tidigare version hade det, och en avvikande kopia gor previewn oparbar
// mot matningen.
//
// INGENTING SKRIVS TILL KALLAN. Injektionen lever i den renderade sidan och
// tas bort mellan kandidater. Ingen registry-write, ingen tokenwrite.
//
// TRE FAIL-CLOSED GRINDAR, alla obligatoriska fore ett previewresultat far
// anvandas som beslutsunderlag:
//   1 TEMAGRIND      · scenen ar faktiskt i det authored morka laget
//   2 KALLGRIND      · malets nuvarande varde ar det matningen registrerade
//   3 FORALDERGRIND  · malets faktiska foralderelement ar det upplosta

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

/** Stabil, reproducerbar identitet for ett previewmal. */
export const malidentitet = m => m.art + '#' + m.ordinal + '#' + m.egenskap;

/** Ordningsoberoende fingeravtryck for en malmangd. */
export function malfingeravtryck(mal) {
  const s = mal.map(malidentitet).sort();
  let h = 2166136261;
  for (const ch of s.join('|')) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619) >>> 0; }
  return { antal: s.length, unika: new Set(s).size, fingeravtryck: h.toString(16).padStart(8, '0') }; }

/** Malgrind. Forvantad malmangd mot faktisk. Fail closed. */
export function malgrind(forvantade, faktiska) {
  const F = new Set(forvantade.map(malidentitet)), A = faktiska.map(malidentitet), As = new Set(A);
  const saknade = [...F].filter(x => !As.has(x));
  const extra = [...As].filter(x => !F.has(x));
  const dubbletter = A.filter((x, i) => A.indexOf(x) !== i);
  const ok = !saknade.length && !extra.length && !dubbletter.length;
  return { ok, saknade, extra, dubbletter,
    fingeravtryck: { forvantat: malfingeravtryck(forvantade), faktiskt: malfingeravtryck(faktiska) },
    skal: ok ? null : saknade.length + ' saknade, ' + extra.length + ' extra, ' +
      dubbletter.length + ' dubbletter' }; }

/* Produktordinalbasen. Exakt samma harledning som semantic-units och
   theme-paint-probe: index bland PRODUKTELEMENTEN, aldrig bland alla. */
const BAS = `
${SCOPE_KOD}
${KEDJA_KOD}
  function produktElement(it) {
    return [...it.querySelectorAll('*')]
      .filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product'); }`;

/** Hela artefaktens malade tillstand, i produktordinalbasen. */
export const SCENTILLSTAND = arter => `(() => {
${BAS}
  const ut = {};
  for (const id of ${JSON.stringify(arter)}) {
    const it = document.getElementById(id); if (!it) continue;
    ut[id] = produktElement(it).map(e => { const cs = getComputedStyle(e);
      return cs.color + '|' + cs.backgroundColor + '|' + cs.borderTopColor + ',' +
        cs.borderRightColor + ',' + cs.borderBottomColor + ',' + cs.borderLeftColor + '|' +
        cs.fill + ',' + cs.stroke; }); }
  return ut; })()`;

/**
 * KALLGRIND. Malets nuvarande berknade varde ska vara exakt det matningen
 * registrerade. Har kallan drivit har previewn inget att saga om beslutet.
 */
export const KALLGRIND = mal => `(() => {
${BAS}
  const MAL = ${JSON.stringify(mal)};
  const ut = [];
  for (const m of MAL) {
    const it = document.getElementById(m.art);
    if (!it) { ut.push({ ...m, ok: false, skal: 'artefakten saknas' }); continue; }
    const el = produktElement(it)[m.ordinal];
    if (!el) { ut.push({ ...m, ok: false, skal: 'ordinalen finns inte i produktbasen' }); continue; }
    const nu = getComputedStyle(el).getPropertyValue(m.egenskap);
    const lika = nu.replace(/\\s/g, '') === String(m.forvantat).replace(/\\s/g, '');
    ut.push({ ...m, nu, ok: lika, skal: lika ? null : 'kallan har drivit: ' + nu + ' mot forvantat ' + m.forvantat }); }
  return { ok: ut.every(x => x.ok), rader: ut }; })()`;

/**
 * FORALDERGRIND. Malets narmaste malade forfader ska vara det element
 * foralderupplosningen pekade ut. Jamforelsen sker pa ORDINAL, aldrig pa farg.
 */
export const FORALDERGRIND = mal => `(() => {
${BAS}
  const MAL = ${JSON.stringify(mal)};
  const parse = v => { const m = String(v).match(/rgba?\\(([\\d.]+),\\s*([\\d.]+),\\s*([\\d.]+)(?:,\\s*([\\d.]+))?\\)/);
    return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; };
  const ut = [];
  for (const m of MAL) {
    const it = document.getElementById(m.art);
    if (!it) { ut.push({ ...m, ok: false, skal: 'artefakten saknas' }); continue; }
    const prod = produktElement(it);
    const ord = new Map(prod.map((e, i) => [e, i]));
    const el = prod[m.ordinal];
    if (!el) { ut.push({ ...m, ok: false, skal: 'ordinalen finns inte' }); continue; }
    let n = el.parentElement, funnen = null;
    while (n && n !== it) { const c = parse(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0) { funnen = n; break; } n = n.parentElement; }
    const faktisk = funnen ? (ord.has(funnen) ? ord.get(funnen) : 'utanfor-produktbasen') : null;
    const lika = faktisk === m.foralderOrdinal;
    ut.push({ ...m, faktiskForalder: faktisk, ok: lika,
      skal: lika ? null : 'foralder ' + faktisk + ' mot upplost ' + m.foralderOrdinal }); }
  return { ok: ut.every(x => x.ok), rader: ut }; })()`;

/**
 * Applicera kandidaten pa exakt de angivna malen. Sparar tidigare inline-varde
 * sa att aterstallningen blir exakt.
 */
export const INJICERA = (mal, varde) => `(() => {
${BAS}
  const MAL = ${JSON.stringify(mal)};
  const V = ${JSON.stringify(varde)};
  window.__previewAterstall = window.__previewAterstall || [];
  const ut = [];
  for (const m of MAL) {
    const it = document.getElementById(m.art);
    if (!it) { ut.push({ ...m, ok: false, skal: 'artefakten saknas' }); continue; }
    const el = produktElement(it)[m.ordinal];
    if (!el) { ut.push({ ...m, ok: false, skal: 'ordinalen finns inte' }); continue; }
    const fore = getComputedStyle(el).getPropertyValue(m.egenskap);
    window.__previewAterstall.push({ el, egenskap: m.egenskap,
      tidigareInline: el.style.getPropertyValue(m.egenskap),
      tidigarePrio: el.style.getPropertyPriority(m.egenskap) });
    el.style.setProperty(m.egenskap, V, 'important');
    const efter = getComputedStyle(el).getPropertyValue(m.egenskap);
    // Berknat varde ar alltid rgb()/rgba(). Kandidaten kan vara hex. Jamforelsen
    // sker pa normaliserade kanaler — aldrig pa strangform.
    const norm = v => { const s = String(v).trim();
      const h = s.match(/^#([0-9a-f]{6})$/i);
      if (h) return [parseInt(h[1].slice(0,2),16), parseInt(h[1].slice(2,4),16), parseInt(h[1].slice(4,6),16), 1].join(',');
      const r = s.match(/rgba?\\(([\\d.]+),\\s*([\\d.]+),\\s*([\\d.]+)(?:,\\s*([\\d.]+))?\\)/);
      return r ? [+r[1], +r[2], +r[3], r[4] === undefined ? 1 : +r[4]].join(',') : s; };
    ut.push({ ...m, ok: true, fore, efter, blevKandidaten: norm(efter) === norm(V) }); }
  return ut; })()`;

/**
 * SCENTEMAGRIND. Temat maste sla igenom i SCENEN, inte nagon annanstans i
 * filen. En fil kan innehalla andra artefakter med authored dark utan att den
 * scen previewn galler har det. Grinden mater darfor scenens egna element.
 */
export const SCENTEMAGRIND = (art, tema) => `(async () => {
${BAS}
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return { ok: false, skal: 'scenen saknas' };
  const prod = produktElement(it);
  const las = () => prod.map(e => { const cs = getComputedStyle(e);
    return cs.color + '|' + cs.backgroundColor + '|' + cs.borderTopColor + '|' + cs.fill + ',' + cs.stroke; });
  const fore = las();
  const stod = (it.getAttribute('data-theme-support') || '').trim().split(/\\s+/).filter(Boolean);
  const stodjer = stod.includes(${JSON.stringify(tema)});
  if (stodjer) it.setAttribute('data-theme', ${JSON.stringify(tema)});
  await new Promise(r => requestAnimationFrame(() => r(1)));
  const efter = las();
  const andrade = efter.filter((v, i) => v !== fore[i]).length;
  if (stodjer) it.removeAttribute('data-theme');
  return { ok: stodjer && andrade > 0, scen: ${JSON.stringify(art)},
    authoredStod: stod, stodjerTemat: stodjer,
    produktElement: prod.length, andradeAvTemat: andrade,
    skal: stodjer ? (andrade ? null : 'temat deklarerat men inget berknat varde andrades')
      : 'scenen har inget authored ' + ${JSON.stringify(tema)} + '-lage' }; })()`;

/** Tar bort ALLA rester infor nasta kandidat. */
export const ATERSTALL = `(() => {
  const lista = window.__previewAterstall || [];
  for (const r of lista) {
    if (r.tidigareInline) r.el.style.setProperty(r.egenskap, r.tidigareInline, r.tidigarePrio);
    else r.el.style.removeProperty(r.egenskap); }
  window.__previewAterstall = [];
  return lista.length; })()`;

/**
 * Kollateralgrind. Bara malen — och, for arvda egenskaper, deras attlingar —
 * far ha andrats. Allt annat ar kollateral injektion och underkanner previewn.
 */
export const ARVDA = new Set(['color', 'fill', 'stroke', 'visibility']);
export function kollateralgrind(fore, efter, mal, attlingar = {}) {
  const avsett = new Set(mal.map(m => m.art + '#' + m.ordinal));
  const tillatetArv = new Set();
  for (const m of mal) if (ARVDA.has(m.egenskap))
    for (const d of (attlingar[m.art + '#' + m.ordinal] || [])) tillatetArv.add(m.art + '#' + d);
  const andrade = [], kollateral = [];
  for (const art of Object.keys(efter)) {
    const a = fore[art] || [], b = efter[art];
    for (let i = 0; i < b.length; i++) if (a[i] !== b[i]) {
      const id = art + '#' + i; andrade.push(id);
      if (!avsett.has(id) && !tillatetArv.has(id)) kollateral.push(id); } }
  return { andrade: andrade.length, kollateral, ok: kollateral.length === 0,
    avsedda: avsett.size }; }

/**
 * KANALVIS KLASSIFICERING AV ANDRINGAR.
 *
 * Felklassen: atta element flaggades som kollaterala nar de i sjalva verket
 * arvde en avsedd andring. De hade ingen egen fargdeklaration — deras
 * ramfarger ar currentColor och foljde den injicerade texten.
 *
 * Regeln: for VARJE andrad kanal, avgor om andringen HANGER PA en avsedd
 * malandring. Gor den det ar den ARVD_BEROENDE. Gor den inte det ar den
 * KOLLATERAL. Tvetydigt agarskap faller stangt.
 *
 * Tillstandsstrangen har fyra falt: color | background | fyra ramfarger | fill,stroke
 */
export const KANAL = Object.freeze({ COLOR: 0, BAKGRUND: 1, RAM: 2, GRAFIK: 3 });

export function kanalvis(fore, efter, mal, art) {
  const avsett = new Set(mal.filter(m => m.art === art).map(m => m.ordinal));
  const fyra = c => [c, c, c, c].join(',');
  const rader = [];
  const a = fore[art] || [], b = efter[art] || [];
  for (let i = 0; i < b.length; i++) {
    if (a[i] === b[i]) continue;
    const fa = String(a[i]).split('|'), fb = String(b[i]).split('|');
    if (fa.length !== fb.length) { rader.push({ ordinal: i, klass: 'OKAND',
      skal: 'tillstandsstrangarna har olika form' }); continue; }
    const andrade = fa.map((x, k) => x === fb[k] ? null : k).filter(k => k !== null);
    if (avsett.has(i)) { rader.push({ ordinal: i, klass: 'AVSEDD', kanaler: andrade }); continue; }
    // Arvt: ramfargerna foljer color bade fore och efter, och inget annat andrades.
    const bararCurrentColor = fa[KANAL.RAM] === fyra(fa[KANAL.COLOR]) &&
      fb[KANAL.RAM] === fyra(fb[KANAL.COLOR]);
    const baraColorOchRam = andrade.every(k => k === KANAL.COLOR || k === KANAL.RAM);
    if (baraColorOchRam && bararCurrentColor) {
      rader.push({ ordinal: i, klass: 'ARVD_BEROENDE', kanaler: andrade,
        skal: 'ramfargerna ar currentColor och foljer den avsedda textfargen' }); continue; }
    if (andrade.includes(KANAL.COLOR) && !bararCurrentColor && andrade.includes(KANAL.RAM)) {
      rader.push({ ordinal: i, klass: 'OKAND', kanaler: andrade,
        skal: 'ramfargen andrades men foljer inte color — agarskapet gar inte att avgora' }); continue; }
    rader.push({ ordinal: i, klass: 'KOLLATERAL', kanaler: andrade }); }
  const r = k => rader.filter(x => x.klass === k);
  return { rader, avsedda: r('AVSEDD').length, arvda: r('ARVD_BEROENDE').length,
    kollaterala: r('KOLLATERAL').length, okanda: r('OKAND').length,
    ok: r('KOLLATERAL').length === 0 && r('OKAND').length === 0,
    $regel: 'Arvt beroende ar inte kollateralt spill. Tvetydigt agarskap faller stangt.' };
}
