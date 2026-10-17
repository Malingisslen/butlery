'use strict';
// Click a part of a screen to edit just that part (a component class). The editor is grouped
// into folds; text, sub text and icons inside the part have their own groups.

// [key, label, type, lo, hi, fallback, step]; a type of 'px', '%', '°' or 's' draws a slider.
const PART_GROUPS = [
  ['Färg', [
    ['bg', 'Bakgrund', 'color'], ['color', 'Textfärg', 'color'],
  ]],
  ['Ruta: storlek och placering', [
    ['w', 'Bredd', 'px', 8, 360, 48], ['h', 'Höjd', 'px', 8, 400, 48],
    ['alignX', 'Innehållet vågrätt', 'sel', [['', 'Som nu'], ['flex-start', 'Vänster'], ['center', 'Mitten'], ['flex-end', 'Höger']]],
    ['alignY', 'Innehållet lodrätt', 'sel', [['', 'Som nu'], ['flex-start', 'Upptill'], ['center', 'Mitten'], ['flex-end', 'Nedtill']]],
    ['mY', 'Marginal upp/ner', 'px', -16, 48, 0], ['mX', 'Marginal sidor', 'px', -16, 48, 0],
  ]],
  ['Form, text och luft', [
    ['radius', 'Rundning', 'px', 0, 40], ['size', 'Textstorlek', 'px', 8, 44],
    ['weight', 'Tyngd', 'sel', [[400, '400'], [600, '600'], [700, '700']]],
    ['padY', 'Luft upp/ner', 'px', 0, 40], ['padX', 'Luft sidor', 'px', 0, 40],
    ['scale', 'Storlek', '%', 70, 140, 100], ['rot', 'Lutning', '°', -15, 15, 0],
    ['tracking', 'Teckenavstånd', 'px', -1, 6, 0], ['caps', 'Versaler', 'check'],
  ]],
  ['Skugga', [
    ['shY', 'Höjd', 'px', -12, 32, 4], ['shBlur', 'Mjukhet', 'px', 0, 60, 12],
    ['shAlpha', 'Styrka', '%', 0, 80, 25], ['shColor', 'Färg', 'color', 0, 0, '#17251d'],
  ]],
  ['Genomskinlighet och glas', [
    ['opacity', 'Hela delen', '%', 10, 100, 100], ['bgAlpha', 'Bakgrunden', '%', 0, 100, 100],
    ['blur', 'Sudda bakom (glas)', 'px', 0, 30, 0],
  ]],
  ['Kant och toning', [
    ['bw', 'Kantlinje', 'px', 0, 6, 0], ['bc', 'Kantfärg', 'color', 0, 0, '#7d897c'],
    ['grad', 'Toning till', 'color', 0, 0, '#ce7c1e'], ['gradAngle', 'Toningens vinkel', '°', 0, 360, 135],
  ]],
  ['Rörelse', [
    ['anim', 'Animation', 'sel', ANIMS], ['dur', 'Animationstid', 's', 0.3, 4, 1.4, 0.1],
    ['hover', 'Vid hovring', 'sel', HOVERS], ['press', 'Vid tryck', 'sel', PRESSES],
  ]],
  ['Rubrik och text inne i delen', [
    ['labColor', 'Färg', 'color', 0, 0, '#24382c'], ['labSize', 'Storlek', 'px', 8, 40, 14],
    ['labWeight', 'Tyngd', 'sel', [[400, '400'], [600, '600'], [700, '700']]],
  ], '.label,.title,.text'],
  ['Underrubrik och värde', [
    ['subColor', 'Färg', 'color', 0, 0, '#627061'], ['subSize', 'Storlek', 'px', 8, 30, 12],
  ], '.subtitle,.value'],
  ['Den här ikonen', [
    ['iStroke', 'Linjetjocklek', 'px', 0.5, 3.5, 1.75, 0.25], ['iRot', 'Vrid', '°', 0, 345, 0, 15],
    ['iFlip', 'Spegelvänd', 'check'],
    ['lib', 'Bibliotek för just den här', 'sel', [['', 'Följ Ikoner-fliken'], ...ICON_LIB_OPTIONS]],
  ], null, 'svg.i'],
  ['Ikoner inne i delen', [
    ['icoColor', 'Färg', 'color', 0, 0, '#24382c'], ['icoSize', 'Storlek', 'px', 12, 48, 24],
  ], 'svg.i,.i'],
];

