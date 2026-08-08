// F2-NT · MATSKRIPTET FOR ICKE-TEXTUELL KONTRAST.
//
// TVA STEG, I DEN HAR ORDNINGEN:
//
//   1  ROLLEN avgors. Vilken grafik BEHOVS for att se att kontrollen finns
//      (componentIdentityCarrier) och for att uppfatta dess tillstand
//      (stateCarrier)? Vad forstarker bara nagot som redan ar identifierbart
//      (supplemental)? Vad betyder ingenting (decorative)?
//
//   2  KONTRASTEN mats — men bara for carriers, och alltid mot den yta
//      carriern faktiskt ligger MOT.
//
// Kontrastvardet far ALDRIG paverka steg 1. En yta pa 1,00 kan vara helt
// redundant ELLER den enda avsedda signalen, och skillnaden avgors av
// komponentens struktur, inte av hur svag fargen rakar vara.
//
// Fargmotorn ar R-01:s verifierade — luminans, alfakomposition och
// bakgrundsupplosning. Text-run-modellen anvands inte: ett grafiskt element
// malas av nagot annat an en textnod.

export const NONTEXT_MEASURE = `(() => {
  /* ── Fargmotorn, oforandrad fran R-01 ─────────────────────────────────── */
  const srgb = c => { c /= 255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); };
  const lum = ([r,g,b]) => 0.2126*srgb(r) + 0.7152*srgb(g) + 0.0722*srgb(b);
  const parse = s => { if (!s) return null;
    const m = String(s).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    if (m) return [ +m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4] ];
    const h = String(s).trim().match(/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/);
    if (!h) return null;
    const v = h[1].length === 3 ? h[1].split('').map(c => c + c).join('') : h[1];
    return [parseInt(v.slice(0,2),16), parseInt(v.slice(2,4),16), parseInt(v.slice(4,6),16), 1]; };
  const over = (fg, bg) => { const a = fg[3]; return [0,1,2].map(i => Math.round(fg[i]*a + bg[i]*(1-a))); };
  function bakgrundBakom(el) { let n = el, stack = [], oreducerbar = null;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') { oreducerbar = cs.backgroundImage.slice(0,60); break; }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement; }
    if (oreducerbar) return { oreducerbar };
    let base = [255,255,255];
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return { rgb: base }; }
  const kvot = (f, b) => { const L1 = lum(f), L2 = lum(b);
    return +(((Math.max(L1,L2)+0.05)/(Math.min(L1,L2)+0.05))).toFixed(2); };
  const fargRgb = c => 'rgb(' + c.join(', ') + ')';

  /* ── Hjalpare for struktur, inte for farg ─────────────────────────────── */
  const synligText = el => {
    // Bara text som FAKTISKT renderas raknas som identifierande.
    let t = '';
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    let n; while ((n = w.nextNode())) {
      const s = (n.textContent || '').trim(); if (!s) continue;
      const m = n.parentElement; if (!m) continue;
      if (getComputedStyle(m).visibility !== 'visible') continue;
      const r = document.createRange(); r.selectNodeContents(n);
      if (![...r.getClientRects()].some(x => x.width > 0 && x.height > 0)) continue;
      t += s + ' '; }
    return t.trim(); };
  const CHEVRON = /chevron|caret|arrow|expand|collapse|pil/i;
  const BOCK = /check|bock|tick/i;
  // Aldrig in i en ANNAN semantisk kontrolls subtrad. Den kontrollen har sin
  // egen grafik och sin egen bedomning.
  const egenSubtrad = (el, rot) => { let n = el;
    while (n && n !== rot) { if (n.hasAttribute('data-a11y-role')) return false; n = n.parentElement; }
    return true; };
  const glyfer = el => [...el.querySelectorAll('svg, [data-icon]')]
    .filter(e => (e.tagName.toLowerCase() === 'svg' || e.hasAttribute('data-icon')) && egenSubtrad(e, el));
  const glyfFarg = svg => { const st = svg.getAttribute('stroke'), fi = svg.getAttribute('fill');
    if (st && st !== 'none') return st;
    if (fi && fi !== 'none') return fi;
    const cs = getComputedStyle(svg);
    if (cs.stroke && cs.stroke !== 'none') return cs.stroke;
    if (cs.fill && cs.fill !== 'none') return cs.fill;
    return null; };
  const harRam = el => { const c = getComputedStyle(el);
    return ['borderTopWidth','borderBottomWidth','borderLeftWidth','borderRightWidth']
      .some(k => parseFloat(c[k]) > 0); };
  const harFyllning = el => { const c = parse(getComputedStyle(el).backgroundColor);
    return !!c && c[3] > 0; };
  const rect = el => { const r = el.getBoundingClientRect();
    return { w: +r.width.toFixed(2), h: +r.height.toFixed(2), x: +r.left.toFixed(2), y: +r.top.toFixed(2) }; };

  const VALKONTROLL = new Set(['checkbox', 'radio', 'switch']);
  const TILLSTANDSROLL = new Set(['tab', 'button', 'menuitem', 'link']);

  /* ── CHILD-DESCENT · den synliga formen kan ligga under agaren ────────── */
  //
  // R-02-modellen gjorde traffytan till ett genomskinligt element och flyttade
  // den synliga formen till ett barn. Agare och visuell barare ar darfor inte
  // alltid samma nod. Descent ar tillaten — men bara nar den ger ett ENTYDIGT
  // svar.
  //
  // Regeln "forsta barnet med ram eller fyllning" anvands INTE. Den skulle
  // valja nagot aven nar ritningen inte pekar ut nagot, och det ar precis vad
  // fail closed ska hindra. Kontrast lases aldrig har.
  function visuellForm(c) {
    if (harRam(c) || harFyllning(c)) return { identitet: c, tillstand: null, grund: 'agaren har egen boundary' };
    const inom = [...c.querySelectorAll('*')].filter(e => egenSubtrad(e, c));
    const avgransade = inom.filter(e => harRam(e) || harFyllning(e));
    const g = glyfer(c);
    const bockar = g.filter(e => BOCK.test(e.getAttribute('data-icon') || ''));
    const ovrigaGlyfer = g.filter(e => !bockar.includes(e));

    if (avgransade.length === 1)
      return { identitet: avgransade[0], tillstand: bockar[0] || null,
        grund: 'exakt ett element i kontrollens egen subtrad ritar en avgransad form' };

    if (avgransade.length === 2) {
      // Track och thumb: den yttre rymmer den inre. Tva syskon gor det inte.
      const [a, b] = avgransade;
      if (a.contains(b)) return { identitet: a, tillstand: b, grund: 'tva avgransade element i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
      if (b.contains(a)) return { identitet: b, tillstand: a, grund: 'tva avgransade element i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
      return { identitet: null, tillstand: null, grund: 'tva avgransade element som syskon — vilket som ar kontrollens form gar inte att avgora' };
    }
    if (avgransade.length > 2)
      return { identitet: null, tillstand: null, grund: avgransade.length + ' avgransade element i subtradet — formen gar inte att avgora entydigt' };

    // Ingen avgransad form. Ar kontrollen ritad SOM en glyf?
    if (ovrigaGlyfer.length === 1)
      return { identitet: ovrigaGlyfer[0], tillstand: bockar[0] || null,
        grund: 'kontrollen ar ritad som en glyf och exakt en glyf bar formen' };
    if (ovrigaGlyfer.length > 1)
      return { identitet: null, tillstand: null, grund: ovrigaGlyfer.length + ' glyfer med olika funktion — vilken som ar kontrollens form gar inte att avgora' };
    return { identitet: null, tillstand: bockar[0] || null, grund: 'varken avgransad form eller glyf i kontrollens subtrad' };
  }

  const ut = [];
  for (const c of document.querySelectorAll('[data-a11y-role]')) {
    const it = c.closest('.sc-item'); if (!it) continue;
    const roll = c.getAttribute('data-a11y-role');
    const namn = c.getAttribute('data-a11y-name') || '';
    const state = c.getAttribute('data-a11y-state');
    const disabled = /(^|[,;\\s])(disabled|inaktiv|avst[aä]ngd)([,;\\s]|$)/i.test(state || '') ||
      c.hasAttribute('disabled') || c.getAttribute('aria-disabled') === 'true';
    const text = synligText(c);
    const harEgenText = text.length > 0;
    const g = glyfer(c);
    const delar = [];

    /* ── STEG 1 · ROLLEN. Ingen kontrast lases har. ────────────────────── */

    if (VALKONTROLL.has(roll)) {
      // Valkontroller identifieras av sin egen ruta, inte av etiketten:
      // etiketten sager VAD valet galler, inte att det ar ett val.
      const bock = g.find(e => BOCK.test(e.getAttribute('data-icon') || ''));
      const form = visuellForm(c);
      if (form.identitet) {
        const e = form.identitet;
        const typ = harRam(e) ? 'ram' : harFyllning(e) ? 'fyllning' : 'glyf';
        delar.push({ typ, roll_i_kontrollen: 'componentIdentityCarrier',
          motivering: 'valkontrollens egen ruta ar det som visar att en valkontroll finns; etiketten identifierar bara vad valet galler — ' + form.grund,
          el: e, motEl: e.parentElement || c, mot: 'yttre', descent: e !== c });
      } else delar.push({ typ: 'saknas', roll_i_kontrollen: 'unknown',
        motivering: 'valkontrollens form gar inte att avgora: ' + form.grund,
        el: c, mot: null });
      // Tillstandsgrafiken matas mot den yta den ligger PA — formen, inte agaren.
      const inreYta = form.identitet || c;
      if (bock) delar.push({ typ: 'bock', roll_i_kontrollen: 'stateCarrier',
        motivering: 'bocken ar den grafik som visar att kontrollen ar ikryssad',
        el: bock, motEl: inreYta, mot: 'inre' });
      const thumb = roll === 'switch'
        ? (form.tillstand && form.tillstand !== bock ? form.tillstand : [...c.children].find(e => e !== bock))
        : null;
      if (thumb) delar.push({ typ: 'thumb', roll_i_kontrollen: 'stateCarrier',
        motivering: 'reglagets knopp och dess lage visar on eller off',
        el: thumb, motEl: inreYta, mot: 'inre' });
      const anvand = new Set([form.identitet, bock, thumb].filter(Boolean));
      for (const e of g) if (!anvand.has(e)) delar.push({ typ: 'ikon',
        roll_i_kontrollen: 'supplemental',
        motivering: 'ytterligare glyf i en valkontroll som redan identifieras av sin ruta',
        el: e, motEl: inreYta, mot: 'inre' });
    } else if (!harEgenText) {
      // Ikonkontroll: glyfen ar det enda som visar att kontrollen finns.
      if (g.length) for (const e of g) delar.push({ typ: 'ikon',
        roll_i_kontrollen: 'componentIdentityCarrier',
        motivering: 'kontrollen har ingen synlig text — glyfen ar det enda som identifierar den',
        el: e, mot: 'yttre' });
      else {
        const form = visuellForm(c);
        if (form.identitet) delar.push({ typ: harRam(form.identitet) ? 'ram' : 'fyllning',
          roll_i_kontrollen: 'componentIdentityCarrier',
          motivering: 'kontrollen har varken text eller glyf — dess egen yta ar det som identifierar den — ' + form.grund,
          el: form.identitet, motEl: form.identitet.parentElement || c, mot: 'yttre',
          descent: form.identitet !== c });
        else delar.push({ typ: 'saknas', roll_i_kontrollen: 'unknown',
          motivering: 'kontrollen har varken text eller glyf och ' + form.grund,
          el: c, mot: null });
      }
    } else {
      // Textmarkt kontroll: texten identifierar komponenten. Men en glyf kan
      // anda bara TILLSTANDET, och det avgors av glyfens funktion — inte av
      // hur den ser ut fargmassigt.
      for (const e of g) {
        const ikon = e.getAttribute('data-icon') || '';
        const barState = state && TILLSTANDSROLL.has(roll) && CHEVRON.test(ikon);
        delar.push({ typ: 'ikon',
          roll_i_kontrollen: barState ? 'stateCarrier' : 'supplemental',
          motivering: barState
            ? 'kontrollen har ett tillstand och glyfen ar riktningsbarande — den visar oppet eller stangt'
            : 'kontrollen identifieras av sin synliga text; glyfen forstarker men behovs inte for identiteten',
          el: e, mot: 'yttre' });
      }
      if (harFyllning(c)) delar.push({ typ: 'fyllning', roll_i_kontrollen: 'supplemental',
        motivering: 'kontrollen identifieras av sin synliga text; fyllningen forstarker',
        el: c, mot: 'yttre' });
      if (harRam(c)) delar.push({ typ: 'ram', roll_i_kontrollen: 'supplemental',
        motivering: 'kontrollen identifieras av sin synliga text; ramen forstarker',
        el: c, mot: 'yttre' });
    }

    /* ── STEG 2 · KONTRASTEN, bara for carriers ───────────────────────── */
    const matta = delar.map(d => {
      const bas = { typ: d.typ, carrier: d.roll_i_kontrollen, motivering: d.motivering,
        ikon: d.el && d.el.getAttribute ? (d.el.getAttribute('data-icon') || null) : null,
        descent: !!d.descent };
      if (d.roll_i_kontrollen === 'supplemental' || d.roll_i_kontrollen === 'decorative' ||
          d.roll_i_kontrollen === 'unknown' || !d.mot)
        return { ...bas, kvot: null, status: d.roll_i_kontrollen === 'unknown' ? 'unknown' : 'ejKravd' };
      // Vilken yta ska den kontrastera MOT? Aldrig godtycklig forfader.
      const motEl = d.motEl || (d.mot === 'inre' ? c : (c.parentElement || c));
      const bg = bakgrundBakom(motEl);
      if (bg.oreducerbar) return { ...bas, kvot: null, status: 'unknown',
        varfor: 'oreducerbar angransande farg: ' + bg.oreducerbar };
      let f = null;
      if (d.typ === 'ram') f = parse(getComputedStyle(d.el).borderTopColor);
      else if (d.typ === 'fyllning' || d.typ === 'thumb') f = parse(getComputedStyle(d.el).backgroundColor);
      else f = parse(glyfFarg(d.el));
      if (!f) return { ...bas, kvot: null, status: 'unknown', varfor: 'fargen kunde inte tolkas' };
      const fk = f[3] < 1 ? over(f, bg.rgb) : f.slice(0, 3);
      return { ...bas, kvot: kvot(fk, bg.rgb), status: 'matt',
        farg: fargRgb(fk), angransande: fargRgb(bg.rgb),
        motYta: d.mot === 'inre' ? 'kontrollens inre yta' : 'ytan utanfor kontrollen' };
    });

    ut.push({ art: it.id, roll, namn: namn || null, state, disabled,
      harEgenText, text: text.slice(0, 30),
      glyfer: g.map(e => e.getAttribute('data-icon') || '(namnlos)'),
      // Icke-fargbaserade signaler, for color-only-sparet.
      signaler: { bock: g.some(e => BOCK.test(e.getAttribute('data-icon') || '')),
        chevron: g.some(e => CHEVRON.test(e.getAttribute('data-icon') || '')),
        text: harEgenText, glyfNamn: g.map(e => e.getAttribute('data-icon') || '').filter(Boolean).sort().join(','),
        barnAntal: c.children.length,
        thumbLage: roll === 'switch' ? getComputedStyle(c).justifyContent : null,
        form: rect(c).w + 'x' + rect(c).h },
      delar: matta });
  }
  return ut;
})()`;
