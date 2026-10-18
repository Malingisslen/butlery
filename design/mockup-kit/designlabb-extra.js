'use strict';
// Spacing, lines, touch targets and icons of designlabb.html. Every control defaults to the
// kit's own value, so an untouched lab changes nothing. Read by buildCss and summary in
// designlabb-core.js and by the panel in designlabb-ui.js.

const SPACE_DEFAULTS = {
  space: 100, rowPad: 10, sectionGap: 16, blockGap: 0, chipGap: 8, rowInner: 12,
  hair: 1, touch: 48, iconSize: 100, iconStroke: 0, iconStyle: '', iconLib: 'butlery', overlay: false,
};
const SPACE_PRESETS = {
  'Tätt': { space: 70 }, 'Normal': { space: 100 }, 'Luftigt': { space: 135 }, 'Mycket luftigt': { space: 170 },
};
const ICON_STYLES = [['', 'Original'], ['round', 'Runda ändar'], ['square', 'Kantiga ändar'], ['duo', 'Dubbeltoning']];
const ICON_SIZES = { '.i': 24, '.i-xs': 12, '.i-s': 16, '.i-m': 20, '.i-xl': 32 };

const ICON_LIBS = {
  butlery: { label: 'Butlerys egna' },
  lucide: {
    label: 'Lucide',
    wrap: ['fill', 'none', 'stroke', 'currentColor', 'stroke-linecap', 'round', 'stroke-linejoin', 'round'], stroke: 2,
  },
  'ph-regular': { label: 'Phosphor, vanlig', wrap: ['fill', 'currentColor'] },
  'ph-bold': { label: 'Phosphor, fet', wrap: ['fill', 'currentColor'] },
  'ph-duotone': { label: 'Phosphor, dubbeltoning', wrap: ['fill', 'currentColor'] },
  'ph-fill': { label: 'Phosphor, fylld', wrap: ['fill', 'currentColor'] },
  tabler: {
    label: 'Tabler',
    wrap: ['fill', 'none', 'stroke', 'currentColor', 'stroke-linecap', 'round', 'stroke-linejoin', 'round'], stroke: 2,
  },
  heroicons: {
    label: 'Heroicons',
    wrap: ['fill', 'none', 'stroke', 'currentColor', 'stroke-linecap', 'round', 'stroke-linejoin', 'round'], stroke: 1.5,
  },
};

function extraCss(st, scope) {
  const k = st.space / 100;
  const pick = (v, base) => (v === base ? +(base * k).toFixed(2) : v);
  const rule = (sel, decls) => `${scoped(sel, scope)}{${important(decls)}}`;
  let css = '';
  const rowPad = pick(st.rowPad, 10), sectionGap = pick(st.sectionGap, 16), chipGap = pick(st.chipGap, 8), rowInner = pick(st.rowInner, 12);
  if (rowPad !== 10) {
    css += rule('.phone .b-row,.phone .mr-item', `padding-top:${rowPad}px;padding-bottom:${rowPad}px`);
    for (const [cls, h] of Object.entries(FIXED_ROWS)) css += rule(`.phone ${cls}`, `height:${+(h + 2 * (rowPad - 10)).toFixed(2)}px`);
  }
  if (sectionGap !== 16) {
    css += rule('.phone .b-section', `padding-top:${sectionGap}px`);
    css += rule('.phone .ik-sec,.phone .sk-sec', `margin-top:${sectionGap}px`);
  }
  if (st.blockGap) css += rule('.phone .b-body > * + *:not(.b-section)', `margin-top:${st.blockGap}px`);
  else if (k !== 1) css += rule('.phone .b-body > * + *:not(.b-section)', `margin-top:${+(8 * k).toFixed(2)}px`);
  if (chipGap !== 8) css += rule('.phone .b-chips,.phone .b-btnrow,.phone .b-field,.phone .mr-chips', `gap:${chipGap}px`);
  if (rowInner !== 12) css += rule('.phone .b-row,.phone .mr-item,.phone .ik-item,.phone .sk-item', `gap:${rowInner}px`);
  if (st.hair !== 1) {
    css += rule('.phone .b-row + .b-row,.phone .sk-item + .sk-item', `border-top-width:${st.hair}px`);
    css += rule('.phone .mr-item,.phone .ik-item', `border-bottom-width:${st.hair}px`);
  }
  if (st.touch !== 48) {
    css += rule('.phone .b-iconbtn:not(.b-band .b-iconbtn)', `width:${st.touch}px;height:${st.touch}px`);
    css += rule('.phone .b-row,.phone .b-btn,.phone .b-input', `min-height:${st.touch}px`);
  }
  if (st.iconSize !== 100) {
    for (const [cls, px] of Object.entries(ICON_SIZES)) {
      css += rule(`.phone svg${cls}`, `width:${+(px * st.iconSize / 100).toFixed(1)}px;height:${+(px * st.iconSize / 100).toFixed(1)}px`);
    }
  }
  if (st.iconStroke) css += rule('.phone svg.i', `--icon-stroke:${st.iconStroke}`);
  css += staticTextCss(st.scale / 100 * (scope ? 1 : SEE.text / 100), scope);
  return css + pageMarginCss(st.margin, scope);
}