const toHex = c => {
  const m = c.match(/[\d.]+/g)?.map(Number);
  if (!m || m.length < 3 || (m.length > 3 && m[3] === 0)) return null;
  return '#' + m.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
};
let selected = null;
function markMatches(sel, view, keep) {
  if (!keep) document.querySelectorAll('[data-lab-match]').forEach(n => n.removeAttribute('data-lab-match'));
  if (sel === '.phone') return { n: 0, views: 0 };
  let list = [];
  try { list = [...document.querySelectorAll(`#screens .phone ${sel}`)]; } catch { /* a selector the browser refuses matches nothing */ }
  if (view != null) list = list.filter(n => n.closest('.phone').dataset.view == view);
  list.forEach(n => n.setAttribute('data-lab-match', ''));
  const light = list.filter(n => n.closest('.phone').dataset.theme !== 'dark');
  return { n: light.length, views: new Set(light.map(n => n.closest('.phone').dataset.view)).size };
}
// Shows the picked state on the picked parts, so a state that never occurs in the examples can still be seen.
function forceState(st) {
  document.querySelectorAll('[data-lab-state]').forEach(n => n.removeAttribute('data-lab-state'));
  if (!st) return;
  document.querySelectorAll('[data-lab-match],[data-lab-selected]').forEach(n => n.setAttribute('data-lab-state', st));
}
function clearSelection() {
  document.querySelectorAll('[data-lab-state]').forEach(n => n.removeAttribute('data-lab-state'));
  document.querySelectorAll('.lab-handles').forEach(n => n.remove());
  document.querySelectorAll('[data-lab-match]').forEach(n => n.removeAttribute('data-lab-match'));
  document.querySelectorAll('[data-lab-selected]').forEach(e => e.removeAttribute('data-lab-selected'));
  selected = null;
  showPartHint();
}
// Anything inside a screen can be picked; a second click on the picked part picks the one around it.
const isLab = e => [...e.classList].some(c => c.startsWith('lab-'));
function componentOf(el) {
  if (!el?.closest || !el.closest('.phone') || isLab(el)) return null;
  const e = el.closest('svg') || el;
  if (e.classList.contains('b-scroll')) return componentOf(e.parentElement);
  return e;
}
function parentPart(el) {
  let p = el.parentElement;
  while (p && p.closest('.phone') && (p.classList.contains('b-scroll') || (!p.classList.contains('phone') && !p.className && !p.getAttribute('style')))) p = p.parentElement;
  return p && p.closest('.phone') ? p : el;
}
function selectorFor(el, variant) {
  if (el.classList.contains('phone')) return '.phone';
  if (el.dataset.glyph && !el.classList.contains('b-icon')) return `svg[data-glyph="${el.dataset.glyph}"]` + (variant ? [...el.classList].filter(c => !c.startsWith('lab-')).map(c => '.' + c).join('') : '');
  if (el.dataset.labKind) return `[data-lab-kind="${el.dataset.labKind}"]`;
  const classes = [...el.classList].filter(c => !c.startsWith('lab-') && c !== 'lab-selected');
  const base = classes.find(c => c.startsWith('b-'));
  if (base) return '.' + base + (variant ? classes.filter(c => c !== base).map(c => '.' + c).join('') : '');
  let anchor = el.parentElement;
  while (anchor && !anchor.classList.contains('phone') && ![...anchor.classList].some(c => c.startsWith('b-') && c !== 'b-scroll')) anchor = anchor.parentElement;
  const prefix = !anchor || anchor.classList.contains('phone') ? '.phone' : selectorFor(anchor, false);
  const tag = el.tagName.toLowerCase();
  if (!classes.length) return `${prefix} ${tag}:nth-child(${[...el.parentElement.children].indexOf(el) + 1})`;
  return `${prefix} ${tag}.${classes[0]}` + (variant ? classes.slice(1).map(c => '.' + c).join('') : '');
}
function showPartHint() {
  $('part').innerHTML = '<p class="hint">Klicka på vad som helst i skärmarna, till exempel en flik, en ikon, en text eller en knapp, så kan du justera just den delen här. Klicka igen på samma del för att välja delen runt omkring. Håll in Ctrl eller Skift när du klickar för att välja flera delar på en gång.</p>';
}

