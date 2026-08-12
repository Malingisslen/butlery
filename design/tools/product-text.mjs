// F2-R04 · FULL PRODUKTTEXTMOTOR MED AUTHORED CONFORMANCE SCOPE.
//
// Varje malande textfragment hamnar i EXAKT en klass:
//
//   PRODUCT_CONTROL_TEXT     produktscope, har en [data-a11y-role]-forfader
//   PRODUCT_STANDALONE_TEXT  produktscope, tillhor ingen kontroll
//   ANNOTATION_TEXT          annotationsscope
//   HARNESS_TEXT             harnessscope
//   UNRESOLVED               scope gick inte att avgora — fail closed
//
// Scopet kommer ur conformance-scope.mjs. Legacy .sc-phone/.sc-card galler dar
// ingen authored grans finns. Ritningens bildtext (.sc-label/.sc-id) ligger
// utanfor produktroten och faller darfor pa 'ingen' — den klassregeln ror
// motorn inte i den har omgangen, den ar avsiktligt kvar orord.
//
// Kontrastprimitiverna — parse, over, lum, ratio, bgOf, osynlig, stor text —
// ar ordagrant desamma som i render-measure.mjs och text-population.mjs.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const PRODUKTTEXT = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  function parse(v) {
    if (!v) return null;
    const m = String(v).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    if (!m) return null;
    return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
  }
  function over(fg, bg) { const a = fg[3];
    return [Math.round(fg[0] * a + bg[0] * (1 - a)),
            Math.round(fg[1] * a + bg[1] * (1 - a)),
            Math.round(fg[2] * a + bg[2] * (1 - a))]; }
  function lum(c) {
    const f = x => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); }
  function ratio(a, b) {
    const l1 = lum(a), l2 = lum(b), h = Math.max(l1, l2), l = Math.min(l1, l2);
    return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100; }
  function bgOf(el) {
    let n = el, stack = [], unreducible = null;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') { unreducible = cs.backgroundImage.slice(0, 60); break; }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement; }
    if (unreducible) return { unreducible };
    let base = [255, 255, 255];
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return { rgb: base }; }
  function osynlig(el) { let n = el;
    while (n && n !== document.documentElement) { const s = getComputedStyle(n);
      if (s.visibility === 'hidden' || s.visibility === 'collapse') return 'visibility:' + s.visibility;
      if (parseFloat(s.opacity) === 0) return 'opacity:0';
      n = n.parentElement; } return null; }

  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const alla = [...it.querySelectorAll('*')];
    const ordinalAv = new Map(alla.map((e, i) => [e, i]));
    // ETT FRAGMENT PER MALANDE ELEMENT — den frysta enheten.
    const perMalare = new Map();
    const w = document.createTreeWalker(it, NodeFilter.SHOW_TEXT, null);
    let n;
    while ((n = w.nextNode())) {
      const t = (n.textContent || '').replace(/\\s+/g, ' ').trim();
      if (!t) continue;
      const m = n.parentElement; if (!m) continue;
      const rng = document.createRange(); rng.selectNodeContents(n);
      if (![...rng.getClientRects()].some(r => r.width > 0 && r.height > 0)) continue;
      if (osynlig(m)) continue;
      const f = perMalare.get(m);
      if (f) f.text += ' ' + t; else perMalare.set(m, { el: m, text: t });
    }

    for (const f of perMalare.values()) {
      const el = f.el;
      const kedja = kedjaFor(el, it);
      const sc = losScope(kedja);
      const integritet = granskaIntegritet(kedja);
      const ctl = el.closest('[data-a11y-role]');
      let klass;
      if (sc.kalla === 'ogiltig' || !integritet.ok) klass = 'UNRESOLVED';
      else if (sc.scope === 'annotation') klass = 'ANNOTATION_TEXT';
      else if (sc.scope === 'harness') klass = 'HARNESS_TEXT';
      else if (sc.scope === 'product') klass = ctl ? 'PRODUCT_CONTROL_TEXT' : 'PRODUCT_STANDALONE_TEXT';
      else klass = 'UTANFOR_PRODUKTROT';   // varken authored grans eller legacy root
      const bas = { art: it.id, klass, scope: sc.scope, scopeKalla: sc.kalla,
        iRitningsetikett: !!el.closest('.sc-label, .sc-id'),
        scopeFel: integritet.ok ? null : integritet.kod,
        elementOrdinal: ordinalAv.has(el) ? ordinalAv.get(el) : null,
        tagg: el.tagName.toLowerCase(), klassnamn: el.getAttribute('class') || null,
        text: f.text.slice(0, 48),
        agare: ctl ? { roll: ctl.getAttribute('data-a11y-role'),
          namn: ctl.getAttribute('data-a11y-name') || null,
          ordinal: ordinalAv.has(ctl) ? ordinalAv.get(ctl) : null } : null };
      if (klass !== 'PRODUCT_CONTROL_TEXT' && klass !== 'PRODUCT_STANDALONE_TEXT') { ut.push(bas); continue; }

      // DISABLED-UNDANTAGET, ordagrant R-01:s frysta regel. Bara kontroller.
      let disabledBasis = null;
      if (ctl) { const st = (ctl.getAttribute('data-a11y-state') || '').toLowerCase();
        if (ctl.disabled === true || ctl.hasAttribute('disabled')) disabledBasis = 'native-disabled';
        else if (ctl.getAttribute('aria-disabled') === 'true') disabledBasis = 'aria-disabled';
        else if (/(^|[,;\\s])(disabled|inaktiv|avst[aä]ngd)([,;\\s]|$)/.test(st)) disabledBasis = 'data-a11y-state'; }
      const cs = getComputedStyle(el);
      const fg = parse(cs.color);
      const bg = bgOf(el);
      const weight = parseInt(cs.fontWeight, 10) || (cs.fontWeight === 'bold' ? 700 : 400);
      const size = parseFloat(cs.fontSize) || null;
      const large = size !== null && (size >= 24 || (size >= 18.66 && weight >= 700));
      const threshold = large ? 3 : 4.5;
      const m2 = { ...bas, color: cs.color, fontSize: size, fontWeight: weight, large, threshold,
        applicability: disabledBasis ? 'exempt:disabled' : 'applicable', disabledBasis };
      if (bg.unreducible) { ut.push({ ...m2, bakgrund: null, ratio: null, status: 'unknown',
        why: 'oreducerbar bakgrund: ' + bg.unreducible, underThreshold: null }); continue; }
      if (!fg) { ut.push({ ...m2, bakgrund: 'rgb(' + bg.rgb.join(', ') + ')', ratio: null,
        status: 'unknown', why: 'forgrundsfargen gick inte att tolka: ' + cs.color, underThreshold: null }); continue; }
      const platt = fg[3] < 1 ? over(fg, bg.rgb) : [fg[0], fg[1], fg[2]];
      const r = ratio(platt, bg.rgb);
      ut.push({ ...m2, bakgrund: 'rgb(' + bg.rgb.join(', ') + ')',
        ratio: r, status: 'matt', why: null,
        underThreshold: disabledBasis ? null : r < threshold });
    }
  }
  return ut;
})()`;
