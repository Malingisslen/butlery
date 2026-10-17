'use strict';
// Core of designlabb.html: reads the generated token block back from the page, holds the lab
// state, turns a state into CSS and keeps the undo history. It reads the page's own stylesheet,
// so it follows tokens.json without a second list to keep in sync.

const HEX = /^#[0-9a-f]{6}$/i;
const used = new Map(); // original hex -> [{ selector, name }]
const paletteNames = new Map(); // original hex -> palette names
const sizes = new Map(); // type role -> original px
const weights = new Map(); // type role -> original weight
const radii = []; // { selector, px }
for (const sheet of document.styleSheets) {
  let rules;
  try { rules = sheet.cssRules; } catch { continue; }
  for (const rule of rules) {
    if (!(rule instanceof CSSStyleRule)) continue;
    const root = /:root|\[data-theme/.test(rule.selectorText);
    for (const prop of rule.style) {
      const v = rule.style.getPropertyValue(prop).trim();
      if (root && prop.startsWith('--') && HEX.test(v)) {
        const hex = v.toLowerCase();
        if (!used.has(hex)) used.set(hex, []);
        used.get(hex).push({ selector: rule.selectorText, name: prop });
        if (prop.startsWith('--butlery-palette-')) {
          if (!paletteNames.has(hex)) paletteNames.set(hex, []);
          paletteNames.get(hex).push(prop.replace('--butlery-palette-', ''));
        }
      }
      const type = /^--butlery-type-(.*)-(size|weight)$/.exec(prop);
      if (type && rule.selectorText === ':root') {
        (type[2] === 'size' ? sizes : weights).set(type[1], parseFloat(v));
      }
    }
    const v = rule.style.getPropertyValue('border-radius').trim();
    if (!root && (v === '12px' || v === '8px')) radii.push({ selector: rule.selectorText, px: v });
  }
}

const FONTS = {
  'ButlerySans': null,
  'Inter': 'Inter:wght@400;600;700',
  'DM Sans': 'DM+Sans:wght@400;600;700',
  'Nunito': 'Nunito:wght@400;600;700',
  'Poppins': 'Poppins:wght@400;600;700',
  'Lora': 'Lora:wght@400;600;700',
  'Fraunces': 'Fraunces:wght@400;600;700',
  'Playfair Display': 'Playfair+Display:wght@400;600;700',
  'Georgia': null,
  'system-ui': null,
};
const defaults = () => ({
  font: 'ButlerySans', fontHead: '', typeRatio: '', scale: 100, lh: 100, card: 12, control: 8, margin: 24,
  hue: 0, sat: 100, light: 100, colors: {}, roles: {}, parts: {}, pause: false,
  moves: [], free: {}, notes: [], ...SPACE_DEFAULTS,
});
let state = defaults();
const clone = st => JSON.parse(JSON.stringify(st));

function hexToHsl(hex) {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255);
  const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
  if (!d) return [0, 0, l];
  const s = d / (1 - Math.abs(2 * l - 1));
  const h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, s, l];
}
function hslToHex(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return '#' + [r, g, b].map(v => Math.round((v + m) * 255).toString(16).padStart(2, '0')).join('');
}
const rgba = (hex, a) => {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  return `rgba(${r},${g},${b},${a})`;
};
function finalColor(st, hex) {
  if (st.colors[hex]) return st.colors[hex];
  if (st.hue === 0 && st.sat === 100 && st.light === 100) return hex;
  const [h, s, l] = hexToHsl(hex);
  return hslToHex((h + st.hue + 360) % 360, Math.min(1, s * st.sat / 100), Math.min(1, l * st.light / 100));
}

// A scope puts every rule under one container, so two states can be drawn side by side.
function scoped(selector, scope) {
  if (!scope) return selector;
  return selector.split(',').map(s => s.trim()).map(s => s === ':root' ? scope : `${scope} ${s}`).join(',');
}

