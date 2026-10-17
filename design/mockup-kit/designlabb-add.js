'use strict';
// Adding parts: a new text, a new icon or an own image, and turning a part into one of the others.
// An addition is a record in state.adds, replayed on the pristine screens like copies and moves, so
// undo, versions and the handoff carry it. The light and dark copy of a screen share ids, so it
// lands in both. A converted part is the new one placed before the old one, which is then removed.

const ADD_IMG_PX = 256;
const ADD_IMG_BYTES = 400 * 1024;
const SVG_NS = 'http://www.w3.org/2000/svg';

const addDomId = a => `${a.to}+${a.id}`;
function buildAdd(a) {
  let el;
  if (a.kind === 'icon') {
    el = document.createElementNS(SVG_NS, 'svg');
    el.setAttribute('class', 'i');
    const use = document.createElementNS(SVG_NS, 'use');
    use.setAttribute('href', `#i-${a.glyph}`);
    el.append(use);
    el.dataset.glyph = a.glyph;
  } else if (a.kind === 'img') {
    el = document.createElement('img');
    el.src = a.src;
    el.alt = '';
  } else {
    el = document.createElement('span');
    el.textContent = a.text;
  }
  // The unique class first, so the part is picked and styled on its own and not with every other new text.
  el.classList.add(`ad-${a.id}`);
  if (a.kind === 'img') el.classList.add('ad-img');
  el.dataset.labId = addDomId(a);
  return el;
}
function applyAdd(a) {
  for (const fig of document.querySelectorAll('#screens > figure')) {
    const to = fig.querySelector(`[data-lab-id="${a.to}"]`);
    if (!to) continue;
    const before = a.before ? fig.querySelector(`[data-lab-id="${a.before}"]`) : null;
    to.insertBefore(buildAdd(a), before && before.parentElement === to ? before : null);
  }
}

const idOf = el => el?.dataset.labId ? el.dataset.labId : null;
// Where a new part lands: after the part that was clicked, or last in the screen's content.
function addSpot(ref) {
  const phone = ref?.closest?.('.phone') || lastPhone;
  if (!phone) return null;
  if (!ref || ref.classList.contains('phone') || !idOf(ref.parentElement)) {
    const c = marqueeContainer(phone);
    return idOf(c) ? { to: idOf(c), before: null } : null;
  }
  const next = [...ref.parentElement.children].slice([...ref.parentElement.children].indexOf(ref) + 1).find(k => idOf(k) && !isLab(k));
  return { to: idOf(ref.parentElement), before: idOf(next) };
}
function recordAdd(a) {
  const used = (state.adds || []).map(x => +x.id.slice(1));
  a.id = 'a' + (Math.max(0, ...used) + 1);
  (state.adds ||= []).push(a);
  applyAdd(a);
  layoutApplied = layoutSig();
  showMoves();
  render();
  selectIds([addDomId(a)]);
}

function pickImageFile() {
  return new Promise(resolve => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = () => {
      const file = input.files[0];
      if (!file) return resolve(null);
      const read = new FileReader();
      read.onerror = () => resolve(null);
      read.onload = () => {
        const url = read.result;
        if (file.type === 'image/svg+xml') return resolve({ src: url, name: file.name });
        const img = new Image();
        img.onerror = () => resolve(null);
        img.onload = () => {
          const k = Math.min(1, ADD_IMG_PX / Math.max(img.width, img.height));
          const c = document.createElement('canvas');
          c.width = Math.max(1, Math.round(img.width * k)); c.height = Math.max(1, Math.round(img.height * k));
          c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
          resolve({ src: c.toDataURL('image/png'), name: file.name });
        };
        img.src = url;
      };
      read.readAsDataURL(file);
    };
    input.click();
  });
}
function toast(msg) {
  const note = document.createElement('div');
  note.className = 'lab-toast';
  note.textContent = msg;
  document.body.append(note);
  setTimeout(() => note.remove(), 4000);
}
async function imageAdd(spot, replace, at) {
  const f = await pickImageFile();
  if (!f) return;
  if (f.src.length > ADD_IMG_BYTES) { toast('Bilden är för stor. Välj en mindre bild eller en SVG.'); return; }
  commitAdd({ kind: 'img', src: f.src, name: f.name }, spot, replace, at);
}
function commitAdd(a, spot, replace, at) {
  if (!spot) return;
  a.to = spot.to; a.before = spot.before;
  a.label = a.kind === 'text' ? a.text : a.kind === 'icon' ? `ikonen ${a.glyph}` : `bilden ${a.name}`;
  const box = document.querySelector(`#screens [data-lab-id="${a.to}"]`);
  a.toLabel = box ? `${box.classList[0] || box.tagName.toLowerCase()}-raden "${labelOf(box).slice(0, 20)}"` : 'skärmen';
  if (replace) {
    (state.removed ||= {})[idOf(replace)] = labelOf(replace);
    a.replaces = labelOf(replace);
    a.before = idOf(replace);
    a.to = idOf(replace.parentElement);
  }
  recordAdd(a);
  if (at && !replace) placeAt(addDomId(a), at);
}
// A part added from the right-click menu lands under the pointer, as an exact offset from where the
// flow put it, so the neighbours stay where they are.
function placeAt(domId, at) {
  const el = [...document.querySelectorAll(`#screens [data-lab-id="${domId}"]`)].find(n => n.closest('.phone')?.dataset.theme !== 'dark');
  if (!el) return;
  const r = el.getBoundingClientRect();
  const o = freeOffset(el);
  freeSet(el, o.ox + Math.round(at.x - (r.left + r.width / 2)), o.oy + Math.round(at.y - (r.top + r.height / 2)));
  showMoves();
  render();
}

