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
  // KORTFORMER. En langform kan malas av en kortform, och CSSOM slutar
  // exponera langformen sa fort kortformens varde innehaller var(). Den tomma
  // langformen ar da SIGNALEN att en kortform vann, inte franvaro av
  // deklaration. Ordningen ar fran mest till minst specifik kortform.
  const KORT = { 'border-top-color': ['border-top-color', 'border-top', 'border'],
    'border-right-color': ['border-right-color', 'border-right', 'border'],
    'border-bottom-color': ['border-bottom-color', 'border-bottom', 'border'],
    'border-left-color': ['border-left-color', 'border-left', 'border'],
    'background-color': ['background-color', 'background'] };

  // Vilken deklaration i ETT deklarationsblock malar egenskapen?
  function iBlock(style, egenskap) {
    if (!style) return null;
    const rak = style.getPropertyValue(egenskap);
    if (rak) return { varde: rak.trim(), namn: egenskap, kortform: null,
      viktig: style.getPropertyPriority(egenskap) === 'important' };
    const kandidater = (KORT[egenskap] || []).filter(n => n !== egenskap)
      .filter(n => { const v = style.getPropertyValue(n); return v && v.indexOf('var(') >= 0; });
    if (!kandidater.length) return null;
    if (kandidater.length > 1) {
      // Inom ett block vinner den sist deklarerade. Gar ordningen inte att
      // faststalla: fail closed, ingen heuristik.
      const lista = [...style];
      const idx = kandidater.map(n => lista.indexOf(n));
      if (idx.some(i => i < 0)) return { tvetydig: true, kandidater };
      const v = kandidater[idx.indexOf(Math.max.apply(null, idx))];
      return { varde: style.getPropertyValue(v).trim(), namn: v, kortform: v,
        viktig: style.getPropertyPriority(v) === 'important' };
    }
    const n = kandidater[0];
    return { varde: style.getPropertyValue(n).trim(), namn: n, kortform: n,
      viktig: style.getPropertyPriority(n) === 'important' };
  }

  // Specificitet for den del av en selektorlista som faktiskt matchar.
  function specificitet(sel, el) {
    let bast = -1;
    for (const del of String(sel).split(',')) {
      const d = del.trim(); if (!d) continue;
      let m = false; try { m = el.matches(d); } catch { continue; }
      if (!m) continue;
      const a = (d.match(/#[\\w-]+/g) || []).length;
      const b = (d.match(/\\.[\\w-]+|\\[[^\\]]*\\]|:(?!:)[\\w-]+(\\([^)]*\\))?/g) || []).length;
      const c = (d.match(/(^|[\\s>+~])[a-zA-Z][\\w-]*/g) || []).length;
      const v = a * 10000 + b * 100 + c;
      if (v > bast) bast = v;
    }
    return bast;
  }

  // Vilken deklaration VINNER kaskaden for egenskapen pa elementet?
  // Ordningen ar den riktiga: !important sist, darefter specificitet,
  // darefter kallordning. Inline behandlas som hogsta specificitet.
  // Ingen tidig retur pa forsta traff — en senare langform kan sla en
  // tidigare kortform.
  function vinnare(el, egenskap) {
    const kandidater = [];
    const inline = iBlock(el.style, egenskap);
    if (inline && inline.tvetydig) return { ursprung: 'AMBIGUOUS', varde: null, selector: null,
      skal: 'flera kortformer i stilattributet kan mala ' + egenskap + ' och ordningen gar inte att faststalla' };
    if (inline) kandidater.push({ ...inline, block: 'inline', spec: Infinity, ordning: Infinity, selector: null });
    for (let i = 0; i < regler.length; i++) {
      const r = regler[i];
      const t = iBlock(r.style, egenskap);
      if (!t || t.tvetydig) continue;
      const sp = specificitet(r.selector, el);
      if (sp < 0) continue;
      kandidater.push({ ...t, block: 'class', spec: sp, ordning: i, selector: r.selector });
    }
    if (!kandidater.length) return null;
    kandidater.sort((a, b) => (a.viktig === b.viktig ? 0 : a.viktig ? 1 : -1) ||
      (a.spec - b.spec) || (a.ordning - b.ordning));
    const v = kandidater[kandidater.length - 1];
    // Ett varde som laser sig ur en variabel ar redan tokeniserat, oavsett om
    // det star inline eller i en klassregel. Var det star bevaras i block.
    const hook = v.varde.indexOf('var(') >= 0;
    return { ursprung: hook ? 'TOKEN_HOOK' : (v.block === 'inline' ? 'INLINE' : 'CLASS_RULE'),
      varde: v.varde, selector: v.selector, viktig: v.viktig,
      block: v.block, kortform: v.kortform || null, deklarationsnamn: v.namn };
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
  // Bara dessa arvs i CSS. En forfaders background eller ram kan aldrig vara
  // kallan till ett barns malade farg.
  const ARVDA = new Set(['color', 'fill', 'stroke']);
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
        // Tvetydig vinnare: fail closed. Ingen kalla fabriceras, inget arv
        // gissas fram.
        if (v && v.ursprung === 'AMBIGUOUS') {
          ut.push({ art: it.id, egenskap, beraknat: berak.trim(), ankare: null,
            block: null, kortform: null, deklarationsnamn: null,
            produktElement_st: produktElement.length, ursprung: 'AMBIGUOUS',
            deklaration: null, selector: null, viaCurrentColor: false, kalla: null,
            skal: v.skal, elementId: el.id || null, arvd: false, arKontroll, arSvg,
            klass: el.getAttribute('class') || null,
            telefonram: el.classList.contains('sc-phone'),
            skelett: /sc-skeleton|sc-loader/.test(el.className || ''),
            roll: rollAv(egenskap, arSvg, arKontroll, el.classList.contains('sc-phone'),
              /sc-skeleton|sc-loader/.test(el.className || '')) });
          continue; }
        let arvd = false;
        if (!v) {
          // ARVET SIST. Bara nar egenskapen saknar egen deklaration — och
          // efter att bade langform och tokeniserad kortform provats — ar
          // fargen arvd. En tokeniserad kortform ar aldrig ett arv.
          if (!ARVDA.has(egenskap)) {
            // Egenskapen arvs inte i CSS. Da kan en forfaders deklaration
            // aldrig vara kallan.
          } else {
            let n = el.parentElement;
            while (n && !v) { v = vinnare(n, egenskap);
              if (v && v.ursprung === 'AMBIGUOUS') { v = null; break; }
              if (v) { arvd = true; v.arvdFran = n.tagName.toLowerCase(); } n = n.parentElement; }
          }
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
          // Kallans form bevaras: var deklarationen star (inline/class) och
          // om den kom via en kortform. En tokeniserad kortform tappar aldrig
          // sitt ursprung och blir aldrig INHERITED.
          block: v ? v.block || null : null,
          kortform: v ? v.kortform || null : null,
          deklarationsnamn: v ? v.deklarationsnamn || egenskap : null,
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
