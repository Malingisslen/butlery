'use strict';
// Talking to Claude from the published lab: a chat that can read and change the lab, a switch that
// lets Claude see what is selected and changed, and a button that leaves a build request for the
// session that works on the app. It needs window.claude, so the Claude column stays hidden when the
// file is opened outside a published page.

const CHAT_RULES = `Du är Claude och sitter i Butlerys designlabb, en webbsida där Malin (som inte kodar) provar färger, typsnitt, avstånd, ikoner och layout på tre exempelskärmar. Svara på svenska, kort och utan fackspråk.
Du har verktyg som läser och ändrar labbet: getLabState, setLabState, setSelectedPart, resetLab, getColors, listAdvice och getAdvice. Använd dem när hon ber om en ändring, och säg vad du ändrade. Du kan INTE ändra själva appen härifrån. När hon vill ha något i appen, be henne trycka på "Skicka till Claude" längst ned i rutan Claude, så bygger sessionen som jobbar med appen det.
Läs alltid färglistan med getColors innan du ändrar en färg, gissa aldrig hexkoder, och kontrollera i svaret från setLabState (applied och lightScreenNow, den ljusa skärmens verkliga bakgrund) att det du lovar Malin är det som hände. Beskriv bara det som faktiskt ändrades.
Rutan Råd i labbet innehåller vedertagna tumregler (Material, Apple, WCAG) med fördelar, nackdelar och nyckeltal, och en kontroll av Malins nuvarande val. Läs den med getAdvice innan du ger designråd, bygg på den, säg vilket råd det gäller och förklara enkelt eftersom Malin inte är designer. Kom ihåg att appen är en receptapp för hushåll. Brödtext ska ha minst 4,5:1 i kontrast. Säg ifrån om en ändring bryter mot det. Inga emoji.`;
const claudeAi = { sample: null, db: null };
const chatTurns = [];
let chatCtl = null;
let shareTimer = 0;

function selectionInfo() {
  if (!selected) return null;
  const mode = selected.mode || (selected.el.closest('.phone').dataset.theme === 'dark' ? 'dark' : 'light');
  const sel = selectorFor(selected.el, false);
  return { selector: sel, mode, text: labelOf(selected.el), props: state.parts[`${mode}|${sel}`]?.props || {} };
}
function labContext() {
  const tab = document.querySelector('#tabs button.on')?.textContent || '';
  const flagged = adviceLevels().filter(x => x.level !== 'ok').map(x => `${x.title}: ${x.text}`);
  return JSON.stringify({ openTab: tab, changes: summary(state) ? JSON.parse(summary(state)) : {}, selectedPart: selectionInfo(), openAdvice: adviceTopic, adviceChecks: flagged }, null, 1);
}

function colorNames(hex) {
  const names = (paletteNames.get(hex) || []).map(n => `palette-${n}`);
  for (const u of used.get(hex) || []) {
    const n = u.name.replace('--butlery-', '');
    if (!n.startsWith('palette-') && !names.includes(n)) names.push(n);
  }
  return names;
}
function colorList() {
  return [...used.entries()].sort((a, b) => b[1].length - a[1].length).slice(0, 45)
    .map(([hex, uses]) => ({ hex, now: finalColor(state, hex), usedBy: colorNames(hex).slice(0, 6), uses: uses.length }));
}
// A color is named by its original hex or by any of the names colorList shows.
function resolveColor(key) {
  const k = key.toLowerCase();
  if (used.has(k)) return k;
  for (const hex of used.keys()) if (colorNames(hex).includes(k.replace(/^--butlery-/, ''))) return hex;
  return null;
}