const KEYFRAMES = `
@keyframes lab-pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.07)}}
@keyframes lab-bounce{0%,100%{transform:translateY(0)}50%{transform:translateY(-6px)}}
@keyframes lab-shake{0%,100%{transform:translateX(0)}20%{transform:translateX(-4px)}40%{transform:translateX(4px)}60%{transform:translateX(-3px)}80%{transform:translateX(3px)}}
@keyframes lab-float{0%,100%{transform:translateY(0) rotate(0)}50%{transform:translateY(-5px) rotate(.8deg)}}
@keyframes lab-glow{0%,100%{filter:drop-shadow(0 0 0 rgba(206,124,30,0))}50%{filter:drop-shadow(0 0 12px rgba(206,124,30,.9))}}
@keyframes lab-spin{to{transform:rotate(360deg)}}
@keyframes lab-fade{0%,100%{opacity:1}50%{opacity:.35}}
@keyframes lab-wiggle{0%,100%{transform:rotate(-3deg)}50%{transform:rotate(3deg)}}`;
const ANIMS = [['', 'Ingen'], ['pulse', 'Pulsera'], ['bounce', 'Studsa'], ['shake', 'Skaka'], ['float', 'Sväva'], ['glow', 'Glöda'], ['wiggle', 'Vicka'], ['fade', 'Blinka mjukt'], ['spin', 'Snurra']];
const HOVERS = [['', 'Ingen'], ['lift', 'Lyft med skugga'], ['grow', 'Förstora'], ['glow', 'Glöd'], ['bright', 'Ljusna'], ['dim', 'Tona ner']];
const PRESSES = [['', 'Ingen'], ['sink', 'Krymp'], ['dip', 'Tryck ner']];
const HOVER_CSS = {
  lift: 'transform:translateY(-3px);filter:drop-shadow(0 8px 14px rgba(23,37,29,.28))',
  grow: 'transform:scale(1.06)', glow: 'filter:drop-shadow(0 0 10px rgba(206,124,30,.85))',
  bright: 'filter:brightness(1.12)', dim: 'opacity:.7',
};
const PRESS_CSS = { sink: 'transform:scale(.95)', dip: 'transform:translateY(2px)' };
const MODE_SCOPE = { light: '.phone:not([data-theme="dark"])', dark: '.phone[data-theme="dark"]', both: '.phone' };
const important = css => css.split(';').filter(Boolean).map(x => x + ' !important').join(';');

// Descendants of a part that have their own text colour, size or icon.
const CHILD = {
  lab: '.label,.title,.text', sub: '.subtitle,.value', ico: 'svg.i,.i',
};

function declsFor(st, p, base) {
  const d = [];
  const bg = p.bg ?? base?.bg;
  if ((p.bg || p.bgAlpha != null || p.grad) && bg) {
    const a = (p.bgAlpha ?? 100) / 100;
    if (p.grad) d.push(`background-color:transparent;background-image:linear-gradient(${p.gradAngle ?? 135}deg,${rgba(bg, a)},${rgba(p.grad, a)})`);
    else d.push(`background-color:${rgba(bg, a)}`);
  }
  if (p.color) d.push(`color:${p.color}`);
  if (p.radius != null) d.push(`border-radius:${p.radius}px`);
  if (p.size != null) d.push(`font-size:${p.size}px`);
  if (p.weight != null) d.push(`font-weight:${p.weight}`);
  if (p.padY != null) d.push(`padding-top:${p.padY}px;padding-bottom:${p.padY}px`);
  if (p.padX != null) d.push(`padding-left:${p.padX}px;padding-right:${p.padX}px`);
  if (p.shY != null || p.shBlur != null || p.shAlpha != null || p.shColor) {
    d.push(`filter:drop-shadow(0 ${p.shY ?? 4}px ${p.shBlur ?? 12}px ${rgba(p.shColor ?? '#17251d', (p.shAlpha ?? 25) / 100)})`);
  }
  if (p.opacity != null) d.push(`opacity:${p.opacity / 100}`);
  if (p.blur) d.push(`backdrop-filter:blur(${p.blur}px);-webkit-backdrop-filter:blur(${p.blur}px)`);
  if (p.bw) d.push(`border:${p.bw}px solid ${p.bc ?? '#7d897c'};box-sizing:border-box`);
  if (p.w != null) d.push(`width:${p.w}px;min-width:${p.w}px;max-width:${p.w}px;flex:none`);
  if (p.h != null) d.push(`height:${p.h}px;min-height:${p.h}px;max-height:${p.h}px`);
  if (p.mY != null) d.push(`margin-top:${p.mY}px;margin-bottom:${p.mY}px`);
  if (p.mX != null) d.push(`margin-left:${p.mX}px;margin-right:${p.mX}px`);
  if (p.alignX || p.alignY) {
    const flex = /flex|grid/.test(base?.display || '');
    const col = base?.col;
    if (!flex) d.push('display:flex');
    if (col) d.push('flex-direction:column');
    if (p.alignX) d.push(`${col ? 'align-items' : 'justify-content'}:${p.alignX}`);
    if (p.alignY) d.push(`${col ? 'justify-content' : 'align-items'}:${p.alignY}`);
  }
  if (p.scale != null || p.rot != null || p.iRot || p.iFlip) {
    d.push(`transform:scale(${(p.scale ?? 100) / 100}) rotate(${(p.rot ?? 0) + (p.iRot ?? 0)}deg)${p.iFlip ? ' scaleX(-1)' : ''}`);
  }
  if (p.iStroke != null) d.push(`--icon-stroke:${p.iStroke}`);
  if (p.tracking != null) d.push(`letter-spacing:${p.tracking}px`);
  if (p.caps) d.push('text-transform:uppercase');
  if (p.anim) d.push(`animation:lab-${p.anim} ${p.dur ?? 1.4}s ease-in-out infinite${st.pause ? ';animation-play-state:paused' : ''}`);
  if (p.hover || p.press) d.push('transition:transform .18s ease,filter .18s ease,opacity .18s ease');
  return d.join(';');
}

