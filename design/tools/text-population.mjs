// F2-R01 · FULL TEXTPOPULATION I TVA STRATA.
//
// R-01:s frysta motor mater KONTROLLER. Text som inte tillhor nagon kontroll
// har darfor aldrig ingatt i namnaren — inte for att den ar godkand, utan for
// att den aldrig matts. Det ar en populationsgrans, ingen brist i R-01.
//
// Den har motorn delar ALL produkttext i exakt tva strata:
//
//   CONTROL_TEXT     textnoden har en [data-a11y-role]-forfader, eller sitter
//                    pa kontrollen sjalv
//   STANDALONE_TEXT  textnoden tillhor ingen produktkontroll
//
// Agarskapet kommer ur FAKTISK strukturell harkomst. Aldrig ur farg, aldrig
// ur narhet, aldrig ur likhet i berknat varde.
//
// Dokumentationslagret (.sc-label, .sc-id) ligger utanfor produktpopulationen
// enligt samma frysta scoperegel som ovriga motorer anvander.
//
// Primitiverna — parse, over, bgOf, osynlig, stor text — ar ordagrant desamma
// som i render-measure.mjs. Provet TP-05 jamfor de tva motorernas resultat pa
// kontrollpopulationen och faller om de nagonsin sarar pa sig.

export const TEXT_POPULATION = `(() => {
  function parse(v) {
    if (!v) return null;
    const m = String(v).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    if (!m) return null;
    return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
  }
  function over(fg, bg) {
    const a = fg[3];
    return [Math.round(fg[0] * a + bg[0] * (1 - a)),
            Math.round(fg[1] * a + bg[1] * (1 - a)),
            Math.round(fg[2] * a + bg[2] * (1 - a))];
  }
  function lum(c) {
    const f = x => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
  }
  function ratio(a, b) {
    const l1 = lum(a), l2 = lum(b), h = Math.max(l1, l2), l = Math.min(l1, l2);
    return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100;
  }
  function bgOf(el) {
    let n = el, stack = [], unreducible = null;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') { unreducible = cs.backgroundImage.slice(0, 60); break; }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement;
    }
    if (unreducible) return { unreducible };
    let base = [255, 255, 255];
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return { rgb: base };
  }
  function osynlig(el) {
    let n = el;
    while (n && n !== document.documentElement) {
      const s = getComputedStyle(n);
      if (s.visibility === 'hidden' || s.visibility === 'collapse') return 'visibility:' + s.visibility;
      if (parseFloat(s.opacity) === 0) return 'opacity:0';
      n = n.parentElement;
    }
    return null;
  }

  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    // PRODUKTYTAN. Dokumentationslagret ar ritningens egen text och ingar
    // aldrig i produktpopulationen.
    const ytor = [...it.querySelectorAll('.sc-phone, .sc-card')];
    if (!ytor.length) continue;
    const produktElement = [...it.querySelectorAll('*')]
      .filter(el => el !== it && ytor.some(y => y === el || y.contains(el)));
    const ordinalAv = new Map(produktElement.map((e, i) => [e, i]));

    // Ett textfragment per MALANDE element. Tva textnoder i samma element ar
    // ett fragment: samma farg, samma bakgrund, samma typografi.
    const perMalare = new Map();
    for (const y of ytor) {
      const w = document.createTreeWalker(y, NodeFilter.SHOW_TEXT, null);
      let n;
      while ((n = w.nextNode())) {
        const t = (n.textContent || '').replace(/\\s+/g, ' ').trim();
        if (!t) continue;
        const m = n.parentElement;
        if (!m) continue;
        if (m.closest('.sc-label, .sc-id')) continue;
        const rng = document.createRange();
        rng.selectNodeContents(n);
        const rects = [...rng.getClientRects()].filter(r => r.width > 0 && r.height > 0);
        if (!rects.length) continue;
        if (osynlig(m)) continue;
        const f = perMalare.get(m);
        if (f) f.text += ' ' + t; else perMalare.set(m, { el: m, text: t });
      }
    }

    for (const f of perMalare.values()) {
      const el = f.el;
      // AGARSKAP UR STRUKTUR. closest() foljer den faktiska forfaderkedjan.
      const ctl = el.closest('[data-a11y-role]');
      const stratum = ctl ? 'CONTROL_TEXT' : 'STANDALONE_TEXT';
      // DISABLED-UNDANTAGET, ordagrant R-01:s frysta regel. Kraver positiv
      // semantisk evidens; farg och opacity bevisar ingenting. Undantaget
      // galler bara KONTROLLER — fristaende text ar ingen inaktiv komponent
      // och kan aldrig undantas.
      let disabledBasis = null;
      if (ctl) {
        const st = (ctl.getAttribute('data-a11y-state') || '').toLowerCase();
        if (ctl.disabled === true || ctl.hasAttribute('disabled')) disabledBasis = 'native-disabled';
        else if (ctl.getAttribute('aria-disabled') === 'true') disabledBasis = 'aria-disabled';
        else if (/(^|[,;\\s])(disabled|inaktiv|avst[aä]ngd)([,;\\s]|$)/.test(st)) disabledBasis = 'data-a11y-state';
      }
      const cs = getComputedStyle(el);
      const fg = parse(cs.color);
      const bg = bgOf(el);
      const weight = parseInt(cs.fontWeight, 10) || (cs.fontWeight === 'bold' ? 700 : 400);
      const size = parseFloat(cs.fontSize) || null;
      const large = size !== null && (size >= 24 || (size >= 18.66 && weight >= 700));
      const threshold = large ? 3 : 4.5;
      const bas = { art: it.id, stratum,
        elementOrdinal: ordinalAv.has(el) ? ordinalAv.get(el) : null,
        tagg: el.tagName.toLowerCase(), klass: el.getAttribute('class') || null,
        text: f.text.slice(0, 48),
        agare: ctl ? { roll: ctl.getAttribute('data-a11y-role'),
          namn: ctl.getAttribute('data-a11y-name') || null,
          ordinal: ordinalAv.has(ctl) ? ordinalAv.get(ctl) : null,
          malareArKontrollen: ctl === el } : null,
        color: cs.color, fontSize: size, fontWeight: weight, large, threshold,
        applicability: disabledBasis ? 'exempt:disabled' : 'applicable',
        disabledBasis };
      if (bg.unreducible) {
        ut.push({ ...bas, bakgrund: null, ratio: null, status: 'unknown',
          why: 'oreducerbar bakgrund: ' + bg.unreducible, underThreshold: null });
        continue; }
      if (!fg) {
        ut.push({ ...bas, bakgrund: 'rgb(' + bg.rgb.join(', ') + ')', ratio: null,
          status: 'unknown', why: 'forgrundsfargen gick inte att tolka: ' + cs.color,
          underThreshold: null });
        continue; }
      const platt = fg[3] < 1 ? over(fg, bg.rgb) : [fg[0], fg[1], fg[2]];
      const r = ratio(platt, bg.rgb);
      // En undantagen kontroll blir ALDRIG ett fynd — och raknas heller
      // aldrig som godkand. Kvoten bevaras som evidens.
      ut.push({ ...bas, bakgrund: 'rgb(' + bg.rgb.join(', ') + ')',
        komposieradForeground: fg[3] < 1 ? 'rgb(' + platt.join(', ') + ')' : null,
        ratio: r, status: 'matt', why: null,
        underThreshold: disabledBasis ? null : r < threshold });
    }
  }
  return ut;
})()`;
