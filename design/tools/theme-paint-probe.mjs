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
    let bast = null;
    for (const r of regler) {
      const v = r.style.getPropertyValue(egenskap);
      if (!v) continue;
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
    for (const el of [it, ...it.querySelectorAll('*')]) {
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

        ut.push({ art: it.id, egenskap, beraknat: berak.trim(),
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
