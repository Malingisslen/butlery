'use strict';
// The Råd box: topic cards (what, pros, cons, rule, key figures, mistakes, source), a live check
// of the lab's current values against each topic, a summary of all checks, a glossary and a
// search. Every card can hand its topic to the Claude chat, and Claude can read and open topics.

for (const [id, more] of Object.entries(ADVICE_MORE)) Object.assign(ADVICE[id], more);
let adviceTopic = null;
let adviceQuery = '';
let adviceAll = false;

const partsWith = test => Object.values(state.parts).filter(p => test(p.props));
const px = (v, d = 0) => `${+v.toFixed(d)} px`;
// Each check returns [level, text]; level is ok, warn or bad. Only values the lab can set.
const ADVICE_CHECK = {
  trycksyta: () => state.touch >= 48 ? ['ok', `Trycksytorna är ${state.touch} px, som Androids 48 dp-rekommendation.`]
    : state.touch >= 44 ? ['warn', `${state.touch} px räcker för Apple (44 pt) men inte Android (48 dp).`]
      : ['bad', `${state.touch} px är under både Apples 44 pt och Androids 48 dp.`],
  textstorlek: () => state.scale >= 100 ? ['ok', `Texten är ${state.scale} % av originalet.`]
    : state.scale >= 90 ? ['warn', `Texten är ${state.scale} % av originalet, lite mindre än tänkt.`]
      : ['bad', `Texten är ${state.scale} % av originalet. Brödtexten blir lätt under 14 px.`],
  radavstand: () => state.lh >= 100 ? ['ok', state.lh === 100 ? 'Radavståndet är originalets.' : `Radavståndet är ${state.lh} % av originalets.`] : ['warn', 'Radavståndet är tätare än originalet.'],
  marginal: () => state.margin < 16 ? ['bad', `Sidmarginalen ${state.margin} px är smalare än Materials 16 dp.`]
    : state.margin < 20 ? ['warn', `Sidmarginalen ${state.margin} px är smal men ryms inom Materials minimum.`]
      : state.margin > 32 ? ['warn', `Sidmarginalen ${state.margin} px tar mycket plats på en smal telefon.`]
        : ['ok', `Sidmarginalen ${state.margin} px ligger i det vanliga intervallet.`],
  avstand: () => state.space < 70 ? ['warn', `Avstånden är ${state.space} % av originalet: mycket tätt, kontrollera trycksytorna.`]
    : state.space > 150 ? ['warn', `Avstånden är ${state.space} % av originalet: mycket luftigt, mer scrollande.`]
      : ['ok', state.space === 100 ? 'Avstånden är originalets.' : `Avstånden är ${state.space} % av originalet.`],
  form: () => state.control > state.card ? ['warn', `Knapparna (${state.control} px) är rundare än korten (${state.card} px). Barnet bör inte vara rundare än föräldern.`]
    : ['ok', `Kort ${state.card} px och knappar ${state.control} px.`],
  ikonstorlek: () => { const s = 24 * state.iconSize / 100; return s < 16 ? ['bad', `Ikonerna blir ${px(s)}, under 16 px som är svårt att tolka.`] : s < 20 ? ['warn', `Ikonerna blir ${px(s)}, små men läsbara.`] : s > 36 ? ['warn', `Ikonerna blir ${px(s)}, stora mot texten.`] : ['ok', `Ikonerna blir ${px(s)}.`]; },
  ikonlinje: () => state.iconStroke && state.iconStroke < 1 ? ['warn', `Linjetjockleken ${state.iconStroke} px är hårfin och syns dåligt i solsken.`] : ['ok', state.iconStroke ? `Linjetjocklek ${state.iconStroke} px.` : 'Ikonernas linjetjocklek är originalets.'],
  avdelare: () => state.hair >= 3 ? ['warn', `Avdelarna är ${state.hair} px, kraftiga för vad de är till för.`] : ['ok', `Avdelarna är ${state.hair} px.`],
  kontrast: () => { const n = document.querySelectorAll('#contrast .bad').length; return n ? ['bad', `${n} färgpar i kontrollen ligger under 4,5:1 (se Kontroll).`] : ['ok', 'Alla uppmätta färgpar klarar 4,5:1.']; },
  farg: () => { const n = Object.keys(state.colors).length; return n > 6 ? ['warn', `${n} färger är ändrade var för sig, risk för ett splittrat intryck.`] : ['ok', n ? `${n} färger är ändrade.` : 'Färgerna är originalets.']; },
  rorelse: () => { const n = partsWith(p => p.anim).length; return n >= 3 && !state.pause ? ['warn', `${n} delar rör sig hela tiden, det blir rastlöst. Bocka i "Pausa animationer" för att se det stilla.`] : ['ok', n ? `${n} delar har rörelse.` : 'Inget rör sig av sig själv.']; },
  hovring: () => { const n = partsWith(p => p.hover && !p.press).length; return n ? ['warn', `${n} delar har hovring men ingen tryckeffekt. På telefon syns då ingenting.`] : ['ok', 'Ingen hovring utan tryckeffekt.']; },
  skugga: () => { const n = partsWith(p => p.shAlpha > 40).length; return n ? ['warn', `${n} delar har mycket tung skugga (över 40 %).`] : ['ok', 'Inga överdrivet tunga skuggor.']; },
  glas: () => { const n = partsWith(p => p.blur > 0).length; return n ? ['warn', `${n} delar har sudd bakom sig. Kontrollera kontrasten mot det som ligger bakom, och prestandan på äldre telefoner.`] : ['ok', 'Inget glas används.']; },
  kant: () => { const n = partsWith(p => p.bw >= 4).length; return n ? ['warn', `${n} delar har kant på 4 px eller mer.`] : ['ok', 'Inga överdrivet kraftiga kanter.']; },
  layout: () => { const n = state.moves.length; return ['ok', n ? `${n} delar är flyttade.` : 'Layouten är originalets.']; },
};

