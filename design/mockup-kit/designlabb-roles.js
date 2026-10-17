'use strict';
// Colour roles: the app's named colours (primary action, surface, text, danger ...) changed in one
// place. A role is one token, so a change here is shared by every component that uses the token.

const ROLE_DEFS = [
  ['action-primary', 'Primär handling', 'Saffran: huvudknappar, markeringar och ikoner som ska dra blicken.'],
  ['action-fill', 'Mörk handling', 'Mörkgrönt: knappar, markerade val och fokusring.'],
  ['action-danger', 'Fara', 'Radera, ta bort och farliga val.'],
  ['surface-base', 'Papper', 'Sidans bakgrund.'],
  ['surface-raised', 'Upphöjd yta', 'Kort, rader och ark som ligger ovanpå papperet.'],
  ['surface-ink', 'Mörk yta', 'Mörka band och toppfält.'],
  ['text-primary', 'Text', 'Rubriker och huvudtext.'],
  ['text-body', 'Brödtext', 'Löpande text.'],
  ['text-secondary', 'Sekundär text', 'Undertexter, hjälptexter och meta.'],
  ['text-link', 'Länk', 'Länkar och accenttext.'],
  ['text-success', 'Lyckat', 'Bekräftelse och klart.'],
  ['text-danger', 'Fara, text', 'Felmeddelanden.'],
  ['text-warning', 'Varning', 'Varningstext.'],
  ['border-subtle', 'Kant, svag', 'Linjer mellan rader och avsnitt.'],
  ['border-control', 'Kant, fält', 'Kantlinjer på fält och knappar.'],
  ['progress-indicator', 'Framsteg', 'Laddning och förloppsstreck.'],
];

// token role -> { light: [{selector, name, hex}], dark: [...] }
const roleTokens = new Map();
for (const [hex, list] of used) {
  for (const { selector, name } of list) {
    const role = ROLE_DEFS.find(r => name === `--butlery-${r[0]}`);
    if (!role) continue;
    const mode = /dark/.test(selector) ? 'dark' : 'light';
    const e = roleTokens.get(role[0]) || { light: [], dark: [] };
    e[mode].push({ selector, name, hex });
    roleTokens.set(role[0], e);
  }
}
const roleHex = (id, mode) => roleTokens.get(id)?.[mode]?.[0]?.hex;

function roleCss(st, scope) {
  let css = '';
  for (const [id, v] of Object.entries(st.roleColors || {})) {
    for (const mode of ['light', 'dark']) {
      if (!v[mode]) continue;
      for (const { selector, name } of roleTokens.get(id)?.[mode] || []) css += `${scoped(selector, scope)}{${name}:${v[mode]}}`;
    }
  }
  return css;
}
function roleSummary(st, out) {
  const roles = {};
  for (const [id, v] of Object.entries(st.roleColors || {})) {
    for (const mode of ['light', 'dark']) {
      if (v[mode] && v[mode] !== roleHex(id, mode)) (roles[id] ||= {})[mode === 'light' ? 'ljust' : 'mörkt'] = { from: roleHex(id, mode), to: v[mode] };
    }
  }
  if (Object.keys(roles).length) out.colorRoles = { notering: 'Ändra tokenen --butlery-<roll> i design/tokens.json, inte enskilda vyer.', ...roles };
}

function wireRoles() {
  const box = document.getElementById('role-colors');
  for (const [id, label, text] of ROLE_DEFS) {
    if (!roleTokens.has(id)) continue;
    const row = document.createElement('div');
    row.className = 'role-row';
    const head = document.createElement('div');
    head.className = 'role-head';
    const name = document.createElement('b'); name.textContent = label;
    const info = document.createElement('small'); info.textContent = text;
    head.append(name, info);
    const pickers = document.createElement('div');
    pickers.className = 'role-pickers';
    const inputs = {};
    for (const [mode, caption] of [['light', 'Ljust'], ['dark', 'Mörkt']]) {
      const base = roleHex(id, mode);
      if (!base) continue;
      const l = document.createElement('label');
      const s = document.createElement('span'); s.textContent = caption;
      const input = document.createElement('input');
      input.type = 'color'; input.value = base;
      const set = v => {
        const r = (state.roleColors ||= {});
        if (v.toLowerCase() === base) { if (r[id]) delete r[id][mode]; if (r[id] && !Object.keys(r[id]).length) delete r[id]; }
        else (r[id] ||= {})[mode] = v;
        render();
      };
      input.oninput = () => set(input.value);
      inputs[mode] = { input, base };
      l.append(s, input, paletteButton(input, v => set(v)));
      pickers.append(l);
    }
    row.append(head, pickers);
    row.syncRole = () => { for (const [mode, { input, base }] of Object.entries(inputs)) input.value = state.roleColors?.[id]?.[mode] || base; };
    box.append(row);
  }
}
function syncRoles() { document.querySelectorAll('#role-colors .role-row').forEach(r => r.syncRole?.()); }
