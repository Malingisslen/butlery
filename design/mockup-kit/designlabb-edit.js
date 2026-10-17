'use strict';
// Everyday editing in the example screens: select all, copy and paste, duplicate (Alt + drag or
// Ctrl+D), double-click to rewrite a text, a right-click menu and aligning several parts. Copies and
// texts are records in the state, replayed on the pristine screens like moves, so undo, versions and
// the handoff carry them. The light and dark copy of a screen share ids, so everything lands in both.

const TRANSIENT = ['data-lab-selected', 'data-lab-match', 'data-lab-hover', 'data-lab-moving', 'data-lab-state'];
let labClip = [];
let lastPhone = null;

function applyCopy(c) {
  for (const fig of document.querySelectorAll('#screens > figure')) {
    const src = fig.querySelector(`[data-lab-id="${c.src}"]`);
    if (!src || src.classList.contains('phone')) continue;
    const el = src.cloneNode(true);
    for (const n of [el, ...el.querySelectorAll('*')]) {
      TRANSIENT.forEach(a => n.removeAttribute(a));
      if (n.dataset.labId) n.dataset.labId = `${n.dataset.labId}~${c.id}`;
    }
    el.querySelectorAll('.lab-handles,.lab-guide,.lab-gap,.lab-drop').forEach(n => n.remove());
    src.after(el);
  }
}
const copyId = c => `${c.src}~${c.id}`;

// Texts: only leaf elements whose own text can be rewritten.
function textHost(el) {
  if (!el || el.tagName === 'svg' || el.closest('svg')) return null;
  const own = [...el.childNodes].filter(n => n.nodeType === 3 && n.textContent.trim());
  return own.length && !el.children.length ? el : null;
}
function applyTexts() {
  for (const [id, t] of Object.entries(state.texts || {})) {
    for (const el of document.querySelectorAll(`#screens [data-lab-id="${id}"]`)) if (textHost(el)) el.textContent = t.to;
  }
}

function addCopy(srcEl) {
  const id = srcEl.dataset.labId;
  if (!id || srcEl.classList.contains('phone')) return null;
  const list = (state.copies ||= []);
  const c = { src: id, id: 'k' + (list.length + 1), label: labelOf(srcEl) };
  list.push(c);
  applyCopy(c);
  layoutApplied = layoutSig();
  return copyId(c);
}
function selectIds(ids) {
  const els = ids.map(id => [...document.querySelectorAll(`#screens [data-lab-id="${id}"]`)].find(n => n.closest('.phone')?.dataset.theme !== 'dark')).filter(Boolean);
  document.querySelectorAll('[data-lab-selected]').forEach(n => n.removeAttribute('data-lab-selected'));
  if (!els.length) { clearSelection(); return; }
  els.forEach(n => n.setAttribute('data-lab-selected', ''));
  selected = { el: els[0], extras: els.slice(1), mode: null };
  openTab('part');
  showPart(false);
}
function dupPicked() {
  const ids = pickedEls().map(addCopy).filter(Boolean);
  if (!ids.length) return;
  showMoves();
  render();
  selectIds(ids);
}
function copyPicked() { labClip = pickedEls().map(el => el.dataset.labId); }
function pastePicked() {
  const ids = labClip.map(id => [...document.querySelectorAll(`#screens [data-lab-id="${id}"]`)][0]).filter(Boolean).map(addCopy).filter(Boolean);
  if (!ids.length) return;
  showMoves();
  render();
  selectIds(ids);
}
function selectAllIn(phone) {
  if (!phone) return;
  const c = marqueeContainer(phone);
  const ids = [...c.children].filter(k => k.dataset.labId && !isLab(k) && !k.classList.contains('b-scroll')).map(k => k.dataset.labId);
  if (ids.length) selectIds(ids.map(id => id));
}

function editText(el) {
  const host = textHost(el);
  if (!host?.dataset.labId) return false;
  const id = host.dataset.labId, from = state.texts?.[id]?.from ?? host.textContent;
  host.contentEditable = 'true';
  host.focus();
  getSelection().selectAllChildren(host);
  const done = save => {
    host.removeEventListener('blur', onBlur);
    host.removeEventListener('keydown', onKey);
    host.contentEditable = 'false';
    const to = host.textContent.trim();
    if (!save || !to || to === (state.texts?.[id]?.to ?? from)) { host.textContent = state.texts?.[id]?.to ?? from; return; }
    if (to === from) delete state.texts[id]; else (state.texts ||= {})[id] = { from, to };
    layoutApplied = layoutSig();
    applyTexts();
    showMoves();
    render();
  };
  const onBlur = () => done(true);
  const onKey = e => {
    if (e.key === 'Enter') { e.preventDefault(); host.blur(); }
    if (e.key === 'Escape') { e.preventDefault(); host.removeEventListener('blur', onBlur); done(false); host.blur(); }
    e.stopPropagation();
  };
  host.addEventListener('blur', onBlur);
  host.addEventListener('keydown', onKey);
  return true;
}