const addText = (ref, replace, at) => commitAdd({ kind: 'text', text: 'Ny text' }, addSpot(ref), replace, at);
const addIcon = (ref, replace, at) => commitAdd({ kind: 'icon', glyph: 'star' }, addSpot(ref), replace, at);
const addImage = (ref, replace, at) => imageAdd(addSpot(ref), replace, at);
// Converting reaches what the pink frame shows: every like part (the same selector as sizes and
// colours) in all views, unless "bara vald del" / "bara i den här vyn" is ticked.
function convertTargets(el) {
  const sel = selectorFor(el, false);
  const own = el.closest('.phone');
  if (selected?.onlyThis || sel === '.phone' || sel.includes(':nth-child')) return [el];
  const out = new Set([el]);
  for (const ph of document.querySelectorAll('#screens .phone')) {
    if (ph.dataset.theme === 'dark' || (selected?.onlyView && ph !== own)) continue;
    try { ph.querySelectorAll(sel.replace(/^\.phone /, '')).forEach(n => { if (idOf(n) && idOf(n.parentElement)) out.add(n); }); } catch { /* a selector the browser refuses matches nothing */ }
  }
  if (!selected?.onlyView) likeTargets(el).forEach(n => out.add(n));
  return [...out];
}
async function convertTo(kind, el) {
  const make = { text: () => ({ kind: 'text', text: 'Ny text' }), icon: () => ({ kind: 'icon', glyph: 'star' }) };
  let img = null;
  if (kind === 'img') {
    img = await pickImageFile();
    if (!img) return;
    if (img.src.length > ADD_IMG_BYTES) { toast('Bilden är för stor. Välj en mindre bild eller en SVG.'); return; }
  }
  const targets = convertTargets(el);
  for (const t of targets) commitAdd(img ? { kind: 'img', src: img.src, name: img.name } : make[kind](), addSpot(t), t);
  if (targets.length > 1) toast(`Gjorde om ${targets.length} likadana delar. Kryssa i "Bara vald del" först om bara en ska ändras.`);
}
// "Make it ..." works on one picked part, which stays where it is as the new part's neighbour.
const canConvert = el => !!el && !el.classList.contains('phone') && !!idOf(el.parentElement);

function addButtons(host) {
  const row = document.createElement('div');
  row.className = 'row';
  row.style.marginTop = '8px';
  for (const [label, fn] of [['Lägg till text', addText], ['Lägg till ikon', addIcon], ['Lägg till egen bild', addImage]]) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'ghost'; b.textContent = label;
    b.onclick = () => fn(selected?.el.isConnected ? selected.el : lastPhone);
    row.append(b);
  }
  host.append(row);
}
const addLine = a => a.replaces
  ? `${a.kind === 'text' ? `Ny text "${a.text}"` : a.kind === 'icon' ? `Ny ikon ${a.glyph}` : `Egen bild ${a.name}`} i stället för "${a.replaces}"`
  : `${a.kind === 'text' ? `Ny text "${a.text}"` : a.kind === 'icon' ? `Ny ikon ${a.glyph}` : `Egen bild ${a.name}`} tillagd i ${a.toLabel}`;
