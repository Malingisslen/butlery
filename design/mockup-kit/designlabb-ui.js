'use strict';
// The panel of designlabb.html: tabs, search, global controls, saved variants and the
// side-by-side compare. State, CSS and undo live in designlabb-core.js, the click-to-edit part
// editor in designlabb-parts.js.

const $ = id => document.getElementById(id);
const SLIDERS = {
  scale: ' %', lh: '', card: ' px', control: ' px', margin: ' px', hue: '°', sat: ' %', light: ' %',
  space: ' %', rowPad: ' px', sectionGap: ' px', blockGap: ' px', chipGap: ' px', rowInner: ' px', hair: ' px', touch: ' px', iconSize: ' %', iconStroke: '',
};
const ORIGINAL_AT = { lh: 100, blockGap: 0, iconStroke: 0 };
const VARIANTS_KEY = 'butlery-designlabb-variants';

// Each screen is written once; its dark copy is cloned next to it.
assignLayoutIds();
for (const fig of [...document.querySelectorAll('#screens > figure')]) {
  const dark = fig.cloneNode(true);
  fig.classList.add('fig-light');
  dark.classList.add('fig-dark');
  dark.querySelector('.phone').dataset.theme = 'dark';
  fig.after(dark);
}
snapshotLayoutBase();

// A script-made <style> element can be refused by a page policy that only trusts the page's own
// inline styles; a constructed stylesheet is set through the CSSOM and is not checked that way.
function labSheet() {
  if (document.adoptedStyleSheets && window.CSSStyleSheet?.prototype.replaceSync) {
    const sheet = new CSSStyleSheet();
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
    return { set text(css) { sheet.replaceSync(css); }, set disabled(v) { sheet.disabled = v; } };
  }
  const el = document.createElement('style');
  document.head.append(el);
  return { set text(css) { el.textContent = css; }, set disabled(v) { el.disabled = v; } };
}
const lab = labSheet(), labA = labSheet(), labB = labSheet();
let compare = null; // { name, state } while two states are shown side by side

function render() {
  if (typeof mirrorThemes === 'function') mirrorThemes();
  lab.disabled = !!compare;
  lab.text = buildCss(state);
  $('out').value = summary(state);
  renderModular();
  if (compare) {
    labA.text = buildCss(state, '.cmpA');
    labB.text = buildCss(compare.state, '.cmpB');
  } else {
    contrast();
  }
  applyIcons();
  drawOverlay();
  applyViewTools();
  markSliders();
  drawPins();
  if (typeof drawHandles === 'function') drawHandles();
  shareNow();
  refreshAdvice();
  scheduleSnapshot();
  try {
    window.history.replaceState(null, '', summary(state) ? '#' + btoa(unescape(encodeURIComponent(JSON.stringify(state, (k, v) => (k === 'src' ? undefined : v))))) : location.pathname + location.search);
  } catch {}
}

// Text pairs that carry reading: WCAG AA wants 4.5:1 for body text.
const PAIRS = [
  ['text-primary', 'surface-base'], ['text-secondary', 'surface-base'], ['text-body', 'surface-raised'],
  ['text-link', 'surface-base'], ['text-danger', 'surface-base'], ['text-on-action-fill', 'action-fill'],
  ['text-on-action-primary', 'action-primary'], ['text-accent-on-ink', 'surface-ink'],
];
function rgbOf(phone, token, prop) {
  const probe = document.createElement('span');
  probe.style[prop] = `var(--butlery-${token})`;
  phone.append(probe);
  const c = getComputedStyle(probe)[prop];
  probe.remove();
  return (c.match(/[\d.]+/g) || []).slice(0, 3).map(Number);
}
const lum = ([r, g, b]) => [r, g, b].map(v => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)
  .reduce((a, v, i) => a + v * [0.2126, 0.7152, 0.0722][i], 0);
function contrast() {
  const box = $('contrast');
  box.textContent = '';
  const phones = document.querySelectorAll('#screens .phone');
  for (const phone of [phones[0], [...phones].find(p => p.dataset.theme === 'dark')]) {
    const mode = phone.dataset.theme === 'dark' ? 'mörkt' : 'ljust';
    for (const [fg, bg] of PAIRS) {
      const a = rgbOf(phone, fg, 'color'), b = rgbOf(phone, bg, 'backgroundColor');
      if (a.length < 3 || b.length < 3) continue;
      const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
      const ratio = (hi + 0.05) / (lo + 0.05);
      [`${fg} på ${bg} (${mode})`, ratio.toFixed(1) + ':1', ratio >= 4.5 ? 'ok' : 'för svag'].forEach((txt, i) => {
        const el = document.createElement('span');
        el.textContent = txt;
        if (i === 2) el.className = ratio >= 4.5 ? 'ok' : 'bad';
        box.append(el);
      });
    }
  }
}