function adviceLevels() {
  const out = [];
  for (const [id, fn] of Object.entries(ADVICE_CHECK)) {
    try { out.push({ id, title: ADVICE[id].t, level: fn()[0], text: fn()[1] }); } catch { /* a check never blocks the box */ }
  }
  return out;
}
function adviceVerdict(id) { try { return ADVICE_CHECK[id]?.(); } catch { return null; } }
function adviceText(id) {
  const a = ADVICE[id], v = adviceVerdict(id);
  return { id, title: a.t, nowInLab: v ? { level: v[0], text: v[1] } : null, what: a.what, pros: a.pro, cons: a.con, rule: a.rule, keyFigures: a.nums, commonMistakes: a.mistakes, source: a.src };
}

const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const LEVEL_WORD = { ok: 'ok', warn: 'se över', bad: 'åtgärda' };

function askAbout(text) {
  if (!claudeAi?.sample || !$('ask-text')) return;
  $('chat-box').hidden = false;
  $('ask-text').value = text;
  $('chat-box').scrollIntoView({ block: 'nearest' });
  ask();
}
function adviceCard(id, open) {
  const a = ADVICE[id];
  const d = el('details');
  d.open = open; d.dataset.topic = id;
  const v = adviceVerdict(id);
  const s = el('summary');
  if (v) s.append(el('span', `dot ${v[0]}`));
  s.append(a.t);
  d.append(s);
  if (v) d.append(el('p', `nowline ${v[0]}`, `I labbet nu (${LEVEL_WORD[v[0]]}): ${v[1]}`));
  const para = (label, text) => { const p = el('p'); p.append(el('b', null, label + ': '), text); return p; };
  d.append(para('Vad det är', a.what), para('Fördelar', a.pro), para('Nackdelar', a.con), para('Tumregel', a.rule));
  if (a.nums) {
    const t = el('div', 'nums');
    for (const [k, val] of a.nums) t.append(el('span', null, k), el('b', null, val));
    d.append(el('h4', null, 'Nyckeltal'), t);
  }
  if (a.mistakes) { const ul = el('ul'); for (const m of a.mistakes) ul.append(el('li', null, m)); d.append(el('h4', null, 'Vanliga misstag'), ul); }
  if (a.src) d.append(el('p', 'src', `Källa: ${a.src}`));
  if (claudeAi?.sample) {
    const row = el('div', 'ask-row');
    for (const [label, q] of [
      ['Fråga Claude om detta', `Förklara rådet "${a.t}" för mig och säg vad det betyder för min app och mina nuvarande val i labbet.`],
      ['Förklara enklare', `Förklara rådet "${a.t}" ännu enklare, som för någon som aldrig har designat.`],
      ['Föreslå ändring', `Utifrån rådet "${a.t}" och hur labbet ser ut nu: föreslå en förbättring, förklara varför och gör den i labbet om du är säker.`],
    ]) { const b = el('button', 'ghost', label); b.type = 'button'; b.onclick = () => askAbout(q); row.append(b); }
    d.append(row);
  }
  return d;
}
function adviceGlossary(q) {
  const items = GLOSSARY.filter(([t, x]) => !q || `${t} ${x}`.toLowerCase().includes(q));
  if (!items.length) return null;
  const d = el('details'); d.open = !!q;
  d.append(el('summary', null, 'Ordlista'));
  for (const [t, x] of items) { const p = el('p'); p.append(el('b', null, t + ': '), x); d.append(p); }
  return d;
}
function adviceSummary() {
  const box = el('div', 'advice-sum');
  const all = adviceLevels();
  const bad = all.filter(x => x.level === 'bad'), warn = all.filter(x => x.level === 'warn');
  box.append(el('p', bad.length ? 'bad' : warn.length ? 'warn' : 'ok',
    bad.length || warn.length ? `${bad.length} att åtgärda, ${warn.length} att se över av ${all.length} kontroller.` : `Inga anmärkningar på ${all.length} kontroller.`));
  for (const x of [...bad, ...warn]) {
    const b = el('button', `link ${x.level}`, `${x.title}: ${x.text}`);
    b.type = 'button'; b.onclick = () => showAdvice(x.id);
    box.append(b);
  }
  if (claudeAi?.sample) {
    const b = el('button', 'ghost', 'Låt Claude granska mina val');
    b.type = 'button';
    b.onclick = () => askAbout('Granska alla mina val i labbet mot råden. Ta det viktigaste först, förklara varför det spelar roll för en receptapp och föreslå vad jag bör ändra. Ändra ingenting utan att jag har sagt ja.');
    box.append(b);
  }
  return box;
}
function showAdvice(topic) {
  if (topic) { adviceTopic = topic; adviceQuery = ''; if ($('advice-q')) $('advice-q').value = ''; }
  const box = $('advice-list');
  if (!box) return;
  const tab = document.querySelector('#tabs button.on')?.dataset.tab || 'all';
  const q = adviceQuery.trim().toLowerCase();
  let ids;
  if (q) ids = Object.keys(ADVICE).filter(id => `${ADVICE[id].t} ${ADVICE[id].what} ${ADVICE[id].rule}`.toLowerCase().includes(q));
  else if (adviceAll) ids = Object.keys(ADVICE);
  else ids = [...new Set([adviceTopic, ...(ADVICE_TABS[tab] || [])].filter(id => ADVICE[id]))];
  const kept = new Set([...box.querySelectorAll('details[open]')].map(d => d.dataset.topic));
  box.textContent = '';
  box.append(adviceSummary());
  ids.forEach((id, i) => box.append(adviceCard(id, kept.has(id) || id === adviceTopic || (!adviceTopic && !q && i === 0 && !kept.size) || (!!q && ids.length === 1))));
  const g = adviceGlossary(q);
  if (g) box.append(g);
  if (q && !ids.length && !g) box.append(el('p', 'hint', 'Inget råd matchar sökningen.'));
  if (topic) box.querySelector(`details[data-topic="${topic}"]`)?.scrollIntoView({ block: 'nearest' });
  $('advice-all').textContent = adviceAll ? 'Visa bara den här fliken' : 'Visa alla råd';
}
function wireAdvice() {
  const panel = document.querySelector('.panel:not(.dock)');
  const topicOf = elt => {
    for (let e = elt; e && e !== panel; e = e.parentElement) if (ADVICE_FOR[e.id]) return ADVICE_FOR[e.id];
    return null;
  };
  panel.addEventListener('focusin', e => { const t = topicOf(e.target); if (t) showAdvice(t); });
  panel.addEventListener('pointerdown', e => { const t = topicOf(e.target); if (t) showAdvice(t); });
  panel.addEventListener('mouseover', e => { const t = e.target.closest('[data-advice]')?.dataset.advice; if (t) showAdvice(t); });
  $('tabs').addEventListener('click', () => { adviceTopic = null; showAdvice(); });
  $('advice-q').oninput = e => { adviceQuery = e.target.value; showAdvice(); };
  $('advice-all').onclick = () => { adviceAll = !adviceAll; showAdvice(); };
  showAdvice();
}

// Called by render(): the verdicts follow every change, however it was made.
let adviceTimer = 0;
function refreshAdvice() {
  clearTimeout(adviceTimer);
  adviceTimer = setTimeout(() => { if ($('advice-list')?.childElementCount) showAdvice(); }, 250);
}
