// F2-R04 · SEMANTISK CONFORMANCE SCOPE.
//
// BAKGRUND. Scopet avgjordes tidigare av CSS-klassnamn: .sc-phone och .sc-card
// gjorde nagot till produkt, .sc-label och .sc-id gjorde nagot till
// dokumentation. Den regeln foll nar .sc-cap visade sig vara semantiskt
// polymorf — samma klass bar bade "SA TOLKADE JAG BESKRIVNINGEN" (produktrubrik
// inuti en telefonram) och "Ratt · en spalt, bottenrad" (ritningens egen
// anteckning om jamforelsefallet). Ett klassnamn ar aldrig tillracklig positiv
// evidens for scope.
//
// ATTRIBUTET. data-conformance-scope uttrycker SEMANTISK CONFORMANCE SCOPE och
// ingenting annat. Det uttrycker inte farg, inte malad yta, inte theme
// coverage, inte viewport, inte layouttyp.
//
//   product      innehall som tillhor det representerade produktgranssnittet
//   annotation   text eller grafik som beskriver sjalva ritningen
//   harness      teknisk verifieringsyta  (reserverad, ingen population an)
//
// UPPLOSNING. Narmaste explicita grans i forfaderkedjan vinner. Symmetriskt:
// product far aterintrada inuti annotation, och annotation far skara ut
// dokumentation inuti en produktkomposition. Ingen sida vinner globalt.
//
// LEGACY. .sc-phone och .sc-card fortsatter tills vidare vara product-root-
// signal dar ingen explicit grans finns. De ar INTE ytproxies och INTE
// annotationsregler. Explicit grans slar alltid legacy.
//
// VAD MOTORN INTE GOR. Den loser aldrig bakgrund. maladBakgrund() nedan laser
// bara faltet bakgrund och kan darfor strukturellt inte paverkas av ett
// scopeattribut. En produktrot ar aldrig en implicit textbakgrund.

export const SCOPE_ATTRIBUT = 'data-conformance-scope';
export const SCOPEVARDEN = ['product', 'annotation', 'harness'];
export const LEGACY_ROOT_VAL = '.sc-phone, .sc-card';

/**
 * Los scopet for ett element ur dess forfaderkedja.
 *
 * kedja[0] ar elementet sjalv, kedja[n] dess n:te forfader. Varje post:
 *   { scope, legacyRoot, kontroll, productSurface, bakgrund }
 *
 * Returnerar { scope, kalla, ankare } dar kalla ar
 *   'explicit'    en authored data-conformance-scope avgjorde
 *   'legacy-root' ingen explicit grans; .sc-phone/.sc-card avgjorde
 *   'ingen'       varken explicit grans eller legacy root — utanfor populationen
 *   'ogiltig'     ett okant scopevarde nagonstans i kedjan — fail closed
 */
export function losScope(kedja) {
  const GILTIGA = ['product', 'annotation', 'harness'];
  // FAIL CLOSED FORST. Ett felstavat varde langre upp i kedjan far aldrig
  // passera tyst bara for att en narmare giltig grans rakar finnas.
  for (let i = 0; i < kedja.length; i++) {
    const v = kedja[i].scope;
    if (v === undefined || v === null || v === '') continue;
    if (!GILTIGA.includes(v))
      return { scope: null, kalla: 'ogiltig', ankare: i,
        fel: 'okant scopevarde ' + JSON.stringify(v) + ' pa niva ' + i };
  }
  for (let i = 0; i < kedja.length; i++) {
    const v = kedja[i].scope;
    if (v === undefined || v === null || v === '') continue;
    return { scope: v, kalla: 'explicit', ankare: i };
  }
  for (let i = 0; i < kedja.length; i++)
    if (kedja[i].legacyRoot) return { scope: 'product', kalla: 'legacy-root', ankare: i };
  return { scope: null, kalla: 'ingen', ankare: null };
}

/**
 * Integritetskontroll. En annotationsgrans far inte gomma verklig produkt-UI.
 *
 * Ligger en kontroll under annotation utan att en NARMARE product-grans
 * aterintrader ar det SCOPE_CONFLICT — fail closed. Motsatsen ar tillaten:
 * en produktrot inuti annotation aterintrader korrekt i produktscope.
 */
export function granskaIntegritet(kedja) {
  const r = losScope(kedja);
  if (r.kalla === 'ogiltig')
    return { ok: false, kod: 'SCOPE_INVALID', skal: r.fel, scope: null, kalla: r.kalla };
  const arKontroll = !!(kedja[0] && kedja[0].kontroll);
  if (arKontroll && r.scope === 'annotation')
    return { ok: false, kod: 'SCOPE_CONFLICT', scope: r.scope, kalla: r.kalla,
      skal: 'produktkontroll ligger under annotation utan narmare product-grans' };
  return { ok: true, kod: null, skal: null, scope: r.scope, kalla: r.kalla };
}

/**
 * Malad bakgrund ur kedjan. Laser BARA faltet bakgrund. Scope, legacy root och
 * data-product-surface ar osynliga har — det ar hela poangen.
 */