function control(part, spec, now, keyword, onSet) {
  const [k, label, type, lo, hi, fallback, step] = spec;
  const cur = part.props[k] ?? now[k] ?? fallback;
  const l = document.createElement('label');
  l.dataset.kw = `${label} ${keyword}`.toLowerCase();
  const s = document.createElement('span'); s.textContent = label;
  let input;
  if (type === 'color') {
    if (!cur) return null;
    input = document.createElement('input');
    input.type = 'color'; input.value = cur;
    input.oninput = () => onSet(k, input.value);
    l.append(s, input, paletteButton(input, v => onSet(k, v)));
  } else if (type === 'sel') {
    input = document.createElement('select');
    for (const o of lo) input.add(Array.isArray(o) ? new Option(o[1], o[0]) : new Option(o, o));
    input.value = part.props[k] ?? now[k] ?? '';
    input.onchange = () => onSet(k, input.value === '' || isNaN(+input.value) ? input.value : +input.value);
    l.append(s, input);
  } else if (type === 'check') {
    input = document.createElement('input');
    input.type = 'checkbox'; input.checked = !!part.props[k];
    input.onchange = () => onSet(k, input.checked);
    l.append(input, s);
  } else {
    input = document.createElement('input');
    input.type = 'range'; input.min = lo; input.max = hi; input.step = step ?? 1; input.value = cur;
    const v = document.createElement('span'); v.className = 'val'; v.textContent = `${cur} ${type}`;
    input.oninput = () => { v.textContent = `${input.value} ${type}`; onSet(k, +input.value); };
    l.append(s, input, v);
  }
  return l;
}