const fontSel = $('font');
for (const f of Object.keys(FONTS)) fontSel.add(new Option(f, f));
function loadFont() {
  for (const name of [state.font, state.fontHead]) {
    const q = FONTS[name];
    if (q && !document.getElementById('gf-' + q)) {
      const l = document.createElement('link');
      l.id = 'gf-' + q; l.rel = 'stylesheet';
      l.href = `https://fonts.googleapis.com/css2?family=${q}&display=swap`;
      document.head.append(l);
    }
  }
}
fontSel.onchange = () => { state.font = fontSel.value; loadFont(); render(); };

function showValue(id) {
  $(id + '-v').textContent = id in ORIGINAL_AT && state[id] === ORIGINAL_AT[id] ? 'orig' : state[id] + SLIDERS[id];
}
for (const id of Object.keys(SLIDERS)) {
  $(id).oninput = () => { state[id] = +$(id).value; showValue(id); markSliders(); render(); };
  const rst = document.createElement('button');
  rst.type = 'button'; rst.className = 'rst'; rst.textContent = '↺'; rst.title = 'Återställ till original'; rst.hidden = true;
  rst.onclick = () => { state[id] = defaults()[id]; $(id).value = state[id]; showValue(id); markSliders(); render(); };
  $(id).closest('label').append(rst);
}
function markSliders() {
  for (const id of Object.keys(SLIDERS)) $(id).closest('label').querySelector('.rst').hidden = state[id] === defaults()[id];
}

const roleInputs = [];
for (const [role, px] of sizes) {
  const row = document.createElement('div');
  row.className = 'role';
  const name = document.createElement('span');
  name.textContent = role;
  const size = document.createElement('input');
  size.type = 'range'; size.min = 8; size.max = 56; size.step = 0.5; size.value = px; size.title = `${px} px`;
  const weight = document.createElement('select');
  for (const w of [400, 600, 700]) weight.add(new Option(w, w));
  weight.value = weights.get(role);
  size.oninput = () => { (state.roles[role] ||= {}).size = +size.value; size.title = size.value + ' px'; render(); };
  weight.onchange = () => { (state.roles[role] ||= {}).weight = +weight.value; render(); };
  roleInputs.push({ role, size, weight });
  row.append(name, size, weight);
  $('roles').append(row);
}

const pickers = [];
const colorRows = [...used.entries()]
  .map(([hex, uses]) => ({ hex, uses: uses.length, label: (paletteNames.get(hex) || [uses[0].name.replace('--butlery-', '')])[0] }))
  .sort((a, b) => b.uses - a.uses);
for (const { hex, uses, label } of colorRows) {
  const row = document.createElement('label');
  const text = document.createElement('span');
  text.textContent = `${label} · ${uses}`;
  const input = document.createElement('input');
  input.type = 'color'; input.value = hex;
  input.oninput = () => {
    if (input.value.toLowerCase() === hex) delete state.colors[hex]; else state.colors[hex] = input.value;
    text.classList.toggle('changed', hex in state.colors);
    render();
  };
  pickers.push({ input, hex, text });
  row.append(text, input);
  $('colors').append(row);
}

// Push the state into every control, so presets, undo, variants and a shared link use one path.
function syncUi() {
  fontSel.value = state.font;
  syncRoles();
  if (typeof renderNotes === 'function' && $('notes')) renderNotes();
  $('font-head').value = state.fontHead || '';
  $('type-ratio').value = state.typeRatio || '';
  for (const id of Object.keys(SLIDERS)) { $(id).value = state[id]; showValue(id); }
  for (const { role, size, weight } of roleInputs) {
    size.value = state.roles[role]?.size ?? sizes.get(role);
    weight.value = state.roles[role]?.weight ?? weights.get(role);
  }
  for (const { input, hex, text } of pickers) {
    input.value = state.colors[hex] ?? hex;
    text.classList.toggle('changed', hex in state.colors);
  }
  $('pause').checked = state.pause;
  $('icon-style').value = state.iconStyle;
  $('icon-lib').value = state.iconLib;
  $('overlay').checked = state.overlay;
  replayLayout();
  showMoves();
  loadFont();
  clearSelection();
  render();
}
function updateHistoryButtons() {
  $('undo').disabled = undoLog.i === 0;
  $('redo').disabled = undoLog.i >= undoLog.stack.length - 1;
}


