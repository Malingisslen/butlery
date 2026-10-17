'use strict';
// Click a part of a screen to edit just that part (a component class). The editor is grouped
// into folds; text, sub text and icons inside the part have their own groups.

// [key, label, type, lo, hi, fallback, step]; a type of 'px', '%', '°' or 's' draws a slider.
const PART_GROUPS = [
  ['Färg', [
    ['bg', 'Bakgrund', 'color'], ['color', 'Textfärg', 'color'],
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
function clearSelection() {
  document.querySelectorAll('[data-lab-selected]').forEach(e => e.removeAttribute('data-lab-selected'));
  selected = null;
  showPartHint();
}
function componentOf(el) {
  for (let e = el; e && e.closest('.phone'); e = e.parentElement) {
    if ([...e.classList].some(c => c.startsWith('b-') && c !== 'b-scroll')) return e;
    if (e.classList.contains('phone')) return e;
  }
  return null;
}
function selectorFor(el, variant) {
  if (el.classList.contains('phone')) return '.phone';
  const classes = [...el.classList];
  const base = classes.find(c => c.startsWith('b-'));
  const rest = classes.filter(c => c !== base && !c.startsWith('lab-'));
  return '.' + base + (variant ? rest.map(c => '.' + c).join('') : '');
}
function showPartHint() {
  $('part').innerHTML = '<p class="hint">Klicka på en knapp, ett kort, en rad eller en ikon i skärmarna, så kan du justera just den delen här.</p>';
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
    l.append(s, input);
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

function showPart(variant = false) {
  const el = selected.el, box = $('part');
  const sel = selectorFor(el, variant), base = selectorFor(el, false);
  selected.mode ||= el.closest('.phone').dataset.theme === 'dark' ? 'dark' : 'light';
  const key = `${selected.mode}|${sel}`;
  const part = state.parts[key] ||= { sel, mode: selected.mode, props: {} };
  const cs = getComputedStyle(el);
  const kid = q => el.querySelector(q);
  const now = {
    bg: toHex(cs.backgroundColor), color: toHex(cs.color), radius: parseFloat(cs.borderTopLeftRadius) || 0,
    size: parseFloat(cs.fontSize), weight: +cs.fontWeight, padY: parseFloat(cs.paddingTop), padX: parseFloat(cs.paddingLeft),
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
  partBase[key] ||= { bg: now.bg };

  box.textContent = '';
  const head = document.createElement('div');
  head.innerHTML = '<div class="path"></div>';
  head.firstChild.textContent = sel;
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
  if (sel !== base) {
    const l = document.createElement('label');
    const c = document.createElement('input');
    c.type = 'checkbox'; c.checked = variant; c.onchange = () => showPart(c.checked);
    const s = document.createElement('span'); s.textContent = 'Bara just den här varianten';
    l.append(c, s); box.append(l);
  }
  const onSet = (k, v) => {
    if (v === '' || v === false) delete part.props[k]; else part.props[k] = v;
    render();
  };
  PART_GROUPS.forEach(([title, specs, childQuery], i) => {
    if (childQuery && !kid(childQuery)) return;
    const d = document.createElement('details');
    d.open = i < 2 || specs.some(s => part.props[s[0]] != null);
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
  for (const [label, fn] of [['Nollställ delen', () => { delete state.parts[key]; render(); showPart(variant); }], ['Avmarkera', clearSelection]]) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'ghost'; b.textContent = label; b.onclick = fn; r.append(b);
  }
  box.append(r);
  const note = document.createElement('p');
  note.className = 'hint';
  note.textContent = 'Skuggor, glas och rörelse finns inte i appens regler idag; med minskad rörelse ska appen visa dem stilla.';
  box.append(note);
  applySearch();
  render();
}

function wireScreens() {
  const screens = $('screens');
  screens.addEventListener('click', e => {
    if (moveMode) return;
    const el = componentOf(e.target);
    if (!el) return;
    e.preventDefault(); e.stopPropagation();
    document.querySelectorAll('[data-lab-selected]').forEach(n => n.removeAttribute('data-lab-selected'));
    el.setAttribute('data-lab-selected', '');
    selected = { el, mode: null };
    openTab('part');
    showPart(false);
  }, true);
  screens.addEventListener('mouseover', e => {
    if (moveMode) return;
    screens.querySelectorAll('[data-lab-hover]').forEach(n => n.removeAttribute('data-lab-hover'));
    componentOf(e.target)?.setAttribute('data-lab-hover', '');
  });
  screens.addEventListener('mouseleave', () => screens.querySelectorAll('[data-lab-hover]').forEach(n => n.removeAttribute('data-lab-hover')));
}

// Ready-made looks that touch many parts at once; each is still editable by clicking the part.
const EFFECTS = {
  'Skuggor på alla kort': [['.b-card', { shY: 6, shBlur: 18, shAlpha: 22 }]],
  'Glas på ark och dialoger': [['.b-sheet', { bgAlpha: 70, blur: 12, shY: 8, shBlur: 24, shAlpha: 25 }], ['.b-dialog', { bgAlpha: 70, blur: 12, shY: 8, shBlur: 24, shAlpha: 25 }]],
  'Knappar lyfter vid hovring': [['.b-btn', { hover: 'lift', press: 'sink' }]],
  'Hjälteknappen pulserar': [['.b-btn.hero', { anim: 'pulse', dur: 1.6 }]],
  'Glödande hjälteknapp': [['.b-btn.hero', { anim: 'glow', dur: 2 }]],
  'Svävande kort': [['.b-card', { anim: 'float', dur: 3.5, shY: 10, shBlur: 24, shAlpha: 18 }]],
  'Chips växer vid hovring': [['.b-chip', { hover: 'grow' }]],
  'Rader tonar vid hovring': [['.b-row', { hover: 'dim' }]],
  'Släck alla effekter': [],
};
function wireEffects() {
  for (const [name, list] of Object.entries(EFFECTS)) {
    const b = document.createElement('button');
    b.type = 'button'; b.textContent = name;
    b.onclick = () => {
      if (!list.length) state.parts = {};
      for (const [sel, props] of list) {
        const key = `both|${sel}`;
        state.parts[key] = { sel, mode: 'both', props: { ...(state.parts[key]?.props || {}), ...props } };
      }
      clearSelection();
      render();
    };
    $('effects').append(b);
  }
  $('pause').onchange = e => { state.pause = e.target.checked; render(); };
}
