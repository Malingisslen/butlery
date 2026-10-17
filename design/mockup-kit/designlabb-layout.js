'use strict';
// Drag and drop in the example screens: rows, sections, bands, buttons and chips can be moved
// to another place. A move is a record in state.moves, replayed on a pristine copy of the
// screens, so undo, saved variants and the shared link all carry the layout. The light and the
// dark copy of a screen share element ids, so a move happens in both. The picked part is moved
// with the cross at its corner (the move handle). Only the lab's own example
// screens change; the app is not touched.

let layoutBase = '';
let layoutApplied = '[]';
let freeMode = false;
let drag = null; // { el, x, y, started, plan }

const inSvg = el => !!el.parentElement?.closest('svg');
// Called once, before the dark copies are cloned, so both copies get the same ids.
function assignLayoutIds() {
  const kinds = new Map();
  document.querySelectorAll('#screens > figure').forEach((fig, f) => {
    let n = 0;
    fig.querySelector('.phone').dataset.view = f;
    fig.querySelectorAll('.phone, .phone *').forEach(el => {
      if (inSvg(el)) return;
      el.dataset.labId = `f${f}-${n++}`;
      // Parts that carry no class of their own are told apart by what they look like, so the same
      // star box or icon is the same part in every screen.
      if (el.tagName === 'svg') {
        const use = el.querySelector('use');
        if (use) el.dataset.glyph = use.getAttribute('href').replace('#i-', '');
      } else if (!el.classList.length && !el.classList.contains('phone')) {
        const sig = [el.tagName, el.getAttribute('style') || '', [...el.children].map(c => c.tagName + (c.querySelector?.('use')?.getAttribute('href') || '')).join(',')].join('|');
        if (!kinds.has(sig)) kinds.set(sig, 'k' + kinds.size);
        el.dataset.labKind = kinds.get(sig);
      }
    });
  });
  layoutBase = $('screens').innerHTML;
}
function snapshotLayoutBase() { layoutBase = $('screens').innerHTML; }

function labelOf(el) { return (el?.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 28) || el?.className?.baseVal || el?.className || el?.tagName || ''; }

function applyMove(m) {
  for (const fig of document.querySelectorAll('#screens > figure')) {
    const el = fig.querySelector(`[data-lab-id="${m.id}"]`);
    if (m.beside) {
      const tgt = fig.querySelector(`[data-lab-id="${m.beside}"]`);
      if (!el || !tgt || el.contains(tgt) || tgt.contains(el)) continue;
      let row = tgt.parentElement;
      if (!row.classList.contains('lab-row')) {
        row = document.createElement('div');
        row.className = 'lab-row';
        row.dataset.labId = `w-${m.beside}`;
        tgt.before(row);
        row.append(tgt);
      }
      if (m.side === 'left') row.insertBefore(el, tgt); else tgt.after(el);
      continue;
    }
    const to = fig.querySelector(`[data-lab-id="${m.to}"]`);
    if (!el || !to || el.contains(to)) continue;
    const before = m.before ? fig.querySelector(`[data-lab-id="${m.before}"]`) : null;
    to.insertBefore(el, before && before.parentElement === to ? before : null);
  }
}
const moveText = m => m.beside ? `"${m.label}" till ${m.side === 'left' ? 'vänster' : 'höger'} om "${m.besideLabel}"`
  : `"${m.label}" ${m.beforeLabel ? `före "${m.beforeLabel}"` : 'sist'} i ${m.toLabel}`;
// Rebuild the screens from the pristine copy and replay the moves, unless nothing changed.
function replayLayout(force) {
  const sig = JSON.stringify(state.moves || []);
  if (!force && sig === layoutApplied) return;
  $('screens').innerHTML = layoutBase;
  for (const m of state.moves || []) applyMove(m);
  layoutApplied = sig;
}

const sameKind = (a, b) => a.tagName === b.tagName && a.classList[0] === b.classList[0];

