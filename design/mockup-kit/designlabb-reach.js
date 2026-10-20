'use strict';
// What the global controls reach in the example screens. The screens are drawn from the app's own views, so
// most of their text sizes, paddings and margins are plain px in view-specific classes and not the kit's
// .b-* ones. This file finds those once, before any lab CSS is applied, so a slider changes every screen.

const CARD = ':is(.b-card,.mr-card)';
const PAGE_MARGIN = 24;
// Rows whose height is fixed in the view's CSS: "air in rows" adds to the height instead of the padding.
const FIXED_ROWS = {};
const STATIC_FONT_SIZES = new Set();

// Text no type token drives is tagged with its own size; a size that does not move when every token is
// changed is not derived from one.
function tagStaticText() {
  const phones = [...document.querySelectorAll('#screens .phone')];
  const els = phones.flatMap(p => [p, ...p.querySelectorAll('*')])
    .filter(e => !e.closest('svg') && [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()));
  const read = () => els.map(e => getComputedStyle(e).fontSize);
  const base = read();
  const probe = new CSSStyleSheet();
  probe.replaceSync(`:root{${[...sizes.keys()].map(r => `--butlery-type-${r}-size:97px`).join(';')}}`);
  document.adoptedStyleSheets = [...document.adoptedStyleSheets, probe];
  const moved = read();
  document.adoptedStyleSheets = document.adoptedStyleSheets.filter(s => s !== probe);
  els.forEach((e, i) => {
    if (moved[i] !== base[i]) return;
    e.dataset.labFs = String(+parseFloat(base[i]).toFixed(2));
    STATIC_FONT_SIZES.add(e.dataset.labFs);
  });
}
function staticTextCss(k, scope) {
  if (k === 1) return '';
  let css = '';
  for (const px of STATIC_FONT_SIZES) css += `${scoped('.phone', scope)} [data-lab-fs="${px}"]{font-size:${+(px * k).toFixed(2)}px !important}`;
  return css;
}

// Full-width parts that pad themselves by the page margin, and parts inset by it, follow the margin slider.
function tagPageMargins() {
  const near = (a, b) => Math.abs(a - b) < 2;
  for (const phone of document.querySelectorAll('#screens .fig-light .phone')) {
    const box = phone.getBoundingClientRect();
    for (const e of phone.querySelectorAll('*')) {
      if (e.closest('svg') || !e.dataset.labId) continue;
      const c = getComputedStyle(e), r = e.getBoundingClientRect(), tags = [];
      if (near(r.width, box.width)) {
        if (parseFloat(c.paddingLeft) === PAGE_MARGIN) tags.push('pl');
        if (parseFloat(c.paddingRight) === PAGE_MARGIN) tags.push('pr');
      }
      if (parseFloat(c.marginLeft) === PAGE_MARGIN && near(r.left - box.left, PAGE_MARGIN)) tags.push('ml');
      if (parseFloat(c.marginRight) === PAGE_MARGIN && near(box.right - r.right, PAGE_MARGIN)) tags.push('mr');
      if (!tags.length) continue;
      for (const twin of document.querySelectorAll(`#screens [data-lab-id="${e.dataset.labId}"]`)) twin.dataset.labMargin = tags.join(' ');
    }
  }
}
function pageMarginCss(px, scope) {
  if (px === PAGE_MARGIN) return '';
  const rules = { pl: 'padding-left', pr: 'padding-right', ml: 'margin-left', mr: 'margin-right' };
  return Object.entries(rules).map(([tag, prop]) => `${scoped('.phone', scope)} [data-lab-margin~="${tag}"]{${prop}:${px}px !important}`).join('');
}

function measureFixedRows() {
  for (const cls of ['.ik-item', '.sk-item']) {
    const row = document.querySelector(`#screens .fig-light .phone ${cls}`);
    if (row) FIXED_ROWS[cls] = parseFloat(getComputedStyle(row).height);
  }
}

// Spacing set from inside a view belongs to that view. The first two screens are the same view (Hem and
// Mina recept share one file), so they follow each other; every other screen stands alone.
const LINKED_VIEWS = [[0, 1]];
const linkedViews = v => LINKED_VIEWS.find(g => g.includes(+v)) || [+v];
const sameView = (a, b) => linkedViews(a).includes(+b);
const VIEW_SPACE_KEYS = ['margin', 'sectionGap', 'rowPad', 'blockGap', 'chipGap', 'rowInner'];

function viewSpaceCss(st, scope) {
  let css = '';
  for (const [v, o] of Object.entries(st.viewSpace || {})) {
    const phone = `.phone[data-view="${v}"]`;
    const rule = (sel, decls) => `${scoped(sel.split(',').map(x => `${phone} ${x}`).join(','), scope)}{${important(decls)}}`;
    if (o.rowPad != null) {
      css += rule('.b-row,.mr-item', `padding-top:${o.rowPad}px;padding-bottom:${o.rowPad}px`);
      for (const [cls, h] of Object.entries(FIXED_ROWS)) css += rule(cls, `height:${+(h + 2 * (o.rowPad - 10)).toFixed(2)}px`);
    }
    if (o.sectionGap != null) {
      css += rule('.b-section', `padding-top:${o.sectionGap}px`);
      css += rule('.ik-sec,.sk-sec', `margin-top:${o.sectionGap}px`);
    }
    if (o.blockGap != null) css += rule('.b-body > * + *:not(.b-section)', `margin-top:${o.blockGap}px`);
    if (o.chipGap != null) css += rule('.b-chips,.b-btnrow,.b-field,.mr-chips', `gap:${o.chipGap}px`);
    if (o.rowInner != null) css += rule('.b-row,.mr-item,.ik-item,.sk-item', `gap:${o.rowInner}px`);
    if (o.margin != null) {
      css += `${scoped(phone, scope)}{--page-margin:${o.margin}px}`;
      for (const [tag, prop] of Object.entries({ pl: 'padding-left', pr: 'padding-right', ml: 'margin-left', mr: 'margin-right' })) {
        css += `${scoped(`${phone} [data-lab-margin~="${tag}"]`, scope)}{${prop}:${o.margin}px !important}`;
      }
    }
  }
  return css;
}