// The same ranges the sliders have, so Claude cannot set a value the panel cannot show.
let askApplied = [];
function applyChanges(changes) {
  const applied = [], refused = [];
  for (const [k, v] of Object.entries(changes || {})) {
    if (k in SLIDERS) {
      const el = $(k), n = Number(v);
      if (!Number.isFinite(n) || n < +el.min || n > +el.max) refused.push(`${k}: ${el.min} till ${el.max}`);
      else { state[k] = n; applied.push(k); }
    } else if (k === 'font' && v in FONTS) { state.font = v; applied.push(k); }
    else if (k === 'iconLib' && v in ICON_LIBS) { state.iconLib = v; applied.push(k); }
    else if (k === 'iconStyle' && ICON_STYLES.some(s => s[0] === v)) { state.iconStyle = v; applied.push(k); }
    else if (k === 'overlay' && typeof v === 'boolean') { state.overlay = v; applied.push(k); }
    else if (k === 'colors' && v && typeof v === 'object') {
      for (const [from, to] of Object.entries(v)) {
        const hex = resolveColor(from);
        if (hex && HEX.test(to)) { state.colors[hex] = to.toLowerCase(); applied.push(`färg ${from} (${hex}) -> ${to}`); }
        else refused.push(`färg ${from}: finns inte i getColors, eller ogiltig färg`);
      }
    } else refused.push(`${k}: okänt reglage`);
  }
  const keep = selected;
  syncUi();
  if (keep?.el.isConnected) {
    selected = keep;
    keep.el.setAttribute('data-lab-selected', '');
  }
  askApplied.push(...applied);
  const adviceKey = Object.keys(changes || {}).map(k => ADVICE_FOR[k]).find(Boolean);
  if (adviceKey) showAdvice(adviceKey); else showAdvice();
  const phone = document.querySelector('#screens .phone:not([data-theme="dark"])');
  const lightScreenNow = phone ? toHex(getComputedStyle(phone).backgroundColor) : null;
  return { applied, refused, lightScreenNow, now: summary(state) ? JSON.parse(summary(state)) : {} };
}
function applyPartProps(props) {
  if (!selected) throw new Error('Ingen del är vald i skärmarna. Be Malin klicka på en del.');
  const specs = Object.fromEntries(PART_GROUPS.flatMap(g => g[1]).map(s => [s[0], s]));
  const mode = selected.mode || (selected.el.closest('.phone').dataset.theme === 'dark' ? 'dark' : 'light');
  const sel = selectorFor(selected.el, false), key = `${mode}|${sel}`;
  const part = state.parts[key] ||= { sel, mode, props: {} };
  partBase[key] ||= { bg: toHex(getComputedStyle(selected.el).backgroundColor) };
  const applied = [], refused = [];
  for (const [k, v] of Object.entries(props || {})) {
    const [, , type, lo, hi] = specs[k] || [];
    const ok = !type ? false : type === 'color' ? HEX.test(v) : type === 'check' ? typeof v === 'boolean'
      : type === 'sel' ? lo.some(o => String(Array.isArray(o) ? o[0] : o) === String(v))
        : Number.isFinite(Number(v)) && Number(v) >= lo && Number(v) <= hi;
    if (!ok) { refused.push(k); continue; }
    part.props[k] = type === 'color' || type === 'check' || type === 'sel' && isNaN(Number(v)) ? v : Number(v);
    applied.push(k);
  }
  showPart(false);
  return { applied, refused, part: sel };
}
// Built on use: SLIDERS is defined in designlabb-ui.js, which loads after this file.
const chatTools = () => [
  {
    name: 'getColors',
    description: 'Listar labbets färger: hex (original), now (nuvarande), usedBy (vilka roller och namn den bär, till exempel surface-base för skärmens bakgrund) och uses. Anropa den före varje färgändring.',
    execute: () => colorList(),
  },
  {
    name: 'listAdvice',
    description: 'Listar alla råd i rutan Råd: id, rubrik och hur Malins val står sig just nu (ok, warn eller bad).',
    execute: () => Object.keys(ADVICE).map(id => ({ id, title: ADVICE[id].t, now: adviceVerdict(id)?.[0] || null })),
  },
  {
    name: 'getAdvice',
    description: 'Hämtar ett råd med id från listAdvice: vad det är, fördelar, nackdelar, tumregel, nyckeltal, vanliga misstag, källa och hur labbet står sig mot det. Öppnar också rådet i rutan Råd så att Malin ser det.',
    inputSchema: { type: 'object', properties: { topic: { type: 'string' } }, required: ['topic'] },
    execute: input => {
      if (!ADVICE[input.topic]) throw new Error('Okänt råd. Använd listAdvice för id.');
      showAdvice(input.topic);
      return adviceText(input.topic);
    },
  },
  { name: 'getLabState', description: 'Returnerar labbets nuvarande ändringar och vilken del Malin har markerat.', execute: () => JSON.parse(labContext()) },
  {
    name: 'setLabState',
    description: `Ändrar hela labbet. changes är ett objekt: reglage som ${Object.keys(SLIDERS).join(', ')} (tal inom reglagets gränser), font (${Object.keys(FONTS).join(', ')}), iconLib (${Object.keys(ICON_LIBS).join(', ')}), iconStyle ('', round, square, duo), overlay (true/false) och colors ({"surface-base":"#ffffff"}, där nyckeln är originalhex eller ett namn från getColors och värdet den nya färgen). Returnerar vad som tillämpades och vad som nekades.`,
    inputSchema: { type: 'object', properties: { changes: { type: 'object' } }, required: ['changes'] },
    execute: input => applyChanges(input.changes),
  },
  {
    name: 'setSelectedPart',
    description: 'Ändrar den del Malin har klickat på. props är ett objekt med nycklar som bg, color, radius, size, weight, padY, padX, scale, shY, shBlur, shAlpha, opacity, bw, bc, anim, hover, press (färger som #rrggbb). Kräver att en del är markerad.',
    inputSchema: { type: 'object', properties: { props: { type: 'object' } }, required: ['props'] },
    execute: input => applyPartProps(input.props),
  },
  { name: 'resetLab', description: 'Återställer allt i labbet till originalet.', execute: () => { state = defaults(); stopCompare(); syncUi(); return 'återställt'; } },
];

