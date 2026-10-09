// F2-R04 · ANALYSPRIMITIVER FOR YTKANDIDATER.
//
// Tre fel intraffade i skarpt lage nar den har logiken lag inbakad i ett
// analysskript. De har nu egna funktioner och egna regressionsprov:
//
//   A  fargparsern tog bara rgb()/rgba(). Ett hexvarde gav null, kvoten blev
//      odefinierad och VARJE kandidat sag duglig ut.
//   B  forgrunder joinades mot sin yta pa FARG. Nar ytan kollapsat till
//      appytans nyans traffade det varje element som lag pa appytan nagon
//      annanstans i skarmen.
//   C  en forgrund som redan foll mot dagens yta diskvalificerade kandidater
//      som inte tillforde nagot nytt fel.

/* ── A · fargtolkning ───────────────────────────────────────────────────── */
export function tolkaFarg(v) {
  if (v === null || v === undefined) return null;
  const t = String(v).trim();
  const m = t.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$/i);
  if (m) return { r: +m[1], g: +m[2], b: +m[3], a: m[4] === undefined ? 1 : +m[4] };
  const h6 = t.match(/^#([0-9a-f]{6})$/i);
  if (h6) return { r: parseInt(h6[1].slice(0, 2), 16), g: parseInt(h6[1].slice(2, 4), 16),
    b: parseInt(h6[1].slice(4, 6), 16), a: 1 };
  const h3 = t.match(/^#([0-9a-f]{3})$/i);
  if (h3) return { r: parseInt(h3[1][0] + h3[1][0], 16), g: parseInt(h3[1][1] + h3[1][1], 16),
    b: parseInt(h3[1][2] + h3[1][2], 16), a: 1 };
  const h8 = t.match(/^#([0-9a-f]{8})$/i);
  if (h8) return { r: parseInt(h8[1].slice(0, 2), 16), g: parseInt(h8[1].slice(2, 4), 16),
    b: parseInt(h8[1].slice(4, 6), 16), a: parseInt(h8[1].slice(6, 8), 16) / 255 };
  return null;
}
const lum = c => { const f = x => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); };
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
export function platta(fg, bg) { const a = tolkaFarg(fg), b = tolkaFarg(bg);
  if (!a) return null; if (a.a >= 1) return a; if (!b) return null;
  return { r: Math.round(a.r * a.a + b.r * (1 - a.a)), g: Math.round(a.g * a.a + b.g * (1 - a.a)),
    b: Math.round(a.b * a.a + b.b * (1 - a.a)), a: 1 }; }

// Returnerar ALLTID ett tal eller null. Ett odefinierat varde far aldrig
// slinka igenom som ett giltigt matresultat.
export function kontrast(fg, bg) {
  const a = platta(fg, bg), b = tolkaFarg(bg);
  if (!a || !b) return null;
  const l1 = lum(a), l2 = lum(b), h = Math.max(l1, l2), l = Math.min(l1, l2);
  const k = Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100;
  return Number.isFinite(k) ? k : null;
}

/* ── B · forgrund mot sin FAKTISKA yta ──────────────────────────────────── */
// Kopplingen sker pa ytans identitet — artefakt plus elementordinal. Farg,
// tokenfarg och narmaste lika berknade varde ar forbjudna som nyckel.
export function forgrunderPaYtan(element, ytor) {
  const ident = new Set(ytor.map(y => y.art + '#' + y.ordinal));
  const ut = [];
  for (const e of element) {
    const u = e.underliggandeYta;
    if (!u || u.ordinal === null || u.ordinal === undefined) continue;
    if (!ident.has(e.art + '#' + u.ordinal)) continue;
    ut.push(e);
  }
  return ut;
}

/* ── C · klassificering av fore och efter ───────────────────────────────── */
export const UTFALL = ['PASS_TO_PASS', 'PASS_TO_FAIL', 'EXISTING_FAIL_IMPROVED',
  'EXISTING_FAIL_UNCHANGED', 'EXISTING_FAIL_WORSENED'];

export function klassificera(fore, efter, troskel) {
  if (fore === null || efter === null || troskel === null) return { utfall: 'UNKNOWN', kopplatFix: false };
  const foreOk = fore >= troskel, efterOk = efter >= troskel;
  if (foreOk && efterOk) return { utfall: 'PASS_TO_PASS', kopplatFix: false };
  if (foreOk && !efterOk) return { utfall: 'PASS_TO_FAIL', kopplatFix: false };
  // Redan fallande. Diskvalificerar aldrig en annars korrekt ytkandidat, men
  // en FORSAMRING far aldrig doljas under "inga nya fel".
  if (efter > fore) return { utfall: 'EXISTING_FAIL_IMPROVED', kopplatFix: false };
  if (efter === fore) return { utfall: 'EXISTING_FAIL_UNCHANGED', kopplatFix: false };
  return { utfall: 'EXISTING_FAIL_WORSENED', kopplatFix: true, markning: 'COUPLED_FIX_REQUIRED' };
}

// En kandidat faller BARA pa PASS_TO_FAIL. Forsamrade befintliga fel gor den
// inte otillaten, men kopplar den till en samtidig forgrundsfix.
export function bedomKandidat(rader) {
  const per = {}; for (const r of rader) per[r.utfall] = (per[r.utfall] || 0) + 1;
  const nya = rader.filter(r => r.utfall === 'PASS_TO_FAIL');
  const kopplade = rader.filter(r => r.kopplatFix);
  return { perUtfall: per, nyaFel: nya.length, kopplatFixKravs: kopplade.length,
    duglig: nya.length === 0 && rader.every(r => r.utfall !== 'UNKNOWN'),
    kraverKopplatFix: kopplade.length > 0, nya, kopplade };
}
