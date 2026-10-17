'use strict';
// Numbered pins with a note on a part of a screen. The notes go to the developer with the rest of
// the changes, so "make this feel calmer" can sit on the exact part it is about.

let noteMode = false;
function labelOf(el) {
  const text = (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 28);
  const cls = [...el.classList].find(c => c.startsWith('b-'));
  return `${cls ? COMPONENT_NAMES[cls] || cls.slice(2) : el.tagName.toLowerCase()}${text ? ` "${text}"` : ''}`;
}
function drawPins() {
  document.querySelectorAll('.lab-pin').forEach(n => n.remove());
  (state.notes || []).forEach((n, i) => {
    for (const phone of document.querySelectorAll('#screens .phone')) {
      const el = phone.querySelector(`[data-lab-id="${n.id}"]`);
      if (!el) continue;
      const base = phone.getBoundingClientRect(), r = el.getBoundingClientRect();
      if (!r.width && !r.height) continue;
      const pin = document.createElement('div');
      pin.className = 'lab-pin';
      pin.textContent = i + 1;
      pin.style.cssText = `left:${r.right - base.left - 9}px;top:${r.top - base.top - 9}px`;
      phone.append(pin);
    }
  });
}
function renderNotes() {
  const box = document.getElementById('notes');
  box.textContent = '';
  (state.notes || []).forEach((n, i) => {
    const row = document.createElement('div');
    row.className = 'note-row';
    const head = document.createElement('div');
    head.className = 'hint';
    head.textContent = `${i + 1}. ${n.label}`;
    const input = document.createElement('input');
    input.type = 'text'; input.value = n.text; input.placeholder = 'Skriv vad du vill att utvecklaren ska veta';
    input.oninput = () => { n.text = input.value; render(); };
    const del = document.createElement('button');
    del.type = 'button'; del.className = 'ghost'; del.textContent = 'Ta bort';
    del.onclick = () => { state.notes.splice(i, 1); renderNotes(); render(); };
    row.append(head, input, del);
    box.append(row);
  });
}
function wireNotes() {
  const add = document.getElementById('note-add');
  add.onclick = () => {
    noteMode = !noteMode;
    add.textContent = noteMode ? 'Klicka nu på en del i en skärm (klicka här för att avbryta)' : 'Sätt en nål: klicka på en del i en skärm';
    document.getElementById('screens').classList.toggle('lab-noting', noteMode);
  };
  document.getElementById('screens').addEventListener('click', e => {
    if (!noteMode) return;
    const el = componentOf(e.target);
    if (!el?.dataset.labId) return;
    e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
    (state.notes ||= []).push({ id: el.dataset.labId, label: labelOf(el), text: '' });
    add.click();
    renderNotes();
    render();
    document.querySelector('#notes .note-row:last-child input')?.focus();
  }, true);
  renderNotes();
}
