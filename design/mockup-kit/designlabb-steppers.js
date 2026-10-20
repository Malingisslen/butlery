'use strict';
// Every slider in the panel also has a minus and a plus button on its sides and a value you can click and
// type over. The handlers stay the sliders' own: this only sets the range value and sends it an input event.

function enhanceSlider(input) {
  const label = input.closest('label');
  if (!label || input.dataset.stepped) return;
  input.dataset.stepped = '1';
  const val = label.querySelector('.val');
  const step = +input.step || 1, lo = +input.min, hi = +input.max;
  const set = v => {
    const next = Math.min(hi, Math.max(lo, Math.round(v / step) * step));
    input.value = String(+next.toFixed(4));
    input.dispatchEvent(new Event('input', { bubbles: true }));
  };
  const button = (text, title, delta) => {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'ghost step'; b.textContent = text; b.title = title;
    b.onclick = e => { e.preventDefault(); set(+input.value + delta * step); };
    return b;
  };
  input.before(button('−', 'Minska', -1));
  input.after(button('+', 'Öka', 1));
  if (!val) return;
  val.contentEditable = 'true';
  val.spellcheck = false;
  val.title = 'Skriv ett värde och tryck Enter';
  const apply = () => {
    const n = parseFloat(val.textContent.replace(',', '.').replace(/[^\d.-]/g, ''));
    if (Number.isFinite(n)) set(n);
    else input.dispatchEvent(new Event('input', { bubbles: true }));
  };
  val.onkeydown = e => {
    if (e.key === 'Enter') { e.preventDefault(); val.blur(); }
    if (e.key === 'Escape') { e.preventDefault(); val.textContent = ''; val.blur(); }
    e.stopPropagation();
  };
  val.onfocus = () => { const r = document.createRange(); r.selectNodeContents(val); const s = getSelection(); s.removeAllRanges(); s.addRange(r); };
  val.onblur = apply;
}

function enhanceSliders(root = document) {
  root.querySelectorAll?.('.panel input[type=range]').forEach(enhanceSlider);
}

function wireSteppers() {
  enhanceSliders();
  new MutationObserver(muts => {
    for (const m of muts) for (const n of m.addedNodes) if (n.nodeType === 1) enhanceSliders(n);
  }).observe(document.body, { childList: true, subtree: true });
  const clear = document.getElementById('viewspace-clear');
  if (clear) clear.onclick = () => { state.viewSpace = {}; render(); };
}
