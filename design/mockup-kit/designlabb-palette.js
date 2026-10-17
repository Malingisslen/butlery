'use strict';
// Colour picker that starts from what the app already uses: every colour with its token name,
// where it sits on the screens (a small live sample) and harmony suggestions for the current one.

const COMPONENT_NAMES = {
  'b-btn': 'Knapp', 'b-iconbtn': 'Ikonknapp', 'b-row': 'Rad', 'b-chip': 'Chip', 'b-card': 'Kort', 'b-input': 'Fält',
  'b-topbar': 'Toppfält', 'b-tabs': 'Flikar', 'b-nav': 'Bottenmeny', 'b-band': 'Band', 'b-section': 'Avsnitt',
  'b-checkbox': 'Kryssruta', 'b-badge': 'Märke', 'b-avatar': 'Avatar', 'b-toggle': 'Reglage',
};
const ROLE_NAMES = { bg: 'Bakgrund', color: 'Text', border: 'Kant', icon: 'Ikon' };

function compName(el) {
  for (let n = el; n && !n.classList?.contains('phone'); n = n.parentElement) {
    for (const c of n.classList || []) if (COMPONENT_NAMES[c]) return COMPONENT_NAMES[c];
    const b = [...(n.classList || [])].find(c => c.startsWith('b-') && c !== 'b-scroll' && c !== 'b-body');
    if (b) return b.slice(2);
  }
  return 'Sida';
}
const toHexStr = c => {
  const m = c.match(/[\d.]+/g)?.map(Number);
  if (!m || m.length < 3 || (m.length > 3 && m[3] < 0.5)) return null;
  return '#' + m.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
};

