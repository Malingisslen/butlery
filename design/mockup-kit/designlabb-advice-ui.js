'use strict';
// The Råd box: topic cards (what, pros, cons, rule, key figures, mistakes, source), a live check
// of the lab's current values against each topic, a summary of all checks, a glossary and a
// search. Every card can hand its topic to the Claude chat, and Claude can read and open topics.

for (const [id, more] of Object.entries(ADVICE_MORE)) Object.assign(ADVICE[id], more);
let adviceTopic = null;

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

// What you can try for a topic: label and the lab values it sets.
const ADVICE_TRY = {
  trycksyta: [['48 px (Android)', { touch: 48 }], ['44 px (Apple)', { touch: 44 }], ['56 px (rymligt)', { touch: 56 }]],
  textstorlek: [['100 % (original)', { scale: 100 }], ['110 %', { scale: 110 }], ['125 %', { scale: 125 }]],
  radavstand: [['Original', { lh: 100 }], ['Luftigare', { lh: 112 }]],
  marginal: [['16 px', { margin: 16 }], ['24 px (original)', { margin: 24 }], ['32 px', { margin: 32 }]],
  avstand: [['Tätare', { space: 80 }], ['Original', { space: 100 }], ['Luftigare', { space: 125 }]],
  form: [['Original', { card: 12, control: 8 }], ['Rundare', { card: 20, control: 14 }], ['Skarpare', { card: 6, control: 4 }]],
  ikonstorlek: [['Original', { iconSize: 100 }], ['Större', { iconSize: 120 }], ['Mindre', { iconSize: 85 }]],
  ikonlinje: [['Original', { iconStroke: 0 }], ['Tunnare', { iconStroke: 1.25 }], ['Tjockare', { iconStroke: 2.25 }]],
  avdelare: [['1 px', { hair: 1 }], ['2 px', { hair: 2 }]],
};
// What the picked part is, which topics fit it, and what you can try on just that part.
const bySize = (key, d) => el => ({ [key]: Math.round(parseFloat(getComputedStyle(el).fontSize) + d) });
const PART_KINDS = {
  icon: { name: 'Ikon', topics: ['ikonstorlek', 'ikonlinje', 'ikonstil'], tries: [['Mindre', { scale: 85 }], ['Större', { scale: 120 }], ['Dämpad', { opacity: 55 }]] },
  button: { name: 'Knapp eller chip', topics: ['trycksyta', 'form', 'tryck'], tries: [['Rundare', { radius: 24 }], ['Skarpare', { radius: 6 }], ['Mjuk skugga', { shY: 2, shBlur: 8, shAlpha: 20 }], ['Högre', { padY: 14 }]] },
  row: { name: 'Rad', topics: ['avstand', 'avdelare', 'trycksyta'], tries: [['Luftigare', { padY: 16 }], ['Tätare', { padY: 6 }]] },
  card: { name: 'Kort', topics: ['form', 'skugga', 'kant'], tries: [['Rundare', { radius: 22 }], ['Mjuk skugga', { shY: 4, shBlur: 14, shAlpha: 18 }], ['Kantlinje', { bw: 1 }], ['Luftigare', { padY: 20, padX: 20 }]] },
  nav: { name: 'Bottenmeny', topics: ['bottenmeny', 'ikonstorlek', 'trycksyta'], tries: [['Högre', { h: 72 }], ['Mjuk skugga', { shY: -2, shBlur: 10, shAlpha: 15 }]] },
  field: { name: 'Fält', topics: ['form', 'trycksyta', 'kant'], tries: [['Rundare', { radius: 16 }], ['Kantlinje', { bw: 2 }], ['Högre', { h: 56 }]] },
  text: { name: 'Text', topics: ['typsnitt', 'textstorlek', 'kontrast'], tries: [['Större', bySize('size', 2)], ['Mindre', bySize('size', -2)], ['Fetare', { weight: 700 }]] },
  box: { name: 'Ruta', topics: ['avstand', 'form', 'layout'], tries: [['Luftigare', { padY: 16, padX: 16 }], ['Rundare', { radius: 20 }], ['Mitten', { alignX: 'center', alignY: 'center' }]] },
};
function partKind(e) {
  if (e.tagName === 'svg' || e.closest('svg')) return 'icon';
  if (e.matches('.b-bottomnav') || e.closest('.b-bottomnav') && e.matches('.tab,.add')) return 'nav';
  if (e.matches('.b-btn,.b-chip,.b-iconbtn,button')) return 'button';
  if (e.matches('.b-row')) return 'row';
  if (e.matches('.b-input,.b-field')) return 'field';
  if (e.matches('.b-card,.mr-card,.b-band,.b-section')) return 'card';
  if (!e.children.length || [...e.children].every(c => ['SPAN', 'B', 'I'].includes(c.tagName))) return 'text';
  return 'box';
}