function bubble(kind, text) {
  const el = document.createElement('div');
  el.className = `chat-msg ${kind}`;
  el.textContent = text;
  $('chat-log').append(el);
  el.scrollIntoView({ block: 'nearest' });
  return el;
}
const ASK_ERRORS = {
  rate_limited: 'För många frågor just nu. Vänta en stund och försök igen.',
  session_expired: 'Du behöver logga in igen.',
  refused: 'Claude kunde inte svara på det. Fråga på ett annat sätt.',
  upstream_error: 'Något gick fel på vägen. Försök igen.',
};
async function ask() {
  const text = $('ask-text').value.trim();
  if (!text || !claudeAi.sample || chatCtl) return;
  $('ask-text').value = '';
  chatTurns.push({ role: 'user', content: text });
  bubble('me', text);
  const answer = bubble('claude', 'Tänker ...');
  askApplied = [];
  chatCtl = new AbortController();
  $('ask-stop').hidden = false; $('ask-go').disabled = true;
  try {
    const hasTools = !!(await claudeAi.sample.limits().catch(() => ({}))).tools;
    const { text: reply } = await claudeAi.sample(
      [{ role: 'user', content: `${CHAT_RULES}\n\nLäget i labbet nu:\n${labContext()}` }, ...chatTurns.slice(-12)],
      { cache: false, signal: chatCtl.signal, modelTier: 'quick', tools: hasTools ? chatTools() : undefined, onText: ({ text: t }) => { answer.textContent = t; } },
    );
    chatTurns.push({ role: 'assistant', content: reply });
    bubble('note', askApplied.length ? `Ändrat i labbet: ${askApplied.join(', ')}.` : 'Inget ändrades i labbet av det här svaret.');
  } catch (e) {
    if (e.text) { answer.textContent = e.text; chatTurns.push({ role: 'assistant', content: e.text }); } else answer.remove();
    if (e.code !== 'cancelled') bubble('note', ASK_ERRORS[e.code] || 'Det gick inte att fråga just nu.');
    if (!e.text) chatTurns.pop();
  } finally {
    chatCtl = null;
    $('ask-stop').hidden = true; $('ask-go').disabled = false;
  }
}

async function sendRequest() {
  const text = $('req-text').value.trim();
  const note = $('req-note');
  if (!claudeAi.db) { note.textContent = 'Den här sidan kan inte spara till Claude. Använd Kopiera i stället.'; return; }
  const at = new Date().toISOString();
  note.textContent = 'Skickar ...';
  try {
    await claudeAi.db.doc(`requests/${at.replace(/[:.]/g, '-')}`).set({
      at, status: 'new', text, handoff: HANDOFF_RULE, summary: summary(state), state: JSON.stringify(state), selection: selectionInfo(), chat: chatTurns.slice(-6),
    });
    $('req-text').value = '';
    note.textContent = 'Skickat. Skriv "skickat" i tråden hos Claude, så läser Claude det direkt.';
  } catch {
    note.textContent = 'Det gick inte att skicka. Använd Kopiera i stället.';
  }
}
// Claude reads this document on request, so it only holds the latest picture of the lab.
function shareNow() {
  if (!claudeAi.db || !$('share-live').checked) return;
  clearTimeout(shareTimer);
  shareTimer = setTimeout(() => {
    claudeAi.db.doc('live/now').set({ at: new Date().toISOString(), summary: summary(state), selection: selectionInfo(), openTab: document.querySelector('#tabs button.on')?.textContent || '' }).catch(() => {});
  }, 800);
}

async function initClaude() {
  if (!window.claude?.use) return;
  try {
    [claudeAi.sample, claudeAi.db] = await Promise.all([claude.use('sample'), claude.use('db')]);
  } catch { return; }
  if (!claudeAi.sample && !claudeAi.db) return;
  if (typeof loadVariantsFromDb === 'function') loadVariantsFromDb();
  $('dock').hidden = false;
  $('chat-box').hidden = !claudeAi.sample;
  $('send-box').hidden = !claudeAi.db;
  $('ask-go').onclick = ask;
  $('ask-text').onkeydown = e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); ask(); } };
  $('ask-stop').onclick = () => chatCtl?.abort();
  $('req-go').onclick = sendRequest;
  $('share-live').onchange = shareNow;
}