// hex -> { names: token names, uses: Map('Bakgrund i Knapp' -> { n, el }) }
function scanAppColors() {
  const found = new Map();
  const add = (hex, role, el) => {
    if (!hex) return;
    if (!found.has(hex)) found.set(hex, { names: [], uses: new Map() });
    const e = found.get(hex), key = `${ROLE_NAMES[role]} i ${compName(el)}`;
    const u = e.uses.get(key) || { n: 0, el };
    u.n++;
    e.uses.set(key, u);
  };
  for (const phone of document.querySelectorAll('#screens .phone:not([data-theme="dark"])')) {
    for (const el of phone.querySelectorAll('*')) {
      if (el.closest('.lab-handles') || el.classList.contains('lab-gap')) continue;
      const cs = getComputedStyle(el);
      if (cs.display === 'none') continue;
      const isSvg = el.tagName.toLowerCase() === 'svg';
      add(toHexStr(cs.backgroundColor), 'bg', el);
      if (isSvg) add(toHexStr(cs.color), 'icon', el);
      else if (el.childNodes.length && [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) add(toHexStr(cs.color), 'color', el);
      if (parseFloat(cs.borderTopWidth) > 0) add(toHexStr(cs.borderTopColor), 'border', el);
    }
  }
  for (const [hex, list] of used) {
    const names = (paletteNames.get(hex) || list.map(u => u.name.replace('--butlery-', ''))).slice(0, 2);
    if (found.has(hex)) found.get(hex).names = names;
    else found.set(hex, { names, uses: new Map() });
  }
  return found;
}

function harmonies(hex) {
  const [h, s, l] = hexToHsl(hex);
  const rot = d => hslToHex((h + d + 360) % 360, s, l);
  const tone = dl => hslToHex(h, s, Math.max(0.08, Math.min(0.95, l + dl / 100)));
  return [
    ['Motfärg', 'Rakt motsatt på färghjulet. Ger starkast kontrast mot din färg.', [rot(180)]],
    ['Grannfärger', 'Ligger bredvid din färg på hjulet. Ger en lugn och sammanhängande känsla.', [rot(-30), rot(30)]],
    ['Trio', 'Tre jämnt fördelade färger med din. Ger en livlig och färgglad känsla.', [rot(120), rot(240)]],
    ['Samma färg, andra ljushet', 'Din färg i fyra steg, från mörkare till ljusare.', [tone(-24), tone(-12), tone(12), tone(24)]],
  ];
}

let colorPop = null;
function closeColorPop() { colorPop?.remove(); colorPop = null; }
function openColorPopover(anchor, current, onPick) {
  closeColorPop();
  const pop = document.createElement('div');
  pop.className = 'color-pop';
  const head = document.createElement('div');
  head.className = 'cp-head';
  head.innerHTML = '<strong>Välj färg</strong>';
  const x = document.createElement('button');
  x.type = 'button'; x.className = 'ghost'; x.textContent = 'Stäng'; x.onclick = closeColorPop;
  head.append(x);
  pop.append(head);
  const pick = hex => { onPick(hex); closeColorPop(); };
  const textOn = hex => (lumOf(hex) > 0.45 ? '#17251d' : '#ffffff');
  const swatch = (hex, label) => {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'cp-sw'; b.title = `${label || ''} ${hex}`.trim();
    b.style.background = hex;
    b.style.color = textOn(hex);
    b.innerHTML = `<b>Aa</b><small>${hex}</small>`;
    b.onclick = () => pick(hex);
    return b;
  };
  if (window.EyeDropper) {
    const eye = document.createElement('button');
    eye.type = 'button'; eye.className = 'ghost'; eye.textContent = 'Pipett: plocka färg från skärmen';
    eye.onclick = async () => { try { pick((await new EyeDropper().open()).sRGBHex); } catch { /* cancelled */ } };
    pop.append(eye);
  }
  if (current) {
    const h2 = document.createElement('h3'); h2.textContent = 'Idéer som passar ihop med din färg';
    const now = document.createElement('div'); now.className = 'cp-now';
    now.innerHTML = `<i style="background:${current}"></i><span>Din färg just nu: <b>${current}</b>. Klicka på en ruta nedan för att byta till den.</span>`;
    pop.append(h2, now);
    for (const [name, text, list] of harmonies(current)) {
      const row = document.createElement('div'); row.className = 'cp-row';
      const t = document.createElement('div'); t.className = 'cp-text';
      t.innerHTML = `<b></b><small></small>`;
      t.firstChild.textContent = name; t.lastChild.textContent = text;
      const sw = document.createElement('div'); sw.className = 'cp-sws';
      for (const hex of list) sw.append(swatch(hex, name));
      row.append(t, sw); pop.append(row);
    }
  }
  const h3 = document.createElement('h3'); h3.textContent = 'Färger som redan används i appen (mest använda först)';
  pop.append(h3);
  const all = [...scanAppColors()].sort((a, b) => [...b[1].uses.values()].reduce((s, u) => s + u.n, 0) - [...a[1].uses.values()].reduce((s, u) => s + u.n, 0));
  for (const [hex, info] of all) {
    const row = document.createElement('button');
    row.type = 'button'; row.className = 'cp-app';
    const dot = document.createElement('i'); dot.style.background = hex;
    const txt = document.createElement('span');
    const name = document.createElement('b'); name.textContent = info.names.join(' / ') || hex;
    const hx = document.createElement('small'); hx.textContent = hex;
    const where = document.createElement('small');
    const uses = [...info.uses].sort((a, b) => b[1].n - a[1].n).slice(0, 3);
    where.textContent = uses.length ? uses.map(([k, u]) => `${k}${u.n > 1 ? ` (${u.n})` : ''}`).join(', ') : 'Finns i färgreglagen men syns inte i exempelvyerna';
    txt.append(name, hx, where);
    row.append(dot, txt);
    const sample = uses[0]?.[1].el;
    if (sample) {
      const mini = document.createElement('span');
      mini.className = 'cp-mini';
      const g = sample.closest('svg') || (sample.tagName.toLowerCase() === 'svg' ? sample : null);
      if (g) mini.innerHTML = `<svg class="i" style="color:${hex}">${g.innerHTML}</svg>`;
      else {
        mini.textContent = 'Aa';
        mini.style.cssText = `background:${uses[0][0].startsWith('Bakgrund') ? hex : '#fff'};color:${uses[0][0].startsWith('Text') ? hex : (uses[0][0].startsWith('Bakgrund') ? '#fff' : '#222')};${uses[0][0].startsWith('Kant') ? `border:2px solid ${hex}` : ''}`;
      }
      row.append(mini);
    }
    row.onclick = () => pick(hex);
    pop.append(row);
  }
  document.body.append(pop);
  const r = anchor.getBoundingClientRect();
  pop.style.top = Math.max(8, Math.min(r.bottom + 6, innerHeight - 440)) + 'px';
  pop.style.left = Math.max(8, Math.min(r.left, innerWidth - 336)) + 'px';
  colorPop = pop;
}
document.addEventListener('pointerdown', e => { if (colorPop && !colorPop.contains(e.target) && !e.target.closest('.cp-open')) closeColorPop(); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeColorPop(); });

// A small button beside a colour input that opens the popover and feeds the choice back into the input.
function paletteButton(input, onSet) {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'ghost cp-open'; b.textContent = 'Appens färger'; b.title = 'Välj bland färger som redan används i appen';
  b.onclick = () => openColorPopover(b, input.value, hex => { input.value = hex; onSet(hex); });
  return b;
}