// Each pane heading becomes a fold-out section; only the first one in a pane starts open.
function foldSections() {
  for (const pane of document.querySelectorAll('.pane[data-pane]')) {
    if (pane.dataset.pane === 'part') continue;
    let cur = null, n = 0;
    for (const el of [...pane.children]) {
      if (el.tagName === 'H2') {
        cur = document.createElement('details'); cur.className = 'sec'; cur.open = n++ === 0;
        const sm = document.createElement('summary'); pane.insertBefore(cur, el); sm.append(el); cur.append(sm);
      } else if (cur) cur.append(el);
    }
  }
}
foldSections();

// ---- Tabs and search ----
function openTab(name) {
  for (const b of document.querySelectorAll('#tabs button, #check-open')) b.classList.toggle('on', b.dataset.tab === name);
  for (const p of document.querySelectorAll('.pane')) p.hidden = !!$('search').value ? false : p.dataset.pane !== name;
}
function applySearch() {
  const q = $('search').value.trim().toLowerCase();
  for (const el of document.querySelectorAll('.pane label, .pane .role, .pane .chips button, .pane details')) {
    const hit = !q || (el.dataset.kw || '').includes(q) || el.textContent.toLowerCase().includes(q);
    el.hidden = !hit;
    if (q && el.tagName === 'DETAILS' && hit) el.open = true;
  }
  openTab(document.querySelector('#tabs button.on, #check-open.on')?.dataset.tab || 'all');
}
for (const b of document.querySelectorAll('#tabs button, #check-open')) b.onclick = () => { $('search').value = ''; applySearch(); openTab(b.dataset.tab); };
$('search').oninput = applySearch;