export function maladBakgrund(kedja) {
  for (let i = 0; i < kedja.length; i++)
    if (kedja[i].bakgrund) return { farg: kedja[i].bakgrund, ankare: i };
  return null;
}

/** Ingar elementet i produktpopulationen? */
export const arProdukt = kedja => losScope(kedja).scope === 'product';

// Samma kod, en gang. Sonderna nedan kor exakt de funktioner proven kor.
export const SCOPE_KOD = [losScope, granskaIntegritet, maladBakgrund].map(f => f.toString()).join('\n');

/**
 * Bygg kedjan ur en riktig DOM-nod. Som kallstrang, for injektion i sidan.
 */
export const KEDJA_KOD = `
function kedjaFor(el, stopp) {
  const k = []; let n = el;
  while (n && n !== stopp && n.nodeType === 1) {
    const cs = getComputedStyle(n);
    const bg = cs.backgroundColor;
    k.push({ scope: n.getAttribute('data-conformance-scope'),
      legacyRoot: n.classList.contains('sc-phone') || n.classList.contains('sc-card'),
      kontroll: n.hasAttribute('data-a11y-role'),
      productSurface: n.hasAttribute('data-product-surface'),
      bakgrund: (bg && !/rgba\\(0,\\s*0,\\s*0,\\s*0\\)|transparent/.test(bg)) ? bg : null,
      tagg: n.tagName.toLowerCase(), klass: n.getAttribute('class') || null });
    n = n.parentElement; }
  return k;
}`;

/**
 * INVENTERINGSSOND. Beskriver populationen, domer ingenting.
 *
 * Ett textfragment per MALANDE element — samma frysta enhet som R-01 och
 * text-population.mjs. Bade dagens klassbaserade utfall och den nya motorns
 * utfall redovisas per fragment, sa att varje denominatorforandring gar att
 * harleda fragment for fragment.
 */
export const SCOPE_INVENTERING = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  function osynlig(el) { let n = el;
    while (n && n !== document.documentElement) { const s = getComputedStyle(n);
      if (s.visibility === 'hidden' || s.visibility === 'collapse') return true;
      if (parseFloat(s.opacity) === 0) return true; n = n.parentElement; } return false; }

  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const ytor = [...it.querySelectorAll('.sc-phone, .sc-card')];
    const fragment = [];
    const sedda = new Set();
    const w = document.createTreeWalker(it, NodeFilter.SHOW_TEXT, null);
    let n;
    while ((n = w.nextNode())) {
      const t = (n.textContent || '').replace(/\\s+/g, ' ').trim();
      if (!t) continue;
      const m = n.parentElement; if (!m) continue;
      const rng = document.createRange(); rng.selectNodeContents(n);
      if (![...rng.getClientRects()].some(r => r.width > 0 && r.height > 0)) continue;
      if (osynlig(m)) continue;
      if (sedda.has(m)) { const f = fragment.find(x => x.el === m); if (f) f.text += ' ' + t; continue; }
      sedda.add(m); fragment.push({ el: m, text: t });
    }
    const poster = fragment.map(f => {
      const el = f.el;
      const kedja = kedjaFor(el, it);
      const r = losScope(kedja);
      const bg = maladBakgrund(kedja);
      // DAGENS MOTOR, ordagrant: inuti .sc-phone/.sc-card, ej under
      // .sc-label/.sc-id, sedan kontroll eller fristaende.
      const iLegacyYta = ytor.some(y => y === el || y.contains(el));
      const dokUndantag = !!el.closest('.sc-label, .sc-id');
      const kontroll = !!el.closest('[data-a11y-role]');
      const gammal = !iLegacyYta ? 'UTANFOR_POPULATION'
        : dokUndantag ? 'KLASSUNDANTAG_DOK'
        : kontroll ? 'CONTROL_TEXT' : 'STANDALONE_TEXT';
      const kedjeKlasser = kedja.map(k => k.klass).filter(Boolean);
      return { tagg: el.tagName.toLowerCase(), klass: el.getAttribute('class') || null,
        text: f.text.slice(0, 64),
        gammal, iLegacyYta, dokUndantag, kontroll,
        nyScope: r.scope, nyKalla: r.kalla,
        harMaladBakgrund: !!bg, bakgrund: bg ? bg.farg : null,
        iScCap: /(^|\\s)sc-cap(\\s|$)/.test(kedjeKlasser.join(' ')),
        egetScCap: /(^|\\s)sc-cap(\\s|$)/.test(el.getAttribute('class') || ''),
        forfaderklasser: kedjeKlasser.slice(0, 6) };
    });
    // Klassforekomster oavsett om de bar text.
    const forekomst = k => [...it.querySelectorAll(k)].length;
    ut.push({ art: it.id, poster,
      klassforekomst: { 'sc-label': forekomst('.sc-label'), 'sc-id': forekomst('.sc-id'),
        'sc-cap': forekomst('.sc-cap'), 'sc-note': forekomst('.sc-note'),
        'sc-phone': forekomst('.sc-phone'), 'sc-card': forekomst('.sc-card') },
      kontroller: [...it.querySelectorAll('[data-a11y-role]')].length,
      redanScopeAttribut: [...it.querySelectorAll('[data-conformance-scope]')].length });
  }
  return ut;
})()`;
