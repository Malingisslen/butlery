// F2-R04 · MALANDE DEKLARATIONER MED PROVENIENS.
//
// Rollkartan far inte lasas ur kallans text. En deklaration ar intressant
// bara nar den FAKTISKT vinner kaskaden och bidrar till det som malas.
//
//   inline overskriver klassregel  -> klassvardet ar dott och tokeniseras inte
//   klassregel utan inline         -> klassregeln ar den malande deklarationen
//   arvd farg                      -> proveniensen foljer arvet
//
// Ursprunget bevaras: INLINE · SVG_ATTRIBUTE · CLASS_RULE · INHERITED.

export const PAINT_PROBE = `(() => {
  // Alla regler i dokumentet, i kaskadordning.
  const regler = [];
  for (const ss of document.styleSheets) {
    let r; try { r = ss.cssRules; } catch { continue; }
    for (const rule of r) {
      if (!rule.selectorText || !rule.style) continue;
      regler.push({ selector: rule.selectorText, style: rule.style,
        viktig: [...rule.style].some(p => rule.style.getPropertyPriority(p) === 'important') });
    }
  }
  // Vilken regel VINNER for en egenskap pa ett element? Kaskaden approximeras:
  // inline forst, sedan viktiga regler, sedan sist matchande regel.
  function vinnare(el, egenskap) {
    const inline = el.style && el.style.getPropertyValue(egenskap);
    if (inline) return { ursprung: 'INLINE', varde: inline.trim(), selector: null,
      viktig: el.style.getPropertyPriority(egenskap) === 'important' };
    // Kortformer maste med: border och background exponerar inte sina
    // langformer nar vardet innehaller var().
    const KORT = { 'border-top-color': 'border', 'border-right-color': 'border',
      'border-bottom-color': 'border', 'border-left-color': 'border',
      'background-color': 'background' };
    let bast = null;
    for (const r of regler) {
      let v = r.style.getPropertyValue(egenskap);
      let viaKort = false;
      if (!v && KORT[egenskap]) { const k = r.style.getPropertyValue(KORT[egenskap]);
        if (k && k.indexOf('var(') >= 0) { v = k; viaKort = true; } }
      if (!v) continue;
      if (viaKort) { let matchar = false; try { matchar = el.matches(r.selector); } catch { continue; }
        if (matchar) return { ursprung: 'TOKEN_HOOK', varde: v.trim(), selector: r.selector }; }
      let matchar = false; try { matchar = el.matches(r.selector); } catch { continue; }
      if (!matchar) continue;
      const viktig = r.style.getPropertyPriority(egenskap) === 'important';
      if (!bast || viktig || !bast.viktig) bast = { ursprung: 'CLASS_RULE', varde: v.trim(),
        selector: r.selector, viktig };
    }
    return bast;
  }

  const FARGADE = ['background-color', 'border-top-color', 'border-right-color',
    'border-bottom-color', 'border-left-color', 'color', 'fill', 'stroke'];
  const genomskinlig = v => /rgba\\(0,\\s*0,\\s*0,\\s*0\\)|^transparent$|^none$/.test(v);

  const pilot = window.__PILOT || [];
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    if (pilot.length && !pilot.includes(it.id)) continue;
    // PRODUKTYTAN, inte ritningens bildtext. Varje artefakt bestar av en
    // forklarande etikett (.sc-label, .sc-id) och sjalva den avbildade
    // produktytan (.sc-phone eller .sc-card). Bara den senare ar UI som ska
    // tematiseras; etiketten ar dokumentets egen text.
    const ytor = [...it.querySelectorAll('.sc-phone, .sc-card')];
    const iProdukt = el => el === it ? false : ytor.some(y => y === el || y.contains(el));
    // KALLANKARE. Elementets ordinal i produktytans dokumentordning ar samma
    // ordning som oppningstaggarna i kallan. Migratorn far darmed en entydig
    // plats och behover aldrig harleda nagot pa nytt.
    const produktElement = [...it.querySelectorAll('*')].filter(iProdukt);
    const ordinalAv = new Map(produktElement.map((e, i) => [e, i]));
    for (const el of produktElement) {
      const cs = getComputedStyle(el);
      const taggen = el.outerHTML.slice(0, el.outerHTML.indexOf('>') + 1);
      const arKontroll = el.hasAttribute('data-a11y-role') || !!el.closest('[data-a11y-role]');
      const arSvg = el.tagName.toLowerCase() === 'svg';
      for (const egenskap of FARGADE) {
        const berak = cs.getPropertyValue(egenskap);
        if (!berak || genomskinlig(berak)) continue;
        // Ramfarg utan bredd malar ingenting.
        if (egenskap.startsWith('border-') && egenskap.endsWith('-color')) {
          const sida = egenskap.replace('border-', '').replace('-color', '');
          if (!(parseFloat(cs.getPropertyValue('border-' + sida + '-width')) > 0)) continue; }
        // fill och stroke ar bara relevanta pa svg.
        // fill och stroke mats bara pa svg-elementet sjalv. En path arver
        // svg:ns varde och ar ingen egen deklaration.
        if ((egenskap === 'fill' || egenskap === 'stroke') && !arSvg) continue;
        // color raknas bara nar elementet faktiskt malar text.
        if (egenskap === 'color') {
          const egenText = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
          if (!egenText) continue; }

        let v = vinnare(el, egenskap);
        let arvd = false;
        if (!v) {
          // Ingen egen deklaration: fargen ar arvd. Folj arvet uppat.
          let n = el.parentElement;
          while (n && !v) { v = vinnare(n, egenskap); if (v) { arvd = true; v.arvdFran = n.tagName.toLowerCase(); } n = n.parentElement; }
        }
        // svg-attribut ar en egen ursprungsklass.
        if (arSvg && (egenskap === 'fill' || egenskap === 'stroke') && el.hasAttribute(egenskap))
          v = { ursprung: 'SVG_ATTRIBUTE', varde: el.getAttribute(egenskap), selector: null };

        // Skrivbar bara nar deklarationen sitter pa elementet sjalv.
        // Arvd farg sitter pa en FORFADER. Da ar barnet inget skrivstalle.
        const skrivbar = v && !arvd && (v.ursprung === 'INLINE' || v.ursprung === 'SVG_ATTRIBUTE');
        ut.push({ art: it.id, egenskap, beraknat: berak.trim(),
          ankare: skrivbar ? { elementOrdinal: ordinalAv.get(el),
            tagg: el.tagName.toLowerCase(),
            egenskap: v.ursprung === 'SVG_ATTRIBUTE' ? egenskap : egenskap,
            form: v.ursprung } : null,
          produktElement_st: produktElement.length,
          ursprung: v ? (arvd ? 'INHERITED' : v.ursprung) : 'OKAND',
          deklaration: v ? v.varde : null, selector: v ? v.selector || null : null,
          arvd, arKontroll, arSvg,
          klass: el.getAttribute('class') || null,
          telefonram: el.classList.contains('sc-phone'),
          skelett: /sc-skeleton|sc-loader/.test(el.className || '') });
      }
    }
  }
  return ut;
})()`;