// ---- Saved variants and compare ----
let variants = [];
try { variants = JSON.parse(localStorage.getItem(VARIANTS_KEY) || '[]'); } catch {}
normalizeVariants();
// Saved versions live in this browser and, when the page can reach the shared store, in the artifact's database too.
const variantDb = () => (typeof claudeAi !== 'undefined' ? claudeAi.db : null);
// The id is derived from the save time, so the same version saved in two places is recognised as one.
function variantKey(v) { return `${v.name}|${JSON.stringify({ ...defaults(), ...v.state })}`; }
function stableAt(v) {
  let h = 7;
  for (const c of variantKey(v)) h = (h * 31 + c.charCodeAt(0)) % 1000000007;
  return h;
}
function normalizeVariants() {
  const seen = new Set();
  variants = variants.filter(v => {
    v.state = { ...defaults(), ...v.state };
    v.base ||= LAB_BASE;
    v.orig = { ...defaults(), ...(v.orig || {}) };
    v.at ||= stableAt(v);
    v.id = 'v' + v.at;
    const key = variantKey(v);
    if (seen.has(v.id) || seen.has(key)) return false;
    seen.add(v.id); seen.add(key);
    return true;
  });
}
function saveVariants() {
  normalizeVariants();
  try { localStorage.setItem(VARIANTS_KEY, JSON.stringify(variants)); } catch {}
  const db = variantDb();
  if (db) for (const v of variants) {
    db.doc(`variants/${v.id}`).set({ name: v.name, at: v.at, base: v.base, json: JSON.stringify(v.state), orig: JSON.stringify(v.orig) }).catch(() => {});
  }
  renderVariants();
}
function renderVariantSelect() {
  const sel = $('ver-select');
  sel.textContent = '';
  sel.add(new Option(variants.length ? 'Öppna version …' : 'Inga sparade versioner än', ''));
  variants.forEach((v, i) => sel.add(new Option(v.name + (v.at > 1e11 ? ' · ' + new Date(v.at).toLocaleString('sv-SE', { dateStyle: 'short', timeStyle: 'short' }) : ''), String(i))));
  sel.disabled = !variants.length;
}
function renderVariants() {
  renderVariantSelect();
  const box = $('variants');
  box.textContent = '';
  if (!variants.length) box.innerHTML = '<p class="hint">Inga sparade varianter än. Spara det du har nu, ändra vidare och jämför.</p>';
  variants.forEach((v, i) => {
    const row = document.createElement('div');
    row.className = 'variant';
    const name = document.createElement('input');
    name.type = 'text'; name.value = v.name;
    name.onchange = () => { v.name = name.value; saveVariants(); };
    const summaryEl = document.createElement('div');
    summaryEl.className = 'hint';
    const s = v.state;
    summaryEl.textContent = [s.font !== 'ButlerySans' && s.font, s.hue && `nyans ${s.hue}°`, s.sat !== 100 && `mättnad ${s.sat} %`,
      s.card !== 12 && `kort ${s.card} px`, s.control !== 8 && `knappar ${s.control} px`, s.scale !== 100 && `text ${s.scale} %`, Object.keys(s.parts || {}).length && `${Object.keys(s.parts).length} delar`, Object.keys(s.colors).length && `${Object.keys(s.colors).length} färger`]
      .filter(Boolean).join(' · ') || 'originalet';
    if (v.at > 1e11) summaryEl.textContent += ` · sparad ${new Date(v.at).toLocaleString('sv-SE', { dateStyle: 'short', timeStyle: 'short' })}`;
    const actions = document.createElement('div');
    actions.className = 'row';
    for (const [label, fn] of [
      ['Använd', () => openVersion(v)],
      ['Jämför', () => startCompare(v)],
      ['Ta bort', () => { const [gone] = variants.splice(i, 1); if (gone.id) variantDb()?.doc(`variants/${gone.id}`).delete().catch(() => {}); saveVariants(); }],
    ]) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'ghost'; b.textContent = label; b.onclick = fn; actions.append(b);
    }
    row.append(name, summaryEl, actions);
    box.append(row);
  });
}
const FIELD_NAMES = { font: 'Typsnitt', fontHead: 'Rubrikfont', typeRatio: 'Textskala', scale: 'Textstorlek', lh: 'Radavstånd', card: 'Kort och ark', control: 'Knappar och fält', margin: 'Sidmarginal', hue: 'Nyans', sat: 'Mättnad', light: 'Ljushet', space: 'Avståndsskala', rowPad: 'Luft i rader', sectionGap: 'Mellan avsnitt', blockGap: 'Mellan block', chipGap: 'Mellan knappar och chips', rowInner: 'Ikon till text i rad', hair: 'Skiljelinjer', touch: 'Minsta träffyta', iconSize: 'Ikonstorlek', iconStroke: 'Linjetjocklek', iconStyle: 'Linjeändar', iconLib: 'Ikonbibliotek' };
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
// Opens a saved version on top of the CURRENT original: what the version did not change follows the original,
// and a value the original has moved since the version was saved is not pulled back.
function openVersion(v) {
  const now = defaults();
  const next = clone(now);
  const skipped = [], lostColors = [];
  const known = new Set(pickers.map(p => p.hex.toLowerCase()));
  for (const [k, mine] of Object.entries(v.state)) {
    const was = v.orig[k];
    if (!(k in now) || same(mine, was)) continue;
    if (k === 'colors') {
      next.colors = {};
      for (const [hex, to] of Object.entries(mine)) (known.has(hex.toLowerCase()) ? next.colors : lostColors)[hex] = to;
      continue;
    }
    if (same(was, now[k])) next[k] = clone(mine);
    else skipped.push({ k, mine, was, now: now[k] });
  }
  state = next;
  stopCompare(); syncUi();
  showVersionNote(v, skipped, Object.keys(lostColors));
}
function showVersionNote(v, skipped, lostColors) {
  const box = $('ver-note');
  box.textContent = '';
  if (!skipped.length && !lostColors.length) { box.hidden = true; return; }
  const p = document.createElement('div');
  p.textContent = `"${v.name}" sparades mot ett äldre original. Det nya originalet behölls för:`;
  const ul = document.createElement('ul');
  for (const s of skipped) {
    const li = document.createElement('li');
    li.textContent = `${FIELD_NAMES[s.k] || s.k}: originalet är nu ${s.now}, din version ville ha ${s.mine}`;
    ul.append(li);
  }
  for (const hex of lostColors) {
    const li = document.createElement('li');
    li.textContent = `Färgen ${hex} finns inte längre i appen, så den ändringen hoppades över`;
    ul.append(li);
  }
  const row = document.createElement('div'); row.className = 'row';
  if (skipped.length) {
    const keep = document.createElement('button');
    keep.type = 'button'; keep.className = 'ghost'; keep.textContent = 'Ta med mina värden ändå';
    keep.onclick = () => { for (const s of skipped) state[s.k] = clone(s.mine); box.hidden = true; syncUi(); };
    row.append(keep);
  }
  const ok = document.createElement('button');
  ok.type = 'button'; ok.className = 'ghost'; ok.textContent = 'Stäng'; ok.onclick = () => { box.hidden = true; };
  row.append(ok);
  box.append(p, ul, row);
  box.hidden = false;
}
function addVariant(btn) {
  variants.push({ name: `Version ${variants.length + 1}`, at: Date.now(), base: LAB_BASE, orig: clone(defaults()), state: clone(state) });
  saveVariants();
  if (btn) { const old = btn.textContent; btn.textContent = 'Sparad'; setTimeout(() => { btn.textContent = old; }, 1500); }
}
$('save-variant').onclick = e => addVariant(e.currentTarget);
$('ver-save').onclick = e => addVariant(e.currentTarget);
$('ver-select').onchange = e => {
  const v = variants.find((x, i) => String(i) === e.target.value);
  if (v) openVersion(v);
  e.target.value = '';
};
// Called once the shared store is reachable: pulls in versions saved from other browsers.
async function loadVariantsFromDb() {
  const db = variantDb();
  if (!db) return;
  try {
    const snap = await db.collection('variants').get();
    for (const d of snap.docs) {
      const data = typeof d.data === 'function' ? d.data() : d.data;
      if (!data?.json) continue;
      let incoming = { name: data.name, at: data.at, base: data.base, orig: data.orig ? JSON.parse(data.orig) : undefined, state: { ...defaults(), ...JSON.parse(data.json) } };
      const twin = variants.find(v => v.at === data.at || variantKey(v) === variantKey(incoming));
      if (twin) { if (twin.id !== d.id) db.doc(`variants/${d.id}`).delete().catch(() => {}); continue; }
      variants.push(incoming);
    }
    variants.sort((a, b) => (a.at || 0) - (b.at || 0));
    saveVariants();
  } catch { /* the local list still works */ }
}

