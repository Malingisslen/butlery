'use strict';
// Drag and drop in the example screens: rows, sections, bands, buttons and chips can be moved
// to another place. A move is a record in state.moves, replayed on a pristine copy of the
// screens, so undo, saved variants and the shared link all carry the layout. The light and the
// dark copy of a screen share element ids, so a move happens in both. The picked part is moved
// with the cross at its corner (the move handle). Only the lab's own example
// screens change; the app is not touched.

const labInline = new Set();
let layoutBase = '';
let layoutApplied = '[]';
let freeMode = true; // exact pixels is the default; Shift while dragging does the other kind
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
        // A part with text is also the same part when only an icon inside it differs (a list or a grid
        // toggle in the header row), so the like part in the other views is found by this one.
        const text = (el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 24);
        if (text) {
          const loose = [el.tagName, el.getAttribute('style') || '', [...el.children].map(c => c.tagName).join(','), text].join('|');
          if (!kinds.has(loose)) kinds.set(loose, 'l' + kinds.size);
          el.dataset.labKindLoose = kinds.get(loose);
        }
      }
    });
    // Text that sits loose between other parts ("35 min · 4 port · 4,0") gets a part of its own per
    // piece, so each can be picked. Done after the numbering so saved ids keep their numbers.
    let t = 0;
    fig.querySelectorAll('.phone, .phone *').forEach(el => {
      if (inSvg(el) || el.tagName === 'svg' || !el.children.length) return;
      // In a flex or grid row every piece would become its own item with its own gap, so the text stays one piece.
      const lay = /flex|grid/.test(getComputedStyle(el).display);
      for (const node of [...el.childNodes].filter(n => n.nodeType === 3)) {
        for (const piece of lay ? [node.textContent] : node.textContent.split(/(\s*·\s*)/)) {
          const core = piece.trim();
          if (!core || core === '·') { node.before(piece); continue; }
          const lead = piece.slice(0, piece.indexOf(core)), trail = piece.slice(lead.length + core.length);
          const span = document.createElement('span');
          span.textContent = core;
          span.dataset.labId = `f${f}-t${t++}`;
          const sig = ['SPAN', '', ''].join('|');
          if (!kinds.has(sig)) kinds.set(sig, 'k' + kinds.size);
          span.dataset.labKind = kinds.get(sig);
          const loose = ['SPAN', '', '', core.slice(0, 24)].join('|');
          if (!kinds.has(loose)) kinds.set(loose, 'l' + kinds.size);
          span.dataset.labKindLoose = kinds.get(loose);
          node.before(lead, span, trail);
        }
        node.remove();
      }
    });
  });
  markSymbols();
  // A translate does nothing to an inline box, so a part that is inline is made inline-block when it is moved.
  document.querySelectorAll('#screens .phone, #screens .phone *').forEach(el => {
    if (el.dataset.labId && !el.closest('svg') && getComputedStyle(el).display === 'inline') labInline.add(el.dataset.labId);
  });
  layoutBase = $('screens').innerHTML;
}
// A bullet or a slash is its own part even when it shares a class with the numbers next to it
// ("• 4,5"), so picking it does not pick the numbers, and the numbers leave the symbols out.
function markSymbols() {
  const leaf = el => !el.children.length && el.closest('.phone') && !el.closest('svg') && el.textContent.trim();
  const keyOf = el => el.tagName + '.' + [...el.classList].filter(c => !c.startsWith('lab-')).join('.');
  const syms = new Set();
  const all = [...document.querySelectorAll('#screens .phone *')].filter(leaf);
  for (const el of all) {
    if (!/^[^\p{L}\p{N}]+$/u.test(el.textContent.trim()) || !el.classList.length) continue;
    el.dataset.labSym = '';
    el.dataset.labKindLoose ||= 'y' + el.textContent.trim().codePointAt(0);
    syms.add(keyOf(el));
  }
  for (const el of all) if (!('labSym' in el.dataset) && syms.has(keyOf(el))) el.dataset.labSibsym = '';
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
const layoutSig = () => JSON.stringify([state.moves || [], state.copies || [], state.texts || {}, state.adds || []]);
function replayLayout(force) {
  const sig = layoutSig();
  if (!force && sig === layoutApplied) return;
  $('screens').innerHTML = layoutBase;
  for (const a of state.adds || []) applyAdd(a);
  for (const c of state.copies || []) applyCopy(c);
  for (const m of state.moves || []) applyMove(m);
  applyTexts();
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
    label: labelOf(el), toLabel: (container.querySelector('.b-overline') && labelOf(container.querySelector('.b-overline'))) || container.className.baseVal || container.className.split(' ')[0] || container.tagName.toLowerCase(),
    beforeLabel: before ? labelOf(before) : '',
  };
  (state.moves ||= []).push(m);
  applyMove(m);
  layoutApplied = layoutSig();
  showMoves();
  render();
}
// Free placement is an exact offset in whole pixels (CSS translate), so what is set is what shows;
// margins would shift a centred neighbour by half and break the alignment.
const freeOffset = el => { const f = state.free?.[el.dataset.labId]; return { ox: f?.ox ?? 0, oy: f?.oy ?? 0 }; };
// When the part has no match by type in another view, the same words in the same kind of element
// are the same part (a title or a button that is built differently in two views).
const textKey = (n, withClasses) => {
  const t = (n.textContent || '').replace(/\s+/g, ' ').trim();
  const cls = withClasses ? [...n.classList].filter(c => !c.startsWith('lab-')).sort().join('.') : '';
  return t.length >= (withClasses ? 3 : 8) && !n.closest('svg') ? `${n.tagName}|${cls}|${t}` : '';
};
function sameByText(el, own, ph) {
  for (const withClasses of [true, false]) {
    const key = textKey(el, withClasses);
    if (!key) continue;
    const mine = [...own.querySelectorAll(el.tagName)].filter(n => textKey(n, withClasses) === key);
    const theirs = [...ph.querySelectorAll(el.tagName)].filter(n => n.dataset.labId && textKey(n, withClasses) === key);
    const hit = theirs[mine.indexOf(el)];
    if (hit) return hit;
  }
  return null;
}
// A move reaches what the pink frame shows (the same rule as sizes and colours): every like part in
// all views, in this view too, unless "bara vald del" / "bara i den här vyn" is ticked. With two like
// parts picked together each moves on its own.
function likeTargets(el) {
  const picked = selected?.el.isConnected ? pickedEls() : [];
  const own = el.closest('.phone'), sel = selectorFor(el, false);
  if (!picked.includes(el) || selected.onlyThis || own.dataset.theme === 'dark') return [el];
  if (sel === '.phone' || sel.includes(':nth-child') || picked.some(o => o !== el && selectorFor(o, false) === sel)) return [el];
  const targets = new Set([el]);
  for (const ph of document.querySelectorAll('#screens .phone')) {
    if (ph.dataset.theme === 'dark' || (selected.onlyView && ph !== own)) continue;
    let hits = [];
    try { hits = [...ph.querySelectorAll(sel.replace(/^\.phone /, ''))].filter(n => n.dataset.labId); } catch { /* a selector the browser refuses matches nothing */ }
    if (!hits.length && ph !== own) { const t = sameByText(el, own, ph); if (t) hits = [t]; }
    hits.forEach(n => targets.add(n));
  }
  return [...targets];
}
function freeSet(el, ox, oy) {
  if (!el.dataset.labId) return;
  const targets = likeTargets(el), grp = targets.length > 1 ? `${selectorFor(el, false)}|${selected.onlyView ? el.closest('.phone').dataset.view : ''}` : null;
  // The picked part lands exactly on (ox, oy); the like parts move by the same step from where each is.
  const own = freeOffset(el), dx = ox - own.ox, dy = oy - own.oy;
  for (const t of targets) {
    const id = t.dataset.labId, at = t === el ? { ox, oy } : (() => { const o = freeOffset(t); return { ox: o.ox + dx, oy: o.oy + dy }; })();
    const f = (state.free ||= {})[id] ||= {};
    f.label = el.dataset.glyph ? `ikonen ${el.dataset.glyph}` : labelOf(el); f.ox = at.ox; f.oy = at.oy;
    if (grp) { f.grp = grp; f.n = targets.length; } else { delete f.grp; delete f.n; }
    if (!f.ox && !f.oy && f.ml == null) delete state.free[id];
  }
}
function freeClear(el) {
  const f = state.free?.[el.dataset.labId];
  if (!f) return;
  for (const [id, g] of Object.entries(state.free)) if (id === el.dataset.labId || f.grp && g.grp === f.grp) { delete g.ox; delete g.oy; if (g.ml == null) delete state.free[id]; }
}
const freeGroups = list => { const seen = new Set(); return list.filter(f => !f.grp || (!seen.has(f.grp) && seen.add(f.grp))); };
// Smart guides: the dragged part snaps to the edges and centres of the other parts and of the
// screen when it comes within 4 px (Alt turns the snapping off), and pink lines show what lines up.
const SNAP_PX = 4;
// A picked group moves as one: its box is the union of the parts' boxes.
function unionRect(els) {
  const rs = els.map(e => e.getBoundingClientRect());
  const left = Math.min(...rs.map(r => r.left)), top = Math.min(...rs.map(r => r.top)), right = Math.max(...rs.map(r => r.right)), bottom = Math.max(...rs.map(r => r.bottom));
  return { left, top, right, bottom, width: right - left, height: bottom - top };
}
function guideTargets(els) {
  const phone = els[0].closest('.phone'), pr = phone.getBoundingClientRect();
  const out = [{ r: pr, screen: true }];
  for (const n of phone.querySelectorAll('[data-lab-id]')) {
    if (n === phone || els.some(el => n === el || n.contains(el) || el.contains(n)) || n.closest('.lab-handles') || n.classList.contains('b-scroll')) continue;
    const r = n.getBoundingClientRect();
    if (r.width < 3 || r.height < 3 || r.bottom < pr.top || r.top > pr.bottom || r.right < pr.left || r.left > pr.right) continue;
    out.push({ r });
  }
  return out;
}
const lines = r => ({ x: [r.left, (r.left + r.right) / 2, r.right], y: [r.top, (r.top + r.bottom) / 2, r.bottom] });
function snapDelta(rect, targets) {
  const m = lines(rect);
  let dx = null, dy = null;
  for (const t of targets) {
    const o = lines(t.r);
    for (const a of m.x) for (const b of o.x) if (Math.abs(b - a) <= SNAP_PX && (dx === null || Math.abs(b - a) < Math.abs(dx))) dx = b - a;
    for (const a of m.y) for (const b of o.y) if (Math.abs(b - a) <= SNAP_PX && (dy === null || Math.abs(b - a) < Math.abs(dy))) dy = b - a;
  }
  return { dx: dx === null ? 0 : Math.round(dx), dy: dy === null ? 0 : Math.round(dy) };
}
function drawGuides(els) {
  document.querySelectorAll('.lab-guide').forEach(n => n.remove());
  const phone = els[0].closest('.phone'), base = phone.getBoundingClientRect(), r = unionRect(els), m = lines(r);
  const add = (x, y, w, h) => {
    const d = document.createElement('div');
    d.className = 'lab-guide';
    d.style.cssText = `left:${x - base.left}px;top:${y - base.top}px;width:${Math.max(w, 1)}px;height:${Math.max(h, 1)}px`;
    phone.append(d);
  };
  for (const t of guideTargets(els)) {
    const o = lines(t.r);
    // Lines only span the two parts they connect (the screen only draws its centre), so a guide never
    // reads as a frame around something.
    const top = Math.max(Math.min(r.top, t.r.top), r.top - 80), bottom = Math.min(Math.max(r.bottom, t.r.bottom), r.bottom + 80), left = Math.max(Math.min(r.left, t.r.left), r.left - 80), right = Math.min(Math.max(r.right, t.r.right), r.right + 80);
    m.x.forEach((a, i) => { if ((!t.screen || i === 1) && o.x.some(b => Math.abs(a - b) < 0.6)) add(a, top, 1, bottom - top); });
    m.y.forEach((a, i) => { if ((!t.screen || i === 1) && o.y.some(b => Math.abs(a - b) < 0.6)) add(left, a, right - left, 1); });
  }
}
function freeMove(e) {
  let dx = Math.round(e.clientX - drag.x), dy = Math.round(e.clientY - drag.y);
  const lockX = e.shiftKey && Math.abs(dy) > Math.abs(dx), lockY = e.shiftKey && !lockX;
  if (lockX) dx = 0;
  if (lockY) dy = 0;
  const place = (sx, sy) => { for (const st of drag.starts) freeSet(st.el, st.ox + dx + sx, st.oy + dy + sy); render(); };
  place(0, 0);
  const els = drag.starts.map(st => st.el);
  if (!e.altKey) {
    drag.targets ||= guideTargets(els);
    const s = snapDelta(unionRect(els), drag.targets);
    if (s.dx || s.dy) place(lockX ? 0 : s.dx, lockY ? 0 : s.dy);
  }
  drawGuides(els);
  const o = freeOffset(drag.el);
  showMeasure(els, `x ${o.ox >= 0 ? '+' : ''}${o.ox}  y ${o.oy >= 0 ? '+' : ''}${o.oy}`);
  showFreeGaps(drag.el);
}
// Small number tag under the picked part(s) while dragging or resizing, so nothing has to be read in the panel.
function showMeasure(els, text) {
  document.querySelectorAll('.lab-measure-tag').forEach(n => n.remove());
  if (!text) return;
  const phone = els[0].closest('.phone'), base = phone.getBoundingClientRect(), r = unionRect(els);
  const d = document.createElement('div');
  d.className = 'lab-measure-tag';
  d.textContent = text;
  d.style.cssText = `left:${r.left - base.left + r.width / 2}px;top:${r.bottom - base.top + 6}px`;
  phone.append(d);
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
    if (e.altKey) dupPicked();
    const el = selected.el;
    drag = { el, x: e.clientX, y: e.clientY, started: false, plan: null, starts: pickedEls().map(x => ({ el: x, ...freeOffset(x) })) };
    e.preventDefault(); e.stopPropagation();
  }, true);
  window.addEventListener('pointermove', e => {
    if (!drag) return;
    if (!drag.started && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 6) {
      drag.started = true;
      for (const st of drag.starts) st.el.classList.add('lab-dragging');
      document.querySelectorAll('.lab-handles').forEach(n => { n.style.visibility = 'hidden'; });
    }
    if (!drag.started) return;
    e.preventDefault();
    drag.free = true;
    if (drag.free) { freeMove(e); return; }
    drag.plan = dropPlan(e.clientX, e.clientY);
    showDropLine(drag.plan);
  }, { passive: false });
  window.addEventListener('pointerup', () => {
    if (!drag) return;
    const d = drag;
    drag = null;
    for (const st of d.starts) st.el.classList.remove('lab-dragging');
    document.querySelectorAll('.lab-drop,.lab-gap,.lab-guide,.lab-measure-tag').forEach(n => n.remove());
    if (d.started && d.free) { showMoves(); refreshExact(); }
    else if (d.started && d.plan) recordMove(d.el, d.plan.container, d.plan.before, d.plan.beside, d.plan.side);
    drawHandles();
  });
  window.addEventListener('keydown', e => {
    if ((e.key === 'Delete' || e.key === 'Backspace') && selected?.el.isConnected && !e.target.closest?.('input,select,textarea,summary,.panel,[contenteditable]')) {
      const els = [selected.el, ...(selected.extras || [])].filter(x => x.dataset.labId && !x.classList.contains('phone'));
      if (!els.length) return;
      e.preventDefault();
      for (const el of els) (state.removed ||= {})[el.dataset.labId] = labelOf(el);
      clearSelection(); showMoves(); render();
      return;
    }
    const d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key];
    if (!d || !selected?.el.isConnected || e.target.closest?.('input,select,textarea,summary,.panel,[contenteditable]')) return;
    e.preventDefault();
    const step = e.shiftKey ? 10 : 1;
    for (const el of [selected.el, ...(selected.extras || [])]) { const o = freeOffset(el); freeSet(el, o.ox + d[0] * step, o.oy + d[1] * step); }
    showMoves(); render(); refreshExact(); drawGuides(pickedEls());
  });
  window.addEventListener('keyup', e => { if (e.key.startsWith('Arrow')) document.querySelectorAll('.lab-guide').forEach(n => n.remove()); });
}