let adviceCtx = null; // { text, tries: [[label, props | fn]], apply }
function askAbout(text) {
  if (!claudeAi?.sample || !$('ask-text')) return;
  $('chat-box').hidden = false;
  $('ask-text').value = text;
  $('chat-box').scrollIntoView({ block: 'nearest' });
  ask();
}
function labSet(changes) {
  const n = askApplied.length;
  applyChanges(changes);
  askApplied.length = n;
}
function tryRow(label, tries, run) {
  const row = el('div', 'try-row');
  row.append(el('span', 'try-label', label));
  for (const [name, what] of tries) {
    const b = el('button', 'ghost', name);
    b.type = 'button'; b.onclick = () => run(what);
    row.append(b);
  }
  return row;
}
function adviceCard(id) {
  const a = ADVICE[id], v = adviceVerdict(id);
  const card = el('div', 'advice-card');
  card.dataset.topic = id;
  card.append(el('h3', null, a.t));
  if (v) card.append(el('p', `nowline ${v[0]}`, `Ditt val nu (${LEVEL_WORD[v[0]]}): ${v[1]}`));
  card.append(el('p', 'what', a.what));
  const cols = el('div', 'procon');
  const pro = el('div', 'pro'), con = el('div', 'con');
  pro.append(el('b', null, 'Fördelar'), el('span', null, a.pro));
  con.append(el('b', null, 'Nackdelar'), el('span', null, a.con));
  cols.append(pro, con);
  card.append(cols);
  const rule = el('p', 'rule'); rule.append(el('b', null, 'Tumregel: '), a.rule);
  card.append(rule);
  if (ADVICE_TRY[id]) card.append(tryRow('Prova:', ADVICE_TRY[id], changes => { labSet(changes); showAdvice(id); }));
  if (a.nums || a.mistakes || a.src) {
    const d = el('details');
    d.append(el('summary', null, 'Mer om detta'));
    if (a.nums) { const t = el('div', 'nums'); for (const [k, val] of a.nums) t.append(el('span', null, k), el('b', null, val)); d.append(t); }
    if (a.mistakes) { const ul = el('ul'); for (const m of a.mistakes) ul.append(el('li', null, m)); d.append(el('h4', null, 'Vanliga misstag'), ul); }
    if (a.src) d.append(el('p', 'src', `Källa: ${a.src}`));
    card.append(d);
  }
  if (claudeAi?.sample) {
    const b = el('button', 'ghost ask', 'Fråga Claude om detta');
    b.type = 'button';
    b.onclick = () => askAbout(`Förklara rådet "${a.t}" för mig och säg vad det betyder för min app och mina nuvarande val i labbet. Föreslå en ändring om du ser en, och gör den bara om jag säger ja.`);
    card.append(b);
  }
  return card;
}
function adviceIdle(box) {
  box.append(el('p', 'hint', 'Peka på ett reglage, eller klicka på något i en skärm, så får du råd om just det här: vad det gör, för- och nackdelar, och vad du kan prova.'));
  const all = adviceLevels();
  const bad = all.filter(x => x.level === 'bad'), warn = all.filter(x => x.level === 'warn');
  if (bad.length || warn.length) {
    const d = el('details', 'advice-sum');
    d.append(el('summary', bad.length ? 'bad' : 'warn', `${bad.length + warn.length} av dina val kan behöva ses över`));
    for (const x of [...bad, ...warn]) {
      const b = el('button', `link ${x.level}`, `${x.title}: ${x.text}`);
      b.type = 'button'; b.onclick = () => showAdvice(x.id);
      d.append(b);
    }
    box.append(d);
  } else box.append(el('p', 'ok-line', 'Inga anmärkningar på dina val just nu.'));
  const pick = el('select');
  pick.add(new Option('Läs ett råd ...', ''));
  for (const id of Object.keys(ADVICE)) pick.add(new Option(ADVICE[id].t, id));
  pick.onchange = () => pick.value && showAdvice(pick.value);
  box.append(pick);
  if (claudeAi?.sample) {
    const b = el('button', 'ghost ask', 'Låt Claude granska mina val');
    b.type = 'button';
    b.onclick = () => askAbout('Granska alla mina val i labbet mot råden. Ta det viktigaste först, förklara varför det spelar roll för en receptapp och föreslå vad jag bör ändra. Ändra ingenting utan att jag har sagt ja.');
    box.append(b);
  }
}
// topic: a topic id, or null for the overview; ctx: what the advice is about ("Du rör: Textstorlek").
function showAdvice(topic, ctx) {
  const box = $('advice-list');
  if (!box) return;
  if (ctx !== undefined) adviceCtx = ctx;
  if (topic === undefined) topic = adviceTopic;
  adviceTopic = topic && ADVICE[topic] ? topic : null;
  box.textContent = '';
  if (adviceCtx) {
    box.append(el('p', 'ctx', adviceCtx.text));
    if (adviceCtx.topics?.length > 1) {
      const row = el('div', 'topic-row');
      for (const id of adviceCtx.topics) {
        const b = el('button', 'ghost' + (id === adviceTopic ? ' on' : ''), ADVICE[id].t);
        b.type = 'button'; b.onclick = () => showAdvice(id);
        row.append(b);
      }
      box.append(row);
    }
  }
  if (adviceTopic) box.append(adviceCard(adviceTopic));
  else adviceIdle(box);
  if (adviceTopic || adviceCtx) {
    const back = el('button', 'link', 'Visa översikten');
    back.type = 'button'; back.onclick = () => { adviceCtx = null; showAdvice(null); };
    box.append(back);
  }
}
// A part was picked in a screen: advice for what it is, with things to try on it.
function adviceForPart(e) {
  if (!$('advice-list')) return;
  const kind = PART_KINDS[partKind(e)];
  showAdvice(kind.topics[0], {
    text: `Du har valt: ${kind.name.toLowerCase()}.`,
    topics: kind.topics,
    tries: kind.tries.map(([n, w]) => [n, w]),
    run: what => { applyPartProps(typeof what === 'function' ? what(selected.el) : what); },
  });
}
// Topics that read best together: opening one offers the others as buttons.
const ADVICE_RELATED = { rorelse: ['rorelse', 'rorelsekurva', 'rorelsefrekvens', 'rorelsestart'], rorelsekurva: ['rorelse', 'rorelsekurva', 'rorelsefrekvens', 'rorelsestart'] };
function wireAdvice() {
  const panel = document.querySelector('.panel:not(.dock)');
  const labelOfControl = elt => elt.closest('label')?.querySelector('span')?.textContent?.trim();
  const topicOf = elt => {
    for (let e = elt; e && e !== panel; e = e.parentElement) if (ADVICE_FOR[e.id]) return ADVICE_FOR[e.id];
    return null;
  };
  const open = elt => {
    const t = topicOf(elt);
    if (t) showAdvice(t, { text: `Du rör: ${(labelOfControl(elt) || ADVICE[t].t).toLowerCase()}.`, ...(ADVICE_RELATED[t] && { topics: ADVICE_RELATED[t] }) });
  };
  panel.addEventListener('focusin', e => open(e.target));
  panel.addEventListener('pointerdown', e => open(e.target));
  panel.addEventListener('mouseover', e => { const t = e.target.closest('[data-advice]')?.dataset.advice; if (t) showAdvice(t, { text: ADVICE[t].t }); });
  showAdvice(null, null);
}

// Called by render(): the verdicts follow every change, however it was made.
let adviceTimer = 0;
function refreshAdvice() {
  clearTimeout(adviceTimer);
  adviceTimer = setTimeout(() => { if ($('advice-list')?.childElementCount) showAdvice(); }, 250);
}