// The saved version's own structure (added, copied, moved and rewritten parts), built on the pristine
// screens and put back at once, so Jämför shows the version and not today's layout under its colours.
function layoutFigureFor(st, index) {
  const live = $('screens').innerHTML, liveState = state;
  try {
    $('screens').innerHTML = layoutBase;
    state = { ...state, texts: st.texts || {} };
    for (const a of st.adds || []) applyAdd(a);
    for (const c of st.copies || []) applyCopy(c);
    for (const m of st.moves || []) applyMove(m);
    applyTexts();
    return $('screens').children[index]?.cloneNode(true) || null;
  } finally {
    $('screens').innerHTML = live;
    state = liveState;
  }
}
const cmpScreen = $('cmp-screen');
function buildCompare() {
  const wrap = $('compare-grid');
  wrap.textContent = '';
  const figs = [...document.querySelectorAll('#screens > figure')];
  const i = +cmpScreen.value * 2;
  for (const [scope, title] of [['cmpA', 'Nu'], ['cmpB', compare.name]]) {
    const col = document.createElement('div');
    col.className = scope;
    const h = document.createElement('h2');
    h.textContent = title;
    col.append(h);
    const row = document.createElement('div');
    row.className = 'screens';
    for (const f of [scope === 'cmpB' ? layoutFigureFor(compare.state, i + +$('cmp-mode').value) || figs[i + +$('cmp-mode').value] : figs[i + +$('cmp-mode').value]]) {
      const c = f.cloneNode(true);
      c.querySelectorAll('[data-lab-selected],[data-lab-hover]').forEach(n => { n.removeAttribute('data-lab-selected'); n.removeAttribute('data-lab-hover'); });
      row.append(c);
    }
    col.append(row);
    wrap.append(col);
  }
}
function startCompare(v) {
  compare = { name: v.name, state: clone(v.state) };
  $('screens').hidden = true;
  $('compare').hidden = false;
  buildCompare();
  render();
}
function stopCompare() {
  compare = null;
  $('screens').hidden = false;
  $('compare').hidden = true;
  render();
}
$('cmp-mode').onchange = () => compare && buildCompare();
cmpScreen.onchange = () => compare && buildCompare() || render();
$('cmp-close').onclick = stopCompare;