function childRules(target, p) {
  let css = '';
  const rule = (kids, decls) => {
    if (!decls.length) return;
    css += kids.split(',').map(k => `${target} ${k}`).join(',') + `{${important(decls.join(';'))}}`;
  };
  rule(CHILD.lab, [p.labColor && `color:${p.labColor}`, p.labSize != null && `font-size:${p.labSize}px`, p.labWeight != null && `font-weight:${p.labWeight}`].filter(Boolean));
  rule(CHILD.sub, [p.subColor && `color:${p.subColor}`, p.subSize != null && `font-size:${p.subSize}px`].filter(Boolean));
  rule(CHILD.ico, [p.icoColor && `color:${p.icoColor}`, p.icoSize != null && `width:${p.icoSize}px;height:${p.icoSize}px`].filter(Boolean));
  if (p.color) css += `${target} .label,${target} .title,${target} .text{color:inherit !important}`;
  return css;
}

const partBase = {}; // part key -> the colours it had when first clicked

const STATE_SELECTORS = {
  hover: [':hover'], press: [':active'], focus: [':focus-visible', ':focus-within'],
  disabled: [':disabled', '[aria-disabled="true"]'], selected: ['[aria-selected="true"]', '[aria-pressed="true"]'],
  error: ['[aria-invalid="true"]', '.error'],
};
const STATE_LABELS = [['', 'Normal'], ['hover', 'Hovring'], ['press', 'Tryck'], ['focus', 'Fokus'], ['disabled', 'Inaktiv'], ['selected', 'Vald'], ['error', 'Fel']];

function partsCss(st, scope) {
  let css = '';
  for (const [key, { sel, mode, props, view, state }] of Object.entries(st.parts)) {
    const phone = view != null ? `${MODE_SCOPE[mode]}[data-view="${view}"]` : MODE_SCOPE[mode];
    const base = scoped(sel === '.phone' ? phone : `${phone} ${sel}`, scope);
    const targets = state ? [...STATE_SELECTORS[state].map(x => base + x), `${base}[data-lab-state="${state}"]`] : [base];
    const decls = declsFor(st, props, partBase[key]);
    if (decls) css += `${targets.join(',')}{${important(decls)}}`;
    if (!state && props.hover) css += `${base}:hover{${important(HOVER_CSS[props.hover])}}`;
    if (!state && props.press) css += `${base}:active{${important(PRESS_CSS[props.press])}}`;
    for (const t of targets) css += childRules(t, props);
  }
  return css;
}

