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
      // En langform som redan laser sitt varde ur en variabel ar lika mycket
      // en tokenhook som kortformen. Skillnaden var bara att kortformen inte
      // exponerar sina langformer, aldrig att den ena vore mer tokeniserad.
      const hook = v.indexOf('var(') >= 0;
      if (!bast || viktig || !bast.viktig) bast = { ursprung: hook ? 'TOKEN_HOOK' : 'CLASS_RULE',
        varde: v.trim(), selector: r.selector, viktig };
    }
    return bast;
  }

  // ROLLEN HARLEDS HAR, en enda gang. Konsumenterna far den fardig och far
  // aldrig rakna ut den pa nytt — det var precis den dubbleringen som lat
  // migratorn kalla en ikon i en kontroll for fristaende.
  const rollAv = (egenskap, arSvg, arKontroll, telefonram, skelett) => {
    if (arSvg) return arKontroll ? 'ikon-kontroll' : 'ikon-fristaende';
    if (egenskap === 'color') return arKontroll ? 'text-kontroll' : 'text-innehall';
    if (egenskap === 'background-color') {
      if (telefonram) return 'yta-app';
      if (skelett) return 'yta-platshallare';
      return arKontroll ? 'yta-kontroll' : 'yta-upphojd'; }
    if (/^border-(top|right|bottom|left)-color$/.test(egenskap)) {
      if (telefonram) return 'ram-app';
      return arKontroll ? 'ram-kontroll' : 'ram-behallare'; }
    return 'ospecificerad';
  };

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
        if (arSvg && (egenskap === 'fill' || egenskap === 'stroke') && el.hasAttribute(egenskap)) {
          v = { ursprung: 'SVG_ATTRIBUTE', varde: el.getAttribute(egenskap), selector: null };
          arvd = false; }

        // CURRENTCOLOR AR EN HANVISNING, INTE ETT FARGVARDE.
        //
        // fill="currentColor" sager bara "ta den farg elementet redan har".
        // Deklarationen som FAKTISKT bestammer fargen ar color-deklarationen,
        // och den kan sitta pa elementet sjalv eller pa en forfader. Att peka
        // ut svg-attributet som skrivstalle ar att peka ut fel kalla: dar
        // finns inget fargvarde att byta.
        //
        // Proveniensen foljer alltsa hanvisningen hela vagen till den
        // vinnande color-deklarationen och behaller dess ursprung. Finns
        // ingen entydig authored kalla: fail closed, ingen fabricerad kalla.
        let kalla = null;
        if (v && /^currentcolor$/i.test(String(v.varde).trim())) {
          const hanvisning = { ursprung: v.ursprung, varde: v.varde, selector: v.selector || null };
          let barare = el, c = vinnare(el, 'color'), arvdC = false;
          while (!c && barare.parentElement) {
            barare = barare.parentElement;
            c = vinnare(barare, 'color');
            if (c) arvdC = true; }
          if (!c) {
            kalla = { hanvisning, upplost: false, skal: 'ingen authored color-deklaration i kedjan' };
            v = null; arvd = false;
          } else {
            const iYtan = iProdukt(barare);
            kalla = { hanvisning, upplost: true, egenskap: 'color', ursprung: c.ursprung,
              varde: c.varde, selector: c.selector || null, arvd: arvdC,
              tagg: barare.tagName.toLowerCase(), iProduktytan: iYtan,
              elementOrdinal: iYtan ? ordinalAv.get(barare) : null,
              skal: iYtan ? null : 'color-deklarationen ligger utanfor produktytan' };
            v = { ursprung: c.ursprung, varde: c.varde, selector: c.selector || null };
            arvd = arvdC; }
        }

        // Skrivbar bara nar deklarationen sitter pa elementet sjalv.
        // Arvd farg sitter pa en FORFADER. Da ar barnet inget skrivstalle.
        // Undantaget ar currentColor: dar ar bararen av color-deklarationen
        // ett exakt utpekat skrivstalle, inte en gissning ur DOM-narhet.
        let ankare = null;
        if (kalla) {
          if (kalla.upplost && kalla.ursprung === 'INLINE' && kalla.iProduktytan)
            ankare = { elementOrdinal: kalla.elementOrdinal, tagg: kalla.tagg,
              egenskap: 'color', form: 'INLINE' };
        } else if (v && !arvd && (v.ursprung === 'INLINE' || v.ursprung === 'SVG_ATTRIBUTE')) {
          ankare = { elementOrdinal: ordinalAv.get(el), tagg: el.tagName.toLowerCase(),
            egenskap, form: v.ursprung };
        }
        ut.push({ art: it.id, egenskap, beraknat: berak.trim(),
          ankare,
          produktElement_st: produktElement.length,
          // Proveniensen bevaras. En currentColor-post far kallans ursprung,
          // aldrig INHERITED: att deklarationen sitter pa en forfader ar en
          // egenskap hos kallan (kalla.arvd), inte ett okant ursprung.
          ursprung: kalla ? (kalla.upplost ? kalla.ursprung : 'OKAND_CURRENTCOLOR')
            : v ? (arvd ? 'INHERITED' : v.ursprung) : 'OKAND',
          deklaration: v ? v.varde : null, selector: v ? v.selector || null : null,
          viaCurrentColor: !!kalla, kalla,
          elementId: el.id || null,
          arvd, arKontroll, arSvg,
          klass: el.getAttribute('class') || null,
          telefonram: el.classList.contains('sc-phone'),
          skelett: /sc-skeleton|sc-loader/.test(el.className || ''),
          roll: rollAv(egenskap, arSvg, arKontroll,
            el.classList.contains('sc-phone'),
            /sc-skeleton|sc-loader/.test(el.className || '')) });
      }
    }
  }
  return ut;
})()`;