function partFor(el, variant) {
  let sel = selectorFor(el, variant), base = selectorFor(el, false);
  if (selected.onlyThis && el.dataset.labId && sel !== '.phone') sel = base = `[data-lab-id="${el.dataset.labId}"]`;
  const view = selected.onlyView ? +el.closest('.phone').dataset.view : null;
  const st = selected.state || '';
  const key = `${selected.mode}|${view != null ? `v${view}|` : ''}${sel}${st ? `|@${st}` : ''}`;
  const part = state.parts[key] ||= { sel, mode: selected.mode, props: {}, ...(view != null ? { view } : {}), ...(st ? { state: st } : {}) };
  return { el, sel, base, view, key, part };
}
// Every glyph of the app, searchable, to swap the picked icon (and its like) for another.
function glyphPicker(parts, part, done) {
  const wrap = document.createElement('details');
  wrap.open = false;
  const sm = document.createElement('summary'); sm.textContent = 'Byt ikon';
  const search = document.createElement('input');
  search.type = 'search'; search.placeholder = 'Sök ikon, till exempel stjärna';
  const grid = document.createElement('div');
  grid.className = 'glyph-grid';
  const names = [...document.querySelectorAll('#butlery-icons symbol')].map(s => s.id.replace('i-', ''));
  const fill = () => {
    grid.textContent = '';
    const q = search.value.trim().toLowerCase();
    const list = names.filter(n => !q || n.includes(q) || (ICON_WORDS[n] || '').includes(q));
    for (const n of list) {
      const b = document.createElement('button');
      b.type = 'button'; b.title = n; b.className = 'ghost' + (part.props.glyph === n ? ' on' : '');
      b.innerHTML = `<svg class="i"><use href="#i-${n}"></use></svg>`;
      b.onclick = () => { for (const p of parts) p.props.glyph = n; done(); };
      grid.append(b);
    }
    if (!list.length) grid.textContent = 'Ingen ikon hittades.';
  };
  search.oninput = fill;
  fill();
  const reset = document.createElement('button');
  reset.type = 'button'; reset.className = 'ghost'; reset.textContent = 'Tillbaka till originalikonen';
  reset.onclick = () => { for (const p of parts) delete p.props.glyph; done(); };
  wrap.append(sm, search, grid, reset);
  return wrap;
}
// Light and dark are kept together: everything but colours is copied to the same part in the
// other theme as soon as it changes; a colour is copied only after the user said yes (selected.follow).
const COLOR_KEYS = new Set(PART_GROUPS.flatMap(g => g[1]).filter(sp => sp[2] === 'color').map(sp => sp[0]));
const otherMode = m => (m === 'light' ? 'dark' : 'light');
const modeWord = m => (m === 'light' ? 'ljust' : 'mörkt');
function twinEl(el, mode) {
  const id = el.dataset.labId;
  if (!id) return null;
  return [...document.querySelectorAll(`#screens [data-lab-id="${id}"]`)].find(n => (n.closest('.phone')?.dataset.theme === 'dark') === (mode === 'dark')) || null;
}
function mirrorThemes() {
  if (!selected?.keys) return;
  selected.keys.forEach((key, i) => {
    const part = selected.parts[i];
    if (!part || state.parts[key] !== part || part.mode === 'both') return;
    const carry = k => !COLOR_KEYS.has(k) || selected.follow?.[k];
    const next = Object.fromEntries(Object.entries(part.props).filter(([k]) => carry(k)));
    const sig = JSON.stringify(next);
    selected.sigs ||= {};
    if (selected.sigs[key] === sig) return;
    selected.sigs[key] = sig;
    const other = otherMode(part.mode), key2 = other + key.slice(part.mode.length);
    let twin = state.parts[key2];
    if (!twin) {
      if (!Object.keys(next).length) return;
      twin = state.parts[key2] = { ...part, mode: other, props: {} };
    }
    for (const k of Object.keys(twin.props)) if (carry(k) && !(k in next)) delete twin.props[k];
    Object.assign(twin.props, next);
    if (!Object.keys(twin.props).length) delete state.parts[key2];
    else if (!partBase[key2]) {
      const t = twinEl(selected.el, other);
      if (t) { const c = getComputedStyle(t); partBase[key2] = { bg: toHex(c.backgroundColor), display: c.display, col: c.flexDirection.startsWith('column') }; }
    }
  });
}
function clearTwins(keys) {
  for (const key of keys) {
    const mode = key.split('|')[0];
    if (mode === 'both') continue;
    const twin = state.parts[otherMode(mode) + key.slice(mode.length)];
    if (!twin) continue;
    for (const k of Object.keys(twin.props)) if (!COLOR_KEYS.has(k)) delete twin.props[k];
    if (!Object.keys(twin.props).length) delete state.parts[otherMode(mode) + key.slice(mode.length)];
  }
}
function drawAsk() {
  const box = $('theme-ask');
  if (!box) return;
  box.textContent = '';
  box.className = '';
  const k = selected?.ask, mode = selected?.part?.mode;
  if (!k || !mode || mode === 'both') return;
  const other = otherMode(mode);
  const p = document.createElement('p');
  p.textContent = `Du ändrade en färg i ${modeWord(mode)} läge. Ska motsvarande färg ändras i ${modeWord(other)} läge också?`;
  const row = document.createElement('div'); row.className = 'row';
  const btn = (label, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'ghost'; b.textContent = label; b.onclick = fn; row.append(b); };
  const close = follow => { (selected.follow ||= {})[k] = follow; selected.ask = null; };
  btn('Ja, samma färg', () => { close(true); render(); drawAsk(); });
  btn(`Ja, välj själv i ${modeWord(other)}`, () => {
    close(false);
    const t = twinEl(selected.el, other);
    if (!t) { drawAsk(); return; }
    document.querySelectorAll('[data-lab-selected]').forEach(n => n.removeAttribute('data-lab-selected'));
    t.setAttribute('data-lab-selected', '');
    selected.el = t; selected.extras = []; selected.mode = other;
    showPart(false);
  });
  btn(`Nej, bara ${modeWord(mode)}`, () => { close(false); drawAsk(); });
  box.className = 'themeask';
  box.append(p, row);
}
function showPart(variant = false) {
  const el = selected.el, box = $('part');
  selected.mode ||= el.closest('.phone').dataset.theme === 'dark' ? 'dark' : 'light';
  selected.extras = (selected.extras || []).filter(x => x.isConnected);
  const targets = [el, ...selected.extras].map(x => partFor(x, variant));
  const { sel, base, view, key, part } = targets[0];
  selected.part = part;
  selected.parts = targets.map(t => t.part);
  selected.keys = targets.map(t => t.key);
  selected.sigs ||= {};
  for (const t of targets) selected.sigs[t.key] ??= JSON.stringify(Object.fromEntries(Object.entries(t.part.props).filter(([k]) => !COLOR_KEYS.has(k) || selected.follow?.[k])));
  const cs = getComputedStyle(el);
  const kid = q => el.querySelector(q);
  const now = {
    bg: toHex(cs.backgroundColor), color: toHex(cs.color), radius: parseFloat(cs.borderTopLeftRadius) || 0,
    size: parseFloat(cs.fontSize), weight: +cs.fontWeight, padY: parseFloat(cs.paddingTop), padX: parseFloat(cs.paddingLeft),
    w: Math.round(el.getBoundingClientRect().width), h: Math.round(el.getBoundingClientRect().height),
  };
  const read = (q, map) => {
    const k = kid(q);
    if (!k) return;
    const c = getComputedStyle(k);
    for (const [name, v] of Object.entries(map(c))) now[name] = v;
  };
  read('.label,.title,.text', c => ({ labColor: toHex(c.color), labSize: parseFloat(c.fontSize), labWeight: +c.fontWeight }));
  read('.subtitle,.value', c => ({ subColor: toHex(c.color), subSize: parseFloat(c.fontSize) }));
  read('svg.i,.i', c => ({ icoColor: toHex(c.color), icoSize: parseFloat(c.width) || 24 }));
  for (const t of targets) {
    const c = getComputedStyle(t.el);
    partBase[t.key] ||= { bg: toHex(c.backgroundColor), display: c.display, col: c.flexDirection.startsWith('column') };
  }

  box.textContent = '';
  const head = document.createElement('div');
  head.innerHTML = '<div class="path"></div>';
  head.firstChild.textContent = `${sel} · ${now.w} × ${now.h} px`;
  box.append(head);
  const seg = document.createElement('div');
  seg.className = 'seg';
  for (const [m, label] of [['light', 'Ljust'], ['dark', 'Mörkt'], ['both', 'Båda']]) {
    const b = document.createElement('button');
    b.type = 'button'; b.textContent = label; b.className = 'ghost' + (selected.mode === m ? ' on' : '');
    b.onclick = () => { selected.mode = m; showPart(variant); };
    seg.append(b);
  }
  box.append(seg);
  const askBox = document.createElement('div'); askBox.id = 'theme-ask';
  box.append(askBox);
  const tnote = document.createElement('p'); tnote.className = 'hint';
  tnote.textContent = 'Allt utom färger ändras i både ljust och mörkt. Färger gäller bara läget du står i, och du får en fråga om det andra.';
  box.append(tnote);
  const stateRow = document.createElement('label');
  const stateName = document.createElement('span'); stateName.textContent = 'Tillstånd';
  const stateSel = document.createElement('select');
  for (const [v, l] of STATE_LABELS) stateSel.add(new Option(l, v));
  stateSel.value = selected.state || '';
  stateSel.onchange = () => { selected.state = stateSel.value; showPart(variant); };
  stateRow.append(stateName, stateSel);
  box.append(stateRow);
  if (selected.state) {
    const hint = document.createElement('p'); hint.className = 'hint';
    hint.textContent = 'Det du ändrar nu gäller bara när delen är i det här tillståndet. Delarna visas i tillståndet så länge du står här.';
    box.append(hint);
  }
  let found = { n: 0, views: 0 };
  targets.forEach((t, i) => {
    const f = markMatches(t.sel, t.view, i > 0);
    found = { n: found.n + f.n, views: Math.max(found.views, f.views) };
  });
  if (targets.length > 1) {
    const info = document.createElement('p');
    info.className = 'hint';
    info.textContent = `${targets.length} delar är valda och ändras tillsammans. Håll in Ctrl eller Skift och klicka på en vald del för att ta bort den ur urvalet.`;
    box.append(info);
  }
  if (found.n) {
    const info = document.createElement('p');
    info.className = 'hint';
    info.textContent = `Ändringen gäller ${found.n} likadana delar i ${found.views} ${found.views === 1 ? 'vy' : 'vyer'} (markerade med rosa ram).`;
    box.append(info);
  }
  if (el.dataset.labId && !el.classList.contains('phone')) {
    const l = document.createElement('label');
    const c = document.createElement('input');
    c.type = 'checkbox'; c.checked = !!selected.onlyThis; c.onchange = () => { selected.onlyThis = c.checked; showPart(variant); };
    const s = document.createElement('span'); s.textContent = 'Bara vald del (inte de likadana)';
    l.append(c, s); box.append(l);
  }
  if (sel !== '.phone' && !selected.onlyThis) {
    const l = document.createElement('label');
    const c = document.createElement('input');
    c.type = 'checkbox'; c.checked = !!selected.onlyView; c.onchange = () => { selected.onlyView = c.checked; showPart(variant); };
    const s = document.createElement('span'); s.textContent = 'Bara i den här vyn';
    l.append(c, s); box.append(l);
  }
  if (sel !== base) {
    const l = document.createElement('label');
    const c = document.createElement('input');
    c.type = 'checkbox'; c.checked = variant; c.onchange = () => showPart(c.checked);
    const s = document.createElement('span'); s.textContent = 'Bara just den här varianten';
    l.append(c, s); box.append(l);
  }
  const warn = document.createElement('details');
  warn.open = true;
  const wsum = document.createElement('summary'); wsum.textContent = 'Kontroll av det du valt';
  const wbox = document.createElement('div'); wbox.id = 'part-warn';
  warn.append(wsum, wbox);
  box.append(warn);
  const onSet = (k, v) => {
    for (const p of selected.parts) if (v === '' || v === false) delete p.props[k]; else p.props[k] = v;
    if (COLOR_KEYS.has(k) && v !== '' && v !== false && part.mode !== 'both' && selected.follow?.[k] === undefined) selected.ask = k;
    render();
    drawAsk();
    refreshPartWarn(() => showPart(variant));
  };
  if (el.matches('svg.i')) box.append(glyphPicker(selected.parts, part, () => { render(); showPart(variant); }));
  PART_GROUPS.forEach(([title, specs, childQuery, selfQuery], i) => {
    if (childQuery && !kid(childQuery)) return;
    if (selfQuery && !el.matches(selfQuery)) return;
    const d = document.createElement('details');
    d.open = i < 2 || !!selfQuery || specs.some(s => part.props[s[0]] != null);
    const sm = document.createElement('summary'); sm.textContent = title;
    d.append(sm);
    for (const spec of specs) {
      const c = control(part, spec, now, title, onSet);
      if (c) d.append(c);
    }
    box.append(d);
  });
  const r = document.createElement('div');
  r.className = 'row';
  for (const [label, fn] of [['Nollställ delen', () => { clearTwins(targets.map(t => t.key)); for (const t of targets) delete state.parts[t.key]; render(); showPart(variant); }], ['Avmarkera', clearSelection]]) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'ghost'; b.textContent = label; b.onclick = fn; r.append(b);
  }
  box.append(r);
  const note = document.createElement('p');
  note.className = 'hint';
  note.textContent = 'Skuggor, glas och rörelse finns inte i appens regler idag; med minskad rörelse ska appen visa dem stilla.';
  box.append(note);
  applySearch();
  drawAsk();
  render();
  refreshPartWarn(() => showPart(variant));
  forceState(selected.state);
}