function dropPlan(x, y) {
  if (!drag) return null;
  drag.el.style.pointerEvents = 'none';
  const t = document.elementFromPoint(x, y);
  drag.el.style.pointerEvents = '';
  if (!t || !t.closest?.('.phone') || t.closest('.phone') !== drag.el.closest('.phone')) return null;
  let start = t.closest('svg') || t;
  let container = null;
  for (let c = start; c && !c.classList.contains('phone'); c = c.parentElement) {
    if (drag.el.contains(c)) return null;
    if ([...c.children].some(k => k !== drag.el && sameKind(k, drag.el))) { container = c; break; }
  }
  if (!container) {
    const parent = drag.el.parentElement;
    container = parent.contains(start) ? parent : start.closest('.b-body,.b-section,.phone') || null;
  }
  if (!container || container.classList.contains('phone') && !container.querySelector('.b-body')) return null;
  const cs = getComputedStyle(container);
  const horizontal = (cs.display === 'flex' || cs.display === 'inline-flex') && cs.flexDirection.startsWith('row');
  const siblings = [...container.children].filter(c => c !== drag.el && !c.classList.contains('lab-drop') && !c.classList.contains('lab-gap'));
  if (!horizontal) {
    const cw = container.getBoundingClientRect().width;
    for (const s of siblings) {
      const r = s.getBoundingClientRect();
      if (y < r.top || y > r.bottom) continue;
      const narrow = r.width < cw * 0.9;
      const side = x > r.right - Math.min(r.width * 0.3, 60) && (narrow || x > r.right) ? 'right'
        : x < r.left + Math.min(r.width * 0.3, 60) && (narrow || x < r.left) ? 'left' : null;
      if (side) return { container, beside: s, side, siblings, horizontal };
    }
  }
  const before = siblings.find(s => {
    const r = s.getBoundingClientRect();
    return horizontal ? x < r.left + r.width / 2 : y < r.top + r.height / 2;
  }) || null;
  return { container, before, siblings, horizontal };
}
function showDropLine(plan) {
  document.querySelectorAll('.lab-drop').forEach(n => n.remove());
  if (!plan) return;
  const phone = plan.container.closest('.phone'), base = phone.getBoundingClientRect();
  if (plan.beside) {
    const r = plan.beside.getBoundingClientRect(), edge = plan.side === 'left' ? r.left : r.right;
    const bar = document.createElement('div');
    bar.className = 'lab-drop';
    bar.style.cssText = `left:${edge - base.left - 1}px;top:${r.top - base.top}px;width:3px;height:${r.height}px`;
    phone.append(bar);
    return;
  }
  const ref = plan.before || plan.siblings[plan.siblings.length - 1];
  const line = document.createElement('div');
  line.className = 'lab-drop';
  if (!ref) {
    const r = plan.container.getBoundingClientRect();
    line.style.cssText = `left:${r.left - base.left}px;top:${r.bottom - base.top - 2}px;width:${r.width}px;height:3px`;
  } else {
    const r = ref.getBoundingClientRect();
    if (plan.horizontal) line.style.cssText = `left:${(plan.before ? r.left : r.right) - base.left - 1}px;top:${r.top - base.top}px;width:3px;height:${r.height}px`;
    else line.style.cssText = `left:${r.left - base.left}px;top:${(plan.before ? r.top : r.bottom) - base.top - 1}px;width:${r.width}px;height:3px`;
  }
  phone.append(line);
}
function recordMove(el, container, before, beside, side) {
  if (!el.dataset.labId || !container.dataset.labId) return;
  const m = beside ? { id: el.dataset.labId, beside: beside.dataset.labId, side, label: labelOf(el), besideLabel: labelOf(beside) } : {
    id: el.dataset.labId, to: container.dataset.labId, before: before?.dataset.labId ?? null,
    label: labelOf(el), toLabel: labelOf(container.querySelector('.b-overline')) || container.className.baseVal || container.className.split(' ')[0] || container.tagName.toLowerCase(),
    beforeLabel: before ? labelOf(before) : '',
  };
  (state.moves ||= []).push(m);
  applyMove(m);
  layoutApplied = JSON.stringify(state.moves);
  showMoves();
  render();
}
const snap4 = (v, off) => { const g = (typeof SEE !== 'undefined' && SEE.grid) || 4; return off ? v : Math.round(v / g) * g; };
// Free drag: the part keeps its place in the flow but its margins follow the pointer (snapped to
// 4 px, Alt for exact), so what is around it moves over and the gaps stay true.
function freeMove(e) {
  const { el } = drag, id = el.dataset.labId;
  if (!id) return;
  const dx = snap4(e.clientX - drag.x, e.altKey), dy = snap4(e.clientY - drag.y, e.altKey);
  (state.free ||= {})[id] = { ml: drag.ml + dx, mt: drag.mt + dy, dx, dy, label: labelOf(el) };
  render();
  showFreeGaps(el);
}
function showFreeGaps(el, kind = '') {
  document.querySelectorAll(kind ? '.lab-gap.measure' : '.lab-gap:not(.measure)').forEach(n => n.remove());
  const phone = el.closest('.phone'), base = phone.getBoundingClientRect(), r = el.getBoundingClientRect();
  const tag = (x, y, w, h, text) => {
    const d = document.createElement('div');
    d.className = `lab-gap between ${kind}`.trim();
    d.style.cssText = `left:${x - base.left}px;top:${y - base.top}px;width:${Math.max(w, 1)}px;height:${Math.max(h, 1)}px`;
    d.textContent = text;
    phone.append(d);
  };
  const prev = el.previousElementSibling, next = el.nextElementSibling, par = el.parentElement.getBoundingClientRect();
  if (prev && !prev.classList.contains('lab-gap')) { const p = prev.getBoundingClientRect(); const g = Math.round(r.top - p.bottom); if (g > 0) tag(r.left, p.bottom, r.width, g, g); }
  if (next && !next.classList.contains('lab-gap')) { const n = next.getBoundingClientRect(); const g = Math.round(n.top - r.bottom); if (g > 0) tag(r.left, r.bottom, r.width, g, g); }
  const left = Math.round(r.left - par.left), right = Math.round(par.right - r.right);
  if (left > 0) tag(par.left, r.top, left, r.height, left);
  if (right > 0) tag(r.right, r.top, right, r.height, right);
}

