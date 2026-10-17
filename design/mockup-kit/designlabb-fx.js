'use strict';
// Effekter tab: pick WHAT an effect applies to (one kind of part, or the part picked in the screens),
// then add effects from the lists. An effect is a set of part props, so the Vald del tab refines it.

const FX_TARGETS = [
  ['@sel', 'Markerad del (klicka på något i skärmarna)'],
  ['.b-btn', 'Alla knappar'], ['.b-btn.hero', 'Stora knappen (Börja laga)'], ['.b-iconbtn', 'Ikonknappar'],
  ['.b-card', 'Kort'], ['.b-row', 'Rader i listor'], ['.b-section', 'Sektioner'], ['.b-chip', 'Chips (taggar)'],
  ['.b-bottomnav', 'Bottenmenyn'], ['.b-bottomnav .tab', 'Flikarna i bottenmenyn'], ['.b-topbar-root', 'Toppfält (huvudflik)'],
  ['.b-topbar-sub', 'Toppfält (undersida)'], ['.b-input', 'Fält'], ['.b-snackbar', 'Snackbar'], ['.b-stepper', 'Portionsväljare'],
  ['.b-switch', 'Brytare'], ['.b-avatar', 'Avatar'], ['.b-band', 'Band'], ['.b-count', 'Räknare'], ['.b-overline', 'Avsnittsrubriker'],
  ['.phone', 'Hela skärmen'],
];
const FX_NONE = { shY: 0, shBlur: 0, shAlpha: 0 };
const FX_GROUPS = [
  ['Skugga', 'skugga', [
    ['Ingen skugga', 'Plattare, grafisk känsla', FX_NONE],
    ['Mjuk skugga', 'Diskret lyft, passar de flesta kort', { shY: 4, shBlur: 14, shAlpha: 18 }],
    ['Tydlig skugga', 'Tydligt lyft från bakgrunden', { shY: 8, shBlur: 20, shAlpha: 30 }],
    ['Hög svävande skugga', 'Stort djup, för det som ligger överst', { shY: 14, shBlur: 32, shAlpha: 22 }],
    ['Hård skugga', 'Skarp och grafisk, som ett klistermärke', { shY: 4, shBlur: 0, shAlpha: 35 }],
  ]],
  ['Form och kant', 'form', [
    ['Skarpa hörn', 'Exakt och allvarligt', { radius: 0 }],
    ['Mjuka hörn', 'Vänligt och lugnt', { radius: 20 }],
    ['Piller', 'Helt runda ändar, bra på knappar och chips', { radius: 40 }],
    ['Tunn kant', '1 px linje, ordnar utan att väga tungt', { bw: 1, bc: '#7d897c' }],
    ['Kraftig kant', '3 px mörk linje, tydlig och teckning-lik', { bw: 3, bc: '#17251d' }],
    ['Kant i saffran', 'Accenten som ram', { bw: 2, bc: '#d68523' }],
    ['Utan kant', 'Tar bort ramen', { bw: 0 }],
  ]],
  ['Glas och ton', 'glas', [
    ['Lätt glas', '80 % täckande, suddar lite bakom', { bgAlpha: 80, blur: 8 }],
    ['Kraftigt glas', '55 % täckande, suddar mer', { bgAlpha: 55, blur: 16 }],
    ['Dämpad', 'Hela delen 70 % synlig, ser avstängd ut', { opacity: 70 }],
    ['Toning till saffran', 'Ytan går över i saffran snett nedåt', { grad: '#d68523', gradAngle: 135 }],
    ['Toning till mörkgrönt', 'Ytan går över i djupgrönt', { grad: '#17251d', gradAngle: 180 }],
  ]],
  ['Rörelse som pågår', 'rorelse', [
    ['Ingen rörelse', 'Stillastående', { anim: '' }],
    ['Pulsera', 'Växer och krymper, drar blicken', { anim: 'pulse', dur: 1.6 }],
    ['Studsa', 'Hoppar upp och ned', { anim: 'bounce', dur: 1.2 }],
    ['Sväva', 'Lugn, nästan som i luften', { anim: 'float', dur: 3.5 }],
    ['Glöd', 'Saffransglöd som tänds och släcks', { anim: 'glow', dur: 2 }],
    ['Skaka', 'Uppmärksamhet, till exempel vid fel', { anim: 'shake', dur: 0.8 }],
    ['Vicka', 'Lekfull sväng fram och tillbaka', { anim: 'wiggle', dur: 1 }],
    ['Blinka mjukt', 'Tonar ut och in', { anim: 'fade', dur: 1.6 }],
    ['Snurra', 'Bra för laddare, mindre för annat', { anim: 'spin', dur: 1.4 }],
  ]],
  ['Vid hovring (dator)', 'hovring', [
    ['Lyft', 'Flyttar upp med skugga', { hover: 'lift' }],
    ['Förstora', 'Växer lite', { hover: 'grow' }],
    ['Glöd', 'Saffransglöd', { hover: 'glow' }],
    ['Ljusna', 'Blir ljusare', { hover: 'bright' }],
    ['Tona ner', 'Blir lite genomskinlig', { hover: 'dim' }],
    ['Ingen hovring', 'Tar bort effekten', { hover: '' }],
  ]],
  ['Vid tryck (telefon)', 'tryck', [
    ['Krymp', 'Blir lite mindre under trycket', { press: 'sink' }],
    ['Tryck ner', 'Flyttas några px nedåt', { press: 'dip' }],
    ['Ingen tryckeffekt', 'Tar bort effekten', { press: '' }],
  ]],
  ['Text', 'typsnitt', [
    ['Versaler med luft', 'STORA BOKSTÄVER med spärrning, bra för små rubriker', { caps: true, tracking: 1.5 }],
    ['Fetare text', 'Tyngre text inne i delen', { labWeight: 700 }],
    ['Luftig text', 'Lite spärrad text, lugnare', { tracking: 0.6 }],
  ]],
];
const FX_COMBOS = [
  ['Mjuk och modern', 'Runda kort med mjuk skugga, pillerknappar', [['.b-card', { radius: 20, shY: 4, shBlur: 14, shAlpha: 18 }], ['.b-btn', { radius: 40 }], ['.b-chip', { radius: 40 }]]],
  ['Skarp och teknisk', 'Inga rundningar, tunna kanter, ingen skugga', [['.b-card', { radius: 0, bw: 1, bc: '#7d897c', ...FX_NONE }], ['.b-btn', { radius: 0 }], ['.b-input', { radius: 0, bw: 1, bc: '#7d897c' }]]],
  ['Lekfull', 'Studsande huvudknapp, chips som växer', [['.b-btn.hero', { anim: 'bounce', dur: 1.2, radius: 40 }], ['.b-chip', { hover: 'grow', press: 'sink' }], ['.b-card', { radius: 24 }]]],
  ['Lugn och dämpad', 'Ingen rörelse, minimala skuggor', [['.b-card', { shY: 2, shBlur: 8, shAlpha: 10 }], ['.b-btn.hero', { anim: '' }]]],
  ['Premium', 'Tunna kanter, diskret skugga, spärrade rubriker', [['.b-card', { bw: 1, bc: '#d3d6c8', shY: 6, shBlur: 20, shAlpha: 12 }], ['.b-overline', { caps: true, tracking: 2 }]]],
  ['Skuggor på alla kort', 'Lyft alla kort lite', [['.b-card', { shY: 6, shBlur: 18, shAlpha: 22 }]]],
  ['Glas på ark och dialoger', 'Halvgenomskinliga ark', [['.b-sheet', { bgAlpha: 70, blur: 12, shY: 8, shBlur: 24, shAlpha: 25 }], ['.b-dialog', { bgAlpha: 70, blur: 12, shY: 8, shBlur: 24, shAlpha: 25 }]]],
  ['Knappar lyfter och krymper', 'Hovring och tryck på alla knappar', [['.b-btn', { hover: 'lift', press: 'sink' }]]],
  ['Glödande stora knappen', 'Saffransglöd på Börja laga', [['.b-btn.hero', { anim: 'glow', dur: 2 }]]],
  ['Svävande kort', 'Korten rör sig mjukt', [['.b-card', { anim: 'float', dur: 3.5, shY: 10, shBlur: 24, shAlpha: 18 }]]],
  ['Rader tonar vid hovring', 'Hovring på listrader', [['.b-row', { hover: 'dim' }]]],
];