// Word-style frame around the picked part: dragging a handle sets its width and height, for every like part.
function drawHandles() {
  document.querySelectorAll('.lab-handles').forEach(n => n.remove());
  if (!selected?.el.isConnected || drag?.started || typeof compare !== 'undefined' && compare) return;
  const phone = selected.el.closest('.phone');
  if (!phone) return;
  const base = phone.getBoundingClientRect(), r = selected.el.getBoundingClientRect();
  const box = document.createElement('div');
  box.className = 'lab-handles';
  box.style.cssText = `left:${r.left - base.left}px;top:${r.top - base.top}px;width:${r.width}px;height:${r.height}px`;
  for (const h of ['nw', 'n', 'ne', 'e', 'se', 's', 'sw', 'w']) {
    const d = document.createElement('i');
    d.className = `lab-h lab-h-${h}`;
    d.dataset.h = h;
    box.append(d);
  }
  if (selected.el.dataset.labId && !selected.el.classList.contains('phone')) {
    const x = document.createElement('i');
    x.className = 'lab-cross';
    x.title = 'Dra för att flytta delen';
    x.innerHTML = '<svg viewBox="0 0 24 24"><path d="M12 2l3.5 3.5h-2.5v5.5h5.5v-2.5l3.5 3.5-3.5 3.5v-2.5h-5.5v5.5h2.5l-3.5 3.5-3.5-3.5h2.5v-5.5h-5.5v2.5l-3.5-3.5 3.5-3.5v2.5h5.5v-5.5h-2.5z"/></svg>';
    const left = r.left - base.left, top = r.top - base.top;
    x.style.cssText = `left:${Math.max(2, left - 26) - left}px;top:${Math.max(2, top - 26) - top}px`;
    box.append(x);
  }
  phone.append(box);
}
let resizing = null;
function wireHandles() {
  const screens = $('screens');
  screens.addEventListener('pointerdown', e => {
    const h = e.target.closest?.('.lab-h');
    if (!h || !selected?.part) return;
    e.preventDefault(); e.stopPropagation();
    const r = selected.el.getBoundingClientRect();
    resizing = { h: h.dataset.h, x: e.clientX, y: e.clientY, w: r.width, hh: r.height, part: selected.part };
  }, true);
  window.addEventListener('pointermove', e => {
    if (!resizing) return;
    const { h, part } = resizing, dx = e.clientX - resizing.x, dy = e.clientY - resizing.y;
    const clamp = v => Math.max(8, Math.min(360, Math.round(v)));
    for (const p of selected.parts || [part]) {
      if (h.includes('e')) p.props.w = clamp(resizing.w + dx);
      if (h.includes('w')) p.props.w = clamp(resizing.w - dx);
      if (h.includes('s')) p.props.h = clamp(resizing.hh + dy);
      if (h.includes('n')) p.props.h = clamp(resizing.hh - dy);
    }
    render();
  });
  window.addEventListener('pointerup', () => { if (resizing) { resizing = null; showPart(false); } });
  screens.addEventListener('scroll', () => drawHandles(), true);
}

