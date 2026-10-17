'use strict';
// Drag and drop in the example screens: rows, sections, bands, buttons and chips can be moved
// to another place. A move is a record in state.moves, replayed on a pristine copy of the
// screens, so undo, saved variants and the shared link all carry the layout. The light and the
// dark copy of a screen share element ids, so a move happens in both. Only the lab's own example
// screens change; the app is not touched.

// Items that are picked as a whole when you press anywhere inside them.
const MOVABLE = '.b-row,.b-section,.b-band,.b-btn,.b-chip,.b-card,.mr-card,.b-field,.b-input,.b-iconbtn,.tab,.add';
let moveMode = false;
let layoutBase = '';
let layoutApplied = '[]';
let moving = null; // the picked element
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

function markDraggable() {
  $('screens').classList.toggle('lab-move', moveMode);
  if (!moveMode) pickMoving(null);
}
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
  moving = null;
  $('screens').innerHTML = layoutBase;
  for (const m of state.moves || []) applyMove(m);
  layoutApplied = sig;
  markDraggable();
  showMoving();
}

// The item to pick: the closest kit item around the pressed spot, else the smallest box that has
// neighbours. A second press on the picked item picks the box around it.
function pickAt(target) {
  let e = target.closest?.('.phone') ? target : null;
  if (!e) return null;
  if (inSvg(e) || e.tagName === 'svg') e = e.closest('svg');
  for (let p = e; p && !p.classList.contains('phone'); p = p.parentElement) {
    if (p.matches(MOVABLE) && !p.classList.contains('b-scroll')) return p;
  }
  for (let p = e; p && !p.classList.contains('phone'); p = p.parentElement) {
    if (p.parentElement && p.parentElement.children.length > 1 && !p.classList.contains('b-scroll')) return p;
  }
  return null;
}
function boxAround(el) {
  let p = el.parentElement;
  while (p && !p.classList.contains('phone') && (p.classList.contains('b-scroll') || p.parentElement?.children.length < 2)) p = p.parentElement;
  return p && !p.classList.contains('phone') ? p : el;
}
function pickMoving(el) {
  document.querySelectorAll('[data-lab-moving]').forEach(n => n.removeAttribute('data-lab-moving'));
  moving = el;
  el?.setAttribute('data-lab-moving', '');
  showMoving();
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
  const again = document.querySelector(`#screens .fig-light [data-lab-id="${m.id}"]`) || document.querySelector(`#screens [data-lab-id="${m.id}"]`);
  pickMoving(again);
}
// One step among the neighbours, for touch screens and for precise nudges.
function nudge(dir) {
  if (!moving) return;
  const parent = moving.parentElement;
  const sibs = [...parent.children].filter(c => !c.classList.contains('lab-drop') && !c.classList.contains('lab-gap'));
  const i = sibs.indexOf(moving), j = i + dir;
  if (j < 0 || j >= sibs.length) return;
  recordMove(moving, parent, dir < 0 ? sibs[j] : sibs[j + 1] || null);
}

function wireLayout() {
  const screens = $('screens');
  screens.addEventListener('pointerdown', e => {
    if (!moveMode || e.button > 0) return;
    let el = pickAt(e.target);
    if (!el) return;
    if (moving?.isConnected && moving.contains(e.target) && !drag) el = moving;
    drag = { el, x: e.clientX, y: e.clientY, started: false, plan: null, wasPicked: el === moving };
    el.setAttribute('data-lab-moving', '');
    if (e.pointerType === 'touch') e.preventDefault();
  }, true);
  window.addEventListener('pointermove', e => {
    if (!drag) return;
    if (!drag.started && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 6) {
      drag.started = true;
      drag.el.classList.add('lab-dragging');
    }
    if (!drag.started) return;
    e.preventDefault();
    drag.plan = dropPlan(e.clientX, e.clientY);
    showDropLine(drag.plan);
  }, { passive: false });
  window.addEventListener('pointerup', () => {
    if (!drag) return;
    const d = drag;
    drag = null;
    d.el.classList.remove('lab-dragging');
    document.querySelectorAll('.lab-drop').forEach(n => n.remove());
    if (d.started) {
      if (d.plan) recordMove(d.el, d.plan.container, d.plan.before, d.plan.beside, d.plan.side);
      else pickMoving(d.el);
    } else if (d.wasPicked && moving === d.el) pickMoving(boxAround(d.el));
    else pickMoving(d.el);
  });
  screens.addEventListener('click', e => { if (moveMode) { e.preventDefault(); e.stopPropagation(); } }, true);
  $('move-up').onclick = () => nudge(-1);
  $('move-down').onclick = () => nudge(1);
  $('move-out').onclick = () => { if (moving) pickMoving(boxAround(moving)); };
}

function showMoving() {
  const box = $('moving');
  if (!box) return;
  if (!moveMode) { box.textContent = 'Slå på Flytta delar för att välja något i skärmarna.'; }
  else if (!moving?.isConnected) box.textContent = 'Tryck på en del i en skärm för att välja den, och dra den dit du vill ha den. Tryck igen på samma del för att välja rutan runt.';
  else box.textContent = `Vald: "${labelOf(moving)}"`;
  for (const id of ['move-up', 'move-down', 'move-out']) $(id).disabled = !moveMode || !moving?.isConnected;
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
    p.textContent = `${i + 1}. ${moveText(m)}`;
    box.append(p);
  });
}
function layoutSummary(st, out) {
  if (!st.moves?.length) return;
  out.layoutMoves = st.moves.map(moveText);
}
