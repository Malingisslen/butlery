'use strict';
// Drag and drop in the example screens: rows, sections, bands, buttons and chips can be moved
// to another place. A move is a record in state.moves, replayed on a pristine copy of the
// screens, so undo, saved variants and the shared link all carry the layout. The light and the
// dark copy of a screen share element ids, so a move happens in both. Only the lab's own example
// screens change; the app is not touched.

const MOVE_KINDS = [
  { item: '.b-row', into: '.b-section, .b-body' },
  { item: '.b-section', into: '.b-body', handle: '.b-overline' },
  { item: '.b-band', into: '.b-body' },
  { item: '.b-btn', into: '.b-body, .b-btnrow' },
  { item: '.b-chip', into: '.b-chips' },
];
const MOVABLE = MOVE_KINDS.map(k => k.item).join(',');
const CONTAINERS = ['.b-body', '.b-section', '.b-chips', '.b-btnrow'].join(',');
let moveMode = false;
let layoutBase = '';
let layoutApplied = '[]';
let drag = null; // { el, kind }

// Called once, before the dark copies are cloned, so both copies get the same ids.
function assignLayoutIds() {
  document.querySelectorAll('#screens > figure').forEach((fig, f) => {
    fig.querySelectorAll(`${MOVABLE},${CONTAINERS}`).forEach((el, n) => { el.dataset.labId = `f${f}-${n}`; });
  });
  layoutBase = $('screens').innerHTML;
}
function snapshotLayoutBase() { layoutBase = $('screens').innerHTML; }

function markDraggable() {
  const screens = $('screens');
  screens.classList.toggle('lab-move', moveMode);
  screens.querySelectorAll(`${MOVABLE},.b-overline`).forEach(el => {
    if (moveMode) el.setAttribute('draggable', 'true'); else el.removeAttribute('draggable');
  });
}
function labelOf(el) { return (el?.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 28) || el?.className || ''; }

function applyMove(m) {
  for (const fig of document.querySelectorAll('#screens > figure')) {
    const el = fig.querySelector(`[data-lab-id="${m.id}"]`), to = fig.querySelector(`[data-lab-id="${m.to}"]`);
    if (!el || !to || el.contains(to)) continue;
    const before = m.before ? fig.querySelector(`[data-lab-id="${m.before}"]`) : null;
    to.insertBefore(el, before && before.parentElement === to ? before : null);
  }
}
// Rebuild the screens from the pristine copy and replay the moves, unless nothing changed.
function replayLayout(force) {
  const sig = JSON.stringify(state.moves || []);
  if (!force && sig === layoutApplied) return;
  $('screens').innerHTML = layoutBase;
  for (const m of state.moves || []) applyMove(m);
  layoutApplied = sig;
  markDraggable();
}

function dropPlan(e) {
  if (!drag) return null;
  const container = e.target.closest?.(drag.kind.into);
  if (!container || drag.el.contains(container) || container.closest('.phone') !== drag.el.closest('.phone')) return null;
  const horizontal = container.matches('.b-chips,.b-btnrow');
  const siblings = [...container.children].filter(c => c !== drag.el && c.matches(drag.kind.item));
  const before = siblings.find(s => {
    const r = s.getBoundingClientRect();
    return horizontal ? e.clientX < r.left + r.width / 2 : e.clientY < r.top + r.height / 2;
  }) || null;
  return { container, before, siblings, horizontal };
}
function showDropLine(plan) {
  document.querySelectorAll('.lab-drop').forEach(n => n.remove());
  if (!plan) return;
  const phone = plan.container.closest('.phone'), base = phone.getBoundingClientRect();
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

function wireLayout() {
  const screens = $('screens');
  screens.addEventListener('dragstart', e => {
    if (!moveMode) return;
    const handle = e.target.closest?.('.b-overline');
    const el = handle ? handle.closest('.b-section') : e.target.closest?.(MOVABLE);
    const kind = el && MOVE_KINDS.find(k => el.matches(k.item));
    if (!kind) { e.preventDefault(); return; }
    drag = { el, kind };
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', el.dataset.labId || '');
    el.classList.add('lab-dragging');
  });
  screens.addEventListener('dragover', e => {
    const plan = dropPlan(e);
    if (plan) e.preventDefault();
    showDropLine(plan);
  });
  screens.addEventListener('drop', e => {
    const plan = dropPlan(e);
    if (!plan) return;
    e.preventDefault();
    const m = {
      id: drag.el.dataset.labId, to: plan.container.dataset.labId, before: plan.before?.dataset.labId ?? null,
      label: labelOf(drag.el), toLabel: labelOf(plan.container.querySelector('.b-overline')) || plan.container.className.split(' ')[0],
      beforeLabel: plan.before ? labelOf(plan.before) : '',
    };
    (state.moves ||= []).push(m);
    applyMove(m);
    layoutApplied = JSON.stringify(state.moves);
    showMoves();
    render();
  });
  screens.addEventListener('dragend', () => {
    drag?.el.classList.remove('lab-dragging');
    drag = null;
    document.querySelectorAll('.lab-drop').forEach(n => n.remove());
  });
}

function showMoves() {
  const box = $('moves');
  box.textContent = '';
  const moves = state.moves || [];
  if (!moves.length) {
    box.innerHTML = '<p class="hint">Inga flyttar än. Slå på Flytta delar och dra en rad, ett avsnitt eller en knapp till ett annat ställe.</p>';
    return;
  }
  moves.forEach((m, i) => {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = `${i + 1}. "${m.label}" till ${m.beforeLabel ? `före "${m.beforeLabel}"` : 'sist'} i ${m.toLabel}`;
    box.append(p);
  });
}
function layoutSummary(st, out) {
  if (!st.moves?.length) return;
  out.layoutMoves = st.moves.map(m => `"${m.label}" ${m.beforeLabel ? `före "${m.beforeLabel}"` : 'sist'} i ${m.toLabel}`);
}