function wireScreens() {
  const screens = $('screens');
  screens.addEventListener('click', e => {
    let el = componentOf(e.target);
    if (!el) return;
    e.preventDefault(); e.stopPropagation();
    if ((e.ctrlKey || e.shiftKey || e.metaKey) && selected?.el.isConnected) {
      if (el === selected.el) {
        if (selected.extras?.length) {
          el.removeAttribute('data-lab-selected');
          selected.el = selected.extras.shift();
        }
      } else if (selected.extras?.includes(el)) {
        selected.extras = selected.extras.filter(x => x !== el);
        el.removeAttribute('data-lab-selected');
      } else {
        (selected.extras ||= []).push(el);
        el.setAttribute('data-lab-selected', '');
      }
      showPart(false);
      return;
    }
    if (selected?.el.isConnected && selected.el.contains(e.target)) el = parentPart(selected.el);
    document.querySelectorAll('[data-lab-selected]').forEach(n => n.removeAttribute('data-lab-selected'));
    el.setAttribute('data-lab-selected', '');
    selected = { el, mode: null };
    openTab('part');
    showPart(false);
    adviceForPart(el);
  }, true);
  screens.addEventListener('mouseover', e => {
    screens.querySelectorAll('[data-lab-hover]').forEach(n => n.removeAttribute('data-lab-hover'));
    componentOf(e.target)?.setAttribute('data-lab-hover', '');
  });
  wireHandles();
  screens.addEventListener('mouseleave', () => screens.querySelectorAll('[data-lab-hover]').forEach(n => n.removeAttribute('data-lab-hover')));
}