function spaceSummary(st, out) {
  const d = SPACE_DEFAULTS;
  const spacing = {};
  for (const [key, name] of [['space', 'spacingScalePercent'], ['rowPad', 'rowPaddingPx'], ['sectionGap', 'sectionGapPx'], ['blockGap', 'blockGapPx'],
    ['chipGap', 'chipGapPx'], ['rowInner', 'rowInnerGapPx'], ['hair', 'dividerThicknessPx'], ['touch', 'touchTargetPx']]) {
    if (st[key] !== d[key]) spacing[name] = st[key];
  }
  if (Object.keys(spacing).length) out.spacing = spacing;
  const icons = {};
  if (st.iconSize !== 100) icons.sizePercent = st.iconSize;
  if (st.iconStroke) icons.strokeWidth = st.iconStroke;
  if (st.iconStyle) icons.lineEnds = st.iconStyle;
  if (st.iconLib !== 'butlery') icons.library = ICON_LIBS[st.iconLib]?.label || st.iconLib;
  if (Object.keys(icons).length) out.icons = icons;
}

// ---- Icon libraries ----
// The glyphs come from designlabb-iconlibs.js, so the lab needs no network.
function ensureSymbol(libKey, glyph) {
  const lib = ICON_LIBS[libKey], data = ICON_LIB_DATA[libKey]?.[glyph];
  if (!lib?.wrap || !data) return null;
  const id = `lib-${libKey}-${glyph}`;
  if (document.getElementById(id)) return id;
  const doc = new DOMParser().parseFromString(`<svg xmlns="http://www.w3.org/2000/svg">${data[1]}</svg>`, 'image/svg+xml');
  const NS = 'http://www.w3.org/2000/svg';
  const sym = document.createElementNS(NS, 'symbol');
  sym.id = id;
  sym.setAttribute('viewBox', data[0]);
  const g = document.createElementNS(NS, 'g');
  for (let i = 0; i < lib.wrap.length; i += 2) g.setAttribute(lib.wrap[i], lib.wrap[i + 1]);
  if (lib.stroke) g.setAttribute('style', `stroke-width:var(--icon-stroke,${lib.stroke})`);
  for (const child of doc.documentElement.children) g.append(document.importNode(child, true));
  sym.append(g);
  document.getElementById('butlery-icons').append(sym);
  return id;
}
// A part can swap its own icon or library; the part's selector and scope decide which icons it reaches.
function iconOverrides() {
  const map = new Map();
  for (const part of Object.values(state.parts)) {
    if (!part.props.glyph && !part.props.lib) continue;
    for (const phone of document.querySelectorAll('#screens .phone, #compare-grid .phone')) {
      const dark = phone.dataset.theme === 'dark';
      if (part.mode === 'light' && dark || part.mode === 'dark' && !dark) continue;
      if (part.view != null && phone.dataset.view != part.view) continue;
      let hits = [];
      try { hits = [...phone.querySelectorAll(part.sel)]; } catch { /* a selector the browser refuses matches nothing */ }
      for (const svg of hits) if (svg.matches('svg.i')) map.set(svg, { ...map.get(svg), ...(part.props.glyph && { glyph: part.props.glyph }), ...(part.props.lib && { lib: part.props.lib }) });
    }
  }
  return map;
}
// A <use> clone ignores page rules aimed at the sprite, so the line ends are written onto the sprite's own markup.
const ICON_ATTRS = ['stroke-linecap', 'stroke-linejoin', 'fill', 'fill-opacity'];
let iconStyleDone = null;
function applyIconStyle(style) {
  const sprite = document.getElementById('butlery-icons');
  const key = style + '|' + sprite.childElementCount;
  if (key === iconStyleDone) return;
  iconStyleDone = key;
  for (const g of sprite.querySelectorAll('g')) {
    g.labOrig ||= Object.fromEntries(ICON_ATTRS.map(a => [a, g.getAttribute(a)]));
    const want = { ...g.labOrig };
    if (style === 'round') Object.assign(want, { 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
    if (style === 'square') Object.assign(want, { 'stroke-linecap': 'square', 'stroke-linejoin': 'miter' });
    if (style === 'duo' && g.labOrig.fill === 'none') Object.assign(want, { fill: 'currentColor', 'fill-opacity': '.18' });
    for (const a of ICON_ATTRS) {
      if (want[a] === null) g.removeAttribute(a);
      else if (g.getAttribute(a) !== want[a]) g.setAttribute(a, want[a]);
    }
  }
}

function applyIcons() {
  applyIconStyle(compare ? '' : state.iconStyle);
  const over = iconOverrides();
  for (const use of document.querySelectorAll('#screens svg.i > use, #compare-grid svg.i > use')) {
    use.dataset.orig ||= use.getAttribute('href');
    const o = over.get(use.parentNode);
    const glyph = o?.glyph || use.dataset.orig.replace('#i-', '');
    const lib = o?.lib || state.iconLib;
    const own = o?.glyph ? '#i-' + glyph : use.dataset.orig;
    const want = lib === 'butlery' ? own : '#' + (ensureSymbol(lib, glyph) || '');
    const target = want === '#' ? own : want;
    if (use.getAttribute('href') !== target) use.setAttribute('href', target);
  }
}

// ---- Spacing overlay: boxes for every block and the gap between neighbours ----
// With "drag the spacing" on, every gap is a handle for the global slider that sets it, so one drag
// changes that spacing in the whole app.
let spaceDrag = false;
let spaceBig = true; // one size of gap at a time keeps the screens readable
const BIG_GAP = 12;
function drawOverlay() {
  document.querySelectorAll('.lab-gap').forEach(n => n.remove());
  const show = state.overlay || spaceDrag;
  document.getElementById('screens').classList.toggle('lab-overlay', state.overlay);
  document.getElementById('screens').classList.toggle('lab-spacedrag', spaceDrag);
  if (!show) return;
  for (const phone of document.querySelectorAll('#screens .phone')) {
    const base = phone.getBoundingClientRect();
    const tag = (x, y, w, h, text, kind, key, axis, sign = 1) => {
      if (spaceDrag && key && (text >= BIG_GAP) !== spaceBig) return null;
      const el = document.createElement('div');
      el.className = `lab-gap ${kind}`;
      el.style.cssText = `left:${x - base.left}px;top:${y - base.top}px;width:${w}px;height:${h}px`;
      if (spaceDrag && key) {
        el.classList.add('drag');
        Object.assign(el.dataset, { spaceKey: key, spaceAxis: axis, spaceSign: sign });
        el.textContent = `${axis === 'y' ? '↕' : '↔'} ${text}`;
      } else if (text) el.textContent = text;
      phone.append(el);
      return el;
    };
    for (const body of phone.querySelectorAll('.b-body')) {
      const r = body.getBoundingClientRect();
      const m = parseFloat(getComputedStyle(body).paddingLeft);
      if (m) {
        tag(r.left, r.top, m, 28, spaceDrag ? state.margin : Math.round(m), 'side', 'margin', 'x', 1);
        tag(r.right - m, r.top, m, 28, spaceDrag ? state.margin : Math.round(m), 'side', 'margin', 'x', -1);
      }
    }
    const groups = [...phone.querySelectorAll('.b-body, .b-section, .b-chips, .b-btnrow')];
    for (const parent of groups) {
      const kids = [...parent.children].filter(c => c.getBoundingClientRect().height > 0 && !c.classList.contains('lab-gap'));
      const row = parent.matches('.b-chips, .b-btnrow');
      const key = row ? 'chipGap' : parent.matches('.b-body') ? 'blockGap' : null;
      for (let i = 1; i < kids.length; i++) {
        const a = kids[i - 1].getBoundingClientRect(), b = kids[i].getBoundingClientRect();
        const gap = row ? b.left - a.right : b.top - a.bottom;
        if (gap < 1) continue;
        if (row) tag(a.right, Math.min(a.top, b.top), gap, Math.max(a.height, b.height), Math.round(gap), 'between', key, 'x');
        else tag(Math.min(a.left, b.left), a.bottom, Math.max(a.width, b.width), gap, Math.round(gap), 'between', key, 'y');
      }
    }
    if (!spaceDrag) continue;
    // Views built from their own parts: every gap between neighbours moves that part and its like parts.
    const covered = '.b-body, .b-section, .b-chips, .b-btnrow, .b-row';
    for (const parent of phone.querySelectorAll('[data-lab-id]')) {
      if (parent.matches(covered) || parent.closest('svg')) continue;
      const kids = [...parent.children].filter(c => c.dataset.labId && !c.classList.contains('lab-gap') && c.getBoundingClientRect().height > 0);
      for (let i = 1; i < kids.length; i++) {
        const a = kids[i - 1].getBoundingClientRect(), b = kids[i].getBoundingClientRect();
        const down = b.top >= a.bottom - 0.5, across = !down && b.left >= a.right - 0.5;
        const gap = down ? b.top - a.bottom : across ? b.left - a.right : 0;
        if (gap < 1) continue;
        const axis = down ? 'y' : 'x';
        const made = down ? tag(Math.min(a.left, b.left), a.bottom, Math.max(a.width, b.width), gap, Math.round(gap), 'between', 'part', 'y')
          : tag(a.right, Math.min(a.top, b.top), gap, Math.max(a.height, b.height), Math.round(gap), 'between', 'part', axis);
        if (made) made.dataset.partId = kids[i].dataset.labId;
      }
    }
    for (const sec of phone.querySelectorAll('.b-section')) {
      const r = sec.getBoundingClientRect(), pad = parseFloat(getComputedStyle(sec).paddingTop);
      if (pad >= 1) tag(r.left, r.top, Math.min(r.width, 56), pad, Math.round(pad), 'between', 'sectionGap', 'y');
    }
    for (const rowEl of phone.querySelectorAll('.b-row')) {
      const r = rowEl.getBoundingClientRect(), cs = getComputedStyle(rowEl), pad = parseFloat(cs.paddingTop);
      if (pad >= 1) tag(r.left, r.top, Math.min(r.width, 56), pad, Math.round(pad), 'between', 'rowPad', 'y');
      const kids = [...rowEl.children].filter(c => c.getBoundingClientRect().height > 0);
      if (kids.length > 1) {
        const a = kids[0].getBoundingClientRect(), b = kids[1].getBoundingClientRect(), gap = b.left - a.right;
        if (gap >= 1) tag(a.right, Math.min(a.top, b.top), gap, Math.max(a.height, b.height), Math.round(gap), 'between', 'rowInner', 'x');
      }
    }
  }
}
// A drag on a gap handle moves the global slider by the pointer's travel along the gap's axis.
function wireSpaceDrag() {
  const screens = document.getElementById('screens');
  screens.addEventListener('pointerdown', e => {
    const h = e.target.closest?.('.lab-gap.drag');
    if (!h) return;
    e.preventDefault(); e.stopPropagation();
    const { spaceKey: key, spaceAxis: axis } = h.dataset, sign = +h.dataset.spaceSign;
    if (key === 'part') return dragPartGap(e, h, axis);
    const input = document.getElementById(key);
    const shown = parseFloat(h.textContent.replace(/[^\d.-]/g, '')) || 0;
    // A slider left at its original reads from the gap that was grabbed; one already set is the start.
    const from = key === 'margin' || state[key] !== SPACE_DEFAULTS[key] && state[key] ? state[key] : shown, at = axis === 'y' ? e.clientY : e.clientX;
    const move = ev => {
      const v = Math.round(from + sign * ((axis === 'y' ? ev.clientY : ev.clientX) - at));
      const next = Math.min(+input.max, Math.max(+input.min, v));
      if (next === state[key]) return;
      state[key] = next; input.value = next; showValue(key); markSliders(); render();
    };
    const up = () => { removeEventListener('pointermove', move); removeEventListener('pointerup', up); };
    addEventListener('pointermove', move);
    addEventListener('pointerup', up);
  }, true);
  screens.addEventListener('click', e => { if (e.target.closest?.('.lab-gap.drag')) { e.preventDefault(); e.stopPropagation(); } }, true);
}

// A gap between two parts is the later part's top (or left) margin; it is set on that part and its like
// parts, except the first of each group, which has nothing above it.
function dragPartGap(e, h, axis) {
  const el = h.closest('.phone').querySelector(`[data-lab-id="${h.dataset.partId}"]`);
  if (!el) return;
  const partOf = (node, edge) => {
    const base = selectorFor(node, false);
    if (base === '.phone') return null;
    const sel = `${base}:not(:${edge}-child)`, key = `both|${sel}`;
    return state.parts[key] ||= { sel, mode: 'both', props: {} };
  };
  const part = partOf(el, 'first'), prev = el.previousElementSibling;
  if (!part) return;
  const cs = getComputedStyle(el), flow = /flex|grid/.test(getComputedStyle(el.parentElement).display);
  const mtNow = parseFloat(axis === 'y' ? cs.marginTop : cs.marginLeft) || 0;
  const r = el.getBoundingClientRect(), pr = prev.getBoundingClientRect();
  const gapNow = Math.round(axis === 'y' ? r.top - pr.bottom : r.left - pr.right);
  // In normal block flow the previous part's bottom margin collapses with this top margin, so it is
  // cleared and the top margin carries the whole gap; flex and grid add the two instead.
  const collapses = axis === 'y' && !flow && prev.dataset.labId;
  const prevPart = collapses ? partOf(prev, 'last') : null;
  const from = collapses ? gapNow : mtNow, prop = axis === 'y' ? 'mT' : 'mL';
  const at = axis === 'y' ? e.clientY : e.clientX;
  const move = ev => {
    const v = Math.min(64, Math.max(-16, Math.round(from + (axis === 'y' ? ev.clientY : ev.clientX) - at)));
    if (part.props[prop] === v) return;
    part.props[prop] = v;
    if (prevPart) prevPart.props.mB = 0;
    render();
  };
  const up = () => { removeEventListener('pointermove', move); removeEventListener('pointerup', up); };
  addEventListener('pointermove', move);
  addEventListener('pointerup', up);
}