// Align several parts to their common box, or spread them evenly (offsets, so neighbours stay).
function alignParts(kind) {
  const els = pickedEls();
  if (els.length < 2) return;
  const rs = els.map(el => el.getBoundingClientRect()), u = unionRect(els);
  const shift = els.map(() => [0, 0]);
  const axisOf = k => (['left', 'centerX', 'right', 'spreadX'].includes(k) ? 0 : 1);
  if (kind === 'spreadX' || kind === 'spreadY') {
    const a = axisOf(kind), lo = a ? 'top' : 'left', size = a ? 'height' : 'width';
    const order = els.map((_, i) => i).sort((i, j) => rs[i][lo] - rs[j][lo]);
    const gap = (u[size] - order.reduce((n, i) => n + rs[i][size], 0)) / (order.length - 1);
    let at = u[lo];
    for (const i of order) { shift[i][a] = at - rs[i][lo]; at += rs[i][size] + gap; }
  } else {
    els.forEach((_, i) => {
      const r = rs[i];
      shift[i] = {
        left: [u.left - r.left, 0], centerX: [(u.left + u.right) / 2 - (r.left + r.right) / 2, 0], right: [u.right - r.right, 0],
        top: [0, u.top - r.top], centerY: [0, (u.top + u.bottom) / 2 - (r.top + r.bottom) / 2], bottom: [0, u.bottom - r.bottom],
      }[kind];
    });
  }
  els.forEach((el, i) => { const o = freeOffset(el); freeSet(el, o.ox + Math.round(shift[i][0]), o.oy + Math.round(shift[i][1])); });
  showMoves();
  render();
  showPart(false);
}

let labMenu = null;
function closeLabMenu() { labMenu?.remove(); labMenu = null; }
function openLabMenu(x, y, target) {
  closeLabMenu();
  const els = pickedEls();
  const items = [
    ['Duplicera', 'Ctrl+D', dupPicked],
    ['Kopiera', 'Ctrl+C', copyPicked],
    ['Klistra in', 'Ctrl+V', pastePicked, !labClip.length],
    ['Lägg till text', '', () => addText(target, null, { x, y })],
    ['Lägg till ikon', '', () => addIcon(target, null, { x, y })],
    ['Lägg till egen bild…', '', () => addImage(target, null, { x, y })],
    ['Gör om till ikon', '', () => convertTo('icon', els[0]), els.length !== 1 || !canConvert(els[0])],
    ['Gör om till text', '', () => convertTo('text', els[0]), els.length !== 1 || !canConvert(els[0])],
    ['Byt mot egen bild…', '', () => convertTo('img', els[0]), els.length !== 1 || !canConvert(els[0])],
    ['Redigera text', 'Dubbelklick', () => editText(target), !textHost(target)],
    ['Byt plats på delarna', '', () => { if (els.length === 2 && swapParts(els[0], els[1])) showPart(false); }, els.length !== 2],
    ['Ta bort', 'Delete', () => deletePicked(), !els.length],
    ['Nollställ flytten', '', () => { for (const el of els) freeClear(el); showMoves(); render(); refreshExact(); }, !els.length],
    ['Markera allt', 'Ctrl+A', () => selectAllIn(target?.closest('.phone'))],
  ];
  const menu = document.createElement('div');
  menu.className = 'lab-menu';
  for (const [label, key, fn, off] of items) {
    const b = document.createElement('button');
    b.type = 'button'; b.disabled = !!off;
    b.innerHTML = '<span></span><small></small>';
    b.firstChild.textContent = label; b.lastChild.textContent = key;
    b.onclick = () => { closeLabMenu(); fn(); };
    menu.append(b);
  }
  document.body.append(menu);
  menu.style.left = Math.min(x, innerWidth - menu.offsetWidth - 8) + 'px';
  menu.style.top = Math.min(y, innerHeight - menu.offsetHeight - 8) + 'px';
  labMenu = menu;
}
function deletePicked() {
  const els = pickedEls();
  if (!els.length) return;
  for (const el of els) (state.removed ||= {})[el.dataset.labId] = labelOf(el);
  clearSelection(); showMoves(); render();
}

function wireEdit() {
  const screens = $('screens');
  screens.addEventListener('mouseover', e => { lastPhone = e.target.closest?.('.phone') || lastPhone; });
  screens.addEventListener('dblclick', e => {
    const el = componentOf(e.target);
    if (el && textHost(el)) { e.preventDefault(); editText(el); }
  });
  screens.addEventListener('contextmenu', e => {
    const phone = e.target.closest?.('.phone');
    if (!phone) return;
    e.preventDefault();
    let el = componentOf(e.target);
    if (!el || isEmptySpot(el)) el = phone;
    if (!pickedEls().includes(el) && !pickedEls().some(x => x.contains(el))) selectIds([el.dataset.labId]);
    openLabMenu(e.clientX, e.clientY, el);
  });
  document.addEventListener('pointerdown', e => { if (labMenu && !labMenu.contains(e.target)) closeLabMenu(); }, true);
  window.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeLabMenu();
    if (e.target.closest?.('input,select,textarea,summary,.panel,[contenteditable="true"]') || !(e.ctrlKey || e.metaKey)) return;
    const k = e.key.toLowerCase();
    if (k === 'a') { e.preventDefault(); selectAllIn(selected?.el.isConnected ? selected.el.closest('.phone') : lastPhone); }
    else if (k === 'c' && pickedEls().length) { e.preventDefault(); copyPicked(); }
    else if (k === 'v' && labClip.length) { e.preventDefault(); pastePicked(); }
    else if (k === 'd' && pickedEls().length) { e.preventDefault(); dupPicked(); }
  });
}
