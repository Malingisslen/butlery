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

// [lucide, phosphor] names for the glyphs the example screens use; a glyph that is not here
// keeps the app's own drawing in every library.
const ICON_NAMES = {
  bell: ['bell', 'bell'], 'chevron-left': ['chevron-left', 'caret-left'], 'chevron-right': ['chevron-right', 'caret-right'],
  clock: ['clock', 'clock'], export: ['share', 'export'], heart: ['heart', 'heart'], 'log-out': ['log-out', 'sign-out'],
  minus: ['minus', 'minus'], 'more-vertical': ['ellipsis-vertical', 'dots-three-vertical'], 'nav-add': ['plus', 'plus'],
  'nav-home': ['house', 'house'], 'nav-more': ['ellipsis', 'dots-three'], 'nav-shopping': ['shopping-basket', 'basket'],
  'nav-week': ['calendar-days', 'calendar-blank'], plus: ['plus', 'plus'], 'refresh-cw': ['refresh-cw', 'arrows-clockwise'],
  search: ['search', 'magnifying-glass'], user: ['user', 'user'], users: ['users', 'users'],
};
const PH = 'https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets';
const ICON_LIBS = {
  butlery: { label: 'Butlerys egna' },
  lucide: {
    label: 'Lucide', idx: 0, url: n => `https://cdn.jsdelivr.net/npm/lucide-static@0.468.0/icons/${n}.svg`,
    wrap: ['fill', 'none', 'stroke', 'currentColor', 'stroke-linecap', 'round', 'stroke-linejoin', 'round'], stroke: 2,
  },
  'ph-regular': { label: 'Phosphor, vanlig', idx: 1, url: n => `${PH}/regular/${n}.svg`, wrap: ['fill', 'currentColor'] },
  'ph-bold': { label: 'Phosphor, fet', idx: 1, url: n => `${PH}/bold/${n}-bold.svg`, wrap: ['fill', 'currentColor'] },
  'ph-duotone': { label: 'Phosphor, dubbeltoning', idx: 1, url: n => `${PH}/duotone/${n}-duotone.svg`, wrap: ['fill', 'currentColor'] },
  'ph-fill': { label: 'Phosphor, fylld', idx: 1, url: n => `${PH}/fill/${n}-fill.svg`, wrap: ['fill', 'currentColor'] },
};