// ---- Spacing, icons and layout tabs, and the hand-off to the app ----
function wireExtras() {
  for (const [v, l] of ICON_STYLES) $('icon-style').add(new Option(l, v));
  for (const [key, lib] of Object.entries(ICON_LIBS)) $('icon-lib').add(new Option(lib.label, key));
  $('icon-style').onchange = () => { state.iconStyle = $('icon-style').value; render(); };
  $('icon-lib').onchange = () => { state.iconLib = $('icon-lib').value; render(); };
  $('overlay').onchange = () => { state.overlay = $('overlay').checked; render(); };
  $('spacedrag').onchange = () => { spaceDrag = $('spacedrag').checked; $('spacesize').hidden = !spaceDrag; render(); };
  for (const b of $('spacesize').querySelectorAll('button')) {
    b.onclick = () => {
      spaceBig = b.dataset.size === 'big';
      for (const o of $('spacesize').querySelectorAll('button')) o.classList.toggle('on', o === b);
      render();
    };
  }
  wireSpaceDrag();
  for (const [name, patch] of Object.entries(SPACE_PRESETS)) {
    const b = document.createElement('button');
    b.type = 'button'; b.textContent = name;
    b.onclick = () => { Object.assign(state, { ...SPACE_DEFAULTS, overlay: state.overlay, iconStyle: state.iconStyle, iconLib: state.iconLib, iconSize: state.iconSize, iconStroke: state.iconStroke }, patch); syncUi(); };
    $('space-presets').append(b);
  }
  $('clear-moves').onclick = () => { state.moves = []; state.free = {}; state.removed = {}; state.copies = []; state.adds = []; state.texts = {}; replayLayout(); showMoves(); render(); };
  wireLayout();
  wireEdit();
  $('apply').onclick = async () => {
    const text = `Lägg in detta i appen (från designlabbet). Länk till labbet: ${location.href}\n\n${summary(state) || '(inga ändringar)'}\n\nByggregel: ${HANDOFF_RULE}`;
    try { await navigator.clipboard.writeText(text); } catch { $('out').value = text; $('out').select(); document.execCommand('copy'); }
    $('apply').textContent = 'Kopierat. Klistra in i tråden';
    setTimeout(() => { $('apply').textContent = 'Spara och för in i appen'; }, 3000);
  };
}

// ---- Footer and history ----
$('undo').onclick = () => stepHistory(-1);
$('redo').onclick = () => stepHistory(1);
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') clearSelection();
  const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName) && document.activeElement.type !== 'range';
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z' && !typing) {
    e.preventDefault();
    stepHistory(e.shiftKey ? 1 : -1);
  }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y' && !typing) {
    e.preventDefault();
    stepHistory(1);
  }
});
$('reset').onclick = () => { state = defaults(); stopCompare(); clearSelection(); replayLayout(); syncUi(); showMoves(); };
for (const [ev, off] of [['pointerdown', true], ['pointerup', false], ['pointerleave', false]]) {
  $('hold').addEventListener(ev, () => { lab.disabled = off && !compare; });
}
$('copy').onclick = async () => {
  const out = $('out');
  out.select();
  try { await navigator.clipboard.writeText(out.value); } catch { document.execCommand('copy'); }
};

wireNotes();
wireRoles();
wireScreens();
wireViewTools();
wireType();
wireEffects();
wireExtras();
wireAdvice();
for (const b of document.querySelectorAll('#viewbar button')) {
  b.onclick = () => {
    $('screens').className = `screens ${b.dataset.view === 'both' ? '' : 'only-' + b.dataset.view}`;
    document.querySelectorAll('#viewbar button').forEach(x => x.classList.toggle('on', x === b));
    render();
  };
}
document.querySelector('#viewbar [data-view="light"]').classList.add('on');
renderVariants();
if (location.hash.length > 1) {
  try { state = { ...defaults(), ...JSON.parse(decodeURIComponent(escape(atob(location.hash.slice(1))))) }; undoLog.stack[0] = JSON.stringify(state); } catch {}
}
openTab('all');
syncUi();
initClaude();