function showMoves() {
  const box = $('moves');
  box.textContent = '';
  const moves = state.moves || [], free = freeGroups(Object.values(state.free || {})), removed = Object.entries(state.removed || {}), extra = [...(state.adds || []).map(addLine), ...(state.copies || []).map(c => `"${c.label}" kopierad`), ...Object.values(state.texts || {}).map(t => `Texten "${t.from}" ändrad till "${t.to}"`)];
  if (!moves.length && !free.length && !removed.length && !extra.length) {
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
  for (const line of extra) {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = line;
    box.append(p);
  }
  for (const [id, label] of removed) {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = `"${label}" borttagen `;
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'ghost'; b.textContent = 'Ta tillbaka';
    b.onclick = () => { delete state.removed[id]; showMoves(); render(); };
    p.append(b);
    box.append(p);
  }
}
const freeText = f => (f.ox != null
  ? `"${f.label}" flyttad exakt ${f.ox} px åt höger och ${f.oy} px nedåt (förskjutning, grannarna ligger kvar)${f.grp ? `, gäller ${f.n} likadana delar` : ''}`
  : `"${f.label}" flyttad fritt ${f.dx} px åt höger och ${f.dy} px nedåt (marginalerna ${f.ml} och ${f.mt} px)`);
function layoutSummary(st, out) {
  const free = freeGroups(Object.values(st.free || {})), removed = Object.values(st.removed || {}), copies = st.copies || [], texts = Object.values(st.texts || {}), adds = st.adds || [];
  if (!st.moves?.length && !free.length && !removed.length && !copies.length && !texts.length && !adds.length) return;
  out.layoutMoves = [...adds.map(addLine), ...(st.moves || []).map(moveText), ...free.map(freeText), ...removed.map(l => `"${l}" borttagen`), ...copies.map(c => `"${c.label}" kopierad (ny del direkt efter originalet)`), ...texts.map(t => `Texten "${t.from}" ändrad till "${t.to}"`)];
}

// Swap two parts: each goes to the other's place (moves are recorded, so both themes and undo follow).
function swapParts(a, b) {
  const kids = el => [...el.parentElement.children].filter(c => !(c.getAttribute('class') || '').split(' ').some(k => k.startsWith('lab-') && k !== 'lab-row'));
  const next = el => { const k = kids(el), i = k.indexOf(el); return k[i + 1] || null; };
  const pa = a.parentElement, pb = b.parentElement, aNext = next(a), bNext = next(b);
  if (!pa?.dataset.labId || !pb?.dataset.labId) return false;
  recordMove(a, pb, bNext === a ? null : bNext);
  if (aNext === b) return true;
  recordMove(b, pa, aNext);
  return true;
}