function extraCss(st, scope) {
  const k = st.space / 100;
  const pick = (v, base) => (v === base ? +(base * k).toFixed(2) : v);
  const rule = (sel, decls) => `${scoped(sel, scope)}{${important(decls)}}`;
  let css = '';
  const rowPad = pick(st.rowPad, 10), sectionGap = pick(st.sectionGap, 16), chipGap = pick(st.chipGap, 8), rowInner = pick(st.rowInner, 12);
  if (rowPad !== 10) css += rule('.phone .b-row', `padding-top:${rowPad}px;padding-bottom:${rowPad}px`);
  if (sectionGap !== 16) css += rule('.phone .b-section', `padding-top:${sectionGap}px`);
  if (st.blockGap) css += rule('.phone .b-body > * + *:not(.b-section)', `margin-top:${st.blockGap}px`);
  else if (k !== 1) css += rule('.phone .b-body > * + *:not(.b-section)', `margin-top:${+(8 * k).toFixed(2)}px`);
  if (chipGap !== 8) css += rule('.phone .b-chips,.phone .b-btnrow,.phone .b-field', `gap:${chipGap}px`);
  if (rowInner !== 12) css += rule('.phone .b-row', `gap:${rowInner}px`);
  if (st.hair !== 1) css += rule('.phone .b-row + .b-row', `border-top-width:${st.hair}px`);
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
  // The glyph markup sits in the page's sprite, so the line ends are set there.
  if (!scope && st.iconStyle === 'round') css += '#butlery-icons g{stroke-linecap:round !important;stroke-linejoin:round !important}';
  if (!scope && st.iconStyle === 'square') css += '#butlery-icons g{stroke-linecap:square !important;stroke-linejoin:miter !important}';
  if (!scope && st.iconStyle === 'duo') css += '#butlery-icons g[fill="none"]{fill:currentColor !important;fill-opacity:.18}';
  return css;
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
const iconCache = new Map(); // symbol id -> 'pending' | 'ok' | 'missing'
function ensureSymbol(libKey, glyph) {
  const lib = ICON_LIBS[libKey], names = ICON_NAMES[glyph];
  if (!lib?.url || !names) return null;
  const id = `lib-${libKey}-${glyph}`;
  const status = iconCache.get(id);
  if (status === 'ok') return id;
  if (status) return null;
  iconCache.set(id, 'pending');
  fetch(lib.url(names[lib.idx])).then(r => (r.ok ? r.text() : Promise.reject(new Error(String(r.status))))).then(text => {
    const doc = new DOMParser().parseFromString(text, 'image/svg+xml');
    const root = doc.documentElement;
    if (root.nodeName !== 'svg') throw new Error('not svg');
    const NS = 'http://www.w3.org/2000/svg';
    const sym = document.createElementNS(NS, 'symbol');
    sym.id = id;
    sym.setAttribute('viewBox', root.getAttribute('viewBox') || '0 0 24 24');
    const g = document.createElementNS(NS, 'g');
    for (let i = 0; i < lib.wrap.length; i += 2) g.setAttribute(lib.wrap[i], lib.wrap[i + 1]);
    if (lib.stroke) g.setAttribute('style', `stroke-width:var(--icon-stroke,${lib.stroke})`);
    for (const child of root.children) {
      if (child.nodeName !== 'script') g.append(document.importNode(child, true));
    }
    sym.append(g);
    document.getElementById('butlery-icons').append(sym);
    iconCache.set(id, 'ok');
    applyIcons();
  }).catch(() => iconCache.set(id, 'missing'));
  return null;
}
function applyIcons() {
  for (const use of document.querySelectorAll('#screens svg.i > use, #compare-grid svg.i > use')) {
    use.dataset.orig ||= use.getAttribute('href');
    const glyph = use.dataset.orig.replace('#i-', '');
    const want = state.iconLib === 'butlery' ? use.dataset.orig : '#' + (ensureSymbol(state.iconLib, glyph) || '');
    const target = want === '#' ? use.dataset.orig : want;
    if (use.getAttribute('href') !== target) use.setAttribute('href', target);
  }
}

// ---- Spacing overlay: boxes for every block and the gap between neighbours ----
function drawOverlay() {
  document.querySelectorAll('.lab-gap').forEach(n => n.remove());
  document.getElementById('screens').classList.toggle('lab-overlay', state.overlay);
  if (!state.overlay) return;
  for (const phone of document.querySelectorAll('#screens .phone')) {
    const base = phone.getBoundingClientRect();
    const tag = (x, y, w, h, text, kind) => {
      const el = document.createElement('div');
      el.className = `lab-gap ${kind}`;
      el.style.cssText = `left:${x - base.left}px;top:${y - base.top}px;width:${w}px;height:${h}px`;
      if (text) el.textContent = text;
      phone.append(el);
    };
    for (const body of phone.querySelectorAll('.b-body')) {
      const r = body.getBoundingClientRect();
      const m = parseFloat(getComputedStyle(body).paddingLeft);
      if (m) {
        tag(r.left, r.top, m, 28, Math.round(m), 'side');
        tag(r.right - m, r.top, m, 28, Math.round(m), 'side');
      }
    }
    const groups = [...phone.querySelectorAll('.b-body, .b-section, .b-chips, .b-btnrow')];
    for (const parent of groups) {
      const kids = [...parent.children].filter(c => c.getBoundingClientRect().height > 0 && !c.classList.contains('lab-gap'));
      for (let i = 1; i < kids.length; i++) {
        const a = kids[i - 1].getBoundingClientRect(), b = kids[i].getBoundingClientRect();
        const row = parent.matches('.b-chips, .b-btnrow');
        const gap = row ? b.left - a.right : b.top - a.bottom;
        if (gap < 1) continue;
        if (row) tag(a.right, Math.min(a.top, b.top), gap, Math.max(a.height, b.height), Math.round(gap), 'between');
        else tag(Math.min(a.left, b.left), a.bottom, Math.max(a.width, b.width), gap, Math.round(gap), 'between');
      }
    }
  }
}