function wireLayout() {
  const screens = $('screens');
  screens.addEventListener('pointerdown', e => {
    if (e.button > 0 || !e.target.closest?.('.lab-cross') || !selected?.el.isConnected) return;
    const el = selected.el, ms = getComputedStyle(el), had = state.free?.[el.dataset.labId];
    drag = { el, x: e.clientX, y: e.clientY, started: false, plan: null,
      ml: had ? had.ml - had.dx : parseFloat(ms.marginLeft) || 0, mt: had ? had.mt - had.dy : parseFloat(ms.marginTop) || 0 };
    e.preventDefault(); e.stopPropagation();
  }, true);
  window.addEventListener('pointermove', e => {
    if (!drag) return;
    if (!drag.started && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 6) {
      drag.started = true;
      drag.el.classList.add('lab-dragging');
      document.querySelectorAll('.lab-handles').forEach(n => { n.style.visibility = 'hidden'; });
    }
    if (!drag.started) return;
    e.preventDefault();
    if (freeMode) { freeMove(e); return; }
    drag.plan = dropPlan(e.clientX, e.clientY);
    showDropLine(drag.plan);
  }, { passive: false });
  window.addEventListener('pointerup', () => {
    if (!drag) return;
    const d = drag;
    drag = null;
    d.el.classList.remove('lab-dragging');
    document.querySelectorAll('.lab-drop,.lab-gap').forEach(n => n.remove());
    if (d.started && freeMode) showMoves();
    else if (d.started && d.plan) recordMove(d.el, d.plan.container, d.plan.before, d.plan.beside, d.plan.side);
    drawHandles();
  });
  $('move-style').onchange = e => { freeMode = e.target.value === 'free'; };
}

function showMoves() {
  const box = $('moves');
  box.textContent = '';
  const moves = state.moves || [], free = Object.values(state.free || {});
  if (!moves.length && !free.length) {
    box.innerHTML = '<p class="hint">Inga flyttar än. Välj en del i en skärm och dra den med pilkorset vid hörnet till ett annat ställe.</p>';
    return;
  }
  moves.forEach((m, i) => {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = `${i + 1}. ${moveText(m)}`;
    box.append(p);
  });
  for (const f of free) {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = freeText(f);
    box.append(p);
  }
}
const freeText = f => `"${f.label}" flyttad fritt ${f.dx} px åt höger och ${f.dy} px nedåt (marginalerna ${f.ml} och ${f.mt} px)`;
function layoutSummary(st, out) {
  const free = Object.values(st.free || {});
  if (!st.moves?.length && !free.length) return;
  out.layoutMoves = [...(st.moves || []).map(moveText), ...free.map(freeText)];
}
