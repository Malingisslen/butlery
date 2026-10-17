'use strict';
// "Se som" bar above the screens: how the design looks to people who see or use the app differently
// (colour vision, larger system text, other screen sizes, reduced motion) plus a grid and Alt-hover
// measuring. Pure viewing aids: nothing here is part of the state that goes into the app.

const SEE = { vision: '', text: 100, device: '360x800', motion: false, grid: 0, safe: false };
const VISION = [['', 'Vanlig syn'], ['protan', 'Rödblind (protanopi)'], ['deutan', 'Grönblind (deuteranopi)'], ['tritan', 'Blågul-blind (tritanopi)'], ['gray', 'Gråskala'], ['blur', 'Dimsyn']];
const TEXT_SIZES = [100, 125, 150, 200];
const DEVICES = [['360x800', 'Telefon, 360 × 800'], ['320x568', 'Liten telefon, 320 × 568'], ['412x915', 'Stor telefon, 412 × 915'], ['768x1024', 'Surfplatta, 768 × 1024'], ['800x360', 'Liggande, 800 × 360']];
let labView = null;

function injectFilters() {
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('width', 0); svg.setAttribute('height', 0); svg.style.position = 'absolute';
  const mats = {
    protan: '0.567 0.433 0 0 0 0.558 0.442 0 0 0 0 0.242 0.758 0 0 0 0 0 1 0',
    deutan: '0.625 0.375 0 0 0 0.7 0.3 0 0 0 0 0.3 0.7 0 0 0 0 0 1 0',
    tritan: '0.95 0.05 0 0 0 0 0.433 0.567 0 0 0 0.475 0.525 0 0 0 0 0 1 0',
  };
  for (const [id, values] of Object.entries(mats)) {
    const f = document.createElementNS(NS, 'filter');
    f.id = `lab-see-${id}`;
    const m = document.createElementNS(NS, 'feColorMatrix');
    m.setAttribute('type', 'matrix'); m.setAttribute('values', values);
    f.append(m); svg.append(f);
  }
  document.body.append(svg);
}

function viewCss() {
  let css = '';
  const f = { protan: 'url(#lab-see-protan)', deutan: 'url(#lab-see-deutan)', tritan: 'url(#lab-see-tritan)', gray: 'grayscale(1)', blur: 'blur(1.6px)' }[SEE.vision];
  if (f) css += `#screens .phone{filter:${f} !important}`;
  if (SEE.text !== 100) {
    const k = SEE.text / 100, vars = [];
    for (const [role, px] of sizes) vars.push(`--butlery-type-${role}-size:${+((state.roles[role]?.size ?? px * state.scale / 100) * k).toFixed(2)}px`);
    css += `#screens .phone{${vars.join(';')}}`;
  }
  const [w, h] = SEE.device.split('x').map(Number);
  if (SEE.device !== '360x800') css += `#screens .phone{width:${w}px !important;height:${h}px !important}`;
  if (SEE.motion) css += '#screens .phone, #screens .phone *{animation:none !important;transition:none !important}';
  return css;
}

function markClipped() {
  document.querySelectorAll('[data-lab-clip]').forEach(n => n.removeAttribute('data-lab-clip'));
  const note = document.getElementById('see-note');
  if (!note) return;
  if (SEE.text === 100 && SEE.device === '360x800') { note.textContent = ''; return; }
  let n = 0;
  for (const el of document.querySelectorAll('#screens .phone:not([data-theme="dark"]) *')) {
    if (el.closest('.lab-handles') || !el.firstChild || ![...el.childNodes].some(c => c.nodeType === 3 && c.textContent.trim())) continue;
    const cs = getComputedStyle(el);
    const clipsX = el.scrollWidth > el.clientWidth + 1 && cs.overflowX !== 'visible';
    const clipsY = el.scrollHeight > el.clientHeight + 2 && cs.overflowY !== 'visible' && cs.overflowY !== 'auto';
    if (clipsX || clipsY) { el.setAttribute('data-lab-clip', ''); n++; }
  }
  note.textContent = n ? `${n} ställen där text klipps eller tränger ut (markerade med röd ram).` : 'Ingen text klipps i det här läget.';
}

function drawGrid() {
  document.querySelectorAll('.lab-grid, .lab-safe').forEach(n => n.remove());
  for (const phone of document.querySelectorAll('#screens .phone')) {
    if (SEE.grid) {
      const g = document.createElement('div');
      g.className = 'lab-grid';
      g.style.backgroundSize = `${SEE.grid}px ${SEE.grid}px`;
      phone.append(g);
    }
    if (SEE.safe) {
      for (const [cls, h] of [['top', 47], ['bottom', 34]]) {
        const z = document.createElement('div');
        z.className = `lab-safe ${cls}`;
        z.style.height = `${h}px`;
        phone.append(z);
      }
    }
  }
}

function applyViewTools() {
  labView ||= labSheet();
  labView.text = viewCss();
  drawGrid();
  requestAnimationFrame(markClipped);
}

function wireViewTools() {
  injectFilters();
  const fill = (id, list, key, num) => {
    const sel = document.getElementById(id);
    for (const [v, l] of list) sel.add(new Option(l, v));
    sel.value = SEE[key];
    sel.onchange = () => { SEE[key] = num ? +sel.value : sel.value; applyViewTools(); };
  };
  fill('see-vision', VISION, 'vision');
  fill('see-text', TEXT_SIZES.map(v => [v, `Systemtext ${v} %`]), 'text', true);
  fill('see-device', DEVICES, 'device');
  fill('see-grid', [[0, 'Inget rutnät'], [4, 'Rutnät 4 px'], [8, 'Rutnät 8 px']], 'grid', true);
  document.getElementById('see-motion').onchange = e => { SEE.motion = e.target.checked; applyViewTools(); };
  document.getElementById('see-safe').onchange = e => { SEE.safe = e.target.checked; applyViewTools(); };
  document.getElementById('see-reset').onclick = () => {
    Object.assign(SEE, { vision: '', text: 100, device: '360x800', motion: false, grid: 0, safe: false });
    for (const [id, key] of [['see-vision', 'vision'], ['see-text', 'text'], ['see-device', 'device'], ['see-grid', 'grid']]) document.getElementById(id).value = SEE[key];
    document.getElementById('see-motion').checked = false;
    document.getElementById('see-safe').checked = false;
    applyViewTools();
  };
  // Alt over a part shows the distances to its neighbours and to the screen edges, like Figma.
  const screens = document.getElementById('screens');
  const clearMeasure = () => document.querySelectorAll('.lab-gap.measure').forEach(n => n.remove());
  screens.addEventListener('mousemove', e => {
    if (!e.altKey) { if (screens.dataset.measuring) { clearMeasure(); delete screens.dataset.measuring; } return; }
    const el = componentOf(e.target);
    if (!el || screens.dataset.measuring === el.dataset.labId) return;
    screens.dataset.measuring = el.dataset.labId || '1';
    clearMeasure();
    showFreeGaps(el, 'measure');
  });
  window.addEventListener('keyup', e => { if (e.key === 'Alt') { clearMeasure(); delete screens.dataset.measuring; } });
}