function buildCss(st, scope = '') {
  const byRule = new Map();
  for (const hex of used.keys()) {
    const to = finalColor(st, hex);
    if (to === hex) continue;
    for (const { selector, name } of used.get(hex)) {
      const sel = scoped(selector, scope);
      byRule.set(sel, (byRule.get(sel) || '') + `${name}:${to};`);
    }
  }
  let css = scope === '.cmpB' ? '' : KEYFRAMES;
  for (const [sel, body] of byRule) css += `${sel}{${body}}`;
  const typeVars = [];
  for (const [role, px] of sizes) {
    const own = st.roles[role]?.size;
    const size = own ?? px * st.scale / 100;
    if (own != null || st.scale !== 100) typeVars.push(`--butlery-type-${role}-size:${+size.toFixed(2)}px`);
  }
  for (const [role, w] of weights) {
    const own = st.roles[role]?.weight;
    if (own != null && own !== w) typeVars.push(`--butlery-type-${role}-weight:${own}`);
  }
  if (typeVars.length) css += `${scoped(':root', scope)}{${typeVars.join(';')}}`;
  if (st.font !== 'ButlerySans') css += `${scoped('.phone', scope)},${scoped('.phone *', scope)}{font-family:'${st.font}',sans-serif !important}`;
  if (st.fontHead) css += `${scoped('.phone .t-display,.phone .t-display-compact,.phone .t-title,.phone .t-stat,.phone .t-card-title', scope)}{font-family:'${st.fontHead}',sans-serif !important}`;
  if (st.lh !== 100) css += `${scoped('.phone *', scope)}{line-height:${st.lh / 100} !important}`;
  if (st.margin !== 24) css += `${scoped('.phone', scope)}{--page-margin:${st.margin}px}`;
  for (const { selector, px } of radii) {
    css += `${scoped(selector, scope)}{border-radius:${px === '12px' ? st.card : st.control}px}`;
  }
  return css + extraCss(st, scope) + freeCss(st, scope) + partsCss(st, scope);
}
// Free moves: a part's margins, so its neighbours make room for it and the spacing follows.
function freeCss(st, scope) {
  let css = '';
  for (const [id, f] of Object.entries(st.free || {})) {
    css += `${scoped(`.phone [data-lab-id="${id}"]`, scope)}{margin-left:${f.ml}px !important;margin-top:${f.mt}px !important}`;
  }
  return css;
}

const PART_LABELS = { lab: 'rubrik/text', sub: 'underrubrik/värde', ico: 'ikon' };
function summary(st) {
  const out = {};
  const colors = {};
  for (const hex of used.keys()) {
    const to = finalColor(st, hex);
    if (to === hex) continue;
    const names = paletteNames.get(hex) || used.get(hex).slice(0, 3).map(u => u.name.replace('--butlery-', ''));
    colors[names.join(' / ')] = { from: hex, to };
  }
  if (Object.keys(colors).length) out.colors = colors;
  if (st.font !== 'ButlerySans') out.fontFamily = st.font;
  if (st.fontHead) out.headingFont = st.fontHead;
  if (st.typeRatio) out.typeScaleRatio = +st.typeRatio;
  if (st.scale !== 100) out.textScalePercent = st.scale;
  if (st.lh !== 100) out.lineHeight = st.lh / 100;
  const roles = {};
  for (const [role, r] of Object.entries(st.roles)) {
    if (r.size != null && r.size !== sizes.get(role)) (roles[role] ||= {}).sizePx = r.size;
    if (r.weight != null && r.weight !== weights.get(role)) (roles[role] ||= {}).weight = r.weight;
  }
  if (Object.keys(roles).length) out.textRoles = roles;
  if (st.card !== 12) out.radiusCard = st.card;
  if (st.control !== 8) out.radiusControl = st.control;
  if (st.margin !== 24) out.pageMargin = st.margin;
  spaceSummary(st, out);
  layoutSummary(st, out);
  modularitySummary(st, out);
  const notes = (st.notes || []).filter(n => n.text.trim());
  if (notes.length) out.anteckningar = notes.map(n => `${n.label}: ${n.text.trim()}`);
  const parts = Object.values(st.parts).filter(p => Object.keys(p.props).length);
  if (parts.length) out.components = parts.map(p => ({ selector: p.sel, mode: p.mode, ...(p.state && { state: p.state }), ...p.props }));
  return Object.keys(out).length ? JSON.stringify(out, null, 2) : '';
}

// Undo history: a snapshot is taken shortly after the last change, so a drag is one step.
const undoLog = { stack: [JSON.stringify(state)], i: 0, restoring: false, timer: 0 };
function snapshot() {
  const s = JSON.stringify(state);
  if (s === undoLog.stack[undoLog.i]) return;
  undoLog.stack.length = undoLog.i + 1;
  undoLog.stack.push(s);
  undoLog.i++;
  if (undoLog.stack.length > 100) { undoLog.stack.shift(); undoLog.i--; }
  updateHistoryButtons();
}
function scheduleSnapshot() {
  if (undoLog.restoring) return;
  clearTimeout(undoLog.timer);
  undoLog.timer = setTimeout(snapshot, 350);
}
function stepHistory(dir) {
  clearTimeout(undoLog.timer);
  snapshot();
  const next = undoLog.i + dir;
  if (next < 0 || next >= undoLog.stack.length) return;
  undoLog.i = next;
  undoLog.restoring = true;
  state = { ...defaults(), ...JSON.parse(undoLog.stack[undoLog.i]) };
  syncUi();
  undoLog.restoring = false;
  updateHistoryButtons();
}
