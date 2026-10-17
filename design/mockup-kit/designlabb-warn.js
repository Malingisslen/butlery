'use strict';
// Warnings right at the picked part: contrast, touch target and small text, each with a fix button.
// They only advise; nothing here stops a choice.

const lumOf = hex => {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255).map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratioOf = (a, b) => { const [x, y] = [lumOf(a), lumOf(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
const hexOfColor = c => {
  const m = c.match(/[\d.]+/g)?.map(Number);
  if (!m || m.length < 3) return null;
  return '#' + m.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
};
function backdropOf(el) {
  for (let n = el; n; n = n.parentElement) {
    const m = getComputedStyle(n).backgroundColor.match(/[\d.]+/g)?.map(Number);
    if (m && m.length >= 3 && (m.length === 3 || m[3] > 0.9)) return hexOfColor(getComputedStyle(n).backgroundColor);
  }
  return '#ffffff';
}
const INTERACTIVE = 'button,a,input,select,textarea,[role="button"],.b-btn,.b-iconbtn,.b-chip,.b-checkbox,.b-toggle';

function partWarnings(el, parts) {
  const out = [];
  const cs = getComputedStyle(el), r = el.getBoundingClientRect();
  const bg = backdropOf(el);
  const isIcon = el.matches('svg');
  const hasText = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
  const fg = hexOfColor(cs.color);
  if (fg && (hasText || isIcon)) {
    const big = parseFloat(cs.fontSize) >= 24 || (parseFloat(cs.fontSize) >= 18.66 && +cs.fontWeight >= 700);
    const need = isIcon || big ? 3 : 4.5;
    const got = ratioOf(fg, bg);
    out.push({ ok: got >= need, text: `${isIcon ? 'Ikon' : 'Text'} mot bakgrund: ${got.toFixed(1)}:1 (minst ${need}:1).`,
      fix: got >= need ? null : ['Fixa färgen', () => { const c = fixContrast(fg, bg, need); for (const p of parts) p.props.color = c; }] });
  }
  if (el.matches(INTERACTIVE) && Math.min(r.width, r.height) < 44) {
    out.push({ ok: false, text: `Träffytan är ${Math.round(r.width)} × ${Math.round(r.height)} px. Riktmärke: 44 px (Apple) och 48 dp (Material).`,
      fix: ['Gör minst 48 px', () => { for (const p of parts) { if (r.width < 48) p.props.w = 48; if (r.height < 48) p.props.h = 48; } }] });
  } else if (el.matches(INTERACTIVE)) out.push({ ok: true, text: `Träffytan är ${Math.round(r.width)} × ${Math.round(r.height)} px.` });
  if (hasText && parseFloat(cs.fontSize) < 11) out.push({ ok: false, text: `Texten är ${parseFloat(cs.fontSize)} px. Under 11 px blir den svår att läsa.`,
    fix: ['Gör 12 px', () => { for (const p of parts) p.props.size = 12; }] });
  if (parts.some(p => p.props.anim)) out.push({ ok: false, text: 'Animationen visas stilla när någon valt minskad rörelse. Testa med "Minska rörelse" ovanför skärmarna.' });
  return out;
}

function fixContrast(fg, bg, need) {
  let [h, s, l] = hexToHsl(fg);
  const lighten = lumOf(bg) < 0.4;
  for (let i = 0; i < 40 && ratioOf(hslToHex(h, s, l), bg) < need; i++) l = Math.max(0, Math.min(1, l + (lighten ? 0.03 : -0.03)));
  return hslToHex(h, s, l);
}

function refreshPartWarn(done) {
  const box = document.getElementById('part-warn');
  if (!box || !selected?.el?.isConnected) return;
  box.textContent = '';
  const list = partWarnings(selected.el, selected.parts || [selected.part]);
  for (const w of list) {
    const row = document.createElement('div');
    row.className = `warn-row ${w.ok ? 'ok' : 'bad'}`;
    const t = document.createElement('span'); t.textContent = (w.ok ? 'Ok. ' : 'Varning. ') + w.text;
    row.append(t);
    if (w.fix) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'ghost'; b.textContent = w.fix[0];
      b.onclick = () => { w.fix[1](); render(); done ? done() : refreshPartWarn(); };
      row.append(b);
    }
    box.append(row);
  }
}