function fxTargets() {
  const val = $('fx-target').value;
  if (val === '@sel') {
    if (!selected) return [];
    const mode = selected.mode || (selected.el.closest('.phone').dataset.theme === 'dark' ? 'dark' : 'light');
    return [{ sel: selectorFor(selected.el, false), mode, el: selected.el }];
  }
  return [{ sel: val, mode: 'both', el: document.querySelector(`#screens .phone:not([data-theme="dark"]) ${val === '.phone' ? '' : val}`) || document.querySelector('#screens ' + val) }];
}
function applyFx(list) {
  const targets = fxTargets();
  if (!targets.length) { $('fx-note').textContent = 'Klicka först på en del i skärmarna, eller välj vad effekten ska gälla.'; return; }
  for (const { sel, mode, el } of targets) {
    for (const [s, props] of list || [[null, {}]]) {
      const useSel = s || sel, key = `${mode}|${useSel}`;
      if (mode === 'both' && s && !document.querySelector(`#screens ${s}`)) continue;
      state.parts[key] = { sel: useSel, mode, props: { ...(state.parts[key]?.props || {}), ...props } };
      const base = el && !s ? el : document.querySelector(`#screens .phone:not([data-theme="dark"]) ${useSel}`);
      if (base) partBase[key] ||= { bg: toHex(getComputedStyle(base).backgroundColor) };
    }
  }
  $('fx-note').textContent = '';
  render();
  showFxActive();
}
function applyCombo(list) {
  for (const [sel, props] of list) {
    const key = `both|${sel}`;
    if (!document.querySelector(`#screens ${sel}`)) continue;
    state.parts[key] = { sel, mode: 'both', props: { ...(state.parts[key]?.props || {}), ...props } };
    const base = document.querySelector(`#screens .phone:not([data-theme="dark"]) ${sel}`);
    if (base) partBase[key] ||= { bg: toHex(getComputedStyle(base).backgroundColor) };
  }
  clearSelection();
  render();
  showFxActive();
}
function showFxActive() {
  const box = $('fx-active');
  box.textContent = '';
  const names = Object.fromEntries(FX_TARGETS.map(([s, n]) => [s, n]));
  const entries = Object.entries(state.parts).filter(([, p]) => Object.keys(p.props).length);
  if (!entries.length) { box.innerHTML = '<p class="hint">Inga effekter eller delar är ändrade ännu.</p>'; return; }
  for (const [key, p] of entries) {
    const row = document.createElement('div');
    row.className = 'fx-row';
    const t = document.createElement('span');
    t.textContent = `${names[p.sel] || p.sel}${p.mode === 'both' ? '' : p.mode === 'dark' ? ' (mörkt)' : ' (ljust)'}: ${Object.keys(p.props).length} inställningar`;
    const x = document.createElement('button');
    x.type = 'button'; x.className = 'ghost'; x.textContent = 'Ta bort';
    x.onclick = () => { delete state.parts[key]; render(); showFxActive(); };
    row.append(t, x);
    box.append(row);
  }
}
function wireEffects() {
  const sel = $('fx-target');
  for (const [v, label] of FX_TARGETS) sel.append(new Option(label, v));
  sel.value = '.b-btn';
  const combos = $('fx-combos');
  for (const [name, hint, list] of FX_COMBOS) {
    const b = document.createElement('button');
    b.type = 'button'; b.title = hint; b.dataset.advice = 'skugga';
    b.innerHTML = `<b></b><small></small>`;
    b.firstChild.textContent = name; b.lastChild.textContent = hint;
    b.onclick = () => applyCombo(list);
    combos.append(b);
  }
  for (const [title, topic, items] of FX_GROUPS) {
    const h = document.createElement('h2');
    h.textContent = title;
    const wrap = document.createElement('div');
    wrap.className = 'chips fxlist';
    for (const [name, hint, props] of items) {
      const b = document.createElement('button');
      b.type = 'button'; b.dataset.advice = topic; b.title = hint;
      b.innerHTML = '<b></b><small></small>';
      b.firstChild.textContent = name; b.lastChild.textContent = hint;
      b.onclick = () => applyFx([[null, props]]);
      wrap.append(b);
    }
    $('fx-groups').append(h, wrap);
  }
  $('fx-clear').onclick = () => {
    for (const { sel: s, mode } of fxTargets()) for (const k of Object.keys(state.parts)) if (k === `${mode}|${s}` || (mode !== 'both' && k.endsWith('|' + s))) delete state.parts[k];
    clearSelection(); render(); showFxActive();
  };
  $('fx-reset').onclick = () => { state.parts = {}; clearSelection(); render(); showFxActive(); };
  $('pause').onchange = e => { state.pause = e.target.checked; render(); };
  showFxActive();
}
